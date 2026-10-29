import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import 'currency.dart';
import 'session.dart';
import 'data_cards.dart';
import 'data_chart.dart';
import 'driving_statistics_contract.g.dart' as legacy;
import 'statistics_period.dart';
import 'workspace.dart';

/// A topic receives the same vehicle/calendar selection, never a derived total.
class StatisticsInsightsContext {
  StatisticsInsightsContext(
    this.workspace,
    this.currency,
    this.selection,
    this.features, {
    this.compact = false,
    StatisticsWindow? window,
  }) : window =
           window ??
           selection.resolve(workspace.calendar!, workspace.session.now());
  final VehicleWorkspace workspace;
  final CurrencySettings currency;
  final StatisticsSelection selection;
  final Map<String, bool> features;
  final bool compact;
  final StatisticsWindow window;
}

typedef StatisticsTopicBuilder = Widget Function(
  StatisticsInsightsContext context,
);

class StatisticsInsightsPage extends StatefulWidget {
  const StatisticsInsightsPage({
    super.key,
    required this.workspace,
    required this.currency,
    required this.legacyBuilder,
    required this.initialSelection,
    this.topics = const {},
  });
  final VehicleWorkspace workspace;
  final CurrencySettings currency;
  final Widget Function() legacyBuilder;
  final StatisticsSelection initialSelection;
  final Map<String, StatisticsTopicBuilder> topics;
  @override
  State<StatisticsInsightsPage> createState() => _StatisticsInsightsPageState();
}

