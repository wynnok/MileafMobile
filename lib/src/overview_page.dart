import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'currency.dart';
import 'design/components/components.dart';
import 'design/icons.dart';
import 'design/layout.dart';
import 'design/motion.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'number_format.dart';
import 'driving_statistics_contract.g.dart' as stats;
import 'charging_statistics_contract.g.dart' as charge;
import 'charging_experience_contract.g.dart' as expanded;
import 'statistics_insights_contract.g.dart' as insights;
import 'statistics_insights_page.dart' show canCompare;
import 'overview_contract.g.dart' as dto;
import 'performance_trace.dart';
import 'statistics_period.dart';
import 'overview_period.dart';
import 'map/map_consent.dart';
import 'map/map_panel.dart';
import 'map/map_privacy_page.dart';
import 'map/map_key.dart';
import 'map/map_platform.dart';
import 'workspace.dart';
import 'session.dart' show SiteSession;

enum _Metric { distance, net, charge, cost, energy }

class OverviewPage extends StatefulWidget {
  const OverviewPage({
    super.key,
    required this.workspace,
    required this.currency,
    this.onRecord,
    this.onStatistics,
    this.onInsight,
    this.topBar,
  });
  final VehicleWorkspace workspace;
  final CurrencySettings currency;
  final void Function(String, StatisticsSelection)? onStatistics;
  final void Function(String, StatisticsSelection)? onInsight;
  final void Function(String kind, int id)? onRecord;
  final Widget? topBar;
  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage>
    with WidgetsBindingObserver {
  dto.Summary? data;
  CachedResult? result;
  String? error;
  bool loading = false;
  int sequence = 0;
  int capabilitySequence = 0;
  bool pairedAvailable = false, coverageAvailable = false;
  String? capabilityError;
  stats.DrivingStats? driving;
  charge.ChargingStats? charging;
  final results = <String, CachedResult>{};
  final errors = <String, String>{};
  final pending = <String>{};
  final attempts = <String, int>{};
  OverviewWindow? range;
  final ranges = <String, OverviewWindow>{};
  int scopeRevision = 0;
  OverviewWindow? comparisonRange;
  stats.DrivingStats? comparisonDriving;
  CachedResult? comparisonResult;
  OverviewPeriod period = OverviewPeriod.month;
  stats.DrivingStats? comparison;
  String? comparisonError;
  bool comparing = false;
  int comparisonSequence = 0;
  String? windowDay, windowZone;
  _Metric metric = _Metric.distance;
  int? chartSelection;
  final plotKey = GlobalKey();
  final chartKey = GlobalKey();
  final viewportKey = GlobalKey();
  VehicleWorkspace get workspace => widget.workspace;

  insights.DrivingStats? enhancedDriving(CachedResult? value) {
    if (!pairedAvailable || value == null) return null;
    try {
      return insights.DrivingStats.fromJson(value.body);
    } on FormatException {
      return null;
    }
  }

  expanded.ChargingStats? get enhancedCharging {
    if (!coverageAvailable || results['charging'] == null) return null;
    try {
      return expanded.ChargingStats.fromJson(results['charging']!.body);
    } on FormatException {
      return null;
    }
  }

  Future<void> loadCapabilities({bool force = false}) async {
    final owner = workspace.session.current;
    if (owner == null) return;
    final request = ++capabilitySequence;
    try {
      final result = await workspace.cache.get(owner, 'meta', force: force);
      if (!mounted ||
          request != capabilitySequence ||
          !workspace.session.isCurrent(owner)) {
        return;
      }
      final driving = result.body['statistics_insights'],
          charging = result.body['charging_experience'];
      setState(() {
        pairedAvailable =
            driving is Map &&
            driving['contract_version'] == 'statistics-insights-v1' &&
            driving['minimum_server_version'] == '0.3.0' &&
            driving['features'] is Map &&
            driving['features']['driving_coverage'] == true;
        coverageAvailable =
            charging is Map &&
            charging['contract_version'] == 'charging-experience-v1' &&
            charging['fields'] is Map;
        capabilityError = null;
      });
    } catch (_) {
      if (mounted &&
          request == capabilitySequence &&
          workspace.session.isCurrent(owner)) {
        setState(() => capabilityError = '扩展能力暂未确认；保留当前口径');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    workspace.addCostReader(refreshCost);
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
    await Future.wait([
      loadSummary(force: true),
      loadStats('charging', force: true, requestedRange: range),
    ]);
    return error == null && !errors.containsKey('charging');
  }

  bool get readable =>
      data != null &&
      driving != null &&
      charging != null &&
      !loading &&
      pending.isEmpty &&
      error == null &&
      errors.isEmpty &&
      windowZone == workspace.calendar?.identifier &&
      windowDay == workspace.calendar?.day(workspace.session.now());
  bool get chartVisible {
    final chart = chartTimes.isEmpty
        ? chartKey.currentContext?.findRenderObject()
        : plotKey.currentContext?.findRenderObject();
    final viewport = viewportKey.currentContext?.findRenderObject();
    if (chart is! RenderBox ||
        viewport is! RenderBox ||
        !chart.hasSize ||
        !viewport.hasSize) {
      return false;
    }
    final plotRect = chart.localToGlobal(Offset.zero) & chart.size;
    final viewRect = viewport.localToGlobal(Offset.zero) & viewport.size;
    return plotRect.width > 0 &&
        plotRect.height > 0 &&
        plotRect.top >= viewRect.top &&
        plotRect.bottom <= viewRect.bottom;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      final owner = workspace.session.current;
      if (readable && owner != null) {
        PerformanceTrace.warmOverviewFrame(
          () =>
              mounted &&
              workspace.session.isCurrent(owner) &&
              readable &&
              chartVisible &&
              (ModalRoute.of(context)?.isCurrent ?? false),
        );
      }
      foreground();
    }
  }

  Future<void> foreground() async {
    final changed = await workspace.foreground();
    if (mounted && !changed) await load();
  }

  Future<void> load({bool force = false}) async {
    final calendar = workspace.calendar, owner = workspace.session.current;
    final id = workspace.selectedId;
    if (calendar == null || owner == null || id == null) return;
    final now = workspace.session.now();
    final day = calendar.day(now);
    if (windowDay != null &&
        (day != windowDay || calendar.identifier != windowZone)) {
      setState(() {
        scopeRevision++;
        sequence++;
        comparisonSequence++;
        data = null;
        result = null;
        error = null;
        driving = null;
        charging = null;
        results.clear();
        ranges.clear();
        errors.clear();
        pending.clear();
        comparison = null;
        comparisonDriving = null;
        comparisonRange = null;
        comparisonResult = null;
        comparisonError = null;
        comparing = false;
      });
    }
    windowDay = day;
    windowZone = calendar.identifier;
    try {
      range = OverviewWindow(period, calendar, now);
    } on FormatException {
      setState(() => errors['driving'] = '本期尚无可统计时间，稍后刷新里程趋势');
      await loadSummary(force: force);
      return;
    }
    await Future.wait([
      loadCapabilities(force: force),
      loadSummary(force: force),
      loadStats('driving', force: force, requestedRange: range),
      loadStats('charging', force: force, requestedRange: range),
    ]);
  }

  Future<void> loadSummary({bool force = false}) async {
    final owner = workspace.session.current, calendar = workspace.calendar;
    final id = workspace.selectedId;
    if (owner == null || calendar == null || id == null) return;
    final attempt = ++sequence;
    bool current() =>
        mounted &&
        attempt == sequence &&
        workspace.session.isCurrent(owner) &&
        workspace.selectedId == id &&
        workspace.calendar?.identifier == calendar.identifier;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await workspace.cache.get(
        owner,
        'vehicles/$id/summary',
        query: {'tz': calendar.identifier},
        force: force,
      );
      final decoded = dto.Summary.fromJson(value.body);
      if (!current()) return;
      if (decoded.vehicle.id != id) throw const FormatException();
      setState(() {
        data = decoded;
        result = value;
      });
    } catch (e) {
      if (!current()) return;
      PerformanceTrace.mark(PerformancePoint.overviewFailed);
      if (e is BusinessFailure && e.status == 404) {
        await workspace.session.loadVehicles();
      }
      if (current()) {
        setState(
          () => error = e is FormatException
              ? '服务返回格式不兼容，请核对版本'
              : '${e is ApiFailure ? e.message : '数据读取失败'}${data == null ? '' : '；保留上次快照'}',
        );
      }
    } finally {
      if (current()) setState(() => loading = false);
    }
  }

  Future<void> loadStats(
    String kind, {
    bool force = false,
    OverviewWindow? requestedRange,
  }) async {
    final owner = workspace.session.current, calendar = workspace.calendar;
    final id = workspace.selectedId;
    if (owner == null || calendar == null || id == null) return;
    if (calendar.day(workspace.session.now()) != windowDay ||
        calendar.identifier != windowZone) {
      await load(force: true);
      return;
    }
    final revalidate = force || errors.containsKey(kind);
    if (!revalidate &&
        (results[kind]?.validUntil.isAfter(workspace.session.now()) ?? false)) {
      if (kind == 'driving') unawaited(loadComparison());
      return;
    }
    final OverviewWindow requested;
    try {
      requested =
          requestedRange ??
          OverviewWindow(period, calendar, workspace.session.now());
    } on FormatException {
      setState(() => errors[kind] = '本期尚无可统计时间，请稍后刷新');
      return;
    }
    final scope = scopeRevision, attempt = (attempts[kind] ?? 0) + 1;
    attempts[kind] = attempt;
    bool current() =>
        mounted &&
        scope == scopeRevision &&
        attempt == attempts[kind] &&
        workspace.session.isCurrent(owner) &&
        workspace.selectedId == id &&
        workspace.calendar?.identifier == calendar.identifier;
    setState(() {
      pending.add(kind);
      errors.remove(kind);
    });
    try {
      final value = await workspace.cache.get(
        owner,
        'vehicles/$id/stats',
        query: requested.current.query(kind, calendar),
        force: revalidate,
      );
      if (!current()) return;
      if (kind == 'driving') {
        final decoded = stats.DrivingStats.fromJson(value.body);
        setState(() {
          driving = decoded;
          results[kind] = value;
          ranges[kind] = requested;
        });
        unawaited(loadComparison(force: force));
      } else {
        final decoded = charge.ChargingStats.fromJson(value.body);
        setState(() {
          charging = decoded;
          results[kind] = value;
          ranges[kind] = requested;
        });
      }
    } catch (e) {
      if (!current()) return;
      PerformanceTrace.mark(PerformancePoint.overviewFailed);
      setState(
        () => errors[kind] = e is FormatException
            ? '统计返回格式不兼容，请核对版本'
            : '${e is ApiFailure ? e.message : '统计读取失败'}${results[kind] == null
                  ? ''
                  : kind == 'driving'
                  ? '；保留上次趋势快照'
                  : '；保留上次补能快照'}',
      );
    } finally {
      if (current()) setState(() => pending.remove(kind));
    }
  }

