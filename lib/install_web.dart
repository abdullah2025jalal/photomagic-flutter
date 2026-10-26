/// Web-only install/browser bridge — real implementation (dart:js_util).
///
/// Reads the globals installed by `web/index.html`:
///   __PM_STANDALONE / __PM_INSTALLED / __PM_INSTALL_EVENT
library;

import 'dart:js_util' as js_util;

const bool pmIsWebBrowser = true;

dynamic _global(String key) {
  try {
    return js_util.getProperty(js_util.globalThis, key);
  } catch (_) {
    return null;
  }
}

bool pmStandalone() => _global('__PM_STANDALONE') == true;

bool pmInstalled() => _global('__PM_INSTALLED') == true;

bool pmInstallAvailable() => _global('__PM_INSTALL_EVENT') != null;

bool pmIsSecureContext() => _global('isSecureContext') == true;

bool pmIsOnline() {
  final nav = _global('navigator');
  if (nav == null) return true;
  try {
    return js_util.getProperty(nav, 'onLine') != false;
  } catch (_) {
    return true;
  }
}

/// Triggers the native in-browser install prompt. Returns true when it was
/// actually fired (the event exists); false on iPhone/Firefox (no event).
bool pmPromptInstall() {
  final event = _global('__PM_INSTALL_EVENT');
  if (event == null) return false;
  try {
    js_util.callMethod(event, 'prompt', const <dynamic>[]);
    return true;
  } catch (_) {
    return false;
  }
}

/// Same browser sniff as the web build (isIos): iPhone/iPad/iPod, or an
/// iPadOS-13+ desktop-Mac UA with 5 touch points.
bool pmIsIos() {
  final nav = _global('navigator');
  if (nav == null) return false;
  final ua = '${js_util.getProperty(nav, 'userAgent')}'.toLowerCase();
  final maxTouch = js_util.getProperty(nav, 'maxTouchPoints');
  final isAppleTouchDevice =
      ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
  return isAppleTouchDevice || (ua.contains('macintosh') && maxTouch == 5);
}
