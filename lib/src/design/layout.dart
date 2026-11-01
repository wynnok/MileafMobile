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

  static bool largeText(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(MileafBreakpoints.largeTextReference) >=
      MileafBreakpoints.largeTextThreshold;

  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static double chartHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= MileafBreakpoints.wide
      ? MileafSpace.chartHeightWide
      : MileafSpace.chartHeight;

  /// 320–359 uses a 56 display, 390+ uses 64, base is 60.
  static double heroDisplaySize(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < MileafBreakpoints.base) return 56;
    if (width >= MileafBreakpoints.wide) return 64;
    return MileafType.displaySize;
  }

  /// Duration that collapses to zero when reduce motion is requested.
  static Duration motion(BuildContext context, Duration duration) =>
      reduceMotion(context) ? Duration.zero : duration;

  static EdgeInsets pagePadding(
    BuildContext context, {
    double top = 0,
    double bottom = MileafSpace.s24,
  }) => EdgeInsets.fromLTRB(
    pageInset(context),
    top,
    pageInset(context),
    bottom,
  );
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

/// Page-level 2px progress line; static colour when reduce motion is on.
class MileafProgressLine extends StatelessWidget {
  const MileafProgressLine({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 2,
    child: LinearProgressIndicator(
      minHeight: 2,
      backgroundColor: Colors.transparent,
      color: context.colors.accent,
    ),
  );
}
