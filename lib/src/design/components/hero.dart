import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';

/// Full-bleed dark anchor for the one "now / primary result" block per page.
///
/// The surface paints the hero colour and a single radial glow in the top-right
/// corner (≤20% opacity). Light pages keep this dark hero.
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
    final content = Stack(
      children: [
        if (glow)
          Positioned(
            top: -180,
            right: -140,
            child: IgnorePointer(
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colors.accentHero.withValues(alpha: .18),
                      colors.accentHero.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        child,
      ],
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Material(
        color: colors.hero,
        clipBehavior: Clip.hardEdge,
        child: semanticLabel == null
            ? content
            : Semantics(
                container: true,
                label: semanticLabel,
                child: content,
              ),
      ),
    );
  }
}

/// Hero padding from Spec §4, including the status-bar inset.
EdgeInsets mileafHeroPadding(BuildContext context) => EdgeInsets.fromLTRB(
  MileafLayout.pageInset(context),
  MediaQuery.paddingOf(context).top + MileafSpace.heroTop,
  MileafLayout.pageInset(context),
  MileafSpace.heroBottom,
);
