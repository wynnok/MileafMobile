import 'package:flutter/material.dart';

import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

/// One bar per energy category (AC / DC / 未知) scaled to the largest one.
///
/// Use for per-category comparison inside a table-like block; the single
/// segmented share bar is [MileafCompositionBar]. One accent plus a 50 % step
/// and a neutral, never a second accent colour (Spec §2.4).
class MileafCategoryBars extends StatelessWidget {
  const MileafCategoryBars({super.key, required this.values, this.note});

  static const unit = 'kWh';
  final List<(String, num?)> values;
  final String? note;

  Color _bar(BuildContext context, int index) {
    final colors = context.colors;
    return switch (index % 3) {
      0 => colors.accent,
      1 => colors.accent.withValues(alpha: .5),
      _ => colors.textFaint,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final maximum = values.fold<num>(
      0,
      (m, entry) => (entry.$2 ?? 0) > m ? entry.$2! : m,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < values.length; i++)
          Semantics(
            container: true,
            excludeSemantics: true,
            label:
                '${values[i].$1} ${values[i].$2 == null ? '—' : '${values[i].$2!.toStringAsFixed(2)} $unit'}',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: MileafSpace.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: MileafSpace.s12,
                    runSpacing: MileafSpace.s4,
                    children: [
                      Text(
                        values[i].$1,
                        style: type.body.copyWith(color: colors.textMuted),
                      ),
                      Text(
                        values[i].$2 == null
                            ? '—'
                            : '${values[i].$2!.toStringAsFixed(2)} $unit',
                        style: type.body.copyWith(
                          color: colors.text,
                          fontWeight: MileafType.weightSemiBold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: MileafSpace.s8),
                  LayoutBuilder(
                    builder: (context, constraints) => Container(
                      height: MileafSpace.inline6,
                      decoration: BoxDecoration(
                        color: colors.line,
                        borderRadius: MileafRadius.xsAll,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: maximum <= 0
                              ? 0
                              : constraints.maxWidth *
                                    ((values[i].$2 ?? 0) / maximum).clamp(0, 1),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: _bar(context, i),
                              borderRadius: MileafRadius.xsAll,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (note != null)
          Text(
            note!,
            style: type.micro.copyWith(color: colors.textMuted),
          ),
      ],
    );
  }
}
