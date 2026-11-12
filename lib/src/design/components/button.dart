import 'package:flutter/material.dart';

import '../icons.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

enum MileafButtonKind { primary, secondary, ghost }

/// Primary (48px floor), secondary (44px) or ghost button; loading keeps its
/// label and blocks repeat taps (R05).
class MileafButton extends StatefulWidget {
  const MileafButton({
    super.key,
    required this.label,
    this.onPressed,
    this.kind = MileafButtonKind.primary,
    this.loading = false,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final MileafButtonKind kind;
  final bool loading;
  final MileafIconName? icon;
  final bool expand;

  @override
  State<MileafButton> createState() => _MileafButtonState();
}

class _MileafButtonState extends State<MileafButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    final onPressed = widget.onPressed;
    final kind = widget.kind;
    final loading = widget.loading;
    final icon = widget.icon;
    final expand = widget.expand;
    final colors = context.colors;
    final type = context.type;
    final enabled = onPressed != null && !loading;
    final (background, foreground, border) = switch (kind) {
      MileafButtonKind.primary => (
        enabled || loading ? colors.accentStrong : colors.line,
        enabled || loading ? colors.textOnAccent : colors.textFaint,
        null,
      ),
      MileafButtonKind.secondary => (
        Colors.transparent,
        enabled || loading ? colors.text : colors.textFaint,
        colors.lineStrong,
      ),
      MileafButtonKind.ghost => (
        Colors.transparent,
        enabled || loading ? colors.accentStrong : colors.textFaint,
        null,
      ),
    };
    // Spec §7.2: primary and ghost highlight with `accentSoft`; the outlined
    // secondary highlights with the neutral `pressOverlay` (an accent tint on
    // a transparent outline button reads as a second accent colour).
    final highlight = kind == MileafButtonKind.secondary
        ? colors.pressOverlay
        : colors.accentSoft;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: foreground,
            ),
          ),
          const SizedBox(width: MileafSpace.s8),
        ] else if (icon != null) ...[
          MileafIcon(icon, size: MileafIconMetrics.inline, color: foreground),
          const SizedBox(width: MileafSpace.s8),
        ],
        Flexible(
          child: Text(
            label,
            style: type.body.copyWith(
              color: foreground,
              fontWeight: MileafType.weightMedium,
            ),
            // R03：长标签换行重排，不缩字、不溢出（Row 内需显式 Flexible 才有界）。
            softWrap: true,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      value: loading ? '正在处理' : null,
      child: Focus(
        onFocusChange: (value) => setState(() => _focused = value),
        child: Material(
          color: background,
          borderRadius: MileafRadius.mdAll,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: MileafRadius.mdAll,
            highlightColor: highlight,
            child: Container(
              constraints: BoxConstraints(
                minHeight: kind == MileafButtonKind.primary
                    ? MileafSpace.primaryButtonHeight
                    : MileafSpace.touch,
              ),
              padding: const EdgeInsets.symmetric(horizontal: MileafSpace.s16),
              decoration: BoxDecoration(
                borderRadius: MileafRadius.mdAll,
                border: Border.all(
                  color: _focused
                      ? colors.focusRing
                      : border ?? Colors.transparent,
                  width: _focused ? 2 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
