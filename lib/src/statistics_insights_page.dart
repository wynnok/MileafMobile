import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import 'currency.dart';
import 'number_format.dart';

import 'copy/dates.dart' as copy;
import 'copy/durations.dart' as copy;
import 'copy/terms.dart' as terms;
import 'design/components/components.dart';
import 'design/icons.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'session.dart';
import 'driving_statistics_contract.g.dart' as legacy;
import 'statistics_insights_contract.g.dart' as insights;

import 'package:flutter/foundation.dart';

import 'statistics_period.dart';
import 'workspace.dart';
import 'reading_scope.dart';

/// A topic receives the same vehicle/calendar selection, never a derived total.
class StatisticsInsightsContext {
  StatisticsInsightsContext(
    this.workspace,
    this.currency,
    this.selection,
    this.features, {
    this.compact = false,
    StatisticsWindow? window,
    this.revalidate,
  }) : window =
           window ??
           selection.resolve(workspace.calendar!, workspace.session.now());
  final VehicleWorkspace workspace;
  final CurrencySettings currency;
  final StatisticsSelection selection;
  final Map<String, bool> features;
  final bool compact;
  final StatisticsWindow window;
  final Future<void> Function()? revalidate;
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
    this.topBar,
  });
  final Widget? topBar;
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
    with
        WidgetsBindingObserver,
        ReadingLifecycle<StatisticsInsightsPage>,
        CostAwareReading<StatisticsInsightsPage> {
  late StatisticsSelection selection = widget.initialSelection;
  Map<String, bool>? features;
  Map<String, dynamic>? current, reference;
  Map<String, dynamic>? charging;
  String? chargingError;
  String? error, referenceError;
  String topic = 'overview';
  DateTime? pointAt;
  int point = 0;
  bool pointTouched = false;
  int sequence = 0, revision = 0;
  bool busy = false;
  bool foregrounding = false;
  StatisticsWindow? loadedWindow;
  @override
  VehicleWorkspace get workspace => widget.workspace;
  @override
  void initState() {
    super.initState();
    revision = workspace.revision;
    initCostReading();
    workspace.addCostReader(refreshCost);
    topic = widget.initialTopic;
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    workspace.removeCostReader(refreshCost);
    sequence++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<bool> refreshCost() async {
    // A covered or hidden page keeps its snapshot and consumes the revision
    // once visible; a deferred refresh is never reported as updated.
    if (!readingVisible) {
      deferCost();
      return false;
    }
    final owner = workspace.session.current,
        vehicle = workspace.selectedId,
        cal = workspace.calendar;
    if (topic != 'overview' ||
        owner == null ||
        vehicle == null ||
        cal == null) {
      consumeCost();
      return true;
    }
    await loadCharging(owner, vehicle, cal, true);
    final refreshed = chargingError == null;
    if (refreshed) consumeCost();
    return refreshed;
  }

  @override
  void didUpdateWidget(covariant StatisticsInsightsPage old) {
    super.didUpdateWidget(old);
    // A foreground pass drives its own reload; the notification it causes must
    // not add a second read through this path. A page hidden or covered by a
    // route records the new revision and reads it on its next visible frame.
    if (!readingWasVisible || foregrounding) return;
    if (revision != workspace.revision ||
        old.initialTopic != widget.initialTopic) {
      revision = workspace.revision;
      if (old.initialTopic != widget.initialTopic) {
        topic = widget.initialTopic;
        selection = widget.initialSelection;
        point = 0;
        pointAt = null;
      }
      loadedWindow = null;
      current = null;
      reference = null;
      charging = null;
      load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (readingVisible &&
        state == AppLifecycleState.resumed &&
        (features == null || features!['driving_coverage'] == true)) {
      foreground();
    }
  }

  @override
  Future<void> resumeReading() async {
    if (features == null || features!['driving_coverage'] == true) {
      await foreground();
    }
  }

  Future<void>? foregroundRead;
  Future<void> foreground() => foregroundRead ??= runForeground().whenComplete(
    () => foregroundRead = null,
  );

  Future<void> runForeground() async {
    foregrounding = true;
    try {
      await _foreground();
    } finally {
      foregrounding = false;
    }
  }

  Future<void> _foreground() async {
    final changed = await workspace.foreground();
    if (!mounted || !readingPresent) return;
    final staleCalendar = changed || revision != workspace.revision;
    revision = workspace.revision;
    final costChanged = costPending;
    if (staleCalendar) {
      loadedWindow = null;
      current = null;
      reference = null;
      charging = null;
    }
    if (costChanged) {
      if (topic != 'overview') {
        // This view shows no fee aggregate; consume the revision without a read.
        consumeCost();
        return;
      }
      await load(force: true);
      if (mounted && error == null && chargingError == null) consumeCost();
      return;
    }
    final previous = loadedWindow, owner = workspace.session.current;
    if (!staleCalendar &&
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
    loadedWindow = null;
    await load();
  }

  void selectTopic(String key) {
    if (key == 'overview') {
      setState(() => topic = key);
      if (current == null && !busy) load();
      return;
    }
    final captured = StatisticsInsightsContext(
      workspace,
      widget.currency,
      selection,
      features ?? const {},
      window: loadedWindow,
    );
    final capturedRevision = workspace.revision;
    final capturedOwner = workspace.session.current;
    final capturedZone = workspace.calendar?.identifier;
    // U08 owns the long index and legacy route. Topic layouts migrate in U09.
    final body = Column(
      children: [
        MileafContent(
          child: Padding(
            padding: MileafLayout.pageHorizontal(context),
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
        ),
        Expanded(
          child: key == 'long'
              ? longTopics()
              : widget.topics[key]?.call(captured) ??
                    widget.legacyBuilder(selection),
        ),
      ],
    );
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
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  MileafContent(
                    child: MileafNavigationRow(
                      title: Text(
                        const {
                              'usage': '节奏',
                              'energy': '能耗',
                              'charging': '补能',
                              'long': '长期',
                              'range': '长期续航',
                              'parking': '停放观察',
                              'legacy': '原始统计指标',
                            }[key] ??
                            '统计专题',
                      ),
                      onBack: () => Navigator.of(routeContext).pop(),
                    ),
                  ),
                  Expanded(
                    child: key == 'long' || key == 'legacy'
                        ? MileafContent(child: body)
                        : body,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
        setState(() => chargingError = '充电统计读取失败');
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
        revalidate: foreground,
      );
  Widget longTopics() => ListView(
    padding: MileafLayout.pagePadding(context),
    children: [
      for (final entry in const {
        'range': ('展开长期续航', '独立6/12个本地月窗口', 'range_observations'),
        'parking': ('展开停放观察', '所选期间的停放变化', 'parking_observations'),
      }.entries) ...[
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(entry.value.$1, style: context.type.body),
          subtitle: Text(
            features?[entry.value.$3] == true ? entry.value.$2 : '当前站点暂不支持此专题',
            style: context.type.label,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => selectTopic(entry.key),
        ),
        const Divider(height: 1),
      ],
    ],
  );
  Widget _allMetricsAction() => TextButton(
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
    child: const Text('全部指标'),
  );

  Widget insightHeader() {
    final actions = <Widget>[_allMetricsAction()];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (topic != 'overview')
          MileafNavigationRow(
            title: Text(
              const {
                    'usage': '用车节奏',
                    'energy': '能耗',
                    'charging': '补能',
                    'long': '长期观察',
                    'range': '长期续航',
                    'parking': '停放观察',
                    'legacy': '原始统计指标',
                  }[topic] ??
                  '统计专题',
            ),
            onBack: () => selectTopic('overview'),
            actions: actions,
          ),
        Padding(
          padding: MileafLayout.pageHorizontal(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (topic != 'overview')
                Text(
                  _periodLabel(),
                  style: context.type.subheadline.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              SizedBox(
                height: topic == 'overview' ? MileafSpace.s8 : MileafSpace.s8,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: StatisticsPeriodControls(
                      selection: selection,
                      calendar: workspace.calendar!,
                      now: workspace.session.now(),
                      editor: readingEditor,
                      onChanged: (s) {
                        setState(() {
                          selection = s;
                          current = null;
                          reference = null;
                          charging = null;
                          loadedWindow = null;
                          point = 0;
                          pointAt = null;
                          pointTouched = false;
                        });
                        load();
                      },
                    ),
                  ),
                  // R27/PD10：四个根页的期间行尾部各有且只有一个刷新圆钮。
                  Padding(
                    padding: const EdgeInsets.only(left: MileafSpace.s8),
                    child: MileafIconButton(
                      icon: MileafIconName.refresh,
                      tooltip: '刷新统计',
                      fill: MileafIconButtonFill.track,
                      onPressed: busy ? null : () => load(force: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

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
  Widget build(BuildContext context) => Column(
    children: [
      if (topic == 'overview' && widget.topBar != null) widget.topBar!,
      Expanded(
        child: SafeArea(
          top: topic != 'overview',
          bottom: false,
          child: MileafContent(child: buildContent(context)),
        ),
      ),
    ],
  );

  Widget buildContent(BuildContext context) {
    if (features != null && features!['driving_coverage'] != true) {
      return Column(
        children: [
          if (topic == 'overview' && widget.topBar == null)
            SizedBox(height: MileafLayout.rootTopClearance(context)),
          if (topic != 'overview') insightHeader(),
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
                    onPressed: () => selectTopic('usage'),
                    child: const Text('用车节奏'),
                  ),
                if (features!['driving_analysis'] == true)
                  TextButton(
                    onPressed: () => selectTopic('energy'),
                    child: const Text('能耗'),
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
      final content = topic == 'long'
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
                  if (busy) ...[
                    const MileafProgressLine(),
                    const Text('正在读取统计'),
                  ],
                  if (error != null) Text(error!),
                  TextButton(
                    onPressed: () => load(force: true),
                    child: const Text('重试统计'),
                  ),
                  if (error != null)
                    Wrap(
                      spacing: MileafSpace.s8,
                      runSpacing: MileafSpace.s4,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final entry in const {
                          'usage': '节奏',
                          'energy': '能耗',
                          'charging': '补能',
                          'long': '长期',
                        }.entries)
                          TextButton(
                            onPressed: () => selectTopic(entry.key),
                            child: Text(entry.value),
                          ),
                      ],
                    ),
                ],
              ),
            );
      if (topic == 'overview') {
        return ListView(
          scrollCacheExtent: const ScrollCacheExtent.pixels(10000),
          children: [
            if (widget.topBar == null)
              SizedBox(height: MileafLayout.rootTopClearance(context)),
            insightHeader(),
            content,
          ],
        );
      }
      return Column(
        children: [
          insightHeader(),
          Expanded(child: content),
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
      revalidate: foreground,
    );
    return Column(
      children: [
        if (topic != 'overview') insightHeader(),
        Expanded(
          child: topic == 'long'
              ? longTopics()
              : topic != 'overview' && widget.topics.containsKey(topic)
              ? widget.topics[topic]!(contextData)
              : topic != 'overview'
              ? widget.legacyBuilder(selection)
              : ListView(
                  scrollCacheExtent: const ScrollCacheExtent.pixels(10000),
                  padding: EdgeInsets.zero,
                  children: [
                    if (widget.topBar == null)
                      SizedBox(height: MileafLayout.rootTopClearance(context)),
                    insightHeader(),
                    Padding(
                      // §6 退让阶梯第 1 步：去掉与期间行重复的 8 间距。
                      padding: EdgeInsets.fromLTRB(
                        MileafLayout.pageInset(context),
                        MileafSpace.s4,
                        MileafLayout.pageInset(context),
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (error != null)
                            InlineBanner(
                              message: error!,
                              tone: BannerTone.error,
                              actionLabel: '重试',
                              onAction: () => load(force: true),
                            ),
                          if (referenceError != null)
                            InlineBanner(
                              message: referenceError!,
                              tone: BannerTone.warning,
                              actionLabel: '重试',
                              onAction: retryReference,
                            ),
                          MileafModuleCard(
                            padding: const EdgeInsets.all(MileafSpace.s12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _conclusionTile(
                                  stats,
                                  enhanced,
                                  paired,
                                  comparable,
                                  other,
                                ),
                                const SizedBox(height: MileafSpace.s16),
                                _mileageChartTile(
                                  enhanced,
                                  other,
                                  comparable,
                                  cal,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _questionTiles(enhanced, charging),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        MileafLayout.pageInset(context),
                        MileafSpace.section,
                        MileafLayout.pageInset(context),
                        MileafLayout.rootNavigationClearance(context),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: _allMetricsAction(),
                          ),
                          _moreSection(cal, stats, enhanced, paired, other),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  /// C prints whole Wh/km, but keeps a decimal when the API value has one.
  String _whKm(num value) =>
      grouped(value, decimals: value == value.roundToDouble() ? 0 : 1);

  /// CP03：比较结果写成句子（多/少/持平），不用箭头；CP02：比较对象用真实名称。
  String _mileageDeltaText(num current, num? reference, bool comparable) {
    final name = _compareName;
    if (!comparable || reference == null) return '统计方式不同，暂不比较';
    if (reference == 0) return '$name为 0，无法比较';
    final delta = current - reference;
    final range = _referenceRange();
    if (delta.abs() < .05) return '与$name持平';
    return delta > 0
        ? '比 $range 多 ${grouped(delta.abs(), decimals: 1)} km'
        : '比 $range 少 ${grouped(delta.abs(), decimals: 1)} km';
  }

  String get _compareName =>
      terms.compareNameFor(selection.period.name) ?? _referenceRange();

  /// DF3 本期区间（本地日历）。
  String _currentRange() {
    final window = loadedWindow;
    final cal = workspace.calendar;
    if (window == null || cal == null) return '';
    return copy.formatRange(
      cal.local(window.from),
      cal.local(window.to.subtract(const Duration(microseconds: 1))),
    );
  }

  String get _periodName => switch (selection.period) {
    StatisticsPeriod.week => '本周',
    StatisticsPeriod.recent => '近 7 天',
    StatisticsPeriod.month => '本月',
    StatisticsPeriod.year => '本年',
    StatisticsPeriod.custom => '自定义区间',
  };

  String _referenceRange() {
    final query = reference?['query'] as Map?;
    if (query == null) return '参照同期';
    final cal = workspace.calendar!;
    final from = cal.local(DateTime.parse(query['from'] as String));
    final to = cal.local(
      DateTime.parse(query['to'] as String)
          .subtract(const Duration(microseconds: 1)),
    );
    return copy.formatRange(from, to);
  }

  /// P06 结论卡：期间名与区间一句、metricLg 主值、右侧 metricSm 趟数、
  /// 一句比较（多/少/持平）与「查看对比明细」下钻。
  Widget _conclusionTile(
    legacy.DrivingStats stats,
    insights.DrivingStats enhanced,
    Map? paired,
    bool comparable,
    Map<String, dynamic>? other,
  ) {
    final referenceKm = other == null
        ? null
        : legacy.DrivingStats.fromJson(other).totals.distanceKm;
    final colors = context.colors;
    final type = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$_periodName ${_currentRange()}',
          style: type.subheadline.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: MileafSpace.s4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: MetricBlock(
                value: grouped(stats.totals.distanceKm, decimals: 1),
                unit: 'km',
                scale: MetricValueScale.metricLg,
                semanticLabel:
                    '$_periodName ${grouped(stats.totals.distanceKm, decimals: 1)} 公里',
              ),
            ),
            const SizedBox(width: MileafSpace.s12),
            Text(
              '${stats.totals.drives} 趟',
              style: type.subheadline.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: MileafSpace.s4),
        Row(
          children: [
            Expanded(
              child: Text(
                _mileageDeltaText(
                  stats.totals.distanceKm,
                  referenceKm,
                  comparable,
                ),
                style: type.subheadline.copyWith(color: colors.textSecondary),
              ),
            ),
            MileafButton(
              label: '查看对比明细',
              kind: MileafButtonKind.ghost,
              onPressed: () => selectTopic('energy'),
            ),
          ],
        ),
      ],
    );
  }

  /// Same-surface mileage bars with a comparable dashed reference.
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

    var selected = times.isEmpty ? 0 : times.length - 1;
    for (var i = times.length - 1; i >= 0; i--) {
      if (i < values.length && (values[i] ?? 0) > 0) {
        selected = i;
        break;
      }
    }
    if (pointTouched && times.isNotEmpty) selected = _selectedPoint(times);
    return Semantics(
      label: '每日里程，本期与参照',
      child: TimeSeriesChart(
        key: const ValueKey('statistics-insights-chart-frame'),
        title: '每日里程',
        unit: 'km',
        times: times,
        series: [
          ChartSeries(
            label: '本期',
            values: values,
            style: ChartSeriesStyle.bars,
          ),
          if (comparable)
            ChartSeries(
              label: '$_compareName ${_referenceRange()}',
              values: referenceBuckets,
              style: ChartSeriesStyle.reference,
            ),
        ],
        semanticsLabel: '每日里程图表',
        showYAxis: true,
        height: MileafSpace.chartHeight,
        // §6 退让阶梯第 3 步：根页焦点卡改用紧凑读数行，为专题首行腾出高度。
        compactReadout: true,
        tickLabel: tick,
        readout: (index) {
          final value = index < values.length ? values[index] : null;
          final reference = comparable && index < referenceBuckets.length
              ? referenceBuckets[index]
              : null;
          return '${index < times.length ? tick(times[index]) : '—'} '
              '${value == null ? '—' : grouped(value, decimals: 1)} km'
              '${reference == null || value == null ? '' : ' / 参照 ${_referenceRange()} ${grouped(reference, decimals: 1)} km（差 ${grouped(value - reference, decimals: 1)} km）'}';
        },
        plotKey: const ValueKey('statistics-insights-chart'),
        selectedIndex: selected,
        onSelected: (index) => setState(() {
          point = index;
          pointAt = index < times.length ? times[index] : null;
          pointTouched = true;
        }),
      ),
    );
  }

  /// Keeps a deliberate point by its bucket date across revalidations, then
  /// falls back to the nearest earlier bucket that still exists.
  int _selectedPoint(List<DateTime> times) =>
      bucketIndexAt(times, pointAt) ?? point.clamp(0, times.length - 1);

  /// P06 专题卡片：入口图标 + 名称（headline）+ 一个 metricSm 值 + 一句脚注。
  Widget _chapter(
    String title,
    MileafIconName icon,
    String value,
    String? unit,
    String note,
    VoidCallback onTap,
  ) {
    final colors = context.colors;
    final type = context.type;
    return MileafModuleCard(
      padding: const EdgeInsets.all(MileafSpace.s12),
      child: InkWell(
        key: ValueKey('statistics-topic-$title'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(MileafRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MileafIcon(
                  icon,
                  size: MileafIconMetrics.nav,
                  color: colors.accentStrong,
                ),
                const SizedBox(width: MileafSpace.s8),
                Expanded(
                  child: Text(
                    title,
                    style: type.headline.copyWith(color: colors.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MileafSpace.s8),
            MetricBlock(
              value: value,
              unit: unit,
              scale: MetricValueScale.metricSm,
            ),
            const SizedBox(height: MileafSpace.s4),
            Text(
              note,
              style: type.footnote.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  /// A 2×2 chapter grid separated by 1px lines; no coloured cards.
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
    final known = totals?['cost_known_sessions'];
    final sessions = totals?['sessions'];
    final currencyNote = widget.currency.amountNote;
    final items = <Widget>[
      _chapter(
        '节奏',
        MileafIconName.clock,
        '$active',
        '天',
        minutes == null ? '驾驶时长缺失' : '驾驶 $duration',
        () => selectTopic('usage'),
      ),
      _chapter(
        '能耗',
        MileafIconName.chart,
        net == null ? '—' : _whKm(net),
        net == null ? null : 'Wh/km',
        '有效行程估算\n${_netDeltaNote(net, prior, comparable)}',
        () => selectTopic('energy'),
      ),
      _chapter(
        '补能',
        MileafIconName.bolt,
        widget.currency.amountValue(cost),
        null,
        chargingError ??
            (energy == null
                ? '充电统计读取失败'
                : '${known ?? '—'} / ${sessions ?? '—'} 次有记录 · '
                      '${grouped(energy, decimals: 1)} kWh'
                      '${currencyNote == null ? '' : ' · $currencyNote'}'),
        () => selectTopic('charging'),
      ),
      _chapter(
        '长期',
        MileafIconName.battery,
        '—',
        'km',
        '查看专题',
        () => selectTopic('long'),
      ),
    ];
    final inset = MileafLayout.pageInset(context);
    // 同一行两张卡片：保持 12 间距。等高需要固有尺寸测量，而 MileafNumber
    // 内部用 LayoutBuilder（不支持固有尺寸），因此这里按内容自然高度排列。
    Widget pair(int left, int right) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: items[left]),
        const SizedBox(width: MileafSpace.s12),
        Expanded(child: items[right]),
      ],
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, 0, inset, 0),
      child: MileafLayout.largeText(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const SizedBox(height: MileafSpace.s12),
                  items[i],
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                pair(0, 1),
                const SizedBox(height: MileafSpace.s12),
                pair(2, 3),
              ],
            ),
    );
  }

  String _netDeltaNote(num? value, num? prior, bool comparable) {
    if (!comparable || value == null || prior == null) return '样本不足或口径不一致';
    if (prior == 0) return '参照为0，不计算变化';
    final delta = value - prior;
    if (delta.abs() < .5) return '与参照基本持平';
    return '较参照${delta < 0 ? '低' : '高'} ${grouped(delta.abs())} Wh/km';
  }

  /// R30.2 页尾「关于这些数据」：口径与估算、记录与缺失、时间与时区、
  /// 来源与生成时间、技术详情（可复制）。
  Widget _moreSection(
    CalendarContext cal,
    legacy.DrivingStats stats,
    insights.DrivingStats enhanced,
    Map? paired,
    Map<String, dynamic>? other,
  ) {
    final active = enhanced.buckets.where((b) => b.distanceKm > 0).length;
    final coverage = enhanced.totals.comparisonQuality.distanceCoverage;
    final durationMin = enhanced.totals.drivingCoverage.durationKnownMin;
    final totals = charging?['totals'] as Map?;
    final known = totals?['cost_known_sessions'];
    final sessions = totals?['sessions'];
    return MileafDataNotes(
      groups: [
        MileafDataNoteGroup(
          category: DataNoteCategory.caliber,
          note: [
            '电耗按续航差和车辆效率估算。',
            if (paired?['value_wh_km'] != null)
              '有效行程电耗 ${paired!['value_wh_km']} Wh/km。',
            '耗时与抽样由服务器汇总，非车辆原始采样。',
          ].join(''),
        ),
        MileafDataNoteGroup(
          category: DataNoteCategory.records,
          note: [
            '用车 $active 天。',
            '已完成行程 ${enhanced.totals.drivingCoverage.completedDrives} 趟，'
                '${enhanced.totals.drivingCoverage.ongoingDrives} 趟进行中，未计入结果。',
            if (durationMin != null)
              '有记录的驾驶时长 ${copy.duration(Duration(minutes: durationMin.round()))}，'
                  '${enhanced.totals.drivingCoverage.durationKnownDrives} 趟有记录。',
            if (coverage != null)
              '里程覆盖 ${(coverage * 100).toStringAsFixed(0)}%。',
            if (sessions != null)
              '$sessions 次充电中 $known 次有费用。'
                  '${widget.currency.amountNote ?? ''}',
            '估算行驶能量 ${stats.totals.energyKwh?.toStringAsFixed(2) ?? '—'} kWh，'
                '能量有效里程 ${enhanced.totals.drivingCoverage.netEnergyKnownDistanceKm?.toStringAsFixed(1) ?? '—'} km。',
          ].join(''),
        ),
        MileafDataNoteGroup(
          category: DataNoteCategory.time,
          note:
              '统计时区 ${cal.identifier}。本期 ${_currentRange()}，'
              '行程按开始日期统计。',
        ),
        MileafDataNoteGroup(
          category: DataNoteCategory.source,
          note:
              '数据生成时间 ${copy.formatPrecise(cal.local(enhanced.asOf))}，'
              '不是车辆采样时间。',
        ),
        if (other != null)
          MileafDataNoteGroup(
            category: DataNoteCategory.technical,
            copyable: true,
            note: [
              '对比时间 ${_referenceRange()}',
              '对比里程 ${legacy.DrivingStats.fromJson(other).totals.distanceKm} km',
              '对比有效行程电耗 '
                  '${other['totals']['net_consumption_paired']['value_wh_km'] ?? '—'} Wh/km',
              '样本 ${other['totals']['comparison_quality']['sample_status']}，'
                  '${other['range_kind']}',
              '区间 ${other['query']['from']} — ${other['query']['to']}，'
                  '时区 ${other['query']['tz']}',
              '对比生成 ${cal.local(insights.DrivingStats.fromJson(other).asOf)}；'
                  '本期与对比分别生成，不是同一快照',
            ].join('\n'),
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
    appBar: mileafPageBar(context, title: const Text('全部指标与口径')),
    body: MileafContent(
      child: ListView(
        padding: MileafLayout.pagePadding(context),
        children: [
          for (final entry in const {
            'usage': ('节奏', '驾驶时间、单程与星期分布'),
            'energy': ('能耗', '温度与距离条件'),
            'charging': ('补能', '费用、均价与 AC/DC'),
            'long': ('长期', '额定续航与停放观察'),
          }.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.value.$1),
              subtitle: Text(entry.value.$2),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onTopic(entry.key),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('原始统计指标'),
            subtitle: const Text('驾驶与充电的区间指标、时间桶明细'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onTopic('legacy'),
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('数据说明'),
            children: [
              Text('沿用当前车辆与期间；归期时区 $timezone。'),
              const Text('各专题只回答一个问题，指标口径与统计首页一致。'),
            ],
          ),
        ],
      ),
    ),
  );
}
