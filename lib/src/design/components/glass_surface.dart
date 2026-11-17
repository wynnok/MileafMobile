import 'dart:ui' as ui;

import 'package:flutter/material.dart';

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
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    return CustomPaint(
      painter: LiquidGlassShadowPainter(
        borderRadius: borderRadius,
        shadows: colors.glassShadow,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ui.ImageFilter.compose(
            outer: ui.ColorFilter.matrix(
              saturationMatrix(MileafMaterialMetrics.glassSaturation),
            ),
            inner: ui.ImageFilter.blur(
              sigmaX: MileafMaterialMetrics.glassBlur,
              sigmaY: MileafMaterialMetrics.glassBlur,
            ),
          ),
          child: CustomPaint(
            painter: LiquidGlassPainter(
              borderRadius: borderRadius,
              fillTop: colors.glassFillTop,
              fillBottom: colors.glassFillBottom,
              sheen: colors.glassSheen,
              meniscus: colors.glassMeniscus,
              edge: colors.glassEdge,
              rimStroke: hairline * MileafMaterialMetrics.glassRimStroke,
              innerStroke: hairline * MileafMaterialMetrics.glassInnerStroke,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 选中目的地的镜片：比底栏更密的一层玻璃，自带更亮的顶边和一圈内缘。
///
/// [elevated] 为 false 时不投外影：顶栏的车辆胶囊与设置圆钮也用这层镜片，
/// 但 R24 规定静态容器没有阴影，阴影只给浮层。
class MileafGlassLens extends StatelessWidget {
  const MileafGlassLens({
    super.key,
    required this.child,
    this.borderRadius = MileafRadius.fullAll,
    this.elevated = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final bool elevated;

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
    this.sheenReach = 0,
    this.meniscusStart = 1,
  });

  final BorderRadius borderRadius;
  final Color fillTop;
  final Color fillBottom;
  final GlassEdge edge;
  final Color? sheen;
  final Color? meniscus;
  final double sheenReach;
  final double meniscusStart;
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
            stops: [0, sheenReach],
            colors: [sheenColor, sheenColor.withValues(alpha: 0)],
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
    canvas.drawRRect(
      rrect.deflate(rimStroke / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rimStroke
        ..isAntiAlias = true
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, .5, 1],
          colors: [edge.top, edge.side, edge.bottom],
        ).createShader(rect),
    );
    canvas.drawRRect(
      rrect.deflate(rimStroke + innerStroke / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = innerStroke
        ..isAntiAlias = true
        ..shader = _vertical(
          rect,
          stops: [MileafMaterialMetrics.glassInnerReach, 1],
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
      sheenReach != old.sheenReach ||
      meniscusStart != old.meniscusStart ||
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
