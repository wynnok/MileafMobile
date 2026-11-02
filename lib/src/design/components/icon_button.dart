import 'package:flutter/material.dart';

import '../icons.dart';
import '../semantic.dart';
import '../tokens.dart';

/// 44×44 icon action with press, disabled and 2px focus states.
class MileafIconButton extends StatefulWidget {
  const MileafIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
    this.size = MileafIconMetrics.nav,
    this.selected = false,
  });

  final MileafIconName icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final bool selected;

  @override
  State<MileafIconButton> createState() => _MileafIconButtonState();
}

class _MileafIconButtonState extends State<MileafIconButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = widget.onPressed != null;
    final color = !enabled
        ? colors.textFaint.withValues(alpha: .38)
        : widget.selected
        ? colors.accent
        : widget.color ?? colors.textMuted;
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: widget.selected,
        label: widget.tooltip,
        child: SizedBox.square(
          dimension: MileafSpace.touch,
          child: Focus(
            onFocusChange: (value) => setState(() => _focused = value),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.selected ? colors.accentSoft : null,
                border: _focused
                    ? Border.all(color: colors.focusRing, width: 2)
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: widget.onPressed,
                  highlightColor: colors.accentSoft,
                  splashColor: colors.accentSoft,
                  child: Center(
                    child: MileafIcon(
                      widget.icon,
                      size: widget.size,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
