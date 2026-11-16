import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';
import 'focus_ring.dart';

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

/// Known values keep their slot, including a baseline mark for real zero.
List<int> chartStemIndices(List<num?> values) => [
  for (var i = 0; i < values.length; i++)
    if (values[i] != null) i,
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
    this.headerTrailing,
    this.height,
    this.plotKey,
    this.tickLabel,
    this.selectedIndex,
    this.onSelected,
    this.readout,
    this.readoutBuilder,
    this.trailing,
    this.note,
    this.onHero = false,
    this.showYAxis = false,
    this.yRange,
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

  /// 指标控件。占标题之下的独立一行：它按顺序改变图里的数据身份，不该和
  /// 标题、窗口抢同一行宽。
  final Widget? headerTrailing;
  final double? height;
  final Key? plotKey;
  final String Function(DateTime)? tickLabel;
  final int? selectedIndex;
  final ValueChanged<int>? onSelected;
  final String Function(int index)? readout;

  /// Replaces the plain reading with a composed view of the same point, for
  /// pages that need the date, value and reference in separate roles. The
  /// [readout] sentence remains the live-region label, so the visible and the
  /// spoken reading cannot diverge.
  final Widget Function(int index)? readoutBuilder;
  final Widget? trailing;
  final String? note;
  final bool onHero;
  final bool showYAxis;
  final (double, double)? yRange;
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
    // R06.6：可比时读值带「参照区间名 参照值（差 ±d）」；当前值或参照值
    // 任一缺失即省略参照段——不伪造比较，不按分母折百分比。
    final references = widget.series
        .where((s) => s.style == ChartSeriesStyle.reference)
        .toList();
    final reference = references.isEmpty ? null : references.first;
    if (value != null &&
        reference != null &&
        index < reference.values.length &&
        reference.values[index] != null) {
      final refValue = reference.values[index]!;
      final diff = value.toDouble() - refValue.toDouble();
      final sign = diff > 0 ? '+' : '';
      return '${_tick(date)} · ${_value(value)} · ${reference.label} '
          '${_format(refValue)} ${widget.unit}'
          '（差 $sign${_format(diff)} ${widget.unit}）';
    }
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
    // 标尺文字（轴刻度、单位、区间）共用一个淡档；图例是要被读懂的词，
    // 抬到 muted 一档，否则虚线标签在浅色底上会先消失。
    final legendColor = onHero ? colors.heroMuted : colors.textMuted;
    // 阅读顺序：名称 → 度量 → 窗口 → 指标控件 → key → 图形。图例不是标题
    // 的一部分，它解释的是下方那批标记，所以贴到绘图区之上（R01 对齐 + 用户
    // 要求的「一行只讲一件事」），而不是挤在标题右侧。
    final heading = _ChartHeading(
      title: widget.title,
      unit: widget.unit,
      subtitle: widget.subtitle,
      titleColor: titleColor,
      metaColor: faint,
    );
    final legend = _legend(colors, legendColor);
    // R01：标题到所属内容 12，控件之后再回到 8。标题因此拥有整块图表，而
    // 控件、图例、绘图区是同属它的三段。
    final chrome = <Widget>[
      heading,
      if (widget.headerTrailing != null) ...[
        const SizedBox(height: MileafSpace.s12),
        widget.headerTrailing!,
      ],
      if (widget.controls != null) ...[
        SizedBox(
          height: widget.headerTrailing == null
              ? MileafSpace.s12
              : MileafSpace.s8,
        ),
        widget.controls!,
      ],
    ];
    if (widget.times.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...chrome,
          _ChartMessage(message: widget.emptyMessage, color: faint),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...chrome,
        if (legend != null) ...[const SizedBox(height: MileafSpace.s8), legend],
        const SizedBox(height: MileafSpace.s8),
        LayoutBuilder(
          builder: (context, constraints) {
            final scaler = MediaQuery.textScalerOf(context);
            final labelStyle = chartAxisLabelStyle(
              color: faint,
              scaler: scaler,
            );
            final bounds = widget.yRange ?? _chartBounds(widget.series);
            final ticks = {bounds.$1, (bounds.$1 + bounds.$2) / 2, bounds.$2};
            final sizes = [
              for (final tick in ticks)
                _measureAxis(_axisNumber(tick), labelStyle),
            ];
            final plotHeight =
                widget.height ?? MileafLayout.chartHeight(context);
            final left = widget.showYAxis
                ? sizes.map((s) => s.width).reduce(math.max) + MileafSpace.s8
                : 0.0;
            final bottom = widget.showXAxis
                ? _measureAxis(_tick(widget.times.first), labelStyle).height +
                      MileafSpace.s8
                // 无 X 轴时仍保住一个底部 halo，底部标记不被裁（R06.4）。
                : MileafChartMetrics.currentHalo;
            final plotWidth = math.max(1.0, constraints.maxWidth - left);
            // Spec §8: the current marker is a 4px point inside an 8px halo.
            // The box reserves one halo of margin above the plot (plus half
            // the Y-tick label when a Y axis is shown) and at least one halo
            // below it, so a mark at the maximum, the minimum, a negative
            // value or a real zero is never cut by the plot edge. With a Y
            // axis the top margin also carries half the tick label
            // (R06: 轴留白按实际 TextPainter 度量), which grows past the
            // halo at large text sizes.
            final topMargin = widget.showYAxis
                ? math.max(
                    MileafChartMetrics.currentHalo,
                    sizes.first.height / 2,
                  )
                : MileafChartMetrics.currentHalo;
            final plot = Rect.fromLTWH(
              left,
              topMargin,
              plotWidth,
              math.max(1.0, plotHeight),
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
              child: MileafFocusRing(
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
                      // R06：盒子高度按实际绘制范围给足——顶轴留白 +
                      // 绘图区 + 底部 X 轴行高，大字下随文字增高，不截字。
                      height: plot.top + math.max(1.0, plotHeight) + bottom,
                      child: CustomPaint(
                        size: Size(constraints.maxWidth, plotHeight),
                        painter: _ChartPainter(
                          times: widget.times,
                          series: widget.series,
                          selected: selected,
                          plot: plot,
                          progress: 1,
                          primary: onHero ? colors.accentHero : colors.accent,
                          reference: colors.reference,
                          axis: faint,
                          // Spec §8: the only horizontal grid line is the zero
                          // baseline — `line` on paper, heroText 12% on a hero.
                          baseline: onHero
                              ? colors.heroText.withValues(alpha: .12)
                              : colors.line,
                          scaler: MediaQuery.textScalerOf(context),
                          yRange: widget.yRange,
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
        // R06.6/§1.4: the plot keeps 8 from its reading.
        const SizedBox(height: MileafSpace.s8),
        _readingBlock(context, selected),
        if (widget.onActivateSelected != null &&
            MileafLayout.largeText(context))
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

  /// The selected point's reading. A page may supply a composed view through
  /// [TimeSeriesChart.readoutBuilder]; the plain sentence then stays the single
  /// live-region label so the spoken reading never drifts from the visible one.
  Widget _readingBlock(BuildContext context, int selected) {
    final colors = context.colors;
    final type = context.type;
    final faint = widget.onHero ? colors.heroFaint : colors.textFaint;
    final sentence = _reading(selected);
    final reading = widget.readoutBuilder == null
        ? Text(
            sentence,
            style: type.body.copyWith(
              color: widget.onHero ? colors.heroText : colors.text,
            ),
          )
        : widget.readoutBuilder!(selected);
    final trailing = widget.trailing == null
        ? null
        : DefaultTextStyle.merge(
            style: type.label.copyWith(color: faint),
            child: widget.trailing!,
          );
    // The live region covers the reading alone: the drill action stays a
    // sibling so a page that supplies both a builder and an action keeps the
    // button reachable instead of silently excluding it.
    final node = Semantics(
      container: true,
      explicitChildNodes: widget.readoutBuilder == null,
      liveRegion: true,
      label: widget.readoutBuilder == null ? null : sentence,
      excludeSemantics: widget.readoutBuilder != null,
      child: reading,
    );
    final large = MileafLayout.largeText(context);
    return large
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [node, ?trailing],
          )
        : Row(
            children: [
              Expanded(child: node),
              if (widget.onActivateSelected != null)
                TextButton(
                  onPressed: widget.onActivateSelected,
                  child: Text('看当天', semanticsLabel: widget.activationLabel),
                ),
              ?trailing,
            ],
          );
  }

  Color _seriesColor(ChartSeries series, MileafColors colors) =>
      switch (series.style) {
        ChartSeriesStyle.reference => colors.reference,
        _ => widget.onHero ? colors.accentHero : colors.accent,
      };

  /// 图例：只解释「位置说不清的那条标记」。
  ///
  /// 三条规则，按顺序生效：
  /// 1. 单系列不出图例——一个标记不需要 key。
  /// 2. 一个测量 + 参照、且这个测量已经被指标控件点名（`controls` 或
  ///    `headerTrailing` 的 chip 里就写着它的名字）时，只留参照：实心系列
  ///    已经被标题和控件说过两遍，再配色块就是第三次命名。没有控件点名的
  ///    页面（如统计洞察的「本期 / 参照」）保留完整图例，否则实心系列在可见
  ///    层就失去了名字。
  /// 3. 色块只在它能指认时才画。绘图区只拿得到一个 `primary`，多测量
  ///    （净/毛电耗、AC/DC）的线同色，此时给每条都画同色块等于宣称它们相同，
  ///    所以多测量只列名字；参照虚线与其它标记形状不同，永远带样本。
  Widget? _legend(MileafColors colors, Color textColor) {
    final entries = _legendEntries();
    if (entries.isEmpty) return null;
    return _ChartLegend(
      entries: [
        for (final entry in entries)
          (
            label: entry.series.label,
            color: _seriesColor(entry.series, colors),
            dashed: entry.series.style == ChartSeriesStyle.reference,
            swatch: entry.swatch,
          ),
      ],
      textColor: textColor,
    );
  }

  List<({ChartSeries series, bool swatch})> _legendEntries() {
    final series = widget.series;
    if (series.length < 2) return const [];
    final measures = [
      for (final s in series)
        if (s.style != ChartSeriesStyle.reference) s,
    ];
    final named = widget.controls != null || widget.headerTrailing != null;
    final keyed = measures.length == 1 && named
        ? [
            for (final s in series)
              if (s.style == ChartSeriesStyle.reference) s,
          ]
        : series;
    // A single measure is one shape, so its sample is honest; two or more share
    // one colour and a sample would claim they are the same.
    return [
      for (final s in keyed)
        (
          series: s,
          swatch: s.style == ChartSeriesStyle.reference || measures.length == 1,
        ),
    ];
  }
}

/// Style for the text the chart paints itself (axis labels, tick labels).
///
/// The painter cannot read the theme, so the family and the CJK fallback are
/// declared here once: self-drawn chart text falls back to the same face as
/// every other number on the page. Size follows the full text scaler (R06.4:
/// 自绘轴文字应用完整 TextScaler，不设放大上限).
TextStyle chartAxisLabelStyle({
  required Color color,
  required TextScaler scaler,
  double? fontSize,
}) => TextStyle(
  fontFamily: MileafType.family,
  fontFamilyFallback: MileafType.fallback,
  fontSize: scaler.scale(fontSize ?? MileafChartMetrics.axisLabelSize),
  color: color,
  height: 1.5,
  fontFeatures: const [FontFeature.tabularFigures()],
);

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

/// 标题（是什么）、度量（轴在数什么）、窗口（轴覆盖到哪）。
///
/// 三件东西按左→右的固定次序排一行：标题定住左端，窗口落在右端、与绘图区
/// 的右沿对齐；单位紧贴标题（间距 6，与 `MetricBlock` 的「标签→值」同一对
/// 节奏），是标题所命名坐标轴的度量，不是第四个标题。
///
/// 与 [SectionHeader] 同构：标题都用 `type.title`、区间都用 `type.label` 的
/// 淡档、大字时区间落到标题下一行并共用左缘——所以图表头和它上面的章节标题
/// 不会各说各话。
class _ChartHeading extends StatelessWidget {
  const _ChartHeading({
    required this.title,
    required this.unit,
    required this.subtitle,
    required this.titleColor,
    required this.metaColor,
  });

  final String title;
  final String unit;
  final String? subtitle;
  final Color titleColor;
  final Color metaColor;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final heading = Wrap(
      spacing: MileafSpace.inline6,
      runSpacing: MileafSpace.s4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _ChartTitle(title: title, color: titleColor),
        if (unit.isNotEmpty)
          Text(
            unit,
            style: type.micro.copyWith(color: metaColor),
            // 单位只是标题的尺度注脚：读屏念「单位km」，但标题仍是唯一的
            // header 节点，导航不会被这个 12 号标签打断。
            semanticsLabel: '单位$unit',
          ),
      ],
    );
    final range = subtitle == null
        ? null
        : Text(subtitle!, style: type.label.copyWith(color: metaColor));
    if (range == null) return heading;
    if (MileafLayout.largeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          const SizedBox(height: MileafSpace.s4),
          range,
        ],
      );
    }
    // 窗口可以是长区间（如跨年日期），所以它必须能收窄换行，不能把标题行
    // 顶破；`spaceBetween` 保证它收窄之后仍然贴着右沿。
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: heading),
        const SizedBox(width: MileafSpace.s12),
        Flexible(child: range),
      ],
    );
  }
}

