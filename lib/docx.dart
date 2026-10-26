/// Word (.docx) builder — a byte-level port of the web build's buildDocx():
/// same [Content_Types].xml, same rels, same document.xml with anchored
/// drawings (EMU offsets x*360000), same A4 sectPr (11906×16838 twips,
/// 340-twip margins), same DEFLATE zip, same PhotoMagic_A4_<ts>.docx name.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart' as ar;

import 'model.dart';

class DocxPayload {
  DocxPayload(this.bytes, this.name);
  final Uint8List bytes;
  final String name;
}

class _Face {
  _Face(this.key, this.imgIndex, this.relId, this.w, this.h);
  final String key;
  final int imgIndex; // index into images
  final String relId;
  final double w;
  final double h;
}

Future<DocxPayload> buildDocx(
  Plan plan,
  Future<Uint8List> Function(double w, double h, ui.Image img) renderFace,
) async {
  final faces = <_Face>[];
  final faceIds = <String, String>{};
  final images = <(double, double, ui.Image)>[]; // (w, h, ui.Image)

  for (final p in plan.placed) {
    final key = '${p.item.id}_${p.back ? 'b' : 'f'}';
    final img = p.back ? p.item.backBitmap : p.item.bitmap;
    if (img == null || faceIds.containsKey(key)) continue;
    final relId = 'rId${faces.length + 1}';
    faceIds[key] = relId;
    final imgIndex = images.length;
    images.add((p.w, p.h, img));
    faces.add(_Face(key, imgIndex, relId, p.w, p.h));
  }

  final archive = ar.Archive();

  for (var index = 0; index < faces.length; index++) {
    final face = faces[index];
    final (w, h, img) = images[face.imgIndex];
    final png = await renderFace(w, h, img);
    archive.addFile(ar.ArchiveFile(
      'word/media/image_${index + 1}.png',
      png.length,
      png,
    ));
  }

  archive.addFile(ar.ArchiveFile.string(
    '[Content_Types].xml',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Default Extension="png" ContentType="image/png"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''',
  ));

  archive.addFile(ar.ArchiveFile.string(
    '_rels/.rels',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''',
  ));

  var rels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">''';
  for (final face in faces) {
    rels +=
        '<Relationship Id="${face.relId}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/image_${face.imgIndex + 1}.png"/>';
  }
  rels += '</Relationships>';
  archive.addFile(ar.ArchiveFile.string('word/_rels/document.xml.rels', rels));

  var doc = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
 xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
 xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
 xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
 xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><w:body>''';

  for (var p = 0; p < plan.totalPages; p++) {
    if (p > 0) doc += '<w:p><w:r><w:br w:type="page"/></w:r></w:p>';
    doc += '<w:p><w:pPr><w:spacing w:before="0" w:after="0"/></w:pPr>';
    for (final i in plan.placed.where((el) => el.page == p)) {
      final relId =
          faceIds['${i.item.id}_${i.back ? 'b' : 'f'}'] ?? 'rId1';
      final x = (i.x * 360000).round();
      final y = (i.y * 360000).round();
      final w = (i.w * 360000).round();
      final h = (i.h * 360000).round();
      doc +=
          '<w:r><w:drawing><wp:anchor distT="0" distB="0" distL="0" distR="0" simplePos="0" relativeHeight="${251658240 + i.order}" behindDoc="0" locked="0" layoutInCell="1" allowOverlap="1"><wp:simplePos x="0" y="0"/><wp:positionH relativeFrom="page"><wp:posOffset>$x</wp:posOffset></wp:positionH><wp:positionV relativeFrom="page"><wp:posOffset>$y</wp:posOffset></wp:positionV><wp:extent cx="$w" cy="$h"/><wp:wrapNone/><wp:docPr id="${i.order + 1}" name="Photo_${i.order + 1}"/><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic><pic:nvPicPr><pic:cNvPr id="${i.order + 1}" name="Photo_${i.order + 1}"/><pic:cNvPicPr><a:picLocks noChangeAspect="1"/></pic:cNvPicPr></pic:nvPicPr><pic:blipFill><a:blip r:embed="$relId"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$w" cy="$h"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:anchor></w:drawing></w:r>';
    }
    doc += '</w:p>';
  }

  doc +=
      '<w:sectPr><w:pgSz w:w="11906" w:h="16838" w:orient="portrait"/><w:pgMar w:top="340" w:right="340" w:bottom="340" w:left="340" w:header="0" w:footer="0"/></w:sectPr></w:body></w:document>';
  archive.addFile(ar.ArchiveFile.string('word/document.xml', doc));

  final zipped = ar.ZipEncoder().encode(archive);
  if (zipped == null) {
    throw StateError('ZipEncoder returned a null archive');
  }
  final name = 'PhotoMagic_A4_${DateTime.now().millisecondsSinceEpoch}.docx';
  return DocxPayload(Uint8List.fromList(zipped), name);
}
