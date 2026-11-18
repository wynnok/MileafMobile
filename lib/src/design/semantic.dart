import 'package:flutter/material.dart';

import 'tokens.dart';

/// Semantic colour layer for「行笺」appearance v2.
///
/// Pages consume these tokens (or the components built on them); they never
/// reference primitive hex values directly. Every colour is neutral except the
/// accent, which has two strengths: [accent] for graphics (≥3:1) and
/// [accentStrong] for text and solid fills (≥4.5:1).
@immutable
class MileafColors extends ThemeExtension<MileafColors> {
  const MileafColors({
    required this.isDark,
    required this.canvas,
    required this.hero,
    required this.surface,
    required this.surfaceRaised,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.textOnAccent,
    required this.accent,
    required this.accentStrong,
    required this.accentPressed,
    required this.accentSoft,
    required this.accentHero,
    required this.reference,
    required this.warning,
    required this.error,
    required this.line,
    required this.lineStrong,
    required this.heroText,
    required this.heroMuted,
    required this.heroFaint,
    required this.nav,
    required this.scrim,
    required this.skeleton,
    required this.sheetShadow,
  });

  /// R23.1：功能文字两级的次级名，值即现有 textMuted（浅 #5A6672、深
  /// #9AA5B1）。textFaint 只用于占位符、禁用态和非文字装饰。
  Color get textSecondary => textMuted;

  /// R23.5：输入与可操作边界用更轻的独立中性色（候选 #808A95/#626C78 经
  /// 合成实测被否决，见 AP01 交接偏差账本；现值对全部相邻底色 ≥3:1）。
  Color get controlBorder => isDark
      ? MileafPalette.controlBorderDark
      : MileafPalette.controlBorderLight;

  /// Neutral inset track and its single selected surface.
  Color get segmentTrack =>
      isDark ? surfaceRaised : MileafPalette.segmentTrackLight;
  Color get segmentSelected =>
      isDark ? MileafPalette.segmentSelectedDark : surface;

  Color get navigationSolid => isDark ? surfaceRaised : surface;

  /// 实色底栏上的选中底。底栏本身就是 surface，所以这里用分段轨道的中性档，
  /// 否则会出现「白底浮白块」——选中只剩颜色，没有位置标记。
  Color get navigationSelection => isDark
      ? MileafPalette.segmentSelectedDark
      : MileafPalette.segmentTrackLight;
  Color get navigationBorder => isDark ? lineStrong : line;

  /// 根底栏未选目的地的文字与图标：玻璃与实色两条路径共用，只服务根底栏。
  Color get navigationLabel => isDark
      ? MileafPalette.navigationLabelDark
      : MileafPalette.navigationLabelLight;
  Color get navigationHighlight =>
      isDark ? MileafPalette.navHighlightDark : MileafPalette.navHighlightLight;
  List<BoxShadow> get navigationShadow =>
      isDark ? MileafElevation.navigationDark : MileafElevation.navigationLight;

  /// 液态玻璃（ADR 0013）：玻璃体上下沿、顶部受光带、下沿弯月、端头增厚。
  ///
  /// 玻璃只叠加本模式的中性色——浅色用白、深色用近黑——所以它只会把
  /// 背后内容朝 canvas 方向推，正文与图标对比不因透明度下降。
  Color get glassFillTop =>
      isDark ? MileafPalette.glassDarkTop : MileafPalette.glassLightTop;
  Color get glassFillBottom =>
      isDark ? MileafPalette.glassDarkBottom : MileafPalette.glassLightBottom;
  Color get glassSheen =>
      isDark ? MileafPalette.glassDarkSheen : MileafPalette.glassLightSheen;
  Color get glassMeniscus => isDark
      ? MileafPalette.glassDarkMeniscus
      : MileafPalette.glassLightMeniscus;

  /// 端头增厚：胶囊两端的弯曲侧壁沿视线方向更厚，受光更亮（只压左右两端）。
  Color get glassLip =>
      isDark ? MileafPalette.glassDarkLip : MileafPalette.glassLightLip;

  /// 受光边缘：顶边最亮、两侧衰减、底沿最暗。
  GlassEdge get glassEdge => isDark
      ? const GlassEdge(
          top: MileafPalette.glassRimDarkTop,
          side: MileafPalette.glassRimDarkSide,
          bottom: MileafPalette.glassRimDarkBottom,
          inner: MileafPalette.glassInnerDark,
        )
      : const GlassEdge(
          top: MileafPalette.glassRimLightTop,
          side: MileafPalette.glassRimLightSide,
          bottom: MileafPalette.glassRimLightBottom,
          inner: MileafPalette.glassInnerLight,
        );

  /// 选中镜片：比底栏更密的一层玻璃，自带更亮的顶边与自己的受光带。
  ///
  /// 受光带只在底栏镜片打开（`MileafGlassLens(sheen: true)`）；顶栏的车辆胶囊与
  /// 设置圆钮贴在磨砂顶栏上、不叠在内容上，仍按规格 §3 的顶栏取值。
  Color get glassLensSheen => isDark
      ? MileafPalette.glassDarkLensSheen
      : MileafPalette.glassLightLensSheen;

