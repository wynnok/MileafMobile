import 'package:flutter/material.dart';

import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

/// 44px chip with a 44px touch target; selection settles over 180ms (R16).
class StatusChip extends StatefulWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.enabled = true,
    this.onHero = false,
    this.semanticLabel,
  });

  final String label;
  final String? semanticLabel;
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
    final onHero = widget.onHero;
    final grouped = ChipTrackScope.maybeOf(context);
    final background = grouped || !selected
        ? Colors.transparent
        : colors.segmentSelected;
    final Color foreground;
    if (!widget.enabled) {
      foreground = colors.textFaint.withValues(alpha: .38);
    } else if (selected) {
      foreground = onHero ? colors.heroText : colors.text;
    } else {
      foreground = onHero ? colors.heroMuted : colors.textMuted;
    }
    final chip = AnimatedContainer(
      duration: MileafLayout.motion(context, MileafDurations.selection),
      curve: Curves.easeOutCubic,
      constraints: BoxConstraints(minHeight: MileafLayout.touchTarget(context)),
      padding: const EdgeInsets.symmetric(horizontal: MileafSpace.s12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(MileafSpace.s8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              widget.label,
              style: type.label.copyWith(
                color: foreground,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: widget.onTap != null,
      selected: selected,
      enabled: enabled,
      label: widget.semanticLabel ?? widget.label,
      excludeSemantics: true,
      child: Focus(
        onFocusChange: (value) => setState(() => _focused = value),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MileafLayout.touchTarget(context),
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Material(
              color: Colors.transparent,
              shape: const RoundedRectangleBorder(
                borderRadius: MileafRadius.mdAll,
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? widget.onTap : null,
                customBorder: const RoundedRectangleBorder(
                  borderRadius: MileafRadius.mdAll,
                ),
                highlightColor: colors.accentSoft,
                child: Container(
                  foregroundDecoration: _focused
                      ? BoxDecoration(
                          borderRadius: MileafRadius.mdAll,
                          border: Border.all(color: colors.focusRing, width: 2),
                        )
                      : null,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      chip,
                      if (selected && !grouped)
                        const Positioned.fill(child: ChipSelectionMark()),
                    ],
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

/// Marks chips whose selected surface is painted once by the shared track.
class ChipTrackScope extends InheritedWidget {
  const ChipTrackScope({super.key, required super.child});

  static bool maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChipTrackScope>() != null;

  @override
  bool updateShouldNotify(ChipTrackScope oldWidget) => false;
}

class ChipSelectionMark extends StatelessWidget {
  const ChipSelectionMark({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: MileafSpace.s4),
        child: Container(
          width: MileafSpace.s12,
          height: MileafSpace.inline2,
          decoration: BoxDecoration(
            color: context.colors.accentStrong,
            borderRadius: BorderRadius.circular(MileafSpace.inline2),
          ),
        ),
      ),
    ),
  );
}
