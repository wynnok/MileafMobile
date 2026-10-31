import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'geo.dart';
import 'map_platform.dart';
import 'map_scene.dart';

/// Pure-Flutter fallback. It is explicitly a sketch, never a fake basemap.
class SketchPlatform implements MapPlatform {
  const SketchPlatform();
  @override
  String get providerName => '路线示意';
  @override
  bool get supported => true;
  @override
  Widget build(
    MapScene scene,
    MapCallbacks callbacks,
    MapViewController controller,
  ) => _SketchReady(scene: scene, callbacks: callbacks);
}

class _SketchReady extends StatefulWidget {
  const _SketchReady({required this.scene, required this.callbacks});
  final MapScene scene;
  final MapCallbacks callbacks;
  @override
  State<_SketchReady> createState() => _SketchReadyState();
}

class _SketchReadyState extends State<_SketchReady> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.callbacks.onLoaded();
    });
  }

  @override
  Widget build(BuildContext context) => RouteSketch(scene: widget.scene);
}

class RouteSketch extends StatelessWidget {
  const RouteSketch({super.key, required this.scene});
  final MapScene scene;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (scene.isEmpty) {
      return ColoredBox(
        color: theme.colorScheme.surfaceContainerLow,
        child: Center(
          child: Text(
            '没有有效轨迹坐标',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return Semantics(
      label: '路线示意，${scene.pointCount} 个有效采样点',
      child: ExcludeSemantics(
        child: ColoredBox(
          color: theme.colorScheme.surfaceContainerLow,
          child: CustomPaint(
            painter: _SketchPainter(
              scene,
              line: theme.colorScheme.primary,
              start: theme.colorScheme.primary,
              end: theme.colorScheme.onSurface,
              selected: theme.colorScheme.tertiary,
              grid: theme.colorScheme.outlineVariant,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _SketchPainter extends CustomPainter {
  _SketchPainter(
    this.scene, {
    required this.line,
    required this.start,
    required this.end,
    required this.selected,
    required this.grid,
  });
  final MapScene scene;
  final Color line, start, end, selected, grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _paintGrid(canvas, size);
    final visible = scene.visible;
    if (visible.isEmpty) return;
    var minLat = visible.first.lat, maxLat = minLat;
    var minLon = visible.first.lon, maxLon = minLon;
    for (final p in visible) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLon = math.min(minLon, p.lon);
      maxLon = math.max(maxLon, p.lon);
    }
    final single =
        (maxLat - minLat).abs() < 1e-9 && (maxLon - minLon).abs() < 1e-9;
    final latSpan = math.max(maxLat - minLat, 1e-6);
    final lonSpan = math.max(maxLon - minLon, 1e-6);
    const pad = 26.0;
    final w = math.max(size.width - pad * 2, 1.0);
    final h = math.max(size.height - pad * 2, 1.0);
    Offset project(Wgs84Point p) => single
        ? Offset(size.width / 2, size.height / 2)
        : Offset(
            pad + (p.lon - minLon) / lonSpan * w,
            pad + (maxLat - p.lat) / latSpan * h,
          );

    final linePaint = Paint()
      ..color = line.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (scene.pointCount == 1) {
      canvas.drawCircle(project(visible.first), 5, Paint()..color = line);
    } else {
      for (final part in scene.segments) {
        if (part.length < 2) continue;
        final path = Path()
          ..moveTo(project(part.first).dx, project(part.first).dy);
        for (final point in part.skip(1)) {
          final offset = project(point);
          path.lineTo(offset.dx, offset.dy);
        }
        canvas.drawPath(path, linePaint);
      }
    }
    void dot(Wgs84Point? point, Color color, double radius) {
      if (point == null) return;
      final offset = project(point);
      canvas.drawCircle(
        offset,
        radius + 2,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
      canvas.drawCircle(offset, radius, Paint()..color = color);
    }

    dot(scene.start, start, 5);
    dot(scene.end, end, 5);
    dot(scene.selected, selected, 4.5);
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = grid.withValues(alpha: 0.45)
      ..strokeWidth = 0.6;
    const step = 28.0;
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SketchPainter old) =>
      old.scene != scene || old.line != line || old.selected != selected;
}
