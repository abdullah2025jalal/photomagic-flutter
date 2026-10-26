/// Writes a real file through the browser download — the direct analogue of
/// the web build's downloadBlob(): Blob URL + anchor + revoke after 8 s.
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

@JS('Blob')
external JSFunction get _blobCtor;

@JS('URL')
external JSObject get _urlCls;

@JS('document')
external JSObject get _document;

Future<String> writeOutFile(String name, Uint8List bytes) async {
  final parts = <JSAny?>[bytes.toJS].toJS;
  final blob = _blobCtor.callAsConstructor<JSObject>(parts);
  final url = _urlCls.callMethod<JSString>('createObjectURL'.toJS, blob).toDart;

  final anchor = _document.callMethod<JSObject>('createElement'.toJS, 'a'.toJS);
  anchor.setProperty('href'.toJS, url.toJS);
  anchor.setProperty('download'.toJS, name.toJS);
  final body = _document.getProperty('body'.toJS) as JSObject;
  body.callMethod<JSAny?>('appendChild'.toJS, anchor);
  anchor.callMethod<JSAny?>('click'.toJS);

  // Give the browser time to start the download before revoking (same 8 s
  // as the web build's setTimeout).
  Future.delayed(const Duration(seconds: 8), () {
    try {
      _urlCls.callMethod<JSAny?>('revokeObjectURL'.toJS, url.toJS);
      body.callMethod<JSAny?>('removeChild'.toJS, anchor);
    } catch (_) {}
  });
  return name;
}
