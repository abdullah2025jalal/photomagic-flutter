/// Account verification + session handling from the web build — a faithful
/// Dart port of fetchAccount / verifyAccount / pbkdf2Hex / pbkdf2Hash /
/// sha256Hex / equalHex / lockUntil / registerFailure.
///
/// Contract (same as the Android apps + admin panel):
///   /accounts/{username}   (username = trimmed, lower-cased)
///     salt:            hex string (UTF-8 bytes are the PBKDF2 salt)
///     hash:            "v2$<iterations>$<saltHex>$<digestHex>"  (PBKDF2)
///                      ...or legacy bare sha256(salt + password) hex
///     permanent:       true | false
///     expiry_at:       epoch ms (temporary accounts only)
///     suspended:       true | false
///     suspended_until: epoch ms (0/absent = permanent suspension)
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

const kDbUrl =
    'https://photomagic-2a69e-default-rtdb.europe-west1.firebasedatabase.app';
const kMaxAttempts = 5;

String hexDump(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

String sha256Hex(String text) => hexDump(sha256.convert(utf8.encode(text)).bytes);

/// PBKDF2-HMAC-SHA256 — the salt is used EXACTLY as the stored string bytes
/// (same subtle behavior the web build relies on).
String pbkdf2Hex(String password, String salt, int iterations) {
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(
      Uint8List.fromList(utf8.encode(salt)),
      iterations,
      256,
    ));
  final out = derivator.process(Uint8List.fromList(utf8.encode(password)));
  return hexDump(out);
}

/// Byte-wise comparison, identical to equalHex (length short-circuit first).
bool equalHex(String a, String b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
  }
  return diff == 0;
}

String pbkdf2Hash(String salt, String password, int iterations) =>
    'v2\$$iterations\$$salt\$${pbkdf2Hex(password, salt, iterations)}';

/// Reads one account node through the RTDB REST API.
Future<dynamic> fetchAccount(String username) async {
  final response = await http
      .get(
        Uri.parse('$kDbUrl/accounts/${Uri.encodeComponent(username)}.json'),
        headers: {'Cache-Control': 'no-store'},
      )
      .timeout(const Duration(seconds: 20));
  if (response.statusCode != 200) {
    throw TransientAccountError(response.statusCode);
  }
  // Avoid storing/handling errors; return raw parsed JSON.
  return jsonDecode(response.body);
}

class TransientAccountError implements Exception {
  TransientAccountError(this.statusCode);
  final int statusCode;
}

/// Result statuses mirror the web build exactly.
enum VerifyStatus { success, invalid, suspended, expired, offline }

class VerifyResult {
  const VerifyResult(this.status, this.account);
  final VerifyStatus status;
  final Map<String, dynamic>? account;
}

/// Verifies credentials exactly like the Android app:
/// suspension → expiry → password hash (v2 PBKDF2 or legacy sha256).
Future<VerifyResult> verifyAccount(String username, String password) async {
  final key = username.trim().toLowerCase();
  if (key.isEmpty || password.isEmpty) {
    return const VerifyResult(VerifyStatus.invalid, null);
  }

  dynamic account;
  try {
    account = await fetchAccount(key);
  } catch (e) {
    return const VerifyResult(VerifyStatus.offline, null);
  }
  if (account is! Map<String, dynamic>) {
    return const VerifyResult(VerifyStatus.invalid, null);
  }
  final salt = account['salt'];
  final stored = account['hash'];
  if (salt is! String || stored is! String) {
    return const VerifyResult(VerifyStatus.invalid, null);
  }

  final now = DateTime.now().millisecondsSinceEpoch;
  final permanent = account['permanent'] == true;
  final expiryVal = account['expiry_at'];
  final expiry = expiryVal is num ? expiryVal.toInt() : 0;
  final suspended = account['suspended'] == true;
  final suspendedUntilVal = account['suspended_until'];
  final suspendedUntil = suspendedUntilVal is num ? suspendedUntilVal.toInt() : 0;

  if (suspended && (suspendedUntil <= 0 || now < suspendedUntil)) {
    return const VerifyResult(VerifyStatus.suspended, null);
  }
  if (!permanent && expiry > 0 && now >= expiry) {
    return const VerifyResult(VerifyStatus.expired, null);
  }

  var ok = false;
  String? upgraded;
  if (stored.startsWith('v2\$')) {
    final parts = stored.split(r'$');
    final iterations =
        parts.length == 4 ? int.tryParse(parts[1]) ?? -1 : -1;
    if (iterations > 0 && iterations <= 2000000 && parts[3].length == 64) {
      ok = equalHex(pbkdf2Hex(password, parts[2], iterations), parts[3]);
    }
  } else if (stored.length == 64) {
    ok = equalHex(sha256Hex('$salt$password'), stored);
    if (ok) upgraded = pbkdf2Hash(salt, password, 100000);
  }

  if (!ok) return const VerifyResult(VerifyStatus.invalid, null);

  // One-time v1 → v2 hardening, same as the Android app (best effort:
  // silently skipped when the database rules are read-only).
  if (upgraded != null) {
    http
        .patch(
          Uri.parse('$kDbUrl/accounts/${Uri.encodeComponent(key)}.json'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'hash': upgraded}),
        )
        .catchError((Object e) => http.Response('', 0));
  }

  return VerifyResult(VerifyStatus.success, account);
}
