/// Web-only install/browser bridge — real implementation (dart:js_interop).
///
/// Reads the globals installed by `web/index.html`:
///   __PM_STANDALONE / __PM_INSTALLED / __PM_INSTALL_EVENT
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// `window.navigator` — resolved lazily on first access.
@JS('navigator')
external JSObject get _navigator;

@JS('__PM_STANDALONE')
external JSAny? get _pmStandalone;

@JS('__PM_INSTALLED')
external JSAny? get _pmInstalled;

@JS('__PM_INSTALL_EVENT')
external JSAny? get _pmInstallEvent;

@JS('isSecureContext')
external JSAny? get _isSecureContext;

const bool pmIsWebBrowser = true;

/// JS truthiness coercion for the globals (they are plain booleans/objects
/// written by the bootstrap script of `web/index.html`).
bool _asBool(JSAny? value) {
  if (value == null) return false;
  if (value.isA<JSBoolean>()) return (value as JSBoolean).toDart;
  if (value.isUndefinedOrNull) return false;
  if (value.isA<JSNumber>()) return (value as JSNumber).toDartInt != 0;
  if (value.isA<JSString>()) return (value as JSString).toDart.isNotEmpty;
  return true;
}

bool pmStandalone() => _asBool(_pmStandalone);

bool pmInstalled() => _asBool(_pmInstalled);

bool pmInstallAvailable() {
  final event = _pmInstallEvent;
  return event != null && !event.isUndefinedOrNull;
}

bool pmIsSecureContext() => _asBool(_isSecureContext);

bool pmIsOnline() {
  try {
    final onLine = _navigator.getProperty('onLine'.toJS);
    if (onLine.isA<JSBoolean>()) return (onLine as JSBoolean).toDart;
    return true;
  } catch (_) {
    return true;
  }
}

/// Triggers the native in-browser install prompt. Returns true when it was
/// actually fired (the event exists); false on iPhone/Firefox (no event).
bool pmPromptInstall() {
  final event = _pmInstallEvent;
  if (event != null && !event.isA<JSObject>()) return false;
  try {
    (event as JSObject).callMethod<JSAny?>('prompt'.toJS);
    return true;
  } catch (_) {
    return false;
  }
}

/// Same browser sniff as the web build (isIos): iPhone/iPad/iPod, or an
/// iPadOS-13+ desktop-Mac UA with 5 touch points.
bool pmIsIos() {
  try {
    final nav = _navigator;
    final uaAny = nav.getProperty('userAgent'.toJS);
    final ua = (uaAny.isA<JSString>() ? (uaAny as JSString).toDart : '')
        .toLowerCase();
    final touchesAny = nav.getProperty('maxTouchPoints'.toJS);
    final touches = touchesAny.isA<JSNumber>()
        ? (touchesAny as JSNumber).toDartInt
        : 0;
    final isAppleTouchDevice =
        ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod');
    final desktopMac = ua.contains('macintosh') && touches == 5;
    return isAppleTouchDevice || desktopMac;
  } catch (_) {
    return false;
  }
}
