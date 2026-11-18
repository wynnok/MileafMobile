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

/// R22 字体角色表（ADR0014 / PD04）：display、metricLg、metricMd、metricSm、
/// largeTitle、title2、headline、body、subheadline、control、footnote、caption。
/// AP14 已删除旧角色 title、label、micro、pageTitle、navigationTitle、
/// bodyStrong（R22 过渡别名收口）。每个数字样式带 tabular figures。
@immutable
class MileafTextStyles extends ThemeExtension<MileafTextStyles> {
  const MileafTextStyles({
    required this.display,
    required this.metricLg,
    required this.metricMd,
    required this.metricSm,
    required this.largeTitle,
    required this.title2,
    required this.headline,
    required this.body,
    required this.subheadline,
    required this.control,
    required this.footnote,
    required this.caption,
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
    metricSm: _style(
      size: MileafType.metricSmSize,
      height: MileafType.metricSmHeight,
      weight: MileafType.weightMedium,
      tracking: MileafType.metricSmTracking,
      color: colors.text,
    ),
    largeTitle: _style(
      size: MileafType.largeTitleSize,
      height: MileafType.largeTitleHeight,
      weight: MileafType.weightSemiBold,
      tracking: MileafType.largeTitleTracking,
      color: colors.text,
    ),
    title2: _style(
      size: MileafType.title2Size,
      height: MileafType.title2Height,
      weight: MileafType.weightSemiBold,
      tracking: MileafType.title2Tracking,
      color: colors.text,
    ),
    headline: _style(
      size: MileafType.headlineSize,
      height: MileafType.headlineHeight,
      weight: MileafType.weightSemiBold,
      tracking: MileafType.headlineTracking,
      color: colors.text,
    ),
    body: _style(
      size: MileafType.bodySize,
      height: MileafType.bodyHeight,
      weight: MileafType.weightRegular,
      color: colors.text,
    ),
    subheadline: _style(
      size: MileafType.subheadlineSize,
      height: MileafType.subheadlineHeight,
      weight: MileafType.weightRegular,
      tracking: MileafType.subheadlineTracking,
      color: colors.textSecondary,
    ),
    control: _style(
      size: MileafType.controlSize,
      height: MileafType.controlHeight,
      weight: MileafType.weightMedium,
      tracking: MileafType.controlTracking,
      color: colors.textSecondary,
    ),
    footnote: _style(
      size: MileafType.footnoteSize,
      height: MileafType.footnoteHeight,
      weight: MileafType.weightRegular,
      tracking: MileafType.footnoteTracking,
      color: colors.textSecondary,
    ),
    caption: _style(
      size: MileafType.captionSize,
      height: MileafType.captionHeight,
      weight: MileafType.weightRegular,
      tracking: MileafType.captionTracking,
      color: colors.textSecondary,
    ),
  );

  /// R22：分组标题用 subheadline 的 500 变体。
  TextStyle get groupTitle =>
      subheadline.copyWith(fontWeight: MileafType.weightMedium);

  /// R22：控件选中态用 control 的 600 变体。
  TextStyle get controlSelected =>
      control.copyWith(fontWeight: MileafType.weightSemiBold);

  /// R22 底栏标签：12/16/500，由 caption 400 加 500 字重构成。
  TextStyle get navLabel =>
      caption.copyWith(fontWeight: MileafType.weightMedium);

  final TextStyle display;
  final TextStyle metricLg;
  final TextStyle metricMd;
  final TextStyle metricSm;
  final TextStyle largeTitle;
  final TextStyle title2;
  final TextStyle headline;

  final TextStyle body;
  final TextStyle subheadline;
  final TextStyle control;
  final TextStyle footnote;
  final TextStyle caption;

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

  /// Material text theme for built-in widgets; still five levels.
  TextTheme materialTheme(MileafColors colors) {
    final base = TextTheme(
      displayLarge: display,
      displayMedium: metricLg,
      displaySmall: metricMd,
      headlineLarge: metricLg,
      headlineMedium: metricMd,
      headlineSmall: headline,
      titleLarge: title2,
      titleMedium: headline,
      titleSmall: body.copyWith(fontWeight: MileafType.weightSemiBold),
      bodyLarge: body,
      bodyMedium: body,
      bodySmall: footnote.copyWith(color: colors.textMuted),
      labelLarge: control,
      labelMedium: control,
      labelSmall: caption,
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
    TextStyle? metricSm,
    TextStyle? largeTitle,
    TextStyle? title2,
    TextStyle? headline,
    TextStyle? body,
    TextStyle? subheadline,
    TextStyle? control,
    TextStyle? footnote,
    TextStyle? caption,
  }) => MileafTextStyles(
    display: display ?? this.display,
    metricLg: metricLg ?? this.metricLg,
    metricMd: metricMd ?? this.metricMd,
    metricSm: metricSm ?? this.metricSm,
    largeTitle: largeTitle ?? this.largeTitle,
    title2: title2 ?? this.title2,
    headline: headline ?? this.headline,
    body: body ?? this.body,
    subheadline: subheadline ?? this.subheadline,
    control: control ?? this.control,
    footnote: footnote ?? this.footnote,
    caption: caption ?? this.caption,
  );

  @override
  MileafTextStyles lerp(covariant MileafTextStyles? other, double t) {
    if (other == null) return this;
    TextStyle mix(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return MileafTextStyles(
      display: mix(display, other.display),
      metricLg: mix(metricLg, other.metricLg),
      metricMd: mix(metricMd, other.metricMd),
      metricSm: mix(metricSm, other.metricSm),
      largeTitle: mix(largeTitle, other.largeTitle),
      title2: mix(title2, other.title2),
      headline: mix(headline, other.headline),
      body: mix(body, other.body),
      subheadline: mix(subheadline, other.subheadline),
      control: mix(control, other.control),
      footnote: mix(footnote, other.footnote),
      caption: mix(caption, other.caption),
    );
  }
}

extension MileafTextContext on BuildContext {
  /// Shorthand for the type scale: `context.type.headline`.
  MileafTextStyles get type => MileafTextStyles.of(this);
}
