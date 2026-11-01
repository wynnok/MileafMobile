import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout.dart';
import '../motion.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

enum ChartSeriesStyle { line, area, bars, stem, reference }

class ChartSeries {
  const ChartSeries({
    required this.label,
    required this.values,
    this.style = ChartSeriesStyle.line,
  });
  final String label;
  final List<num?> values;
  final ChartSeriesStyle style;
}

/// Contiguous runs of known values; each null starts a new run.
List<List<int>> chartRuns(List<num?> values) {
  final runs = <List<int>>[];
  List<int>? current;
  for (var i = 0; i < values.length; i++) {
    if (values[i] == null) {
      current = null;
      continue;
    }
    if (current == null) {
      current = <int>[];
      runs.add(current);
    }
    current.add(i);
  }
  return runs;
}

/// Stem positions: null and real zero are both empty slots (no hairline).
List<int> chartStemIndices(List<num?> values) => [
  for (var i = 0; i < values.length; i++)
    if (values[i] != null && values[i] != 0) i,
];

/// A sampled time chart: line/area, bars and reference series in one widget.
///
/// Null values break every series (never zero-filled or shifted); a real zero
/// stays a zero; the current point is accent + halo and the readout is the
/// accessible, tap-driven value.
class TimeSeriesChart extends StatefulWidget {
  const TimeSeriesChart({
    super.key,
    required this.title,
    required this.unit,
    required this.times,
    required this.series,
    required this.semanticsLabel,
    this.subtitle,
    this.controls,
    this.height,
    this.plotKey,
    this.tickLabel,
    this.selectedIndex,
    this.onSelected,
    this.readout,
    this.trailing,
    this.note,
    this.onHero = false,
    this.showYAxis = false,
    this.showXAxis = true,
    this.emptyMessage = '还没有采样点',
    this.onActivateSelected,
    this.activationLabel = '查看这一天',
  });

  final String title;
  final String unit;
  final List<DateTime> times;
  final List<ChartSeries> series;
  final String semanticsLabel;
  final String? subtitle;
  final Widget? controls;
  final double? height;
  final Key? plotKey;
  final String Function(DateTime)? tickLabel;
  final int? selectedIndex;
  final ValueChanged<int>? onSelected;
  final String Function(int index)? readout;
  final Widget? trailing;
  final String? note;
  final bool onHero;
  final bool showYAxis;
  final bool showXAxis;
  final String emptyMessage;
  final VoidCallback? onActivateSelected;
  final String activationLabel;

  @override
  State<TimeSeriesChart> createState() => _TimeSeriesChartState();
}

