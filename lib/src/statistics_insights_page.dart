import 'package:flutter/material.dart';

import 'currency.dart';
import 'session.dart';
import 'data_cards.dart';
import 'data_chart.dart';
import 'driving_statistics_contract.g.dart' as legacy;
import 'statistics_insights_contract.g.dart' as insights;

import 'package:flutter/foundation.dart';

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
    this.initialTopic = 'overview',
  });
  final VehicleWorkspace workspace;
  final CurrencySettings currency;
  final Widget Function(StatisticsSelection selection) legacyBuilder;
  final StatisticsSelection initialSelection;
  final Map<String, StatisticsTopicBuilder> topics;
  final String initialTopic;
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
  int metric = 0, point = 0;
  int sequence = 0, revision = 0;
  bool busy = false;
  StatisticsWindow? loadedWindow;
  VehicleWorkspace get workspace => widget.workspace;
  @override
  void initState() {
    super.initState();
    revision = workspace.revision;
    topic = widget.initialTopic;
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
    if (revision != workspace.revision ||
        old.initialTopic != widget.initialTopic) {
      revision = workspace.revision;
      if (old.initialTopic != widget.initialTopic) {
        topic = widget.initialTopic;
        selection = widget.initialSelection;
        loadedWindow = null;
        point = 0;
      }
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
      charging = null;
    }
    loadedWindow = null;
    load();
  }

  void selectTopic(String key) {
    setState(() => topic = key);
    if (key == 'overview' && !busy) {
      if (current == null) {
        load();
      } else if (reference == null) {
        retryReference();
      }
    }
  }

  Future<void> load({bool force = false}) async {
    final owner = workspace.session.current,
        id = workspace.selectedId,
        cal = workspace.calendar;
    if (owner == null || id == null || cal == null) return;
    if (force) loadedWindow = null;
    final window =
        loadedWindow ?? selection.resolve(cal, workspace.session.now());
    loadedWindow = window;
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
      setState(() {
        features = flags;
        loadedWindow ??= selection.resolve(cal, workspace.session.now());
      });
      if (flags['driving_coverage'] != true || topic != 'overview') return;
      loadCharging(owner, id, cal, force);
      final data = await workspace.cache.get(
        owner,
        'vehicles/$id/stats',
        query: window.query('driving', cal),
        force: force,
      );
      // Decode the published base contract before rendering extension fields.
      insights.DrivingStats.fromJson(data.body);
      if (!valid()) return;
      setState(() {
        current = data.body;
        reference = null;
        loadedWindow = window;
      });
      if (topic != 'overview') return;
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
        insights.DrivingStats.fromJson(other.body);
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
    final window =
        loadedWindow ?? selection.resolve(cal, workspace.session.now());
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

  Future<void> retryReference() async {
    final owner = workspace.session.current,
        id = workspace.selectedId,
        cal = workspace.calendar,
        window = loadedWindow;
    if (owner == null || id == null || cal == null || window == null) return;
    final request = sequence;
    final previous = referenceWindow(window, cal, selection.period);
    if (previous == null) {
      setState(() => referenceError = '日历进度无法对齐，仅展示本期原值');
      return;
    }
    try {
      final result = await workspace.cache.get(
        owner,
        'vehicles/$id/stats',
        query: previous.query('driving', cal),
        force: true,
      );
      insights.DrivingStats.fromJson(result.body);
      if (mounted &&
          request == sequence &&
          workspace.session.isCurrent(owner) &&
          workspace.selectedId == id &&
          workspace.calendar?.identifier == cal.identifier &&
          identical(window, loadedWindow)) {
        setState(() {
          reference = result.body;
          referenceError = null;
        });
      }
    } catch (_) {
      if (mounted && request == sequence) {
        setState(() => referenceError = '参照读取失败，本期结果保留');
      }
    }
  }

  StatisticsInsightsContext topicContext({bool compact = false}) =>
      StatisticsInsightsContext(
        workspace,
        widget.currency,
        selection,
        features ?? const {},
        compact: compact,
        window: loadedWindow,
      );
  Widget longTopics() => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      if (features?['range_observations'] != true &&
          features?['parking_observations'] != true)
        Text(features == null ? '正在识别长期观察能力' : '本站未提供长期观察能力，请升级服务或重试能力'),
      for (final key in ['range', 'parking'])
        if (widget.topics.containsKey(key) &&
            features?[key == 'range'
                    ? 'range_observations'
                    : 'parking_observations'] ==
                true) ...[
          widget.topics[key]!(topicContext(compact: true)),
          TextButton(
            onPressed: () => setState(() => topic = key),
            child: Text(key == 'range' ? '展开长期续航' : '展开停放观察'),
          ),
        ],
    ],
  );
  Widget insightHeader() => Padding(
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
          calendar: workspace.calendar!,
          now: workspace.session.now(),
          onChanged: (s) {
            setState(() {
              selection = s;
              current = null;
              reference = null;
              charging = null;
              loadedWindow = null;
            });
            load();
          },
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final label in ['总览', '节奏', '能耗', '补能', '长期'])
              ChoiceChip(
                label: Text(label),
                visualDensity: VisualDensity.compact,
                labelPadding: const EdgeInsets.symmetric(horizontal: 3),
                showCheckmark: false,
                selected:
                    topic ==
                    const {
                      '总览': 'overview',
                      '节奏': 'usage',
                      '能耗': 'energy',
                      '补能': 'charging',
                      '长期': 'long',
                    }[label],
                onSelected: (_) => selectTopic(
                  const {
                    '总览': 'overview',
                    '节奏': 'usage',
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
  );
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
          if (features!.values.any((v) => v))
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => setState(() => topic = 'overview'),
                  child: const Text('总览'),
                ),
                if (features!['driving_analysis'] == true)
                  TextButton(
                    onPressed: () => setState(() => topic = 'usage'),
                    child: const Text('用车节奏'),
                  ),
                if (features!['range_observations'] == true ||
                    features!['parking_observations'] == true)
                  TextButton(
                    onPressed: () => setState(() => topic = 'long'),
                    child: const Text('长期'),
                  ),
              ],
            ),
          Expanded(
            child: topic == 'long'
                ? longTopics()
                : topic != 'overview' &&
                      topic != 'charging' &&
                      widget.topics.containsKey(topic)
                ? widget.topics[topic]!(topicContext())
                : widget.legacyBuilder(selection),
          ),
        ],
      );
    }
    final data = current;
    if (data == null) {
      return Column(
        children: [
          insightHeader(),
          Expanded(
            child: topic == 'long'
                ? longTopics()
                : topic != 'overview' &&
                      features != null &&
                      widget.topics.containsKey(topic)
                ? widget.topics[topic]!(topicContext())
                : topic != 'overview'
                ? widget.legacyBuilder(selection)
                : Center(
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
                  ),
          ),
        ],
      );
    }
    final cal = workspace.calendar!,
        stats = legacy.DrivingStats.fromJson(data),
        totals = Map<String, dynamic>.from(data['totals'] as Map);
    final paired = totals['net_consumption_paired'] as Map?;
    final other = reference;
    final enhanced = insights.DrivingStats.fromJson(data);
    final comparable =
        other != null && canCompare(data, other, cal, selection.period);
    final contextData = StatisticsInsightsContext(
      workspace,
      widget.currency,
      selection,
      features!,
      window: loadedWindow,
    );
    return Column(
      children: [
        insightHeader(),
        Expanded(
          child: topic == 'long'
              ? longTopics()
              : topic != 'overview' && widget.topics.containsKey(topic)
              ? widget.topics[topic]!(contextData)
              : topic != 'overview'
              ? widget.legacyBuilder(selection)
              : ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    if (error != null) Text(error!),
                    if (referenceError != null)
                      Row(
                        children: [
                          Expanded(child: Text(referenceError!)),
                          TextButton(
                            onPressed: retryReference,
                            child: const Text('重试参照'),
                          ),
                        ],
                      ),
                    Text(
                      '这段时间的用车回顾',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    MetricTile(
                      label: '期间里程',
                      value: '${stats.totals.distanceKm} km',
                      emphasize: true,
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: MediaQuery.textScalerOf(context).scale(13) > 20
                              ? MediaQuery.sizeOf(context).width - 36
                              : (MediaQuery.sizeOf(context).width - 48) / 2,
                          child: MetricTile(
                            label: '行驶净电耗（配对估算）',
                            value: '${paired?['value_wh_km'] ?? '—'} Wh/km',
                            note:
                                '有效${enhanced.totals.netConsumptionPaired.eligibleDrives}趟 · ${enhanced.totals.comparisonQuality.distanceCoverage == null ? '里程覆盖未知' : '里程覆盖${(enhanced.totals.comparisonQuality.distanceCoverage! * 100).toStringAsFixed(0)}%'}',
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.textScalerOf(context).scale(13) > 20
                              ? MediaQuery.sizeOf(context).width - 36
                              : (MediaQuery.sizeOf(context).width - 48) / 2,
                          child: MetricTile(
                            label: '已知充电支出',
                            value: chargingError != null
                                ? '—'
                                : widget.currency.amount(
                                    (charging?['totals'] as Map?)?['cost']
                                        as num?,
                                  ),
                            note:
                                chargingError ??
                                '费用有记录 ${(charging?['totals'] as Map?)?['cost_known_sessions'] ?? '—'}/${(charging?['totals'] as Map?)?['sessions'] ?? '—'} 次',
                          ),
                        ),
                      ],
                    ),
                    if (comparable)
                      Text(
                        '里程较参照 ${_relative(stats.totals.distanceKm, legacy.DrivingStats.fromJson(other).totals.distanceKm)} · 净电耗差 ${((paired!['value_wh_km'] as num) - (other['totals']['net_consumption_paired']['value_wh_km'] as num)).toStringAsFixed(1)} Wh/km（${_relative(paired['value_wh_km'] as num, other['totals']['net_consumption_paired']['value_wh_km'] as num)}）',
                      )
                    else
                      const Text('参照质量或口径不满足时，仅展示原值'),
                    Row(
                      children: [
                        const Text('趋势指标'),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: metric,
                          items: [
                            for (final (i, label) in [
                              '里程',
                              '次数',
                              '估算能量',
                              '最高速度',
                              '配对净电耗',
                            ].indexed)
                              DropdownMenuItem(value: i, child: Text(label)),
                          ],
                          onChanged: (i) {
                            if (i != null) setState(() => metric = i);
                          },
                        ),
                      ],
                    ),
                    TimeChart(
                      title: ['里程走势', '行程次数', '估算能量', '最高速度', '配对净电耗'][metric],
                      unit: ['km', '次', 'kWh', 'km/h', 'Wh/km'][metric],
                      times: enhanced.buckets
                          .map((b) => b.bucketStart)
                          .toList(),
                      series: [
                        ChartSeries(
                          label: '本期',
                          values: enhanced.buckets
                              .map((b) => _metricValue(b, metric))
                              .toList(),
                        ),
                        if (comparable)
                          ChartSeries(
                            label: '参照（同进度）',
                            values: insights.DrivingStats.fromJson(other)
                                .buckets
                                .map((b) => _metricValue(b, metric))
                                .toList(),
                          ),
                      ],
                      timestamp: (t) => cal.local(t).toString(),
                      height: 135,
                      plotKey: const ValueKey('statistics-insights-chart'),
                      compact: true,
                      selectedIndex: point,
                      onSelected: (i) => setState(() => point = i),
                      presentation: metric == 4
                          ? ChartPresentation.line
                          : comparable
                          ? ChartPresentation.groupedBars
                          : ChartPresentation.bars,
                    ),
                    if (comparable && stats.buckets.isNotEmpty)
                      Text(
                        '本期读数 ${_metricValue(enhanced.buckets[point.clamp(0, stats.buckets.length - 1)], metric)?.toStringAsFixed(1) ?? '—'} ${['km', '次', 'kWh', 'km/h', 'Wh/km'][metric]} · 参照读数 ${_metricValue(insights.DrivingStats.fromJson(other).buckets[point.clamp(0, stats.buckets.length - 1)], metric)?.toStringAsFixed(1) ?? '—'} ${['km', '次', 'kWh', 'km/h', 'Wh/km'][metric]}',
                      ),
                    const SizedBox(height: 12),
                    DataCard(
                      child: MetricGrid(
                        children: [
                          MetricTile(
                            label: '记录驾驶时长',
                            value:
                                enhanced
                                        .totals
                                        .drivingCoverage
                                        .durationKnownMin ==
                                    null
                                ? '—（缺失）'
                                : '${enhanced.totals.drivingCoverage.durationKnownMin!.toStringAsFixed(0)} 分钟',
                            note:
                                '${enhanced.totals.drivingCoverage.durationKnownDrives}/${enhanced.totals.drivingCoverage.completedDrives}趟有记录',
                          ),
                          MetricTile(
                            label: '已完成行程',
                            value:
                                '${enhanced.totals.drivingCoverage.completedDrives} 趟',
                            note:
                                '${enhanced.totals.drivingCoverage.ongoingDrives}趟进行中，未计入结果',
                          ),
                          MetricTile(
                            label: '估算行驶能量',
                            value:
                                '${stats.totals.energyKwh?.toStringAsFixed(2) ?? '—'} kWh',
                            note:
                                '${enhanced.totals.drivingCoverage.netEnergyKnownDrives}趟能量有记录',
                          ),
                          MetricTile(
                            label: '能量有效里程',
                            value:
                                '${enhanced.totals.drivingCoverage.netEnergyKnownDistanceKm?.toStringAsFixed(1) ?? '—'} km',
                            note: '与全里程分开核对',
                          ),
                        ],
                      ),
                    ),
                    if (other != null)
                      ExpansionTile(
                        title: const Text('参照原值与质量'),
                        children: [
                          Text(
                            '参照里程 ${legacy.DrivingStats.fromJson(other).totals.distanceKm} km',
                          ),
                          Text(
                            '参照配对净电耗 ${other['totals']['net_consumption_paired']['value_wh_km'] ?? '—'} Wh/km',
                          ),
                          Text(
                            '质量 ${other['totals']['comparison_quality']['sample_status']} · ${other['range_kind']}',
                          ),
                          Text(
                            '${other['query']['from']} — ${other['query']['to']} · ${other['query']['tz']}',
                          ),
                          Text(
                            '参照生成 ${cal.local(insights.DrivingStats.fromJson(other).asOf)}；本期/参照分别生成，不保证原子快照',
                          ),
                        ],
                      ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: const Text('全部指标与口径')),
                            body: widget.legacyBuilder(selection),
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
                    Text(
                      '${cal.identifier} · 行程按开始日归期\n本期 ${cal.local(enhanced.query.from)} — ${cal.local(enhanced.query.to)}\n生成时间 ${cal.local(enhanced.asOf)}，非车辆采样时间',
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

bool canCompare(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
  CalendarContext cal,
  StatisticsPeriod period,
) {
  final x = insights.DrivingStats.fromJson(a),
      y = insights.DrivingStats.fromJson(b);
  final p = x.totals.netConsumptionPaired,
      q = y.totals.netConsumptionPaired,
      c = x.totals.comparisonQuality,
      d = y.totals.comparisonQuality;
  final expected = referenceWindow(
    StatisticsWindow(x.query.from, x.query.to, x.query.bucket),
    cal,
    period,
  );
  return expected != null &&
      expected.from.isAtSameMomentAs(y.query.from) &&
      expected.to.isAtSameMomentAs(y.query.to) &&
      x.query.vehicleId == y.query.vehicleId &&
      x.query.tz == y.query.tz &&
      x.query.bucket == y.query.bucket &&
      x.query.timeBasis == y.query.timeBasis &&
      mapEquals(x.query.filters, y.query.filters) &&
      x.buckets.length == y.buckets.length &&
      c.status == 'available' &&
      d.status == 'available' &&
      c.sampleStatus == 'adequate' &&
      d.sampleStatus == 'adequate' &&
      c.method == d.method &&
      c.version == d.version &&
      x.rangeKind != null &&
      x.rangeKind == y.rangeKind &&
      p.method == q.method &&
      p.version == q.version &&
      p.status == 'available' &&
      q.status == 'available' &&
      p.valueWhKm != null &&
      q.valueWhKm != null;
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
    // An IANA civil time must map to exactly one instant. Enumerating the
    // location's offsets also handles half-hour transitions without normalizing
    // a missing time or silently choosing one side of an ambiguous time.
    final candidates = <int>{};
    for (final zone in cal.location.zones) {
      final instant = civil.microsecondsSinceEpoch - zone.offset.inMicroseconds;
      final local = cal.local(
        DateTime.fromMicrosecondsSinceEpoch(instant, isUtc: true),
      );
      if (local.year == civil.year &&
          local.month == civil.month &&
          local.day == civil.day &&
          local.hour == civil.hour &&
          local.minute == civil.minute &&
          local.second == civil.second &&
          local.millisecond == civil.millisecond &&
          local.microsecond == civil.microsecond) {
        candidates.add(instant);
      }
    }
    return candidates.length == 1
        ? DateTime.fromMicrosecondsSinceEpoch(candidates.single, isUtc: true)
        : null;
  }

  final from = shift(start), to = shift(end);
  return from == null || to == null
      ? null
      : StatisticsWindow(from, to, w.bucket);
}

num? _metricValue(insights.DrivingBucket b, int metric) => switch (metric) {
  0 => b.distanceKm,
  1 => b.drives,
  2 => b.energyKwh,
  3 => b.speedMaxKmh,
  _ => b.netConsumptionPaired.valueWhKm,
};

String _relative(num current, num reference) => reference == 0
    ? '—（基期为0）'
    : '${((current - reference) / reference * 100).toStringAsFixed(1)}%';
