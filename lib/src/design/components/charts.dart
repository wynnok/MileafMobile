import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../copy/dates.dart' as copy_dates;
import '../../copy/units.dart' as copy_units;
import '../icons.dart';
import '../layout.dart';
import '../motion.dart';
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

/// 读数头数值的角色（R21.3 / R29）：根页 metricMd，详情与专题 metricSm。
enum ChartReadoutScale { root, detail }

/// R29 图表语法的几何与语义常量（AP05）。绘制与测试共用同一组数值。
abstract final class MileafChartGrammar {
  const MileafChartGrammar._();

  /// 柱值端圆角上限：实际取 min(4, 柱宽/2)。
  static const barEndRadius = 4.0;

  /// 选中竖线：1 逻辑像素、textSecondary。
  static const selectionLine = 1.0;

  /// 选中的 accent 点半径 4，外加 2 像素卡片底色描边（R29）。
  static const selectionDot = 4.0;
  static const selectionRing = 2.0;

  /// 条形图参照刻度：宽 = 柱宽 + 4，线宽 1.5，reference 色。
  static const referenceTickBleed = 4.0;

  /// 步进圆钮：视觉 36、命中 44、图标 20（R24/R27）。
  static const stepVisual = 36.0;
  static const stepHit = 44.0;
  static const stepIcon = 20.0;

  /// CP06 步进语义名称。
  static const previousStep = '上一个数据点';
  static const nextStep = '下一个数据点';

  /// CP11 图表语义提示（替代可见的「点按…读值」这类提示）。
  static const hint = '拖动或轻点查看每天的值；可用调整手势切换日期';

  /// 读数头朗读节点（live region）：可见读数与朗读句的唯一接缝。
  static const readoutLiveKey = ValueKey('chart-readout-live');

  /// M09 身份淡入的节点，测试与调试共用。
  static const identityFadeKey = ValueKey('chart-identity-fade');
}

/// 轴刻度的时间粒度（CP04 DF9）。
enum _AxisGrain { time, day, week, month }

/// CP04 DF9 的分桶边界：DF9 规定「自定义 32–180 天按周分桶」，所以约 7 天
/// （6–8 天容错）走周级，≥25 天走月级，其余按日。
const int _weekGrainHours = 7 * 24;
const int _monthGrainHours = 25 * 24;

_AxisGrain _axisGrain(List<DateTime> times) {
  if (times.length < 2) return _AxisGrain.day;
  final first = times.first;
  final sameDay = times.every(
    (time) =>
        time.year == first.year &&
        time.month == first.month &&
        time.day == first.day,
  );
  if (sameDay) return _AxisGrain.time;
  final gaps = <int>[
    for (var i = 1; i < times.length; i++)
      times[i].difference(times[i - 1]).inHours.abs(),
  ]..sort();
  final median = gaps[gaps.length ~/ 2];
  if (median >= _monthGrainHours) return _AxisGrain.month;
  if (median >= _weekGrainHours - 24 && median <= _weekGrainHours + 24) {
    return _AxisGrain.week;
  }
  return _AxisGrain.day;
}

/// R29 + CP04 DF9 的轴刻度文字。
///
/// 刻度集是绘图区实际画出来的那几个索引，所以「每月第一个刻度写 月日」
/// 只按刻度序列判断，不受被跳过的中间点影响。日级的时间格式可由 tickLabel
/// 覆盖（页面已按站点日历本地化时用它，否则用共享格式化器）。
List<String> chartAxisTickLabels({
  required List<DateTime> times,
  required List<int> indices,
  DateTime? today,
  String Function(DateTime)? tickLabel,
}) {
  if (times.isEmpty || indices.isEmpty) return const [];
  final anchor = today ?? times.last;
  final ticks = [for (final index in indices) times[index]];
  switch (_axisGrain(times)) {
    case _AxisGrain.time:
      return [for (final time in ticks) copy_dates.formatAxisTime(time)];
    case _AxisGrain.month:
      return [
        for (final time in ticks) copy_dates.formatAxisMonth(time, anchor),
      ];
    case _AxisGrain.week:
      return [
        for (final time in ticks) copy_dates.formatAxisWeekBucket(time, anchor),
      ];
    case _AxisGrain.day:
      if (tickLabel != null) return [for (final time in ticks) tickLabel(time)];
      return copy_dates.formatAxisDayTicks(ticks, anchor);
  }
}