class _TimeSeriesChartState extends State<TimeSeriesChart> {
  int _selected = 0;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedIndex ?? 0;
  }

  @override
  void didUpdateWidget(covariant TimeSeriesChart old) {
    super.didUpdateWidget(old);
    if (widget.selectedIndex != null &&
        widget.selectedIndex != old.selectedIndex) {
      _selected = widget.selectedIndex!;
    }
    _selected = _selected.clamp(0, math.max(0, widget.times.length - 1));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (widget.times.isEmpty) return;
    final next = index.clamp(0, widget.times.length - 1);
    setState(() => _selected = next);
    widget.onSelected?.call(next);
  }

  String _tick(DateTime time) =>
      widget.tickLabel?.call(time) ?? '${time.month}/${time.day}';

  String _value(num? value) =>
      value == null ? '—' : '${_format(value)} ${widget.unit}';

  String _format(num value) => value is int
      ? '$value'
      : value == value.roundToDouble()
      ? '${value.toInt()}'
      : value.abs() >= 100
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  String _reading(int index) {
    if (widget.readout != null) return widget.readout!(index);
    final date = widget.times[index];
    final series = widget.series.isEmpty ? null : widget.series.first;
    final value = series == null || index >= series.values.length
        ? null
        : series.values[index];
    return '${_tick(date)} · ${_value(value)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final onHero = widget.onHero;
    final selected = _selected
        .clamp(0, math.max(0, widget.times.length - 1))
        .toInt();
    final titleColor = onHero ? colors.heroText : colors.text;
    final faint = onHero ? colors.heroFaint : colors.textFaint;
    final header = MileafLayout.largeText(context)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ChartTitle(title: widget.title, color: titleColor),
              if (widget.subtitle != null) ...[
                const SizedBox(height: MileafSpace.s4),
                Text(
                  widget.subtitle!,
                  style: type.label.copyWith(color: faint),
                ),
              ],
            ],
          )
        : Row(
            children: [
              Expanded(
                child: _ChartTitle(title: widget.title, color: titleColor),
              ),
              if (widget.subtitle != null)
                Text(
                  widget.subtitle!,
                  style: type.label.copyWith(color: faint),
                ),
            ],
          );
    final legend = widget.series.length > 1
        ? Padding(
            padding: const EdgeInsets.only(top: MileafSpace.s8),
            child: Wrap(
              spacing: MileafSpace.s16,
              runSpacing: MileafSpace.s4,
              children: [
                for (final series in widget.series)
                  _Legend(
                    series: series,
                    color: _seriesColor(series, colors),
                    textColor: faint,
                  ),
              ],
            ),
          )
        : null;
    if (widget.times.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          if (widget.controls != null) ...[
            const SizedBox(height: MileafSpace.s8),
            widget.controls!,
          ],
          _ChartMessage(message: widget.emptyMessage, color: faint),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (widget.controls != null) ...[
          const SizedBox(height: MileafSpace.s8),
          widget.controls!,
        ],
        ?legend,
        const SizedBox(height: MileafSpace.s8),
        LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
            final plotHeight =
                widget.height ?? MileafLayout.chartHeight(context);
            final left = widget.showYAxis ? 34.0 : 0.0;
            final bottom = widget.showXAxis ? 18.0 * math.min(scale, 1.5) : 0.0;
            final plotWidth = math.max(1.0, constraints.maxWidth - left);
            final plot = Rect.fromLTWH(
              left,
              6,
              plotWidth,
              math.max(1.0, plotHeight - bottom - 6),
            );
            double? lastFraction;
            void selectAt(Offset position) {
              final fraction = ((position.dx - plot.left) / plot.width).clamp(
                0.0,
                1.0,
              );
              if (lastFraction == null ||
                  (fraction - lastFraction!).abs() > .001) {
                final index = (fraction * (widget.times.length - 1)).round();
                _select(index);
              }
              lastFraction = fraction;
            }

            return Focus(
              focusNode: _focus,
              onKeyEvent: (_, event) {
                if (event is! KeyDownEvent) return KeyEventResult.ignored;
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  _select(selected - 1);
                  return KeyEventResult.handled;
                }
                if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  _select(selected + 1);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Semantics(
                container: true,
                label: widget.semanticsLabel,
                value: _reading(selected),
                increasedValue: selected < widget.times.length - 1
                    ? _reading(selected + 1)
                    : null,
                decreasedValue: selected > 0 ? _reading(selected - 1) : null,
                onIncrease: selected < widget.times.length - 1
                    ? () => _select(selected + 1)
                    : null,
                onDecrease: selected > 0 ? () => _select(selected - 1) : null,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    _focus.requestFocus();
                    selectAt(details.localPosition);
                  },
                  onHorizontalDragStart: (details) {
                    _focus.requestFocus();
                    selectAt(details.localPosition);
                  },
                  onHorizontalDragUpdate: (details) =>
                      selectAt(details.localPosition),
                  child: SizedBox(
                    key: widget.plotKey,
                    height: plotHeight,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: MileafLayout.motion(
                        context,
                        MileafDurations.chart,
                      ),
                      curve: MileafCurves.chart,
                      builder: (context, progress, _) => CustomPaint(
                        size: Size(constraints.maxWidth, plotHeight),
                        painter: _ChartPainter(
                          times: widget.times,
                          series: widget.series,
                          selected: selected,
                          plot: plot,
                          progress: progress,
                          primary: onHero ? colors.accentHero : colors.accent,
                          reference: colors.reference,
                          axis: faint,
                          baseline: (onHero ? colors.heroText : colors.text)
                              .withValues(alpha: .18),
                          scaler: MediaQuery.textScalerOf(context),
                          showYAxis: widget.showYAxis,
                          showXAxis: widget.showXAxis,
                          tick: _tick,
                          largeText: MileafLayout.largeText(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: MileafSpace.inline6),
        Semantics(
          liveRegion: true,
          label: _reading(selected),
          excludeSemantics: true,
          child: MileafLayout.largeText(context)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _reading(selected),
                      style: type.body.copyWith(
                        color: onHero ? colors.heroText : colors.text,
                      ),
                    ),
                    if (widget.trailing != null)
                      DefaultTextStyle.merge(
                        style: type.label.copyWith(color: faint),
                        child: widget.trailing!,
                      ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        _reading(selected),
                        style: type.body.copyWith(
                          color: onHero ? colors.heroText : colors.text,
                        ),
                      ),
                    ),
                    if (widget.trailing != null)
                      DefaultTextStyle.merge(
                        style: type.label.copyWith(color: faint),
                        child: widget.trailing!,
                      ),
                  ],
                ),
        ),
        if (widget.onActivateSelected != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: widget.onActivateSelected,
              child: Text('看当天', semanticsLabel: widget.activationLabel),
            ),
          ),
        if (widget.note != null)
          Padding(
            padding: const EdgeInsets.only(top: MileafSpace.s4),
            child: Text(widget.note!, style: type.micro.copyWith(color: faint)),
          ),
      ],
    );
  }

  Color _seriesColor(ChartSeries series, MileafColors colors) =>
      switch (series.style) {
        ChartSeriesStyle.reference => colors.reference,
        _ => widget.onHero ? colors.accentHero : colors.accent,
      };
}

