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
    this.subtitle,
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
  final String? subtitle;

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
      subtitle: subtitle,
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
      height: 120,
      tickLabel: (time) {
        final local = timestamp(time);
        return local;
      },
      readout: (index) {
        if (index < 0 || index >= points.length) return '$label读数 —';
        return '$label读数 ${_value(points[index].$2)}';
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
        if (points.isNotEmpty)
          Text(unit, style: type.micro.copyWith(color: colors.textFaint)),
        if (points.isNotEmpty && onSelected != null)
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: selected <= 0
                    ? null
                    : () => onSelected!(selected - 1),
                child: const Text('前一个采样'),
              ),
              TextButton(
                onPressed: selected >= points.length - 1
                    ? null
                    : () => onSelected!(selected + 1),
                child: const Text('后一个采样'),
              ),
            ],
          ),
        if (points.length == 1)
          Padding(
            padding: const EdgeInsets.only(top: MileafSpace.s8),
            child: Text(
              '仅1个采样点，无法绘制趋势',
              style: type.micro.copyWith(color: colors.textMuted),
            ),
          ),
        if (points.isNotEmpty && values.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: MileafSpace.s8),
            child: Text(
              '此指标没有已知读数',
              style: type.micro.copyWith(color: colors.textMuted),
            ),
          ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(
            '$label数据说明',
            style: type.body.copyWith(color: colors.textMuted),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '连线仅为采样示意，不代表连续观测；缺失值断线，不补点或补零。',
                style: type.micro.copyWith(color: colors.textMuted),
              ),
            ),
            if (values.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$label采样：${points.length} 点；已知 ${values.length} 点；'
                  '范围 ${_value(values.reduce(math.min))} 至 '
                  '${_value(values.reduce(math.max))}，不是原始极值。',
                  style: type.micro.copyWith(color: colors.textFaint),
                ),
              ),
          ],
        ),
      ],
    );
    return body;
  }
}
