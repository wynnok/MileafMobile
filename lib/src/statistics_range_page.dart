import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design/components/components.dart';
import 'design/icons.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'reading_scope.dart';
import 'statistics_insights_page.dart';
import 'statistics_usage_page.dart';
import 'workspace.dart';
import 'range_observations_contract.g.dart' as dto;

class RangeObservationPage extends StatefulWidget {
  const RangeObservationPage({
    super.key,
    required this.context,
    this.expanded = false,
  });
  final StatisticsInsightsContext context;
  final bool expanded;
  @override
  State<RangeObservationPage> createState() => _RangeObservationPageState();
}

class _RangeObservationPageState extends State<RangeObservationPage>
    with WidgetsBindingObserver {
  Map<String, dynamic>? data;
  String? error;
  bool loading = false;
  int months = 6, sequence = 0, selected = 0;
  String? identity;
  DateTime? checkedAt;

  /// The owner is actually looking at this topic: its own route is on top and
  /// the statistics tab it lives in is the selected one.
  bool get readingNow =>
      ReadingScope.isActive(context) &&
      (ModalRoute.of(context)?.isCurrent ?? false);

  String get currentIdentity {
    final c = widget.context;
    return '${c.workspace.session.current?.generation}/${c.workspace.selectedId}/${c.workspace.calendar?.identifier}/${c.workspace.revision}/${c.features['range_observations']}/${c.workspace.calendar?.day(c.workspace.session.now())}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    identity = currentIdentity;
    load();
  }

  @override
  void didUpdateWidget(covariant RangeObservationPage old) {
    super.didUpdateWidget(old);
    // A hidden or covered topic records nothing and reads nothing; the next
    // visible rebuild picks the change up.
    if (identity != currentIdentity && readingNow) {
      identity = currentIdentity;
      data = null;
      load();
    }
  }

  @override
  void dispose() {
    sequence++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        readingNow &&
        (checkedAt == null ||
            widget.context.workspace.session
                    .now()
                    .difference(checkedAt!)
                    .inSeconds >=
                30 ||
            identity != currentIdentity)) {
      if (identity != currentIdentity) {
        identity = currentIdentity;
        data = null;
      }
      load();
    }
  }

  Future<void> load({bool force = false}) async {
    final c = widget.context,
        w = c.workspace,
        owner = w.session.current,
        id = w.selectedId,
        cal = w.calendar;
    final attempt = ++sequence;
    if (c.features['range_observations'] != true ||
        owner == null ||
        id == null ||
        cal == null) {
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    final captured = currentIdentity;
    bool valid() =>
        mounted &&
        sequence == attempt &&
        captured == currentIdentity &&
        w.session.isCurrent(owner);
    try {
      final r = await w.cache.get(
        owner,
        'vehicles/$id/range-observations',
        query: {
          'months': '$months',
          'to': w.session.now().toUtc().toIso8601String(),
          'tz': cal.identifier,
        },
        force: force,
      );
      final parsed = dto.RangeObservations.fromJson(r.body);
      if (parsed.query.vehicleId != id ||
          parsed.query.tz != cal.identifier ||
          parsed.query.filters['months'] != months ||
          parsed.query.timeBasis != 'ended_at' ||
          parsed.method != 'session-day-rated-range-v1' ||
          parsed.version != 1 ||
          parsed.rangeKind != 'rated' ||
          parsed.socSource != 'battery_level') {
        throw const FormatException('Mismatched range observation context');
      }
      if (valid()) {
        setState(() {
          checkedAt = w.session.now();
          data = r.body;
          selected = math.max(0, (data!['buckets'] as List).length - 1);
        });
      }
    } catch (_) {
      if (valid()) {
        setState(() => error = '续航观察读取失败${data == null ? '' : '，保留上次结果'}');
      }
    } finally {
      if (valid()) setState(() => loading = false);
    }
  }

  String value(Object? x) => x is num ? x.toStringAsFixed(1) : '—';

  /// R06：趋势图例用真实编码色样，区分月中位数折线与P10–P90波动带。
  Widget _legend(BuildContext context) {
    final colors = context.colors;
    final style = context.type.label.copyWith(color: colors.textMuted);
    return Wrap(
      spacing: MileafSpace.s16,
      runSpacing: MileafSpace.s4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 16, height: 2, color: colors.accent),
            const SizedBox(width: MileafSpace.s4),
            // R03：大字下图例文字换行重排，色样固定，不横向溢出。
            Flexible(child: Text('月中位数', style: style)),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 10,
              decoration: BoxDecoration(
                color: colors.accent.withValues(
                  alpha: MileafChartMetrics.areaMaxOpacity,
                ),
                borderRadius: BorderRadius.circular(MileafRadius.xs),
              ),
            ),
            const SizedBox(width: MileafSpace.s4),
            Flexible(child: Text('P10–P90有效日波动带', style: style)),
          ],
        ),
      ],
    );
  }

  /// R06.3/R06.4/R06.7：绘图区高度沿专题200（大字240留字面量，沿
  /// mapHeight 先例）；轴文字应用完整TextScaler；点按/拖动映射与绘制
  /// 共用同一刻度尺和轴留白；键盘左右与语义增减选择月份。
  Widget _trendChart(
    BuildContext context,
    List<Map<String, dynamic>> rows, {
    required CalendarContext calendar,
    required bool large,
    required _RangeScale scale,
    required double leftPad,
  }) {
    void pick(double dx, double width) {
      if (width <= leftPad) return;
      setState(() {
        selected = ((dx - leftPad) / (width - leftPad) * rows.length)
            .floor()
            .clamp(0, rows.length - 1);
      });
    }

    return Semantics(
      container: true,
      label: '月续航走势图表，横向拖动或键盘左右键选择月份',
      onIncrease: selected < rows.length - 1
          ? () => setState(() => selected++)
          : null,
      onDecrease: selected > 0 ? () => setState(() => selected--) : null,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
            return KeyEventResult.ignored;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
              selected > 0) {
            setState(() => selected--);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
              selected < rows.length - 1) {
            setState(() => selected++);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MileafFocusRing(
          child: LayoutBuilder(
            builder: (context, box) => GestureDetector(
              onTapDown: (p) => pick(p.localPosition.dx, box.maxWidth),
              onHorizontalDragUpdate: (p) =>
                  pick(p.localPosition.dx, box.maxWidth),
              child: SizedBox(
                // R06.3：专题主图200；大字240与U09c专题主图一致。
                height: large ? 240 : MileafSpace.detailChartHeight,
                width: double.infinity,
                child: CustomPaint(
                  key: const Key('range-observation-chart'),
                  size: Size(
                    box.maxWidth,
                    large ? 240 : MileafSpace.detailChartHeight,
                  ),
                  painter: _RangePainter(
                    rows,
                    selected.clamp(0, rows.length - 1),
                    context.colors,
                    calendar,
                    context.type.micro.copyWith(
                      color: context.colors.textFaint,
                    ),
                    MediaQuery.textScalerOf(context),
                    large,
                    scale,
                    leftPad,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.context;
    if (c.features['range_observations'] != true) {
      return const StateView(
        kind: StateViewKind.empty,
        title: '当前站点不支持长期续航观察',
        message: '站点未声明额定续航观察能力。',
      );
    }
    final d = data, totals = d?['totals'] as Map?;
    final rows = d == null
        ? <Map<String, dynamic>>[]
        : [
            for (final row in d['buckets'] as List)
              Map<String, dynamic>.from(row as Map),
          ];
    final compact = c.compact && !widget.expanded;
    final chosen = rows.isEmpty
        ? null
        : rows[selected.clamp(0, rows.length - 1)];
    final content = <Widget>[
      SectionHeader(
        title: '满电等效额定续航',
        range: compact ? null : '独立$months个月观察窗口',
        action: MileafIconButton(
          icon: MileafIconName.refresh,
          tooltip: '刷新续航观察',
          onPressed: loading ? null : () => load(force: true),
        ),
      ),
      if (loading) const MileafProgressLine(),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: MileafSpace.s8),
          child: InlineBanner(
            message: error!,
            tone: BannerTone.error,
            actionLabel: '重试续航观察',
            onAction: () => load(force: true),
          ),
        ),
      if (d != null && totals?['status'] == 'unsupported')
        const StateView(kind: StateViewKind.empty, title: '当前数据源不支持额定续航观察')
      else if (d != null && totals?['status'] == 'no_records')
        const StateView(
          kind: StateViewKind.empty,
          title: '观察窗口内无充电记录',
          message: '换一个观察窗口或继续记录充电。',
        )
      else if (d != null && totals?['status'] == 'insufficient_data')
        const StateView(
          kind: StateViewKind.empty,
          title: '尚无有效续航样本',
          message: '有效样本不足时不推算额定续航。',
        )
      else ...[
        if (!compact) ...[
          const SizedBox(height: MileafSpace.s16),
          Wrap(
            spacing: MileafSpace.s8,
            runSpacing: MileafSpace.s8,
            children: [
              for (final m in [6, 12])
                StatusChip(
                  label: '$m个月',
                  selected: months == m,
                  onTap: () {
                    if (m != months) {
                      setState(() {
                        months = m;
                        data = null;
                      });
                      load();
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: MileafSpace.s16),
          Text(
            '所选月中位数',
            style: context.type.label.copyWith(color: context.colors.textMuted),
          ),
          const SizedBox(height: MileafSpace.s4),
          MileafNumber(
            value: chosen?['median_range_km'] == null
                ? null
                : value(chosen!['median_range_km']),
            unit: 'km',
            // P10/R02：所选月中位数固定 metricLg 36；MileafNumber 在 null 时
            // 自动降到 24 号「—」，缺失口径紧跟其后。
            scale: MetricValueScale.metricLg,
          ),
          if (chosen?['median_range_km'] == null)
            Text(
              '暂无有效月样本',
              style: context.type.micro.copyWith(
                color: context.colors.textMuted,
              ),
            )
          else
            const SizedBox(height: MileafSpace.s4),
          Text(
            '满电等效额定续航 · 记录估计 · 非电池健康检测',
            style: context.type.micro.copyWith(color: context.colors.textMuted),
          ),
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: MileafNumber(
                  value: chosen?['median_range_km'] == null
                      ? null
                      : value(chosen!['median_range_km']),
                  unit: 'km',
                  scale: MetricValueScale.metricLg,
                ),
              ),
            ],
          ),
        if (!compact && rows.isNotEmpty) ...[
          const SizedBox(height: MileafSpace.s16),
          Text(
            '月中位数 · P10–P90有效日波动带（km）',
            style: context.type.label.copyWith(color: context.colors.textMuted),
          ),
          const SizedBox(height: MileafSpace.s8),
          Builder(
            builder: (chartContext) {
              final large = MileafLayout.largeText(context);
              final axisStyle = context.type.micro.copyWith(
                color: context.colors.textFaint,
              );
              final scale = _RangeScale(rows, large);
              final leftPad = scale.leftPadFor(
                axisStyle,
                MediaQuery.textScalerOf(context),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _legend(chartContext),
                  // R06.2：长期续航折线非零起点时可见标注轴范围，
                  // 波动幅度相对该范围读取，不暗示电池健康。
                  if (scale.low > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: MileafSpace.s4),
                      child: Text(
                        '纵轴 ${scale.low.toStringAsFixed(0)}–${scale.high.toStringAsFixed(0)} km，非零起点',
                        style: context.type.micro.copyWith(
                          color: context.colors.textMuted,
                        ),
                      ),
                    ),
                  const SizedBox(height: MileafSpace.s8),
                  _trendChart(
                    chartContext,
                    rows,
                    calendar: c.workspace.calendar!,
                    large: large,
                    scale: scale,
                    leftPad: leftPad,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: MileafSpace.s8),
          Builder(
            builder: (_) {
              final row = rows[selected.clamp(0, rows.length - 1)];
              final coverage = row['coverage'] as Map?;
              final date = c.workspace.calendar!.local(
                DateTime.parse(row['bucket_start'] as String),
              );
              final sample = switch (row['sample_status']) {
                'sparse' => '样本稀疏，仅供点读',
                'adequate' => '有效样本',
                _ => '无有效样本',
              };
              return Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '${date.year}/${date.month} · ${row['partial'] == true ? '未结束月' : '完整月'}',
                      style: context.type.body.copyWith(
                        color: context.colors.text,
                      ),
                    ),
                    const SizedBox(height: MileafSpace.s4),
                    Text(
                      '中位 ${value(row['median_range_km'])} km',
                      style: context.type.body.copyWith(
                        color: context.colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: MileafSpace.s4),
                    Text(
                      'P10 ${value(row['p10_range_km'])} / P90 ${value(row['p90_range_km'])} km',
                      style: context.type.body.copyWith(
                        color: context.colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: MileafSpace.s4),
                    Text(
                      '有效日 ${coverage?['valid_days'] ?? 0} · $sample',
                      style: context.type.micro.copyWith(
                        color: context.colors.textMuted,
                      ),
                    ),
                    // R01：读值到下钻动作8。
                    const SizedBox(height: MileafSpace.s8),
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: selected > 0
                              ? () => setState(() => selected--)
                              : null,
                          child: const Text('前一个月'),
                        ),
                        TextButton(
                          onPressed: selected + 1 < rows.length
                              ? () => setState(() => selected++)
                              : null,
                          child: const Text('后一个月'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: MileafSpace.section),
          StatisticsTopicFacts(
            facts: [
              StatisticsTopicFact(
                label: '有效日',
                value: '${(chosen?['coverage'] as Map?)?['valid_days'] ?? '—'}',
                unit: '天',
              ),
              StatisticsTopicFact(
                label: '有效会话',
                value:
                    '${(chosen?['coverage'] as Map?)?['valid_sessions'] ?? '—'}',
                unit: '次',
              ),
              StatisticsTopicFact(
                label: '有效采样',
                value:
                    '${(chosen?['coverage'] as Map?)?['valid_points'] ?? '—'}',
                unit: '点',
              ),
              StatisticsTopicFact(
                label: 'P10',
                value: value(chosen?['p10_range_km']),
                unit: 'km',
              ),
              StatisticsTopicFact(
                label: 'P90',
                value: value(chosen?['p90_range_km']),
                unit: 'km',
              ),
            ],
          ),
        ],
        const SizedBox(height: MileafSpace.section),
        if (!compact)
          StatisticsTopicNotes(
            children: [
              Text(
                '$months个本地月 · ${d?['query']['from']} 至 ${d?['query']['to']}',
              ),
              Text('查询生成时间：${d?['as_of']}（非采样时间）'),
              Text('窗口内首次有效采样：${d?['first_observed_at'] ?? '—'}（仅查询窗口，不是新车基线）'),
              const Text(
                '固定使用额定续航和仪表电量，同点电量20–90%；先求单次充电中位数，再求每日中位数和月分位数。筛选阈值为首版产品规则，非显著性或健康检测标准。此窗口独立于首页期间；不代表 SOH、容量或衰减。',
              ),
              for (final row in rows)
                Text(
                  '${widget.context.workspace.calendar!.local(DateTime.parse(row['bucket_start'] as String)).year}/${widget.context.workspace.calendar!.local(DateTime.parse(row['bucket_start'] as String)).month} · 有效日 ${(row['coverage'] as Map?)?['valid_days'] ?? 0} · 有效会话 ${(row['coverage'] as Map?)?['valid_sessions'] ?? 0} · 有效采样 ${(row['coverage'] as Map?)?['valid_points'] ?? 0}',
                  style: context.type.micro.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
            ],
          ),
      ],
    ];
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: content,
    );
    if (compact) return body;
    // R01：专题主体沿共享内容限宽560，与其他专题页一致；compact分支保留。
    return MileafContent(
      child: SingleChildScrollView(
        padding: MileafLayout.pagePadding(context, top: MileafSpace.s8),
        child: body,
      ),
    );
  }
}

/// 长期续航趋势的共享刻度尺：量程与刻度文本由数据决定，绘制与命中映射
/// 使用同一实例，避免轴留白与选月偏移分叉（对齐能耗条件点图的_BinScale）。
class _RangeScale {
  _RangeScale(List<Map<String, dynamic>> rows, bool largeText) {
    final values = [
      for (final r in rows)
        for (final k in const [
          'p10_range_km',
          'median_range_km',
          'p90_range_km',
        ])
          if (r[k] is num) (r[k] as num).toDouble(),
    ];
    if (values.isNotEmpty) {
      low = (values.reduce(math.min) / 10).floor() * 10.0 - 10;
      high = (values.reduce(math.max) / 10).ceil() * 10.0 + 10;
    }
    span = (high - low).abs() < .001 ? 1.0 : high - low;
    // R06.4：大字减少刻度；无样本时不伪造刻度。
    tickCount = largeText ? 2 : 3;
    tickTexts = [
      if (values.isNotEmpty)
        for (var i = 0; i < tickCount; i++)
          (low + span * i / (tickCount - 1)).toStringAsFixed(0),
    ];
  }

  double low = 0, high = 10, span = 10;
  late int tickCount;
  late List<String> tickTexts;

  /// R06.4：左侧留白按最长刻度宽 + 8，应用完整 TextScaler。
  double leftPadFor(TextStyle style, TextScaler scaler) {
    if (tickTexts.isEmpty) return 0;
    var widest = 0.0;
    for (final text in tickTexts) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest + MileafSpace.s8;
  }

  // R10：shouldRepaint 依赖值相等；同数据/同字号下跳过重绘。不引入新依赖。
  @override
  bool operator ==(Object other) =>
      other is _RangeScale &&
      other.low == low &&
      other.high == high &&
      other.tickCount == tickCount &&
      _listEquals(other.tickTexts, tickTexts);

  @override
  int get hashCode => Object.hash(low, high, tickCount, tickTexts.length);
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class _RangePainter extends CustomPainter {
  _RangePainter(
    this.rows,
    this.selected,
    this.colors,
    this.calendar,
    this.axisStyle,
    this.textScaler,
    this.largeText,
    this.scale,
    this.leftPad,
  );
  final List<Map<String, dynamic>> rows;
  final int selected;
  final MileafColors colors;
  final CalendarContext calendar;
  final TextStyle axisStyle;
  final TextScaler textScaler;
  final bool largeText;

  /// 与命中映射共享的刻度尺，保证点按位置与绘制槽位同源。
  final _RangeScale scale;
  final double leftPad;

  TextPainter _measure(String text) => TextPainter(
    text: TextSpan(text: text, style: axisStyle),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final low = scale.low, span = scale.span;
    final tickPainters = [for (final text in scale.tickTexts) _measure(text)];
    // R06.4：大字减少X标签到首末；端点留白给选中标记。
    final xLabels = largeText
        ? {0, rows.length - 1}
        : {0, ((rows.length - 1) / 2).round(), rows.length - 1};
    final xPainters = <int, TextPainter>{
      for (final i in xLabels)
        i: _measure(
          '${calendar.local(DateTime.parse(rows[i]['bucket_start'] as String)).month}月',
        ),
    };
    var tickHeight = 0.0, xHeight = 0.0;
    for (final p in tickPainters) {
      if (p.height > tickHeight) tickHeight = p.height;
    }
    for (final p in xPainters.values) {
      if (p.height > xHeight) xHeight = p.height;
    }
    // R06.4：底部按实际行高 + 8；顶部留白给选中标记（halo 8 + 余量4）。
    final plotBottom = size.height - xHeight - MileafSpace.s8;
    final plotTop = MileafChartMetrics.currentHalo + MileafSpace.s4;
    final plotHeight = (plotBottom - plotTop).clamp(1.0, size.height);
    if (rows.isEmpty || size.width <= leftPad) return;
    final plotWidth = size.width - leftPad;
    double x(int i) => leftPad + (i + .5) * plotWidth / rows.length;
    double y(num n) => plotBottom - (n.toDouble() - low) / span * plotHeight;
    // R06.5：基线加至多3条轻细网格线，只有数据/选中线需要高对比。
    canvas.drawLine(
      Offset(leftPad, plotBottom),
      Offset(size.width, plotBottom),
      Paint()..color = colors.line,
    );
    for (var i = 1; i < tickPainters.length; i++) {
      final value = low + span * i / (scale.tickCount - 1);
      final gridY = y(value);
      if (gridY >= plotTop) {
        canvas.drawLine(
          Offset(leftPad, gridY),
          Offset(size.width, gridY),
          Paint()..color = colors.line,
        );
      }
    }
    for (var i = 0; i < tickPainters.length; i++) {
      final value = low + span * i / (scale.tickCount - 1);
      final p = tickPainters[i];
      p.paint(
        canvas,
        Offset(leftPad - MileafSpace.s4 - p.width, y(value) - p.height / 2),
      );
    }
    var lastRight = double.negativeInfinity;
    for (final entry in xPainters.entries) {
      final p = entry.value;
      final center = x(entry.key);
      final left = (center - p.width / 2).clamp(leftPad, size.width - p.width);
      // R06.3：轴标签以可读为先，与前一个重叠时跳过。
      if (left < lastRight + MileafSpace.s4) continue;
      p.paint(canvas, Offset(left, plotBottom + MileafSpace.s8));
      lastRight = left + p.width;
    }
    bool known(int i) =>
        rows[i]['status'] == 'available' && rows[i]['median_range_km'] is num;
    bool adequate(int i) =>
        known(i) &&
        rows[i]['sample_status'] == 'adequate' &&
        rows[i]['p10_range_km'] is num &&
        rows[i]['p90_range_km'] is num;
    for (var i = 1; i < rows.length; i++) {
      if (adequate(i - 1) && adequate(i)) {
        final a = rows[i - 1], r = rows[i];
        final band = Path()
          ..moveTo(x(i - 1), y(a['p10_range_km'] as num))
          ..lineTo(x(i), y(r['p10_range_km'] as num))
          ..lineTo(x(i), y(r['p90_range_km'] as num))
          ..lineTo(x(i - 1), y(a['p90_range_km'] as num))
          ..close();
        canvas.drawPath(
          band,
          Paint()
            ..color = colors.accent.withValues(
              alpha: MileafChartMetrics.areaMaxOpacity,
            ),
        );
      }
      if (known(i - 1) && known(i)) {
        canvas.drawLine(
          Offset(x(i - 1), y(rows[i - 1]['median_range_km'] as num)),
          Offset(x(i), y(rows[i]['median_range_km'] as num)),
          Paint()
            ..color = colors.accent
            ..strokeWidth = MileafChartMetrics.lineStroke
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    for (var i = 0; i < rows.length; i++) {
      if (!known(i)) continue;
      final point = Offset(x(i), y(rows[i]['median_range_km'] as num));
      if (i == selected) {
        canvas.drawCircle(
          point,
          MileafChartMetrics.currentHalo,
          Paint()..color = colors.accent.withValues(alpha: .2),
        );
      }
      canvas.drawCircle(
        point,
        i == selected
            ? MileafChartMetrics.currentPoint
            : MileafChartMetrics.pointRadius,
        Paint()
          ..color = colors.accent
          ..style = adequate(i) ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = MileafChartMetrics.lineStroke,
      );
    }
    for (final p in [...tickPainters, ...xPainters.values]) {
      p.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant _RangePainter old) =>
      old.selected != selected ||
      old.rows != rows ||
      old.largeText != largeText ||
      old.textScaler != textScaler ||
      old.axisStyle != axisStyle ||
      old.scale != scale ||
      old.leftPad != leftPad;
}
