/// PhotoMagic — Flutter port of the PhotoMagic web app (exact parity).
///
/// boot(): load prefs → apply locale/theme → optimistic session restore
/// (open the studio right away) → start the 30 s monitor, the same flow the
/// web build performs. Any model change rebuilds the root, so the studio /
/// login swap and locale/theme flips propagate everywhere.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_model.dart';
import 'home.dart';
import 'screens.dart';
import 'shared.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final model = AppModel(prefs)..initSettings();
  final username = model.readSession();
  if (username != null && username.isNotEmpty) {
    model.restoreSession(username);
    model.startMonitor();
  }
  runApp(PhotoMagicApp(model: model));
}

class PhotoMagicApp extends StatefulWidget {
  const PhotoMagicApp({super.key, required this.model});

  final AppModel model;

  @override
  State<PhotoMagicApp> createState() => _PhotoMagicAppState();
}

class _PhotoMagicAppState extends State<PhotoMagicApp> {
  bool _wasSignedIn = false;

  AppModel get model => widget.model;

  @override
  void initState() {
    super.initState();
    _wasSignedIn = model.signedIn;
    model.addListener(_onModelChanged);
  }

  @override
  void dispose() {
    model.removeListener(_onModelChanged);
    super.dispose();
  }

  void _onModelChanged() {
    final notice = model.sessionEndedNotice;
    var restored = false;
    if (notice != null) model.consumeSessionNotice();
    if (_wasSignedIn && !model.signedIn) {
      restored = true;
      _wasSignedIn = false;
      final navigator = Navigator.of(context, rootNavigator: true);
      if (navigator.canPop()) navigator.popUntil((r) => r.isFirst);
    }
    _wasSignedIn = model.signedIn;
    if (notice != null && mounted) {
      showToast(context, notice, icon: '🔒');
    }
    if (notice == null && restored == false) setState(() {});
    // Session notices already surfaced a rebuild through consumeSessionNotice.
  }

  ThemeData _theme({required bool useDark}) {
    final scheme = useDark ? const Scheme.dark() : const Scheme();
    final brightness = useDark ? Brightness.dark : Brightness.light;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: scheme.accent,
      brightness: brightness,
    ).copyWith(
      primary: scheme.accent,
      onPrimary: scheme.accentInk,
      secondary: scheme.accent,
      onSecondary: scheme.accentInk,
      onSecondaryContainer: scheme.accentInk,
      error: scheme.alarm,
      onError: Colors.white,
      surface: scheme.surface,
      onSurface: scheme.text,
      outline: scheme.frame,
      surfaceContainerLowest: scheme.surface,
      surfaceContainerLow: scheme.glass,
      surfaceContainer: scheme.glass,
      surfaceContainerHigh: scheme.glass,
      surfaceContainerHighest: scheme.glass,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scheme.bg,
      textTheme: const TextTheme().apply(
        bodyColor: scheme.text,
        displayColor: scheme.text,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: scheme.text,
        contentTextStyle: TextStyle(
          color: scheme.bg,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.accent,
          foregroundColor: scheme.accentInk,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.accent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.accent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: scheme.dim, fontSize: 13),
        floatingLabelStyle: TextStyle(color: scheme.dim, fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.frame),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.frame),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.accent, width: 1.6),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhotoMagic',
      debugShowCheckedModeBanner: false,
      theme: _theme(useDark: false),
      darkTheme: _theme(useDark: true),
      themeMode: model.dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => Directionality(
        textDirection:
            model.locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        child: child ?? const SizedBox.shrink(),
      ),
      home: model.signedIn
          ? StudioScreen(model: model)
          : LoginScreen(model: model),
    );
  }
}