  Future<void> changePeriod(OverviewPeriod value) async {
    if (value == period) return;
    setState(() {
      scopeRevision++;
      period = value;
      range = null;
      driving = null;
      charging = null;
      comparison = null;
      results.clear();
      ranges.clear();
      comparisonRange = null;
      comparisonDriving = null;
      comparisonResult = null;
      errors.clear();
      pending.clear();
      comparisonSequence++;
      comparing = false;
      comparisonError = null;
    });
    await load();
  }

  Future<void> loadComparison({bool force = false}) async {
    final owner = workspace.session.current, calendar = workspace.calendar;
    final id = workspace.selectedId,
        requested = ranges['driving'],
        currentDriving = driving;
    if (owner == null ||
        calendar == null ||
        id == null ||
        requested == null ||
        currentDriving == null) {
      return;
    }
    if (calendar.day(workspace.session.now()) != windowDay) {
      await load(force: true);
      return;
    }
    if (requested.previous == null) {
      setState(() {
        comparisonSequence++;
        comparison = null;
        comparisonDriving = null;
        comparisonRange = null;
        comparisonResult = null;
        comparisonError = null;
        comparing = false;
      });
      return;
    }
    final revalidate = force || comparisonError != null;
    if (!revalidate &&
        identical(comparisonRange, requested) &&
        (comparisonResult?.validUntil.isAfter(workspace.session.now()) ??
            false)) {
      return;
    }
    final attempt = ++comparisonSequence, scope = scopeRevision;
    bool current() =>
        mounted &&
        scope == scopeRevision &&
        attempt == comparisonSequence &&
        identical(ranges['driving'], requested) &&
        workspace.session.isCurrent(owner) &&
        workspace.selectedId == id &&
        workspace.calendar?.identifier == calendar.identifier;
    setState(() {
      comparing = true;
      comparisonError = null;
    });
    try {
      final value = await workspace.cache.get(
        owner,
        'vehicles/$id/stats',
        query: requested.previous!.query('driving', calendar),
        force: revalidate,
      );
      final decoded = stats.DrivingStats.fromJson(value.body);
      if (current()) {
        setState(() {
          comparison = decoded;
          comparisonDriving = currentDriving;
          comparisonRange = requested;
          comparisonResult = value;
        });
      }
    } catch (e) {
      if (current()) {
        setState(
          () => comparisonError = e is ApiFailure ? e.message : '比较数据读取失败',
        );
      }
    } finally {
      if (current()) setState(() => comparing = false);
    }
  }

