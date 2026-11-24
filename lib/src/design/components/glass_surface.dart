import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../display_preferences.dart';
import '../semantic.dart';
import '../tokens.dart';

/// 液态玻璃（ADR 0013）：一层有界、可读的玻璃表面。
///
/// 组成只有四件事，顺序固定：背景模糊与轻微过饱和、自上而下的玻璃体叠色、
/// 顶部固定高光与下沿弯月、内外两圈受光边缘。没有扫光、没有动画光学参数，
/// 所以同一屏的材质是静态的，只有位置随内容变化。
///
/// 玻璃体只用本模式的中性色（浅色白、深色近黑）叠加，因此它只会把背后内容
/// 朝 canvas 方向推：浅色页只会更亮、深色页只会更暗。正文与图标的对比度由
/// token 与本层叠色共同决定，不随背后内容的色相漂移。
class MileafGlassSurface extends StatelessWidget {
  const MileafGlassSurface({
    super.key,
    required this.child,
    this.borderRadius = MileafRadius.fullAll,
  }) : _control = false,
       _tintedSurface = null,
       forceSolid = false,
       elevated = true,
       blurBackdrop = true;

  /// 控件、顶部工具栏和浮层的玻璃。底部导航仍走默认构造。
  const MileafGlassSurface.control({
    super.key,
    required this.child,
    this.borderRadius = MileafRadius.fullAll,
    this.forceSolid = false,
    this.elevated = true,
    this.blurBackdrop = true,
  }) : _control = true,
       _tintedSurface = null;

  /// 贴合正文和胶囊轮廓的色面玻璃。固定底色使密集信息在滚动中保持稳定。
  const MileafGlassSurface.tinted({
    super.key,
    required Color color,
    required this.borderRadius,
    required this.child,
  }) : _control = true,
       _tintedSurface = color,
       forceSolid = false,
       elevated = false,
       blurBackdrop = false;

  final Widget child;
  final BorderRadius borderRadius;
  final bool _control;
  final Color? _tintedSurface;
  final bool forceSolid;
  final bool elevated;
  final bool blurBackdrop;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    if (_control) return _buildControl(context, colors, hairline);
    return CustomPaint(
      painter: LiquidGlassShadowPainter(
        borderRadius: borderRadius,
        shadows: colors.glassShadow,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: _glassBackdrop(
          CustomPaint(
            painter: LiquidGlassPainter(
              borderRadius: borderRadius,
              fillTop: colors.glassFillTop,
              fillBottom: colors.glassFillBottom,
              sheen: colors.glassSheen,
              meniscus: colors.glassMeniscus,
              lip: colors.glassLip,
              edge: colors.glassEdge,
              sheenReach: MileafMaterialMetrics.glassSheenReach,
              sheenCore: MileafMaterialMetrics.glassSheenCore,
              meniscusStart: MileafMaterialMetrics.glassMeniscusStart,
              lipReach: MileafMaterialMetrics.glassLipReach,
              rimStroke: hairline * MileafMaterialMetrics.glassRimStroke,
              innerStroke: hairline * MileafMaterialMetrics.glassInnerStroke,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildControl(
    BuildContext context,
    MileafColors colors,
    double hairline,
  ) {
    final solid =
        forceSolid ||
        MediaQuery.highContrastOf(context) ||
        (DisplayPreferencesScope.maybeOf(context)?.useSolidMaterial ?? true);
    final tinted = _tintedSurface;
    final base =
        tinted ??
        (colors.isDark ? MileafPalette.slate900 : MileafPalette.paper0);
    final top =
        tinted ??
        base.withValues(alpha: MileafMaterialMetrics.controlGlassOpacity);
    final bottom =
        tinted ??
        base.withValues(alpha: MileafMaterialMetrics.controlGlassBottomOpacity);
    final sheen = tinted == null
        ? colors.glassSheen
        : Colors.white.withValues(
            alpha: colors.isDark
                ? MileafMaterialMetrics.cardGlassSheenDark
                : MileafMaterialMetrics.cardGlassSheenLight,
          );
    // 贴合屏幕的顶栏只保留页栏自己的下沿，环形受光边留给独立悬浮件。
    final paint = elevated || tinted != null
        ? CustomPaint(
            painter: LiquidGlassPainter(
              borderRadius: borderRadius,
              fillTop: top,
              fillBottom: bottom,
              sheen: sheen,
              sheenReach: tinted == null
                  ? MileafMaterialMetrics.glassSheenReach
                  : MileafMaterialMetrics.cardGlassSheenReach,
              sheenCore: tinted == null
                  ? MileafMaterialMetrics.glassSheenCore
                  : MileafMaterialMetrics.cardGlassSheenCore,
              meniscus: tinted == null ? colors.glassMeniscus : null,
              meniscusStart: MileafMaterialMetrics.glassMeniscusStart,
              edge: tinted == null ? colors.glassEdge : colors.tintedGlassEdge,
              rimStroke:
                  hairline *
                  (tinted == null ? MileafMaterialMetrics.glassRimStroke : 1),
              innerStroke:
                  hairline *
                  (tinted == null
                      ? MileafMaterialMetrics.glassInnerStroke
                      : .5),
            ),
          )
        : ColoredBox(color: top);
    final glass = blurBackdrop ? _glassBackdrop(paint) : paint;
    // 材质只在背板绘制，开关减少透明度时保留子控件与其焦点。
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: solid
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: borderRadius,
                      border: Border.all(
                        color: colors.controlBorder,
                        width: hairline,
                      ),
                    ),
                  )
                : !elevated
                ? ClipRRect(borderRadius: borderRadius, child: glass)
                : CustomPaint(
                    painter: LiquidGlassShadowPainter(
                      borderRadius: borderRadius,
                      shadows: colors.isDark
                          ? MileafElevation.controlGlassDark
                          : MileafElevation.controlGlassLight,
                    ),
                    child: ClipRRect(borderRadius: borderRadius, child: glass),
                  ),
          ),
        ),
        child,
      ],
    );
  }
}

