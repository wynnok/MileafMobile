import 'package:flutter/material.dart';

import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

/// 34px chip with a 44px touch target.
class StatusChip extends StatefulWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.enabled = true,
    this.onHero = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;
  final bool onHero;

  @override
  State<StatusChip> createState() => _StatusChipState();
}

class _StatusChipState extends State<StatusChip> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final selected = widget.selected;
    final enabled = widget.enabled && widget.onTap != null;
    final background = selected
        ? colors.accentSoft
        : widget.onHero
        ? colors.heroText.withValues(alpha: .04)
        : Colors.transparent;
    final border = selected
        ? colors.accent
        : widget.onHero
        ? colors.heroText.withValues(alpha: .16)
        : colors.line;
    final foreground = !widget.enabled
        ? colors.textFaint.withValues(alpha: .38)
        : selected
        ? colors.accent
        : widget.onHero
        ? colors.heroMuted
        : colors.textMuted;
    final chip = Container(
      constraints: const BoxConstraints(minHeight: MileafSpace.chipHeight),
      padding: const EdgeInsets.symmetric(horizontal: MileafSpace.s12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: MileafRadius.fullAll,
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: type.label.copyWith(color: foreground),
          ),
        ],
      ),
    );
    return Semantics(
      button: widget.onTap != null,
      selected: selected,
      enabled: widget.enabled,
      label: widget.label,
      excludeSemantics: true,
      child: Focus(
        onFocusChange: (value) => setState(() => _focused = value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: MileafSpace.touch),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Material(
              color: Colors.transparent,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? widget.onTap : null,
                customBorder: const StadiumBorder(),
                highlightColor: colors.accent.withValues(alpha: .12),
                child: Container(
                  foregroundDecoration: _focused
                      ? BoxDecoration(
                          borderRadius: MileafRadius.fullAll,
                          border: Border.all(
                            color: colors.focusRing,
                            width: 2,
                          ),
                        )
                      : null,
                  child: chip,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