/// CP04 的单点日期：日级 DF1、时间级 HH:mm、月级 M月。
String _pointDate(DateTime time, DateTime anchor, _AxisGrain grain) =>
    switch (grain) {
      _AxisGrain.time => copy_dates.formatTime(time),
      _AxisGrain.month => copy_dates.formatMonth(time, anchor),
      _AxisGrain.week || _AxisGrain.day => copy_dates.formatDay(time, anchor),
    };

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
/// stays a zero; the selected point is a 1px rule plus a 4px accent dot, and the
/// complete readout above the plot is the visible reading of that point while
/// the readout callback stays the single spoken sentence (R29).
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
    this.hue,
    this.showYAxis = false,
    this.yRange,
    this.showXAxis = true,
    this.emptyMessage = '还没有采样点',
    this.onActivateSelected,
    this.activationLabel = '查看这一天',
    this.readoutScale = ChartReadoutScale.root,
    this.compactReadout = false,
    this.showSteps = true,
    this.readoutDate,
    this.markerBackdrop,
    this.readoutMinHeight,
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
  /// readout sentence remains the live-region label, so the visible and the
  /// spoken reading cannot diverge. It takes the readout header slot above the
  /// plot (R29).
  final Widget Function(int index)? readoutBuilder;
  final Widget? trailing;
  final String? note;
  final bool onHero;

  /// CL12/CL15：图表的数据身份色相。整张图只用一个色相（多测量同色是既有
  /// 图例规则的一部分，见 `_legend` 注释），参照系列仍走中性 `reference`。
  final MileafHue? hue;
  final bool showYAxis;
  final (double, double)? yRange;
  final bool showXAxis;
  final String emptyMessage;
  final VoidCallback? onActivateSelected;
  final String activationLabel;

  /// 读数头数值角色（R21.3）：根页 metricMd，详情与专题 metricSm。
  final ChartReadoutScale readoutScale;

  /// 紧凑读数行：88 高的节奏图与每日充电图（R29）。
  final bool compactReadout;

  /// 读数头尾部的步进圆钮（R27/R29），两端禁用。
  final bool showSteps;

  /// 读数头的日期格式；不传时按 DF1/DF9 的粒度用共享格式化器。
  final String Function(DateTime)? readoutDate;

  /// 选中点的 2 像素描边色：卡片底色（默认 surface，hero 内用 accentHero）。
  final Color? markerBackdrop;

  /// readoutBuilder 版式的最小高度（R29「读数头最小高度取各状态最大值」）。
  /// builder 由页面排版，组件量不到它内部的行；页面按自己的最长状态传这个值，
  /// 拖动选点时绘图区就不会被顶动。
  final double? readoutMinHeight;

  @override
  State<TimeSeriesChart> createState() => _TimeSeriesChartState();
}

