import 'package:flutter/material.dart';

import '../semantic.dart';

/// Paints the enclosing Focus state without changing chart geometry.
class MileafFocusRing extends StatelessWidget {
  const MileafFocusRing({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    position: DecorationPosition.foreground,
    decoration: BoxDecoration(
      border: Border.all(
        color: Focus.of(context).hasFocus
            ? context.colors.focusRing
            : Colors.transparent,
        width: 2,
      ),
    ),
    child: child,
  );
}
