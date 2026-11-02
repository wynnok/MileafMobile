import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';

/// The one "now / primary result" block per page.
///
/// The form is derived from the palette, never passed in (Spec §6.1):
///
/// - **Full bleed** (dark, ΔL\*0.6): the hero is the same continuous material
///   as the canvas, so it keeps the screen edges, the status bar over its own
///   colour, and the top inset.
/// - **Card** (light, ΔL\*93.6): the dark anchor becomes an object on paper —
///   12 outer margin, 20 radius, no stroke and no shadow. It no longer sits
///   under the status bar, so it declares no `SystemUiOverlayStyle`; the page
///   level region in `main.dart` decides the icon brightness from the canvas.
///
/// The surface paints a single radial glow in the top-right corner (≤20%
/// opacity); on a card the glow follows the card width.
class MileafHero extends StatelessWidget {
  const MileafHero({
    super.key,
    required this.child,
    this.glow = true,
    this.semanticLabel,
  });

  final Widget child;
  final bool glow;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final card = colors.heroAsCard;
    final content = Stack(
      children: [
        if (glow) _glow(colors, card: card),
        child,
      ],
    );
    final surface = Material(
      color: colors.hero,
      borderRadius: card ? BorderRadius.circular(MileafRadius.lg) : null,
      clipBehavior: Clip.hardEdge,
      child: semanticLabel == null
          ? content
          : Semantics(container: true, label: semanticLabel, child: content),
    );
    if (card) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: MileafSpace.cardInset),
        child: surface,
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: surface,
    );
  }

  Widget _glow(MileafColors colors, {required bool card}) {
    final glowColors = [
      colors.accentHero.withValues(alpha: .18),
      colors.accentHero.withValues(alpha: 0),
    ];
    if (!card) {
      // Full bleed keeps the fixed 420 disc anchored to the top-right corner.
      return Positioned(
        top: -180,
        right: -140,
        child: IgnorePointer(
          child: Container(
            width: 420,
            height: 420,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: glowColors),
            ),
          ),
        ),
      );
    }
    // Card: same 18% peak; Flutter resolves a fractional radius against the
    // box's **short side**, so 0.95 reads as ≈0.95×height here, not 0.95×width
    // as §6.3's "半径 ≈ w×0.95" says. The centre is the spec ratio
    // (w×1.02, −h×0.15) expressed in the card's own fractional coordinates, so
    // it needs no built-time height.
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(1.04, -1.3),
              radius: .95,
              colors: glowColors,
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero padding from Spec §6.2 / §6.3.
///
/// Full bleed keeps the status-bar inset; the card form drops it (the paper
/// owns the status bar) and uses the card's 16 / 20 box instead.
///
/// This is the **default card box**, used by the design gallery to render a
/// spec-shaped hero. Real pages pass their own vertical padding through
/// `MileafHero` (overview keeps `s4` / `heroBottom`), so the 20 below is not a
/// promise that every page's hero is 20 tall inside.
EdgeInsets mileafHeroPadding(BuildContext context) {
  if (context.colors.heroAsCard) {
    return const EdgeInsets.fromLTRB(
      MileafSpace.cardPad,
      MileafSpace.s20,
      MileafSpace.cardPad,
      MileafSpace.s20,
    );
  }
  final horizontal = MileafLayout.heroInset(context);
  return EdgeInsets.fromLTRB(
    horizontal,
    MediaQuery.paddingOf(context).top + MileafSpace.heroTop,
    horizontal,
    MileafSpace.heroBottom,
  );
}
