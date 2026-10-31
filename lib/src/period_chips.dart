import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => Row(
    children: [
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
            onSelected: (_) => onSelected(i),
          ),
        ),
      const Spacer(),
      ?trailing,
    ],
  );
}
