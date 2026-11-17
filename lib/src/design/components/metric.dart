import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

/// The three numeric tiers allowed for a result. Values never shrink below
/// `metricMd` (24) at large text sizes.
enum MetricValueScale { display, metricLg, metricMd, metricSm }

/// Numeric result with its unit, rendered as one `TextSpan` per part and
/// measured before drawing so 200% text reflows instead of clipping.
class MileafNumber extends StatelessWidget {
  const MileafNumber({
    super.key,
    this.value,
    this.unit,
    this.scale = MetricValueScale.metricMd,
    this.onHero = false,
    this.color,
    this.unitColor,
    this.alignEnd = false,
  });

  /// Already grouped/formatted value; null renders an em dash.
  final String? value;
  final String? unit;
  final MetricValueScale scale;
  final bool onHero;
  final Color? color;
  final Color? unitColor;
  final bool alignEnd;

  List<TextStyle> _tiers(BuildContext context) {
    final type = context.type;
    // A missing value must not become a giant em-dash bar in display size.
    if (value == null) return [type.metricMd];
    final all = switch (scale) {
      MetricValueScale.display => [type.display, type.metricLg, type.metricMd],
      MetricValueScale.metricLg => [type.metricLg, type.metricMd],
      MetricValueScale.metricMd => [type.metricMd],
      MetricValueScale.metricSm => [type.metricSm],
    };
    return all;
  }

  TextStyle _unitStyle(BuildContext context) => switch (scale) {
    MetricValueScale.display => context.type.body,
    _ => context.type.subheadline,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final numberColor = color ?? (onHero ? colors.heroText : colors.text);
    final resolvedUnit = unit == null || unit!.isEmpty ? null : unit;
    final text = value ?? '—';
    final unitStyle = _unitStyle(context).copyWith(
      color: unitColor ?? (onHero ? colors.heroMuted : colors.textSecondary),
    );
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        // R21.5：数值与单位永不拆行。放不下时由网格先改两列、再改一列；
        // 这里只保留单行，在最窄一档自然截断，不再把单位折到第二行。
        var chosen = _tiers(context).last;
        for (final tier in _tiers(context)) {
          final candidate = tier.copyWith(color: numberColor);
          if (!maxWidth.isFinite) {
            chosen = candidate;
            break;
          }
          final painter = TextPainter(
            text: TextSpan(
              text: text,
              style: candidate,
              children: [
                if (resolvedUnit != null)
                  TextSpan(text: ' $resolvedUnit', style: unitStyle),
              ],
            ),
            textDirection: TextDirection.ltr,
            textScaler: textScaler,
            maxLines: 1,
          )..layout();
          final fits = painter.width <= maxWidth + .5;
          painter.dispose();
          chosen = candidate;
          if (fits) break;
        }
        return Text.rich(
          TextSpan(
            text: text,
            style: chosen,
            children: [
              if (resolvedUnit != null)
                TextSpan(text: ' $resolvedUnit', style: unitStyle),
            ],
          ),
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          maxLines: 1,
        );
      },
    );
  }
}

/// label → value + unit → note, with an optional trailing widget (delta).
class MetricBlock extends StatelessWidget {
  const MetricBlock({
    super.key,
    this.label,
    this.value,
    this.unit,
    this.note,
    this.trailing,
    this.scale = MetricValueScale.metricMd,
    this.onHero = false,
    this.onTap,
    this.selected = false,
    this.semanticLabel,
    this.alignEnd = false,
  });

