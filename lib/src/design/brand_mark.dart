import 'package:flutter/material.dart';

import 'semantic.dart';
import 'tokens.dart';
import 'typography.dart';

/// 03「M 径」brand symbol: a 24-grid M whose right leg becomes a route that
/// ends in a solid dot.
///
/// Single colour, 1.5px stroke, no gradient, no shadow, no second colour.
/// Legible down to 18px because the endpoint stays solid.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = MileafIconMetrics.brandDefault,
    this.color,
    this.semanticLabel = '行笺',
  });

  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? context.colors.accent;
    final mark = CustomPaint(
      size: Size.square(size),
      painter: _BrandMarkPainter(resolved),
    );
    if (semanticLabel == null) return mark;
    return Semantics(label: semanticLabel, image: true, child: mark);
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / MileafIconMetrics.grid;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = MileafIconMetrics.stroke * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Offset p(double x, double y) => Offset(x * scale, y * scale);

    final path = Path()
      ..moveTo(3.0 * scale, 19.4 * scale)
      ..lineTo(3.0 * scale, 4.6 * scale)
      ..lineTo(9.9 * scale, 13.0 * scale)
      ..lineTo(16.4 * scale, 4.6 * scale)
      ..lineTo(16.4 * scale, 16.6 * scale)
      ..cubicTo(
        16.4 * scale,
        18.4 * scale,
        17.5 * scale,
        18.2 * scale,
        18.7 * scale,
        16.6 * scale,
      )
      ..lineTo(20.2 * scale, 12.8 * scale);
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      p(21.0, 11.8),
      MileafIconMetrics.brandDotDiameter / 2 * scale,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _BrandMarkPainter old) => old.color != color;
}

/// `行笺` + `MILEAF` lockup for login/connection and other brand surfaces.
class MileafWordmark extends StatelessWidget {
  const MileafWordmark({
    super.key,
    this.markSize = 28,
    this.color,
    this.showLatin = true,
  });

  final double markSize;
  final Color? color;
  final bool showLatin;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? context.colors.accent;
    final word = context.type.title.copyWith(
      fontSize: MileafBrand.wordSize,
      height: 1.1,
      letterSpacing: MileafBrand.wordTracking * MileafBrand.wordSize,
      color: resolved,
      fontWeight: MileafType.weightSemiBold,
    );
    final latin = context.type.micro.copyWith(
      fontSize: MileafBrand.latinSize,
      height: 1.1,
      letterSpacing: MileafBrand.latinTracking * MileafBrand.latinSize,
      color: resolved,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(size: markSize, color: resolved, semanticLabel: null),
        const SizedBox(width: MileafBrand.gap),
        Text('行笺', style: word),
        if (showLatin) ...[
          const SizedBox(width: MileafBrand.latinGap),
          Text('MILEAF', style: latin),
        ],
      ],
    );
  }
}
