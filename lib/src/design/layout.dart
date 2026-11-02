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

  /// Horizontal inset for content that sits inside a hero (Spec §6.3).
  ///
  /// A card hero is already 12 away from the screen edge and keeps a fixed
  /// 16 inside, so its content lands 28 from the edge at every width; a
  /// full-bleed hero keeps the page inset. The form comes from the palette
  /// ([MileafColors.heroAsCard]); call sites never decide it themselves.
  static double heroInset(BuildContext context) =>
      context.colors.heroAsCard ? MileafSpace.cardPad : pageInset(context);

  static bool largeText(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(MileafBreakpoints.largeTextReference) >=
      MileafBreakpoints.largeTextThreshold;

  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Map hero height. At 150%+ every map uses 240 (Spec §9.4) so the in-map
  /// notice band, which grows with the text scaler, still fits without
  /// clipping the copy or covering its action.
  static double mapHeight(BuildContext context, {required double normal}) =>
      largeText(context) ? 240 : normal;

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

  /// Horizontal-only inset, for lists that own their vertical rhythm.
  static EdgeInsets pageHorizontal(BuildContext context) =>
      EdgeInsets.symmetric(horizontal: pageInset(context));

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