  final String? label;
  final String? value;
  final String? unit;
  final String? note;
  final Widget? trailing;
  final MetricValueScale scale;
  final bool onHero;
  final VoidCallback? onTap;
  final bool selected;
  final String? semanticLabel;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final labelColor = onHero ? colors.heroFaint : colors.textFaint;
    final noteColor = onHero ? colors.heroMuted : colors.textMuted;
    final cross = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final number = MileafNumber(
      value: value,
      unit: unit,
      scale: scale,
      onHero: onHero,
      alignEnd: alignEnd,
    );
    final text = Column(
      crossAxisAlignment: cross,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: type.label.copyWith(color: labelColor),
          ),
          const SizedBox(height: MileafSpace.inline6),
        ],
        number,
        if (note != null) ...[
          const SizedBox(height: MileafSpace.inline6),
          Text(
            note!,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: type.micro.copyWith(color: noteColor),
          ),
        ],
      ],
    );
    Widget content;
    if (trailing == null) {
      content = text;
    } else if (MileafLayout.largeText(context)) {
      content = Column(
        crossAxisAlignment: cross,
        mainAxisSize: MainAxisSize.min,
        children: [
          text,
          const SizedBox(height: MileafSpace.s8),
          Align(
            alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
            child: trailing,
          ),
        ],
      );
    } else {
      content = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: text),
          const SizedBox(width: MileafSpace.s12),
          trailing!,
        ],
      );
    }
    final semantics =
        semanticLabel ??
        '${label == null ? '' : '$label '}${value ?? '—'}${unit == null ? '' : ' $unit'}';
    return Semantics(
      container: true,
      button: onTap != null,
      enabled: onTap != null,
      selected: onTap == null ? null : selected,
      label: semantics,
      excludeSemantics: true,
      onTap: onTap,
      child: onTap == null
          ? content
          : Material(
              color: selected ? colors.accentSoft : Colors.transparent,
              borderRadius: MileafRadius.smAll,
              child: InkWell(
                onTap: onTap,
                borderRadius: MileafRadius.smAll,
                highlightColor: colors.accentSoft,
                child: Padding(
                  padding: const EdgeInsets.all(MileafSpace.s8),
                  child: content,
                ),
              ),
            ),
    );
  }
}

/// 数值网格（R21.5）。
///
/// 两列网格可用 metricMd，三列网格只用 metricSm；数值与单位放不下时网格先改
/// 两列、再改一列（按最小格宽收列），大字下直接单列堆叠。
/// Children keep their natural height; no card and no equal-height stretching.
class MetricGrid extends StatelessWidget {
  const MetricGrid({
    super.key,
    required this.children,
    this.columns = 2,
    this.spacing = MileafSpace.s12,
  });

  final List<Widget> children;

  /// R21.5：三列网格只用 metricSm；两列网格可用 metricMd。
  final int columns;

  /// R24：卡片网格格与格之间 12。
  final double spacing;

  /// R21.5 收列阈值：一格至少容纳「1,198.6 km」这类 metricSm 数值加单位。
  /// 低于该宽度时先改两列、再改一列，而不是把单位折到第二行或裁掉数值。
  static const double minCellWidth = 100;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final maxWidth = constraints.maxWidth;
      if (!maxWidth.isFinite) {
        return Wrap(spacing: spacing, runSpacing: spacing, children: children);
      }
      final count = children.isEmpty ? 1 : children.length;
      final fit = (maxWidth + spacing) ~/ (minCellWidth + spacing);
      final effective = MileafLayout.largeText(context)
          ? 1
          : math.min(columns, math.min(count, math.max(1, fit)));
      final width = (maxWidth - (effective - 1) * spacing) / effective;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

/// Comparison direction: arrow + value + reference label, never red/green.
class MetricDelta extends StatelessWidget {
  const MetricDelta({
    super.key,
    required this.text,
    this.label,
    this.up,
    this.onHero = false,
  });

  final String text;
  final String? label;

  /// `true` up, `false` down, `null` no arrow (e.g. “与参照持平”).
  final bool? up;
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final arrow = up == null ? null : (up! ? '↑' : '↓');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (arrow != null) ...[
              Text(
                arrow,
                style: type.body.copyWith(
                  color: colors.accentHero,
                  fontWeight: MileafType.weightSemiBold,
                ),
              ),
              const SizedBox(width: MileafSpace.s4),
            ],
            Text(
              text,
              style: type.body.copyWith(
                color: onHero ? colors.heroText : colors.text,
                fontWeight: MileafType.weightSemiBold,
              ),
            ),
          ],
        ),
        if (label != null) ...[
          const SizedBox(height: MileafSpace.inline2),
          Text(
            label!,
            textAlign: TextAlign.end,
            style: type.micro.copyWith(
              color: onHero ? colors.heroMuted : colors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
