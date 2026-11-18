import 'package:flutter/material.dart';

import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

/// Stable-height, 0-radius frame for the map or its documented fallback.
///
/// Only maps and charts may own a fixed height; text always grows.
class MapFrame extends StatelessWidget {
  const MapFrame({
    super.key,
    required this.height,
    this.child,
    this.overlay,
    this.fallback,
    this.semanticsLabel,
  });

  final double height;
  final Widget? child;
  final Widget? overlay;
  final Widget? fallback;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final content =
        child ??
        fallback ??
        ColoredBox(
          color: colors.surface,
          child: Center(
            child: Text(
              '地图暂不可用',
              style: context.type.body.copyWith(color: colors.textMuted),
            ),
          ),
        );
    final body = SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            content,
            if (overlay != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors.hero.withValues(alpha: 0),
                        colors.hero.withValues(alpha: .88),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      MileafLayout.pageInset(context),
                      MileafSpace.s32,
                      MileafLayout.pageInset(context),
                      MileafSpace.s16,
                    ),
                    child: overlay,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (semanticsLabel == null) return body;
    return Semantics(label: semanticsLabel, child: body);
  }
}
