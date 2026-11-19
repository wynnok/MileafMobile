import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout.dart';
import '../motion.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

/// The three numeric tiers allowed for a result. Values never shrink below
/// `metricMd` (24) at large text sizes.
enum MetricValueScale { display, metricLg, metricMd, metricSm }

/// Numeric result with its unit, rendered as one `TextSpan` per part and
/// measured before drawing so 200% text reflows instead of clipping.
///
/// MG08/PD13：数值内容变更统一 120ms 交叉淡化（M08 扩展为「任何焦点值内容
/// 变更」）；`transitionBuilder` 只动 opacity，`layoutBuilder` 把新旧值叠在
/// 同一 Stack 里按原对齐方向对齐——高度取两侧最大值，不跳高度。交叉淡化期间
/// 旧值经 `ExcludeSemantics` 移出语义树，同一时刻只有一个数值可被朗读。
/// 减少动效时长归零，内容直接切换。
class MileafNumber extends StatefulWidget {
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

  @override
  State<MileafNumber> createState() => _MileafNumberState();
}

class _MileafNumberState extends State<MileafNumber> {
  List<TextStyle> _tiers(BuildContext context) {
    final type = context.type;
    // A missing value must not become a giant em-dash bar in display size.
    if (widget.value == null) return [type.metricMd];
    final all = switch (widget.scale) {
      MetricValueScale.display => [type.display, type.metricLg, type.metricMd],
      MetricValueScale.metricLg => [type.metricLg, type.metricMd],
      MetricValueScale.metricMd => [type.metricMd],
      MetricValueScale.metricSm => [type.metricSm],
    };
    return all;
  }

  TextStyle _unitStyle(BuildContext context) => switch (widget.scale) {
    MetricValueScale.display => context.type.body,
    _ => context.type.subheadline,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final numberColor =
        widget.color ?? (widget.onHero ? colors.heroText : colors.text);
    final resolvedUnit = widget.unit == null || widget.unit!.isEmpty
        ? null
        : widget.unit;
    final text = widget.value ?? '—';
    final unitStyle = _unitStyle(context).copyWith(
      color:
          widget.unitColor ??
          (widget.onHero ? colors.heroMuted : colors.textSecondary),
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
        return AnimatedSwitcher(
          // M08/PD13：焦点值内容变更 120ms 交叉淡化；减动效归零后直接切换。
          duration: MileafLayout.motion(context, MileafDurations.value),
          switchInCurve: MileafCurves.fade,
          switchOutCurve: MileafCurves.fade,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: widget.alignEnd
                ? Alignment.centerRight
                : Alignment.centerLeft,
            children: [
              // 当前值排首位：widget 遍历（find/语义）永远先命中新值。
              ?currentChild,
              // 切换期间旧值移出语义树：读屏单一来源（MG08）。
              for (final child in previousChildren)
                ExcludeSemantics(child: child),
            ],
          ),
          child: Text.rich(
            // 内容不变不触发动画；内容变更才换 key 走淡化。
            key: ValueKey('$text|$resolvedUnit'),
            TextSpan(
              text: text,
              style: chosen,
              children: [
                if (resolvedUnit != null)
                  TextSpan(text: ' $resolvedUnit', style: unitStyle),
              ],
            ),
            textAlign: widget.alignEnd ? TextAlign.end : TextAlign.start,
            maxLines: 1,
          ),
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
    this.hue,
  });

  /// CL12：这一格的数据身份色相。给了就把**读数**染成 `hue.strong`（浅色
  /// 5.90:1 / 深色 7.42:1，正文门槛之上），标签与旁注保持中性——彩色只落在
  /// 数字上，网格的 2×2 排布与字号阶梯都不动（CL15）。
  final MileafHue? hue;

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
    // R23.1（apple-polish）：功能文字只有 text/textSecondary 两级；标签是
    // 字段名，不再用 textFaint（只留占位/禁用/装饰）。hero 卡维持 heroFaint。
    final labelColor = onHero ? colors.heroFaint : colors.textSecondary;
    final noteColor = onHero ? colors.heroMuted : colors.textMuted;
    final cross = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final number = MileafNumber(
      value: value,
      unit: unit,
      scale: scale,
      onHero: onHero,
      alignEnd: alignEnd,
      // CL08：缺失值本身就是「不知道」，不属于该域的数据——不上色。
      // 这条放在组件里而不是 20 个调用点：调用方传 hue 是「这一格是什么数据」，
      // 有没有数据要由组件自己判。
      //
      // CL55（ADR 0017）：读数按字号分档取色。display/metricLg/metricMd 是
      // 40/32/24 号，落在 WCAG「大文本」里，门槛 3:1 而不是 4.5:1——这三个档
      // 取 solid（3.55:1，饱和度与图表线同档），比原来的 strong 明显更亮；
      // metricSm（20 号，600 重）仍取 strong，保守过正文门槛。
      color: value == null
          ? null
          : (scale == MetricValueScale.metricSm
                ? hue?.strong(colors)
                : hue?.solid(colors)),
    );
    final text = Column(
      crossAxisAlignment: cross,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: type.subheadline.copyWith(color: labelColor),
          ),
          const SizedBox(height: MileafSpace.s4),
        ],
        number,
        if (note != null) ...[
          const SizedBox(height: MileafSpace.s4),
          Text(
            note!,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: type.footnote.copyWith(color: noteColor),
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
            style: type.footnote.copyWith(
              color: onHero ? colors.heroMuted : colors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
