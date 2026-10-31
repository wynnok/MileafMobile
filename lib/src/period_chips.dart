import 'package:flutter/material.dart';

import 'collage.dart';

/// Shared C period selector: a row of quiet chips plus an optional trailing
/// control (refresh or date action). Keeps the three list headers consistent.
class PeriodChips extends StatelessWidget {
  const PeriodChips({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.trailing,
  });

  /// Chip label per index; the index is what [onSelected] reports.
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (var i = 0; i < labels.length; i++)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            label: Text(
              labels[i],
              style: Theme.of(context).textTheme.labelMedium,
            ),
            selected: selected == i,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            onSelected: (_) => onSelected(i),
          ),
        ),
    ];
    // Large text wraps instead of overflowing the 360 dp header.
    if (largeText(context)) {
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [...chips, ?trailing],
      );
    }
    return Row(children: [...chips, const Spacer(), ?trailing]);
  }
}
