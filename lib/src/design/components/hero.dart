import 'package:flutter/material.dart';

import '../semantic.dart';
import '../tokens.dart';

/// The one current-state block per page. R13 keeps it on the ordinary content
/// surface in both appearances, with a 24px concentric radius.
class MileafHero extends StatelessWidget {
  const MileafHero({super.key, required this.child, this.semanticLabel});

  final Widget child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final surface = Material(
      color: colors.hero,
      borderRadius: MileafRadius.surfaceAll,
      clipBehavior: Clip.hardEdge,
      child: semanticLabel == null
          ? child
          : Semantics(container: true, label: semanticLabel, child: child),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MileafSpace.cardInset),
      child: surface,
    );
  }
}

/// Default card box used by the design gallery. Real pages may pass their own
/// vertical rhythm through [MileafHero].
EdgeInsets mileafHeroPadding(BuildContext context) => const EdgeInsets.fromLTRB(
  MileafSpace.cardPad,
  MileafSpace.s20,
  MileafSpace.cardPad,
  MileafSpace.s20,
);
