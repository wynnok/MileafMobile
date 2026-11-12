import 'package:flutter/material.dart';

import '../icons.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

enum StateViewKind { empty, error, loading }

/// Formal empty / error / loading presentation; never a fake all-zero chart.
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.kind,
    this.title = '',
    this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.onHero = false,
  });

  final StateViewKind kind;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final MileafIconName? icon;
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    if (kind == StateViewKind.loading) {
      return Semantics(
        label: title.isEmpty ? '正在加载' : title,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: MileafSpace.s40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              SkeletonBlock(width: 160, height: 14),
              SizedBox(height: MileafSpace.s12),
              SkeletonBlock(width: 220, height: 10),
              SizedBox(height: MileafSpace.s8),
              SkeletonBlock(width: 120, height: 10),
            ],
          ),
        ),
      );
    }
    final tone = kind == StateViewKind.error
        ? colors.error
        : onHero
        ? colors.heroMuted
        : colors.textMuted;
    final titleColor = kind == StateViewKind.error
        ? colors.error
        : onHero
        ? colors.heroText
        : colors.text;
    final messageColor = onHero ? colors.heroMuted : colors.textMuted;
    final glyph =
        icon ??
        (kind == StateViewKind.error
            ? MileafIconName.info
            : MileafIconName.route);
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: MileafSpace.s40,
        horizontal: MileafSpace.s20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MileafIcon(glyph, size: MileafIconMetrics.header, color: tone),
          const SizedBox(height: MileafSpace.s16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: type.title.copyWith(color: titleColor),
          ),
          if (message != null) ...[
            const SizedBox(height: MileafSpace.s8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: type.body.copyWith(color: messageColor),
            ),
          ],
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: MileafSpace.s12),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

enum BannerTone { info, warning, error }

/// Inline status strip used for stale data and failed resources.
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.message,
    this.tone = BannerTone.info,
    this.actionLabel,
    this.onAction,
    this.liveRegion = true,
  });

  final String message;
  final BannerTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final color = switch (tone) {
      BannerTone.info => colors.textMuted,
      BannerTone.warning => colors.warning,
      BannerTone.error => colors.error,
    };
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.line),
          bottom: BorderSide(color: colors.line),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: MileafSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MileafIcon(
            MileafIconName.info,
            size: MileafIconMetrics.inline,
            color: color,
          ),
          const SizedBox(width: MileafSpace.s8),
          Expanded(
            child: Semantics(
              liveRegion: liveRegion,
              child: Text(
                message,
                style: type.body.copyWith(color: colors.textMuted),
              ),
            ),
          ),
          if (onAction != null && actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Static skeleton (R07/R08): a fixed shape in the skeleton tone, so first
/// load shows the module's real structure without an infinite pulse or a
/// shimmer sweep; reduce motion needed no special case because nothing moves.
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    required this.width,
    required this.height,
    this.radius = MileafRadius.xs,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: context.colors.skeleton,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
