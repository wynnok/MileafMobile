import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data_cards.dart';

enum ChartPresentation { line, bars, groupedBars }

class ChartSeries {
  const ChartSeries({required this.label, required this.values});
  final String label;
  final List<num?> values;
}

/// A read-only, sampled chart. Time coordinates and original nullable values
/// remain intact; drawing never adds observations or recomputes metrics.
class TimeChart extends StatefulWidget {
  const TimeChart({
    super.key,
    required this.title,
    required this.unit,
    required this.times,
    required this.series,
    required this.timestamp,
    this.tickLabel,
    this.presentation = ChartPresentation.bars,
    this.controls,
    this.subtitle,
    this.note,
    this.height = 160,
    this.minimum,
    this.maximum,
    this.plotKey,
    this.valueLabel,
    this.selectedIndex,
    this.onSelected,
    this.compact = false,
    this.onActivateSelected,
  });
  final String title, unit;
  final List<DateTime> times;
  final List<ChartSeries> series;
  final String Function(DateTime) timestamp;
  final String Function(DateTime)? tickLabel;
  final ChartPresentation presentation;
  final Widget? controls;
  final String? subtitle, note;
  final double height;
  final double? minimum, maximum;
  final Key? plotKey;
  final String Function(num?)? valueLabel;
  final int? selectedIndex;
  final ValueChanged<int>? onSelected;
  final bool compact;
  final VoidCallback? onActivateSelected;
  @override
  State<TimeChart> createState() => _TimeChartState();
}

