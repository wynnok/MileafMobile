import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A small sampled time-series view; timestamps, not sample indexes, set X.
class SampleChart extends StatefulWidget {
  const SampleChart({
    super.key,
    required this.points,
    required this.label,
    required this.unit,
    required this.timestamp,
  });
  final List<(DateTime, num?)> points;
  final String label, unit;
  final String Function(DateTime) timestamp;
  @override
  State<SampleChart> createState() => _SampleChartState();
}

class _SampleChartState extends State<SampleChart> {
  int selected = 0;
  @override
  void didUpdateWidget(covariant SampleChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    selected = selected.clamp(0, math.max(0, widget.points.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    if (points.isEmpty) return const Text('没有采样点');
    final values = points.map((p) => p.$2).whereType<num>().toList();
    final p = points[selected];
    String value(num? n) => n == null
        ? '—（缺失）'
        : '${n.toStringAsFixed(n == n.roundToDouble() ? 0 : 1)} ${widget.unit}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${widget.label}采样：${points.length} 点；已知 ${values.length} 点'),
        if (values.isNotEmpty)
          Text(
            '采样范围 ${value(values.reduce(math.min))} 至 ${value(values.reduce(math.max))}；不是原始极值',
          ),
        if (points.length == 1) const Text('仅1个采样点，无法绘制趋势'),
        if (values.isEmpty) const Text('此指标没有已知读数'),
        LayoutBuilder(
          builder: (context, constraints) => Semantics(
            label: '${widget.label}采样图，按真实时间分布，可用前后采样按钮读取',
            child: GestureDetector(
              onTapDown: (details) {
                final first = points.first.$1.microsecondsSinceEpoch;
                final last = points.last.$1.microsecondsSinceEpoch;
                final target =
                    first +
                    (last - first) *
                        (details.localPosition.dx / constraints.maxWidth).clamp(
                          0,
                          1,
                        );
                var nearest = 0;
                for (var i = 1; i < points.length; i++) {
                  if ((points[i].$1.microsecondsSinceEpoch - target).abs() <
                      (points[nearest].$1.microsecondsSinceEpoch - target)
                          .abs()) {
                    nearest = i;
                  }
                }
                setState(() => selected = nearest);
              },
              child: CustomPaint(
                key: const ValueKey('sample-chart'),
                size: Size(constraints.maxWidth, 160),
                painter: _SamplesPainter(
                  points,
                  selected,
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
        Text(
          '${widget.timestamp(points.first.$1)} → ${widget.timestamp(points.last.$1)}',
        ),
        Semantics(
          liveRegion: true,
          child: Text(
            '${widget.label}读数 ${value(p.$2)}\n${widget.timestamp(p.$1)}',
          ),
        ),
        Wrap(
          children: [
            TextButton(
              onPressed: selected == 0
                  ? null
                  : () => setState(() => selected--),
              child: const Text('前一个采样'),
            ),
            TextButton(
              onPressed: selected >= points.length - 1
                  ? null
                  : () => setState(() => selected++),
              child: const Text('后一个采样'),
            ),
          ],
        ),
        const Text('连线仅为采样示意，不代表连续观测；缺失值断线，不补点或补零。'),
      ],
    );
  }
}

class _SamplesPainter extends CustomPainter {
  _SamplesPainter(this.points, this.selected, this.color);
  final List<(DateTime, num?)> points;
  final int selected;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final known = points.map((p) => p.$2).whereType<num>().toList();
    if (known.isEmpty) return;
    final min = known.reduce(math.min).toDouble(),
        max = known.reduce(math.max).toDouble();
    final first = points.first.$1.microsecondsSinceEpoch,
        last = points.last.$1.microsecondsSinceEpoch;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    Offset? previous;
    for (var i = 0; i < points.length; i++) {
      final (time, value) = points[i];
      if (value == null) {
        previous = null;
        continue;
      }
      final x = last == first
          ? size.width / 2
          : (time.microsecondsSinceEpoch - first) /
                    (last - first) *
                    (size.width - 8) +
                4;
      final y = max == min
          ? size.height / 2
          : size.height - 8 - (value - min) / (max - min) * (size.height - 16);
      final point = Offset(x, y);
      if (previous != null) canvas.drawLine(previous, point, paint);
      canvas.drawCircle(point, i == selected ? 5 : 2, Paint()..color = color);
      previous = point;
    }
  }

  @override
  bool shouldRepaint(covariant _SamplesPainter oldDelegate) => true;
}
