import 'package:flutter/material.dart';

import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

/// The three numeric tiers allowed for a result. Values never shrink below
/// `metricMd` (24) at large text sizes.
enum MetricValueScale { display, metricLg, metricMd }

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
    final all = switch (scale) {
      MetricValueScale.display => [type.display, type.metricLg, type.metricMd],
      MetricValueScale.metricLg => [type.metricLg, type.metricMd],
      MetricValueScale.metricMd => [type.metricMd],
    };
    return all;
  }

  TextStyle _unitStyle(BuildContext context) => switch (scale) {
    MetricValueScale.display => context.type.body,
    _ => context.type.label,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final numberColor = color ?? (onHero ? colors.heroText : colors.text);
    final resolvedUnit = unit == null || unit!.isEmpty ? null : unit;
    final text = value ?? '—';
    final unitStyle = _unitStyle(context).copyWith(
      color: unitColor ?? (onHero ? colors.heroFaint : colors.textFaint),
    );
    final textScaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        TextStyle? chosen;
        bool singleLine = false;
        for (final tier in _tiers(context)) {
          final numberStyle = tier.copyWith(color: numberColor);
          if (maxWidth.isFinite) {
            final painter = TextPainter(
              text: TextSpan(
                text: text,
                style: numberStyle,
                children: [
                  if (resolvedUnit != null)
                    TextSpan(
                      text: ' $resolvedUnit',
                      style: unitStyle,
                    ),
                ],
              ),
              textDirection: TextDirection.ltr,
              textScaler: textScaler,
              maxLines: 1,
            )..layout();
            final fits = painter.width <= maxWidth + .5;
            painter.dispose();
            if (fits) {
              chosen = numberStyle;
              singleLine = true;
              break;
            }
          } else {
            chosen = numberStyle;
            singleLine = true;
            break;
          }
          chosen = numberStyle;
        }
        final numberStyle = chosen ?? _tiers(context).last.copyWith(
          color: numberColor,
        );
        final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
        final textAlign = alignEnd ? TextAlign.end : TextAlign.start;
        if (singleLine) {
          return Text.rich(
            TextSpan(
              text: text,
              style: numberStyle,
              children: [
                if (resolvedUnit != null)
                  TextSpan(text: ' $resolvedUnit', style: unitStyle),
              ],
            ),
            textAlign: textAlign,
          );
        }
        return Column(
          crossAxisAlignment: align,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: numberStyle, textAlign: textAlign),
            if (resolvedUnit != null) ...[
              const SizedBox(height: 2),
              Text(resolvedUnit, style: unitStyle, textAlign: textAlign),
            ],
          ],
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
                highlightColor: colors.accent.withValues(alpha: .12),
                child: Padding(
                  padding: const EdgeInsets.all(MileafSpace.s8),
                  child: content,
                ),
              ),
            ),
    );
  }
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
          const SizedBox(height: 2),
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
