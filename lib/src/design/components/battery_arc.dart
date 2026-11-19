import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

/// 88px SOC arc (72 at large text): 2.5px stroke, 10% track, round caps.
///
/// 环内只放数值（含单位）：标签移到环外的一句说明，环里不再挤「值 + 单位 +
/// 标签」三行（R29）。[start] turns the same arc into an interval (18→82)
/// without pretending to be a 0→82 progress bar.
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
    this.hue,
  });

  final num? level;
  final num? start;
  final String label;
  final double? size;
  final bool onHero;
  final bool showLabel;
  final String? semanticsLabel;

  /// CL01/CL02：弧前景（数据图形）的语义色相。传了就取 `hue.solid`；缺省仍
  /// 走 `accent`（hero 内 `accentHero`），与改造前像素等价。
  ///
  /// 轨道**不**跟随色相：它仍是原有的 `trackOpacity` 低透明度底（CL02 的
  /// 次级元素），环与轨道之间因此始终是「一个数据色 + 一层洗色」的关系。
  final MileafHue? hue;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final Size resolved = Size.square(
      size ??
          (MileafLayout.largeText(context)
              ? MileafBatteryMetrics.largeTextSize
              : MileafBatteryMetrics.size),
    );
    final arcColor =
        hue?.solid(colors) ?? (onHero ? colors.accentHero : colors.accent);
    final trackColor = (onHero ? colors.heroText : colors.accent).withValues(
      alpha: MileafBatteryMetrics.trackOpacity,
    );
    final semantics =
        semanticsLabel ??
        (start == null
            ? '电池电量 ${level == null ? '未知' : '${level!.toStringAsFixed(0)}%'}'
            : '电量区间 ${start == null ? '未知' : '${start!.toStringAsFixed(0)}%'} 至 '
                  '${level == null ? '未知' : '${level!.toStringAsFixed(0)}%'}，尺度0至100%');
    final large = MileafLayout.largeText(context);
    // 大字下环内放不下读数，数值移到环外（沿既有行为）；标签只在小字出现。
    final separate = large && showLabel;
    final arc = SizedBox.fromSize(
      size: resolved,
      child: CustomPaint(
        painter: _BatteryArcPainter(
          level: level,
          start: start,
          arc: arcColor,
          track: trackColor,
        ),
        child: separate
            ? null
            : Center(
                child: _ArcValue(
                  level: level,
                  onHero: onHero,
                  diameter: resolved.width,
                ),
              ),
      ),
    );
    final labelText = Text(
      label,
      textAlign: TextAlign.center,
      style: type.subheadline.copyWith(
        color: onHero ? colors.heroMuted : colors.textSecondary,
      ),
    );
    return Semantics(
      container: true,
      label: semantics,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          arc,
          if (separate)
            // CP03：百分号紧贴数值；数值单独成 Text，读屏与测试都以它为止。
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  level == null ? '—' : level!.toStringAsFixed(0),
                  style: type.metricMd.copyWith(
                    color: onHero ? colors.heroText : colors.text,
                  ),
                ),
                if (level != null)
                  Text(
                    '%',
                    style: type.subheadline.copyWith(
                      color: onHero ? colors.heroMuted : colors.textSecondary,
                    ),
                  ),
              ],
            ),
          if (showLabel && !large) ...[
            const SizedBox(height: MileafSpace.s4),
            labelText,
          ],
        ],
      ),
    );
  }
}

/// 环内读数：只有数值与单位（R22：单位 subheadline textSecondary）。
class _ArcValue extends StatelessWidget {
  const _ArcValue({
    required this.level,
    required this.onHero,
    required this.diameter,
  });

  final num? level;
  final bool onHero;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final valueColor = onHero ? colors.heroText : colors.text;
    final unitColor = onHero ? colors.heroMuted : colors.textSecondary;
    final maxWidth = diameter * .62;
    final valueText = level == null ? '—' : level!.toStringAsFixed(0);
    final valueStyle = type.metricMd.copyWith(
      fontSize: MileafBatteryMetrics.valueSize,
      height: MileafBatteryMetrics.valueHeight / MileafBatteryMetrics.valueSize,
      color: valueColor,
    );
    // 回落到小一号的数值（0.85×），否则 smallStyle 与 valueStyle 同宽，
    // 这条回退分支永远走不到。
    final smallStyle = valueStyle.copyWith(
      fontSize: MileafBatteryMetrics.valueSize * .85,
      height: 1.2,
    );
    final unitStyle = type.subheadline.copyWith(color: unitColor);
    // 单位挤不下时落到数值下方，用 R22 的紧凑标注角色（caption）而不是正文
    // 角色：环内是密集区，subheadline 在 200% 会把圆心顶破。
    final wrappedUnitStyle = type.caption.copyWith(color: unitColor);
    final scaler = MediaQuery.textScalerOf(context);
    bool fits(TextStyle style, {required bool unit}) {
      final painter = TextPainter(
        text: TextSpan(
          text: valueText,
          style: style,
          children: [if (unit) TextSpan(text: '%', style: unitStyle)],
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final ok = painter.width <= maxWidth;
      painter.dispose();
      return ok;
    }

    double heightOf(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    var style = valueStyle;
    var withUnit = level != null && fits(valueStyle, unit: true);
    if (!withUnit && level != null) {
      // R29/D-AP08-05：环内只放数值与紧贴的 %。数值 + % 放不下时，先试
      // 缩一号的数值保住紧贴单位，而不是把 % 挪到下一行。
      if (fits(smallStyle, unit: true)) {
        style = smallStyle;
        withUnit = true;
      } else if (!fits(valueStyle, unit: false)) {
        style = smallStyle;
        withUnit = fits(smallStyle, unit: true);
      }
    }
    // 圆心的内圆高度：数值 + 换行单位放不下时宁可省掉单位行，也绝不让圆心
    // 溢出（单位仍由语义标签朗读）。
    final innerHeight = diameter - MileafBatteryMetrics.stroke * 2;
    final unitBelow =
        !withUnit &&
        level != null &&
        heightOf(valueText, style) +
                MileafSpace.inline2 +
                heightOf('%', wrappedUnitStyle) <=
            innerHeight;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // CP03：百分号紧贴数值（68%）。数值与单位分成两个 Text，
        // 让 battery_finder 仍以数值本身为键。
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(valueText, style: style),
            if (withUnit) Text('%', style: unitStyle),
          ],
        ),
        if (unitBelow)
          Text('%', textAlign: TextAlign.center, style: wrappedUnitStyle),
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
    canvas.drawArc(
      rect,
      -math.pi / 2 + lower / 100 * math.pi * 2,
      sweep,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BatteryArcPainter old) =>
      old.level != level ||
      old.start != start ||
      old.arc != arc ||
      old.track != track;
}