class _TimeSeriesChartState extends State<TimeSeriesChart>
    with SingleTickerProviderStateMixin {
  int _selected = 0;
  final _focus = FocusNode();
  late String _identity;
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: MileafDurations.metricFade,
    value: 1,
  );

  static String _identityOf(TimeSeriesChart chart) => [
    chart.title,
    chart.unit,
    chart.times.length,
    chart.times.isEmpty ? '' : chart.times.first.toIso8601String(),
    chart.times.isEmpty ? '' : chart.times.last.toIso8601String(),
    for (final series in chart.series) series.label,
  ].join('|');

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedIndex ?? 0;
    _identity = _identityOf(widget);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MileafLayout.reduceMotion(context)) _fade.value = 1;
  }

  @override
  void didUpdateWidget(covariant TimeSeriesChart old) {
    super.didUpdateWidget(old);
    if (widget.selectedIndex != null &&
        widget.selectedIndex != old.selectedIndex) {
      _selected = widget.selectedIndex!;
    }
    _selected = _selected.clamp(0, math.max(0, widget.times.length - 1));
    final identity = _identityOf(widget);
    if (identity != _identity) {
      _identity = identity;
      // M09：切换指标或期间时读数头与图 120ms 淡入；减少动效直接切换。
      if (MileafLayout.reduceMotion(context)) {
        _fade.value = 1;
      } else {
        _fade.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (widget.times.isEmpty) return;
    final next = index.clamp(0, widget.times.length - 1);
    final changed = next != _selected;
    setState(() => _selected = next);
    widget.onSelected?.call(next);
    // M07：选中索引变化时一次 selectionClick；程序恢复选点不触发。
    if (changed) HapticFeedback.selectionClick();
  }

  String _tick(DateTime time) {
    final override = widget.tickLabel;
    if (override != null) return override(time);
    final anchor = widget.times.isEmpty ? time : widget.times.last;
    return _pointDate(time, anchor, _axisGrain(widget.times));
  }

  ChartSeries? get _reference {
    for (final series in widget.series) {
      if (series.style == ChartSeriesStyle.reference) return series;
    }
    return null;
  }

  ChartSeries? get _primary {
    for (final series in widget.series) {
      if (series.style != ChartSeriesStyle.reference) return series;
    }
    return null;
  }

  num? _valueAt(int index) {
    final series = _primary;
    if (series == null || index < 0 || index >= series.values.length) {
      return null;
    }
    return series.values[index];
  }

  int _decimals(num value) => value is int || value == value.roundToDouble()
      ? 0
      : (value.abs() >= 100 ? 0 : 1);

  String _number(num value) =>
      copy_units.valueUnit(value, widget.unit, decimals: _decimals(value));

  String _valueText(num? value) => value == null ? '—' : _number(value);

  /// 第三行：参照与差值写成一句（R29）。当前值或参照任一缺失即不给句子，
  /// 不伪造比较。
  String? _contextAt(int index) {
    final value = _valueAt(index);
    final reference = _reference;
    if (value == null || reference == null) return null;
    if (index < 0 || index >= reference.values.length) return null;
    final referenceValue = reference.values[index];
    if (referenceValue == null) return null;
    final difference = value.toDouble() - referenceValue.toDouble();
    final referenceText = '${reference.label} ${_number(referenceValue)}';
    if (difference == 0) return '$referenceText，持平';
    final word = difference > 0 ? '多' : '少';
    return '$referenceText，$word ${_number(difference.abs())}';
  }

  String _readoutDateText(int index) {
    final time = widget.times[index];
    final override = widget.readoutDate;
    if (override != null) return override(time);
    return _tick(time);
  }

  /// The selected point's spoken reading: one sentence per point, still the only
  /// live-region source (R29). Pages may replace it through their readout.
  String _reading(int index) {
    final override = widget.readout;
    if (override != null) return override(index);
    final value = _valueAt(index);
    final context = _contextAt(index);
    return [_readoutDateText(index), _valueText(value), ?context].join('，');
  }

  /// 读数头数值行的预留串：取全序列里最长的一条，切换选点不跳高度。
  String? _longestValue() {
    String? longest;
    for (var i = 0; i < widget.times.length; i++) {
      final text = _valueText(_valueAt(i));
      if (longest == null || text.length > longest.length) longest = text;
    }
    return longest;
  }

  /// 读数头日期行的预留串：跨年或窄宽时可能换行，同样要预留。
  String? _longestDate() {
    String? longest;
    for (var i = 0; i < widget.times.length; i++) {
      final text = _readoutDateText(i);
      if (longest == null || text.length > longest.length) longest = text;
    }
    return longest;
  }

  /// 读数头第三行的预留句：取全序列里最长的一条，切换选点不跳高度。
  String? _longestContext() {
    if (_reference == null) return null;
    String? longest;
    for (var i = 0; i < widget.times.length; i++) {
      final context = _contextAt(i);
      if (context == null) continue;
      if (longest == null || context.length > longest.length) longest = context;
    }
    return longest;
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
    final metaColor = onHero ? colors.heroMuted : colors.textSecondary;
    // 阅读顺序：名称 → 度量 → 窗口 → 指标控件 → 读数头 → 绘图区 → 轴 →
    // 图例 → 限定脚注 → 下钻（R29）。
    final chrome = <Widget>[
      _ChartHeading(
        title: widget.title,
        unit: widget.unit,
        subtitle: widget.subtitle,
        titleColor: titleColor,
        metaColor: metaColor,
      ),
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
          _ChartMessage(message: widget.emptyMessage, color: metaColor),
        ],
      );
    }
    final body = FadeTransition(
      key: MileafChartGrammar.identityFadeKey,
      opacity: CurvedAnimation(parent: _fade, curve: MileafCurves.fade),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _readoutHeader(selected, colors: colors, type: type),
          const SizedBox(height: MileafSpace.s8),
          _plot(context, selected, colors),
          if (_legendEntries().isNotEmpty) ...[
            const SizedBox(height: MileafSpace.s8),
            _legend(colors, metaColor)!,
          ],
          if (widget.note != null) ...[
            const SizedBox(height: MileafSpace.s8),
            Text(widget.note!, style: type.footnote.copyWith(color: metaColor)),
          ],
        ],
      ),
    );
    final actions = _actions(colors, type);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...chrome,
        body,
        if (actions != null) const SizedBox(height: MileafSpace.s8),
        ?actions,
      ],
    );
  }

  /// 下钻行在 live region 之外：选中某天时给一个「看当天」，以及页面自带的
  /// trailing 组件。紧凑读数行把下钻留在同一行（R29）。
  Widget? _actions(MileafColors colors, MileafTextStyles type) {
    final drill = widget.onActivateSelected == null
        ? null
        : TextButton(
            onPressed: widget.onActivateSelected,
            child: Text(
              widget.activationLabel,
              semanticsLabel: widget.activationLabel,
            ),
          );
    final trailing = widget.trailing;
    if (widget.compactReadout) {
      if (trailing == null) return null;
      return Align(
        alignment: Alignment.centerRight,
        child: DefaultTextStyle.merge(
          style: type.footnote.copyWith(color: colors.textSecondary),
          child: trailing,
        ),
      );
    }
    if (drill == null && trailing == null) return null;
    return Row(
      children: [
        ?drill,
        if (trailing != null)
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: DefaultTextStyle.merge(
                style: type.footnote.copyWith(color: colors.textSecondary),
                child: trailing,
              ),
            ),
          ),
      ],
    );
  }

  Widget _readoutHeader(
    int selected, {
    required MileafColors colors,
    required MileafTextStyles type,
  }) {
    final sentence = _reading(selected);
    final dateStyle = type.subheadline.copyWith(
      color: widget.onHero ? colors.heroMuted : colors.textSecondary,
    );
    final valueStyle =
        (widget.readoutScale == ChartReadoutScale.detail
                ? type.metricSm
                : type.metricMd)
            .copyWith(color: widget.onHero ? colors.heroText : colors.text);
    final builder = widget.readoutBuilder;
    if (builder != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: widget.readoutMinHeight ?? 0,
              ),
              child: Semantics(
                key: MileafChartGrammar.readoutLiveKey,
                container: true,
                liveRegion: true,
                label: sentence,
                excludeSemantics: true,
                child: builder(selected),
              ),
            ),
          ),
          if (widget.showSteps) ..._steps(selected, colors),
        ],
      );
    }
    return MileafChartReadout(
      sentence: sentence,
      date: _readoutDateText(selected),
      value: _valueText(_valueAt(selected)),
      reserveValue: _longestValue(),
      reserveDate: _longestDate(),
      contextLine: _contextAt(selected),
      reserveContext: _longestContext(),
      dateStyle: dateStyle,
      valueStyle: valueStyle,
      // 同期对比一句（参照 + 差值）比日期行再小一号（footnote 13）：保持
      // 单行读感，不把「上月同期 …，多 …」折成两行。
      contextStyle: type.footnote.copyWith(
        color: widget.onHero ? colors.heroMuted : colors.textSecondary,
      ),
      colors: colors,
      type: type,
      compact: widget.compactReadout,
      onPrevious: widget.showSteps && selected > 0
          ? () => _select(selected - 1)
          : null,
      onNext: widget.showSteps && selected < widget.times.length - 1
          ? () => _select(selected + 1)
          : null,
      onActivateSelected: widget.compactReadout
          ? widget.onActivateSelected
          : null,
      activationLabel: widget.activationLabel,
    );
  }

  List<Widget> _steps(int selected, MileafColors colors) => [
    _ChartStepButton(
      icon: MileafIconName.back,
      label: MileafChartGrammar.previousStep,
      enabled: selected > 0,
      onTap: () => _select(selected - 1),
      colors: colors,
    ),
    _ChartStepButton(
      icon: MileafIconName.chevron,
      label: MileafChartGrammar.nextStep,
      enabled: selected < widget.times.length - 1,
      onTap: () => _select(selected + 1),
      colors: colors,
    ),
  ];

  Widget _plot(BuildContext context, int selected, MileafColors colors) {
    final onHero = widget.onHero;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final labelStyle = chartAxisLabelStyle(
          color: onHero ? colors.heroMuted : colors.textSecondary,
          scaler: scaler,
        );
        final bounds = widget.yRange ?? _chartBounds(widget.series);
        final ticks = {bounds.$1, (bounds.$1 + bounds.$2) / 2, bounds.$2};
        final sizes = [
          for (final tick in ticks) _measureAxis(_axisNumber(tick), labelStyle),
        ];
        final plotHeight = widget.height ?? MileafLayout.chartHeight(context);
        // R29：Y 轴刻度在绘图区右侧，绘图区左缘与卡内文字起始线对齐。
        final right = widget.showYAxis
            ? sizes.map((size) => size.width).reduce(math.max) + MileafSpace.s8
            : 0.0;
        final plotWidth = math.max(1.0, constraints.maxWidth - right);
        final indices =
            (MileafLayout.largeText(context)
                    ? <int>[0, widget.times.length - 1]
                    : <int>{
                        0,
                        ((widget.times.length - 1) / 2).round(),
                        widget.times.length - 1,
                      })
                .toList()
              ..sort();
        final labels = chartAxisTickLabels(
          times: widget.times,
          indices: indices,
          today: widget.times.last,
          tickLabel: widget.tickLabel,
        );
        final bottom = widget.showXAxis
            ? _measureAxis(
                    labels.isEmpty ? '' : labels.first,
                    labelStyle,
                  ).height +
                  MileafSpace.s8
            // 无 X 轴时仍保住一个底部余量，底部标记不被裁。
            : MileafChartMetrics.currentHalo;
        final topMargin = widget.showYAxis
            ? math.max(MileafChartMetrics.currentHalo, sizes.first.height / 2)
            : MileafChartMetrics.currentHalo;
        final plot = Rect.fromLTWH(
          0,
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
          if (lastFraction == null || (fraction - lastFraction!).abs() > .001) {
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
              hint: MileafChartGrammar.hint,
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
                  height: plot.top + math.max(1.0, plotHeight) + bottom,
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, plotHeight),
                    painter: _ChartPainter(
                      times: widget.times,
                      series: widget.series,
                      selected: selected,
                      plot: plot,
                      progress: 1,
                      // CL53：线取 strong（浅色深一档、深色即 solid），面取亮面。
                      primary:
                          widget.hue?.strong(colors) ??
                          (onHero ? colors.accentHero : colors.accent),
                      fill: widget.hue?.vivid(colors),
                      reference: colors.reference,
                      axis: onHero ? colors.heroMuted : colors.textSecondary,
                      baseline: onHero
                          ? colors.heroText.withValues(alpha: .12)
                          : colors.line,
                      selectionLine: onHero
                          ? colors.heroMuted
                          : colors.textSecondary,
                      markerBackdrop:
                          widget.markerBackdrop ??
                          (onHero ? colors.accentHero : colors.surface),
                      scaler: MediaQuery.textScalerOf(context),
                      yRange: widget.yRange,
                      showYAxis: widget.showYAxis,
                      showXAxis: widget.showXAxis,
                      tickLabels: {
                        for (var i = 0; i < indices.length; i++)
                          indices[i]: labels[i],
                      },
                      largeText: MileafLayout.largeText(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 图例：只解释「位置说不清的那条标记」。
  ///
  /// 三条规则，按顺序生效：
  /// 1. 单系列不出图例——一个标记不需要 key。
  /// 2. 一个测量 + 参照、且这个测量已经被指标控件点名（controls 或
  ///    headerTrailing 的 chip 里就写着它的名字）时，只留参照：实心系列
  ///    已经被标题和控件说过两遍，再配色块就是第三次命名。没有控件点名的
  ///    页面（如统计洞察的「本期 / 参照」）保留完整图例。
  /// 3. 色块只在它能指认时才画。绘图区只拿得到一个主色，多测量
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

  Color _seriesColor(ChartSeries series, MileafColors colors) =>
      switch (series.style) {
        ChartSeriesStyle.reference => colors.reference,
        _ =>
          widget.hue?.strong(colors) ??
              (widget.onHero ? colors.accentHero : colors.accent),
      };

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

/// 完整读数头（R29/PD03）与紧凑读数行（同一朗读源与步进语义）。
///
/// 三行顺序固定：日期 → 数值（含单位）→ 参照与差值一句。第三行的高度按全序列
/// 最长的句子预留，所以切换选点时不跳高度。步进圆钮在读数头尾部，位于 live
/// region 之外，可单独聚焦。
class MileafChartReadout extends StatelessWidget {
  const MileafChartReadout({
    super.key,
    required this.sentence,
    required this.date,
    required this.value,
    this.reserveValue,
    this.reserveDate,
    this.contextLine,
    this.reserveContext,
    required this.dateStyle,
    required this.valueStyle,
    required this.contextStyle,
    required this.colors,
    required this.type,
    this.compact = false,
    this.onPrevious,
    this.onNext,
    this.previousLabel = MileafChartGrammar.previousStep,
    this.nextLabel = MileafChartGrammar.nextStep,
    this.onActivateSelected,
    this.activationLabel = '查看这一天',
  });

  /// 朗读句：live region 的唯一内容，可见行不再各自朗读。
  final String sentence;
  final String date;
  final String value;
  final String? reserveValue;
  final String? reserveDate;
  final String? contextLine;
  final String? reserveContext;
  final TextStyle dateStyle;
  final TextStyle valueStyle;
  final TextStyle contextStyle;
  final MileafColors colors;
  final MileafTextStyles type;
  final bool compact;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final String previousLabel;
  final String nextLabel;
  final VoidCallback? onActivateSelected;
  final String activationLabel;

  @override
  Widget build(BuildContext context) {
    final hasSteps = onPrevious != null || onNext != null;
    final steps = <Widget>[
      _ChartStepButton(
        icon: MileafIconName.back,
        label: previousLabel,
        enabled: onPrevious != null,
        onTap: onPrevious ?? () {},
        colors: colors,
      ),
      _ChartStepButton(
        icon: MileafIconName.chevron,
        label: nextLabel,
        enabled: onNext != null,
        onTap: onNext ?? () {},
        colors: colors,
      ),
    ];
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(
          1.0,
          constraints.maxWidth -
              (hasSteps ? 2 * MileafChartGrammar.stepHit : 0),
        );
        // 没有参照系列时第三行根本不存在：不留空行，别把首屏预算推下去。
        final hasContextRow = contextLine != null || reserveContext != null;
        final reservedHeight = hasContextRow
            ? _reserveLines(
                    contextLine,
                    reserveContext,
                    contextStyle,
                    width,
                    scaler,
                  ) *
                  _lineHeight(contextStyle, scaler)
            : 0.0;
        final valueHeight =
            _reserveLines(value, reserveValue, valueStyle, width, scaler) *
            _lineHeight(valueStyle, scaler);
        final dateHeight =
            _reserveLines(date, reserveDate, dateStyle, width, scaler) *
            _lineHeight(dateStyle, scaler);
        final live = Semantics(
          key: MileafChartGrammar.readoutLiveKey,
          container: true,
          liveRegion: true,
          label: sentence,
          excludeSemantics: true,
          child: compact
              ? Wrap(
                  spacing: MileafSpace.s8,
                  runSpacing: MileafSpace.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(date, style: dateStyle),
                    Text(
                      value,
                      // R29 紧凑读数行：数值用 body 600，不再用度量角色。
                      style: type.body.copyWith(
                        color: valueStyle.color,
                        fontWeight: MileafType.weightSemiBold,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: dateHeight,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(date, style: dateStyle),
                      ),
                    ),
                    SizedBox(
                      height: valueHeight,
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(value, style: valueStyle),
                      ),
                    ),
                    if (hasContextRow)
                      SizedBox(
                        height: reservedHeight,
                        child: contextLine == null
                            ? null
                            : Align(
                                alignment: Alignment.topLeft,
                                child: Text(contextLine!, style: contextStyle),
                              ),
                      ),
                  ],
                ),
        );
        final drillButton = (compact && onActivateSelected != null)
            ? TextButton(
                onPressed: onActivateSelected,
                // D-AP10-04：可见文字与语义统一用页面传入的下钻短语
                // （概览/行程「查看当天」、充电「查看这一天的充电」）。
                child: Text(activationLabel, semanticsLabel: activationLabel),
              )
            : null;
        final inline = Row(
          crossAxisAlignment: compact
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: reservedHeight),
                child: live,
              ),
            ),
            // R29：下钻文字按钮在 live region 之外（读屏要能单独触发），
            // 位置在行尾、步进之前。200% 大字下长短语（充电「查看这一天的
            // 充电」）与步进同行会溢出 88px（D-AP10-04 落地实测），此时下钻
            // 换到行尾独占一行，读数内容保持在原行。
            if (drillButton != null && !MileafLayout.largeText(context))
              drillButton,
            if (hasSteps) ...steps,
          ],
        );
        if (drillButton != null && MileafLayout.largeText(context)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              inline,
              Align(alignment: Alignment.centerRight, child: drillButton),
            ],
          );
        }
        return inline;
      },
    );
  }

  /// 一行实际占几行：取当前文本与预留文本的最大值（至少一行）。
  ///
  /// 只测「当前」与「最长」两条候选，切换选点时不会在两条之间来回跳高度。
  int _reserveLines(
    String? text,
    String? reserve,
    TextStyle style,
    double width,
    TextScaler scaler,
  ) {
    var lines = 1;
    for (final candidate in [text, reserve]) {
      if (candidate == null || candidate.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: candidate, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: null,
      )..layout(maxWidth: width);
      final height = painter.height;
      final lineHeight = painter.preferredLineHeight;
      painter.dispose();
      if (lineHeight <= 0) continue;
      lines = math.max(lines, (height / lineHeight).round());
    }
    return lines;
  }

  double _lineHeight(TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      // 哨兵用拉丁字母：只为量一行的高度，不属于文案账目。
      text: TextSpan(text: 'M', style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }
}

