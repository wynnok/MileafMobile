import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design/components/components.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'statistics_insights_page.dart';

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

/// One evidence fact on an A statistics topic: label, number and unit.
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
  String? loadedScope;
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
        setState(() => error = '用车节奏读取失败${data != null ? '，保留上次结果' : ''}');
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
      if (valid()) setState(() => calendarError = '日历暂不可用');
    }
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
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: MileafSpace.s12),
          child: InlineBanner(
            message: error!,
            tone: BannerTone.error,
            actionLabel: '重试用车节奏',
            onAction: () => load(force: true),
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
      else
        const StateView(kind: StateViewKind.loading, title: '正在加载用车节奏'),
    ];
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    return source.compact
        ? column
        : SingleChildScrollView(
            padding: MileafLayout.pagePadding(context, top: MileafSpace.s8),
            child: column,
          );
  }

  Widget _empty(String title, String message) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SectionHeader(title: '这段时间的用车节奏'),
      const SizedBox(height: MileafSpace.s8),
      StateView(kind: StateViewKind.empty, title: title, message: message),
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
        const SectionHeader(title: '这段时间的用车节奏', range: '有行程的日子'),
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
                style: type.display.copyWith(color: colors.text),
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
          '${usageValue(d['driving_distance_km'])} km 记录里程 · '
          '每活跃日 ${usageValue(d['distance_per_active_day_km'])} km'
          '${partial ? ' · 今天尚未结束' : ''}',
          style: type.body.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }

  Widget _calendarSection() {
    final colors = context.colors;
    final type = context.type;
    final buckets = calendar == null
        ? const <Map<String, dynamic>>[]
        : usageItems(calendar!['buckets']);
    final positive = buckets.any((b) => (b['distance_km'] as num? ?? 0) > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (calendarError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: MileafSpace.s8),
            child: InlineBanner(
              message: calendarError!,
              tone: BannerTone.warning,
              actionLabel: '重试日历',
              onAction: () => load(force: true),
            ),
          ),
        if (buckets.isEmpty)
          Text(
            calendar == null ? '正在读取每日里程' : '还没有每日里程',
            style: type.body.copyWith(color: colors.textMuted),
          )
        else if (!positive)
          Text('还没有每日里程', style: type.body.copyWith(color: colors.textMuted))
        else ...[
          const SectionHeader(title: '每日用车', range: 'km'),
          const SizedBox(height: MileafSpace.s8),
          LayoutBuilder(
            builder: (context, constraints) {
              final scaler = MediaQuery.textScalerOf(context);
              const gap = MileafSpace.s4;
              final preferred = math.max(39.0, scaler.scale(39));
              final columns = math.max(
                1,
                math.min(
                  7,
                  ((constraints.maxWidth + gap) / (preferred + gap)).floor(),
                ),
              );
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              final height = math.max(scaler.scale(44), width);
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final bucket in buckets)
                    _dayCell(bucket, width: width, height: height),
                ],
              );
            },
          ),
          const SizedBox(height: MileafSpace.s8),
          Text(
            '浅→深：0 / <50 / <100 / ≥100 km；未来日期不补零',
            style: type.micro.copyWith(color: colors.textMuted),
          ),
        ],
      ],
    );
  }

  Widget _dayCell(
    Map<String, dynamic> b, {
    required double width,
    required double height,
  }) {
    final colors = context.colors;
    final type = context.type;
    final local = source.workspace.calendar!.local(
      DateTime.parse(b['bucket_start'] as String),
    );
    final km = b['distance_km'] as num?;
    final level = km == null
        ? 0.0
        : km == 0
        ? 0.06
        : km < 50
        ? 0.18
        : km < 100
        ? 0.38
        : 0.72;
    final high = level > .5;
    return Semantics(
      button: true,
      label: '${local.month}月${local.day}日 ${usageValue(km)}公里',
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          color: colors.accent.withValues(alpha: level),
          borderRadius: MileafRadius.xsAll,
          child: InkWell(
            borderRadius: MileafRadius.xsAll,
            onTap: () => _openDay(local),
            child: Center(
              child: Text(
                '${local.month}/${local.day}',
                style: type.micro.copyWith(
                  // The strongest cell stays a mid blue in both modes, so its
                  // 9px label is always dark ink: white would be 2.45:1 on
                  // paper and 4.11:1 on the dark surface (AV06).
                  color: high && colors.isDark
                      ? colors.textOnAccent
                      : colors.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
      ),
      StatisticsTopicFact(
        label: '每活跃日',
        value: usageValue(d['distance_per_active_day_km']),
        unit: 'km',
      ),
      StatisticsTopicFact(
        label: '单程中位数',
        value: usageValue(d['distance_p50_km']),
        unit: 'km',
      ),
      StatisticsTopicFact(
        label: '较长单程 P90',
        value: usageValue(d['distance_p90_km']),
        unit: 'km',
      ),
      StatisticsTopicFact(
        label: '平均记录速度',
        value: usageValue(d['mean_speed_kmh']),
        unit: 'km/h',
      ),
    ],
  );

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
                '${usageValue(b['drives'])} 趟 · ${usageValue(b['distance_km'])} km',
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
    final barArea = scaler.scale(72);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: '一周的用车节奏', range: 'km'),
        const SizedBox(height: MileafSpace.s4),
        Text(
          '按星期累计里程 · km',
          style: type.micro.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: MileafSpace.s8),
        SizedBox(
          height: scaler.scale(120),
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
                          width: 12,
                          height:
                              (b['distance_km'] as num? ?? 0).clamp(0, max) /
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
        const SizedBox(height: MileafSpace.s8),
        Text(
          '按开始日分组 · 星期分布仅供观察，不自动判断通勤',
          style: type.micro.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }

  Widget _notesSection(Map<String, dynamic> d) => StatisticsTopicNotes(
    children: [
      Text(
        '候选 ${usageValue(usageMap(d['coverage'])['candidate_count'])} 趟；各指标有效集独立，中位数与P90直接使用完整查询结果。',
      ),
      for (final entry in usageMap(d['coverage']).entries)
        if (entry.value is Map)
          Text(
            '${entry.key}：有效 ${usageValue(usageMap(entry.value)['valid_count'])} / 排除 ${usageValue(usageMap(entry.value)['excluded_count'])}',
          ),
      const Text('按开始日归期；日桶来自服务端日聚合，不从单次行程重算。'),
    ],
  );
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
    appBar: AppBar(title: Text(widget.title)),
    body: invalid
        ? const Center(child: Text('车辆或会话已改变，请返回统计'))
        : ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Text('完整匹配 ${usageValue(matched)} 趟 · 按开始日'),
              Text('${query['from']} — ${query['to']}'),
              if (error != null) Text(error!),
              for (final d in items)
                ListTile(
                  title: Text(
                    '${usageMap(d['start'])['display_name'] ?? '未知起点'} → ${usageMap(d['end'])['display_name'] ?? '未知终点'}',
                  ),
                  subtitle: Text(
                    '${usageValue(d['distance_km'])} km · ${usageValue(d['duration_min'])} 分钟',
                  ),
                  onTap: widget.onRecord == null
                      ? null
                      : () => widget.onRecord!(d['id'] as int),
                ),
              if (loading) const Center(child: CircularProgressIndicator()),
              if (error != null || cursor != null)
                TextButton(
                  onPressed: loading
                      ? null
                      : () => load(more: items.isNotEmpty),
                  child: Text(error != null ? '重试行程证据' : '加载更多行程'),
                ),
            ],
          ),
  );
}