Widget _glassBackdrop(Widget child) => BackdropFilter(
  filter: ui.ImageFilter.compose(
    outer: ui.ColorFilter.matrix(
      saturationMatrix(MileafMaterialMetrics.glassSaturation),
    ),
    inner: ui.ImageFilter.blur(
      sigmaX: MileafMaterialMetrics.glassBlur,
      sigmaY: MileafMaterialMetrics.glassBlur,
    ),
  ),
  child: child,
);

/// 选中目的地的镜片：比底栏更密的一层玻璃，自带更亮的顶边和一圈内缘。
///
/// [elevated] 为 false 时不投外影：顶栏的车辆胶囊与设置圆钮也用这层镜片，
/// 但 R24 规定静态容器没有阴影，阴影只给浮层。
///
/// [sheen] 只在底栏的选中镜片上打开。顶栏镜片贴在磨砂顶栏上、不叠在内容上，
/// 加受光带会改变顶栏观感（规格 §3：顶栏仍按 R14），因此默认关闭。
class MileafGlassLens extends StatelessWidget {
  const MileafGlassLens({
    super.key,
    required this.child,
    this.borderRadius = MileafRadius.fullAll,
    this.elevated = true,
    this.sheen = false,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final bool elevated;
  final bool sheen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    return CustomPaint(
      painter: LiquidGlassShadowPainter(
        borderRadius: borderRadius,
        shadows: elevated ? colors.glassLensShadow : const [],
      ),
      child: CustomPaint(
        painter: LiquidGlassPainter(
          borderRadius: borderRadius,
          fillTop: colors.glassLensTop,
          fillBottom: colors.glassLensBottom,
          sheen: sheen ? colors.glassLensSheen : null,
          sheenReach: MileafMaterialMetrics.glassLensSheenReach,
          sheenCore: MileafMaterialMetrics.glassLensSheenCore,
          edge: colors.glassLensEdge,
          rimStroke: hairline * MileafMaterialMetrics.glassLensRimStroke,
          innerStroke: hairline * MileafMaterialMetrics.glassInnerStroke,
        ),
        child: child,
      ),
    );
  }
}

/// 只在玻璃外侧投影：内部被挖掉，薄薄的玻璃不会把身下的阴影透出来。
class LiquidGlassShadowPainter extends CustomPainter {
  const LiquidGlassShadowPainter({
    required this.borderRadius,
    required this.shadows,
  });

  final BorderRadius borderRadius;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    if (shadows.isEmpty) return;
    final rect = Offset.zero & size;
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect.inflate(MileafMaterialMetrics.glassShadowMargin)),
      Path()..addRRect(borderRadius.toRRect(rect)),
    );
    canvas.save();
    canvas.clipPath(outside, doAntiAlias: true);
    for (final shadow in shadows) {
      final body = borderRadius.toRRect(
        rect.inflate(shadow.spreadRadius).shift(shadow.offset),
      );
      canvas.drawPath(
        Path()..addRRect(body),
        Paint()
          ..color = shadow.color
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            shadow.blurRadius * MileafMaterialMetrics.glassShadowSigmaScale,
          ),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LiquidGlassShadowPainter old) =>
      borderRadius != old.borderRadius || !sameShadows(shadows, old.shadows);
}