class _StatisticsInsightsPageState extends State<StatisticsInsightsPage>
    with WidgetsBindingObserver {
  late StatisticsSelection selection = widget.initialSelection;
  Map<String, bool>? features;
  Map<String, dynamic>? current, reference;
  Map<String, dynamic>? charging;
  String? chargingError;
  String? error, referenceError;
  String topic = 'overview';
  int metric = 0;
  int sequence = 0, revision = 0;
  bool busy = false;
  StatisticsWindow? loadedWindow;
  VehicleWorkspace get workspace => widget.workspace;
  @override
  void initState() {
    super.initState();
    revision = workspace.revision;
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    sequence++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StatisticsInsightsPage old) {
    super.didUpdateWidget(old);
    if (revision != workspace.revision) {
      revision = workspace.revision;
      current = null;
      reference = null;
      charging = null;
      load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (features == null || features!['driving_coverage'] == true) &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      foreground();
    }
  }

  Future<void> foreground() async {
    final changed = await workspace.foreground();
    if (!mounted) return;
    final previous = loadedWindow, owner = workspace.session.current;
    if (!changed &&
        previous != null &&
        owner != null &&
        workspace.calendar!.day(previous.to) ==
            workspace.calendar!.day(workspace.session.now())) {
      final cached = workspace.cache.peek(
        owner,
        'vehicles/${workspace.selectedId}/stats',
        previous.query('driving', workspace.calendar!),
      );
      if (cached != null &&
          cached.validUntil.isAfter(workspace.session.now())) {
        return;
      }
    }
    if (changed) {
      current = null;
      reference = null;
    }
    load();
  }

  Future<void> load({bool force = false}) async {
    final owner = workspace.session.current,
        id = workspace.selectedId,
        cal = workspace.calendar;
    if (owner == null || id == null || cal == null) return;
    final request = ++sequence;
    setState(() {
      busy = true;
      error = null;
      referenceError = null;
    });
    bool valid() =>
        mounted &&
        request == sequence &&
        workspace.session.isCurrent(owner) &&
        workspace.selectedId == id &&
        workspace.calendar?.identifier == cal.identifier;
    try {
      final meta = await workspace.cache.get(owner, 'meta', force: force);
      final capability = meta.body['statistics_insights'];
      final supported =
          capability is Map &&
          capability['contract_version'] == 'statistics-insights-v1' &&
          capability['minimum_server_version'] == '0.3.0' &&
          capability['features'] is Map;
      final flags = <String, bool>{
        if (supported)
          for (final e in (capability['features'] as Map).entries)
            if (e.value is bool) e.key.toString(): e.value as bool,
      };
      if (!valid()) return;
      setState(() => features = flags);
      if (flags['driving_coverage'] != true) return;
      loadCharging(owner, id, cal, force);
      final window = selection.resolve(cal, workspace.session.now());
      final data = await workspace.cache.get(
        owner,
        'vehicles/$id/stats',
        query: window.query('driving', cal),
        force: force,
      );
      // Decode the published base contract before rendering extension fields.
      legacy.DrivingStats.fromJson(data.body);
      if (!valid()) return;
      setState(() {
        current = data.body;
        reference = null;
        loadedWindow = window;
      });
      final previous = referenceWindow(window, cal, selection.period);
      if (previous == null) {
        setState(() => referenceError = '日历进度无法对齐，仅展示本期原值');
        return;
      }
      try {
        final other = await workspace.cache.get(
          owner,
          'vehicles/$id/stats',
          query: previous.query('driving', cal),
          force: force,
        );
        legacy.DrivingStats.fromJson(other.body);
        if (valid()) setState(() => reference = other.body);
      } catch (_) {
        if (valid()) setState(() => referenceError = '参照读取失败，本期结果保留');
      }
    } catch (_) {
      if (valid()) {
        if (features == null) {
          setState(() => features = <String, bool>{});
        }
        setState(() => error = '统计读取失败，请重试${current != null ? '；保留上次快照' : ''}');
      }
    } finally {
      if (valid()) setState(() => busy = false);
    }
  }

  Future<void> loadCharging(
    SiteSession owner,
    int id,
    CalendarContext cal,
    bool force,
  ) async {
    final ticket = sequence;
    final window = selection.resolve(cal, workspace.session.now());
    try {
      final result = await workspace.cache.get(
        owner,
        'vehicles/$id/stats',
        query: window.query('charging', cal),
        force: force,
      );
      if (mounted &&
          ticket == sequence &&
          workspace.session.isCurrent(owner) &&
          workspace.selectedId == id) {
        setState(() {
          charging = result.body;
          chargingError = null;
        });
      }
    } catch (_) {
      if (mounted && ticket == sequence) {
        setState(() => chargingError = '补能统计读取失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (features != null && features!['driving_coverage'] != true) {
      return Column(
        children: [
          if (error != null)
            Row(
              children: [
                Expanded(child: Text(error!)),
                TextButton(
                  onPressed: () => load(force: true),
                  child: const Text('重试能力'),
                ),
              ],
            ),
          Expanded(child: widget.legacyBuilder()),
        ],
      );
    }
    final data = current;
    if (data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy) const CircularProgressIndicator(),
            if (error != null) Text(error!),
            TextButton(
              onPressed: () => load(force: true),
              child: const Text('重试统计'),
            ),
          ],
        ),
      );
    }
    final cal = workspace.calendar!,
        stats = legacy.DrivingStats.fromJson(data),
        totals = Map<String, dynamic>.from(data['totals'] as Map);
    final paired = totals['net_consumption_paired'] as Map?;
    final other = reference;
    final comparable = other != null && canCompare(data, other);
    final contextData = StatisticsInsightsContext(
      workspace,
      widget.currency,
      selection,
      features!,
      window: loadedWindow,
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              Row(
                children: [
                  Text('用车洞察', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    onPressed: () => load(force: true),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              StatisticsPeriodControls(
                selection: selection,
                calendar: cal,
                now: workspace.session.now(),
                onChanged: (s) {
                  setState(() {
                    selection = s;
                    current = null;
                    reference = null;
                  });
                  load();
                },
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final label in ['总览', '能耗', '补能', '长期'])
                    ChoiceChip(
                      label: Text(label),
                      selected:
                          topic ==
                          const {
                            '总览': 'overview',
                            '能耗': 'energy',
                            '补能': 'charging',
                            '长期': 'long',
                          }[label],
                      onSelected: (_) => setState(
                        () => topic = const {
                          '总览': 'overview',
                          '能耗': 'energy',
                          '补能': 'charging',
                          '长期': 'long',
                        }[label]!,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: topic == 'long'
              ? SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final key in ['range', 'parking'])
                        if (widget.topics.containsKey(key))
                          widget.topics[key]!(contextData),
                    ],
                  ),
                )
              : topic != 'overview' && widget.topics.containsKey(topic)
              ? widget.topics[topic]!(contextData)
              : topic != 'overview'
              ? widget.legacyBuilder()
              : ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    if (error != null) Text(error!),
                    if (referenceError != null) Text(referenceError!),
                    Text(
                      '这段时间的用车回顾',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    MetricTile(
                      label: '期间里程',
                      value: '${stats.totals.distanceKm} km',
                      emphasize: true,
                    ),
                    MetricTile(
                      label: '行驶净电耗（配对估算）',
                      value: '${paired?['value_wh_km'] ?? '—'} Wh/km',
                      note: '同批有效里程；非电网侧能耗',
                    ),
                    if (comparable)
                      Text(
                        '较参照净电耗变化 ${((paired!['value_wh_km'] as num) - (other['totals']['net_consumption_paired']['value_wh_km'] as num)).toStringAsFixed(1)} Wh/km',
                      )
                    else
                      const Text('参照质量或口径不满足时，仅展示原值'),
                    MetricTile(
                      label: '已知充电支出',
                      value: chargingError != null
                          ? '—'
                          : widget.currency.amount(
                              (charging?['totals'] as Map?)?['cost'] as num?,
                            ),
                      note:
                          chargingError ??
                          '费用有记录 ${(charging?['totals'] as Map?)?['cost_known_sessions'] ?? '—'}/${(charging?['totals'] as Map?)?['sessions'] ?? '—'} 次',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final (i, label) in [
                          '里程',
                          '次数',
                          '估算能量',
                          '最高速度',
                        ].indexed)
                          ChoiceChip(
                            label: Text(label),
                            selected: metric == i,
                            onSelected: (_) => setState(() => metric = i),
                          ),
                      ],
                    ),
                    TimeChart(
                      title: ['里程走势', '行程次数', '估算能量', '最高速度'][metric],
                      unit: ['km', '次', 'kWh', 'km/h'][metric],
                      times: stats.buckets.map((b) => b.bucketStart).toList(),
                      series: [
                        ChartSeries(
                          label: '本期',
                          values: stats.buckets
                              .map(
                                (b) => switch (metric) {
                                  0 => b.distanceKm,
                                  1 => b.drives,
                                  2 => b.energyKwh,
                                  _ => b.speedMaxKmh,
                                },
                              )
                              .toList(),
                        ),
                        if (comparable)
                          ChartSeries(
                            label: '参照（同进度）',
                            values: legacy.DrivingStats.fromJson(other).buckets
                                .map(
                                  (b) => switch (metric) {
                                    0 => b.distanceKm,
                                    1 => b.drives,
                                    2 => b.energyKwh,
                                    _ => b.speedMaxKmh,
                                  },
                                )
                                .toList(),
                          ),
                      ],
                      timestamp: (t) => cal.local(t).toString(),
                      height: 150,
                      presentation: comparable
                          ? ChartPresentation.groupedBars
                          : ChartPresentation.bars,
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: const Text('全部指标与口径')),
                            body: widget.legacyBuilder(),
                          ),
                        ),
                      ),
                      child: const Text('全部指标与口径'),
                    ),
                    if (widget.topics.containsKey('usage')) ...[
                      widget.topics['usage']!(
                        StatisticsInsightsContext(
                          workspace,
                          widget.currency,
                          selection,
                          features!,
                          compact: true,
                          window: loadedWindow,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => topic = 'usage'),
                        child: const Text('展开用车节奏'),
                      ),
                    ],
                    Text('${cal.identifier} · 行程按开始日归期'),
                  ],
                ),
        ),
      ],
    );
  }
}

