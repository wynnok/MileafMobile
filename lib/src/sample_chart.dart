import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'data_chart.dart';

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
  });
  final List<(DateTime, num?)> points;
  final String label, unit;
  final String Function(DateTime) timestamp;
  final int? selectedIndex;
  final ValueChanged<int>? onSelected;
  final Key plotKey;
  final Key? plotObserverKey;
  @override
  Widget build(BuildContext context) {
    final values = points.map((p) => p.$2).whereType<num>().toList();
    String value(num n) =>
        '${n.toStringAsFixed(n == n.roundToDouble() ? 0 : 1)} $unit';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TimeChart(
          title: label,
          unit: unit,
          times: points.map((p) => p.$1).toList(),
          series: [
            ChartSeries(label: label, values: points.map((p) => p.$2).toList()),
          ],
          timestamp: timestamp,
          presentation: ChartPresentation.line,
          plotKey: plotKey,
          plotObserverKey: plotObserverKey,
          selectedIndex: selectedIndex,
          onSelected: onSelected,
        ),
        ExpansionTile(
          title: Text('$label数据说明'),
          children: [
            const Text('连线仅为采样示意，不代表连续观测；缺失值断线，不补点或补零。'),
            Text(
              '$label采样：${points.length} 点；已知 ${values.length} 点',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (values.isNotEmpty)
              Text(
                '采样范围 ${value(values.reduce(math.min))} 至 ${value(values.reduce(math.max))}；不是原始极值',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        if (points.length == 1) const Text('仅1个采样点，无法绘制趋势'),
        if (points.isNotEmpty && values.isEmpty) const Text('此指标没有已知读数'),
      ],
    );
  }
}
