import 'package:flutter/material.dart';

import '../icons.dart';
import '../layout.dart';
import '../motion.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';
import 'focus_ring.dart';

/// 折叠行：一行标签 + 右侧箭头，展开后内容在原位自然重排。
///
/// 行的文字起点就是内容左边缘——命中区从这一行自己的左沿开始，不带
/// Material `ExpansionTile` 的 16 行内边距，也不像文本按钮那样把标签缩进
/// 12–16。因此「对照电量」「采样数据说明」这类入口与章节标题、图表标题、
/// 事实表首列落在同一条竖线上（焕新规格 R11「共用起始线」）。
///
/// 动效沿用 R16 M06：箭头旋转 160ms easeOutCubic，内容随实际高度重排；
/// 减少动效时为 0ms。收起时子内容不构建，展开才付布局成本。
class MileafDisclosure extends StatefulWidget {
  const MileafDisclosure({
    super.key,
    required this.label,
    required this.child,
    this.meta,
    this.emphasis = false,
    this.topLine = false,
    this.expanded,
    this.onExpandedChanged,
  });

  /// 行标签。动作行用动词短语，说明行用名词短语。
  final String label;

  /// 展开后的内容。
  final Widget child;

  /// 标签下的第二行说明，在按下之前就说清展开会出现什么。
  final String? meta;

  /// 动作行（如「对照电量」）比纯说明行更实一档：标签用 `text` 与 500。
  final bool emphasis;

  /// 行上方的 1px 分隔线，用于把「图表 + 数据说明」与「追加动作」分开。
  final bool topLine;

  /// 受控展开态；为 null 时组件自己持有状态。页面把状态提出去，
  /// 同一行在相邻控件（例如切指标）卸载重建后仍保持原来的开合。
  final bool? expanded;

  final ValueChanged<bool>? onExpandedChanged;

  @override
  State<MileafDisclosure> createState() => _MileafDisclosureState();
}

class _MileafDisclosureState extends State<MileafDisclosure> {
  bool _local = false;

  bool get _expanded => widget.expanded ?? _local;

  void _toggle() {
    if (widget.expanded == null) setState(() => _local = !_local);
    widget.onExpandedChanged?.call(!_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final labelColor = widget.emphasis ? colors.text : colors.textMuted;
    // 标签首行的行高（含 TextScaler），箭头按它居中。
    final labelLineHeight = MediaQuery.textScalerOf(context)
        .scale(MileafType.bodyHeight);
    final labelBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: type.body.copyWith(
            color: labelColor,
            fontWeight: widget.emphasis
                ? MileafType.weightMedium
                : MileafType.weightRegular,
          ),
        ),
        if (widget.meta case final meta?) ...[
          const SizedBox(height: MileafSpace.inline2),
          Text(meta, style: type.footnote.copyWith(color: colors.textMuted)),
        ],
      ],
    );
    final header = ConstrainedBox(
      constraints: BoxConstraints(minHeight: MileafLayout.touchTarget(context)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MileafSpace.s8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: labelBlock),
            const SizedBox(width: MileafSpace.s12),
            // 箭头与标签首行同一视觉中线：两行标签时不会落到两行之间。
            SizedBox(
              width: MileafIconMetrics.inline,
              height: labelLineHeight,
              child: Center(
                child: AnimatedRotation(
                  turns: _expanded ? -.25 : .25,
                  duration: MileafLayout.motion(
                    context,
                    MileafDurations.chevron,
                  ),
                  curve: Curves.easeOutCubic,
                  child: MileafIcon(
                    MileafIconName.chevron,
                    size: MileafIconMetrics.inline,
                    color: widget.emphasis
                        ? colors.textMuted
                        : colors.textFaint,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final tile = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          button: true,
          expanded: _expanded,
          label: widget.label,
          hint: widget.meta,
          onTap: _toggle,
          excludeSemantics: true,
          // 焦点停在 InkWell 自己的节点上；这里只作为焦点环的定位锚，
          // 不再多一个 Tab 停靠点。
          child: Focus(
            canRequestFocus: false,
            child: MileafFocusRing(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _toggle,
                  highlightColor: colors.pressOverlay,
                  splashColor: colors.pressOverlay,
                  // 语义由外层 container 承载，点击不新增第二个节点。
                  excludeFromSemantics: true,
                  child: header,
                ),
              ),
            ),
          ),
        ),
        AnimatedOpacity(
          duration: MileafLayout.motion(context, MileafDurations.foldOpacity),
          curve: MileafCurves.fade,
          opacity: _expanded ? 1 : 0,
          // M06：折叠内容高度 200ms、透明度 120ms；阅读锚点不跳（顶部不动，
          // 内容向下长出，收起时原地收敛）。
          child: AnimatedSize(
            duration: MileafLayout.motion(context, MileafDurations.foldHeight),
            curve: MileafCurves.fold,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: MileafSpace.s8),
                    child: widget.child,
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ),
      ],
    );
    if (!widget.topLine) return tile;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: tile,
    );
  }
}