bool canCompare(Map<String, dynamic> a, Map<String, dynamic> b) {
  final x = a['totals'] as Map, y = b['totals'] as Map;
  final p = x['net_consumption_paired'] as Map?,
      q = y['net_consumption_paired'] as Map?;
  return (x['comparison_quality'] as Map?)?['sample_status'] == 'adequate' &&
      (y['comparison_quality'] as Map?)?['sample_status'] == 'adequate' &&
      a['range_kind'] != null &&
      a['range_kind'] == b['range_kind'] &&
      p?['method'] is String &&
      p?['method'] == q?['method'] &&
      p?['version'] is int &&
      p?['version'] == q?['version'] &&
      p?['value_wh_km'] is num &&
      q?['value_wh_km'] is num;
}

StatisticsWindow? referenceWindow(
  StatisticsWindow w,
  CalendarContext cal,
  StatisticsPeriod period,
) {
  final start = cal.local(w.from), end = cal.local(w.to);
  final days =
      DateTime.utc(
        end.year,
        end.month,
        end.day,
      ).difference(DateTime.utc(start.year, start.month, start.day)).inDays +
      (end.hour + end.minute + end.second > 0 ? 1 : 0);
  DateTime? shift(DateTime d) {
    final civil = switch (period) {
      StatisticsPeriod.week => DateTime.utc(
        d.year,
        d.month,
        d.day - 7,
        d.hour,
        d.minute,
        d.second,
        d.millisecond,
        d.microsecond,
      ),
      StatisticsPeriod.month => DateTime.utc(
        d.year,
        d.month - 1,
        d.day,
        d.hour,
        d.minute,
        d.second,
        d.millisecond,
        d.microsecond,
      ),
      StatisticsPeriod.year => DateTime.utc(
        d.year - 1,
        d.month,
        d.day,
        d.hour,
        d.minute,
        d.second,
        d.millisecond,
        d.microsecond,
      ),
      StatisticsPeriod.custom => DateTime.utc(
        d.year,
        d.month,
        d.day - days,
        d.hour,
        d.minute,
        d.second,
        d.millisecond,
        d.microsecond,
      ),
    };
    if (period == StatisticsPeriod.month && civil.day != d.day ||
        period == StatisticsPeriod.year && civil.day != d.day) {
      return null;
    }
    final local = tz.TZDateTime(
      cal.location,
      civil.year,
      civil.month,
      civil.day,
      civil.hour,
      civil.minute,
      civil.second,
      civil.millisecond,
      civil.microsecond,
    );
    if (local.hour != civil.hour || local.day != civil.day) return null;
    // Reject a repeated civil time instead of picking one offset silently.
    for (final delta in [-1, 1]) {
      final adjacent = cal.local(local.toUtc().add(Duration(hours: delta)));
      if (adjacent.year == local.year &&
          adjacent.month == local.month &&
          adjacent.day == local.day &&
          adjacent.hour == local.hour &&
          adjacent.minute == local.minute) {
        return null;
      }
    }
    return local.toUtc();
  }

  final from = shift(start), to = shift(end);
  return from == null || to == null
      ? null
      : StatisticsWindow(from, to, w.bucket);
}
