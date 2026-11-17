import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../icons.dart';
import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';
import 'disclosure.dart';

/// R30.2 「关于这些数据」的五类说明分组（PD08）。
///
/// 顺序固定；缺哪类就不出现。分类标题用分组标题（R22 subheadline 500）。
enum DataNoteCategory { caliber, records, time, source, technical }

/// R30.2 五类说明分组的人话标题（固定文案；缺类不出现）。
String dataNoteLabel(DataNoteCategory category) => switch (category) {
  DataNoteCategory.caliber => '口径与估算',
  DataNoteCategory.records => '记录与缺失',
  DataNoteCategory.time => '时间与时区',
  DataNoteCategory.source => '来源与生成时间',
  DataNoteCategory.technical => '技术详情',
};

/// R24 模块卡：根页的图表、网格与记录进卡片。
///
/// 半径 [MileafRadius.lg]（20）、内边 [MileafSpace.cardPad]（16）、静态卡无阴影；
/// 不出现卡中卡，内部分组用分隔线或 16 间距。
class MileafModuleCard extends StatelessWidget {
  const MileafModuleCard({super.key, required this.child, this.padding});

  final Widget child;

  /// 默认卡内 16 内边；焦点卡在 §6 退让阶梯第 2 步可收紧到 12。
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    borderRadius: BorderRadius.circular(MileafRadius.lg),
    clipBehavior: Clip.hardEdge,
    child: Padding(
      padding: padding ?? const EdgeInsets.all(MileafSpace.cardPad),
      child: child,
    ),
  );
}

/// R24 分组卡：设置分组、记录分组与专题明细的容器。
///
/// 与模块卡同为圆角矩形、无阴影；[clip] 控制是否裁剪子内容。
class MileafGroupCard extends StatelessWidget {
  const MileafGroupCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.clip = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool clip;

  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    borderRadius: BorderRadius.circular(MileafRadius.lg),
    clipBehavior: clip ? Clip.hardEdge : Clip.none,
    child: Padding(padding: padding, child: child),
  );
}

/// R24 分组标题：卡片内或页尾的分组名，subheadline 500（R22）。
class MileafGroupHeader extends StatelessWidget {
  const MileafGroupHeader({super.key, required this.title, this.footnote});

  final String title;