  Color get glassLensTop =>
      isDark ? MileafPalette.glassDarkLensTop : MileafPalette.glassLightLensTop;
  Color get glassLensBottom => isDark
      ? MileafPalette.glassDarkLensBottom
      : MileafPalette.glassLightLensBottom;
  GlassEdge get glassLensEdge => isDark
      ? const GlassEdge(
          top: MileafPalette.glassLensRimDarkTop,
          side: MileafPalette.glassLensRimDarkSide,
          bottom: MileafPalette.glassLensRimDarkBottom,
          inner: MileafPalette.glassLensInnerDark,
        )
      : const GlassEdge(
          top: MileafPalette.glassLensRimLightTop,
          side: MileafPalette.glassLensRimLightSide,
          bottom: MileafPalette.glassLensRimLightBottom,
          inner: MileafPalette.glassLensInnerLight,
        );

  List<BoxShadow> get glassShadow => isDark
      ? MileafElevation.glassNavigationDark
      : MileafElevation.glassNavigationLight;
  List<BoxShadow> get glassLensShadow =>
      isDark ? MileafElevation.glassLensDark : MileafElevation.glassLensLight;

  /// Dark: neutral cold black, one accent for graphics and text.
  const MileafColors.dark()
    : isDark = true,
      canvas = MileafPalette.slate950,
      hero = MileafPalette.slate900,
      surface = MileafPalette.slate900,
      surfaceRaised = MileafPalette.slate850,
      text = MileafPalette.mist0,
      textMuted = MileafPalette.mist500,
      textFaint = MileafPalette.mist600,
      textOnAccent = MileafPalette.slate950,
      accent = MileafPalette.azure300,
      accentStrong = MileafPalette.azure300,
      accentPressed = MileafPalette.azure300,
      accentSoft = MileafPalette.accentSoftDark,
      accentHero = MileafPalette.azure300,
      reference = MileafPalette.steel300,
      warning = MileafPalette.amber400,
      error = MileafPalette.red400,
      line = MileafPalette.lineDark,
      lineStrong = MileafPalette.lineStrongDark,
      heroText = MileafPalette.mist0,
      heroMuted = MileafPalette.mist500,
      heroFaint = MileafPalette.mist600,
      nav = MileafPalette.navDark,
      scrim = MileafPalette.scrimDark,
      skeleton = MileafPalette.skeletonDark,
      sheetShadow = MileafElevation.sheetDark;

  /// Light uses the same content hierarchy as the rest of the page.
  const MileafColors.light()
    : isDark = false,
      canvas = MileafPalette.paper50,
      hero = MileafPalette.paper0,
      surface = MileafPalette.paper0,
      surfaceRaised = MileafPalette.paper0,
      text = MileafPalette.graphite900,
      textMuted = MileafPalette.graphite600,
      textFaint = MileafPalette.graphite500,
      textOnAccent = MileafPalette.paper0,
      accent = MileafPalette.azure500,
      accentStrong = MileafPalette.azure600,
      accentPressed = MileafPalette.azure600,
      accentSoft = MileafPalette.accentSoftLight,
      accentHero = MileafPalette.azure500,
      reference = MileafPalette.steel500,
      warning = MileafPalette.amber500,
      error = MileafPalette.red600,
      line = MileafPalette.lineLight,
      lineStrong = MileafPalette.lineStrongLight,
      heroText = MileafPalette.graphite900,
      heroMuted = MileafPalette.graphite600,
      heroFaint = MileafPalette.graphite500,
      nav = MileafPalette.navLight,
      scrim = MileafPalette.scrimLight,
      skeleton = MileafPalette.skeletonLight,
      sheetShadow = MileafElevation.sheetLight;

  final bool isDark;
  final Color canvas;
  final Color hero;
  final Color surface;
  final Color surfaceRaised;
  final Color text;
  final Color textMuted;
  final Color textFaint;
  final Color textOnAccent;

  /// Graphics only: chart lines, progress, indicators, icons, switches.
  final Color accent;

  /// Text and solid fills: links, selected labels, primary button fill.
  final Color accentStrong;

  /// Pressed accent. Unused since §7.2 routes press feedback to `accentSoft`;
  /// kept only so this batch does not change the token surface (AV08 may drop it).
  final Color accentPressed;

  final Color accentSoft;
  final Color accentHero;
  final Color reference;
  final Color warning;
  final Color error;
  final Color line;
  final Color lineStrong;
  final Color heroText;
  final Color heroMuted;
  final Color heroFaint;
  final Color nav;
  final Color scrim;
  final Color skeleton;
  final List<BoxShadow> sheetShadow;

  static MileafColors of(BuildContext context) {
    final colors = Theme.of(context).extension<MileafColors>();
    assert(colors != null, 'MileafColors extension missing from ThemeData');
    return colors ??
        (Theme.of(context).brightness == Brightness.dark
            ? const MileafColors.dark()
            : const MileafColors.light());
  }

