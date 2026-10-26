/// Writes a real file through the browser download (the direct analogue of
/// the web build's downloadBlob(): blob URL + anchor + revoke after 8 s).
library;

import 'dart:html' as html;
import 'dart:typed_data';

Future<String> writeOutFile(String name, Uint8List bytes) async {
  final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes]));
  final anchor = html.AnchorElement(href: url)
    ..download = name
    ..click();
  // Give the browser time to start the download before revoking (same 8 s
  // as the web build's setTimeout).
  Future.delayed(const Duration(seconds: 8), () {
    try {
      html.Url.revokeObjectUrl(url);
      anchor.remove();
    } catch (_) {}
  });
  return name;
}