class _ChartTitle extends StatelessWidget {
  const _ChartTitle({required this.title, required this.color});
  final String title;
  final Color color;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(title, style: context.type.title.copyWith(color: color)),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.series,
    required this.color,
    required this.textColor,
  });
  final ChartSeries series;
  final Color color;
  final Color textColor;
  @override
  Widget build(BuildContext context) {
    final reference = series.style == ChartSeriesStyle.reference;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (reference)
          Row(
            children: [
              for (var i = 0; i < 2; i++)
                Container(
                  width: 4,
                  height: 1.5,
                  margin: const EdgeInsets.only(right: 2),
                  color: color,
                ),
            ],
          )
        else
          Container(
            width: 10,
            height: 2,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        const SizedBox(width: MileafSpace.s4),
        Text(
          series.label,
          style: context.type.micro.copyWith(color: textColor),
        ),
      ],
    );
  }
}

class _ChartMessage extends StatelessWidget {
  const _ChartMessage({required this.message, required this.color});
  final String message;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      vertical: MileafSpace.s32,
      horizontal: MileafSpace.s16,
    ),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: context.type.body.copyWith(color: color),
    ),
  );
}

/// Daily charging stems: discrete vertical hairlines; zero and null are empty.
class StemChart extends StatelessWidget {
  const StemChart({
    super.key,
    required this.title,
    required this.unit,
    required this.times,
    required this.values,
    required this.semanticsLabel,
    this.subtitle,
    this.controls,
    this.height,
    this.plotKey,
    this.selectedIndex,
    this.onSelected,
    this.readout,
    this.trailing,
    this.note,
    this.onHero = false,
    this.onActivateSelected,
    this.activationLabel = '查看这一天',
  });

  final String title;
  final String unit;
  final List<DateTime> times;
  final List<num?> values;
  final String semanticsLabel;
  final String? subtitle;
  final Widget? controls;
  final double? height;
  final Key? plotKey;
  final int? selectedIndex;
  final ValueChanged<int>? onSelected;
  final String Function(int index)? readout;
  final Widget? trailing;
  final String? note;
  final bool onHero;
  final VoidCallback? onActivateSelected;
  final String activationLabel;

