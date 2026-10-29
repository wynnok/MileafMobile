import 'package:flutter/material.dart';

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
      return const Text('当前站点不支持用车节奏分析');
    }
    final d = data;
    if (d?['status'] == 'no_records') {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Text('区间内无已完成行程'),
      );
    }
    final children = <Widget>[
      if (error != null) Text(error!),
      if (error != null || d == null)
        TextButton(
          onPressed: () => load(force: true),
          child: const Text('重试用车节奏'),
        ),
      if (data == null && calendarError != null) Text(calendarError!),
      if (data == null && calendar != null) calendarView(),
      if (d != null && d['status'] == 'unsupported')
        const Text('当前站点不支持用车节奏分析'),
      if (d != null && d['status'] != 'unsupported') ...[
        Text(
          '活跃 ${usageValue(d['active_days'])} 天',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (d['partial_today'] == true) const Text('今天尚未结束'),
        Wrap(
          spacing: 20,
          runSpacing: 12,
          children: [
            metric('驾驶记录时长', d['driving_duration_min'], '分钟'),
            metric('每活跃日', d['distance_per_active_day_km'], 'km'),
            metric('单程中位数', d['distance_p50_km'], 'km'),
          ],
        ),
        if (calendarError != null) Text(calendarError!),
        if (calendar != null) calendarView(),
        if (!source.compact) ...[
          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              metric('较长单程 P90', d['distance_p90_km'], 'km'),
              metric('记录时长 P50', d['duration_p50_min'], '分钟'),
              metric('记录时长 P90', d['duration_p90_min'], '分钟'),
              metric('平均记录速度', d['mean_speed_kmh'], 'km/h'),
            ],
          ),
          const SizedBox(height: 18),
          Text('短途、中途与长途', style: Theme.of(context).textTheme.titleMedium),
          distanceStructure(usageItems(d['distance_bins'])),
          for (final b in usageItems(d['distance_bins']))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${usageValue(b['lower_km'])}–${b['upper_km'] == null ? '以上' : usageValue(b['upper_km'])} km',
              ),
              subtitle: Text(
                '${usageValue(b['drives'])} 趟 · ${usageValue(b['distance_km'])} km · ${usageValue(b['consumption_wh_km'])} Wh/km',
              ),
              trailing: b['evidence_filter'] is Map
                  ? const Icon(Icons.chevron_right)
                  : null,
              onTap: b['evidence_filter'] is Map
                  ? () => openDrivingEvidence(
                      context,
                      source,
                      usageMap(b['evidence_filter']),
                      onRecord: widget.onRecord,
                    )
                  : null,
            ),
          const SizedBox(height: 12),
          Text('一周的用车节奏', style: Theme.of(context).textTheme.titleMedium),
          weekdayView(usageItems(d['weekday_bins'])),
          const Text('按开始日分组 · 星期分布仅供观察，不自动判断通勤'),
          ExpansionTile(
            title: const Text('数据覆盖与口径'),
            children: [
              Text(
                '候选 ${usageValue(usageMap(d['coverage'])['candidate_count'])} 趟；各指标有效集独立，中位数与P90直接使用完整查询结果。',
              ),
              for (final entry in usageMap(d['coverage']).entries)
                if (entry.value is Map)
                  Text(
                    '${entry.key}：有效 ${usageValue(usageMap(entry.value)['valid_count'])} / 排除 ${usageValue(usageMap(entry.value)['excluded_count'])}',
                  ),
            ],
          ),
        ],
      ],
    ];
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    return source.compact
        ? column
        : SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: column,
          );
  }

  Widget metric(String label, Object? value, String unit) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Text(
        '${usageValue(value)} $unit',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ],
  );
  Widget calendarView() {
    final all = usageItems(calendar!['buckets']);
    final days = source.compact && all.length > 31
        ? all.sublist(all.length - 31)
        : all;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 14),
        Text(
          source.compact && all.length > 31 ? '最近31个日桶 · 每日里程' : '每日里程 · km',
        ),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [for (final b in days) day(b)],
        ),
        const Text('浅→深：0 / <50 / <100 / ≥100 km；未来日期不补零'),
      ],
    );
  }

  Widget day(Map<String, dynamic> b) {
    final local = source.workspace.calendar!.local(
      DateTime.parse(b['bucket_start'] as String),
    );
    final km = b['distance_km'] as num?;
    final level = km == null
        ? 0.0
        : km == 0
        ? 0.08
        : km < 50
        ? 0.25
        : km < 100
        ? 0.5
        : 0.85;
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: MediaQuery.textScalerOf(context).scale(39),
      height: MediaQuery.textScalerOf(context).scale(44),
      child: Semantics(
        label: '${local.month}月${local.day}日 ${usageValue(km)}公里',
        child: TextButton(
          style: TextButton.styleFrom(
            backgroundColor: color.withValues(alpha: level),
            padding: EdgeInsets.zero,
          ),
          onPressed: () {
            final date = DateTime.utc(local.year, local.month, local.day);
            openDrivingEvidence(
              context,
              source,
              {
                'from': source.workspace.calendar!
                    .midnight(date)
                    .toIso8601String(),
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
          },
          child: Text(
            '${local.month}/${local.day}',
            style: TextStyle(
              color: level > .5
                  ? Theme.of(context).colorScheme.onPrimary
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget distanceStructure(List<Map<String, dynamic>> bins) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('已知有效里程结构 · 短 / 中 / 长途'),
      const SizedBox(height: 6),
      SizedBox(
        height: 18,
        child: Row(
          children: [
            for (final b in bins)
              if ((b['distance_km'] as num? ?? 0) > 0)
                Expanded(
                  flex: ((b['distance_km'] as num) * 100).round().clamp(
                    1,
                    100000000,
                  ),
                  child: Tooltip(
                    message:
                        '${usageValue(b['lower_km'])}–${usageValue(b['upper_km'])}km组：${usageValue(b['distance_km'])}km',
                    child: Container(
                      color: (b['lower_km'] as num) == 0
                          ? Theme.of(context).colorScheme.primary
                          : (b['lower_km'] as num) == 10
                          ? Theme.of(context).colorScheme.tertiary
                          : Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ),
          ],
        ),
      ),
      const SizedBox(height: 8),
    ],
  );
  Widget weekdayView(List<Map<String, dynamic>> bins) {
    final max = bins.fold<double>(
      1,
      (m, b) => (b['distance_km'] as num? ?? 0) > m
          ? (b['distance_km'] as num).toDouble()
          : m,
    );
    return SizedBox(
      height: MediaQuery.textScalerOf(context).scale(160),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final b in bins)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    usageValue(b['distance_km']),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Container(
                    width: 20,
                    height:
                        ((b['distance_km'] as num? ?? 0).clamp(0, max) /
                                max *
                                100)
                            .toDouble(),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  Text(
                    '周${['一', '二', '三', '四', '五', '六', '日'][(b['weekday'] as int) - 1]}',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
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
