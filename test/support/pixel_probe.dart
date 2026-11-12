import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pixels one `RepaintBoundary` actually painted, sampled 1:1 with logical
/// coordinates so a test can judge the final drawing instead of a token.
class PixelProbe {
  PixelProbe._(this.width, this.height, this._rgba);

  final int width;
  final int height;
  final Uint8List _rgba;

  /// Raw RGBA rows, for comparing two captures of the same content.
  Uint8List get bytes => _rgba;

  Color at(int x, int y) {
    assert(x >= 0 && x < width && y >= 0 && y < height, '(x, y) = ($x, $y)');
    final i = (y * width + x) * 4;
    return Color.fromARGB(
      _rgba[i + 3],
      _rgba[i],
      _rgba[i + 1],
      _rgba[i + 2],
    );
  }

  /// How many pixels equal [color] within [tolerance] per channel.
  int count(
    Color color, {
    int tolerance = 1,
    bool Function(int x, int y)? where,
  }) {
    var found = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (where != null && !where(x, y)) continue;
        if (_matches(at(x, y), color, tolerance)) found++;
      }
    }
    return found;
  }

  /// Pixels equal to [color], as `(x, y)` pairs.
  List<Offset> find(
    Color color, {
    int tolerance = 1,
    bool Function(int x, int y)? where,
  }) => [
    for (var y = 0; y < height; y++)
      for (var x = 0; x < width; x++)
        if ((where == null || where(x, y)) && _matches(at(x, y), color, tolerance))
          Offset(x.toDouble(), y.toDouble()),
  ];

  /// Contiguous runs of x columns that contain at least one pixel of [color].
  ///
  /// Bars and stems are separated horizontally, so one run means one drawn
  /// data mark; a merged run means a mark is missing or two marks touch.
  List<({int from, int to})> columns(
    Color color, {
    int tolerance = 1,
  }) {
    final seen = <int>{};
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (_matches(at(x, y), color, tolerance)) seen.add(x);
      }
    }
    final sorted = seen.toList()..sort();
    final runs = <({int from, int to})>[];
    for (final x in sorted) {
      if (runs.isNotEmpty && x == runs.last.to + 1) {
        runs[runs.length - 1] = (from: runs.last.from, to: x);
      } else {
        runs.add((from: x, to: x));
      }
    }
    return runs;
  }

  /// Bounding box of every pixel of [color], or `null` when none is painted.
  Rect? bounds(
    Color color, {
    int tolerance = 1,
    bool Function(int x, int y)? where,
  }) {
    final hits = find(color, tolerance: tolerance, where: where);
    if (hits.isEmpty) return null;
    var left = hits.first.dx, right = hits.first.dx;
    var top = hits.first.dy, bottom = hits.first.dy;
    for (final hit in hits) {
      if (hit.dx < left) left = hit.dx;
      if (hit.dx > right) right = hit.dx;
      if (hit.dy < top) top = hit.dy;
      if (hit.dy > bottom) bottom = hit.dy;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Bounding box of [color] inside the x band `[from, to]`.
  Rect? columnBounds(Color color, int from, int to, {int tolerance = 1}) =>
      bounds(color, tolerance: tolerance, where: (x, _) => x >= from && x <= to);

  bool _matches(Color a, Color b, int tolerance) => (a.r * 255 - b.r * 255).abs() <= tolerance &&
      (a.g * 255 - b.g * 255).abs() <= tolerance &&
      (a.b * 255 - b.b * 255).abs() <= tolerance;
}

/// Rasterises [boundary] and returns its pixels at one pixel per logical pixel.
Future<PixelProbe> capturePixels(
  WidgetTester tester,
  Finder boundary, {
  double pixelRatio = 1,
}) async {
  final render = tester.renderObject<RenderRepaintBoundary>(boundary);
  late PixelProbe probe;
  await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      probe = PixelProbe._(
        image.width,
        image.height,
        data!.buffer.asUint8List(),
      );
    } finally {
      image.dispose();
    }
  });
  return probe;
}
