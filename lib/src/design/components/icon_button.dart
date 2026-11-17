import 'package:flutter/material.dart';

import '../icons.dart';
import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import 'button.dart' show MileafControlMetrics, MileafPressOverlay;

/// R27 图标按钮的填充形态。
enum MileafIconButtonFill {
  /// 无填充：只在按压与焦点时才出现面。
  none,

  /// 画布上的圆钮用 segmentTrack 填充（R27）。
  ///
  /// 顶栏镜片的实色路径同为 segmentTrack（R26），半透明镜片材质由外壳提供，
  /// 因此外壳只需要同一枚实色圆钮。
  track,
}

/// R27 图标圆钮：视觉 36、图标 20、命中按平台触控尺寸（iOS 44 / Android 48）。
/// 按压无涟漪（§4 M01），禁用 38% textFaint，选中用 accentSoft 底与 accent 图标。
class MileafIconButton extends StatefulWidget {
  const MileafIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
    this.size = MileafIconMetrics.nav,
    this.selected = false,
    this.fill = MileafIconButtonFill.none,
  });

  final MileafIconName icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final bool selected;
  final MileafIconButtonFill fill;

  @override
  State<MileafIconButton> createState() => _MileafIconButtonState();
}

class _MileafIconButtonState extends State<MileafIconButton> {
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = widget.onPressed != null;
    final color = !enabled
        ? colors.textFaint.withValues(alpha: .38)
        : widget.selected
        ? colors.accent
        : widget.color ?? colors.textMuted;
    final fill = widget.selected
        ? colors.accentSoft
        : widget.fill == MileafIconButtonFill.track
        ? colors.segmentTrack
        : null;
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: widget.selected,
        label: widget.tooltip,
        child: SizedBox.square(
          dimension: MileafLayout.touchTarget(context),
          child: Focus(
            onFocusChange: (value) => setState(() => _focused = value),
            child: Material(
              color: Colors.transparent,
              // 命中用整块方形（A08）；视觉与覆盖层才是 36 的圆。
              child: InkWell(
                onTap: widget.onPressed,
                onHighlightChanged: enabled
                    ? (value) => setState(() => _pressed = value)
                    : null,
                customBorder: const CircleBorder(),
                highlightColor: Colors.transparent,
                splashColor: Colors.transparent,
                child: Center(
                  child: SizedBox.square(
                    dimension: MileafControlMetrics.iconVisual,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: fill,
                            border: _focused
                                ? Border.all(color: colors.focusRing, width: 2)
                                : null,
                          ),
                          child: const SizedBox.expand(),
                        ),
                        MileafIcon(
                          widget.icon,
                          size: widget.size,
                          color: color,
                        ),
                        Positioned.fill(
                          child: MileafPressOverlay(
                            visible: _pressed,
                            color: colors.accentSoft,
                            shape: const CircleBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