  @override
  Widget build(BuildContext context) => TimeSeriesChart(
    title: title,
    unit: unit,
    times: times,
    series: [
      ChartSeries(label: title, values: values, style: ChartSeriesStyle.stem),
    ],
    semanticsLabel: semanticsLabel,
    subtitle: subtitle,
    controls: controls,
    height: height,
    plotKey: plotKey,
    selectedIndex: selectedIndex,
    onSelected: onSelected,
    readout: readout,
    trailing: trailing,
    note: note,
    onHero: onHero,
    onActivateSelected: onActivateSelected,
    activationLabel: activationLabel,
  );
}

enum SparkStyle { line, bars }

/// Quiet micro trend for chapter tiles; null breaks the line.
class MicroSpark extends StatelessWidget {
  const MicroSpark({
    super.key,
    required this.values,
    this.height = 28,
    this.style = SparkStyle.line,
    this.semanticsLabel,
  });

  final List<num?> values;
  final double height;
  final SparkStyle style;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spark = SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparkPainter(
          values: values,
          color: colors.accent,
          style: style,
        ),
      ),
    );
    if (semanticsLabel == null) return spark;
    return Semantics(label: semanticsLabel, child: spark);
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.values,
    required this.color,
    required this.style,
  });
  final List<num?> values;
  final Color color;
  final SparkStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final known = values.whereType<num>();
    if (known.isEmpty) return;
    final lo = known.reduce(math.min).toDouble();
    final hi = known.reduce(math.max).toDouble();
    final span = hi - lo;
    double x(int index) => values.length == 1
        ? size.width / 2
        : index * size.width / (values.length - 1);
    double y(num value) =>
        size.height -
        1.5 -
        (span == 0 ? .5 : (value - lo) / span) * (size.height - 3);
    if (style == SparkStyle.bars) {
      final slot = size.width / math.max(1, values.length);
      final width = math.max(1.5, slot * .55);
      for (var i = 0; i < values.length; i++) {
        final value = values[i];
        if (value == null) continue;
        final top = value == 0 ? y(0) : y(value);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(x(i) - width / 2, top, x(i) + width / 2, y(0)),
            const Radius.circular(1),
          ),
          Paint()..color = color.withValues(alpha: .55),
        );
      }
      return;
    }
    final line = Path();
    final area = Path();
    var started = false;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) {
        started = false;
        continue;
      }
      final px = x(i), py = y(value);
      if (!started) {
        line.moveTo(px, py);
        area.moveTo(px, size.height);
        area.lineTo(px, py);
        started = true;
      } else {
        line.lineTo(px, py);
        area.lineTo(px, py);
      }
    }
    if (started) {
      area.lineTo(x(values.length - 1), size.height);
      area.close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: .12), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = MileafChartMetrics.microStroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.values != values || old.color != color || old.style != style;
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.times,
    required this.series,
    required this.selected,
    required this.plot,
    required this.progress,
    required this.primary,
    required this.reference,
    required this.axis,
    required this.baseline,
    required this.scaler,
    required this.showYAxis,
    required this.showXAxis,
    required this.tick,
    required this.largeText,
  });

  final List<DateTime> times;
  final List<ChartSeries> series;
  final int selected;
  final Rect plot;
  final double progress;
  final Color primary;
  final Color reference;
  final Color axis;
  final Color baseline;
  final TextScaler scaler;
  final bool showYAxis;
  final bool showXAxis;
  final String Function(DateTime) tick;
  final bool largeText;

  @override
  void paint(Canvas canvas, Size size) {
    final known = series.expand((s) => s.values).whereType<num>().toList();
    var high = known.isEmpty ? 1.0 : known.reduce(math.max).toDouble();
    var low = math.min(
      0.0,
      known.isEmpty ? 0.0 : known.reduce(math.min).toDouble(),
    );
    if (high == low) high = low + 1;
    final step = _niceStep((high - low) / 3);
    high = (high / step).ceil() * step;
    if (high == low) high = low + step;
    final span = high - low;
    double y(num value) => plot.bottom - (value - low) / span * plot.height;
    // Inset the drawn data so the 8px current-point halo is never clipped.
    final inner = Rect.fromLTRB(
      plot.left + MileafChartMetrics.currentHalo,
      plot.top,
      plot.right - MileafChartMetrics.currentHalo,
      plot.bottom,
    );
    double x(int index) => times.length == 1
        ? inner.center.dx
        : inner.left + index / (times.length - 1) * inner.width;

    final labelStyle = TextStyle(
      fontFamily: MileafType.family,
      fontFamilyFallback: MileafType.fallback,
      fontSize:
          MileafChartMetrics.axisLabelSize * math.min(scaler.scale(1), 1.5),
      color: axis,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    void label(
      String text,
      Offset at, {
      bool centered = false,
      bool right = false,
    }) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
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
      painter.dispose();
    }

    if (showYAxis && !largeText) {
      for (final value in {low, (low + high) / 2, high}) {
        label(_axisNumber(value), Offset(0, y(value) - 5));
      }
    }
    if (showXAxis) {
      final indices = largeText
          ? [0, times.length - 1]
          : {0, ((times.length - 1) / 2).round(), times.length - 1}.toList();
      for (final index in indices) {
        final centered = index != 0 && index != times.length - 1;
        label(
          tick(times[index]),
          Offset(x(index), plot.bottom + 4),
          centered: centered,
          right: index == times.length - 1,
        );
      }
    }

    final clip = Rect.fromLTWH(
      plot.left,
      plot.top - 4,
      plot.width * progress.clamp(0.0, 1.0),
      plot.height + 8,
    );
    canvas.save();
    canvas.clipRect(clip);

    // Zero baseline is the only horizontal line drawn by default.
    if (low <= 0 && high >= 0) {
      canvas.drawLine(
        Offset(plot.left, y(0)),
        Offset(plot.right, y(0)),
        Paint()
          ..color = baseline
          ..strokeWidth = 1,
      );
    }

    for (final chart in series) {
      if (chart.style == ChartSeriesStyle.reference) {
        _drawReference(canvas, chart, x, y);
        continue;
      }
      switch (chart.style) {
        case ChartSeriesStyle.bars:
          _drawBars(canvas, chart, x, y);
        case ChartSeriesStyle.stem:
          _drawStems(canvas, chart, x, y);
        case ChartSeriesStyle.line:
        case ChartSeriesStyle.area:
          _drawLine(canvas, chart, x, y);
        case ChartSeriesStyle.reference:
          break;
      }
    }
    final primarySeries = series.where(
      (s) => s.style != ChartSeriesStyle.reference,
    );
    final first = primarySeries.isEmpty ? null : primarySeries.first;
    if (first != null &&
        selected < first.values.length &&
        first.values[selected] != null &&
        first.style != ChartSeriesStyle.bars &&
        first.style != ChartSeriesStyle.stem) {
      final point = Offset(x(selected), y(first.values[selected]!));
      canvas.drawCircle(
        point,
        MileafChartMetrics.currentHalo,
        Paint()..color = primary.withValues(alpha: .2),
      );
      canvas.drawCircle(
        point,
        MileafChartMetrics.currentPoint,
        Paint()..color = primary,
      );
    }
    canvas.restore();
  }

  void _drawLine(
    Canvas canvas,
    ChartSeries chart,
    double Function(int) x,
    double Function(num) y,
  ) {
    final runs = chartRuns(chart.values);
    final areaPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primary.withValues(alpha: MileafChartMetrics.areaMaxOpacity),
              primary.withValues(alpha: MileafChartMetrics.areaMinOpacity),
            ],
          ).createShader(
            Rect.fromLTWH(plot.left, plot.top, plot.width, plot.height),
          );
    for (final run in runs) {
      final path = Path();
      for (var i = 0; i < run.length; i++) {
        final point = Offset(x(run[i]), y(chart.values[run[i]]!));
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      if (chart.style == ChartSeriesStyle.area) {
        final fill = Path.from(path)
          ..lineTo(x(run.last), y(0))
          ..lineTo(x(run.first), y(0))
          ..close();
        canvas.drawPath(fill, areaPaint);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = MileafChartMetrics.lineStroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      if (run.length == 1) {
        canvas.drawCircle(
          Offset(x(run.first), y(chart.values[run.first]!)),
          MileafChartMetrics.pointRadius,
          Paint()..color = primary,
        );
      }
    }
  }

  void _drawReference(
    Canvas canvas,
    ChartSeries chart,
    double Function(int) x,
    double Function(num) y,
  ) {
    final paint = Paint()
      ..color = reference
      ..style = PaintingStyle.stroke
      ..strokeWidth = MileafChartMetrics.lineStroke
      ..strokeCap = StrokeCap.round;
    for (final run in chartRuns(chart.values)) {
      for (var i = 1; i < run.length; i++) {
        _dashedLine(
          canvas,
          Offset(x(run[i - 1]), y(chart.values[run[i - 1]]!)),
          Offset(x(run[i]), y(chart.values[run[i]]!)),
          paint,
        );
      }
    }
  }

  void _dashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    final delta = to - from;
    final length = delta.distance;
    if (length == 0) return;
    final dash = MileafChartMetrics.referenceDash.first;
    final gap = MileafChartMetrics.referenceDash.last;
    for (var distance = 0.0; distance < length; distance += dash + gap) {
      final end = math.min(distance + dash, length);
      canvas.drawLine(
        from + delta * (distance / length),
        from + delta * (end / length),
        paint,
      );
    }
  }

  void _drawBars(
    Canvas canvas,
    ChartSeries chart,
    double Function(int) x,
    double Function(num) y,
  ) {
    final slot =
        (plot.width - 2 * MileafChartMetrics.currentHalo) /
        math.max(1, times.length);
    final width = math.min(
      MileafChartMetrics.barMaxWidth,
      slot * MileafChartMetrics.barSlotCoverage,
    );
    for (var i = 0; i < chart.values.length; i++) {
      final value = chart.values[i];
      if (value == null) continue;
      final top = math.min(y(0), y(value));
      final bottom = math.max(y(0), y(value));
      final rect = Rect.fromLTRB(
        x(i) - width / 2,
        top,
        x(i) + width / 2,
        bottom,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          const Radius.circular(MileafChartMetrics.barRadius),
        ),
        Paint()
          ..color = primary.withValues(
            alpha: i == selected ? 1 : MileafChartMetrics.barIdleOpacity,
          ),
      );
      if (value == 0) {
        canvas.drawCircle(Offset(x(i), y(0)), 1.5, Paint()..color = primary);
      }
    }
  }

  void _drawStems(
    Canvas canvas,
    ChartSeries chart,
    double Function(int) x,
    double Function(num) y,
  ) {
    for (final index in chartStemIndices(chart.values)) {
      final value = chart.values[index]!;
      final color = primary.withValues(
        alpha: index == selected ? 1 : MileafChartMetrics.stemIdleOpacity,
      );
      final top = Offset(x(index), y(value));
      final bottom = Offset(x(index), y(0));
      canvas.drawLine(
        bottom,
        top,
        Paint()
          ..color = color
          ..strokeWidth = MileafChartMetrics.stemStroke
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        top,
        MileafChartMetrics.stemEndpoint,
        Paint()..color = color,
      );
    }
  }

  double _niceStep(double raw) {
    if (raw <= 0 || !raw.isFinite) return 1;
    final magnitude = math
        .pow(10, (math.log(raw) / math.ln10).floor())
        .toDouble();
    final fraction = raw / magnitude;
    final factor = fraction <= 1
        ? 1
        : fraction <= 2
        ? 2
        : fraction <= 5
        ? 5
        : 10;
    return factor * magnitude;
  }

  String _axisNumber(double value) => value.abs() >= 10000
      ? '${(value / 1000).toStringAsFixed(1)}k'
      : value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  @override
  bool shouldRepaint(covariant _ChartPainter old) => true;
}
