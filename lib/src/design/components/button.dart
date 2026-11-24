import 'package:flutter/material.dart';

import '../icons.dart';
import '../layout.dart';
import '../motion.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';
import 'glass_surface.dart';

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

  /// CL13.1/CL14：按钮图标**在左**，与文字的间距恒为 s8，视觉居中。
  ///
  /// 间距只有这一处来源：主按钮、次按钮、文字按钮共用 [iconLeading]，页面不得
  /// 自己给图标加间距或把它挪到文字右侧。
  static const buttonIconGap = MileafSpace.s8;

  /// CL14 的图标槽：图标（inline 16，取按钮前景色）+ s8 间距。
  ///
  /// 没给图标时不占位——文字按钮可以没有图标，但一旦给出就固定在文字左侧
  /// （CL14 第三条：同一动作可省略图标，不得换一个图标）。
  static List<Widget> iconLeading(MileafIconName? icon, Color color) => [
    if (icon != null) ...[
      MileafIcon(icon, size: MileafIconMetrics.inline, color: color),
      const SizedBox(width: buttonIconGap),
    ],
  ];

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

/// CL14 动作图标映射：动作语义 → 字形，页面按动作取图标，不再每页各挑一个。
///
/// 纪律：**图标只复述按钮词义，不得引入按钮文字里没有的概念。**「刷新」配
/// refresh、「查看对比明细」配 chart，因为那两句文字说的就是刷新与明细；图标
/// 不承担第二套动作名，也不为装饰而加（映射表 #8：参考 App「动作不靠图标」，
/// 本轮按用户指令反向要求补图标）。
///
/// 同一个动作在不同页面、不同层级都用同一个字形：文字按钮可以省略图标
/// （[MileafButton.icon] 为 null），但不得换一个图标。因此「刷新」与「重试」
/// 虽然是两种措辞，仍是同一个 refresh 字形。
abstract final class MileafActionIcon {
  const MileafActionIcon._();

  /// 刷新（重新取当前数据）。
  static const refresh = MileafIconName.refresh;

  /// 分享（页面级动作）。
  static const share = MileafIconName.share;

  /// 对比 / 明细下钻（按钮文字里说的是「明细」「对比」）。
  static const compare = MileafIconName.chart;

  /// 补录费用（只有费用补录入口用钱包，不用于充电记录行）。
  static const addCost = MileafIconName.wallet;

  /// 放大 / 查看完整地图。
  static const expand = MileafIconName.expand;

  /// 查看地图（跳到地图或地图详情）。
  static const map = MileafIconName.mapPin;

  /// 重试：动作与 [refresh] 相同，只是措辞是「重试」。
  static const retry = MileafIconName.refresh;

  /// 筛选（展开条件选择，与下拉箭头一致）。
  static const filter = MileafIconName.chevronDown;

  /// 复制。
  static const copy = MileafIconName.copy;

  /// 清除（关闭弹层、清空输入）。
  static const clear = MileafIconName.close;

  /// 保存（确认写入）。
  static const save = MileafIconName.check;

  /// 日期区间。
  static const dateRange = MileafIconName.calendar;
}

enum MileafButtonKind { primary, secondary, ghost }

/// R27 按钮：主按钮 50 高胶囊（primaryAction 填充、headline 文字）；次按钮 50 高
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
        enabled || loading ? colors.primaryAction : colors.line,
        enabled || loading ? colors.onPrimaryAction : colors.textFaint,
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
    // §7.2 / M01：有填色的按钮使用中性覆盖层，文字按钮使用品牌叠色。
    final highlight = kind == MileafButtonKind.ghost
        ? colors.accentSoft
        : colors.pressOverlay;
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
        // CL14：图标在左、间距 s8，间距只来自 buttonIconGap。
        ...MileafControlMetrics.iconLeading(icon, foreground),
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
    final secondary = kind == MileafButtonKind.secondary;
    final button = Material(
      color: secondary ? Colors.transparent : background,
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
          padding: const EdgeInsets.symmetric(horizontal: MileafSpace.s16),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: _focused
                  ? kind == MileafButtonKind.primary
                        ? colors.onPrimaryAction
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
    );
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
          child: secondary
              ? MileafGlassSurface.tinted(
                  color: Color.alphaBlend(background, colors.cardSurface()),
                  borderRadius: radius,
                  child: button,
                )
              : button,
        ),
      ),
    );
  }
}
