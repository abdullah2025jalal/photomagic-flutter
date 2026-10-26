/// Domain model + the A4 layout engine — a faithful Dart port of the web
/// build's computePlan() (page 21.0×29.7 cm, margin 0.6, spacing 0.1, photo
/// rows capped at 6 when w<=3.05, documents on their own rows below with the
/// SAME_PAGE / BACK_SIDE duplex semantics).
library;

import 'dart:ui' as ui;

/// 'PHOTO' | 'DOCUMENT'
class PmItem {
  PmItem({
    required this.id,
    required this.type,
    required this.name,
    required this.bitmap,
    this.backBitmap,
    this.duplexMode,
    required this.widthCm,
    required this.heightCm,
    this.copies = 1,
  });

  final String id;
  final String type;
  String name;
  ui.Image bitmap;
  ui.Image? backBitmap;
  String? duplexMode; // 'SAME_PAGE' | 'BACK_SIDE'
  double widthCm;
  double heightCm;
  int copies;

  bool get isDoc => type == 'DOCUMENT';
}

class PlacedFace {
  PlacedFace({
    required this.item,
    required this.back,
    required this.page,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.order,
  });

  final PmItem item;
  final bool back;
  final int page;
  final double x, y, w, h;
  final int order;
}

class Plan {
  Plan(this.placed, this.totalPages)
      : pageWidth = 21.0,
        pageHeight = 29.7;

  final List<PlacedFace> placed;
  final int totalPages;
  final double pageWidth;
  final double pageHeight;
}

Plan computePlan(List<PmItem> items) {
  const pageWidth = 21.0;
  const pageHeight = 29.7;
  const margin = 0.6;
  const spacing = 0.1;
  const maxX = pageWidth - margin;
  const maxY = pageHeight - margin;
  final placed = <PlacedFace>[];
  int page = 0;
  double x = margin;
  double y = margin;
  double rowHeight = 0;
  int inRow = 0;
  int order = 0;

  final photos = items.where((i) => i.type == 'PHOTO').toList();
  final docs = items.where((i) => i.type == 'DOCUMENT').toList();

  int maxPlacedPage() {
    var m = page;
    for (final p in placed) {
      if (p.page > m) m = p.page;
    }
    return m;
  }

  for (final item in photos) {
    final w = item.widthCm < 1.0 ? 1.0 : item.widthCm;
    final h = item.heightCm < 1.0 ? 1.0 : item.heightCm;
    for (var c = 0; c < item.copies; c++) {
      if (x + w > maxX + 0.01 || (w <= 3.05 && inRow >= 6)) {
        y += rowHeight + spacing;
        x = margin;
        rowHeight = 0;
        inRow = 0;
      }
      if (y + h > maxY + 0.01) {
        page += 1;
        x = margin;
        y = margin;
        rowHeight = 0;
        inRow = 0;
      }
      placed.add(PlacedFace(
        item: item,
        back: false,
        page: page,
        x: x,
        y: y,
        w: w,
        h: h,
        order: order++,
      ));
      inRow += 1;
      rowHeight = rowHeight < h ? h : rowHeight;
      x += w + spacing;
    }
  }

  if (inRow > 0) {
    y += rowHeight + spacing;
    x = margin;
    rowHeight = 0;
    inRow = 0;
  }

  for (final item in docs) {
    final w = item.widthCm < 1.0 ? 1.0 : item.widthCm;
    final h = item.heightCm < 1.0 ? 1.0 : item.heightCm;
    for (var c = 0; c < item.copies; c++) {
      if (y + h > maxY + 0.01) {
        page = maxPlacedPage() + 1;
        x = margin;
        y = margin;
      }
      if (item.duplexMode == 'BACK_SIDE') {
        placed.add(PlacedFace(
            item: item, back: false, page: page, x: margin, y: y, w: w, h: h, order: order++));
        final backPage = page + 1;
        placed.add(PlacedFace(
            item: item,
            back: true,
            page: backPage,
            x: pageWidth - margin - w,
            y: y,
            w: w,
            h: h,
            order: order++));
        y += h + spacing;
      } else if (item.backBitmap != null) {
        placed.add(PlacedFace(
            item: item, back: true, page: page, x: margin, y: y, w: w, h: h, order: order++));
        placed.add(PlacedFace(
            item: item,
            back: false,
            page: page,
            x: pageWidth - margin - w,
            y: y,
            w: w,
            h: h,
            order: order++));
        y += h + spacing;
      } else {
        placed.add(PlacedFace(
            item: item, back: false, page: page, x: margin, y: y, w: w, h: h, order: order++));
        y += h + spacing;
      }
    }
  }

  var totalPages = 0;
  if (placed.isNotEmpty) {
    var max = 0;
    for (final p in placed) {
      if (p.page > max) max = p.page;
    }
    totalPages = max + 1;
  } else {
    totalPages = 1;
  }

  return Plan(placed, totalPages);
}

/// Stable fingerprint of the current page layout (what the file contains) —
/// the same hash idea as the web-built planKey (used for the warm cache).
String planKey(Plan plan) {
  final sb = StringBuffer('v1_${plan.totalPages}_');
  plan.placed.forEach((p) {
    sb
      ..write(p.item.id)
      ..write('_')
      ..write(p.back ? 'b' : 'f')
      ..write('_')
      ..write(p.page)
      ..write('_')
      ..write((p.x * 1000).round())
      ..write('_')
      ..write((p.y * 1000).round())
      ..write('-');
  });
  return sb.toString();
}
