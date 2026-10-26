/// App state — the single source of truth, ported verbatim from the web
/// build: items, optimistic session, the 30 s monitor with the SAME dead
/// rules (account gone / suspended-now / expired-now; transient network
/// errors keep the session), the attempt lockout (5 attempts → 30 s×shift),
/// locale/theme, the docx warm cache and every studio mutation.
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth.dart' show fetchAccount, kMaxAttempts;
import 'docx.dart';
import 'i18n.dart';
import 'model.dart';
import 'render.dart';
import 'saver.dart';

const kMonitorMs = 30000;
const kSessionKey = 'photomagic.web.session.v1';
const kLocaleKey = 'photomagic.web.locale_v1';
const kThemeKey = 'photomagic.web.theme_v1';
const kLockKey = 'photomagic.web.lock_v1.lock';
const kInstallDismissKey = 'photomagic.web.install_dismissed_v1';
const kMimeDocx =
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

class AppModel extends ChangeNotifier {
  AppModel(this._prefs);

  final SharedPreferences _prefs;
  final picker = ImagePicker();

  final items = <PmItem>[];
  ui.Image? docFrontBitmap;
  ui.Image? docBackBitmap;

  String locale = kDefaultLocale;
  bool dark = false;
  bool signedIn = false;
  String? sessionUsername;
  String? sessionEndedNotice;
  int failedAttempts = 0;

  Timer? _monitorTimer;

  // The pre-built Word file for the CURRENT layout (webapp docxCache).
  DocxPayload? _docxCache;
  String? _docxCacheKey;
  bool _warming = false;

  // ------------------------------------------------------------------
  // i18n + theme
  // ------------------------------------------------------------------
  String t(String key) => tOf(locale, key);

  String tf(String key, {required String s}) =>
      tOf(locale, key).replaceFirst('{s}', s);

  void initSettings() {
    dark = _prefs.getString(kThemeKey) == 'dark';
    final savedLocale = _prefs.getString(kLocaleKey);
    locale = savedLocale == 'en' ? 'en' : 'ar';
  }

  void applyLocale(String next) {
    final value = next == 'en' ? 'en' : 'ar';
    if (value == locale) return;
    locale = value;
    _prefs.setString(kLocaleKey, value);
    notifyListeners();
  }

  void applyTheme(bool isDark) {
    if (isDark == dark) return;
    dark = isDark;
    _prefs.setString(kThemeKey, dark ? 'dark' : 'light');
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // session (same keys and the same 30 s monitor as the web build)
  // ------------------------------------------------------------------
  String? readSession() => _prefs.getString(kSessionKey);

  /// Optimistic restore at boot: the UI opens directly on the studio; the
  /// monitor re-checks after 30 s and kills dead sessions.
  void restoreSession(String username) {
    sessionUsername = username;
    signedIn = true;
  }

  void saveSession(String username) {
    sessionUsername = username;
    signedIn = true;
    _prefs.setString(kSessionKey, username);
    notifyListeners();
  }

  void logout() {
    _endSession(false);
  }

  void _endSession(bool withNotice) {
    sessionUsername = null;
    signedIn = false;
    failedAttempts = 0;
    _prefs.remove(kSessionKey);
    stopMonitor();
    docFrontBitmap = null;
    docBackBitmap = null;
    if (withNotice) sessionEndedNotice = t('sessionEnded');
    notifyListeners();
  }

  MonitorStatus? _debugLastStatus; // kept for dev introspection only

  /// 30 s monitor — same dead rules as the web build. Transient network
  /// failures keep the session (optimistic) and the next tick re-checks.
  void startMonitor() {
    stopMonitor();
    _monitorTimer = Timer.periodic(
      const Duration(milliseconds: kMonitorMs),
      (_) async {
        final username = sessionUsername;
        if (username == null || !signedIn) return;
        try {
          final account = await fetchAccount(username);
          final now = DateTime.now().millisecondsSinceEpoch;
          final permanent = account is Map && account['permanent'] == true;
          final expiryVal = account is Map ? account['expiry_at'] : null;
          final expiry = expiryVal is num ? expiryVal.toInt() : 0;
          final suspended = account is Map && account['suspended'] == true;
          final untilVal = account is Map ? account['suspended_until'] : null;
          final suspendedUntil = untilVal is num ? untilVal.toInt() : 0;
          final dead = account is! Map ||
              (suspended && (suspendedUntil <= 0 || now < suspendedUntil)) ||
              (!permanent && expiry > 0 && now >= expiry);
          _debugLastStatus = dead ? MonitorStatus.dead : MonitorStatus.alive;
          if (dead) _endSession(true);
          return;
        } catch (_) {
          _debugLastStatus = MonitorStatus.networkError;
        }
      },
    );
  }

  void stopMonitor() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
  }