/// Paints the glass body and its lit edges into the bounds of its child.
class LiquidGlassPainter extends CustomPainter {
  const LiquidGlassPainter({
    required this.borderRadius,
    required this.fillTop,
    required this.fillBottom,
    required this.edge,
    required this.rimStroke,
    required this.innerStroke,
    this.sheen,
    this.meniscus,
    this.lip,
    this.sheenReach = 0,
    this.sheenCore = 0,
    this.meniscusStart = 1,
    this.lipReach = 0,
    this.innerReach = MileafMaterialMetrics.glassInnerReach,
  }) : assert(
         sheen == null || sheenReach > sheenCore,
         '受光带必须真的画出来：reach 要大于 core，否则等于两条看不见的带（L11）',
       ),
       assert(lip == null || lipReach > 0, '端头增厚给了颜色却没有范围，等于画了看不见的带（L11）'),
       assert(
         meniscus == null || meniscusStart < 1,
         '弯月给了颜色却从 100% 才开始，等于画了看不见的带（L11）',
       );

  final BorderRadius borderRadius;
  final Color fillTop;
  final Color fillBottom;
  final GlassEdge edge;
  final Color? sheen;
  final Color? meniscus;
  final Color? lip;
  final double sheenReach;
  final double sheenCore;
  final double meniscusStart;
  final double lipReach;
  final double innerReach;
  final double rimStroke;
  final double innerStroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fillTop, fillBottom],
        ).createShader(rect),
    );
    final sheenColor = sheen;
    if (sheenColor != null) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = _vertical(
            rect,
            stops: [0, sheenCore, sheenReach],
            colors: [
              sheenColor,
              sheenColor.withValues(
                alpha: sheenColor.a * MileafMaterialMetrics.glassSheenCoreAlpha,
              ),
              sheenColor.withValues(alpha: 0),
            ],
          ),
      );
    }
    final meniscusColor = meniscus;
    if (meniscusColor != null) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = _vertical(
            rect,
            stops: [meniscusStart, 1],
            colors: [meniscusColor.withValues(alpha: 0), meniscusColor],
          ),
      );
    }
    // 端头增厚：只在胶囊两端、贴着圆角的一竖条，横向渐变到中间透明。
    final lipColor = lip;
    if (lipColor != null && lipReach > 0) {
      final clear = lipColor.withValues(alpha: 0);
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [0, lipReach, 1 - lipReach, 1],
            colors: [lipColor, clear, clear, lipColor],
          ).createShader(rect),
      );
      canvas.restore();
    }
    // 受光边缘：竖着读光——顶边最亮、两侧衰减、底沿最暗。斜向渐变会让
    // 左侧比右侧亮一档，光就从「上方」漂成了「左上角」。
    canvas.drawRRect(
      rrect.deflate(rimStroke / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rimStroke
        ..isAntiAlias = true
        ..shader = _vertical(
          rect,
          stops: const [0, .5, 1],
          colors: [edge.top, edge.side, edge.bottom],
        ),
    );
    canvas.drawRRect(
      rrect.deflate(rimStroke + innerStroke / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = innerStroke
        ..isAntiAlias = true
        ..shader = _vertical(
          rect,
          stops: [innerReach, 1],
          colors: [edge.inner.withValues(alpha: 0), edge.inner],
        ),
    );
  }

  static Shader _vertical(
    Rect rect, {
    required List<double> stops,
    required List<Color> colors,
  }) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: stops,
    colors: colors,
  ).createShader(rect);

  @override
  bool shouldRepaint(covariant LiquidGlassPainter old) =>
      borderRadius != old.borderRadius ||
      fillTop != old.fillTop ||
      fillBottom != old.fillBottom ||
      edge != old.edge ||
      sheen != old.sheen ||
      meniscus != old.meniscus ||
      lip != old.lip ||
      sheenReach != old.sheenReach ||
      sheenCore != old.sheenCore ||
      meniscusStart != old.meniscusStart ||
      lipReach != old.lipReach ||
      innerReach != old.innerReach ||
      rimStroke != old.rimStroke ||
      innerStroke != old.innerStroke;
}

/// Two alpha-based shadow lists compare by value, not identity.
bool sameShadows(List<BoxShadow> a, List<BoxShadow> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// sRGB saturation matrix for [ui.ColorFilter.matrix].
List<double> saturationMatrix(double saturation) {
  const lr = .2126, lg = .7152, lb = .0722;
  final inverse = 1 - saturation;
  return <double>[
    lr * inverse + saturation,
    lg * inverse,
    lb * inverse,
    0,
    0,
    lr * inverse,
    lg * inverse + saturation,
    lb * inverse,
    0,
    0,
    lr * inverse,
    lg * inverse,
    lb * inverse + saturation,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}
