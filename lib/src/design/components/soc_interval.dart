import 'package:flutter/material.dart';

import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

/// 0–100 % track with the driven segment drawn on top (Spec §9.4).
///
/// The bar is always the full 0–100 scale, so a 68→76 % trip is a short segment
/// near the end — never a 0→76 % progress bar. Unknown bounds draw no segment
/// and print `—`; a real 0 % stays a real 0.
class SocIntervalBar extends StatelessWidget {
  const SocIntervalBar({super.key, required this.start, required this.end});

  /// 出发电量 (start of the trip/charge) in percent.
  final num? start;

  /// 到达电量 (end of the trip/charge) in percent.
  final num? end;

  static const double _trackHeight = 8;

  /// The pair reads 「出发 76% / 到达 68%」 — journey order, `%` glued to the
  /// number so a label never wraps mid-value. (2026-11-01 用户裁定以此顺序为准，
  /// 覆盖 Spec §9.4 原句的「到达 / 出发」。)
  String _value(num? level) =>
      level == null ? '—' : '${level.toStringAsFixed(0)}%';

  String _spoken(num? level) =>
      level == null ? '未知' : '${level.toStringAsFixed(0)} %';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final start = this.start;
    final end = this.end;
    final known = start != null && end != null;
    final low = known ? (start < end ? start : end) : 0;
    final high = known ? (start < end ? end : start) : 0;
    final large = MileafLayout.largeText(context);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '电量区间，出发 ${_spoken(start)}，到达 ${_spoken(end)}，尺度 0 至 100%',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Container(
                height: _trackHeight,
                margin: const EdgeInsets.symmetric(vertical: MileafSpace.s8),
                decoration: BoxDecoration(
                  color: colors.lineStrong,
                  borderRadius: MileafRadius.xsAll,
                ),
                child: known
                    ? Stack(
                        children: [
                          Positioned(
                            left: width * (low / 100).clamp(0, 1),
                            width: width * ((high - low) / 100).clamp(0, 1),
                            top: 0,
                            bottom: 0,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.accent,
                                borderRadius: MileafRadius.xsAll,
                              ),
                            ),
                          ),
                        ],
                      )
                    : null,
              );
            },
          ),
          const SizedBox(height: MileafSpace.s4),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: MileafSpace.s16,
            runSpacing: MileafSpace.s4,
            children: [
              Text(
                '出发 ${_value(start)}',
                style: (large ? type.body : type.label).copyWith(
                  color: colors.textMuted,
                ),
              ),
              Text(
                '到达 ${_value(end)}',
                style: (large ? type.body : type.label).copyWith(
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
