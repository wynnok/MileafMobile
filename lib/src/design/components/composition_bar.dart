import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

/// AC / DC / 未知 分段构成条（Spec §9.5）.
///
/// One 8px bar split by known energy only: entries without a positive value are
/// dropped from the bar (never drawn as a zero-width sliver), and when nothing
/// is known the caller's [emptyMessage] is printed instead of an empty bar.
/// Colours follow Spec §2.4: accent, 50 % accent, neutral — never two accents.
class MileafCompositionBar extends StatelessWidget {
  const MileafCompositionBar({
    super.key,
    required this.segments,
    this.emptyMessage = 'AC/DC 分类能量缺失',
    this.height = 8,
    this.hue,
  });

  /// Label and known energy in kWh; `null` means the field was never recorded.
  final List<(String, num?)> segments;
  final String emptyMessage;
  final double height;

  /// CL01/CL02：分段色相。传了就是「同一色相两档 + 中性」——主段
  /// `hue.solid`、次段 `hue.strong`、「未知」仍 `seriesNeutral`；
  /// 缺省沿用 series 三档，与改造前像素等价。
  final MileafHue? hue;

  Color _color(BuildContext context, int index) {
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
    final known = [
      for (final segment in segments)
        if (segment.$2 != null && segment.$2! > 0) segment,
    ];
    final total = known.fold<num>(0, (sum, segment) => sum + segment.$2!);
    if (total <= 0) {
      return Text(
        emptyMessage,
        style: context.type.footnote.copyWith(color: context.colors.textFaint),
      );
    }
    return ClipRRect(
      borderRadius: MileafRadius.xsAll,
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (final (index, segment) in known.indexed)
              Expanded(
                flex: math.max(1, (segment.$2! / total * 1000).round()),
                child: ColoredBox(color: _color(context, index)),
              ),
          ],
        ),
      ),
    );
  }
}
