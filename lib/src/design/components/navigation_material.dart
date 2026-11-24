import 'dart:ui';

import 'package:flutter/material.dart';

import '../display_preferences.dart';
import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import 'glass_surface.dart';

/// 导航材质的两种职责（R14、ADR 0013）。
enum NavigationMaterialStyle {
  /// 随内容滚动的顶栏：与 canvas 同调的磨砂，背景只作为低频色块透出。
  frosted,

  /// 内容滚至顶栏下方时使用有界的控件玻璃。
  chrome,

  /// 悬浮在页面之上的根底栏：液态玻璃，高透、有受光边缘。
  glass,
}

/// Bounded navigation material. Content and form surfaces stay opaque.
class NavigationMaterial extends StatelessWidget {
  const NavigationMaterial({
    super.key,
    required this.child,
    this.borderRadius = MileafRadius.surfaceAll,
    this.forceSolid = false,
    this.solidColor,
    this.style = NavigationMaterialStyle.frosted,
    this.elevated = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final bool forceSolid;
  final Color? solidColor;
  final NavigationMaterialStyle style;

  /// 为 false 时不投导航阴影（R24：阴影只给浮层；贴在内容上的二级导航不属浮层）。
  final bool elevated;

  /// 实色路径的唯一判定：强制、高对比、未知或已请求减少透明度。
  ///
  /// 材质与它的子层（如选中镜片）必须用同一判定，否则会出现「实色底栏里
  /// 浮着一层玻璃镜片」的合成。
  static bool resolvesSolid(BuildContext context, {bool forceSolid = false}) {
    final preferences = DisplayPreferencesScope.maybeOf(context);
    return forceSolid ||
        MediaQuery.highContrastOf(context) ||
        (preferences?.useSolidMaterial ?? true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    final solid = resolvesSolid(context, forceSolid: forceSolid);
    if (style == NavigationMaterialStyle.glass && !solid) {
      return MileafGlassSurface(borderRadius: borderRadius, child: child);
    }
    if (style == NavigationMaterialStyle.chrome && !solid) {
      return MileafGlassSurface.control(
        borderRadius: borderRadius,
        elevated: false,
        child: child,
      );
    }
    // 边线画在 foreground：写在 decoration 里会把容器撑大一个 hairline，
    // 实色底栏就会比玻璃底栏高 1px、选中镜片窄 1px（L08）。
    final content = AnimatedContainer(
      duration: MileafLayout.motion(context, MileafDurations.chrome),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: solid ? solidColor ?? colors.navigationSolid : colors.nav,
        borderRadius: borderRadius,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(color: colors.navigationBorder, width: hairline),
      ),
      child: child,
    );
    final layered = Stack(
      children: [
        content,
        if (!solid)
          PositionedDirectional(
            start: 0,
            end: 0,
            top: 0,
            child: ColoredBox(
              color: colors.navigationHighlight,
              child: SizedBox(height: hairline),
            ),
          ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: solid || !elevated ? const [] : colors.navigationShadow,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: solid
            ? layered
            : BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: MileafMaterialMetrics.navigationBlur,
                  sigmaY: MileafMaterialMetrics.navigationBlur,
                ),
                child: layered,
              ),
      ),
    );
  }
}