class _TimeChartState extends State<TimeChart> {
  int selected = 0;
  final focus = FocusNode();
  @override
  void didUpdateWidget(covariant TimeChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    selected = selected.clamp(0, math.max(0, widget.times.length - 1));
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  void select(int index) {
    final next = index.clamp(0, widget.times.length - 1);
    setState(() => selected = next);
    widget.onSelected?.call(next);
  }

  String value(num? n) =>
      widget.valueLabel?.call(n) ??
      (n == null ? '—（缺失）' : '${_number(n, widget.unit)} ${widget.unit}');
  String reading(int index) =>
      '${widget.timestamp(widget.times[index])}；${widget.series.map((s) => '${s.label}读数 ${value(s.values[index])}').join('；')}';
  String tick(DateTime t) {
    if (widget.tickLabel != null) {
      return widget.tickLabel!(t);
    }
    final local = widget.timestamp(t);
    final time = RegExp(r'\d{2}:\d{2}').firstMatch(local)?.group(0);
    if (widget.times.last.difference(widget.times.first).inHours < 24 &&
        time != null) {
      return time;
    }
    final date = RegExp(r'\d{4}-(\d{2})-(\d{2})').firstMatch(local);
    return date == null ? local : '${date.group(1)}/${date.group(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final selected = (widget.selectedIndex ?? this.selected)
        .clamp(0, math.max(0, widget.times.length - 1))
        .toInt();
    final scheme = Theme.of(context).colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final colors = [scheme.primary, scheme.tertiary];
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 5,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(widget.unit, style: Theme.of(context).textTheme.labelSmall),
              if (widget.compact && widget.controls != null) widget.controls!,
            ],
          ),
          if (widget.subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.subtitle!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (!widget.compact && widget.controls != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: widget.controls!,
            ),
          SizedBox(height: widget.compact ? 2 : 12),
          if (widget.times.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 35),
              child: Text('没有采样点', textAlign: TextAlign.center),
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final left = 38.0 * math.min(scale, 1.6);
                final plotWidth = constraints.maxWidth - left - 18;
                final inset = _barInset(
                  plotWidth,
                  widget.times.length,
                  widget.series.length,
                  widget.presentation,
                );
                void at(Offset position) {
                  final fraction =
                      ((position.dx - left - inset) / (plotWidth - 2 * inset))
                          .clamp(0.0, 1.0);
                  final first = widget.times.first.microsecondsSinceEpoch;
                  final last = widget.times.last.microsecondsSinceEpoch;
                  final target = first + (last - first) * fraction;
                  var nearest = 0;
                  for (var i = 1; i < widget.times.length; i++) {
                    if ((widget.times[i].microsecondsSinceEpoch - target)
                            .abs() <
                        (widget.times[nearest].microsecondsSinceEpoch - target)
                            .abs()) {
                      nearest = i;
                    }
                  }
                  select(nearest);
                }

                return Focus(
                  focusNode: focus,
                  onKeyEvent: (_, event) {
                    if (event is! KeyDownEvent) return KeyEventResult.ignored;
                    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                      select(selected - 1);
                      return KeyEventResult.handled;
                    }
                    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                      select(selected + 1);
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: Semantics(
                    container: true,
                    label: '${widget.title}图表',
                    value: reading(selected),
                    increasedValue: selected < widget.times.length - 1
                        ? reading(selected + 1)
                        : null,
                    decreasedValue: selected > 0 ? reading(selected - 1) : null,
                    onIncrease: selected < widget.times.length - 1
                        ? () => select(selected + 1)
                        : null,
                    onDecrease: selected > 0
                        ? () => select(selected - 1)
                        : null,
                    child: GestureDetector(
                      onTapUp: (d) {
                        focus.requestFocus();
                        at(d.localPosition);
                      },
                      onHorizontalDragStart: (d) {
                        focus.requestFocus();
                        at(d.localPosition);
                      },
                      onHorizontalDragUpdate: (d) => at(d.localPosition),
                      child: CustomPaint(
                        key: widget.plotKey,
                        size: Size(
                          constraints.maxWidth,
                          widget.height * math.min(scale, 1.4),
                        ),
                        painter: _TimePainter(
                          times: widget.times,
                          series: widget.series,
                          selected: selected,
                          presentation: widget.presentation,
                          colors: colors,
                          grid: scheme.outlineVariant,
                          text: scheme.onSurfaceVariant,
                          fontFamily: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.fontFamily,
                          scale: scale,
                          left: left,
                          minimum: widget.minimum,
                          maximum: widget.maximum,
                          unit: widget.unit,
                          tick: tick,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            if (widget.series.length > 1)
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < widget.series.length; i++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          i.isEven ? Icons.circle : Icons.crop_square,
                          size: 10,
                          color: colors[i % colors.length],
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.series[i].label,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                ],
              ),
            if (widget.compact)
              Row(
                children: [
                  IconButton(
                    tooltip: '前一天',
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 44,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: selected == 0
                        ? null
                        : () => select(selected - 1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      label: reading(selected),
                      excludeSemantics: true,
                      child: Text(
                        '${tick(widget.times[selected])} · ${value(widget.series.first.values[selected])}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '后一天',
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 44,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: selected == widget.times.length - 1
                        ? null
                        : () => select(selected + 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  if (widget.onActivateSelected != null)
                    TextButton(
                      onPressed: widget.onActivateSelected,
                      child: const Text('看当天', semanticsLabel: '查看这一天的行程'),
                    ),
                ],
              )
            else ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in widget.series)
                      Text(
                        '${s.label}读数 ${value(s.values[selected])}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    Text(
                      widget.timestamp(widget.times[selected]),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: selected == 0
                        ? null
                        : () => select(selected - 1),
                    child: const Text('前一个采样'),
                  ),
                  TextButton(
                    onPressed: selected == widget.times.length - 1
                        ? null
                        : () => select(selected + 1),
                    child: const Text('后一个采样'),
                  ),
                ],
              ),
            ],
          ],
          if (widget.note != null)
            Text(widget.note!, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

String _number(num n, String unit) => n.toStringAsFixed(
  RegExp(r'^[A-Z]{3}(\b|/)').hasMatch(unit) ||
          unit.contains('币种') ||
          unit.contains('kWh') ||
          unit == 'kW'
      ? 2
      : unit == 'km' || unit == '°C'
      ? 1
      : 0,
);

double _barWidth(double width, int points, int series) =>
    math.min(12.0, width / math.max(1, points) * .65 / math.max(1, series));

double _barInset(
  double width,
  int points,
  int series,
  ChartPresentation presentation,
) => presentation == ChartPresentation.line
    ? 0
    : (_barWidth(width, points, series) * series +
              math.max(0, series - 1) * 2) /
          2;

class _TimePainter extends CustomPainter {
  _TimePainter({
    required this.times,
    required this.series,
    required this.selected,
    required this.presentation,
    required this.colors,
    required this.grid,
    required this.text,
    required this.fontFamily,
    required this.scale,
    required this.left,
    required this.unit,
    required this.tick,
    this.minimum,
    this.maximum,
  });
  final List<DateTime> times;
  final List<ChartSeries> series;
  final int selected;
  final ChartPresentation presentation;
  final List<Color> colors;
  final Color grid, text;
  final String? fontFamily;
  final double scale, left;
  final double? minimum, maximum;
  final String unit;
  final String Function(DateTime) tick;
  @override
  void paint(Canvas canvas, Size size) {
    final known = series.expand((s) => s.values).whereType<num>().toList();
    var low = math
        .min(minimum ?? 0, known.isEmpty ? 0 : known.reduce(math.min))
        .toDouble();
    var high = math
        .max(maximum ?? 0, known.isEmpty ? 1 : known.reduce(math.max))
        .toDouble();
    if (high == low) high = low + 1;
    final magnitude = math
        .pow(10, (math.log((high - low) / 3) / math.ln10).floor())
        .toDouble();
    final fraction = (high - low) / 3 / magnitude;
    final step =
        (fraction <= 1
            ? 1
            : fraction <= 2
            ? 2
            : fraction <= 5
            ? 5
            : 10) *
        magnitude;
    if (minimum == null) low = (low / step).floor() * step;
    if (maximum == null) high = (high / step).ceil() * step;
    final chart = Rect.fromLTRB(
      left,
      10,
      math.max(left + 1, size.width - 18),
      size.height - 28 * math.min(scale, 1.5),
    );
    final start = times.first.microsecondsSinceEpoch,
        end = times.last.microsecondsSinceEpoch;
    final inset = _barInset(
      chart.width,
      times.length,
      series.length,
      presentation,
    );
    double x(int index) => start == end
        ? chart.center.dx
        : chart.left +
              inset +
              (times[index].microsecondsSinceEpoch - start) /
                  (end - start) *
                  (chart.width - 2 * inset);
    double y(num n) => chart.bottom - (n - low) / (high - low) * chart.height;
    void label(
      String value,
      Offset at, {
      bool right = false,
      bool centered = false,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 10 * math.min(scale, 1.5),
            color: text,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          at.dx -
              (right
                  ? painter.width
                  : centered
                  ? painter.width / 2
                  : 0),
          at.dy,
        ),
      );
    }

    String axis(double n) => n.abs() >= 10000
        ? '${(n / 1000).toStringAsFixed(1)}k'
        : n.toStringAsFixed(n == n.roundToDouble() ? 0 : 2);
    for (final n in {
      low,
      (low + high) / 2,
      high,
      if (low < 0 && high > 0) 0.0,
    }) {
      canvas.drawLine(
        Offset(chart.left, y(n)),
        Offset(chart.right, y(n)),
        Paint()
          ..color = grid
          ..strokeWidth = 1,
      );
      label(
        axis(n),
        Offset(chart.left - 7, y(n) - 6 * math.min(scale, 1.5)),
        right: true,
      );
    }
    final tickCount = scale > 1.4 ? 3 : 4;
    final ticks = <int>{
      0,
      times.length - 1,
      for (var i = 1; i < tickCount - 1; i++)
        ((times.length - 1) * i / (tickCount - 1)).round(),
    };
    for (final i in ticks) {
      final labelX = i == 0
          ? chart.left
          : i == times.length - 1
          ? chart.right
          : x(i);
      label(
        tick(times[i]),
        Offset(labelX, chart.bottom + 8),
        right: i == times.length - 1,
        centered: i != 0 && i != times.length - 1,
      );
    }
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        chart.left - 6,
        chart.top - 5,
        chart.right + 6,
        chart.bottom + 5,
      ),
    );
    for (var s = 0; s < series.length; s++) {
      final values = series[s].values, color = colors[s % colors.length];
      final paint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      Offset? previous;
      final width = _barWidth(chart.width, times.length, series.length);
      for (var i = 0; i < values.length; i++) {
        final v = values[i];
        if (v == null) {
          previous = null;
          continue;
        }
        final point = Offset(x(i), y(v));
        if (presentation == ChartPresentation.line) {
          if (previous != null) {
            if (s.isEven) {
              canvas.drawLine(previous, point, paint);
            } else {
              final delta = point - previous, length = delta.distance;
              for (var distance = 0.0; distance < length; distance += 10) {
                canvas.drawLine(
                  previous + delta * (distance / length),
                  previous + delta * (math.min(length, distance + 6) / length),
                  paint,
                );
              }
            }
          }
          if (s.isEven) {
            canvas.drawCircle(
              point,
              i == selected ? 4 : 2,
              Paint()..color = color,
            );
          } else {
            canvas.drawRect(
              Rect.fromCenter(
                center: point,
                width: i == selected ? 7 : 4,
                height: i == selected ? 7 : 4,
              ),
              paint,
            );
          }
          previous = point;
        } else {
          final center = x(i) + (s - (series.length - 1) / 2) * (width + 2);
          final rect = Rect.fromLTRB(
            center - width / 2,
            math.min(y(0), point.dy),
            center + width / 2,
            math.max(y(0), point.dy),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(2)),
            Paint()
              ..color = color.withValues(
                alpha: s.isOdd
                    ? .12
                    : i == selected
                    ? 1
                    : .6,
              ),
          );
          if (s.isOdd) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(rect, const Radius.circular(2)),
              Paint()
                ..color = color
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5,
            );
          }
          if (v == 0) {
            canvas.drawCircle(
              Offset(center, y(0)),
              1.5,
              Paint()..color = color,
            );
          }
        }
      }
    }
    canvas.drawLine(
      Offset(x(selected), chart.top),
      Offset(x(selected), chart.bottom),
      Paint()
        ..color = text.withValues(alpha: .4)
        ..strokeWidth = .7,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TimePainter oldDelegate) => true;
}
