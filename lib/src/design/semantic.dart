import 'dart:math' as math;

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

  /// Input and actionable boundaries use an opaque neutral with measured contrast.
  Color get controlBorder => textMuted;

  /// Neutral inset track and its single selected surface.
  Color get segmentTrack =>
      isDark ? surfaceRaised : MileafPalette.segmentTrackLight;
  Color get segmentSelected =>
      isDark ? MileafPalette.segmentSelectedDark : surface;

  /// Dark: neutral cold black, one accent for graphics and text.
  const MileafColors.dark()
    : isDark = true,
      canvas = MileafPalette.slate950,
      hero = MileafPalette.slate1000,
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
      heroMuted = MileafPalette.mist400,
      heroFaint = MileafPalette.mist550,
      nav = MileafPalette.navDark,
      scrim = MileafPalette.scrimDark,
      skeleton = MileafPalette.skeletonDark,
      sheetShadow = MileafElevation.sheetDark;

  /// Light is not an inversion: the hero keeps its dark anchor, the paper
  /// is cool grey rather than warm paper.
  const MileafColors.light()
    : isDark = false,
      canvas = MileafPalette.paper50,
      hero = MileafPalette.heroLight,
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
      accentHero = MileafPalette.azure300,
      reference = MileafPalette.steel500,
      warning = MileafPalette.amber500,
      error = MileafPalette.red600,
      line = MileafPalette.lineLight,
      lineStrong = MileafPalette.lineStrongLight,
      heroText = MileafPalette.mist0,
      heroMuted = MileafPalette.mist400,
      heroFaint = MileafPalette.mist550,
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

  /// Hero form is derived, never passed in (Spec §6.1): a hero that sits more
  /// than 20 L\* away from the canvas is a card on that canvas, otherwise it is
  /// the same continuous material. Current values: dark Δ0.61 → full bleed,
  /// light Δ93.58 → card.
  ///
  /// Known transient: during the 200ms appearance swap `MileafColors.lerp`
  /// feeds interpolated hero/canvas here, so the form flips once, late in the
  /// animation, when ΔL\* crosses 20. Any switch between two structurally
  /// different hero forms flips once; moving or removing the flip would need
  /// the form itself animated (Spec §11 forbids hero entry animation, and
  /// batch 2 was scoped to no structural change).
  bool get heroAsCard => (_lStar(hero) - _lStar(canvas)).abs() > 20;

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

extension MileafColorsContext on BuildContext {
  /// Shorthand for the semantic palette: `context.colors.accent`.
  MileafColors get colors => MileafColors.of(this);
}

/// CIELAB L\* of an opaque colour; only the hero form rule needs it (§6.1).
double _lStar(Color color) {
  final y = color.computeLuminance();
  return y > 0.008856 ? 116 * math.pow(y, 1 / 3).toDouble() - 16 : 903.3 * y;
}
