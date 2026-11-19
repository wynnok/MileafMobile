import 'package:flutter/material.dart';

import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

/// One bar per energy category (AC / DC / 未知) scaled to the largest one.
///
/// Use for per-category comparison inside a table-like block; the single
/// segmented share bar is [MileafCompositionBar]. One accent, one darker step
/// of the same hue and a neutral, never a second accent colour (Spec §8).
/// 分类条进度条的视觉高度（图形尺寸，非布局间距；R24 弃用间距迁移后本地化）。
const double kCategoryBarHeight = 6.0;

class MileafCategoryBars extends StatelessWidget {
  const MileafCategoryBars({
    super.key,
    required this.values,
    this.note,
    this.hue,
  });

  static const unit = 'kWh';
  final List<(String, num?)> values;
  final String? note;

  /// CL01/CL02：柱的语义色相。传了就把「主 / 次 / 中性」三档映射成
  /// 「同一色相两档 + 中性」——主柱 `hue.solid`、次柱 `hue.strong`、
  ///「未知」仍 `seriesNeutral`；缺省沿用 series 三档，与改造前像素等价。
  final MileafHue? hue;

  /// Same three steps as [MileafCompositionBar]: primary, secondary, neutral.
  /// Delegating to the series tokens keeps the pair readable on a white card
  /// and on the dark surface (Spec §8, AV06).
  Color _bar(BuildContext context, int index) {
    final colors = context.colors;
    final hue = this.hue;
    return switch (index % 3) {
      0 => hue?.solid(colors) ?? colors.seriesPrimary,
      1 => hue?.strong(colors) ?? colors.seriesSecondary,
      _ => colors.seriesNeutral,
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
                      height: kCategoryBarHeight,
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
          Text(note!, style: type.footnote.copyWith(color: colors.textMuted)),
      ],
    );
  }
}
