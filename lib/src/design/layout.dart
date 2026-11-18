import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'semantic.dart';
import 'tokens.dart';

/// Width, text-scale and motion helpers derived from Spec §10 / §11.
abstract final class MileafLayout {
  const MileafLayout._();

  static double pageInset(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= MileafBreakpoints.wide
      ? MileafSpace.s24
      : MileafSpace.s20;

  /// Horizontal inset inside the accepted card-form hero (Spec §6.3).
  static double heroInset(BuildContext context) => MileafSpace.cardPad;

  static bool largeText(BuildContext context) =>
      MediaQuery.textScalerOf(context)
          .scale(MileafBreakpoints.largeTextReference) >=
      MileafBreakpoints.largeTextThreshold;

  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static double touchTarget(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.android
      ? MileafSpace.touchAndroid
      : MileafSpace.touch;

  /// Map hero height. At 150%+ every map uses 240 (Spec §9.4) so the in-map
  /// notice band, which grows with the text scaler, still fits without
  /// clipping the copy or covering its action.
  static double mapHeight(BuildContext context, {required double normal}) =>
      largeText(context) ? 240 : normal;

  static double chartHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= MileafBreakpoints.wide
      ? MileafSpace.chartHeightWide
      : MileafSpace.chartHeight;

  /// The display role retains its size at every width; callers reflow.
  static double heroDisplaySize(BuildContext context) => MileafType.displaySize;

  /// Duration that collapses to zero when reduce motion is requested.
  static Duration motion(BuildContext context, Duration duration) =>
      reduceMotion(context) ? Duration.zero : duration;

  /// R26/PD05：底栏标签、收起后的顶栏标题与顶栏胶囊文字放大封顶 1.35×，
  /// 其余文字完整随系统字号。封顶的补偿是大内容查看器（M10）。
  static const double rootChromeLabelMaxScale = 1.35;

  /// 封顶后的文字缩放器：只用于 R26 列出的三处文字。
  static TextScaler rootChromeLabelScaler(BuildContext context) =>
      MediaQuery.textScalerOf(context)
          .clamp(maxScaleFactor: rootChromeLabelMaxScale);

  /// Base geometry keeps the accepted 64px surface at 100%, then grows by the
  /// capped label's scaled leading lead so large text remains fully visible.
  static double rootNavigationHeight(BuildContext context) {
    final scaler = rootChromeLabelScaler(context);
    final lead = math.max(
      0.0,
      scaler.scale(MileafType.navLabelHeight) - MileafType.navLabelHeight,
    );
    return math.max(MileafSpace.navHeight, MileafSpace.navHeight + lead);
  }

  static double rootNavigationClearance(BuildContext context) =>
      rootNavigationHeight(context) +
      MediaQuery.viewPaddingOf(context).bottom +
      MileafSpace.s8 +
      MileafSpace.s16;

  /// R26/PD01 展开态外壳：安全区上沿 + 8 + 一行 44 + 8。
  ///
  /// 大字（[largeText]，约 150% 起）把大标题独占一行，控件在其上方一行靠右，
  /// 因此多出一行控件的高度与 4 的行距。
  static double rootTopBarHeight(BuildContext context, {double? topInset}) {
    final scaler = MediaQuery.textScalerOf(context);
    final titleHeight = scaler.scale(MileafType.largeTitleHeight);
    final contentHeight = largeText(context)
        ? touchTarget(context) + MileafSpace.s4 + titleHeight
        : math.max(touchTarget(context), titleHeight);
    return (topInset ?? MediaQuery.viewPaddingOf(context).top) +
        MileafSpace.s8 +
        contentHeight +
        MileafSpace.s8;
  }

  /// R26/PD01 收起态外壳：安全区上沿 + 44。
  ///
  /// 标题在这个高度里封顶 1.35×（[rootChromeLabelScaler]），所以收起高度不随
  /// 系统字号继续增长。
  static double rootTopBarCollapsedHeight(
    BuildContext context, {
    double? topInset,
  }) =>
      (topInset ?? MediaQuery.viewPaddingOf(context).top) +
      math.max(
        touchTarget(context),
        rootChromeLabelScaler(context).scale(MileafType.headlineHeight),
      );

  /// 页面顶部留白：展开态外壳高度 + 8。外壳收起时页面不跟着动（R26）。
  static double rootTopClearance(BuildContext context) =>
      rootTopBarHeight(context) + MileafSpace.s8;

  /// Horizontal-only inset, for lists that own their vertical rhythm.
  static EdgeInsets pageHorizontal(BuildContext context) =>
      EdgeInsets.symmetric(horizontal: pageInset(context));

  static EdgeInsets pagePadding(
    BuildContext context, {
    double top = 0,
    double? bottom,
  }) => EdgeInsets.fromLTRB(
    pageInset(context),
    top,
    pageInset(context),
    bottom ??
        (RootNavigationScope.maybeOf(context)
            ? rootNavigationClearance(context)
            : MileafSpace.s24),
  );
}

class RootNavigationScope extends InheritedWidget {
  const RootNavigationScope({super.key, required super.child});

  static bool maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RootNavigationScope>() != null;

  @override
  bool updateShouldNotify(RootNavigationScope oldWidget) => false;
}

/// Centres content at 560 logical pixels on tablets; never a second column.
class MileafContent extends StatelessWidget {
  const MileafContent({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: MileafBreakpoints.maxContent),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    ),
  );
}

/// Page-level 2px progress line. Under reduce motion the indeterminate
/// animation is replaced by a static accent strip (R07：减少动效不残留无限
/// 转动；静态进度提示由所在页面配文承载). The strip opacity is the midpoint
/// of the former pulse so it still reads as activity, not completion; the
/// value is registered in token-changes as a candidate opacity token.
class MileafProgressLine extends StatelessWidget {
  const MileafProgressLine({super.key});

  /// R07 减动效静态条的透明度（原 1.2s 脉冲的中段值）。
  static const _reducedOpacity = .55;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.accent;
    if (MileafLayout.reduceMotion(context)) {
      return Container(
        height: 2,
        color: color.withValues(alpha: _reducedOpacity),
      );
    }
    return SizedBox(
      height: 2,
      child: LinearProgressIndicator(
        minHeight: 2,
        backgroundColor: Colors.transparent,
        color: color,
      ),
    );
  }
}
