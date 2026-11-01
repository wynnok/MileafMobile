import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

/// 88px SOC arc (72 at large text): 2.5px stroke, 10% track, round caps.
///
/// `start` turns the same arc into an interval (18→82) without pretending to
/// be a 0→82 progress bar.
class BatteryArc extends StatelessWidget {
  const BatteryArc({
    super.key,
    required this.level,
    this.start,
    this.label = '电量',
    this.size,
    this.onHero = false,
    this.showLabel = true,
    this.semanticsLabel,
  });

  final num? level;
  final num? start;
  final String label;
  final double? size;
  final bool onHero;
  final bool showLabel;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final Size resolved = Size.square(
      size ??
          (MileafLayout.largeText(context)
              ? MileafBatteryMetrics.largeTextSize
              : MileafBatteryMetrics.size),
    );
    final arcColor = onHero ? colors.accentHero : colors.accent;
    final trackColor = (onHero ? colors.heroText : colors.accent).withValues(
      alpha: MileafBatteryMetrics.trackOpacity,
    );
    final semantics =
        semanticsLabel ??
        (start == null
            ? '电池电量 ${level == null ? '未知' : '${level!.toStringAsFixed(0)}%'}'
            : '电量区间 ${start == null ? '未知' : '${start!.toStringAsFixed(0)}%'} 至 '
                  '${level == null ? '未知' : '${level!.toStringAsFixed(0)}%'}，尺度0至100%');
    return Semantics(
      container: true,
      label: semantics,
      excludeSemantics: true,
      child: SizedBox.fromSize(
        size: resolved,
        child: CustomPaint(
          painter: _BatteryArcPainter(
            level: level,
            start: start,
            arc: arcColor,
            track: trackColor,
          ),
          child: Center(
            child: _ArcCenter(
              level: level,
              label: label,
              showLabel: showLabel,
              onHero: onHero,
              diameter: resolved.width,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcCenter extends StatelessWidget {
  const _ArcCenter({
    required this.level,
    required this.label,
    required this.showLabel,
    required this.onHero,
    required this.diameter,
  });

  final num? level;
  final String label;
  final bool showLabel;
  final bool onHero;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final valueColor = onHero ? colors.heroText : colors.text;
    final unitColor = onHero ? colors.heroFaint : colors.textFaint;
    final maxWidth = diameter * .62;
    final valueText = level == null ? '—' : level!.toStringAsFixed(0);
    final valueStyle = type.metricMd.copyWith(
      fontSize: MileafBatteryMetrics.valueSize,
      height: MileafBatteryMetrics.valueHeight / MileafBatteryMetrics.valueSize,
      color: valueColor,
    );
    final smallStyle = valueStyle.copyWith(
      fontSize: MileafBatteryMetrics.labelSize * 2,
      height: 1.2,
    );
    final unitStyle = type.micro.copyWith(color: unitColor);
    final scaler = MediaQuery.textScalerOf(context);
    bool fits(TextStyle style, {required bool unit}) {
      final painter = TextPainter(
        text: TextSpan(
          text: valueText,
          style: style,
          children: [
            if (unit) TextSpan(text: ' %', style: unitStyle),
          ],
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final ok = painter.width <= maxWidth;
      painter.dispose();
      return ok;
    }

    var style = valueStyle;
    var withUnit = level != null && fits(valueStyle, unit: true);
    if (!withUnit && !fits(valueStyle, unit: false)) {
      style = smallStyle;
      withUnit = level != null && fits(smallStyle, unit: true);
    }
    final show = showLabel && !MileafLayout.largeText(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            text: valueText,
            style: style,
            children: [
              if (withUnit) TextSpan(text: ' %', style: unitStyle),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        // The unit never disappears; it moves under the value when the arc is
        // too narrow (200% uses the 72px arc).
        if (!withUnit && level != null)
          Text('%', textAlign: TextAlign.center, style: unitStyle),
        if (show) ...[
          Text(
            label,
            textAlign: TextAlign.center,
            style: unitStyle,
          ),
        ],
      ],
    );
  }
}

class _BatteryArcPainter extends CustomPainter {
  const _BatteryArcPainter({
    required this.level,
    required this.start,
    required this.arc,
    required this.track,
  });

  final num? level;
  final num? start;
  final Color arc;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = MileafBatteryMetrics.stroke;
    final radius = (size.shortestSide - stroke) / 2;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);
    if (level == null) return;
    final from = (start ?? 0).toDouble().clamp(0, 100).toDouble();
    final to = level!.toDouble().clamp(0, 100).toDouble();
    final lower = math.min(from, to);
    final upper = math.max(from, to);
    final sweep = (upper - lower) / 100 * math.pi * 2;
    if (sweep <= 0) return;
    final arcPaint = Paint()
      ..color = arc
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2 + lower / 100 * math.pi * 2, sweep, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _BatteryArcPainter old) =>
      old.level != level ||
      old.start != start ||
      old.arc != arc ||
      old.track != track;
}
