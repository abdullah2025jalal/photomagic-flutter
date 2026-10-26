/// Conditional export: web builds use the real browser bridge, native
/// builds use the stub (install prompts exist only in browsers).
library;

export 'install_stub.dart'
    if (dart.library.html) 'install_web.dart'
    if (dart.library.js_interop) 'install_web.dart';
