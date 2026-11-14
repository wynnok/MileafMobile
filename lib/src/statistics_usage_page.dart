import 'dart:math' as math;

import 'package:flutter/material.dart';


import 'design/components/components.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'statistics_insights_page.dart';
import 'statistics_period.dart';

String usageValue(Object? value) => value is num
    ? value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)
    : '—';
Map<String, dynamic> usageMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Map<String, dynamic>> usageItems(Object? value) =>
    value is List ? value.map(usageMap).toList() : [];

/// The evidence filter is supplied by the aggregate, never reconstructed from a page.
void openDrivingEvidence(
  BuildContext context,
  StatisticsInsightsContext source,
  Map<String, dynamic> filter, {
  String title = '行程证据',
  ValueChanged<int>? onRecord,
}) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => DrivingEvidencePage(
        source: source,
        filter: filter,
        title: title,
        onRecord: onRecord,
      ),
    ),
  );
}

/// One evidence fact on a statistics topic: label, number and unit.
class StatisticsTopicFact {
  const StatisticsTopicFact({
    required this.label,
    this.value,
    this.unit,
    this.note,
  });
  final String label;
  final String? value;
  final String? unit;
  final String? note;
}

/// 3–5 evidence facts as hairline blocks: two columns at 100%, one column at
/// large text. No cards and no equal-weight collage tiles.
class StatisticsTopicFacts extends StatelessWidget {
  const StatisticsTopicFacts({
    super.key,
    required this.facts,
    this.title = '证据',
  });

  final List<StatisticsTopicFact> facts;
  final String title;

  @override
  Widget build(BuildContext context) {
    if (facts.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final large = MileafLayout.largeText(context);
    Widget cell(
      StatisticsTopicFact fact, {
      required bool right,
      required bool bottom,
      bool second = false,
    }) => Container(
      padding: EdgeInsets.only(
        top: MileafSpace.s12,
        bottom: MileafSpace.s12,
        right: right ? MileafSpace.s12 : 0,
        left: second && !large ? MileafSpace.s12 : 0,
      ),
      decoration: BoxDecoration(
        border: Border(
          right: right ? BorderSide(color: colors.line) : BorderSide.none,
          bottom: bottom ? BorderSide(color: colors.line) : BorderSide.none,
        ),
      ),
      child: MetricBlock(
        label: fact.label,
        value: fact.value,
        unit: fact.unit,
        note: fact.note,
        semanticLabel:
            '${fact.label} ${fact.value ?? '—'} ${fact.unit ?? ''}${fact.note == null ? '' : '，${fact.note}'}',
        scale: MetricValueScale.metricMd,
      ),
    );
    final blocks = <Widget>[];
    if (large) {
      for (var i = 0; i < facts.length; i++) {
        blocks.add(cell(facts[i], right: false, bottom: i < facts.length - 1));
      }
    } else {
      for (var i = 0; i < facts.length; i += 2) {
        final end = i + 1 >= facts.length;
        blocks.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: cell(
                  facts[i],
                  right: !end,
                  bottom: i + 2 < facts.length,
                ),
              ),
              if (!end)
                Expanded(
                  child: cell(
                    facts[i + 1],
                    right: false,
                    bottom: i + 2 < facts.length,
                    second: true,
                  ),
                ),
            ],
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title),
        const SizedBox(height: MileafSpace.s4),
        ...blocks,
      ],
    );
  }
}

/// Folded technical notes; the visible page keeps the short data sentence.
class StatisticsTopicNotes extends StatelessWidget {
  const StatisticsTopicNotes({
    super.key,
    required this.children,
    this.title = '数据说明',
  });

  final List<Widget> children;
  final String title;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: Text(title),
    childrenPadding: const EdgeInsets.only(bottom: MileafSpace.s8),
    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
  );
}

