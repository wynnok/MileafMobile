import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'currency.dart';
import 'copy/dates.dart' as copy;
import 'copy/durations.dart' as copy;
import 'copy/messages.dart' as messages;
import 'copy/page_actions.dart' as copy_actions;
import 'copy/terms.dart' as terms;
import 'design/components/components.dart';
import 'design/icons.dart';
import 'design/layout.dart';
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
import 'workspace.dart';
import 'reading_scope.dart';
import 'session.dart' show SiteSession;

enum _Metric { distance, net, charge, cost, energy }

/// CP07 的对象名：共享构造函数只接对象名，整句由 messages 拼。
const String _summaryObject = '车况';
const String _drivingObject = '驾驶数据';
const String _chargingObject = '充电数据';

/// 本页重复使用的短文案：集中声明，避免同一句话在页面里各写一份。
const String _unknown = '未知';
const String _retry = '重试';
const String _switchMetric = '可切换其他指标';
const String _staleSuffix = '，显示的是上次的数据';
const String _emptyWindow = '本期还没有可统计的时间，稍后再刷新';

/// 页面重排阈值：正文基值 14 在 100% 字号下恰为 14；留 0.5 的浮点余量，
/// 只要用户把字号调大就重排（R11/R21.5），而不是把单位或新鲜度截断。
const double _reflowScaleFloor = 14.5;

