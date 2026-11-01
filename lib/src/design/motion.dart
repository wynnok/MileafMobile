import 'package:flutter/material.dart';

import 'layout.dart';
import 'tokens.dart';

abstract final class MileafCurves {
  const MileafCurves._();

  static const enter = Curves.easeOutCubic;
  static const chart = Curves.easeOutCubic;
  static const value = Curves.easeOut;
  static const press = Curves.easeOut;
  static const sheet = Curves.easeOutCubic;
  static const tab = Curves.easeInOut;
}

/// 180ms opacity + 4px rise for page entry; opacity only with reduce motion.
///
/// Motion never gates content: the child is laid out at full size from the
/// first frame.
class MileafPageEnter extends StatelessWidget {
  const MileafPageEnter({super.key, required this.child, this.offset = 4});

  final Widget child;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final reduce = MileafLayout.reduceMotion(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduce ? Duration.zero : MileafDurations.enter,
      curve: MileafCurves.enter,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, reduce ? 0 : offset * (1 - value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Static value swap used by readouts; no number rolling.
class MileafValueFade extends StatelessWidget {
  const MileafValueFade({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MileafLayout.motion(context, MileafDurations.value),
    transitionBuilder: (child, animation) =>
        FadeTransition(opacity: animation, child: child),
    child: child,
  );
}