class StatisticsUsagePage extends StatefulWidget {
  const StatisticsUsagePage({super.key, required this.source, this.onRecord});
  final StatisticsInsightsContext source;
  final ValueChanged<int>? onRecord;
  @override
  State<StatisticsUsagePage> createState() => _StatisticsUsagePageState();
}

class _StatisticsUsagePageState extends State<StatisticsUsagePage> {
  Map<String, dynamic>? data, calendar;
  String? error, calendarError;
  int sequence = 0;
  bool loading = false;
  String? loadedScope;
  DateTime? selectedDay;
  String get scope =>
      '${identityHashCode(source.workspace.session.current)}:${source.workspace.selectedId}:${source.workspace.calendar?.identifier}:${source.window.from}:${source.window.to}';
  StatisticsInsightsContext get source => widget.source;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant StatisticsUsagePage old) {
    super.didUpdateWidget(old);
    if (loadedScope != scope) {
      data = null;
      calendar = null;
      selectedDay = null;
      load();
    }
  }

  @override
  void dispose() {
    sequence++;
    super.dispose();
  }

  Future<void> load({bool force = false}) async {
    if (source.features['driving_analysis'] != true) return;
    final ws = source.workspace,
        owner = source.workspace.session.current,
        id = source.workspace.selectedId,
        zone = source.workspace.calendar!;
    if (owner == null || id == null) return;
    loadedScope = scope;
    final attempt = ++sequence, window = source.window;
    final query = {
      'from': window.from.toIso8601String(),
      'to': window.to.toIso8601String(),
      'tz': zone.identifier,
      'view': 'usage',
    };
    bool valid() =>
        mounted &&
        attempt == sequence &&
        ws.session.isCurrent(owner) &&
        ws.selectedId == id &&
        ws.calendar?.identifier == zone.identifier;
    setState(() {
      error = null;
      calendarError = null;
      loading = true;
    });
    try {
      final response = await ws.cache.get(
        owner,
        'vehicles/$id/driving-analysis',
        query: query,
        force: force,
      );
      if (valid()) setState(() => data = response.body);
    } catch (_) {
      if (valid()) {
        setState(
          () => error =
              '用车节奏读取失败${data != null ? '，保留上次结果（${data!['as_of'] ?? '校验时间未知'}）' : ''}',
        );
      }
    }
    try {
      final response = await ws.cache.get(
        owner,
        'vehicles/$id/stats',
        query: {...window.query('driving', zone), 'bucket': 'day'},
        force: force,
      );
      if (valid()) setState(() => calendar = response.body);
    } catch (_) {
      if (valid()) {
        setState(
          () => calendarError =
              '日历暂不可用${calendar != null ? '，保留上次每日结果（${calendar!['as_of'] ?? '校验时间未知'}）' : ''}',
        );
      }
    }
    if (valid()) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (source.features['driving_analysis'] != true) {
      return const StateView(
        kind: StateViewKind.empty,
        title: '当前站点不支持用车节奏分析',
        message: '站点未声明用车节奏分析能力。',
      );
    }
    final d = data;
    final children = <Widget>[
      if (loading && (data != null || calendar != null)) ...[
        const MileafProgressLine(),
        const Text('用车节奏更新中'),
      ],
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: MileafSpace.s12),
          child: _retryNotice(
            error!,
            tone: BannerTone.error,
            actionLabel: '重试用车节奏',
          ),
        ),
      if (d == null && calendarError != null && error == null)
        InlineBanner(message: calendarError!, tone: BannerTone.warning),
      if (d?['status'] == 'no_records')
        _empty('区间内无已完成行程', '这段时间没有已完成的行程；换一个期间或继续记录。')
      else if (d?['status'] == 'unsupported')
        _empty('当前站点不支持用车节奏分析', '站点未声明用车节奏分析能力。')
      else if (d != null) ...[
        _conclusion(d),
        _calendarSection(),
        const SizedBox(height: MileafSpace.section),
        _factsSection(d),
        const SizedBox(height: MileafSpace.section),
        _distanceSection(d),
        const SizedBox(height: MileafSpace.section),
        _weekdaySection(d),
        const SizedBox(height: MileafSpace.section),
        _notesSection(d),
      ] else if (calendar != null)
        _calendarSection()
      else if (error == null)
        const StateView(kind: StateViewKind.loading, title: '正在加载用车节奏'),
    ];
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    return source.compact
        ? column
        : MileafContent(
            child: SingleChildScrollView(
              padding: MileafLayout.pagePadding(context, top: MileafSpace.s8),
              child: column,
            ),
          );
  }

  Widget _empty(String title, String message) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      StateView(kind: StateViewKind.empty, title: title, message: message),
    ],
  );

  Widget _retryNotice(
    String message, {
    required BannerTone tone,
    required String actionLabel,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InlineBanner(message: message, tone: tone),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: loading ? null : () => load(force: true),
          child: Text(actionLabel),
        ),
      ),
    ],
  );

  Widget _conclusion(Map<String, dynamic> d) {
    final colors = context.colors;
    final type = context.type;
    final active = usageValue(d['active_days']);
    final partial = d['partial_today'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('这段时间的用车节奏', style: type.label.copyWith(color: colors.textMuted)),
        const SizedBox(height: MileafSpace.s8),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '活跃 ',
                style: type.title.copyWith(color: colors.textMuted),
              ),
              TextSpan(
                text: active,
                style:
                    (d['active_days'] == null ? type.metricMd : type.metricLg)
                        .copyWith(color: colors.text),
              ),
              TextSpan(
                text: ' 天',
                style: type.body.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: MileafSpace.s4),
        Text(
          '${usageValue(d['driving_distance_km'])} km 记录里程',
          style: type.body.copyWith(color: colors.textMuted),
        ),
        Text(
          '每活跃日 ${usageValue(d['distance_per_active_day_km'])} km',
          style: type.label.copyWith(color: colors.textMuted),
        ),
        if (d['active_days'] == null) Text('暂无活跃天数', style: type.micro),
        if (partial)
          Text('今天尚未结束', style: type.micro.copyWith(color: colors.textMuted)),
        const SizedBox(height: MileafSpace.s24),
      ],
    );
  }

  Widget _calendarSection() {
    final colors = context.colors;
    final type = context.type;
    final zone = source.workspace.calendar!;
    final byDate = {
      for (final bucket in usageItems(calendar?['buckets']))
        statisticsDate(
          zone.local(DateTime.parse(bucket['bucket_start'] as String)),
        ): bucket,
    };
    final first = zone.local(source.window.from);
    final last = zone.local(
      source.window.to.subtract(const Duration(microseconds: 1)),
    );
    // Civil dates are advanced before midnight conversion, including DST days.
    final buckets = <Map<String, dynamic>>[
      if (calendar != null)
        for (
          var date = DateTime.utc(first.year, first.month, first.day);
          !date.isAfter(DateTime.utc(last.year, last.month, last.day));
          date = date.add(const Duration(days: 1))
        )
          byDate[statisticsDate(date)] ??
              {'bucket_start': zone.midnight(date).toIso8601String()},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (calendarError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: MileafSpace.s8),
            child: _retryNotice(
              calendarError!,
              tone: BannerTone.warning,
              actionLabel: '重试日历',
            ),
          ),
        if (buckets.isEmpty)
          Text(
            calendarError != null && calendar == null
                ? '每日里程读取失败'
                : calendar == null
                ? '正在读取每日里程'
                : '还没有每日里程',
            style: type.body.copyWith(color: colors.textMuted),
          )
        else ...[
          const SectionHeader(title: '每日用车', range: 'km'),
          const SizedBox(height: MileafSpace.s8),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = MileafSpace.s4;
              final large = MileafLayout.largeText(context);
              final seven =
                  !large &&
                  MediaQuery.sizeOf(context).width >= MileafBreakpoints.wide &&
                  constraints.maxWidth >= 7 * MileafSpace.touch + 6 * gap;
              final columns = large
                  ? 1
                  : seven
                  ? 7
                  : 4;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    large
                        ? '每日记录'
                        : seven
                        ? '日期与每日里程'
                        : '日期矩阵',
                    style: type.micro.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: MileafSpace.s8),
                  Wrap(
                    key: const ValueKey('usage-daily-plot'),
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final bucket in buckets)
                        _dayCell(bucket, width: width, large: large),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: MileafSpace.s8),
          Wrap(
            spacing: MileafSpace.s12,
            runSpacing: MileafSpace.s8,
            children: [
              for (final (value, label) in <(num?, String)>[
                (0, '0 km'),
                (1, '大于0且小于50 km'),
                (50, '50至小于100 km'),
                (100, '≥100 km'),
                (null, '— 未知'),
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _UsagePattern(value: value, color: colors.controlBorder),
                    const SizedBox(width: MileafSpace.s4),
                    Flexible(
                      child: Text(
                        label,
                        style: type.micro.copyWith(color: colors.textMuted),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: MileafSpace.s8),
          Text(
            '点按日期查看当天行程；缺日为未知，未来日期不补零。',
            style: type.micro.copyWith(color: colors.textMuted),
          ),
        ],
      ],
    );
  }

  Widget _dayCell(
    Map<String, dynamic> b, {
    required double width,
    required bool large,
  }) {
    final colors = context.colors;
    final type = context.type;
    final local = source.workspace.calendar!.local(
      DateTime.parse(b['bucket_start'] as String),
    );
    final km = b['distance_km'] as num?;
    final at = DateTime.parse(b['bucket_start'] as String);
    final selected = selectedDay == at;
    final label =
        '${local.month}月${local.day}日 ${km == null ? '未知里程' : '${usageValue(km)}公里'}';
    return Semantics(
      button: true,
      selected: selected,
      label: '$label，查看当天行程',
      excludeSemantics: true,
      onTap: () => _selectDay(at, local),
      child: SizedBox(
        width: width,
        child: TextButton(
          onPressed: () => _selectDay(at, local),
          style: ButtonStyle(
            animationDuration: Duration.zero,
            minimumSize: const WidgetStatePropertyAll(
              Size(MileafSpace.touch, MileafSpace.touch),
            ),
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(
                vertical: MileafSpace.s4,
                horizontal: large ? MileafSpace.s8 : 0,
              ),
            ),
            backgroundColor: WidgetStatePropertyAll(
              selected ? colors.accentSoft : colors.surface,
            ),
            shape: const WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: MileafRadius.mdAll),
            ),
            side: WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.focused)
                    ? colors.accentStrong
                    : selected
                    ? colors.accentStrong
                    : colors.controlBorder,
                width: states.contains(WidgetState.focused) || selected ? 2 : 1,
              ),
            ),
            overlayColor: WidgetStatePropertyAll(colors.pressOverlay),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                large
                    ? '${local.year}年${local.month}月${local.day}日'
                    : '${local.month}/${local.day}',
                style: type.micro.copyWith(color: colors.text),
              ),
              Text(
                '${usageValue(km)}${large ? ' km' : ''}',
                style: type.label.copyWith(color: colors.text),
              ),
              const SizedBox(height: MileafSpace.s4),
              _UsagePattern(value: km, color: colors.controlBorder),
            ],
          ),
        ),
      ),
    );
  }

  void _selectDay(DateTime at, DateTime local) {
    setState(() => selectedDay = at);
    _openDay(local);
  }

  void _openDay(DateTime local) {
    final date = DateTime.utc(local.year, local.month, local.day);
    openDrivingEvidence(
      context,
      source,
      {
        'from': source.workspace.calendar!.midnight(date).toIso8601String(),
        'to':
            source.workspace.calendar!
                .midnight(date, nextDays: 1)
                .isAfter(source.window.to)
            ? source.window.to.toIso8601String()
            : source.workspace.calendar!
                  .midnight(date, nextDays: 1)
                  .toIso8601String(),
        'tz': source.workspace.calendar!.identifier,
        'completed_only': true,
      },
      title: '${local.month}月${local.day}日行程',
      onRecord: widget.onRecord,
    );
  }

  Widget _factsSection(Map<String, dynamic> d) => StatisticsTopicFacts(
    facts: [
      StatisticsTopicFact(
        label: '驾驶记录时长',
        value: usageValue(d['driving_duration_min']),
        unit: '分钟',
        note: _coverageNote(usageMap(d['coverage'])['duration']),
      ),
      StatisticsTopicFact(
        label: '每活跃日',
        value: usageValue(d['distance_per_active_day_km']),
        unit: 'km',
        note: _coverageNote(usageMap(d['coverage'])['distance']),
      ),
      StatisticsTopicFact(
        label: '单程中位数',
        value: usageValue(d['distance_p50_km']),
        unit: 'km',
        note: _coverageNote(usageMap(d['coverage'])['distance']),
      ),
      StatisticsTopicFact(
        label: '较长单程 P90',
        value: usageValue(d['distance_p90_km']),
        unit: 'km',
        note: _coverageNote(usageMap(d['coverage'])['distance']),
      ),
      StatisticsTopicFact(
        label: '平均记录速度',
        value: usageValue(d['mean_speed_kmh']),
        unit: 'km/h',
        note: _coverageNote(usageMap(d['coverage'])['speed']),
      ),
    ],
  );

  String _coverageNote(Object? value) {
    final coverage = usageMap(value);
    return '有效 ${usageValue(coverage['valid_count'])} 趟，排除 ${usageValue(coverage['excluded_count'])} 趟';
  }

  Widget _distanceSection(Map<String, dynamic> d) {
    final bins = usageItems(d['distance_bins']);
    if (bins.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: '短途、中途与长途', range: 'km'),
        const SizedBox(height: MileafSpace.s4),
        for (final b in bins)
          MileafDataRow(
            title:
                '${usageValue(b['lower_km'])}–${b['upper_km'] == null ? '以上' : usageValue(b['upper_km'])} km',
            meta:
                '${usageValue(b['drives'])} 趟，${usageValue(b['distance_km'])} km\n'
                '配对估算\n${_coverageNote(usageMap(b['coverage'])['paired'])}',
            value: usageValue(b['consumption_wh_km']),
            unit: 'Wh/km',
            topLine: true,
            showChevron: b['evidence_filter'] is Map,
            onTap: b['evidence_filter'] is Map
                ? () => openDrivingEvidence(
                    context,
                    source,
                    usageMap(b['evidence_filter']),
                    onRecord: widget.onRecord,
                  )
                : null,
          ),
      ],
    );
  }

  Widget _weekdaySection(Map<String, dynamic> d) {
    final bins = usageItems(d['weekday_bins']);
    if (bins.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final type = context.type;
    final max = bins.fold<double>(
      1,
      (m, b) => (b['distance_km'] as num? ?? 0) > m
          ? (b['distance_km'] as num).toDouble()
          : m,
    );
    final names = ['一', '二', '三', '四', '五', '六', '日'];
    final scaler = MediaQuery.textScalerOf(context);
    final barArea = MileafSpace.rhythmHeight;
    final available =
        math.min(
          MediaQuery.sizeOf(context).width,
          MileafBreakpoints.maxContent,
        ) -
        2 * MileafLayout.pageInset(context);
    final tooWide = bins.any((b) {
      final painter = TextPainter(
        text: TextSpan(text: usageValue(b['distance_km']), style: type.micro),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final tooWide = painter.width + MileafSpace.s8 > available / bins.length;
      painter.dispose();
      return tooWide;
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: '一周的用车节奏', range: 'km'),
        const SizedBox(height: MileafSpace.s4),
        Text('按星期累计里程', style: type.micro.copyWith(color: colors.textMuted)),
        const SizedBox(height: MileafSpace.s8),
        if (MileafLayout.largeText(context) || tooWide)
          for (final b in bins)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MileafSpace.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '周${names[((b['weekday'] as int) - 1).clamp(0, 6)]}  ${usageValue(b['distance_km'])} km',
                    style: type.body,
                  ),
                  const SizedBox(height: MileafSpace.s8),
                  LayoutBuilder(
                    builder: (context, constraints) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: b['distance_km'] == 0
                            ? MileafChartMetrics.barMaxWidth
                            : b['distance_km'] == null
                            ? 0
                            : (b['distance_km'] as num).clamp(0, max) /
                                  max *
                                  constraints.maxWidth,
                        height: b['distance_km'] == 0
                            ? 1
                            : MileafChartMetrics.barMaxWidth,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            )
        else ...[
          SizedBox(
            height:
                barArea + scaler.scale(MileafType.microHeight) + MileafSpace.s4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final b in bins)
                  Expanded(
                    child: Semantics(
                      label:
                          '周${names[((b['weekday'] as int) - 1).clamp(0, 6).toInt()]} '
                          '${usageValue(b['distance_km'])} 公里',
                      excludeSemantics: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            usageValue(b['distance_km']),
                            style: type.micro.copyWith(color: colors.textMuted),
                          ),
                          const SizedBox(height: MileafSpace.s4),
                          Container(
                            width: MileafChartMetrics.barMaxWidth,
                            height: b['distance_km'] == 0
                                ? 1
                                : (b['distance_km'] as num? ?? 0).clamp(
                                        0,
                                        max,
                                      ) /
                                      max *
                                      barArea,
                            decoration: BoxDecoration(
                              color: colors.accent,
                              borderRadius: BorderRadius.circular(
                                MileafChartMetrics.barRadius,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(height: 1, color: colors.line),
          const SizedBox(height: MileafSpace.s4),
          Row(
            children: [
              for (final b in bins)
                Expanded(
                  child: Text(
                    '周${names[((b['weekday'] as int) - 1).clamp(0, 6).toInt()]}',
                    textAlign: TextAlign.center,
                    style: type.micro.copyWith(color: colors.textFaint),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: MileafSpace.s8),
        Text(
          '按开始日分组。星期分布仅供观察，不自动判断通勤。',
          style: type.micro.copyWith(color: colors.textMuted),
        ),
        for (final b in bins)
          if (usageMap(usageMap(b['coverage'])['distance'])['excluded_count'] !=
              0)
            Text(
              '周${names[((b['weekday'] as int) - 1).clamp(0, 6)]} ${_coverageNote(usageMap(b['coverage'])['distance'])}',
              style: type.micro,
            ),
      ],
    );
  }

  Widget _notesSection(Map<String, dynamic> d) => StatisticsTopicNotes(
    children: [
      const SectionHeader(title: '口径'),
      const Text('按开始日归期；日桶来自服务端日聚合，不从单次行程重算。'),
      const SizedBox(height: MileafSpace.s12),
      const SectionHeader(title: '覆盖'),
      Text(
        '候选 ${usageValue(usageMap(d['coverage'])['candidate_count'])} 趟；各指标有效集独立，中位数与P90直接使用完整查询结果。',
      ),
      for (final entry in usageMap(d['coverage']).entries)
        if (entry.value is Map)
          Text(
            '${entry.key}：有效 ${usageValue(usageMap(entry.value)['valid_count'])} / 排除 ${usageValue(usageMap(entry.value)['excluded_count'])}',
          ),
      const SizedBox(height: MileafSpace.s12),
      const SectionHeader(title: '来源'),
      Text('用车分布 ${d['method'] ?? '—'}，版本 ${usageValue(d['version'])}'),
      const SizedBox(height: MileafSpace.s12),
      const SectionHeader(title: '时间'),
      Text(
        '统计截至 ${d['as_of'] ?? '—'}；站点时区 ${source.workspace.calendar!.identifier}',
      ),
    ],
  );
}

/// Redundant non-colour encoding shared by dates and their exact legend.
class _UsagePattern extends StatelessWidget {
  const _UsagePattern({required this.value, required this.color});
  final num? value;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: const Size(MileafSpace.s24, MileafSpace.s12),
      painter: _UsagePatternPainter(value, color),
    ),
  );
}

class _UsagePatternPainter extends CustomPainter {
  const _UsagePatternPainter(this.value, this.color);
  final num? value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final bounds = (Offset.zero & size).deflate(.5);
    canvas.drawRect(bounds, paint);
    canvas.save();
    canvas.clipRect(bounds);
    if (value == null) {
      canvas.drawLine(bounds.topLeft, bounds.bottomRight, paint);
      canvas.drawLine(bounds.bottomLeft, bounds.topRight, paint);
    } else if (value! > 0 && value! < 50) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
    } else if (value! >= 50) {
      for (var x = -size.height; x < size.width; x += MileafSpace.inline6) {
        canvas.drawLine(
          Offset(x, size.height),
          Offset(x + size.height, 0),
          paint,
        );
        if (value! >= 100) {
          canvas.drawLine(
            Offset(x, 0),
            Offset(x + size.height, size.height),
            paint,
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_UsagePatternPainter oldDelegate) =>
      value != oldDelegate.value || color != oldDelegate.color;
}

class DrivingEvidencePage extends StatefulWidget {
  const DrivingEvidencePage({
    super.key,
    required this.source,
    required this.filter,
    required this.title,
    this.onRecord,
  });
  final StatisticsInsightsContext source;
  final Map<String, dynamic> filter;
  final String title;
  final ValueChanged<int>? onRecord;
  @override
  State<DrivingEvidencePage> createState() => _DrivingEvidencePageState();
}

class _DrivingEvidencePageState extends State<DrivingEvidencePage> {
  List<Map<String, dynamic>> items = [];
  String? cursor, error;
  num? matched;
  bool loading = false, invalid = false;
  late final Object? ownerSnapshot;
  late final int? vehicleSnapshot;
  late final String? zoneSnapshot;
  void changed() {
    final ws = widget.source.workspace;
    if (!identical(ownerSnapshot, ws.session.current) ||
        vehicleSnapshot != ws.selectedId ||
        zoneSnapshot != ws.calendar?.identifier) {
      if (mounted) {
        setState(() {
          invalid = true;
          sequence++;
          items = [];
          loading = false;
        });
      }
    }
  }

  int sequence = 0;
  late final Map<String, String> query = {
    for (final e in widget.filter.entries)
      if (e.value != null) e.key: e.value.toString(),
  };
  @override
  void initState() {
    super.initState();
    ownerSnapshot = widget.source.workspace.session.current;
    vehicleSnapshot = widget.source.workspace.selectedId;
    zoneSnapshot = widget.source.workspace.calendar?.identifier;
    widget.source.workspace.addListener(changed);
    load();
  }

  @override
  void dispose() {
    sequence++;
    widget.source.workspace.removeListener(changed);
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    final ws = widget.source.workspace,
        owner = widget.source.workspace.session.current,
        id = widget.source.workspace.selectedId;
    if (invalid || owner == null || id == null || loading) return;
    final attempt = ++sequence;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await ws.cache.get(
        owner,
        'vehicles/$id/drives',
        query: {
          ...query,
          'limit': '20',
          if (more && cursor != null) 'cursor': cursor!,
        },
      );
      if (mounted &&
          attempt == sequence &&
          ws.session.isCurrent(owner) &&
          ws.selectedId == id) {
        setState(() {
          if (!more) items = [];
          final ids = items.map((x) => x['id']).toSet();
          items.addAll(
            usageItems(r.body['items']).where((x) => !ids.contains(x['id'])),
          );
          matched = r.body['matched_drives'] as num?;
          cursor = r.body['next_cursor'] as String?;
        });
      }
    } catch (_) {
      if (mounted && attempt == sequence) {
        setState(() => error = '行程证据读取失败，已载记录保留');
      }
    } finally {
      if (mounted && attempt == sequence) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: mileafPageBar(context, title: Text(widget.title)),
    body: SafeArea(
      top: false,
      child: MileafContent(
        child: invalid
            ? const Center(child: Text('车辆或会话已改变，请返回统计'))
            : ListView(
                padding: MileafLayout.pagePadding(context, top: MileafSpace.s8),
                children: [
                  Text(
                    '完整匹配 ${usageValue(matched)} 趟',
                    style: context.type.title,
                  ),
                  Text('按开始日归期', style: context.type.micro),
                  const SizedBox(height: MileafSpace.s8),
                  Text(_rangeLabel(), style: context.type.label),
                  const SizedBox(height: MileafSpace.s12),
                  if (error != null)
                    InlineBanner(message: error!, tone: BannerTone.error),
                  if (!loading && error == null && items.isEmpty)
                    const StateView(
                      kind: StateViewKind.empty,
                      title: '没有匹配行程',
                      message: '当前筛选没有已完成的行程。可以返回调整日期或分组。',
                    ),
                  for (final d in items)
                    MileafDataRow(
                      title:
                          '${usageMap(d['start'])['display_name'] ?? '未知起点'} → ${usageMap(d['end'])['display_name'] ?? '未知终点'}',
                      titleMaxLines: MileafLayout.largeText(context) ? null : 2,
                      meta:
                          '${_recordTime(d)}\n${usageValue(d['duration_min'])} 分钟\n净电耗 ${usageValue(d['consumption_wh_km'])} Wh/km',
                      value: d['distance_km'] == null
                          ? null
                          : usageValue(d['distance_km']),
                      unit: 'km',
                      topLine: true,
                      showChevron: true,
                      onTap: widget.onRecord == null
                          ? null
                          : () => widget.onRecord!(d['id'] as int),
                    ),
                  if (loading) ...[
                    const MileafProgressLine(),
                    const Text('正在读取行程证据'),
                  ],
                  if (error != null || cursor != null)
                    TextButton(
                      onPressed: loading
                          ? null
                          : () => load(more: items.isNotEmpty),
                      child: Text(error != null ? '重试行程证据' : '加载更多行程'),
                    ),
                  StatisticsTopicNotes(
                    children: [
                      const SectionHeader(title: '口径'),
                      const Text('沿用统计筛选；完整匹配数来自服务端，不从已加载分页重算。'),
                      const SectionHeader(title: '来源'),
                      for (final entry in query.entries)
                        Text('${entry.key} ${entry.value}'),
                    ],
                  ),
                ],
              ),
      ),
    ),
  );

  String _rangeLabel() {
    final zone = widget.source.workspace.calendar!;
    final from = DateTime.tryParse(query['from'] ?? '');
    final to = DateTime.tryParse(query['to'] ?? '');
    return from == null || to == null
        ? '期间未知'
        : '${statisticsDate(zone.local(from))} 至 ${statisticsDate(zone.local(to.subtract(const Duration(microseconds: 1))))}';
  }

  String _recordTime(Map<String, dynamic> record) {
    final zone = widget.source.workspace.calendar!;
    final from = DateTime.tryParse(record['started_at'] as String? ?? '');
    final to = DateTime.tryParse(record['ended_at'] as String? ?? '');
    if (from == null) return '开始时间未知';
    final start = zone.local(from);
    String clock(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final date = statisticsDate(start);
    if (to == null) return '$date ${clock(start)}，结束时间未知';
    final end = zone.local(to);
    return '$date ${clock(start)}–${statisticsDate(end) == date ? '' : '${statisticsDate(end)} '}${clock(end)}';
  }
}
