import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'currency.dart';
import 'collage.dart';
import 'number_format.dart';
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
  int point = 0;
  bool pointTouched = false;
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
    if (key == 'overview') {
      setState(() => topic = key);
      if (current == null && !busy) load();
      return;
    }
    final captured = topicContext();
    final capturedRevision = workspace.revision;
    final capturedOwner = workspace.session.current;
    final capturedZone = workspace.calendar?.identifier;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => AnimatedBuilder(
          animation: workspace,
          builder: (_, child) {
            if (workspace.revision != capturedRevision ||
                !identical(workspace.session.current, capturedOwner) ||
                workspace.calendar?.identifier != capturedZone) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (routeContext.mounted) Navigator.of(routeContext).pop();
              });
              return const SizedBox.shrink();
            }
            return child!;
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                const {
                      'usage': '节奏',
                      'energy': '能耗',
                      'charging': '补能',
                      'long': '长期',
                      'range': '长期续航',
                      'parking': '停放观察',
                    }[key] ??
                    '统计专题',
              ),
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(() {
                      if (key == 'range') return '独立6/12个本地月窗口';
                      final zone = workspace.calendar!;
                      String date(DateTime instant) {
                        final local = zone.local(instant);
                        return '${local.year}/${local.month}/${local.day}';
                      }

                      return '${date(captured.window.from)} — ${date(captured.window.to)}';
                    }()),
                    subtitle: const Text('数据说明'),
                    children: [
                      Text(
                        '${captured.window.from} — ${captured.window.to} · ${workspace.calendar!.identifier}',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: key == 'long'
                      ? longTopics()
                      : widget.topics[key]?.call(captured) ??
                            widget.legacyBuilder(selection),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget chapters() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text('四个问题', style: Theme.of(context).textTheme.labelMedium),
      ),
      LayoutBuilder(
        builder: (context, constraints) {
          final single = MediaQuery.textScalerOf(context).scale(14) >= 21;
          return Wrap(
            spacing: 8,
            runSpacing: 0,
            children: [
              for (final entry in const {
                'usage': '节奏',
                'energy': '能耗',
                'charging': '补能',
                'long': '长期',
              }.entries)
                SizedBox(
                  width: single
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 8) / 2,
                  child: CollageTile(
                    surface: entry.key == 'usage'
                        ? CollageSurface.mint
                        : CollageSurface.paper,
                    child: TextButton(
                      onPressed: () => selectTopic(entry.key),
                      child: Row(
                        children: [
                          Expanded(child: Text(entry.value)),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );

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
            onPressed: () => selectTopic(key),
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
            if (topic != 'overview')
              IconButton(
                tooltip: '返回统计',
                onPressed: () => selectTopic('overview'),
                icon: const Icon(Icons.arrow_back),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('统计', style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    _periodLabel(),
                    style: Theme.of(context).textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _AllMetricsPage(
                    timezone: workspace.calendar!.identifier,
                    onTopic: (key) {
                      Navigator.of(context).pop();
                      selectTopic(key);
                    },
                  ),
                ),
              ),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_outward, size: 16),
              label: const Text('全部指标'),
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
              point = 0;
              pointTouched = false;
            });
            load();
          },
        ),
      ],
    ),
  );
  String _periodLabel() {
    final w = loadedWindow;
    final cal = workspace.calendar;
    if (w == null || cal == null) return '';
    final d = cal.local(w.to.subtract(const Duration(microseconds: 1)));
    final base = switch (selection.period) {
      StatisticsPeriod.week => '本周',
      StatisticsPeriod.recent => '近7天',
      StatisticsPeriod.month => '本月',
      StatisticsPeriod.year => '本年',
      StatisticsPeriod.custom => '期间',
    };
    return '$base \u00b7 ${d.year}\u5e74${d.month}\u6708';
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
                        chapters(),
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
                  padding: const EdgeInsets.all(12),
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
                    _conclusionTile(stats, enhanced, paired, comparable, other),
                    _mileageChartTile(enhanced, other, comparable, cal),
                    _questionTiles(enhanced, charging),
                    _moreSection(cal, stats, enhanced, paired, other),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _deltaChip(String text) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// C prints whole Wh/km, but keeps a decimal when the API value has one.
  String _whKm(num value) =>
      grouped(value, decimals: value == value.roundToDouble() ? 0 : 1);

  String _mileageDeltaText(num current, num? reference, bool comparable) {
    if (!comparable || reference == null) return '参照口径不可比，仅展示原值';
    if (reference == 0) return '—（基期为0）';
    final delta = current - reference;
    if (delta.abs() < .05) return '与参照同期持平';
    return '${delta > 0 ? '↑' : '↓'} ${grouped(delta.abs(), decimals: 1)} km 较参照';
  }

  /// C conclusion tile: one dominant number, a delta pill and three facts.
  Widget _conclusionTile(
    legacy.DrivingStats stats,
    insights.DrivingStats enhanced,
    Map? paired,
    bool comparable,
    Map<String, dynamic>? other,
  ) {
    final net =
        (paired?['value_wh_km'] as num?) ?? (stats.totals.consumptionWhKmNet);
    final active = enhanced.buckets.where((b) => b.distanceKm > 0).length;
    final totals = charging?['totals'] as Map?;
    final cost = chargingError == null ? (totals?['cost'] as num?) : null;
    final reference = other == null
        ? null
        : legacy.DrivingStats.fromJson(other).totals.distanceKm;
    return CollageTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  selection.period == StatisticsPeriod.month
                      ? '本月 · 驾驶里程'
                      : '期间 · 驾驶里程',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              Text(
                '${stats.totals.drives} 趟',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              text: grouped(stats.totals.distanceKm, decimals: 1),
              children: const [
                TextSpan(text: ' km', style: TextStyle(fontSize: 16)),
              ],
            ),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
              fontSize: 44,
              height: 1,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 8),
          _deltaChip(
            _mileageDeltaText(stats.totals.distanceKm, reference, comparable),
          ),
          const SizedBox(height: 9),
          Text(
            '净电耗 ${net == null ? '—' : '${_whKm(net)} Wh/km'} · 已知支出 ${widget.currency.amount(cost)} · $active 个活跃日',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  /// C main figure: dark tile, distance bars with the same-progress reference.
  Widget _mileageChartTile(
    insights.DrivingStats enhanced,
    Map<String, dynamic>? other,
    bool comparable,
    CalendarContext cal,
  ) {
    final times = enhanced.buckets.map((b) => b.bucketStart).toList();
    final values = enhanced.buckets
        .map<num?>((b) => b.distanceKm.toDouble())
        .toList();
    final referenceBuckets = other == null
        ? const <num?>[]
        : insights.DrivingStats.fromJson(other).buckets
              .map<num?>((b) => b.distanceKm.toDouble())
              .toList();
    String tick(DateTime time) {
      final local = cal.local(time);
      return '${local.month}/${local.day}';
    }

    var selected = point;
    for (var i = times.length - 1; i >= 0; i--) {
      if (i < values.length && (values[i] ?? 0) > 0) {
        selected = i;
        break;
      }
    }
    if (pointTouched) selected = point.clamp(0, times.length - 1);
    return CollageTile(
      surface: CollageSurface.hero,
      child: TimeChart(
        card: false,
        compact: true,
        height: 132,
        title: '里程走势',
        unit: 'km',
        subtitle: '本期 vs 参照 · 同进度',
        times: times,
        series: [
          ChartSeries(label: '本期', values: values),
          if (comparable) ChartSeries(label: '参照', values: referenceBuckets),
        ],
        presentation: comparable
            ? ChartPresentation.barsWithLine
            : ChartPresentation.bars,
        showLegend: false,
        showSteppers: false,
        tickLabel: tick,
        timestamp: (t) => cal.local(t).toString(),
        readout: (index) {
          final value = index < values.length ? values[index] : null;
          final reference = comparable && index < referenceBuckets.length
              ? referenceBuckets[index]
              : null;
          return '${index < times.length ? tick(times[index]) : '—'} '
              '${value == null ? '—' : grouped(value, decimals: 1)} km'
              '${reference == null ? '' : ' / 参照 ${grouped(reference, decimals: 1)}'}';
        },
        trailing: Text('点按图形读值', style: Theme.of(context).textTheme.labelSmall),
        plotKey: const ValueKey('statistics-insights-chart'),
        selectedIndex: selected,
        onSelected: (index) => setState(() {
          point = index;
          pointTouched = true;
        }),
      ),
    );
  }

  Widget _chapterTile(
    String title,
    IconData icon,
    CollageSurface surface, {
    required String value,
    String? unit,
    required String note,
    Widget? mini,
    required VoidCallback onTap,
  }) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: CollageTile(
      surface: surface,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Icon(icon, size: 16),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              text: value,
              children: [
                if (unit != null)
                  TextSpan(
                    text: ' $unit',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Text(note, style: Theme.of(context).textTheme.labelSmall),
          if (mini != null) ...[const SizedBox(height: 6), mini],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text('读下去 →', style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    ),
  );

  Widget? _energySplit(Map<dynamic, dynamic>? totals) {
    final ac = totals?['ac_energy_kwh'] as num?;
    final dc = totals?['dc_energy_kwh'] as num?;
    final unknown = totals?['unknown_energy_kwh'] as num?;
    if (ac == null && dc == null) return null;
    final scheme = Theme.of(context).colorScheme;
    final parts = [
      (ac ?? 0, scheme.primary),
      (dc ?? 0, scheme.tertiary),
      (unknown ?? 0, scheme.outline),
    ];
    final total = parts.fold<double>(0, (sum, part) => sum + part.$1);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            for (final part in parts)
              if (part.$1 > 0)
                Expanded(
                  flex: math.max(
                    1,
                    (part.$1 / (total == 0 ? 1 : total) * 100).round(),
                  ),
                  child: ColoredBox(color: part.$2),
                ),
          ],
        ),
      ),
    );
  }

  /// C 四个问题: each tile previews the loaded metric and opens its topic.
  Widget _questionTiles(
    insights.DrivingStats enhanced,
    Map<String, dynamic>? charging,
  ) {
    final active = enhanced.buckets.where((b) => b.distanceKm > 0).length;
    final minutes = enhanced.totals.drivingCoverage.durationKnownMin;
    final duration = minutes == null
        ? '—'
        : '${minutes ~/ 60}h${(minutes % 60).toString().padLeft(2, '0')}';
    final net = enhanced.totals.netConsumptionPaired.valueWhKm;
    final prior = reference == null
        ? null
        : insights.DrivingStats.fromJson(reference!)
              .totals
              .netConsumptionPaired
              .valueWhKm;
    final comparable =
        current != null &&
        reference != null &&
        canCompare(current!, reference!, workspace.calendar!, selection.period);
    final totals = charging?['totals'] as Map?;
    final cost = chargingError == null ? (totals?['cost'] as num?) : null;
    final energy = totals?['energy_added_kwh'] as num?;
    final items = [
      (
        '节奏',
        Icons.calendar_month_outlined,
        CollageSurface.mint,
        '$active',
        '天',
        minutes == null ? '驾驶时长缺失' : '驾驶 $duration · 单程中位见专题',
        Sparkline(
          height: 24,
          values: [for (final b in enhanced.buckets) b.distanceKm.toDouble()],
        ),
        () => selectTopic('usage'),
      ),
      (
        '能耗',
        Icons.thermostat_outlined,
        CollageSurface.sand,
        net == null ? '—' : _whKm(net),
        'Wh/km',
        _netDeltaNote(net, prior, comparable),
        Sparkline(
          height: 24,
          values: [
            for (final b in enhanced.buckets)
              if (b.consumptionWhKmNet != null)
                b.consumptionWhKmNet!.toDouble(),
          ],
        ),
        () => selectTopic('energy'),
      ),
      (
        '补能',
        Icons.bolt_outlined,
        CollageSurface.paper,
        widget.currency.amount(cost),
        null,
        energy == null
            ? '补能统计读取失败'
            : '${totals?['cost_known_sessions'] ?? '—'} / ${totals?['sessions'] ?? '—'} 次有费用 · ${grouped(energy, decimals: 1)} kWh',
        _energySplit(totals),
        () => selectTopic('charging'),
      ),
      (
        '长期',
        Icons.battery_std_outlined,
        CollageSurface.hero,
        '—',
        'km',
        '6 个月额定续航 P50 · 在专题内读取',
        null,
        () => selectTopic('long'),
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 6),
          child: Text('四个问题', style: Theme.of(context).textTheme.labelMedium),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final single = MediaQuery.textScalerOf(context).scale(14) >= 21;
            return Wrap(
              spacing: 8,
              children: [
                for (final item in items)
                  SizedBox(
                    width: single
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 8) / 2,
                    child: _chapterTile(
                      item.$1,
                      item.$2,
                      item.$3,
                      value: item.$4,
                      unit: item.$5,
                      note: item.$6,
                      mini: item.$7,
                      onTap: item.$8,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _netDeltaNote(num? value, num? prior, bool comparable) {
    if (!comparable || value == null || prior == null) return '样本不足或口径不一致';
    if (prior == 0) return '参照为0，不计算变化';
    final delta = value - prior;
    if (delta.abs() < .5) return '与参照基本持平';
    return '较参照${delta < 0 ? '低' : '高'} ${grouped(delta.abs())} Wh/km';
  }

  /// C keeps APIs, coverage and reference provenance behind 数据说明.
  Widget _moreSection(
    CalendarContext cal,
    legacy.DrivingStats stats,
    insights.DrivingStats enhanced,
    Map? paired,
    Map<String, dynamic>? other,
  ) => CollageTile(
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: const Text('数据说明与更多'),
      children: [
        MetricGrid(
          children: [
            MetricTile(
              label: '行驶净电耗（配对估算）',
              value: '${paired?['value_wh_km'] ?? '—'} Wh/km',
              note:
                  '有效${enhanced.totals.netConsumptionPaired.eligibleDrives}趟 · ${enhanced.totals.comparisonQuality.distanceCoverage == null ? '里程覆盖未知' : '里程覆盖${(enhanced.totals.comparisonQuality.distanceCoverage! * 100).toStringAsFixed(0)}%'}',
            ),
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
            MetricTile(
              label: '记录驾驶时长',
              value: enhanced.totals.drivingCoverage.durationKnownMin == null
                  ? '—（缺失）'
                  : '${enhanced.totals.drivingCoverage.durationKnownMin!.toStringAsFixed(0)} 分钟',
              note:
                  '${enhanced.totals.drivingCoverage.durationKnownDrives}/${enhanced.totals.drivingCoverage.completedDrives}趟有记录',
            ),
            MetricTile(
              label: '已完成行程',
              value: '${enhanced.totals.drivingCoverage.completedDrives} 趟',
              note:
                  '${enhanced.totals.drivingCoverage.ongoingDrives}趟进行中，未计入结果',
            ),
            MetricTile(
              label: '估算行驶能量',
              value: '${stats.totals.energyKwh?.toStringAsFixed(2) ?? '—'} kWh',
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
        if (other != null)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
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
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('数据说明'),
          children: [
            Text(
              '${cal.identifier} · 行程按开始日归期\n本期 ${cal.local(enhanced.query.from)} — ${cal.local(enhanced.query.to)}\n生成时间 ${cal.local(enhanced.asOf)}，非车辆采样时间',
            ),
          ],
        ),
      ],
    ),
  );
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
      StatisticsPeriod.week || StatisticsPeriod.recent => DateTime.utc(
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

/// C03: every metric entry is a topic, not a second equal-weight tab bar.
class _AllMetricsPage extends StatelessWidget {
  const _AllMetricsPage({required this.timezone, required this.onTopic});
  final String timezone;
  final ValueChanged<String> onTopic;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('全部指标与口径')),
    body: ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final entry in const {
          'usage': ('节奏', '驾驶时间、单程与星期分布'),
          'energy': ('能耗', '温度与距离条件'),
          'charging': ('补能', '费用、均价与 AC/DC'),
          'long': ('长期', '额定续航与停放观察'),
        }.entries)
          ListTile(
            title: Text(entry.value.$1),
            subtitle: Text(entry.value.$2),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onTopic(entry.key),
          ),
        ExpansionTile(
          title: const Text('数据说明'),
          children: [
            Text('沿用当前车辆与期间；归期时区 $timezone。'),
            const Text('各专题只回答一个问题，指标口径与统计首页一致。'),
          ],
        ),
      ],
    ),
  );
}
