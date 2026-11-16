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

/// R22 字体角色表（ADR0014 / PD04）：新增角色 largeTitle、title2、headline、
/// metricSm、subheadline、control、footnote、caption；旧角色 title、label、
/// micro、pageTitle、navigationTitle、bodyStrong 保留原值作为过渡别名
/// （AP14 删除）。每个数字样式带 tabular figures。
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
    required this.title,
    required this.body,
    required this.subheadline,
    required this.control,
    required this.footnote,
    required this.caption,
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
      weight: MileafType.weightRegular,
      tracking: MileafType.microTracking,
      color: colors.textFaint,
    ),
  );

  /// R22：分组标题用 subheadline 的 500 变体。
  TextStyle get groupTitle =>
      subheadline.copyWith(fontWeight: MileafType.weightMedium);

  /// R22：控件选中态用 control 的 600 变体。
  TextStyle get controlSelected =>
      control.copyWith(fontWeight: MileafType.weightSemiBold);

  /// 过渡别名（R22/PD04）：原值保留，去向 largeTitle，AP14 删除。
  TextStyle get pageTitle => title.copyWith(
    fontSize: MileafType.pageTitleSize,
    height: MileafType.pageTitleHeight / MileafType.pageTitleSize,
  );

  /// 过渡别名（R22/PD04）：原值保留，去向 headline，AP14 删除。
  TextStyle get navigationTitle => title.copyWith(
    fontSize: MileafType.navigationTitleSize,
    height: MileafType.navigationTitleHeight / MileafType.navigationTitleSize,
  );

  /// 过渡别名（R22/PD04）：原值保留。导航/设置行标题随 body 400（R22）、
  /// 记录行标题随 headline，AP14 删除。
  TextStyle get bodyStrong =>
      body.copyWith(fontWeight: MileafType.weightMedium);
  TextStyle get navLabel => label.copyWith(
    fontSize: MileafType.navLabelSize,
    height: MileafType.navLabelHeight / MileafType.navLabelSize,
  );

  final TextStyle display;
  final TextStyle metricLg;
  final TextStyle metricMd;
  final TextStyle metricSm;
  final TextStyle largeTitle;
  final TextStyle title2;
  final TextStyle headline;

  /// 过渡别名（R22/PD04）：原值保留，AP14 删除；去向 title2/headline。
  final TextStyle title;
  final TextStyle body;
  final TextStyle subheadline;
  final TextStyle control;
  final TextStyle footnote;
  final TextStyle caption;

  /// 过渡别名（R22/PD04）：原值保留，AP14 删除；去向 subheadline/control。
  final TextStyle label;

  /// 过渡别名（R22/PD04）：原值保留，AP14 删除；去向 footnote/caption。
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
    TextStyle? metricSm,
    TextStyle? largeTitle,
    TextStyle? title2,
    TextStyle? headline,
    TextStyle? title,
    TextStyle? body,
    TextStyle? subheadline,
    TextStyle? control,
    TextStyle? footnote,
    TextStyle? caption,
    TextStyle? label,
    TextStyle? micro,
  }) => MileafTextStyles(
    display: display ?? this.display,
    metricLg: metricLg ?? this.metricLg,
    metricMd: metricMd ?? this.metricMd,
    metricSm: metricSm ?? this.metricSm,
    largeTitle: largeTitle ?? this.largeTitle,
    title2: title2 ?? this.title2,
    headline: headline ?? this.headline,
    title: title ?? this.title,
    body: body ?? this.body,
    subheadline: subheadline ?? this.subheadline,
    control: control ?? this.control,
    footnote: footnote ?? this.footnote,
    caption: caption ?? this.caption,
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
      metricSm: mix(metricSm, other.metricSm),
      largeTitle: mix(largeTitle, other.largeTitle),
      title2: mix(title2, other.title2),
      headline: mix(headline, other.headline),
      title: mix(title, other.title),
      body: mix(body, other.body),
      subheadline: mix(subheadline, other.subheadline),
      control: mix(control, other.control),
      footnote: mix(footnote, other.footnote),
      caption: mix(caption, other.caption),
      label: mix(label, other.label),
      micro: mix(micro, other.micro),
    );
  }
}

extension MileafTextContext on BuildContext {
  /// Shorthand for the five-level type scale: `context.type.title`.
  MileafTextStyles get type => MileafTextStyles.of(this);
}
