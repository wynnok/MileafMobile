import 'dart:math' as math;

import 'package:flutter/material.dart';

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
            scale: compact
                ? MetricValueScale.metricLg
                : MetricValueScale.display,
          ),
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
          SizedBox(
            height: MileafLayout.largeText(context) ? 220 : 200,
            child: LayoutBuilder(
              builder: (context, box) => GestureDetector(
                onTapDown: (p) {
                  final i = (p.localPosition.dx / box.maxWidth * rows.length)
                      .floor()
                      .clamp(0, rows.length - 1);
                  setState(() => selected = i);
                },
                onHorizontalDragUpdate: (p) {
                  final i = (p.localPosition.dx / box.maxWidth * rows.length)
                      .floor()
                      .clamp(0, rows.length - 1);
                  setState(() => selected = i);
                },
                child: Semantics(
                  label: '月续航走势图表，横向拖动选择月份',
                  child: CustomPaint(
                    key: const Key('range-observation-chart'),
                    size: Size(box.maxWidth, 200),
                    painter: _RangePainter(
                      rows,
                      selected.clamp(0, rows.length - 1),
                      context.colors,
                      c.workspace.calendar!,
                      MileafLayout.largeText(context),
                    ),
                  ),
                ),
              ),
            ),
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
                      '中位 ${value(row['median_range_km'])} km · P10 ${value(row['p10_range_km'])} / P90 ${value(row['p90_range_km'])} km',
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
    return ListView(
      padding: MileafLayout.pagePadding(context, top: MileafSpace.s8),
      children: [body],
    );
  }
}

class _RangePainter extends CustomPainter {
  _RangePainter(
    this.rows,
    this.selected,
    this.colors,
    this.calendar,
    this.largeText,
  );
  final List<Map<String, dynamic>> rows;
  final int selected;
  final MileafColors colors;
  final CalendarContext calendar;
  final bool largeText;

  @override
  void paint(Canvas canvas, Size size) {
    final values = [
      for (final r in rows)
        for (final k in ['p10_range_km', 'median_range_km', 'p90_range_km'])
          if (r[k] is num) (r[k] as num).toDouble(),
    ];
    if (values.isEmpty) return;
    final low = (values.reduce(math.min) / 10).floor() * 10.0 - 10;
    final high = (values.reduce(math.max) / 10).ceil() * 10.0 + 10;
    final left = largeText ? 0.0 : 34.0;
    const top = 12.0;
    final width = size.width - left - 8;
    final height = size.height - 34;
    if (width <= 0 || height <= 0) return;
    double x(int i) => left + (i + .5) * width / rows.length;
    double y(num n) => top + height - (n - low) / (high - low) * height;
    // This painter never followed the text scaler: the label size steps once
    // for large text and stays fixed otherwise.
    final labelStyle = chartAxisLabelStyle(
      color: colors.textFaint,
      scaler: TextScaler.noScaling,
      fontSize: largeText ? 11 : MileafChartMetrics.axisLabelSize,
    );
    void label(String text, Offset p) {
      final t = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      t.paint(canvas, p);
      t.dispose();
    }

    if (!largeText) {
      for (var i = 0; i < 3; i++) {
        final n = low + (high - low) * i / 2;
        label(n.toStringAsFixed(0), Offset(0, y(n) - 6));
      }
    }
    bool known(int i) =>
        rows[i]['status'] == 'available' && rows[i]['median_range_km'] is num;
    bool adequate(int i) =>
        known(i) &&
        rows[i]['sample_status'] == 'adequate' &&
        rows[i]['p10_range_km'] is num &&
        rows[i]['p90_range_km'] is num;
    final xLabels = largeText
        ? {0, rows.length - 1}
        : {0, ((rows.length - 1) / 2).round(), rows.length - 1};
    for (final i in xLabels) {
      final date = calendar.local(
        DateTime.parse(rows[i]['bucket_start'] as String),
      );
      label('${date.month}月', Offset(x(i) - 10, top + height + 10));
    }
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
  }

  @override
  bool shouldRepaint(covariant _RangePainter old) => true;
}
