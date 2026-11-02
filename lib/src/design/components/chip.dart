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
    // Selected label and stroke are text / edge signals: `accentStrong` on the
    // paper, hero text with an `accentHero` stroke on the dark hero (§7.1).
    final onHero = widget.onHero;
    final selectedTint = colors.heroText.withValues(alpha: .12);
    final idleTint = colors.heroText.withValues(alpha: .04);
    final background = selected
        ? (onHero ? selectedTint : colors.accentSoft)
        : (onHero ? idleTint : Colors.transparent);
    final border = selected
        ? (onHero ? colors.accentHero : colors.accentStrong)
        : (onHero ? colors.heroText.withValues(alpha: .16) : colors.line);
    final Color foreground;
    if (!widget.enabled) {
      foreground = colors.textFaint.withValues(alpha: .38);
    } else if (selected) {
      foreground = onHero ? colors.heroText : colors.accentStrong;
    } else {
      foreground = onHero ? colors.heroMuted : colors.textMuted;
    }
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
                          border: Border.all(color: colors.focusRing, width: 2),
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
