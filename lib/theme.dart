import 'package:flutter/material.dart';

/// Palette — ported EXACTLY from the web app (index.html :root /
/// html[data-theme=dark]).
class PMColors {
  PMColors._();

  static const bg = Color(0xFFF6F8FC);
  static const surface = Color(0xFFFFFFFF);
  static const frame = Color(0xFFC3CAD8);
  static const text = Color(0xFF101423);
  static const dim = Color(0xFF5A6478);
  static const glass = Color(0X14646F87);
  static const accent = Color(0xFF0087A3);
  static const accentInk = Color(0xFFFFFFFF);
  static const good = Color(0xFF00A34A);
  static const alarm = Color(0xFFD21243);
  static const amber = Color(0xFFB26B00);
  static const shadow = Color(0x1A101423);

  static const darkBg = Color(0xFF12131C);
  static const darkSurface = Color(0xFF1A1B26);
  static const darkFrame = Color(0xFF2A2C3D);
  static const darkText = Color(0xFFE8F0FF);
  static const darkDim = Color(0xFF8A93AC);
  static const darkGlass = Color(0x591E2233);
  static const darkAccent = Color(0xFF00F2FE);
  static const darkAccentInk = Color(0xFF04222A);
  static const darkGood = Color(0xFF00FF87);
  static const darkAlarm = Color(0xFFFF2A55);
  static const darkAmber = Color(0xFFFFC24B);
  static const darkShadow = Color(0x73000000);

  /// Real brand channel colors — same tints as ContactSheet (Android) and
  /// the web build.
  static const whatsapp = Color(0xFF25D366);
  static const telegram = Color(0xFF229ED9);
  static const email = Color(0xFFEA4335);
}

/// Resolved palette for the active theme mode.
class Scheme {
  const Scheme.dark()
      : bg = PMColors.darkBg,
        surface = PMColors.darkSurface,
        frame = PMColors.darkFrame,
        text = PMColors.darkText,
        dim = PMColors.darkDim,
        glass = PMColors.darkGlass,
        accent = PMColors.darkAccent,
        accentInk = PMColors.darkAccentInk,
        good = PMColors.darkGood,
        alarm = PMColors.darkAlarm,
        amber = PMColors.darkAmber;

  const Scheme()
      : bg = PMColors.bg,
        surface = PMColors.surface,
        frame = PMColors.frame,
        text = PMColors.text,
        dim = PMColors.dim,
        glass = PMColors.glass,
        accent = PMColors.accent,
        accentInk = PMColors.accentInk,
        good = PMColors.good,
        alarm = PMColors.alarm,
        amber = PMColors.amber;

  final Color bg, surface, frame, text, dim, glass;
  final Color accent, accentInk, good, alarm, amber;
}

const pmShadow = BoxShadow(
  blurRadius: 30,
  offset: Offset(0, 10),
  color: Color(0x1A101423),
);
const pmShadowDark = BoxShadow(
  blurRadius: 30,
  offset: Offset(0, 10),
  color: Color(0x73000000),
);
