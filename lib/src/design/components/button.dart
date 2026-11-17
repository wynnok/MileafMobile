import 'package:flutter/material.dart';

import '../icons.dart';
import '../layout.dart';
import '../motion.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

/// R27/R28 控件几何：分段、按钮、图标圆钮、小胶囊、菜单与浮动弹层的固定尺寸。
///
/// 这些值属于控件层（设计层），页面不得自行复写；数值来源见规格 R24、R27、R28。
abstract final class MileafControlMetrics {
  const MileafControlMetrics._();

  /// R24/R27：分段轨道视觉高 40、选中底 36（轨道上下各留 2）。
  static const segmentTrackHeight = 40.0;
  static const segmentSelectedHeight = 36.0;

  /// R24/R27：主次按钮 50、小胶囊（下拉）32、标签 24。
  static const buttonHeight = 50.0;
  static const smallCapsuleHeight = 32.0;
  static const tagHeight = 24.0;

  /// R24/R27：图标按钮视觉 36、图标 20（命中用平台触控尺寸）。
  static const iconVisual = 36.0;

  /// R28：菜单半径 14、行高 44；浮动弹层左右下各留 8。
  static const menuRadius = 14.0;
  static const menuRowHeight = 44.0;
  static const floatingSheetInset = MileafSpace.s8;

  /// R27：选中底阴影仅浅色（y1 / blur3 / 黑 12%），深色无阴影。
  static List<BoxShadow> selectionShadow(MileafColors colors) => colors.isDark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x1F000000),
            offset: Offset(0, 1),
            blurRadius: 3,
          ),
        ];
}

/// §4 M01：按压覆盖层即时出现，松手 120ms easeOut 消退（无涟漪）。
///
/// 由宿主控件用 InkWell 的 onHighlightChanged 或 Listener 驱动 [visible]；
/// 覆盖层本身不吃指针事件，只画一层同形状的色。
class MileafPressOverlay extends StatelessWidget {
  const MileafPressOverlay({
    super.key,
    required this.visible,
    required this.color,
    this.borderRadius = MileafRadius.fullAll,
    this.shape,
  });

  final bool visible;
  final Color color;
  final BorderRadius borderRadius;

  /// 圆形等非圆角形状；给出时忽略 [borderRadius]。
  final ShapeBorder? shape;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedOpacity(
      // 按下即时出现（时长 0），松手按 M01 用 120ms easeOut 消退。
      opacity: visible ? 1 : 0,
      duration: visible
          ? Duration.zero
          : MileafLayout.motion(context, MileafDurations.press),
      curve: MileafCurves.press,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: color,
          shape: shape ?? RoundedRectangleBorder(borderRadius: borderRadius),
        ),
      ),
    ),
  );
}

enum MileafButtonKind { primary, secondary, ghost }

/// R27 按钮：主按钮 50 高胶囊（accentStrong 填充、headline 文字）；次按钮 50 高
/// 胶囊（accentSoft 填充、accentStrong control 文字）；文字按钮 accentStrong
/// body 400。处理中保留文字并在尾部加平台活动指示器，宽度不跳。
class MileafButton extends StatefulWidget {
  const MileafButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = MileafButtonKind.primary,
    this.loading = false,
    this.icon,
    this.expand = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final MileafButtonKind kind;
  final bool loading;
  final MileafIconName? icon;
  final bool expand;

  /// R27 危险操作：文字按钮或次按钮用 error 文字（确认流程不变）。
  final bool destructive;

  @override
  State<MileafButton> createState() => _MileafButtonState();
}

class _MileafButtonState extends State<MileafButton> {
  bool _focused = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final onPressed = widget.onPressed;
    final kind = widget.kind;
    final loading = widget.loading;
    final icon = widget.icon;
    final expand = widget.expand;
    final destructive = widget.destructive;
    final colors = context.colors;
    final type = context.type;
    final enabled = onPressed != null && !loading;
    final errorText = destructive && kind != MileafButtonKind.primary;
    final (background, foreground, border) = switch (kind) {
      MileafButtonKind.primary => (
        enabled || loading ? colors.accentStrong : colors.line,
        enabled || loading ? colors.textOnAccent : colors.textFaint,
        null,
      ),
      MileafButtonKind.secondary => (
        colors.accentSoft,
        !(enabled || loading)
            ? colors.textFaint
            : errorText
            ? colors.error
            : colors.accentStrong,
        null,
      ),
      MileafButtonKind.ghost => (
        Colors.transparent,
        !(enabled || loading)
            ? colors.textFaint
            : errorText
            ? colors.error
            : colors.accentStrong,
        null,
      ),
    };
    // §7.2 / M01：主按钮与文字按钮的按压是强调动作；次按钮已用 accentSoft 填充，
    // 覆盖层改中性 pressOverlay，否则按下看不出变化。
    final highlight = kind == MileafButtonKind.secondary
        ? colors.pressOverlay
        : colors.accentSoft;
    final textStyle = switch (kind) {
      // R27：主按钮文字 headline；次按钮 control；文字按钮 body 400。
      MileafButtonKind.primary => type.headline,
      MileafButtonKind.secondary => type.control,
      MileafButtonKind.ghost => type.body,
    }.copyWith(color: foreground);
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          MileafIcon(icon, size: MileafIconMetrics.inline, color: foreground),
          const SizedBox(width: MileafSpace.s8),
        ],
        Flexible(
          child: Text(
            label,
            style: textStyle,
            // R03：长标签换行重排，不缩字、不溢出（Row 内需显式 Flexible 才有界）。
            softWrap: true,
            textAlign: TextAlign.center,
          ),
        ),
        // R27：处理中在尾部加平台活动指示器，且宽度不跳——尾部位始终占位。
        const SizedBox(width: MileafSpace.s8),
        SizedBox(
          width: MileafSpace.s16,
          height: MileafSpace.s16,
          child: loading
              ? CircularProgressIndicator(strokeWidth: 1.5, color: foreground)
              : null,
        ),
      ],
    );
    final radius = BorderRadius.circular(MileafRadius.full);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      value: loading ? '正在处理' : null,
      child: AnimatedScale(
        scale: _pressed && !MileafLayout.reduceMotion(context)
            ? MileafMotion.pressScale
            : 1,
        duration: MileafLayout.motion(context, MileafDurations.press),
        curve: MileafCurves.press,
        child: Focus(
          onFocusChange: (value) => setState(() => _focused = value),
          child: Material(
            color: background,
            borderRadius: radius,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              onHighlightChanged: enabled
                  ? (value) => setState(() => _pressed = value)
                  : null,
              borderRadius: radius,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(
                  minHeight: kind == MileafButtonKind.ghost
                      ? MileafLayout.touchTarget(context)
                      : MileafControlMetrics.buttonHeight,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: MileafSpace.s16,
                ),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: _focused
                        ? kind == MileafButtonKind.primary
                              ? colors.textOnAccent
                              : colors.focusRing
                        : border ?? Colors.transparent,
                    width: _focused ? 2 : 1,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    child,
                    Positioned.fill(
                      child: MileafPressOverlay(
                        visible: _pressed,
                        color: highlight,
                        borderRadius: radius,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
