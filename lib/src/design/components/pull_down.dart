import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../icons.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';
import 'button.dart' show MileafControlMetrics, MileafPressOverlay;

/// 下拉菜单的一个选项。
@immutable
class MileafPullDownOption<T> {
  const MileafPullDownOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// R27 下拉：小胶囊（高 32，segmentTrack）+ control 文字 + 向下箭头；菜单按 R28
/// （surfaceRaised 实色、半径 14、行高 44、选中项尾部勾选）。
///
/// 胶囊文字是当前值本身（对照表：类型 / 费用 / 排序 等），不另写标签。
class MileafPullDown<T> extends StatefulWidget {
  const MileafPullDown({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.label,
    this.enabled = true,
  });

  final List<MileafPullDownOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// 读屏用的对象名（如「类型」）；不给时只用当前值。
  final String? label;
  final bool enabled;

  @override
  State<MileafPullDown> createState() => _MileafPullDownState<T>();
}

class _MileafPullDownState<T> extends State<MileafPullDown<T>> {
  final _anchor = GlobalKey();
  bool _pressed = false;

  Future<void> _open() async {
    final box = _anchor.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final colors = context.colors;
    final type = context.type;
    final width = box.size.width;
    final selected = await showMenu<T>(
      context: context,
      position: RelativeRect.fromLTRB(
        origin.dx,
        origin.dy + box.size.height + MileafSpace.s4,
        math.max(0, overlay.size.width - origin.dx - width),
        math.max(0, overlay.size.height - origin.dy - box.size.height),
      ),
      color: colors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MileafControlMetrics.menuRadius),
      ),
      constraints: BoxConstraints(
        minWidth: width,
        maxWidth: math.max(width, MileafSpace.s56 * 4),
      ),
      items: [
        for (final option in widget.options)
          PopupMenuItem<T>(
            value: option.value,
            height: MileafControlMetrics.menuRowHeight,
            padding: const EdgeInsets.symmetric(horizontal: MileafSpace.s16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option.label,
                    style: type.body.copyWith(color: colors.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (option.value == widget.value) ...[
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
      ],
    );
    if (selected != null && selected != widget.value) {
      widget.onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final current = widget.options.firstWhere(
      (option) => option.value == widget.value,
      orElse: () => widget.options.first,
    );
    final semantic = widget.label;
    final value = current.label;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: semantic == null ? value : '$semantic $value',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: _anchor,
          onTap: widget.enabled ? _open : null,
          onHighlightChanged: widget.enabled
              ? (pressed) => setState(() => _pressed = pressed)
              : null,
          customBorder: const StadiumBorder(),
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: MileafControlMetrics.smallCapsuleHeight,
            ),
            padding: const EdgeInsets.symmetric(horizontal: MileafSpace.s12),
            decoration: BoxDecoration(
              color: colors.segmentTrack,
              borderRadius: BorderRadius.circular(MileafRadius.full),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: type.control.copyWith(
                          color: widget.enabled
                              ? colors.text
                              : colors.textFaint.withValues(alpha: .38),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: MileafSpace.s4),
                    MileafIcon(
                      MileafIconName.chevronDown,
                      size: MileafIconMetrics.inline,
                      color: colors.textSecondary,
                    ),
                  ],
                ),
                Positioned.fill(
                  child: MileafPressOverlay(
                    visible: _pressed,
                    color: colors.accentSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