/// One row of marks and names, read left to right, never wider than the plot.
/// Which entries appear is decided by `_TimeSeriesChartState._legend`; this
/// widget only lays them out.
class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.entries, required this.textColor});

  final List<({String label, Color color, bool dashed, bool swatch})> entries;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return Wrap(
      spacing: MileafSpace.s16,
      runSpacing: MileafSpace.inline6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final entry in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (entry.swatch) ...[
                _LegendMark(
                  key: ValueKey('chart-legend-mark-${entry.label}'),
                  color: entry.color,
                  dashed: entry.dashed,
                ),
                const SizedBox(width: MileafSpace.inline6),
              ],
              Text(entry.label, style: type.micro.copyWith(color: textColor)),
            ],
          ),
      ],
    );
  }
}

/// 标记的缩影：实线 12×2 与参照的 4/2 虚线同宽，图例本身就是图形语法的一段。
class _LegendMark extends StatelessWidget {
  const _LegendMark({super.key, required this.color, required this.dashed});

  /// The sample is one bar slot wide (`barMaxWidth`), so the key never reads
  /// as a second, invented symbol.
  static const _width = MileafChartMetrics.barMaxWidth;

  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    // 与绘图区同一套几何：主线 2、参照 1.5 且 4/4 虚线（R06.5）。数值全部取自
    // `MileafChartMetrics`，token 一改，样本和图一起动。
    const dash = MileafChartMetrics.referenceDash;
    return SizedBox(
      width: _width,
      height: MileafChartMetrics.lineStroke,
      child: dashed
          ? Row(
              children: [
                Container(
                  width: dash.first,
                  height: MileafChartMetrics.referenceStroke,
                  color: color,
                ),
                SizedBox(width: dash.last),
                Container(
                  width: dash.first,
                  height: MileafChartMetrics.referenceStroke,
                  color: color,
                ),
              ],
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(
                  MileafChartMetrics.barRadius,
                ),
              ),
            ),
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

/// Daily charging stems with baseline marks for zero and gaps for null.
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
    this.headerTrailing,
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

