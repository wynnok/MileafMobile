import 'package:flutter/material.dart';

import '../icons.dart';
import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';
import 'metric.dart';

/// Hairline list row: optional 30px line icon, title/meta, value + unit.
///
/// Named `MileafDataRow` to avoid clashing with Material's table `DataRow`.
class MileafDataRow extends StatefulWidget {
  const MileafDataRow({
    super.key,
    required this.title,
    this.meta,
    this.value,
    this.unit,
    this.icon,
    this.badge,
    this.onTap,
    this.showChevron = false,
    this.selected = false,
    this.enabled = true,
    this.topLine = false,
    this.bottomLine = false,
    this.destructive = false,
    this.semanticLabel,
    this.titleMaxLines,
  });

  final String title;
  final int? titleMaxLines;
  final String? meta;
  final String? value;
  final String? unit;
  final MileafIconName? icon;
  final Widget? badge;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool selected;
  final bool enabled;
  final bool topLine;
  final bool bottomLine;

  /// Destructive rows (for example「清除已保存的 Key」) take the existing
  /// `error` token for the title. The wording still carries the meaning, so
  /// colour is never the only signal (appearance v2 Spec §3.4).
  final bool destructive;
  final String? semanticLabel;

  @override
  State<MileafDataRow> createState() => _MileafDataRowState();
}

class _MileafDataRowState extends State<MileafDataRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final enabled = widget.enabled && widget.onTap != null;
    final showChevron = widget.showChevron && enabled;
    final titleColor = widget.destructive
        ? (enabled ? colors.error : colors.textFaint)
        : widget.enabled
        ? colors.text
        : colors.textFaint;
    final metaColor = widget.enabled ? colors.textMuted : colors.textFaint;
    final large = MileafLayout.largeText(context);
    // R04 禁止图标圆币：行内图标直接绘制，20px、textMuted，无圆圈包装。
    final leading = widget.icon == null
        ? null
        : MileafIcon(
            widget.icon!,
            size: MileafIconMetrics.nav,
            color: widget.enabled ? colors.textMuted : colors.textFaint,
          );
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          maxLines: widget.titleMaxLines,
          overflow: widget.titleMaxLines == null ? null : TextOverflow.ellipsis,
          style: type.body.copyWith(
            color: titleColor,
            fontWeight: MileafType.weightSemiBold,
          ),
        ),
        if (widget.meta != null) ...[
          const SizedBox(height: MileafSpace.inline2),
          Text(widget.meta!, style: type.micro.copyWith(color: metaColor)),
        ],
      ],
    );
    final value = widget.value == null && widget.unit == null
        ? null
        : MileafNumber(
            value: widget.value,
            unit: widget.unit,
            scale: MetricValueScale.metricMd,
            alignEnd: true,
            color: widget.enabled ? colors.text : colors.textFaint,
            unitColor: colors.textFaint,
          );
    final trailing = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (widget.badge != null) ...[
          widget.badge!,
          const SizedBox(width: MileafSpace.s8),
        ],
        ?value,
        if (showChevron) ...[
          const SizedBox(width: MileafSpace.s4),
          MileafIcon(
            MileafIconName.chevron,
            size: MileafIconMetrics.inline,
            color: colors.textFaint,
          ),
        ],
      ],
    );
    // Navigation rows keep a trailing arrow even at large text sizes. Only
    // rows with a separate value or badge need to stack their trailing data.
    final body = large && (value != null || widget.badge != null)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading,
                const SizedBox(height: MileafSpace.s8),
              ],
              titleBlock,
              if (value != null || widget.badge != null || (showChevron)) ...[
                const SizedBox(height: MileafSpace.s8),
                Align(alignment: Alignment.centerLeft, child: trailing),
              ],
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading,
                const SizedBox(width: MileafSpace.s12),
              ],
              Expanded(child: titleBlock),
              if (value != null || widget.badge != null || (showChevron)) ...[
                const SizedBox(width: MileafSpace.s12),
                trailing,
              ],
            ],
          );
    final row = Material(
      color: widget.selected ? colors.accentSoft : Colors.transparent,
      child: InkWell(
        onTap: enabled ? widget.onTap : null,
        highlightColor: colors.pressOverlay,
        splashColor: colors.pressOverlay,
        child: Container(
          constraints: const BoxConstraints(minHeight: MileafSpace.rowMin),
          decoration: BoxDecoration(
            border: Border(
              top: widget.topLine
                  ? BorderSide(color: colors.line)
                  : BorderSide.none,
              bottom: widget.bottomLine
                  ? BorderSide(color: colors.line)
                  : BorderSide.none,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: MileafSpace.s12),
          alignment: Alignment.centerLeft,
          child: body,
        ),
      ),
    );
    return Semantics(
      container: true,
      button: enabled,
      selected: widget.selected,
      enabled: widget.enabled,
      label:
          widget.semanticLabel ??
          '${widget.title}${widget.meta == null ? '' : '，${widget.meta}'}'
              '${value == null ? '' : '，${widget.value ?? '—'}${widget.unit == null ? '' : ' ${widget.unit}'}'}',
      onTap: enabled ? widget.onTap : null,
      excludeSemantics: true,
      child: Focus(
        onFocusChange: (value) => setState(() => _focused = value),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: _focused
                ? Border.all(color: colors.focusRing, width: 2)
                : null,
          ),
          child: row,
        ),
      ),
    );
  }
}
