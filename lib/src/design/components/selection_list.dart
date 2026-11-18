import 'package:flutter/material.dart';

import '../icons.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

/// 选择列表的一行。
@immutable
class MileafSelectionOption<T> {
  const MileafSelectionOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? subtitle;
  final bool enabled;
}

/// R27/R23.4 选择列表：分组卡内的行，选中只显示尾部勾选，不填充底色。
///
/// 行高按 R24 分组行：单行 52、双行 64；标题 body 400（设置/导航类行不加粗），
/// 副标题 subheadline。分隔线由所在分组卡负责（R24）。
class MileafSelectionList<T> extends StatelessWidget {
  const MileafSelectionList({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    this.showDividers = false,
    this.padding = EdgeInsets.zero,
  });

  final List<MileafSelectionOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String? semanticLabel;

  /// 独立出现（不在分组卡内）时画一物理像素分隔线。
  final bool showDividers;
  final EdgeInsetsGeometry padding;

  /// R24 分组行最小高：单行 52、双行 64。
  static const rowHeight = 52.0;
  static const rowHeightTwoLine = 64.0;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    container: semanticLabel != null,
    child: Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, option) in options.indexed) ...[
            if (showDividers && index > 0)
              const Divider(
                height: MileafStroke.hairline,
                thickness: MileafStroke.hairline,
                indent: MileafSpace.s16,
              ),
            _SelectionRow<T>(
              option: option,
              selected: option.value == value,
              onTap: option.enabled ? () => onChanged(option.value) : null,
            ),
          ],
        ],
      ),
    ),
  );
}

class _SelectionRow<T> extends StatefulWidget {
  const _SelectionRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final MileafSelectionOption<T> option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_SelectionRow<T>> createState() => _SelectionRowState<T>();
}

class _SelectionRowState<T> extends State<_SelectionRow<T>> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final option = widget.option;
    final subtitle = option.subtitle;
    final doubleLine = subtitle != null;
    final label = option.label;
    return Semantics(
      button: true,
      selected: widget.selected,
      enabled: option.enabled,
      label: doubleLine ? '$label $subtitle' : label,
      excludeSemantics: true,
      child: Focus(
        onFocusChange: (value) => setState(() => _focused = value),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            highlightColor: colors.pressOverlay,
            splashColor: Colors.transparent,
            child: Container(
              constraints: BoxConstraints(
                minHeight: doubleLine
                    ? MileafSelectionList.rowHeightTwoLine
                    : MileafSelectionList.rowHeight,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: MileafSpace.s16,
                vertical: MileafSpace.s8,
              ),
              foregroundDecoration: _focused
                  ? BoxDecoration(
                      border: Border.all(color: colors.focusRing, width: 2),
                      borderRadius: BorderRadius.circular(MileafRadius.md),
                    )
                  : null,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: type.body.copyWith(
                            color: option.enabled
                                ? colors.text
                                : colors.textFaint.withValues(alpha: .38),
                          ),
                        ),
                        if (doubleLine) ...[
                          const SizedBox(height: MileafSpace.inline2),
                          Text(subtitle, style: type.subheadline),
                        ],
                      ],
                    ),
                  ),
                  if (widget.selected) ...[
                    const SizedBox(width: MileafSpace.s12),
                    MileafIcon(
                      MileafIconName.check,
                      size: MileafIconMetrics.nav,
                      color: colors.accent,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
