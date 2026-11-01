import 'package:flutter/material.dart';

import '../icons.dart';
import '../layout.dart';
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
  });

  final StateViewKind kind;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final MileafIconName? icon;

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
    final tone = kind == StateViewKind.error ? colors.error : colors.textMuted;
    final glyph = icon ??
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
            style: type.title.copyWith(
              color: kind == StateViewKind.error ? colors.error : colors.text,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: MileafSpace.s8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: type.body.copyWith(color: colors.textMuted),
            ),
          ],
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: MileafSpace.s12),
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
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
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// 1.2s opacity skeleton; static when reduce motion is on.
class SkeletonBlock extends StatefulWidget {
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
  State<SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: MileafDurations.skeleton,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MileafLayout.reduceMotion(context)) {
      _controller
        ..stop()
        ..value = .5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: context.colors.skeleton.withValues(
          alpha: .5 + .5 * _controller.value,
        ),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}