  /// 分组标题下的一句脚注（例如「两项分别计量，不能相加」）。
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: type.groupTitle.copyWith(color: colors.textSecondary),
        ),
        if (footnote case final footnote?) ...[
          const SizedBox(height: MileafSpace.s4),
          Text(
            footnote,
            style: type.footnote.copyWith(color: colors.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// R24 分组行：设置与导航行的容器。
///
/// 最小高：单行 52、双行 64；分隔线从行内文字起始处开始、到卡片右缘结束，
/// 首行之上与末行之下没有分隔线。行首可选 20px 图标，命中区仍为平台命中高度。
class MileafGroupRow extends StatelessWidget {
  const MileafGroupRow({
    super.key,
    required this.title,
    this.meta,
    this.value,
    this.unit,
    this.leading,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.selected = false,
    this.destructive = false,
    this.topLine = false,
    this.bottomLine = false,
    this.semanticLabel,
  });

  final String title;
  final String? meta;
  final String? value;
  final String? unit;
  final MileafIconName? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool selected;

  /// 破坏性行（例如「清除已保存的 Key」）标题用 error 色，含义仍由文字承载。
  final bool destructive;
  final bool topLine;
  final bool bottomLine;
  final String? semanticLabel;

  /// 单行分组行最小高（R24）。
  static const double rowHeight = 52.0;

  /// 双行（带 meta）分组行最小高（R24）。
  static const double rowHeightTwoLine = 64.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final large = MileafLayout.largeText(context);
    final leadingWidth = leading == null
        ? 0.0
        : MileafIconMetrics.nav + MileafSpace.s12;
    final titleColor = destructive
        ? (enabled ? colors.error : colors.textFaint)
        : enabled
        ? colors.text
        : colors.textFaint;
    final metaColor = enabled ? colors.textSecondary : colors.textFaint;
    final leadingIcon = leading == null
        ? null
        : MileafIcon(
            leading!,
            size: MileafIconMetrics.nav,
            color: enabled ? colors.textSecondary : colors.textFaint,
          );
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          // R22：设置与导航行标题用 body 400，不加粗（Apple 设置页同样）。
          style: type.body.copyWith(color: titleColor),
        ),
        if (meta case final meta?) ...[
          const SizedBox(height: MileafSpace.inline2),
          Text(meta, style: type.subheadline.copyWith(color: metaColor)),
        ],
      ],
    );
    final valueWidget = value == null && unit == null
        ? null
        // R22/P12：设置与导航行的尾部值用 body textSecondary，而不是 20 号
        // metricSm（否则数值大于 17 的标题，层级倒置）。
        : Text.rich(
            TextSpan(
              text: value ?? '—',
              style: type.body.copyWith(
                color: enabled ? colors.textSecondary : colors.textFaint,
              ),
              children: unit == null
                  ? null
                  : [
                      TextSpan(
                        text: ' $unit',
                        style: type.subheadline.copyWith(
                          color: enabled
                              ? colors.textSecondary
                              : colors.textFaint,
                        ),
                      ),
                    ],
            ),
            maxLines: 1,
          );
    final hasTrailing = trailing != null || valueWidget != null;
    final trailingWidget = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ?valueWidget,
        if (trailing != null) ...[
          if (valueWidget != null) const SizedBox(width: MileafSpace.s8),
          trailing!,
        ],
      ],
    );
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leadingIcon != null) ...[
          leadingIcon,
          const SizedBox(width: MileafSpace.s12),
        ],
        Expanded(child: titleBlock),
        if (hasTrailing) ...[
          const SizedBox(width: MileafSpace.s12),
          trailingWidget,
        ],
      ],
    );
    Widget hairline() => Container(
      margin: EdgeInsets.only(left: leadingWidth + MileafSpace.cardPad),
      height: 0,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.line, width: MileafStroke.hairline),
        ),
      ),
    );
    final baseHeight = meta == null ? rowHeight : rowHeightTwoLine;
    final minHeight = large ? baseHeight + MileafSpace.s8 : baseHeight;
    final row = Material(
      color: selected ? colors.accentSoft : Colors.transparent,
      child: InkWell(
        onTap: enabled && onTap != null ? onTap : null,
        highlightColor: colors.pressOverlay,
        splashColor: colors.pressOverlay,
        excludeFromSemantics: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(minHeight, MileafLayout.touchTarget(context)),
          ),
          child: Padding(
            // R24：卡内文字对齐卡片内边距（页面 + 16）；行高仍由 52/64 约束。
            padding: const EdgeInsets.symmetric(
              horizontal: MileafSpace.cardPad,
              vertical: MileafSpace.s8,
            ),
            child: content,
          ),
        ),
      ),
    );
    final metaText = meta;
    final valueText = value;
    final unitText = unit;
    String composedLabel() {
      final buffer = StringBuffer(title);
      if (metaText != null) buffer.write('，$metaText');
      if (valueText != null) {
        buffer.write('，$valueText');
        if (unitText != null) buffer.write(' $unitText');
      }
      return buffer.toString();
    }

    final label = semanticLabel ?? composedLabel();
    return Semantics(
      container: true,
      button: enabled && onTap != null,
      enabled: enabled,
      selected: selected,
      label: label,
      onTap: enabled && onTap != null ? onTap : null,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [if (topLine) hairline(), row, if (bottomLine) hairline()],
      ),
    );
  }
}

/// R30.2 一组说明：分类 + 说明文字（[copyable] 时用可选中文本，技术详情用）。
class MileafDataNoteGroup {
  const MileafDataNoteGroup({
    required this.category,
    required this.note,
    this.copyable = false,
  });

  final DataNoteCategory category;
  final String note;
  final bool copyable;
}

/// R30.2 页尾「关于这些数据」：分组标题 + 一张分组卡，卡内默认折叠的说明行。
///
/// 说明行固定分为五类，缺哪类就不出现；说明文字为 body textSecondary，
/// 技术详情可复制（R30.4）。
class MileafDataNotes extends StatelessWidget {
  const MileafDataNotes({
    super.key,
    required this.groups,
    this.title = '关于这些数据',
  });

  final List<MileafDataNoteGroup> groups;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final ordered = [...groups]
      ..sort((a, b) => a.category.index - b.category.index);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MileafGroupHeader(title: title),
        const SizedBox(height: MileafSpace.s8),
        MileafGroupCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final group in ordered)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MileafSpace.cardPad,
                  ),
                  child: MileafDisclosure(
                    label: dataNoteLabel(group.category),
                    child: group.copyable
                        ? SelectableText(
                            group.note,
                            style: type.body.copyWith(
                              color: colors.textSecondary,
                            ),
                          )
                        : Text(
                            group.note,
                            style: type.body.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// R31 进行中：小胶囊标签（高 24、footnote 500、segmentTrack 底）。
class MileafRunningPill extends StatelessWidget {
  const MileafRunningPill({super.key, this.label = '进行中'});

  final String label;

  /// R31：进行中标签高 24。
  static const double pillHeight = 24;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Container(
      height: pillHeight,
      padding: const EdgeInsets.symmetric(horizontal: MileafSpace.s8),
      decoration: BoxDecoration(
        color: colors.segmentTrack,
        borderRadius: MileafRadius.fullAll,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: type.footnote.copyWith(
          color: colors.textSecondary,
          fontWeight: MileafType.weightMedium,
        ),
      ),
    );
  }
}