  void consumeSessionNotice() {
    if (sessionEndedNotice == null) return;
    sessionEndedNotice = null;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // attempt lockout (same numbers as the web/lock pref)
  // ------------------------------------------------------------------
  int lockUntilMillis() {
    final raw = _prefs.getString(kLockKey);
    return int.tryParse(raw ?? '') ?? 0;
  }

  void registerFailure() {
    failedAttempts += 1;
    if (failedAttempts >= kMaxAttempts) {
      final seconds = 30 << (failedAttempts - kMaxAttempts);
      _prefs.setInt(
        kLockKey,
        DateTime.now().millisecondsSinceEpoch + seconds * 1000,
      );
    }
  }

  void clearLock() {
    failedAttempts = 0;
    _prefs.remove(kLockKey);
  }

  // ------------------------------------------------------------------
  // studio state
  // ------------------------------------------------------------------
  Plan get plan => computePlan(items);

  void _invalidate() {
    _docxCache = null;
    _docxCacheKey = null;
    notifyListeners();
  }

  Future<ui.Image> loadImage(XFile file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// The exact web behavior: every picked file becomes one photo item with
  /// 3×4 cm / 6 copies defaults, numbered per existing photo count.
  Future<void> addPhotoFiles(List<XFile> files) async {
    if (files.isEmpty) return;
    var count = items.where((i) => i.type == 'PHOTO').length;
    for (final file in files) {
      count += 1;
      items.add(PmItem(
        id: 'p_${DateTime.now().millisecondsSinceEpoch}_$count',
        type: 'PHOTO',
        name: '${t('photoName')} $count',
        bitmap: await loadImage(file),
        widthCm: 3.0,
        heightCm: 4.0,
        copies: 6,
      ));
    }
    _invalidate();
  }

  Future<void> pickDocFront() async {
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;
    docFrontBitmap = await loadImage(x);
    notifyListeners();
  }

  Future<void> pickDocBack() async {
    final x = await picker.pickImage(source: ImageSource.gallery);
    if (x == null) return;
    docBackBitmap = await loadImage(x);
    notifyListeners();
  }

  void resetDocPicks() {
    docFrontBitmap = null;
    docBackBitmap = null;
  }

  /// Adds the document from the sheet's picks; false when no front image.
  Future<bool> addDoc(
    String duplex,
    double wCm,
    double hCm,
    int copies,
  ) async {
    final front = docFrontBitmap;
    if (front == null) return false;
    items.add(PmItem(
      id: 'd_${DateTime.now().millisecondsSinceEpoch}',
      type: 'DOCUMENT',
      name: '${t('docName')} $wCm×$hCm cm',
      bitmap: front,
      backBitmap: docBackBitmap,
      duplexMode: duplex,
      widthCm: wCm,
      heightCm: hCm,
      copies: copies < 1 ? 1 : copies,
    ));
    docFrontBitmap = null;
    docBackBitmap = null;
    _invalidate();
    return true;
  }

  void deleteItem(int index) {
    if (index < 0 || index >= items.length) return;
    items.removeAt(index);
    _invalidate();
  }

  /// Stepper of the card — clamps at 1, exactly like the web `Math.max(1, ...)`.
  void stepCopies(int index, int delta) {
    if (index < 0 || index >= items.length) return;
    final item = items[index];
    item.copies = item.copies + delta < 1 ? 1 : item.copies + delta;
    _invalidate();
  }

  /// Edit sheet save — same validation semantics as the web (≥1 / doc name).
  void saveEdits(
    int index,
    double wCm,
    double hCm,
    int copies,
    String? duplex,
  ) {
    if (index < 0 || index >= items.length) return;
    final item = items[index];
    item.widthCm = wCm;
    item.heightCm = hCm;
    item.copies = copies;
    if (item.isDoc && duplex != null) {
      item.duplexMode = duplex;
      item.name = '${t('docName')} $wCm×$hCm cm';
    }
    _invalidate();
  }

  // ------------------------------------------------------------------
  // Word export warmth + share/outputs
  // ------------------------------------------------------------------
  Future<DocxPayload> getDocxPayload() async {
    final key = planKey(plan);
    if (_docxCache != null && _docxCacheKey == key) return _docxCache!;
    var payload = await buildDocx(plan, renderFacePng);
    // If the items changed while building, rebuild once so the file matches
    // the layout that is actually on screen (same guard as the web build).
    if (planKey(plan) != key) {
      payload = await buildDocx(plan, renderFacePng);
    }
    _docxCache = payload;
    _docxCacheKey = planKey(plan);
    return payload;
  }

  bool get docxWarm {
    if (_docxCache == null) return false;
    return _docxCacheKey == planKey(plan);
  }

  /// Fire-and-forget warm-up so the share button hands the real file to the
  /// OS sheet within the same tap (iOS-safe, same reason as the web build).
  void warmDocx() {
    if (items.isEmpty || _warming || docxWarm) return;
    _warming = true;
    getDocxPayload()
        .catchError((Object e) => DocxPayload(Uint8List(0), ''))
        .whenComplete(() {
      _warming = false;
    });
  }

  /// Hands the real .docx to the native OS share UI. Returns:
  /// 'shared' | 'cancelled' | 'unsupported' | 'failed' (webapp contract).
  Future<String> tryNativeFileShare(DocxPayload payload) async {
    try {
      final result = await Share.shareXFiles(
        [
          XFile.fromData(
            payload.bytes,
            name: payload.name,
            mimeType: kMimeDocx,
          ),
        ],
        title: 'PhotoMagic',
        text: t('shareDocxText'),
      );
      switch (result.status) {
        case ShareResultStatus.success:
          return 'shared';
        case ShareResultStatus.dismissed:
          return 'cancelled';
        case ShareResultStatus.unavailable:
          return 'unsupported';
      }
    } catch (_) {
      return 'failed';
    }
  }

  /// Writes named bytes to the right destination (browser download or the
  /// Documents directory) and returns the resulting path/name.
  Future<String> saveOutFile(String name, Uint8List bytes) =>
      writeOutFile(name, bytes);
}

enum MonitorStatus { alive, dead, networkError }
