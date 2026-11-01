import 'package:flutter/material.dart';

import 'tokens.dart';

/// Semantic colour layer for A「夜航」.
///
/// Pages consume these tokens (or the components built on them); they never
/// reference primitive hex values directly.
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

  /// Dark is the default and the design baseline.
  const MileafColors.dark()
    : isDark = true,
      canvas = MileafPalette.canvasDark,
      hero = MileafPalette.jade900,
      surface = MileafPalette.surfaceDark,
      surfaceRaised = MileafPalette.surfaceRaisedDark,
      text = MileafPalette.ink0,
      textMuted = MileafPalette.ink500,
      textFaint = MileafPalette.ink600,
      textOnAccent = MileafPalette.jadeOn,
      accent = MileafPalette.jade300,
      accentPressed = MileafPalette.jade350,
      accentSoft = MileafPalette.accentSoftDark,
      accentHero = MileafPalette.jade300,
      reference = MileafPalette.sand300,
      warning = MileafPalette.amber400,
      error = MileafPalette.clay400,
      line = MileafPalette.lineDark,
      lineStrong = MileafPalette.lineStrongDark,
      heroText = MileafPalette.ink0,
      heroMuted = MileafPalette.heroMuted,
      heroFaint = MileafPalette.heroFaint,
      nav = MileafPalette.navDark,
      scrim = MileafPalette.scrimDark,
      skeleton = MileafPalette.skeletonDark,
      sheetShadow = MileafElevation.sheetDark;

  /// Light is not an inversion: the car hero stays dark.
  const MileafColors.light()
    : isDark = false,
      canvas = MileafPalette.stone50,
      hero = MileafPalette.jade800,
      surface = MileafPalette.stone0,
      surfaceRaised = MileafPalette.stoneRaised,
      text = MileafPalette.ink900,
      textMuted = MileafPalette.ink700,
      textFaint = MileafPalette.ink750,
      textOnAccent = MileafPalette.stone0,
      accent = MileafPalette.jade500,
      accentPressed = MileafPalette.jade550,
      accentSoft = MileafPalette.stoneSoft,
      accentHero = MileafPalette.jade300,
      reference = MileafPalette.sand500,
      warning = MileafPalette.sand700,
      error = MileafPalette.clay600,
      line = MileafPalette.lineLight,
      lineStrong = MileafPalette.lineStrongLight,
      heroText = MileafPalette.ink0,
      heroMuted = MileafPalette.heroMuted,
      heroFaint = MileafPalette.heroFaint,
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
  final Color accent;
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

  /// AC / DC / unknown: primary, 50% primary, neutral. No second accent.
  Color get seriesPrimary => accent;
  Color get seriesSecondary => accent.withValues(alpha: .5);
  Color get seriesNeutral => textFaint;

  /// Focus ring is the only 2px accent stroke.
  Color get focusRing => accent.withValues(alpha: .6);

  /// 4% press overlay on content rows.
  Color get pressOverlay =>
      isDark ? MileafPalette.pressOverlay : text.withValues(alpha: .06);

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
      sheetShadow: BoxShadow.lerpList(sheetShadow, other.sheetShadow, t) ?? const [],
    );
  }
}

extension MileafColorsContext on BuildContext {
  /// Shorthand for the semantic palette: `context.colors.accent`.
  MileafColors get colors => MileafColors.of(this);
}
