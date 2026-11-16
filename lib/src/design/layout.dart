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

  /// Base geometry keeps the accepted 64px surface at 100%, then grows by the
  /// label's scaled leading lead so large text remains fully visible.
  static double rootNavigationHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
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

  static double rootTopBarHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final titleHeight = scaler.scale(MileafType.pageTitleHeight);
    final vehicleHeight = math.max(
      touchTarget(context),
      scaler.scale(MileafType.bodyHeight),
    );
    final contentHeight = largeText(context)
        ? math.max(touchTarget(context), titleHeight) + vehicleHeight
        : math.max(touchTarget(context), math.max(titleHeight, vehicleHeight));
    return MediaQuery.viewPaddingOf(context).top +
        MileafSpace.s24 +
        contentHeight;
  }

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
