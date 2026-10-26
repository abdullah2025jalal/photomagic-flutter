/// Native implementation: writes bytes into the app documents directory
/// (Android scoped storage covers Documents/PhotoMagic/...).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> writeOutFile(String name, Uint8List bytes) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  await file.writeAsBytes(bytes);
  return file.path;
}