/// R21.5：车况卡三格一行时，每格至少要 80 才能同时放下数值与单位。
/// 实测：320 宽卡内可用 248 → 每格 74.7，MileafNumber 会把「kWh」裁掉；
/// 360 宽可用 288 → 每格 88，单位完整。低于 80 就先收成两列。
const double _heroCellMinWidth = 80;

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
    with
        WidgetsBindingObserver,
        ReadingLifecycle<OverviewPage>,
        CostAwareReading<OverviewPage> {
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
  DateTime? chartSelectionAt;
  final plotKey = GlobalKey();
  final chartKey = GlobalKey();
  final viewportKey = GlobalKey();
  @override
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
        setState(() => capabilityError = '部分新数据暂不可用，已按基础数据显示');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    initCostReading();
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
    // A covered or hidden page keeps its snapshot and consumes the revision
    // when it is visible again; it must not report this deferral as updated.
    if (!readingVisible) {
      deferCost();
      return false;
    }
    final refreshed = await _refreshCostData();
    if (refreshed) consumeCost();
    return refreshed;
  }

  Future<bool> _refreshCostData() async {
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
    if (readingVisible && state == AppLifecycleState.resumed) {
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

  @override
  Future<void> resumeReading() => foreground();

  Future<void> foreground() async {
    await workspace.foreground();
    if (!mounted || !readingPresent) return;
    if (costPending) {
      await load(force: true);
      if (mounted && error == null && errors.isEmpty) consumeCost();
      return;
    }
    await load();
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
      setState(() => errors['driving'] = _emptyWindow);
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
              ? messages.versionIncompatibleMessage()
              : '${e is ApiFailure ? e.message : messages.readFailedMessage(_summaryObject)}'
                    '${data == null ? '' : _staleSuffix}',
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
      setState(() => errors[kind] = _emptyWindow);
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
            ? messages.versionIncompatibleMessage()
            : '${e is ApiFailure ? e.message : messages.readFailedMessage(kind == 'driving' ? _drivingObject : _chargingObject)}'
                  '${results[kind] == null ? '' : _staleSuffix}',
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
    // A current driving request may finish after the reader changes tabs.
    // The visible return path revalidates this resource through loadStats.
    if (!readingVisible) return;
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
      ? _unknown
      : workspace.calendar!.local(time).toString().split('.').first;

  /// CP04「页面不得自拼」：记录行的时间走共享格式化器（DF5 + DF1）。
  String _shortStamp(DateTime? time) {
    if (time == null) return '未知时间';
    return copy.formatDayTime(workspace.calendar!.local(time), _todayWall);
  }

  String number(num? value, String unit, {int decimals = 0}) =>
      value == null ? '—' : '${grouped(value, decimals: decimals)} $unit';

  String get _zone => workspace.calendar?.identifier ?? 'UTC';

  /// CP02 比较对象名称：名称必须与源码里实际的比较窗口一致。
  /// 概览只有「本月 / 近7天」两个期间；AP06 核对表把 recent 的比较窗口定为前 7 天。
  String get _compareName => terms.compareNameFor(period.name) ?? '上月同期';

  bool get _referenceValid =>
      comparison != null &&
      identical(comparisonRange, ranges['driving']) &&
      comparisonError == null &&
      driving != null &&
      comparison!.buckets.length == driving!.buckets.length;

  String get _stateLabel => switch (data?.state?.value) {
    'online' => '在线',
    'asleep' => '休眠',
    'offline' => '离线',
    'charging' => '充电中',
    _ => '状态未知',
  };

  // P01/R13: both appearances share the same compact content surface.
  Widget _statusSurface(Widget child) => MileafContent(
    padding: MileafLayout.pageHorizontal(context),
    child: Material(
      key: const ValueKey('overview-status'),
      color: context.colors.hero,
      borderRadius: BorderRadius.circular(MileafRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: child,
    ),
  );

  Widget _hero(dto.Summary d) {
    final colors = context.colors;
    final type = context.type;
    final large = MileafLayout.largeText(context);
    // 字号一变大（>100%）就把状态行与今日三项改成可折的排版：R21.5 要求先收列，
    // 而不是把单位或新鲜度截断成「11....」「今天 19:…」。
    final reflow =
        large || MediaQuery.textScalerOf(context).scale(14) > _reflowScaleFloor;
    final charging = d.state?.value == 'charging';
    final since = d.state?.since;
    // P01：状态用图形 + 文字（不再用圆点），充电功率独立成段，不用「·」拼接。
    final statusKind = charging
        ? VehicleStatusKind.charging
        : switch (d.state?.value) {
            'asleep' => VehicleStatusKind.sleeping,
            'offline' => VehicleStatusKind.offline,
            _ => null,
          };
    final statusColor = charging ? colors.accentHero : colors.heroMuted;
    final statusText = _stateLabel;
    // 数据陈旧与否由状态行尾的新鲜度读法（DF7/DF5）承载，不再另起一行重复。
    final power = charging && d.chargingPowerKw != null
        ? '${d.chargingPowerKw!.toStringAsFixed(1)} kW'
        : null;
    final ago = since == null
        ? null
        : copy.formatRelative(
            workspace.calendar!.local(since),
            workspace.calendar!.local(workspace.session.now()),
          );
    // 状态行的四个部件只建一次：100% 时排成一行，大字时新鲜度换行（见下）。
    final glyph = statusKind == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(top: MileafSpace.inline2),
            child: MileafIcon(
              vehicleStatusIcon(statusKind),
              size: MileafIconMetrics.nav,
              color: statusColor,
            ),
          );
    final statusWidget = Text(
      statusText,
      style: type.subheadline.copyWith(color: colors.heroMuted),
    );
    final powerWidget = power == null
        ? null
        : Text(
            power,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: type.subheadline.copyWith(color: colors.heroText),
          );
    final agoWidget = ago == null
        ? null
        : Text(
            ago,
            maxLines: 1,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: type.footnote.copyWith(color: colors.heroFaint),
          );
    final rangeLabel = switch (d.battery?.rangeKind) {
      'rated' => '额定续航',
      'ideal' => '理想续航',
      _ => '续航口径未知',
    };
    final range = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (d.battery?.rangeKm == null)
          Text('— 暂无续航', style: type.metricMd.copyWith(color: colors.heroText))
        else
          MileafNumber(
            value: d.battery?.rangeKm?.toStringAsFixed(0),
            unit: 'km',
            scale: MetricValueScale.display,
            onHero: true,
          ),
        const SizedBox(height: MileafSpace.s4),
        Text(
          '$rangeLabel，非实时',
          style: type.subheadline.copyWith(color: colors.heroMuted),
        ),
      ],
    );
    final arc = d.battery?.level == null
        ? Text('电量未知', style: type.footnote.copyWith(color: colors.heroMuted))
        : BatteryArc(
            level: d.battery?.level,
            onHero: true,
            size: large
                ? MileafBatteryMetrics.largeTextSize
                : MileafBatteryMetrics.size,
          );
    final today = d.period.today;
    // R21.5：三列网格只用 metricSm。车况卡的三项都是短值，100% 时一行三格；
    // 大字按 R11 重排成一列（MetricGrid 在 150% 起收单列）。
    final cells = [
      MetricBlock(
        label: '今日里程',
        value: today.distanceKm.toStringAsFixed(1),
        unit: 'km',
        onHero: true,
        scale: MetricValueScale.metricSm,
      ),
      MetricBlock(
        label: terms.trip,
        value: '${today.drives}',
        unit: terms.tripCount,
        onHero: true,
        scale: MetricValueScale.metricSm,
      ),
      MetricBlock(
        label: terms.estimatedConsumption,
        value: today.energyKwh?.toStringAsFixed(2),
        unit: today.energyKwh == null ? null : 'kWh',
        onHero: true,
        scale: MetricValueScale.metricSm,
      ),
    ];
    // R21.5：100% 时一行三格；字号一变大就交给 MetricGrid 先收两列、再收一列。
    // 直接用 Row 三格时，宽格下的 MileafNumber 只能把单位裁掉（AU09 的变体）。
    final stats = LayoutBuilder(
      builder: (context, constraints) {
        final fits =
            constraints.maxWidth >=
            _heroCellMinWidth * cells.length +
                MileafSpace.s12 * (cells.length - 1);
        return reflow || !fits
            ? MetricGrid(columns: 3, children: cells)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final cell in cells) Expanded(child: cell)],
              );
      },
    );
    return _statusSurface(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              MileafSpace.s16,
              MileafSpace.s12,
              MileafSpace.s16,
              MileafSpace.s12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // R31/R26：状态、功率、新鲜度是三件事，不用「·」拼接。大字时
                // 新鲜度换到下一行，避免 200% 下三项被打成「充电 中 / 11.... / 今天 …」。
                if (reflow)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (glyph != null) ...[
                            glyph,
                            const SizedBox(width: MileafSpace.s8),
                          ],
                          Expanded(child: statusWidget),
                          if (powerWidget != null) ...[
                            const SizedBox(width: MileafSpace.s8),
                            powerWidget,
                          ],
                        ],
                      ),
                      if (agoWidget != null) ...[
                        const SizedBox(height: MileafSpace.s4),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: agoWidget,
                        ),
                      ],
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (glyph != null) ...[
                        glyph,
                        const SizedBox(width: MileafSpace.s8),
                      ],
                      Expanded(child: statusWidget),
                      if (powerWidget != null) ...[
                        const SizedBox(width: MileafSpace.s8),
                        Flexible(child: powerWidget),
                      ],
                      if (agoWidget != null) ...[
                        const SizedBox(width: MileafSpace.s8),
                        Flexible(child: agoWidget),
                      ],
                    ],
                  ),
                const SizedBox(height: MileafSpace.s4),
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
                const SizedBox(height: MileafSpace.s8),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: colors.heroText.withValues(alpha: .12),
                ),
                const SizedBox(height: MileafSpace.s8),
                stats,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroSkeleton() => _statusSurface(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            MileafSpace.s16,
            MileafSpace.s12,
            MileafSpace.s16,
            MileafSpace.s12,
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
    return _statusSurface(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StateView(
            kind: retryable ? StateViewKind.error : StateViewKind.empty,
            onHero: true,
            title: retryable ? '车况暂不可用' : '暂无车况',
            message: error ?? '下拉刷新或检查站点连接',
            actionLabel: _retry,
            actionSemanticLabel: copy_actions.retryVehicleStatus,
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
    child: MileafPeriodRow(
      trailing: MileafIconButton(
        icon: MileafIconName.refresh,
        tooltip: '刷新概览',
        fill: MileafIconButtonFill.track,
        onPressed: loading ? null : () => loadSummary(force: true),
      ),
      children: [
        StatusChip(
          label: '本月',
          selected: period == OverviewPeriod.month,
          onTap: () {
            if (period != OverviewPeriod.month) {
              chartSelection = null;
              chartSelectionAt = null;
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
              chartSelectionAt = null;
              changePeriod(OverviewPeriod.recent);
            }
          },
        ),
      ],
    ),
  );

  ({String text, String? label, bool? up})? get _mileageDelta {
    final requested = ranges['driving'];
    final current = driving?.totals.distanceKm;
    if (requested == null || current == null) return null;
    final window = _compareName;
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

  /// P01 焦点模块卡：期间主值（固定为驾驶里程）→ 一句比较 → 分段与图。
  /// 区间只在这里出现一次（R21.4）；卡片标题用 headline，主值 metricLg。
  Widget _focusCard() {
    final value = driving?.totals.distanceKm;
    final parts = value == null ? '—' : grouped(value, decimals: 1);
    final drives = driving?.totals.drives;
    final label = period == OverviewPeriod.month ? '本月驾驶' : '近 7 天驾驶';
    final window = _dayRange(ranges['driving']?.current);
    final semantic =
        '$label $parts 公里，${drives ?? '—'} ${terms.tripCount}，'
        '${_deltaSentence ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.s16),
      child: MileafModuleCard(
        // §6 退让阶梯第 2 步：焦点卡内边 16 → 12，为首屏预算腾出 8。
        padding: const EdgeInsets.all(MileafSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 320 宽 200% 时卡头一行放不下期间名与区间：大字改两行（R21.4 仍只出现一次）。
            if (MileafLayout.largeText(context)) ...[
              Text(
                label,
                style: context.type.headline.copyWith(
                  color: context.colors.text,
                ),
              ),
              if (window != null) ...[
                const SizedBox(height: MileafSpace.s4),
                Text(
                  window,
                  style: context.type.subheadline.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: context.type.headline.copyWith(
                        color: context.colors.text,
                      ),
                    ),
                  ),
                  if (window != null) ...[
                    const SizedBox(width: MileafSpace.s8),
                    Flexible(
                      child: Text(
                        window,
                        style: context.type.subheadline.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: MileafSpace.s4),
            MetricBlock(
              semanticLabel: semantic,
              value: value == null ? null : parts,
              unit: 'km',
              scale: MetricValueScale.metricLg,
            ),
            if (_deltaSentence case final delta?) ...[
              const SizedBox(height: MileafSpace.s4),
              Text(
                delta,
                style: context.type.subheadline.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: MileafSpace.s16),
            mainChart(),
          ],
        ),
      ),
    );
  }

  /// DF3 区间（本地日历）：只在期间卡标签出现一次。
  String? _dayRange(StatisticsWindow? window) {
    final calendar = workspace.calendar;
    if (window == null || calendar == null) return null;
    return copy.formatRange(
      calendar.local(window.from),
      calendar.local(window.to.subtract(const Duration(microseconds: 1))),
    );
  }

  /// 一句比较（CP03 用「多/少/持平」写进句子里，不用箭头）。
  String? get _deltaSentence {
    final delta = _mileageDelta;
    final name = _compareName;
    if (delta == null) return '$name数据不足，暂不比较';
    if (delta.text == '读取参照中') return '正在读取$name';
    if (delta.text == '参照暂不可用') return '暂时无法比较';
    if (delta.text == '基期为 0') return '$name为 0，无法比较';
    if (delta.text == '持平') return '与$name持平';
    if (delta.up == true) return '比$name多 ${delta.text}';
    if (delta.up == false) return '比$name少 ${delta.text}';
    return null;
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

  /// 入参是已按站点日历本地化的墙钟时间（tick 与读数头共用同一份）。
  /// CP04：日期串由共享格式化器给出（DF1），页面不自拼。
  String tickLabelAt(List<DateTime> times, int index) {
    if (index < 0 || index >= times.length) return '—';
    return copy.formatDay(times[index], _todayWall);
  }

  /// 站点日历里的「今天」（墙钟），共享格式化器用它判断今年与今天/昨天。
  DateTime get _todayWall => workspace.calendar!.local(workspace.session.now());

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
    if (source == null) {
      final kind = isCharging ? 'charging' : 'driving';
      final failure = errors[kind];
      // R29「无数据」与 R31「失败」是两件事：没有返回过统计就不该冒充错误，
      // 空期间只写一句空态、收起绘图区。失败时上方已有一条带「重试」的状态条。
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _metricTabs(),
          const SizedBox(height: MileafSpace.s8),
          if (pending.contains(kind))
            const SkeletonBlock(
              width: double.infinity,
              height: MileafSpace.chartHeight,
            )
          else if (failure != null)
            // R21.4：原因只在上方状态条出现一次，卡内只留对象与去路。
            StateView(
              kind: StateViewKind.error,
              title: isCharging ? _chargingObject : _drivingObject,
              message: _switchMetric,
            )
          else
            StateView(
              kind: StateViewKind.empty,
              title: messages.emptyMessage(isCharging ? '充电记录' : terms.trip),
              message: _switchMetric,
            ),
        ],
      );
    }
    final (title, unit) = switch (metric) {
      _Metric.distance => ('每日里程', 'km'),
      _Metric.net => ('每日电耗（估算）', 'Wh/km'),
      _Metric.energy => ('每日估算耗电', 'kWh'),
      _Metric.charge => ('每日充电量', 'kWh'),
      _Metric.cost => ('每日已记录费用', widget.currency.code ?? '币种未记录'),
    };
    final values = _currentValues();
    final reference = _referenceValues();
    final times = chartTimes;
    // AP05 的 TimeSeriesChart 以「本地墙钟」格式化日期（charts.dart 的
    // chartAxisTickLabels/_pointDate）；服务端 bucket_start 是 UTC 瞬时，
    // 直接传入会让读数头与 X 轴比站点日历早一天（R29 唯一接缝）。
    final wallTimes = [
      for (final time in times) workspace.calendar!.local(time),
    ];
    final selected = _selectedChartPoint(times, values);
    _PointReading point(int index) {
      final raw = index < values.length ? values[index] : null;
      final stamp = tickLabelAt(wallTimes, index);
      final isCost = metric == _Metric.cost;
      final decimals = metric == _Metric.net ? 0 : 1;
      String text(num value) => isCost
          ? widget.currency.amountValue(value)
          : value.toStringAsFixed(decimals);
      String amount(num value) => isCost ? text(value) : '${text(value)} $unit';
      final valueText = raw == null ? '—' : text(raw);
      final unitText = raw == null || isCost ? null : unit;
      var semantic = '$stamp，$valueText${unitText == null ? '' : ' $unitText'}';
      final previous = reference?.elementAtOrNull(index);
      String? referenceText, deltaText, note;
      if (raw != null && previous != null) {
        final label = _compareName;
        final comparable =
            metric != _Metric.net ||
            (pairedAvailable &&
                results['driving'] != null &&
                comparisonResult != null &&
                canCompare(
                  results['driving']!.body,
                  comparisonResult!.body,
                  workspace.calendar!,
                  period == OverviewPeriod.month
                      ? StatisticsPeriod.month
                      : StatisticsPeriod.custom,
                ));
        final range = _dayRange(comparisonRange?.previous);
        referenceText = range == null
            ? '$label ${amount(previous)}'
            : '$label $range，${amount(previous)}';
        final referenceSemantic = '${range ?? label} ${amount(previous)}';
        if (!comparable) {
          note = '数据口径未确认，暂不比较';
          semantic = '$semantic\n$referenceSemantic\n$note';
        } else {
          // CP03/CP11：差异写进句子里说「多 / 少」，不用「差 +」这种符号写法。
          deltaText = raw >= previous
              ? '多 ${amount(raw - previous)}'
              : '少 ${amount(previous - raw)}';
          semantic = '$semantic\n$referenceSemantic\n$deltaText';
        }
      }
      return _PointReading(
        day: stamp,
        value: valueText,
        unit: unitText,
        delta: deltaText,
        reference: referenceText,
        note: note,
        semantic: semantic,
      );
    }

    return TimeSeriesChart(
      key: chartKey,
      plotKey: plotKey,
      showYAxis: true,
      title: title,
      unit: unit,
      // R29：无数据时卡内只留一句人话，绘图区收起（CP02：不再出现「采样点」）。
      emptyMessage: messages.emptyMessage(isCharging ? '充电记录' : terms.trip),
      times: wallTimes,
      semanticsLabel: '$title图表',
      series: [
        ChartSeries(
          label: switch (metric) {
            _Metric.distance => '里程',
            _Metric.net => '本期',
            _Metric.charge => terms.charging,
            _Metric.cost => '费用',
            _Metric.energy => terms.estimatedConsumption,
          },
          values: values,
          style: switch (metric) {
            _Metric.distance => ChartSeriesStyle.bars,
            _Metric.net || _Metric.energy => ChartSeriesStyle.line,
            _ => ChartSeriesStyle.bars,
          },
        ),
        if (reference != null)
          ChartSeries(
            label: _referenceLabel,
            values: reference,
            style: ChartSeriesStyle.reference,
          ),
      ],
      selectedIndex: selected,
      onSelected: (index) => setState(() {
        chartSelection = index;
        chartSelectionAt = index < times.length ? times[index] : null;
      }),
      // R29：读数头在绘图区之上，日期/数值/参照差分行各归其位；句子仍是
      // 唯一朗读来源（live region），页面不再自排读数块。
      readout: (index) => point(index).semantic,
      controls: _metricTabs(),
      note: metric == _Metric.cost ? '未记录的费用不等于免费。' : null,
    );
  }

  /// R29 图例的参照名：比较对象名称 + 真实区间（DF3）。
  String get _referenceLabel {
    final name = _compareName;
    final range = _dayRange(comparisonRange?.previous);
    return range == null ? name : '$name $range';
  }

  /// Keeps a deliberate point by its bucket date. When the calendar window
  /// shifts, the same date moves to another index; when that date is gone the
  /// point falls back to the nearest earlier bucket that still exists.
  int _selectedChartPoint(List<DateTime> times, List<num?> values) {
    final exact = bucketIndexAt(times, chartSelectionAt);
    if (exact != null) return exact;
    final touched = chartSelection;
    if (touched != null && times.isNotEmpty) {
      return touched.clamp(0, times.length - 1);
    }
    final last = values.lastIndexWhere((v) => v != null && v > 0);
    return last < 0 ? 0 : last;
  }

  Widget _metricTabs() => ChipRow(
    equalWidth: true,
    children: [
      for (final (m, label) in [
        (_Metric.distance, '里程'),
        (_Metric.net, terms.energyPerKm),
        (_Metric.charge, terms.charging),
        (_Metric.cost, '费用'),
      ])
        StatusChip(
          label: label,
          selected: metric == m,
          onTap: () => setState(() {
            metric = m;
            chartSelection = null;
            chartSelectionAt = null;
          }),
        ),
    ],
  );

  /// One cell of the period ledger. The label is spelled out because the
  /// shared default stops at the value and would drop the currency caveat,
  /// which is part of the number's meaning here.
  Widget _readingCell(
    String label, {
    Key? key,
    String? value,
    String? unit,
    String? note,
  }) => MetricBlock(
    key: key,
    label: label,
    value: value,
    unit: unit,
    note: note,
    scale: MetricValueScale.metricMd,
    semanticLabel:
        '$label ${value ?? '—'}${unit == null ? '' : ' $unit'}'
        '${note == null ? '' : '，$note'}',
  );

  /// Period totals stay a ledger: one hairline, a quiet caption, four cells on
  /// the shared grid, and the caveats as a single closing paragraph instead of
  /// interleaved lines. The cost coverage sits on the cost cell, because it is
  /// that number's limitation, not a page-level footnote.
  Widget _readingPlate() {
    final colors = context.colors;
    final type = context.type;
    final paired = enhancedDriving(results['driving']);
    final net = pairedAvailable
        ? paired?.totals.netConsumptionPaired.valueWhKm
        : driving?.totals.consumptionWhKmNet;
    final expanded = enhancedCharging;
    final cost = expanded?.totals.cost ?? charging?.totals.cost;
    final coverage = _costCoverage;
    final energy = charging?.totals.energyAddedKwh;
    final costNote = [widget.currency.amountNote, coverage].nonNulls.join('，');
    final cells = [
      _readingCell(
        terms.energyPerKm,
        key: const ValueKey('overview-plate-net'),
        value: net?.toStringAsFixed(0),
        unit: net == null ? null : 'Wh/km',
      ),
      _readingCell(
        terms.recordedCost,
        key: const ValueKey('overview-plate-cost'),
        value: cost == null ? null : widget.currency.amountValue(cost),
        note: costNote,
      ),
      _readingCell(
        terms.charging,
        key: const ValueKey('overview-plate-energy'),
        value: energy == null ? null : grouped(energy, decimals: 2),
        unit: energy == null ? null : 'kWh',
      ),
      _readingCell(
        terms.trip,
        key: const ValueKey('overview-plate-drives'),
        value: driving?.totals.drives.toString(),
        unit: driving == null ? null : terms.tripCount,
      ),
    ];
    return Padding(
      key: const ValueKey('overview-reading-plate'),
      padding: const EdgeInsets.only(top: MileafSpace.s32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: '本期账目'),
          const SizedBox(height: MileafSpace.s8),
          MileafGroupCard(
            padding: const EdgeInsets.all(MileafSpace.cardPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // R21.5：两列网格可用 metricMd。
                MetricGrid(columns: 2, children: cells),
                const SizedBox(height: MileafSpace.s12),
                Text(
                  '未记录的费用不等于免费；电耗和耗电为估算值。',
                  style: type.footnote.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
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
    }) => MileafDataRow(
      title: title,
      meta: meta,
      value: value,
      unit: unit,
      icon: icon,
      showChevron: onTap != null,
      onTap: onTap,
      semanticLabel:
          '$title，$meta${value == null ? '' : '，$value${unit == null ? '' : ' $unit'}'}',
    );
    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: '最近记录'),
          const SizedBox(height: MileafSpace.s8),
          _rowCard([
            row(
              title: '最近行程',
              meta: drive == null
                  ? '这段时间还没有行程'
                  : '${_shortStamp(drive.startedAt)}\n'
                        '电耗 ${number(drive.consumptionWhKm, 'Wh/km')}',
              value: drive?.distanceKm?.toStringAsFixed(1),
              unit: drive?.distanceKm == null ? null : 'km',
              icon: MileafIconName.route,
              onTap: drive == null
                  ? null
                  : () => widget.onRecord?.call('drive', drive.id),
            ),
            row(
              title: '最近充电',
              meta: charge == null
                  ? '还没有充电记录'
                  : '${_shortStamp(charge.startedAt)}\n'
                        '充入 ${number(charge.energyKwh, 'kWh', decimals: 2)}',
              value: charge?.endSoc?.toStringAsFixed(0),
              unit: charge?.endSoc == null ? null : '%',
              icon: MileafIconName.bolt,
              onTap: charge == null
                  ? null
                  : () => widget.onRecord?.call('charging', charge.id),
            ),
          ]),
        ],
      ),
    );
  }

  /// P01 统一内容网格（R24「两条起始线」）：开放行收进分组卡，行内横向内边
  /// 统一 16；发丝线只画在行与行之间，从卡内 16 一直到卡片右缘，首行之上与
  /// 末行之下不画线。这样画布层标题在页面边距、卡内文字在页面边距 + 16，
  /// 不再有第三套左缘。
  Widget _rowCard(List<Widget> rows) => MileafGroupCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0) _hairline(),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MileafSpace.cardPad,
            ),
            child: rows[index],
          ),
        ],
      ],
    ),
  );

  /// R24 分隔线：一物理像素，从行内文字起始处（卡内 16）到卡片右缘。
  Widget _hairline() => Container(
    height: 0,
    margin: const EdgeInsets.only(left: MileafSpace.cardPad),
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(
          color: context.colors.line,
          width: MileafStroke.hairline,
        ),
      ),
    ),
  );

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
    }) => MileafDataRow(
      title: title,
      meta: meta,
      icon: icon,
      showChevron: true,
      onTap: () => open(topic),
    );
    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: '用车专题'),
          const SizedBox(height: MileafSpace.s8),
          _rowCard([
            row(
              title: '节奏',
              meta: '驾驶时间与单程',
              icon: MileafIconName.clock,
              topic: 'usage',
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
            ),
          ]),
        ],
      ),
    );
  }

  void _showComparisonBasis(
    stats.DrivingMetrics? current,
    stats.DrivingMetrics? prior,
    OverviewWindow? pairedRange,
  ) {
    showMileafSheet<void>(
      context: context,
      title: '对比明细',
      builder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _basisRow('本期', number(current?.consumptionWhKmNet, 'Wh/km')),
          _basisRow('对比', number(prior?.consumptionWhKmNet, 'Wh/km')),
          if (pairedRange?.current case final window?)
            _basisRow('本期时间', _dayRange(window) ?? '—'),
          if (pairedRange?.previous case final window?)
            _basisRow('对比时间', _dayRange(window) ?? '—'),
          _basisRow('统计时区', _zone),
          const SizedBox(height: MileafSpace.s12),
          Text(
            '同车、同一时区、同一本地截止时刻。电耗按续航差和车辆效率估算，部分能量样本可能缺失；'
            '只描述数值差异，不推断原因。对比为零或缺失时不输出比较结论。',
            style: context.type.footnote.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _basisRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: MileafSpace.s8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: context.type.subheadline.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: MileafSpace.s12),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: context.type.body.copyWith(color: context.colors.text),
          ),
        ),
      ],
    ),
  );

  Widget _notesSection(dto.Summary? d) => Padding(
    padding: const EdgeInsets.only(top: MileafSpace.section),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _comparisonSection(),
        if (driving != null) const SizedBox(height: MileafSpace.section),
        MileafDataNotes(groups: _dataNotes(d)),
        _statisticsDrills(),
      ],
    ),
  );

  /// 页尾下钻（CP06 页尾文字按钮）：概览期间直接打开驾驶/充电统计，
  /// 沿既有回调 onStatistics 与 StatisticsSelection，路由与参数不变。
  Widget _statisticsDrills() {
    final selection = ranges['driving']?.selection;
    Widget drill(String kind, String label) => TextButton(
      onPressed: selection == null
          ? null
          : () => widget.onStatistics?.call(kind, selection),
      child: Text(label),
    );
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: MileafSpace.s8,
        runSpacing: MileafSpace.s4,
        children: [drill('driving', '驾驶统计'), drill('charging', '充电统计')],
      ),
    );
  }

  /// 参照数据是否满足 canCompare：不足或口径未确认时既不算差值也不造句。
  bool get _comparisonComparable {
    final base = results['driving'];
    final other = comparisonResult;
    if (base == null || other == null) return false;
    // 形状不全时：站点没声明配对能力就沿原行为按服务端净电耗比较；
    // 声明了配对却缺字段则判不可比，不把旧净电耗当配对值（CP08）。
    // canCompare 走 insights 契约解析，形状不全时解析会抛，故先判形状。
    if (base.body['query'] is! Map || other.body['query'] is! Map) {
      return !pairedAvailable;
    }
    try {
      return canCompare(
        base.body,
        other.body,
        workspace.calendar!,
        period == OverviewPeriod.month
            ? StatisticsPeriod.month
            : StatisticsPeriod.custom,
      );
    } on FormatException {
      return false;
    }
  }

  /// P01「电耗对比」：一句差异 + 查看对比明细（原来的「一条有参照的变化」）。
  Widget _comparisonSection() {
    if (driving == null) return const SizedBox.shrink();
    final current = (comparisonDriving ?? driving)?.totals;
    final prior = comparison?.totals;
    final pairedRange = comparisonRange ?? ranges['driving'];
    String message;
    if (ranges['driving']?.previous == null) {
      message = '这段时间没有可对齐的比较时间，暂不比较';
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
    } else if (!_comparisonComparable) {
      // 参照口径不可比时不造句，和图表读数头用同一句口径说明（CP02、CP11）。
      message = '数据口径未确认，暂不比较';
    } else {
      final delta = current.consumptionWhKmNet! - prior.consumptionWhKmNet!;
      final name = _compareName;
      message = delta != 0 && delta.abs() < 1
          ? '电耗与$name差异小于 1 Wh/km'
          : delta == 0
          ? '电耗与$name相同'
          : '电耗比$name${delta < 0 ? '低' : '高'} ${delta.abs().toStringAsFixed(0)} Wh/km';
    }
    // 与「关于这些数据」同一容器语法：区块标题在画布层（页面边距），
    // 内容进一张分组卡（卡内 16），动作是卡内的一行导航行，不再用一个
    // 悬浮的 ghost 按钮在卡里再套一层容器。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: '电耗对比'),
        const SizedBox(height: MileafSpace.s8),
        MileafGroupCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MileafSpace.cardPad,
                  MileafSpace.cardPad,
                  MileafSpace.cardPad,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      message,
                      style: context.type.body.copyWith(
                        color: context.colors.text,
                      ),
                    ),
                    if (comparing)
                      const Padding(
                        padding: EdgeInsets.only(top: MileafSpace.s8),
                        child: MileafProgressLine(),
                      ),
                    if (comparisonError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: MileafSpace.s8),
                        child: InlineBanner(
                          message: '比较暂不可用：$comparisonError',
                          tone: BannerTone.error,
                          actionLabel: _retry,
                          actionSemanticLabel: copy_actions.retryComparison,
                          onAction: () => loadComparison(force: true),
                        ),
                      ),
                  ],
                ),
              ),
              MileafGroupRow(
                title: '查看对比明细',
                trailing: MileafIcon(
                  MileafIconName.chevron,
                  size: MileafIconMetrics.inline,
                  color: context.colors.textFaint,
                ),
                topLine: true,
                onTap: () => _showComparisonBasis(current, prior, pairedRange),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// R30.2「关于这些数据」五类：口径与估算、记录与缺失、时间与时区、
  /// 来源与生成时间、技术详情。缺类不出现；技术详情可复制（R30.4）。
  List<MileafDataNoteGroup> _dataNotes(dto.Summary? d) {
    final paired = enhancedDriving(results['driving']);
    final net = pairedAvailable
        ? paired?.totals.netConsumptionPaired.valueWhKm
        : driving?.totals.consumptionWhKmNet;
    final coverage = _costCoverage;
    final current = _dayRange(ranges['driving']?.current);
    final prior = _dayRange(comparisonRange?.previous);
    final notes = <MileafDataNoteGroup>[
      MileafDataNoteGroup(
        category: DataNoteCategory.caliber,
        note: [
          '电耗与估算耗电按续航差和车辆效率估算。',
          if (driving != null) '毛电耗为区间充入电池能量÷驾驶里程，受补能时点影响，不是网侧电耗。',
          if (charging != null) '未记录的费用不等于免费。',
          if (charging != null) 'AC/DC 仅含已知分类，不代表全部充电；充入均价按充入电池的电量计，仅含有费用的充电。',
          '估算结果只描述数值差异，不推断原因。',
        ].join(''),
      ),
      MileafDataNoteGroup(
        category: DataNoteCategory.records,
        note: [
          if (net != null) '有效行程电耗 ${number(net, 'Wh/km')}。',
          if (paired?.totals.drivingCoverage.durationKnownMin
              case final minutes?)
            '有记录的驾驶时长 '
                '${copy.duration(Duration(minutes: minutes.round()))}，'
                '${paired?.totals.drivingCoverage.durationKnownDrives ?? '—'} 趟有记录。',
          if (coverage != null) '费用记录：$coverage，对应充入 $_costCoverageEnergy kWh。',
          ?_chargingSplitNote,
          if (driving != null) '缺失显示 —，未知不等于 0。',
        ].join(''),
      ),
      MileafDataNoteGroup(
        category: DataNoteCategory.time,
        note: [
          '统计时区 $_zone。',
          if (current != null) '本期时间 $current。',
          if (prior != null) '对比时间 $prior。',
        ].join(''),
      ),
      MileafDataNoteGroup(
        category: DataNoteCategory.source,
        note: [
          '数据生成于 ${timestamp(result?.checkedAt)}。',
          '本期与对比分别生成，非同时快照。',
        ].join(''),
      ),
      MileafDataNoteGroup(
        category: DataNoteCategory.technical,
        copyable: true,
        note: [
          if (d != null) ...[
            // CP02 对照表：车辆与数据 → 车辆信息；位置采样完整时间 → 位置数据时间；
            // 最近状态区间起始 → 状态开始时间；校验时间 → 数据生成时间。
            '车辆信息 ${d.vehicle.name}，${d.vehicle.model}，尾号 ${d.vehicle.vinSuffix}',
            // R30.3 内容不删：当前状态段的起始时刻与 freshness.last_state_at 是两个
            // 不同的原始值（fixture 里相差 12 小时），各占一行。
            '当前状态起始 ${_precise(d.state?.since)}',
            '位置数据时间 ${_precise(d.freshness.lastPositionAt)}',
            '状态开始时间 ${_precise(d.freshness.lastStateAt)}',
            '里程表 ${number(d.odometerKm, 'km', decimals: 1)}',
            '固件 ${d.firmware?.version ?? _unknown}',
          ],
          '数据生成时间 ${_precise(result?.checkedAt)}',
          if (ranges['driving']?.current case final window?)
            '本期 ${_precise(window.from)}–${_precise(window.to)}',
          if (comparisonRange?.previous case final window?)
            '对比 ${_precise(window.from)}–${_precise(window.to)}',
          '统计时区 $_zone',
        ].join('\n'),
      ),
    ];
    return notes;
  }

  /// CP02 费用记录覆盖：「9 次中 8 次有费用」。能力不全或没有充电时为空。
  String? get _costCoverage {
    final expanded = enhancedCharging;
    if (expanded == null || expanded.totals.sessions == 0) return null;
    return '${expanded.totals.sessions} 次中 '
        '${expanded.totals.costKnownSessions} 次有费用';
  }

  /// 有费用的那些充电对应的充入电量（CP02：「对应充入 214 kWh」）。
  String get _costCoverageEnergy =>
      grouped(enhancedCharging?.totals.costKnownEnergyKwh ?? 0, decimals: 2);

  /// 补能分类与均价的原值（P01 把旧「补能账本」表格迁入这里，数值不丢）。
  String? get _chargingSplitNote {
    final totals = charging?.totals;
    if (totals == null) return null;
    final unknown = enhancedCharging?.totals.unknownEnergyKwh;
    String amount(num? value) =>
        value == null ? '—' : '${value.toStringAsFixed(2)} kWh';
    // CP03：% 紧贴数值；CP02：这一段就是说明层里的「充电账目」。
    final share = totals.dcEnergyShare == null
        ? '—'
        : '${(totals.dcEnergyShare! * 100).toStringAsFixed(1)}%';
    final unitCost = coverageAvailable
        ? enhancedCharging?.totals.unitCostAdded.value
        : charging!.totals.costPerKwh;
    return [
      '充电账目：AC ${amount(totals.acEnergyKwh)}',
      'DC ${amount(totals.dcEnergyKwh)}',
      '未知 ${amount(unknown)}',
      'DC 占已知分类能量 $share',
      if (unitCost != null)
        '${terms.averagePrice} ${widget.currency.amountValue(unitCost)}/kWh',
    ].join('，');
  }

  String _precise(DateTime? time) => time == null
      ? _unknown
      : copy.formatPrecise(workspace.calendar!.local(time));

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
      return RefreshIndicator(
        key: viewportKey,
        onRefresh: () => load(force: true),
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (topBar != null)
              topBar
            else
              SizedBox(height: MileafLayout.rootTopClearance(context)),
            if (data != null)
              _hero(data!)
            else if (loading)
              _heroSkeleton()
            else
              _heroEmpty(),
            MileafContent(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  inset,
                  0,
                  inset,
                  MileafLayout.rootNavigationClearance(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (workspace.calendar?.fallback ?? false)
                      Padding(
                        padding: const EdgeInsets.only(top: MileafSpace.s8),
                        child: Text(
                          messages.timezoneUnreadableMessage(),
                          style: context.type.footnote.copyWith(
                            color: context.colors.warning,
                          ),
                        ),
                      ),
                    if (loading && data != null) ...[
                      const MileafProgressLine(),
                      const Text('正在更新'),
                    ],
                    if (error != null && data != null)
                      InlineBanner(
                        message: error!,
                        tone: BannerTone.error,
                        actionLabel: _retry,
                        actionSemanticLabel: copy_actions.retryOverview,
                        onAction: () => loadSummary(force: true),
                      ),
                    _periodBar(),
                    // R31：能力不支持是「保留旧能力」的状态条，落在期间行与
                    // 焦点卡之间，与统计失败条同一层级，读者第一眼就能看到。
                    if (capabilityError != null)
                      InlineBanner(
                        message: capabilityError!,
                        tone: BannerTone.warning,
                        actionLabel: _retry,
                        actionSemanticLabel: copy_actions.retryCapabilities,
                        onAction: () => loadCapabilities(force: true),
                      ),
                    if (errors['driving'] != null)
                      InlineBanner(
                        message: errors['driving']!,
                        tone: BannerTone.error,
                        actionLabel: _retry,
                        actionSemanticLabel: copy_actions.retryDrivingData,
                        onAction: () => loadStats('driving', force: true),
                      ),
                    if (errors['charging'] != null)
                      InlineBanner(
                        message: errors['charging']!,
                        tone: BannerTone.error,
                        actionLabel: _retry,
                        actionSemanticLabel: copy_actions.retryChargingData,
                        onAction: () => loadStats('charging', force: true),
                      ),
                    _focusCard(),
                    if (driving != null || charging != null) _readingPlate(),
                    if (data != null) _recentSection(data!),
                    _continueSection(),
                    _notesSection(data),
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

/// One selected point, split into roles so the date, the value and the
/// reference each keep a single place on screen.
class _PointReading {
  const _PointReading({
    required this.day,
    required this.value,
    this.unit,
    this.delta,
    this.reference,
    this.note,
    required this.semantic,
  });

  final String day;
  final String? value;
  final String? unit;
  final String? delta;
  final String? reference;
  final String? note;

  /// The chart's live-region sentence; it states the same value, reference and
  /// difference that are drawn above it.
  final String semantic;
}

class MetaPage extends StatefulWidget {
  const MetaPage({super.key, required this.workspace});
  final VehicleWorkspace workspace;
  @override
  State<MetaPage> createState() => _MetaPageState();
}

class _MetaPageState extends State<MetaPage> with WidgetsBindingObserver {
  late final SiteSession? owner;
  dto.Meta? data;
  CachedResult? result;
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
        setState(() {
          data = d;
          result = r;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = messages.readFailedMessage('服务信息'));
      }
    }
  }

  /// P12 分组行：100% 时尾部当前值；大字时值移到第二行，避免冻结组件
  /// MileafGroupRow 的尾部 Wrap 在 320/200% 下横向溢出（与设置页同一处理）。
  Widget _serviceRow(String title, String value, {bool topLine = false}) {
    final reflow = MileafLayout.largeText(context);
    return MileafGroupRow(
      title: title,
      value: reflow ? null : value,
      meta: reflow ? value : null,
      topLine: topLine,
    );
  }

  /// DF8 精确时间：入参是 UTC 瞬时，先按站点日历取墙钟。
  String _precise(DateTime? time) {
    if (time == null) return _unknown;
    final calendar = widget.workspace.calendar;
    return copy.formatPrecise(calendar?.local(time) ?? time);
  }

  /// R30.2 技术详情：原始字段与精确时间，可复制（R30.4）。
  MileafDataNoteGroup _technical(dto.Meta d) => MileafDataNoteGroup(
    category: DataNoteCategory.technical,
    copyable: true,
    note: [
      'Mileaf Server ${d.version}',
      'TeslaMate schema ${d.teslamateSchemaVersion?.toString() ?? _unknown}', // copy-guard: technical
      '兼容范围 tested=${d.tested}', // copy-guard: technical
      'Schema 检查 schema_ok=${d.schemaOk}', // copy-guard: technical
      '源单位 ${d.sourceUnitOfLength}，数值单位 ${d.units}', // copy-guard: technical
      if (result case final value?) '数据生成时间 ${_precise(value.checkedAt)}',
      '位置数据时间 ${_precise(d.freshness.lastPositionAt)}',
      '状态开始时间 ${_precise(d.freshness.lastStateAt)}',
    ].join('\n'),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Scaffold(
      appBar: mileafPageBar(context, title: const Text('服务信息')),
      body: SafeArea(
        child: MileafContent(
          child: ListView(
            padding: MileafLayout.pagePadding(context, top: MileafSpace.s12),
            children: [
              if (data == null && error == null)
                const Padding(
                  padding: EdgeInsets.only(top: MileafSpace.s16),
                  child: MileafProgressLine(),
                ),
              if (error != null) ...[
                InlineBanner(
                  message: error!,
                  tone: BannerTone.error,
                  actionLabel: _retry,
                  actionSemanticLabel: copy_actions.retryServiceInfo,
                  onAction: () {
                    setState(() => error = null);
                    load();
                  },
                ),
                const SizedBox(height: MileafSpace.s16),
              ],
              if (data case final d?) ...[
                // R25 二级页身份块：记录本身 title2 + 一行 subheadline 元信息。
                Text(
                  'Mileaf Server ${d.version}',
                  style: type.title2.copyWith(color: colors.text),
                ),
                const SizedBox(height: MileafSpace.s4),
                Text(
                  '当前连接的服务版本',
                  style: type.subheadline.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: MileafSpace.section),
                // P12：服务信息为分组卡 + 技术详情，行内是「标题 + 尾部当前值」。
                const MileafGroupHeader(title: '当前连接'),
                const SizedBox(height: MileafSpace.s8),
                MileafGroupCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _serviceRow('兼容范围', d.tested ? '在已测范围内' : '未声明已测兼容'),
                      _serviceRow(
                        'Schema 检查',
                        d.schemaOk ? '正常' : '未通过',
                        topLine: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MileafSpace.s8),
                // CP08：原文「此版本未声明已测兼容；这不代表 schema 不兼容」的
                // 意义不能删——可以缩句，但要保留「不代表不兼容」。
                Text(
                  '数值使用公制，源单位不做二次换算。未声明已测兼容不代表不兼容。',
                  style: type.footnote.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: MileafSpace.section),
                MileafDataNotes(groups: [_technical(d)]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
