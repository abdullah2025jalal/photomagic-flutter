/// Word/.docx and 300-DPI page "download" targets per platform:
/// browsers go through a real download, native apps write to Documents.
library;

import 'dart:typed_data';

/// Default fallback (never selected in practice — one of the branches below
/// always matches).
Future<String> writeOutFile(String name, Uint8List bytes) async => name;