/// 圆形步进按钮：视觉 36、命中 44、图标 20，两端禁用（R24/R27）。
class _ChartStepButton extends StatelessWidget {
  const _ChartStepButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.colors,
  });

  final MileafIconName icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final MileafColors colors;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    label: label,
    child: SizedBox.square(
      dimension: MileafChartGrammar.stepHit,
      child: Center(
        child: SizedBox.square(
          dimension: MileafChartGrammar.stepVisual,
          child: Material(
            color: colors.segmentTrack,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onTap : null,
              // R29：键盘路径「Tab 到图表、←/→ 步进」沿既有实现。步进圆钮
              // 若进入焦点顺序，第一次 Tab 会落在读数头尾部而不是绘图区，
              // 键盘用户反而失去左右键步进。读屏仍可通过按钮语义触发。
              canRequestFocus: false,
              child: Center(
                child: MileafIcon(
                  icon,
                  size: MileafChartGrammar.stepIcon,
                  color: enabled ? colors.text : colors.textFaint,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
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
  fontSize: scaler.scale(fontSize ?? MileafType.captionSize),
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
    child: Text(title, style: context.type.headline.copyWith(color: color)),
  );
}

/// 标题（是什么）、度量（轴在数什么）、窗口（轴覆盖到哪）。
///
/// 三件东西按左→右的固定次序排一行：标题定住左端，窗口落在右端、与绘图区
/// 的右沿对齐；单位紧贴标题，是标题所命名坐标轴的度量，不是第四个标题。
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
      spacing: MileafSpace.s8,
      runSpacing: MileafSpace.s4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _ChartTitle(title: title, color: titleColor),
        if (unit.isNotEmpty)
          Text(
            unit,
            style: type.subheadline.copyWith(color: metaColor),
            // 单位只是标题的尺度注脚：读屏念「单位km」，但标题仍是唯一的
            // header 节点，导航不会被这个标签打断。
            semanticsLabel: '单位$unit',
          ),
      ],
    );
    final range = subtitle == null
        ? null
        : Text(subtitle!, style: type.subheadline.copyWith(color: metaColor));
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
/// Which entries appear is decided by the chart state; this widget only lays
/// them out. It sits below the X axis (R29).
class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.entries, required this.textColor});

  final List<({String label, Color color, bool dashed, bool swatch})> entries;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return Wrap(
      spacing: MileafSpace.s16,
      runSpacing: MileafSpace.s4,
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
                const SizedBox(width: MileafSpace.s8),
              ],
              Flexible(
                child: Text(
                  entry.label,
                  style: type.subheadline.copyWith(color: textColor),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// 标记的缩影：实线 12×2 与参照的 4/2 虚线同宽，图例本身就是图形语法的一段。
class _LegendMark extends StatelessWidget {
  const _LegendMark({super.key, required this.color, required this.dashed});

  /// The sample is one bar slot wide (barMaxWidth), so the key never reads
  /// as a second, invented symbol.
  static const _width = MileafChartMetrics.barMaxWidth;

  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
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
                // 与柱同一口径：min(4, 宽/2)；样本宽 12，所以是 4。
                borderRadius: BorderRadius.circular(
                  math.min(MileafChartGrammar.barEndRadius, _width / 2),
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
/// 柱/茎式单序列图表（每日里程、每日充电等节奏图）。
///
/// CL12/CL15：`hue` 由 MC08 补（随每日充电图接线）——本类只是
/// [TimeSeriesChart] 的 stem 包装，身份色相必须原样转发，缺省 null 与改造前
/// 像素等价。
class StemChart extends StatelessWidget {
  const StemChart({
    super.key,
    required this.title,
    required this.unit,
    required this.times,
    required this.values,
    required this.semanticsLabel,
    this.hue,
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
    this.readoutScale = ChartReadoutScale.root,
    this.compactReadout = false,
    this.showSteps = true,
    this.readoutDate,
  });

  final String title;
  final String unit;
  final List<DateTime> times;
  final List<num?> values;
  final String semanticsLabel;

  /// 这一张图的数据身份色相；缺省 null 时与改造前像素等价。
  final MileafHue? hue;
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
  final ChartReadoutScale readoutScale;
  final bool compactReadout;
  final bool showSteps;
  final String Function(DateTime)? readoutDate;

  @override
  Widget build(BuildContext context) => TimeSeriesChart(
    title: title,
    unit: unit,
    times: times,
    series: [
      ChartSeries(label: title, values: values, style: ChartSeriesStyle.stem),
    ],
    semanticsLabel: semanticsLabel,
    hue: hue,
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
    readoutScale: readoutScale,
    compactReadout: compactReadout,
    showSteps: showSteps,
    readoutDate: readoutDate,
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
            // CL22-exempt: 柱底 1px 取整，是图形细节不是间距/圆角档位。
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
    this.fill,
    required this.reference,
    required this.axis,
    this.yRange,
    required this.baseline,
    required this.selectionLine,
    required this.markerBackdrop,
    required this.scaler,
    required this.showYAxis,
    required this.showXAxis,
    required this.tickLabels,
    required this.largeText,
  });

  final List<DateTime> times;
  final List<ChartSeries> series;
  final int selected;
  final Rect plot;
  final double progress;
  final Color primary;

  /// 面积填充与选中点圆心用的亮面色（CL53）。为 null 时退回 [primary] 与
  /// 改造前的 16% 淡填充——未接色相的图表（如 hero 内嵌图）保持原样。
  final Color? fill;
  final Color reference;
  final Color axis;
  final Color baseline;
  final Color selectionLine;
  final Color markerBackdrop;
  final TextScaler scaler;
  final (double, double)? yRange;
  final bool showYAxis;
  final bool showXAxis;
  final Map<int, String> tickLabels;
  final bool largeText;

  @override
  void paint(Canvas canvas, Size size) {
    final (low, high) = yRange ?? _chartBounds(series);
    final span = high - low;
    double y(num value) => plot.bottom - (value - low) / span * plot.height;
    // Inset the drawn data so the marks never touch the plot edge.
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
      // R29：刻度文字在绘图区右侧，默认 3 个刻度。
      for (final value in {low, if (!largeText) (low + high) / 2, high}) {
        final text = _axisNumber(value);
        final painter = TextPainter(
          text: TextSpan(text: text, style: labelStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        painter.paint(
          canvas,
          Offset(plot.right + MileafSpace.s8, y(value) - painter.height / 2),
        );
        painter.dispose();
      }
    }
    if (showXAxis) {
      for (final entry in tickLabels.entries) {
        final index = entry.key;
        label(
          entry.value,
          Offset(x(index), plot.bottom + MileafSpace.s8),
          centered: index != 0 && index != times.length - 1,
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

    final barWidth = _barWidth();
    for (final chart in series) {
      if (chart.style == ChartSeriesStyle.reference) {
        _drawReference(canvas, chart, x, y, barWidth);
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
    _drawSelection(canvas, x, y);
    canvas.restore();
  }

  double _barWidth() {
    final slot =
        (plot.width - 2 * MileafChartMetrics.currentHalo) /
        math.max(1, times.length);
    return math.min(
      MileafChartMetrics.barMaxWidth,
      slot * MileafChartMetrics.barSlotCoverage,
    );
  }

  /// R29 选中标记：1 逻辑像素竖线 + 半径 4 的 accent 点 + 2 像素卡片底色描边，
  /// 不再有光晕。真实 0 也按同一标记选中，柱体积仍为零。
  void _drawSelection(
    Canvas canvas,
    double Function(int) x,
    double Function(num) y,
  ) {
    ChartSeries? first;
    for (final chart in series) {
      if (chart.style != ChartSeriesStyle.reference) {
        first = chart;
        break;
      }
    }
    if (first == null) return;
    if (selected < 0 || selected >= first.values.length) return;
    final value = first.values[selected];
    if (value == null) return;
    final point = Offset(x(selected), y(value));
    canvas.drawLine(
      Offset(point.dx, plot.top),
      Offset(point.dx, plot.bottom),
      Paint()
        ..color = selectionLine
        ..strokeWidth = MileafChartGrammar.selectionLine,
    );
    canvas.drawCircle(
      point,
      MileafChartGrammar.selectionDot + MileafChartGrammar.selectionRing,
      Paint()..color = markerBackdrop,
    );
    final center = fill;
    if (center == null) {
      canvas.drawCircle(
        point,
        MileafChartGrammar.selectionDot,
        Paint()..color = primary,
      );
      return;
    }
    // CL54：亮面圆心 + strong 描边。亮面单独对白底只有 2.1–2.5:1，边界由
    // 描边补齐；这枚点因此是页面上唯一「100% 亮面」的图形。
    canvas.drawCircle(
      point,
      MileafChartGrammar.selectionDot,
      Paint()..color = center,
    );
    canvas.drawCircle(
      point,
      MileafChartGrammar.selectionDot,
      Paint()
        ..color = primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = MileafChartMetrics.currentRing,
    );
  }

  void _drawLine(
    Canvas canvas,
    ChartSeries chart,
    double Function(int) x,
    double Function(num) y,
  ) {
    final runs = chartRuns(chart.values);
    // CL53：接了色相的图表用亮面做填充，深一档的 strong 做线——面与线是
    // 两个不同的色阶，而不是同一个颜色的两种透明度。没有色相时保持改造前
    // 的「同色 16% 淡填充」，避免未接线的 hero 图被顺手改掉。
    final areaBase = fill ?? primary;
    final areaMax = fill == null
        ? MileafChartMetrics.areaMaxOpacity
        : MileafChartMetrics.fillMaxOpacity;
    final areaMin = fill == null
        ? MileafChartMetrics.areaMinOpacity
        : MileafChartMetrics.fillMinOpacity;
    final areaPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              areaBase.withValues(alpha: areaMax),
              areaBase.withValues(alpha: areaMin),
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

  /// 条形图：每个时间槽一段短横刻度（宽 = 柱宽 + 4，1.5 线宽）；
  /// 折线图：1.5 虚线 4/4（R29）。
  void _drawReference(
    Canvas canvas,
    ChartSeries chart,
    double Function(int) x,
    double Function(num) y,
    double barWidth,
  ) {
    var bars = false;
    for (final candidate in series) {
      if (candidate.style == ChartSeriesStyle.bars ||
          candidate.style == ChartSeriesStyle.stem) {
        bars = true;
        break;
      }
    }
    final paint = Paint()
      ..color = reference
      ..strokeWidth = MileafChartMetrics.referenceStroke
      ..strokeCap = StrokeCap.round;
    if (bars) {
      final half = (barWidth + MileafChartGrammar.referenceTickBleed) / 2;
      for (var i = 0; i < chart.values.length; i++) {
        final value = chart.values[i];
        if (value == null) continue;
        final at = y(value);
        canvas.drawLine(
          Offset(x(i) - half, at),
          Offset(x(i) + half, at),
          paint,
        );
      }
      return;
    }
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

  /// 柱：宽 ≤12，只在数值端做 min(4, 宽/2) 圆角；真实 0 是基线上的点，
  /// null 留空（R29）。
  void _drawBars(
    Canvas canvas,
    ChartSeries chart,
    double Function(int) x,
    double Function(num) y,
  ) {
    final width = _barWidth();
    final radius = Radius.circular(
      math.min(MileafChartGrammar.barEndRadius, width / 2),
    );
    const zero = Radius.zero;
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
      final positive = value >= 0;
      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: positive ? radius : zero,
        topRight: positive ? radius : zero,
        bottomLeft: positive ? zero : radius,
        bottomRight: positive ? zero : radius,
      );
      // CL53.1：柱体仍取 strong（浅色 5.90:1 / 深色 7.42:1）。试过「亮面填充 +
      // strong 描边」：图形卡本身是色相洗底，同色相的亮面压在同色相的浅底上
      // 只剩 1.5:1，远看像空心描边，反而更弱——亮面只适合压在中性底上。
      canvas.drawRRect(rrect, Paint()..color = primary);
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