  /// 指标控件。占标题之下的独立一行：它按顺序改变图里的数据身份，不该和
  /// 标题、窗口抢同一行宽。
  final Widget? headerTrailing;
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
    headerTrailing: headerTrailing,
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
          Paint()..color = color,
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
    this.yRange,
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
  final (double, double)? yRange;
  final bool showYAxis;
  final bool showXAxis;
  final String Function(DateTime) tick;
  final bool largeText;

  @override
  void paint(Canvas canvas, Size size) {
    final (low, high) = yRange ?? _chartBounds(series);
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

    final labelStyle = chartAxisLabelStyle(color: axis, scaler: scaler);
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

    if (showYAxis) {
      for (final value in {low, if (!largeText) (low + high) / 2, high}) {
        label(
          _axisNumber(value),
          Offset(
            0,
            y(value) - _measureAxis(_axisNumber(value), labelStyle).height / 2,
          ),
        );
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
          Offset(x(index), plot.bottom + MileafSpace.s8),
          centered: centered,
          right: index == times.length - 1,
        );
      }
    }

    const halo = MileafChartMetrics.currentHalo;
    final clip = Rect.fromLTRB(
      plot.left,
      plot.top - halo,
      plot.left + plot.width * progress.clamp(0.0, 1.0),
      plot.bottom + halo,
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
    final value = first != null && selected < first.values.length
        ? first.values[selected]
        : null;
    if (first != null && value != null) {
      // The selected mark is an endpoint plus halo for every series style, so
      // selection never relies on fading the other data. A real zero is the one
      // exception, in every style: it keeps the zero dot so the selection
      // marker can never be mistaken for bar volume.
      final point = Offset(x(selected), y(value));
      canvas.drawCircle(
        point,
        MileafChartMetrics.currentHalo,
        Paint()..color = primary.withValues(alpha: .2),
      );
      canvas.drawCircle(
        point,
        value == 0
            ? MileafChartMetrics.zeroDot
            : MileafChartMetrics.currentPoint,
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
      // R06：参照 1.5 虚线 4/4，比 2px 主线细一档。
      ..strokeWidth = MileafChartMetrics.referenceStroke
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
        Paint()..color = primary,
      );
      if (value == 0) {
        canvas.drawCircle(
          Offset(x(i), y(0)),
          MileafChartMetrics.zeroDot,
          Paint()..color = primary,
        );
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
      final top = Offset(x(index), y(value));
      final bottom = Offset(x(index), y(0));
      canvas.drawLine(
        bottom,
        top,
        Paint()
          ..color = primary
          ..strokeWidth = MileafChartMetrics.stemStroke
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        top,
        MileafChartMetrics.stemEndpoint,
        Paint()..color = primary,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => true;
}

Size _measureAxis(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final size = painter.size;
  painter.dispose();
  return size;
}

(double, double) _chartBounds(List<ChartSeries> series) {
  final known = series.expand((s) => s.values).whereType<num>().toList();
  var high = known.isEmpty ? 1.0 : known.reduce(math.max).toDouble();
  final low = math.min(
    0.0,
    known.isEmpty ? 0.0 : known.reduce(math.min).toDouble(),
  );
  if (high == low) high = low + 1;
  final step = _niceStep((high - low) / 3);
  high = (high / step).ceil() * step;
  if (high == low) high = low + step;
  return (low, high);
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
