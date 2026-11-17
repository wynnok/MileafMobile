import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design/components/components.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';

class SampleChart extends StatelessWidget {
  const SampleChart({
    super.key,
    required this.points,
    required this.label,
    required this.unit,
    required this.timestamp,
    this.selectedIndex,
    this.onSelected,
    this.plotKey = const ValueKey('sample-chart'),
    this.plotObserverKey,
    this.title,
    this.height = 120,
    this.showYAxis = false,
    this.yRange,
    this.readoutTimestamp,
  });
  final List<(DateTime, num?)> points;
  final String label, unit;
  final String Function(DateTime) timestamp;
  final int? selectedIndex;
  final ValueChanged<int>? onSelected;
  final Key plotKey;
  final Key? plotObserverKey;

  /// Chart title (e.g. 速度过程); falls back to the metric label.
  final String? title;
  final double height;
  final bool showYAxis;
  final (double, double)? yRange;
  final String Function(DateTime)? readoutTimestamp;

  String _value(num? value) {
    if (value == null) return '—';
    final text = value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
    return '$text $unit';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final values = points.map((p) => p.$2).whereType<num>().toList();
    final selected = (selectedIndex ?? 0)
        .clamp(0, math.max(0, points.length - 1))
        .toInt();
    final chart = TimeSeriesChart(
      title: title ?? label,
      unit: unit,
      times: [for (final point in points) point.$1],
      series: [
        ChartSeries(
          label: label,
          values: [for (final point in points) point.$2],
        ),
      ],
      semanticsLabel: '$label过程图表',
      selectedIndex: selected,
      onSelected: onSelected,
      height: height,
      showYAxis: showYAxis,
      yRange: yRange,
      // R21.3：详情页读数头用 metricSm；R29：读数头在绘图区之上。
      readoutScale: ChartReadoutScale.detail,
      readoutDate: readoutTimestamp == null
          ? null
          : (time) => readoutTimestamp!(time),
      tickLabel: (time) {
        final local = timestamp(time);
        return local;
      },
      emptyMessage: '没有采样点',
      plotKey: plotKey,
    );
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        plotObserverKey == null
            ? chart
            : KeyedSubtree(key: plotObserverKey, child: chart),
        if (points.length == 1)
          Padding(
            padding: const EdgeInsets.only(top: MileafSpace.s8),
            child: Text(
              '只有 1 个数据点，无法画出变化',
              style: type.micro.copyWith(color: colors.textMuted),
            ),
          ),
        if (points.isNotEmpty && values.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: MileafSpace.s8),
            child: Text(
              '这一项没有记录',
              style: type.micro.copyWith(color: colors.textMuted),
            ),
          ),
        MileafDisclosure(
          label: '$label数据说明',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '连线仅为采样示意，不代表连续观测；缺失值断线，不补点或补零。',
                style: type.micro.copyWith(color: colors.textMuted),
              ),
              if (values.isNotEmpty) ...[
                const SizedBox(height: MileafSpace.s4),
                Text(
                  '$label采样：${points.length} 点；已知 ${values.length} 点；'
                  '范围 ${_value(values.reduce(math.min))} 至 '
                  '${_value(values.reduce(math.max))}，不是原始极值。',
                  style: type.micro.copyWith(color: colors.textFaint),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    return body;
  }
}