  String timestamp(DateTime? time) => time == null
      ? '未知'
      : workspace.calendar!.local(time).toString().split('.').first;

  String _shortStamp(DateTime? time) {
    if (time == null) return '未知时间';
    final local = workspace.calendar!.local(time);
    return '${local.month}/${local.day} · '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String _clock(DateTime time) {
    final local = workspace.calendar!.local(time);
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String number(num? value, String unit, {int decimals = 0}) =>
      value == null ? '—' : '${grouped(value, decimals: decimals)} $unit';

  String get _zone => workspace.calendar?.identifier ?? 'UTC';

  bool get _referenceValid =>
      comparison != null &&
      identical(comparisonRange, ranges['driving']) &&
      comparisonError == null &&
      driving != null &&
      comparison!.buckets.length == driving!.buckets.length;

  bool get _stale {
    final at = data?.freshness.lastPositionAt;
    if (at == null) return true;
    return workspace.session.now().difference(at) > const Duration(minutes: 10);
  }

  String get _stateLabel => switch (data?.state?.value) {
    'online' => '在线',
    'asleep' => '休眠',
    'offline' => '离线',
    'charging' => '充电中',
    _ => '状态未知',
  };

  /// The brand row belongs to the hero only in the full-bleed (dark) form.
  ///
  /// Once the hero is a card, the status bar sits over paper and the row moves
  /// out of the hero as a sibling above it (Spec §6.4); the hero adds no top
  /// inset of its own in that form.
  Widget _topInset() {
    if (context.colors.heroAsCard) return const SizedBox.shrink();
    if (widget.topBar != null) return widget.topBar!;
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: const SizedBox(height: MileafSpace.s12),
    );
  }

  Widget _hero(dto.Summary d) {
    final colors = context.colors;
    final type = context.type;
    final large = MileafLayout.largeText(context);
    final charging = d.state?.value == 'charging';
    final since = d.state?.since;
    final statusColor = _stale
        ? colors.warning
        : charging || d.state?.value == 'online'
        ? colors.accentHero
        : colors.heroMuted;
    final statusText = _stale
        ? '非实时 · 数据截至 ${_clock(d.freshness.lastPositionAt ?? d.freshness.lastStateAt ?? workspace.session.now())}'
        : '$_stateLabel${charging && d.chargingPowerKw != null ? ' · ${d.chargingPowerKw!.toStringAsFixed(1)} kW' : ''}';
    final ago = since == null
        ? null
        : relativeTime(
            workspace.calendar!.local(since),
            workspace.calendar!.local(workspace.session.now()),
          );
    final rangeLabel = switch (d.battery?.rangeKind) {
      'rated' => '额定续航',
      'ideal' => '理想续航（ideal）',
      _ => '续航（未知口径）',
    };
    final range = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MileafNumber(
          value: d.battery?.rangeKm?.toStringAsFixed(0),
          unit: 'km',
          scale: MetricValueScale.display,
          onHero: true,
        ),
        const SizedBox(height: MileafSpace.s4),
        Text(
          '$rangeLabel · 非实时',
          style: type.micro.copyWith(color: colors.heroMuted),
        ),
      ],
    );
    final arc = BatteryArc(
      level: d.battery?.level,
      onHero: true,
      size: large
          ? MileafBatteryMetrics.largeTextSize
          : MileafBatteryMetrics.size,
    );
    final today = d.period.today;
    final stats = large
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _todayStat(
                      '今日 km',
                      today.distanceKm.toStringAsFixed(1),
                    ),
                  ),
                  Expanded(child: _todayStat('次行程', '${today.drives}')),
                ],
              ),
              const SizedBox(height: MileafSpace.s12),
              Align(
                alignment: Alignment.centerLeft,
                child: _todayStat(
                  '估算 kWh',
                  today.energyKwh?.toStringAsFixed(2),
                ),
              ),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _todayStat('今日 km', today.distanceKm.toStringAsFixed(1)),
              ),
              Expanded(child: _todayStat('次行程', '${today.drives}')),
              Expanded(
                child: _todayStat(
                  '估算 kWh',
                  today.energyKwh?.toStringAsFixed(2),
                ),
              ),
            ],
          );
    return MileafHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _topInset(),
          Padding(
            padding: EdgeInsets.fromLTRB(
              MileafLayout.heroInset(context),
              MileafSpace.s4,
              MileafLayout.heroInset(context),
              MileafSpace.heroBottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: MileafSpace.s4),
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: MileafSpace.s8),
                    Expanded(
                      child: Text(
                        statusText,
                        style: type.label.copyWith(color: colors.heroMuted),
                      ),
                    ),
                    if (ago != null) ...[
                      const SizedBox(width: MileafSpace.s12),
                      Text(
                        ago,
                        style: type.label.copyWith(color: colors.heroFaint),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: MileafSpace.inline6),
                if (large) ...[
                  range,
                  const SizedBox(height: MileafSpace.s12),
                  Align(alignment: Alignment.centerRight, child: arc),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: range),
                      arc,
                    ],
                  ),
                const SizedBox(height: MileafSpace.row14),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: colors.heroText.withValues(alpha: .12),
                ),
                const SizedBox(height: MileafSpace.s12),
                stats,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _todayStat(String label, String? value) => MetricBlock(
    label: label,
    value: value,
    onHero: true,
    scale: MetricValueScale.metricMd,
  );

  Widget _heroSkeleton() => MileafHero(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _topInset(),
        Padding(
          padding: EdgeInsets.fromLTRB(
            MileafLayout.heroInset(context),
            MileafSpace.s4,
            MileafLayout.heroInset(context),
            MileafSpace.heroBottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  SkeletonBlock(width: 120, height: 12),
                  Spacer(),
                  SkeletonBlock(width: 56, height: 12),
                ],
              ),
              const SizedBox(height: MileafSpace.s20),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: SkeletonBlock(width: 180, height: 60)),
                  SizedBox(width: MileafSpace.s16),
                  SkeletonBlock(width: 88, height: 88, radius: 44),
                ],
              ),
              const SizedBox(height: MileafSpace.s20),
              const Divider(height: 1),
              const SizedBox(height: MileafSpace.s12),
              const Row(
                children: [
                  Expanded(child: SkeletonBlock(width: 60, height: 36)),
                  Expanded(child: SkeletonBlock(width: 40, height: 36)),
                  Expanded(child: SkeletonBlock(width: 70, height: 36)),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _heroEmpty() {
    final retryable = error != null;
    return MileafHero(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _topInset(),
          StateView(
            kind: retryable ? StateViewKind.error : StateViewKind.empty,
            onHero: true,
            title: retryable ? '车况暂不可用' : '暂无车况',
            message: error ?? '下拉刷新或检查站点连接',
            actionLabel: '重试概览',
            onAction: () => loadSummary(force: true),
          ),
        ],
      ),
    );
  }

  Widget _periodBar() => Padding(
    padding: const EdgeInsets.only(
      top: MileafSpace.s16,
      bottom: MileafSpace.s4,
    ),
    child: Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: MileafSpace.s8,
            runSpacing: MileafSpace.s8,
            children: [
              StatusChip(
                label: '本月',
                selected: period == OverviewPeriod.month,
                onTap: () {
                  if (period != OverviewPeriod.month) {
                    chartSelection = null;
                    changePeriod(OverviewPeriod.month);
                  }
                },
              ),
              StatusChip(
                label: '近7天',
                selected: period == OverviewPeriod.recent,
                onTap: () {
                  if (period != OverviewPeriod.recent) {
                    chartSelection = null;
                    changePeriod(OverviewPeriod.recent);
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: MileafSpace.s8),
        MileafIconButton(
          icon: MileafIconName.refresh,
          tooltip: '刷新概览',
          onPressed: loading ? null : () => loadSummary(force: true),
        ),
      ],
    ),
  );

  String get _monthStamp {
    final now = workspace.calendar!.local(workspace.session.now());
    return '${now.month} 月 · ${now.year}';
  }

  String get _recentStamp {
    final window = range?.current;
    if (window == null) return '近 7 天';
    final calendar = workspace.calendar!;
    final first = calendar.local(window.from);
    final last = calendar.local(
      window.to.subtract(const Duration(microseconds: 1)),
    );
    return '${first.month}/${first.day} — ${last.month}/${last.day}';
  }

  ({String text, String? label, bool? up})? get _mileageDelta {
    final requested = ranges['driving'];
    final current = driving?.totals.distanceKm;
    if (requested == null || current == null) return null;
    final window = period == OverviewPeriod.month ? '上月同期' : '前一区间';
    if (requested.previous == null) return null;
    if (comparison == null) {
      if (comparing) return (text: '读取参照中', label: null, up: null);
      if (comparisonError != null) {
        return (text: '参照暂不可用', label: window, up: null);
      }
      return null;
    }
    if (!identical(comparisonRange, requested) || comparisonError != null) {
      return (text: '参照暂不可用', label: window, up: null);
    }
    final previous = comparison!.totals.distanceKm;
    if (previous == 0) return (text: '基期为 0', label: window, up: null);
    final percent = (current - previous) / previous * 100;
    if (percent.abs() < .05) {
      return (text: '持平', label: '较$window', up: null);
    }
    return (
      text: '${percent.abs().toStringAsFixed(1)}%',
      label: '较$window',
      up: percent > 0,
    );
  }

  Widget _deltaWidget() {
    final delta = _mileageDelta;
    if (delta == null) {
      return Text(
        '同期参照不足',
        style: context.type.micro.copyWith(color: context.colors.textFaint),
      );
    }
    if (delta.up == null && delta.text != '持平') {
      return Text(
        delta.text,
        textAlign: TextAlign.end,
        style: context.type.micro.copyWith(color: context.colors.textFaint),
      );
    }
    return MetricDelta(text: delta.text, label: delta.label, up: delta.up);
  }

  Widget _monthSection() {
    final value = driving?.totals.distanceKm;
    final parts = value == null ? '—' : grouped(value, decimals: 1);
    final drives = driving?.totals.drives;
    final kicker = period == OverviewPeriod.month ? '本月 · 驾驶里程' : '近7天 · 驾驶里程';
    final semantic =
        '${period == OverviewPeriod.month ? '本月' : '近7天'}驾驶里程 '
        '$parts km，${drives ?? '—'} 趟';
    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: kicker,
            range: period == OverviewPeriod.month ? _monthStamp : _recentStamp,
          ),
          const SizedBox(height: MileafSpace.s8),
          MetricBlock(
            semanticLabel: semantic,
            value: parts,
            unit: 'km',
            scale: MetricValueScale.metricLg,
            trailing: _deltaWidget(),
          ),
        ],
      ),
    );
  }

  List<DateTime> get chartTimes =>
      metric == _Metric.charge || metric == _Metric.cost
      ? [
          for (final b in charging?.buckets ?? <charge.ChargingBucket>[])
            b.bucketStart,
        ]
      : [
          for (final b in driving?.buckets ?? <stats.DrivingBucket>[])
            b.bucketStart,
        ];

  String tickLabelAt(List<DateTime> times, int index) {
    if (index < 0 || index >= times.length) return '—';
    final local = workspace.calendar!.local(times[index]);
    return '${local.month}/${local.day}';
  }

  String? _rangeText(StatisticsWindow? window) {
    final calendar = workspace.calendar;
    if (window == null || calendar == null) return null;
    final first = calendar.local(window.from);
    final last = calendar.local(
      window.to.subtract(const Duration(microseconds: 1)),
    );
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(first.month)}.${two(first.day)} — '
        '${two(last.month)}.${two(last.day)}';
  }

  List<num?> _currentValues() {
    final isCharging = metric == _Metric.charge || metric == _Metric.cost;
    if (isCharging) {
      return [
        for (final b in charging?.buckets ?? <charge.ChargingBucket>[])
          metric == _Metric.cost ? b.cost : b.energyAddedKwh,
      ];
    }
    final paired = enhancedDriving(results['driving']);
    return [
      for (final (index, b)
          in (driving?.buckets ?? <stats.DrivingBucket>[]).indexed)
        switch (metric) {
          _Metric.net =>
            pairedAvailable
                ? paired?.buckets
                      .elementAtOrNull(index)
                      ?.netConsumptionPaired
                      .valueWhKm
                : b.consumptionWhKmNet,
          _Metric.energy => b.energyKwh,
          _ => b.distanceKm,
        },
    ];
  }

  List<num?>? _referenceValues() {
    if (!_referenceValid) return null;
    final prior = comparison!;
    if (metric == _Metric.charge || metric == _Metric.cost) return null;
    final pairedPrior = pairedAvailable
        ? enhancedDriving(comparisonResult)
        : null;
    return [
      for (final (index, b) in prior.buckets.indexed)
        switch (metric) {
          _Metric.net =>
            pairedAvailable
                ? pairedPrior?.buckets
                      .elementAtOrNull(index)
                      ?.netConsumptionPaired
                      .valueWhKm
                : b.consumptionWhKmNet,
          _Metric.energy => b.energyKwh,
          _ => b.distanceKm,
        },
    ];
  }

  Widget mainChart() {
    final isCharging = metric == _Metric.charge || metric == _Metric.cost;
    final source = isCharging ? charging : driving;
    if (source == null) return const SizedBox.shrink();
    final (title, unit) = switch (metric) {
      _Metric.distance => ('每日里程', 'km'),
      _Metric.net => ('净电耗趋势 · 估算', 'Wh/km'),
      _Metric.energy => ('驾驶消耗趋势 · 估算', 'kWh'),
      _Metric.charge => ('充入电量趋势', 'kWh'),
      _Metric.cost => ('已知费用趋势', widget.currency.code ?? '币种未记录'),
    };
    final values = _currentValues();
    final reference = _referenceValues();
    final times = chartTimes;
    final selected =
        chartSelection ??
        (values.lastIndexWhere((v) => v != null && v > 0) < 0
            ? 0
            : values.lastIndexWhere((v) => v != null && v > 0));
    final evidence = isCharging
        ? ranges['charging']?.current
        : ranges['driving']?.current;
    String readout(int index) {
      final value = index < values.length ? values[index] : null;
      final stamp = tickLabelAt(times, index);
      return switch (metric) {
        _Metric.cost => '$stamp · ${widget.currency.amountValue(value)}',
        _Metric.net =>
          value == null
              ? '$stamp · —'
              : '$stamp · ${value.toStringAsFixed(0)} Wh/km',
        _ =>
          value == null
              ? '$stamp · —'
              : '$stamp · ${value.toStringAsFixed(1)} $unit',
      };
    }

    return TimeSeriesChart(
      key: chartKey,
      plotKey: plotKey,
      title: metric == _Metric.net && pairedAvailable ? '配对净电耗趋势 · 估算' : title,
      unit: unit,
      times: times,
      semanticsLabel: '$title图表',
      series: [
        ChartSeries(
          label: metric == _Metric.net ? '本期' : '里程',
          values: values,
          style: switch (metric) {
            _Metric.distance => ChartSeriesStyle.area,
            _Metric.net || _Metric.energy => ChartSeriesStyle.line,
            _ => ChartSeriesStyle.bars,
          },
        ),
        if (reference != null)
          ChartSeries(
            label: '参照',
            values: reference,
            style: ChartSeriesStyle.reference,
          ),
      ],
      selectedIndex: selected,
      onSelected: (index) => setState(() => chartSelection = index),
      readout: readout,
      trailing: Text(
        '点按读值',
        style: context.type.label.copyWith(color: context.colors.textFaint),
      ),
      subtitle: _rangeText(evidence),
      tickLabel: (time) {
        final local = workspace.calendar!.local(time);
        return '${local.month}/${local.day}';
      },
      controls: _metricTabs(),
      note: metric == _Metric.cost ? '仅含费用已知记录；缺失不表示免费。' : null,
    );
  }

  Widget _metricTabs() => Wrap(
    spacing: MileafSpace.s8,
    runSpacing: MileafSpace.s8,
    children: [
      for (final (m, label) in [
        (_Metric.distance, '里程'),
        (_Metric.net, '电耗'),
        (_Metric.charge, '补能'),
        (_Metric.cost, '费用'),
      ])
        StatusChip(
          label: label,
          selected: metric == m,
          onTap: () => setState(() {
            metric = m;
            chartSelection = null;
          }),
        ),
    ],
  );

  Widget _auxReadout() {
    final paired = enhancedDriving(results['driving']);
    final net = pairedAvailable
        ? paired?.totals.netConsumptionPaired.valueWhKm
        : driving?.totals.consumptionWhKmNet;
    final expanded = enhancedCharging;
    final cost = expanded?.totals.cost ?? charging?.totals.cost;
    final note = widget.currency.amountNote;
    final coverage = expanded == null || expanded.totals.sessions == 0
        ? null
        : '${expanded.totals.costKnownSessions}/${expanded.totals.sessions} 次';
    final parts = <String>[
      '净电耗 ${net == null ? '—' : '${net.toStringAsFixed(0)} Wh/km'}',
      '已知费用 ${widget.currency.amountValue(cost)}',
      ?note,
      ?coverage,
    ];
    return Text(
      parts.join(' · '),
      style: context.type.body.copyWith(color: context.colors.textMuted),
    );
  }

  Widget _chartSection() {
    if (driving == null && charging == null) {
      if (loading || pending.isNotEmpty) {
        return const Padding(
          padding: EdgeInsets.only(top: MileafSpace.section),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SkeletonBlock(width: 120, height: 18),
              SizedBox(height: MileafSpace.s12),
              SkeletonBlock(width: double.infinity, height: 140),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          mainChart(),
          const SizedBox(height: MileafSpace.s8),
          _auxReadout(),
        ],
      ),
    );
  }

  Widget _recentSection(dto.Summary d) {
    final drive = d.lastDrive;
    final charge = d.lastCharge;
    Widget row({
      required String title,
      required String meta,
      String? value,
      String? unit,
      required MileafIconName icon,
      VoidCallback? onTap,
      bool topLine = false,
    }) => MileafDataRow(
      title: title,
      meta: meta,
      value: value,
      unit: unit,
      icon: icon,
      showChevron: onTap != null,
      topLine: topLine,
      onTap: onTap,
      semanticLabel:
          '$title，$meta${value == null ? '' : '，$value${unit == null ? '' : ' $unit'}'}',
    );
    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: '最近'),
          const SizedBox(height: MileafSpace.s8),
          row(
            title: '最近行程',
            meta: drive == null
                ? '这段时间还没有行程'
                : '${_shortStamp(drive.startedAt)} · '
                      '净电耗 ${number(drive.consumptionWhKm, 'Wh/km')}',
            value: drive?.distanceKm?.toStringAsFixed(1),
            unit: drive?.distanceKm == null ? null : 'km',
            icon: MileafIconName.route,
            onTap: drive == null
                ? null
                : () => widget.onRecord?.call('drive', drive.id),
            topLine: true,
          ),
          row(
            title: '最近充电',
            meta: charge == null
                ? '还没有充电记录'
                : '${_shortStamp(charge.startedAt)} · '
                      '充入 ${number(charge.energyKwh, 'kWh', decimals: 2)}',
            value: charge?.endSoc?.toStringAsFixed(0),
            unit: charge?.endSoc == null ? null : '%',
            icon: MileafIconName.bolt,
            onTap: charge == null
                ? null
                : () => widget.onRecord?.call('charging', charge.id),
          ),
        ],
      ),
    );
  }

  Widget _continueSection() {
    if (widget.onInsight == null || range == null) {
      return const SizedBox.shrink();
    }
    void open(String topic) => widget.onInsight!.call(topic, range!.selection);
    Widget row({
      required String title,
      required String meta,
      required MileafIconName icon,
      required String topic,
      bool topLine = false,
      bool bottomLine = false,
    }) => MileafDataRow(
      title: title,
      meta: meta,
      icon: icon,
      showChevron: true,
      topLine: topLine,
      bottomLine: bottomLine,
      onTap: () => open(topic),
    );
    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: '继续'),
          const SizedBox(height: MileafSpace.s8),
          row(
            title: '节奏',
            meta: '驾驶时间与单程',
            icon: MileafIconName.clock,
            topic: 'usage',
            topLine: true,
          ),
          row(
            title: '能耗',
            meta: '温度与距离',
            icon: MileafIconName.chart,
            topic: 'energy',
          ),
          row(
            title: '长期',
            meta: '续航与停放',
            icon: MileafIconName.battery,
            topic: 'long',
            bottomLine: true,
          ),
        ],
      ),
    );
  }

  Widget _techRow(String label, String value) {
    final type = context.type;
    final colors = context.colors;
    final labelWidget = Text(
      label,
      style: type.micro.copyWith(color: colors.textMuted),
    );
    final valueWidget = Text(
      value,
      textAlign: TextAlign.end,
      style: type.body.copyWith(
        color: colors.text,
        fontFeatures: type.body.fontFeatures,
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: MileafSpace.s8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: MileafLayout.largeText(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: MileafSpace.s4),
                Align(alignment: Alignment.centerRight, child: valueWidget),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: labelWidget),
                const SizedBox(width: MileafSpace.s12),
                Expanded(flex: 6, child: valueWidget),
              ],
            ),
    );
  }

  Widget _noteSection(String title, List<Widget> children, {Widget? action}) =>
      Padding(
        padding: const EdgeInsets.only(top: MileafSpace.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: title, action: action),
            const SizedBox(height: MileafSpace.s4),
            ...children,
          ],
        ),
      );

  Widget _shareBar() {
    final rows = <(String, num?)>[
      ('AC', charging?.totals.acEnergyKwh),
      ('DC', charging?.totals.dcEnergyKwh),
      ('未知', enhancedCharging?.totals.unknownEnergyKwh),
    ];
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MileafCompositionBar(segments: rows),
        const SizedBox(height: MileafSpace.s8),
        Wrap(
          spacing: MileafSpace.s16,
          runSpacing: MileafSpace.s4,
          children: [
            for (final (label, value) in rows)
              Text(
                '$label ${value == null ? '—' : '${value.toStringAsFixed(2)} kWh'}',
                style: context.type.micro.copyWith(color: colors.textMuted),
              ),
          ],
        ),
        const SizedBox(height: MileafSpace.s4),
        Text(
          'DC 占已知分类能量 ${charging?.totals.dcEnergyShare == null ? '—' : '${(charging!.totals.dcEnergyShare! * 100).toStringAsFixed(1)} %'}',
          style: context.type.body.copyWith(color: colors.text),
        ),
      ],
    );
  }

  Widget _coverageNote() {
    if (!coverageAvailable || charging == null) return const SizedBox.shrink();
    final enhanced = enhancedCharging;
    return _noteSection('已知费用的覆盖', [
      if (enhanced != null) ...[
        _techRow(
          '费用有记录',
          '${enhanced.totals.costKnownSessions} / ${enhanced.totals.sessions} 次',
        ),
        _techRow(
          '对应入电',
          number(enhanced.totals.costKnownEnergyKwh, 'kWh', decimals: 1),
        ),
        _techRow(
          '有效入电均价',
          '${widget.currency.amountValue(enhanced.totals.unitCostAdded.value)}/kWh',
        ),
        Text(
          '已知支出不等于全部用车成本。',
          style: context.type.micro.copyWith(color: context.colors.textMuted),
        ),
      ] else
        Text(
          '费用覆盖字段缺失或不兼容，未按完整费用显示',
          style: context.type.body.copyWith(color: context.colors.textMuted),
        ),
    ]);
  }

  Widget _comparisonNote() {
    if (driving == null) return const SizedBox.shrink();
    return pairedAvailable ? _pairedComparisonNote() : _legacyComparisonNote();
  }

  Widget _legacyComparisonNote() {
    final current = (comparisonDriving ?? driving)?.totals;
    final prior = comparison?.totals;
    final pairedRange = comparisonRange ?? ranges['driving'];
    String message;
    if (ranges['driving']?.previous == null) {
      message = '基期没有可对齐的本地日期或唯一时刻，暂不比较';
    } else if (comparing && comparison == null) {
      message = '正在读取比较数据';
    } else if (current == null ||
        prior == null ||
        current.drives == 0 ||
        prior.drives == 0 ||
        current.consumptionWhKmNet == null ||
        prior.consumptionWhKmNet == null ||
        prior.consumptionWhKmNet == 0) {
      message = '电耗样本不足，暂不作区间比较';
    } else {
      final delta = current.consumptionWhKmNet! - prior.consumptionWhKmNet!;
      message = delta != 0 && delta.abs() < 1
          ? '估算净电耗与前一同长区间差异小于1 Wh/km'
          : delta == 0
          ? '估算净电耗与前一同长区间相同'
          : '估算净电耗比前一同长区间${delta < 0 ? '低' : '高'} ${delta.abs().toStringAsFixed(0)} Wh/km';
    }
    return _noteSection('一条有参照的变化', [
      Text(message, style: context.type.body),
      if (comparing) const MileafProgressLine(),
      if (comparisonError != null)
        InlineBanner(
          message:
              '比较暂不可用：$comparisonError${comparison == null ? '' : '；保留上次比较快照'}',
          tone: BannerTone.error,
          actionLabel: '重试比较',
          onAction: () => loadComparison(force: true),
        ),
      if (comparisonRange != null)
        _techRow('比较快照截止', timestamp(comparisonRange!.current.to)),
      const SizedBox(height: MileafSpace.s4),
      Text(
        '样本覆盖率尚不可核验，不直接判断驾驶更省电。',
        style: context.type.micro.copyWith(color: context.colors.textMuted),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => _showComparisonBasis(current, prior, pairedRange),
          child: const Text('查看比较依据'),
        ),
      ),
    ]);
  }

  void _showComparisonBasis(
    stats.DrivingMetrics? current,
    stats.DrivingMetrics? prior,
    OverviewWindow? pairedRange,
  ) {
    showMileafSheet<void>(
      context: context,
      title: '比较依据',
      builder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _techRow('本期', number(current?.consumptionWhKmNet, 'Wh/km')),
          _techRow('基期', number(prior?.consumptionWhKmNet, 'Wh/km')),
          _techRow(
            '本期区间',
            '${timestamp(pairedRange?.current.from)} 至 ${timestamp(pairedRange?.current.to)}',
          ),
          if (pairedRange?.previous case final p?)
            _techRow('基期区间', '${timestamp(p.from)} 至 ${timestamp(p.to)}'),
          _techRow('归期时区', _zone),
          const SizedBox(height: MileafSpace.s12),
          Text(
            '同车、同一时区、同一本地截止时刻。净电耗基于续航差和车辆效率估算，部分能量样本可能缺失；只描述数值差异，不推断原因。基期为零或缺失时不输出比较结论。',
            style: context.type.micro.copyWith(color: context.colors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _pairedComparisonNote() {
    final current = enhancedDriving(results['driving']);
    final prior = enhancedDriving(comparisonResult);
    final currentResult = results['driving'];
    final valid =
        current != null &&
        prior != null &&
        currentResult != null &&
        comparisonResult != null &&
        comparisonError == null &&
        identical(comparisonRange, ranges['driving']) &&
        canCompare(
          currentResult.body,
          comparisonResult!.body,
          workspace.calendar!,
          period == OverviewPeriod.month
              ? StatisticsPeriod.month
              : StatisticsPeriod.custom,
        );
    final value = current?.totals.netConsumptionPaired;
    return _noteSection('配对净电耗与覆盖', [
      _techRow(
        '配对估算净电耗',
        '${number(value?.valueWhKm, 'Wh/km')} · '
            '${value?.eligibleDrives ?? '—'}趟有效',
      ),
      _techRow(
        '记录驾驶时长',
        '${number(current?.totals.drivingCoverage.durationKnownMin, '分钟')} · '
            '${current?.totals.drivingCoverage.durationKnownDrives ?? '—'}趟有记录',
      ),
      _techRow(
        '有效里程',
        '${number(value?.denominatorDistanceKm, 'km', decimals: 1)} '
            '（全里程 ${number(driving?.totals.distanceKm, 'km', decimals: 1)}）',
      ),
      Text(
        valid
            ? '配对净电耗较参照差 ${(value!.valueWhKm! - prior.totals.netConsumptionPaired.valueWhKm!).toStringAsFixed(1)} Wh/km'
            : '参照质量或口径不满足时，仅展示原值',
        style: context.type.body,
      ),
      if (comparing) const MileafProgressLine(),
      if (comparisonError != null)
        InlineBanner(
          message: '比较暂不可用：$comparisonError',
          tone: BannerTone.error,
          actionLabel: '重试比较',
          onAction: () => loadComparison(force: true),
        ),
      if (current == null)
        Text(
          '扩展统计字段缺失或不兼容，未用旧净电耗替代配对值',
          style: context.type.body.copyWith(color: context.colors.error),
        ),
      Text(
        '同批有效能量与里程配对估算；只描述差异，不推断原因。',
        style: context.type.micro.copyWith(color: context.colors.textMuted),
      ),
      ExpansionTile(
        title: const Text('比较区间与口径'),
        children: [
          if (current != null)
            _techRow(
              '本期',
              '${timestamp(current.query.from)}—${timestamp(current.query.to)}；生成 ${timestamp(current.asOf)}',
            ),
          if (prior != null)
            _techRow(
              '参照',
              '${timestamp(prior.query.from)}—${timestamp(prior.query.to)} · '
                  '${number(prior.totals.netConsumptionPaired.valueWhKm, 'Wh/km')}；生成 ${timestamp(prior.asOf)}',
            ),
          _techRow('归期时区', '$_zone；两个资源分别生成，非同时快照'),
        ],
      ),
    ]);
  }

  Widget _drivingNote() {
    if (driving == null) return const SizedBox.shrink();
    return _noteSection(
      '驾驶消耗',
      [
        _techRow(
          '估算驾驶消耗',
          number(driving!.totals.energyKwh, 'kWh', decimals: 2),
        ),
        _techRow(
          '净电耗 · 估算',
          number(driving!.totals.consumptionWhKmNet, 'Wh/km'),
        ),
        _techRow('毛电耗', number(driving!.totals.consumptionWhKmGross, 'Wh/km')),
        Text(
          '毛电耗为区间充入电池能量÷驾驶里程，受补能时点影响，不是网侧电耗；净毛差额不代表停车损耗。净电耗与驾驶消耗按续航差和车辆效率估算。',
          style: context.type.micro.copyWith(color: context.colors.textMuted),
        ),
      ],
      action: TextButton(
        onPressed: () => widget.onStatistics?.call('driving', range!.selection),
        child: const Text('驾驶统计'),
      ),
    );
  }

  Widget _chargingNote() {
    if (charging == null) return const SizedBox.shrink();
    final expanded = enhancedCharging;
    return _noteSection(
      '补能账本',
      [
        _techRow('充电次数', '${charging!.totals.sessions} 次'),
        _techRow(
          coverageAvailable ? '有效入电均价' : '已知费用均价',
          '${widget.currency.amountValue(coverageAvailable ? expanded?.totals.unitCostAdded.value : charging!.totals.costPerKwh)}/kWh',
        ),
        const SizedBox(height: MileafSpace.s8),
        _shareBar(),
        const SizedBox(height: MileafSpace.s8),
        Text(
          'AC/DC 仅含已知分类，不代表全部补能；均价仅含费用已知会话。',
          style: context.type.micro.copyWith(color: context.colors.textMuted),
        ),
      ],
      action: TextButton(
        onPressed: () =>
            widget.onStatistics?.call('charging', range!.selection),
        child: const Text('充电统计'),
      ),
    );
  }

  Widget _vehicleNote(dto.Summary d) => _noteSection('车辆与数据', [
    ExpansionTile(
      title: const Text('车辆与数据时间'),
      children: [
        _techRow('状态开始', timestamp(d.state?.since)),
        _techRow('位置采样完整时间', timestamp(d.freshness.lastPositionAt)),
        _techRow('里程表', number(d.odometerKm, 'km', decimals: 1)),
        _techRow('固件', d.firmware?.version ?? '未知'),
        _techRow('最近状态区间起始', timestamp(d.freshness.lastStateAt)),
        _techRow('校验时间', timestamp(result?.checkedAt)),
        for (final entry in results.entries)
          _techRow(
            entry.key == 'driving' ? '趋势已校验' : '补能已校验',
            timestamp(entry.value.checkedAt),
          ),
        _techRow('归期时区', _zone),
        Text(
          '旧采样或长时间休眠不等同系统故障。',
          style: context.type.micro.copyWith(color: context.colors.textMuted),
        ),
      ],
    ),
  ]);

  Widget _notesSection(dto.Summary d) => Padding(
    padding: const EdgeInsets.only(top: MileafSpace.section),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExpansionTile(
          title: const Text('数据说明与更多'),
          childrenPadding: const EdgeInsets.only(bottom: MileafSpace.s8),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (capabilityError != null)
              InlineBanner(
                message: capabilityError!,
                tone: BannerTone.warning,
                actionLabel: '重试扩展能力',
                onAction: () => loadCapabilities(force: true),
              ),
            _coverageNote(),
            _comparisonNote(),
            _drivingNote(),
            _chargingNote(),
            _vehicleNote(d),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.currency,
    builder: (context, _) {
      if (readable) {
        final owner = workspace.session.current;
        PerformanceTrace.overviewFrame(
          () =>
              mounted &&
              owner != null &&
              workspace.session.isCurrent(owner) &&
              readable &&
              chartVisible &&
              (ModalRoute.of(context)?.isCurrent ?? false),
        );
      }
      final inset = MileafLayout.pageInset(context);
      final topBar = widget.topBar;
      // Card form: the brand row is a sibling on paper, so the status bar never
      // sits over the hero; the row's own 12 bottom padding is the gap to the
      // card (Spec §6.4). Full bleed keeps it inside the hero.
      final barOnPaper = context.colors.heroAsCard ? topBar : null;
      return RefreshIndicator(
        key: viewportKey,
        onRefresh: () => load(force: true),
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ?barOnPaper,
            if (data != null)
              _hero(data!)
            else if (loading)
              _heroSkeleton()
            else
              _heroEmpty(),
            MileafPageEnter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(inset, 0, inset, MileafSpace.s24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (workspace.calendar?.fallback ?? false)
                      Padding(
                        padding: const EdgeInsets.only(top: MileafSpace.s8),
                        child: Text(
                          '无法读取设备 IANA 时区，暂按 UTC 展示与归期',
                          style: context.type.micro.copyWith(
                            color: context.colors.warning,
                          ),
                        ),
                      ),
                    if (loading && data != null) const MileafProgressLine(),
                    if (error != null && data != null)
                      InlineBanner(
                        message: error!,
                        tone: BannerTone.error,
                        actionLabel: '重试概览',
                        onAction: () => loadSummary(force: true),
                      ),
                    _periodBar(),
                    if (errors['driving'] != null)
                      InlineBanner(
                        message: errors['driving']!,
                        tone: BannerTone.error,
                        actionLabel: '重试里程趋势',
                        onAction: () => loadStats('driving', force: true),
                      ),
                    if (errors['charging'] != null)
                      InlineBanner(
                        message: errors['charging']!,
                        tone: BannerTone.error,
                        actionLabel: '重试补能',
                        onAction: () => loadStats('charging', force: true),
                      ),
                    _monthSection(),
                    _chartSection(),
                    if (data != null) _recentSection(data!),
                    _continueSection(),
                    if (data != null) _notesSection(data!),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class MetaPage extends StatefulWidget {
  const MetaPage({
    super.key,
    required this.workspace,
    this.mapConsent,
    this.mapPlatform,
  });
  final VehicleWorkspace workspace;
  final MapConsentController? mapConsent;
  final MapPlatform? mapPlatform;
  @override
  State<MetaPage> createState() => _MetaPageState();
}

class _MetaPageState extends State<MetaPage> with WidgetsBindingObserver {
  late final SiteSession? owner;
  dto.Meta? data;
  String? error;
  @override
  void initState() {
    super.initState();
    owner = widget.workspace.session.current;
    widget.workspace.session.addListener(sessionChanged);
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  void sessionChanged() {
    if (owner != null && !widget.workspace.session.isCurrent(owner!)) {
      setState(() {
        data = null;
        error = "会话已失效，请重新登录";
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      load(force: false);
    }
  }

  @override
  void dispose() {
    widget.workspace.session.removeListener(sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> load({bool force = true}) async {
    final s = widget.workspace.session.current;
    if (s == null) return;
    try {
      final r = await widget.workspace.cache.get(s, 'meta', force: force);
      final d = dto.Meta.fromJson(r.body);
      if (mounted && widget.workspace.session.isCurrent(s)) {
        setState(() => data = d);
      }
    } catch (_) {
      if (mounted) setState(() => error = '服务元信息读取失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('设置与服务')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (data == null && error == null) const LinearProgressIndicator(),
        if (error != null) ...[
          Text(error!),
          TextButton(
            onPressed: () {
              setState(() => error = null);
              load();
            },
            child: const Text('重试'),
          ),
        ],
        if (data case final d?) ...[
          Text('Mileaf Server ${d.version}'),
          Text('TeslaMate schema ${d.teslamateSchemaVersion ?? '未知'}'),
          Text(d.tested ? '此版本在服务端已测兼容范围' : '此版本未声明已测兼容；这不代表 schema 不兼容'),
          Text(d.schemaOk ? 'schema 检查正常' : 'schema 检查未通过'),
          const Text('数值使用公制；源单位不进行二次换算'),
        ],
        if (widget.mapConsent != null)
          MileafDataRow(
            title: '地图',
            meta: MapKeyScope.maybeOf(context)?.status ?? '底图供应商、同意与撤销',
            icon: MileafIconName.mapPin,
            showChevron: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => MapPrivacyPage(
                  consent: widget.mapConsent!,
                  providerName:
                      (widget.mapPlatform ?? defaultMapPlatform()).providerName,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
