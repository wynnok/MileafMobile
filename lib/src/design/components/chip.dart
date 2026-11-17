import 'package:flutter/material.dart';

import '../layout.dart';
import '../motion.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';
import 'button.dart' show MileafControlMetrics, MileafPressOverlay;

/// 分段控件的测试与图板用稳定 Key（不含业务数据）。
abstract final class MileafChipKeys {
  const MileafChipKeys._();

  /// 共享轨道容器。
  static const track = ValueKey('segment-track');

  /// 轨道里唯一的选中底（胶囊）。
  static const selected = ValueKey('segment-selected');

  /// 单个分段的胶囊本体（视觉 36/40 高，命中区在它外面的透明带里）。
  static ValueKey<String> capsule(String label) =>
      ValueKey('segment-capsule-$label');
}

/// R27 分段控件：胶囊轨道（[MileafColors.segmentTrack]）+ 唯一胶囊选中底
/// （[MileafColors.segmentSelected]；浅色加 y1/blur3/黑 12% 阴影，深色无阴影）。
///
/// 几何：轨道视觉高 40、选中底 36；命中区用平台触控尺寸（iOS 44 / Android 48）
/// 透明扩展。文字：未选 control 500 textSecondary，选中 600 text。
/// R27 删除下划线标记；选中语义由胶囊底与 600 字重表达。
class StatusChip extends StatefulWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.enabled = true,
    this.onHero = false,
    this.semanticLabel,
  });

  final String label;
  final String? semanticLabel;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;
  final bool onHero;

  @override
  State<StatusChip> createState() => _StatusChipState();
}

class _StatusChipState extends State<StatusChip> {
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final selected = widget.selected;
    final enabled = widget.enabled && widget.onTap != null;
    final onHero = widget.onHero;
    final track = ChipTrackScope.maybeOf(context);
    final grouped = track != null;
    final Color background;
    if (grouped) {
      // 共享轨道只画一次选中底，分段本体保持透明。
      background = Colors.transparent;
    } else if (selected) {
      background = colors.segmentSelected;
    } else {
      background = colors.segmentTrack;
    }
    final Color foreground;
    if (!widget.enabled) {
      foreground = colors.textFaint.withValues(alpha: .38);
    } else if (selected) {
      foreground = onHero ? colors.heroText : colors.text;
    } else {
      foreground = onHero ? colors.heroMuted : colors.textSecondary;
    }
    final style = (selected ? type.controlSelected : type.control).copyWith(
      color: foreground,
    );
    final radius = BorderRadius.circular(MileafRadius.full);
    final capsule = AnimatedContainer(
      key: MileafChipKeys.capsule(widget.label),
      duration: MileafLayout.motion(context, MileafDurations.selection),
      curve: MileafCurves.selection,
      constraints: BoxConstraints(
        minHeight:
            track?.capsuleHeight ?? MileafControlMetrics.segmentSelectedHeight,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        boxShadow: selected && !grouped
            ? MileafControlMetrics.selectionShadow(colors)
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MileafSpace.s12,
              vertical: MileafSpace.s4,
            ),
            child: Text(
              widget.label,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          Positioned.fill(
            child: MileafPressOverlay(
              visible: _pressed,
              color: colors.accentSoft,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: widget.onTap != null,
      selected: selected,
      enabled: enabled,
      label: widget.semanticLabel ?? widget.label,
      excludeSemantics: true,
      child: Focus(
        onFocusChange: (value) => setState(() => _focused = value),
        child: SizedBox(
          height: MileafLayout.touchTarget(context),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? widget.onTap : null,
              onHighlightChanged: enabled
                  ? (value) => setState(() => _pressed = value)
                  : null,
              customBorder: const StadiumBorder(),
              // §4 M01：无涟漪，按压只用 MileafPressOverlay 计时的覆盖层。
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              child: Center(
                widthFactor: 1,
                child: Container(
                  foregroundDecoration: _focused
                      ? BoxDecoration(
                          borderRadius: radius,
                          border: Border.all(color: colors.focusRing, width: 2),
                        )
                      : null,
                  child: capsule,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Marks chips whose selected surface is painted once by the shared track.
class ChipTrackScope extends InheritedWidget {
  const ChipTrackScope({super.key, required super.child, this.capsuleHeight});

  /// 轨道为整行算出的统一胶囊高（≥36）；分段照此对齐，避免大字下长短不齐。
  final double? capsuleHeight;

  static ChipTrackScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChipTrackScope>();

  @override
  bool updateShouldNotify(ChipTrackScope oldWidget) =>
      oldWidget.capsuleHeight != capsuleHeight;
}
