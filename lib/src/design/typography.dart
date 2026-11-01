import 'package:flutter/material.dart';

import 'semantic.dart';
import 'tokens.dart';

TextStyle _style({
  required double size,
  required double height,
  required FontWeight weight,
  double tracking = 0,
  required Color color,
}) => TextStyle(
  fontFamily: MileafType.family,
  fontFamilyFallback: MileafType.fallback,
  fontSize: size,
  height: height / size,
  fontWeight: weight,
  letterSpacing: tracking * size,
  color: color,
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// Five-level type scale plus the `metric-md` / `micro` size variants.
///
/// Every numeric style carries tabular figures, so pages never opt in per
/// number.
@immutable
class MileafTextStyles extends ThemeExtension<MileafTextStyles> {
  const MileafTextStyles({
    required this.display,
    required this.metricLg,
    required this.metricMd,
    required this.title,
    required this.body,
    required this.label,
    required this.micro,
  });

  factory MileafTextStyles.resolve(MileafColors colors) => MileafTextStyles(
    display: _style(
      size: MileafType.displaySize,
      height: MileafType.displayHeight,
      weight: MileafType.weightMedium,
      tracking: MileafType.displayTracking,
      color: colors.text,
    ),
    metricLg: _style(
      size: MileafType.metricLgSize,
      height: MileafType.metricLgHeight,
      weight: MileafType.weightMedium,
      tracking: MileafType.metricLgTracking,
      color: colors.text,
    ),
    metricMd: _style(
      size: MileafType.metricMdSize,
      height: MileafType.metricMdHeight,
      weight: MileafType.weightMedium,
      tracking: MileafType.metricMdTracking,
      color: colors.text,
    ),
    title: _style(
      size: MileafType.titleSize,
      height: MileafType.titleHeight,
      weight: MileafType.weightSemiBold,
      tracking: MileafType.titleTracking,
      color: colors.text,
    ),
    body: _style(
      size: MileafType.bodySize,
      height: MileafType.bodyHeight,
      weight: MileafType.weightRegular,
      color: colors.text,
    ),
    label: _style(
      size: MileafType.labelSize,
      height: MileafType.labelHeight,
      weight: MileafType.weightMedium,
      tracking: MileafType.labelTracking,
      color: colors.textMuted,
    ),
    micro: _style(
      size: MileafType.microSize,
      height: MileafType.microHeight,
      weight: MileafType.weightMedium,
      tracking: MileafType.microTracking,
      color: colors.textFaint,
    ),
  );

  final TextStyle display;
  final TextStyle metricLg;
  final TextStyle metricMd;
  final TextStyle title;
  final TextStyle body;
  final TextStyle label;
  final TextStyle micro;

  static MileafTextStyles of(BuildContext context) {
    final styles = Theme.of(context).extension<MileafTextStyles>();
    assert(styles != null, 'MileafTextStyles extension missing from ThemeData');
    return styles ??
        MileafTextStyles.resolve(
          Theme.of(context).brightness == Brightness.dark
              ? const MileafColors.dark()
              : const MileafColors.light(),
        );
  }

  /// Unit style: one or two levels below the number and never louder.
  TextStyle unitColor(Color color) => label.copyWith(color: color);

  /// Material text theme for built-in widgets; still five levels.
  TextTheme materialTheme(MileafColors colors) {
    final base = TextTheme(
      displayLarge: display,
      displayMedium: metricLg,
      displaySmall: metricMd,
      headlineLarge: metricLg,
      headlineMedium: metricMd,
      headlineSmall: title,
      titleLarge: title,
      titleMedium: title.copyWith(fontWeight: MileafType.weightMedium),
      titleSmall: body.copyWith(fontWeight: MileafType.weightSemiBold),
      bodyLarge: body,
      bodyMedium: body,
      bodySmall: micro.copyWith(color: colors.textMuted),
      labelLarge: label,
      labelMedium: label,
      labelSmall: micro,
    );
    return base.apply(
      bodyColor: colors.text,
      displayColor: colors.text,
      fontFamily: MileafType.family,
      fontFamilyFallback: MileafType.fallback,
    );
  }

  @override
  MileafTextStyles copyWith({
    TextStyle? display,
    TextStyle? metricLg,
    TextStyle? metricMd,
    TextStyle? title,
    TextStyle? body,
    TextStyle? label,
    TextStyle? micro,
  }) => MileafTextStyles(
    display: display ?? this.display,
    metricLg: metricLg ?? this.metricLg,
    metricMd: metricMd ?? this.metricMd,
    title: title ?? this.title,
    body: body ?? this.body,
    label: label ?? this.label,
    micro: micro ?? this.micro,
  );

  @override
  MileafTextStyles lerp(covariant MileafTextStyles? other, double t) {
    if (other == null) return this;
    TextStyle mix(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return MileafTextStyles(
      display: mix(display, other.display),
      metricLg: mix(metricLg, other.metricLg),
      metricMd: mix(metricMd, other.metricMd),
      title: mix(title, other.title),
      body: mix(body, other.body),
      label: mix(label, other.label),
      micro: mix(micro, other.micro),
    );
  }
}

extension MileafTextContext on BuildContext {
  /// Shorthand for the five-level type scale: `context.type.title`.
  MileafTextStyles get type => MileafTextStyles.of(this);
}
