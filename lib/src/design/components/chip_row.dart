import 'package:flutter/material.dart';

import '../tokens.dart';
import '../semantic.dart';

/// Horizontal row of A chips.
///
/// One rhythm for every filter/tab row: 8 between chips, 4 between runs, and
/// wrapping (never horizontal scrolling) so 200% keeps every label readable.
class ChipRow extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.children,
    this.alignment = WrapCrossAlignment.center,
  });

  final List<Widget> children;
  final WrapCrossAlignment alignment;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.colors.surfaceRaised,
      borderRadius: MileafRadius.mdAll,
    ),
    child: Wrap(
      spacing: MileafSpace.s8,
      runSpacing: MileafSpace.s4,
      crossAxisAlignment: alignment,
      children: children,
    ),
  );
}