  /// AC / DC / unknown: primary, a second step of the same hue, neutral.
  ///
  /// Only one accent colour exists. The second series used to be `accent` at
  /// 50 %, which composites to 1.8:1 over paper and 2.8:1 over the dark
  /// surface — below the 3:1 graphics floor in both modes (AV06). `azure600`
  /// keeps a single hue while measuring 5.4:1 on paper and 3.1:1 on the dark
  /// surface, and 1.7/2.4:1 away from the primary so the pair never merges.
  Color get seriesPrimary => accent;
  Color get seriesSecondary => MileafPalette.azure600;
  Color get seriesNeutral => textFaint;

  /// Focus ring is the only 2px accent stroke.
  Color get focusRing => accentStrong;

  /// 4% (dark) / 6% (light) press overlay on content rows.
  Color get pressOverlay =>
      isDark ? MileafPalette.pressOverlayDark : MileafPalette.pressOverlayLight;

  @override
  MileafColors copyWith({
    bool? isDark,
    Color? canvas,
    Color? hero,
    Color? surface,
    Color? surfaceRaised,
    Color? text,
    Color? textMuted,
    Color? textFaint,
    Color? textOnAccent,
    Color? accent,
    Color? accentStrong,
    Color? accentPressed,
    Color? accentSoft,
    Color? accentHero,
    Color? reference,
    Color? warning,
    Color? error,
    Color? line,
    Color? lineStrong,
    Color? heroText,
    Color? heroMuted,
    Color? heroFaint,
    Color? nav,
    Color? scrim,
    Color? skeleton,
    List<BoxShadow>? sheetShadow,
  }) => MileafColors(
    isDark: isDark ?? this.isDark,
    canvas: canvas ?? this.canvas,
    hero: hero ?? this.hero,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    text: text ?? this.text,
    textMuted: textMuted ?? this.textMuted,
    textFaint: textFaint ?? this.textFaint,
    textOnAccent: textOnAccent ?? this.textOnAccent,
    accent: accent ?? this.accent,
    accentStrong: accentStrong ?? this.accentStrong,
    accentPressed: accentPressed ?? this.accentPressed,
    accentSoft: accentSoft ?? this.accentSoft,
    accentHero: accentHero ?? this.accentHero,
    reference: reference ?? this.reference,
    warning: warning ?? this.warning,
    error: error ?? this.error,
    line: line ?? this.line,
    lineStrong: lineStrong ?? this.lineStrong,
    heroText: heroText ?? this.heroText,
    heroMuted: heroMuted ?? this.heroMuted,
    heroFaint: heroFaint ?? this.heroFaint,
    nav: nav ?? this.nav,
    scrim: scrim ?? this.scrim,
    skeleton: skeleton ?? this.skeleton,
    sheetShadow: sheetShadow ?? this.sheetShadow,
  );

  @override
  MileafColors lerp(covariant MileafColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return MileafColors(
      isDark: t < .5 ? isDark : other.isDark,
      canvas: mix(canvas, other.canvas),
      hero: mix(hero, other.hero),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      text: mix(text, other.text),
      textMuted: mix(textMuted, other.textMuted),
      textFaint: mix(textFaint, other.textFaint),
      textOnAccent: mix(textOnAccent, other.textOnAccent),
      accent: mix(accent, other.accent),
      accentStrong: mix(accentStrong, other.accentStrong),
      accentPressed: mix(accentPressed, other.accentPressed),
      accentSoft: mix(accentSoft, other.accentSoft),
      accentHero: mix(accentHero, other.accentHero),
      reference: mix(reference, other.reference),
      warning: mix(warning, other.warning),
      error: mix(error, other.error),
      line: mix(line, other.line),
      lineStrong: mix(lineStrong, other.lineStrong),
      heroText: mix(heroText, other.heroText),
      heroMuted: mix(heroMuted, other.heroMuted),
      heroFaint: mix(heroFaint, other.heroFaint),
      nav: mix(nav, other.nav),
      scrim: mix(scrim, other.scrim),
      skeleton: mix(skeleton, other.skeleton),
      sheetShadow:
          BoxShadow.lerpList(sheetShadow, other.sheetShadow, t) ?? const [],
    );
  }
}

/// 一圈受光边缘：顶边、两侧、底沿，以及压在下半圈的内缘细线。
///
/// 浅色玻璃压在亮内容上时边缘收暗（内缘取石墨），深色玻璃压在暗内容上时
/// 边缘提亮（内缘取白）；同一个 [GlassEdge] 因此能表达两种极性。
@immutable
class GlassEdge {
  const GlassEdge({
    required this.top,
    required this.side,
    required this.bottom,
    required this.inner,
  });

  final Color top;
  final Color side;
  final Color bottom;
  final Color inner;

  @override
  bool operator ==(Object other) =>
      other is GlassEdge &&
      other.top == top &&
      other.side == side &&
      other.bottom == bottom &&
      other.inner == inner;

  @override
  int get hashCode => Object.hash(top, side, bottom, inner);
}

extension MileafColorsContext on BuildContext {
  /// Shorthand for the semantic palette: `context.colors.accent`.
  MileafColors get colors => MileafColors.of(this);
}
