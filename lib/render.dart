/// Image rendering helpers — Dart ports of the web build's drawCropped /
/// paintPage / savePageImage and the docx media renderer.
///
/// drawCropped reproduces the cover-crop semantics EXACTLY (source crop
/// window rounded with Math.round-for-Dart `.round()` at the same spots).
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show CustomPainter, Canvas, Offset, Paint, Rect, Path, FilterQuality, PaintingStyle;

import 'model.dart';

/// Draws [img] cover-cropped into the destination rect, exactly like the
/// web build's drawCropped(ctx, img, dx, dy, dw, dh).
void drawCropped(
  ui.Canvas canvas,
  ui.Image img,
  double dx,
  double dy,
  double dw,
  double dh,
) {
  final target = dw / dh;
  final source = img.width / img.height;
  var sx = 0.0;
  var sy = 0.0;
  var sw = img.width.toDouble();
  var sh = img.height.toDouble();
  if (source > target) {
    sw = (img.height * target).roundToDouble();
    sx = ((img.width - sw) / 2).roundToDouble();
  } else {
    sh = (img.width / target).roundToDouble();
    sy = ((img.height - sh) / 2).roundToDouble();
  }
  final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;
  canvas.drawImageRect(
    img,
    ui.Rect.fromLTWH(sx, sy, sw, sh),
    ui.Rect.fromLTWH(dx, dy, dw, dh),
    paint,
  );
}

/// Renders one A4 page to PNG bytes at [dpi] — the direct analogue of
/// paintPage(canvas, pageIndex, plan, dpi) + canvas.toDataURL.
Future<Uint8List> renderPagePng(
  Plan plan,
  int pageIndex,
  int dpi,
) async {
  final width = ((plan.pageWidth / 2.54) * dpi).round();
  final height = ((plan.pageHeight / 2.54) * dpi).round();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );

  for (final placed in plan.placed.where((p) => p.page == pageIndex)) {
    final img = placed.back ? placed.item.backBitmap : placed.item.bitmap;
    if (img == null) continue;
    drawCropped(
      canvas,
      img,
      ((placed.x / 2.54) * dpi).roundToDouble(),
      ((placed.y / 2.54) * dpi).roundToDouble(),
      ((placed.w / 2.54) * dpi).roundToDouble(),
      ((placed.h / 2.54) * dpi).roundToDouble(),
    );
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// Renders a face used by the .docx builder — 600 px wide, height scaled to
/// the face's aspect ratio, cover-cropped — exactly like the web build's
/// faces.forEach loop.
Future<Uint8List> renderFacePng(double wCm, double hCm, ui.Image img) async {
  const targetWidth = 600;
  final height = (targetWidth * (hCm / wCm)).round();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  drawCropped(canvas, img, 0, 0, targetWidth.toDouble(), height.toDouble());
  final picture = recorder.endRecording();
  final image = await picture.toImage(targetWidth, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// On-screen A4 page preview — used as the direct visual counterpart of the
/// web build's renderPapers canvases (proportional to the cm plan).
class PagePreviewPainter extends CustomPainter {
  const PagePreviewPainter({
    required this.plan,
    required this.pageIndex,
    required this.dark,
  });

  final Plan plan;
  final int pageIndex;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / plan.pageWidth;
    final h = plan.pageHeight * scale;
    final bg = dark ? const Color(0xFF1A1B26) : const Color(0xFFFFFFFF);

    final pageRect = Rect.fromLTWH(0, 0, size.width, h);
    canvas.drawRect(pageRect, Paint()..color = bg);

    final framePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = dark ? const Color(0xFF2A2C3D) : const Color(0x66C3CAD8);
    canvas.drawRect(pageRect.deflate(0.5), framePaint);

    // Portrait/page frames outline the printable pages like the tenant
    // preview box on web (the pages appear as A4 cards).
    final shadowPath = Path()
      ..addRect(pageRect.shift(const Offset(0, 2)))
      ..close();
    canvas.drawShadow(shadowPath, const Color(0x33000000), 20, false);

    canvas.save();
    canvas.clipRect(pageRect);
    for (final placed in plan.placed.where((p) => p.page == pageIndex)) {
      final img = placed.back ? placed.item.backBitmap : placed.item.bitmap;
      if (img == null) continue;
      // Round at the same points the web build rounds (paintPage).
      canvas.drawImageRect(
        img,
        _coverSource(img, placed.w, placed.h),
        Rect.fromLTWH(
          (placed.x * scale),
          (placed.y * scale),
          (placed.w * scale),
          (placed.h * scale),
        ),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    canvas.restore();
  }

  ui.Rect _coverSource(ui.Image img, double wCm, double hCm) {
    final target = wCm / hCm;
    final source = img.width / img.height;
    var sx = 0.0;
    var sy = 0.0;
    var sw = img.width.toDouble();
    var sh = img.height.toDouble();
    if (source > target) {
      sw = (img.height * target).roundToDouble();
      sx = ((img.width - sw) / 2).roundToDouble();
    } else {
      sh = (img.width / target).roundToDouble();
      sy = ((img.height - sh) / 2).roundToDouble();
    }
    return ui.Rect.fromLTWH(sx, sy, sw, sh);
  }

  @override
  bool shouldRepaint(covariant PagePreviewPainter oldDelegate) =>
      oldDelegate.pageIndex != pageIndex ||
      oldDelegate.dark != dark ||
      !identical(oldDelegate.plan, plan);
}
