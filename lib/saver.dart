/// Conditional export of the platform saver (see saver_web / saver_io).
library;

export 'saver_stub.dart'
    if (dart.library.html) 'saver_web.dart'
    if (dart.library.io) 'saver_io.dart';
