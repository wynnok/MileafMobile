import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'currency.dart';
import 'collage.dart';
import 'data_cards.dart';
import 'data_chart.dart';
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
  });
  final VehicleWorkspace workspace;
  final CurrencySettings currency;
  final void Function(String, StatisticsSelection)? onStatistics;
  final void Function(String, StatisticsSelection)? onInsight;
  final void Function(String kind, int id)? onRecord;
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
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    sequence++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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

  Widget comparisonCard() {
    if (pairedAvailable) return pairedComparisonCard();
    final current = (comparisonDriving ?? driving)?.totals,
        prior = comparison?.totals;
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
    return DataCard(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('一条有参照的变化', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Text(message),
          if (comparing) const LinearProgressIndicator(),
          if (comparisonError != null)
            Text(
              '比较暂不可用：$comparisonError${comparison == null ? '' : '；保留上次比较快照'}',
            ),
          if (comparisonRange != null)
            Text(
              '比较快照截止 ${timestamp(comparisonRange!.current.to)}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          if (comparisonError != null)
            TextButton(
              onPressed: () => loadComparison(force: true),
              child: const Text('重试比较'),
            ),
          const SizedBox(height: 6),
          const Text('样本覆盖率尚不可核验，不直接判断驾驶更省电。', style: TextStyle(fontSize: 12)),
          TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (context) => SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '比较依据',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      line('本期', number(current?.consumptionWhKmNet, 'Wh/km')),
                      line('基期', number(prior?.consumptionWhKmNet, 'Wh/km')),
                      line(
                        '本期区间',
                        '${timestamp(pairedRange?.current.from)} 至 ${timestamp(pairedRange?.current.to)}',
                      ),
                      if (pairedRange?.previous case final p?)
                        line(
                          '基期区间',
                          '${timestamp(p.from)} 至 ${timestamp(p.to)}',
                        ),
                      line('归期时区', workspace.calendar!.identifier),
                      const Text(
                        '同车、同一时区、同一本地截止时刻。净电耗基于续航差和车辆效率估算，部分能量样本可能缺失；只描述数值差异，不推断原因。基期为零或缺失时不输出比较结论。',
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('关闭'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child: const Text('查看比较依据'),
          ),
        ],
      ),
    );
  }

  Widget pairedComparisonCard() {
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
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('配对净电耗与覆盖', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          MetricGrid(
            children: [
              MetricTile(
                label: '配对估算净电耗',
                value: number(value?.valueWhKm, 'Wh/km'),
                note: '${value?.eligibleDrives ?? '—'}趟有效',
              ),
              MetricTile(
                label: '记录驾驶时长',
                value: number(
                  current?.totals.drivingCoverage.durationKnownMin,
                  '分钟',
                ),
                note:
                    '${current?.totals.drivingCoverage.durationKnownDrives ?? '—'}趟有记录',
              ),
            ],
          ),
          Text(
            '有效里程 ${number(value?.denominatorDistanceKm, 'km', decimals: 1)} · 全里程 ${number(driving?.totals.distanceKm, 'km', decimals: 1)}',
          ),
          if (valid)
            Text(
              '配对净电耗较参照差 ${(value!.valueWhKm! - prior.totals.netConsumptionPaired.valueWhKm!).toStringAsFixed(1)} Wh/km',
            )
          else
            const Text('参照质量或口径不满足时，仅展示原值'),
          if (comparing) const LinearProgressIndicator(),
          if (comparisonError != null) Text('比较暂不可用：$comparisonError'),
          if (comparisonError != null)
            TextButton(
              onPressed: () => loadComparison(force: true),
              child: const Text('重试比较'),
            ),
          if (current == null) const Text('扩展统计字段缺失或不兼容，未用旧净电耗替代配对值'),
          const Text(
            '同批有效能量与里程配对估算；只描述差异，不推断原因。',
            style: TextStyle(fontSize: 12),
          ),
          ExpansionTile(
            title: const Text('比较区间与口径'),
            tilePadding: EdgeInsets.zero,
            children: [
              if (current != null)
                Text(
                  '本期 ${timestamp(current.query.from)}—${timestamp(current.query.to)}；生成 ${timestamp(current.asOf)}',
                ),
              if (prior != null)
                Text(
                  '参照 ${timestamp(prior.query.from)}—${timestamp(prior.query.to)} · ${number(prior.totals.netConsumptionPaired.valueWhKm, 'Wh/km')}；生成 ${timestamp(prior.asOf)}',
                ),
              Text('归期时区 ${workspace.calendar!.identifier}；两个资源分别生成，非同时快照'),
            ],
          ),
        ],
      ),
    );
  }

  String timestamp(DateTime? time) => time == null
      ? '未知'
      : workspace.calendar!.local(time).toString().split('.').first;
  String number(num? value, String unit, {int decimals = 0}) =>
      value == null ? '—（缺失）' : '${value.toStringAsFixed(decimals)} $unit';
  Widget line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text('$label  $value'),
  );
  String shortStamp(DateTime? t) {
    if (t == null) return '未知';
    final d = workspace.calendar!.local(t);
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget summary(BuildContext context, dto.Summary d) {
    final theme = Theme.of(context),
        scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final status = switch (d.state?.value) {
      'online' => '在线',
      'asleep' => '休眠',
      'offline' => '离线',
      'charging' => '充电中',
      _ => '未知',
    };
    final rangeLabel = switch (d.battery?.rangeKind) {
      'rated' => '额定续航',
      'ideal' => '理想续航（ideal）',
      _ => '续航（未知口径）',
    };
    final ago = _minutesAgo(d.state?.since);
    final statusLine = '最近状态 · $status${ago == null ? '' : ' · $ago 分钟前'}';
    final values = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.circle, size: 8, color: Color(0xFF8AD6AF)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                statusLine,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF8AD6AF),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            text: d.battery?.rangeKm == null
                ? '—'
                : d.battery!.rangeKm!.toStringAsFixed(0),
            children: [
              TextSpan(
                text: ' km',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFEEF7EF),
                ),
              ),
            ],
          ),
          style: theme.textTheme.displayLarge?.copyWith(
            fontSize: 46,
            height: 1.0,
            color: const Color(0xFFEEF7EF),
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$rangeLabel · 电量 ${number(d.battery?.level, '%')} · 非实时',
          style: const TextStyle(fontSize: 11, color: Color(0xFFB8D6C3)),
        ),
      ],
    );
    final battery = BatteryLevelIndicator(
      level: d.battery?.level,
      size: 66 * scale,
    );
    Widget stat(String value, String label) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFFEEF7EF),
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: Color(0xFFB8D6C3)),
          ),
        ],
      ),
    );
    return CollageTile(
      surface: CollageSurface.hero,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (scale > 1.4) ...[
              values,
              Align(alignment: Alignment.centerRight, child: battery),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: values),
                  const SizedBox(width: 8),
                  battery,
                ],
              ),
            const Divider(height: 12, color: Color(0x2266DDAA)),
            Row(
              children: [
                stat(d.period.today.distanceKm.toStringAsFixed(0), '今日 km'),
                stat('${d.period.today.drives}', '次行程'),
                stat(
                  d.period.today.energyKwh?.toStringAsFixed(2) ?? '—',
                  '估算 kWh',
                ),
                stat(d.chargingPowerKw?.toStringAsFixed(1) ?? '—', 'kW 充电'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int? _minutesAgo(DateTime? since) {
    if (since == null) return null;
    final diff = workspace.session.now().difference(since).inMinutes;
    return diff < 0 ? null : diff;
  }

  String get mileageComparison {
    final current = results['driving'];
    final prior = comparisonResult;
    if (!pairedAvailable ||
        current == null ||
        prior == null ||
        enhancedDriving(current) == null ||
        enhancedDriving(prior) == null ||
        comparisonError != null ||
        !identical(comparisonRange, ranges['driving']) ||
        !canCompare(
          current.body,
          prior.body,
          workspace.calendar!,
          period == OverviewPeriod.month
              ? StatisticsPeriod.month
              : StatisticsPeriod.custom,
        )) {
      return '同期参照不足';
    }
    final previous = comparison?.totals.distanceKm;
    final distance = driving?.totals.distanceKm;
    if (previous == null || distance == null) return '同期里程缺失';
    return '里程较参照差 ${(distance - previous).toStringAsFixed(1)} km';
  }

  Widget pairs(List<Widget> children) =>
      MediaQuery.textScalerOf(context).scale(14) / 14 > 1.4
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        )
      : Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: children[0]),
            const SizedBox(width: 8),
            Expanded(child: children[1]),
          ],
        );
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
  Widget mainChart() {
    final paired = enhancedDriving(results['driving']);
    final isCharging = metric == _Metric.charge || metric == _Metric.cost;
    final displayed = ranges[isCharging ? 'charging' : 'driving']?.current;
    if ((isCharging ? charging : driving) == null) return const SizedBox();
    final (title, label, unit) = switch (metric) {
      _Metric.distance => ('每日里程', '里程', 'km'),
      _Metric.net => ('净电耗趋势 · 估算', '净电耗', 'Wh/km'),
      _Metric.energy => ('驾驶消耗趋势 · 估算', '驾驶消耗', 'kWh'),
      _Metric.charge => ('充入电量趋势', '充入电量', 'kWh'),
      _Metric.cost => ('已知费用趋势', '已知费用', widget.currency.code ?? '币种未知'),
    };
    final values = isCharging
        ? [
            for (final b in charging!.buckets)
              metric == _Metric.cost ? b.cost : b.energyAddedKwh,
          ]
        : [
            for (final (index, b) in driving!.buckets.indexed)
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
    return TimeChart(
      key: chartKey,
      plotKey: plotKey,
      title: metric == _Metric.net && pairedAvailable ? '配对净电耗趋势 · 估算' : title,
      unit: unit,
      times: chartTimes,
      series: [ChartSeries(label: label, values: values)],
      timestamp: timestamp,
      tickLabel: (t) {
        final d = workspace.calendar!.local(t);
        return '${d.month}/${d.day}';
      },
      height: 84,

      presentation: metric == _Metric.net
          ? ChartPresentation.line
          : ChartPresentation.bars,
      subtitle: '${shortStamp(displayed?.from)}—${shortStamp(displayed?.to)}',
      valueLabel: metric == _Metric.cost ? widget.currency.amount : null,
      note: metric == _Metric.cost ? '仅含费用已知记录；缺失不表示免费。' : null,
    );
  }

  Widget resourceStatus(String kind, String retry) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (pending.contains(kind)) const LinearProgressIndicator(),
      if (errors[kind] != null) ...[
        Semantics(liveRegion: true, child: Text(errors[kind]!)),
        TextButton(
          onPressed: () => loadStats(kind, force: true),
          child: Text(retry),
        ),
      ],
    ],
  );
  Widget drivingCard() => DataCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '驾驶消耗',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton(
              onPressed: () =>
                  widget.onStatistics?.call('driving', range!.selection),
              child: const Text('驾驶统计'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        pairs([
          MetricTile(
            label: '估算驾驶消耗',
            value: number(driving!.totals.energyKwh, 'kWh', decimals: 2),
          ),
          MetricTile(
            label: '净电耗 · 估算',
            value: number(driving!.totals.consumptionWhKmNet, 'Wh/km'),
          ),
        ]),
        TextButton(
          onPressed: () => setState(() => metric = _Metric.energy),
          child: const Text('查看每日驾驶消耗'),
        ),
        ExpansionTile(
          title: const Text('毛电耗与计算口径'),
          shape: const Border(),
          collapsedShape: const Border(),
          children: [
            line('毛电耗', number(driving!.totals.consumptionWhKmGross, 'Wh/km')),
            const Text(
              '毛电耗为区间充入电池能量÷驾驶里程，受补能时点影响，不是网侧电耗；净毛差额不代表停车损耗。净电耗与驾驶消耗按续航差和车辆效率估算。',
            ),
          ],
        ),
      ],
    ),
  );
  Widget chargingCard() => DataCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '补能账本',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton(
              onPressed: () =>
                  widget.onStatistics?.call('charging', range!.selection),
              child: const Text('充电统计'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        pairs([
          MetricTile(label: '充电次数', value: '${charging!.totals.sessions} 次'),
          MetricTile(
            label: coverageAvailable ? '有效入电均价' : '已知费用均价',
            value:
                '${widget.currency.amount(coverageAvailable ? enhancedCharging?.totals.unitCostAdded.value : charging!.totals.costPerKwh)}/kWh',
          ),
        ]),
        EnergyComparison(
          values: [
            ('AC', charging!.totals.acEnergyKwh),
            ('DC', charging!.totals.dcEnergyKwh),
          ],
        ),
        Text(
          'DC 占已知分类能量 ${number(charging!.totals.dcEnergyShare == null ? null : charging!.totals.dcEnergyShare! * 100, '%', decimals: 1)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const Text(
          'AC/DC 仅含已知分类，不代表全部补能；均价仅含费用已知会话。',
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
  List<Widget> records(dto.Summary d) => [
    Text('最近记录', style: Theme.of(context).textTheme.titleSmall),
    const SizedBox(height: 8),
    DataCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        title: const Text('最近行程'),
        subtitle: Text(
          d.lastDrive == null
              ? '无记录'
              : '${timestamp(d.lastDrive!.startedAt)}\n${number(d.lastDrive!.distanceKm, 'km', decimals: 1)} · 净电耗 ${number(d.lastDrive!.consumptionWhKm, 'Wh/km')}',
        ),
        trailing: d.lastDrive == null ? null : const Icon(Icons.chevron_right),
        onTap: d.lastDrive == null
            ? null
            : () => widget.onRecord?.call('drive', d.lastDrive!.id),
      ),
    ),
    DataCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        title: const Text('最近充电'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              d.lastCharge == null
                  ? '无记录'
                  : '${timestamp(d.lastCharge!.startedAt)}\n充入 ${number(d.lastCharge!.energyKwh, 'kWh', decimals: 2)} · 结束电量 ${number(d.lastCharge!.endSoc, '%')}',
            ),
            if (d.lastCharge?.endSoc case final soc?)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(
                  value: (soc / 100).clamp(0, 1),
                  semanticsLabel: '最近充电结束电量',
                  semanticsValue: '$soc %',
                ),
              ),
          ],
        ),
        trailing: d.lastCharge == null ? null : const Icon(Icons.chevron_right),
        onTap: d.lastCharge == null
            ? null
            : () => widget.onRecord?.call('charging', d.lastCharge!.id),
      ),
    ),
    DataCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        title: const Text('车辆与数据时间'),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          line('状态开始', timestamp(d.state?.since)),
          line('位置采样完整时间', timestamp(d.freshness.lastPositionAt)),
          line('里程表', number(d.odometerKm, 'km', decimals: 1)),
          line('固件', d.firmware?.version ?? '未知'),
          line('最近状态区间起始', timestamp(d.freshness.lastStateAt)),
          line('校验时间', timestamp(result?.checkedAt)),
          for (final entry in results.entries)
            line(
              entry.key == 'driving' ? '趋势已校验' : '补能已校验',
              timestamp(entry.value.checkedAt),
            ),
          line('归期时区：${workspace.calendar?.identifier ?? 'UTC'}', ''),
          const Text('旧采样或长时间休眠不等同系统故障。'),
        ],
      ),
    ),
  ];
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
      return RefreshIndicator(
        key: viewportKey,
        onRefresh: () => load(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (workspace.calendar?.fallback ?? false)
              const Text('无法读取设备 IANA 时区，暂按 UTC 展示与归期'),
            if (loading) const LinearProgressIndicator(),
            if (error != null) ...[
              Semantics(liveRegion: true, child: Text(error!)),
              TextButton(
                onPressed: () => loadSummary(force: true),
                child: const Text('重试概览'),
              ),
            ],
            if (data != null) summary(context, data!),
            _periodBar(),
            resourceStatus('driving', '重试里程趋势'),
            resourceStatus('charging', '重试补能'),
            _monthBento(),
            _dailyChartCard(),
            _insightStrip(),
            if (data != null) ...records(data!),
            _chapterGrid(),
            ExpansionTile(
              title: const Text('数据说明与更多'),
              children: [
                if (capabilityError != null) ...[
                  Text(capabilityError!),
                  TextButton(
                    onPressed: () => loadCapabilities(force: true),
                    child: const Text('重试扩展能力'),
                  ),
                ],
                if (coverageAvailable && charging != null) _coveragePanel(),
                if (driving != null) comparisonCard(),
                if (driving != null) drivingCard(),
                if (charging != null) chargingCard(),
              ],
            ),
          ],
        ),
      );
    },
  );

  Widget _periodBar() => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: Row(
      children: [
        for (final item in OverviewPeriod.values)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(
                item == OverviewPeriod.month ? '本月' : '近7天',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              selected: period == item,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => changePeriod(item),
            ),
          ),
        const Spacer(),
        IconButton(
          onPressed: loading ? null : () => loadSummary(force: true),
          icon: const Icon(Icons.refresh, size: 18),
          tooltip: '刷新概览',
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        OutlinedButton.icon(
          onPressed: () => setState(() {}),
          icon: const Icon(Icons.calendar_today_outlined, size: 14),
          label: const Text('日期'),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
        ),
      ],
    ),
  );

  Widget _monthBento() =>
      CollageBento(lead: _monthTile(), evidence: [_netTile(), _costTile()]);

  Widget _monthTile() {
    final theme = Theme.of(context);
    final value = driving?.totals.distanceKm;
    final parts = value == null ? '—' : value.toStringAsFixed(1);
    return Semantics(
      container: true,
      label: '本月驾驶里程 $parts km，${driving?.totals.drives ?? 0} 趟',
      child: CollageTile(
        surface: CollageSurface.mint,
        padding: const EdgeInsets.all(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 128),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '本月 · 驾驶里程',
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                  Text(
                    '${driving?.totals.drives ?? 0} 趟',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  text: parts,
                  children: [
                    TextSpan(text: ' km', style: theme.textTheme.titleMedium),
                  ],
                ),
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 46,
                  height: 1.0,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),
              Text(mileageComparison, style: theme.textTheme.labelSmall),
              const SizedBox(height: 8),
              _Sparkline(
                height: 26,
                values: [
                  for (final b in driving?.buckets ?? <stats.DrivingBucket>[])
                    b.distanceKm.toDouble(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _netTile() {
    final theme = Theme.of(context);
    final value = pairedAvailable
        ? enhancedDriving(results['driving'])
              ?.totals
              .netConsumptionPaired
              .valueWhKm
        : driving?.totals.consumptionWhKmNet;
    return Semantics(
      container: true,
      button: true,
      selected: metric == _Metric.net,
      label: '净电耗 估算 ${value?.toStringAsFixed(0) ?? '缺失'} Wh/km',
      excludeSemantics: true,
      child: CollageTile(
        surface: CollageSurface.sand,
        padding: const EdgeInsets.all(12),
        child: InkWell(
          onTap: () => setState(() => metric = _Metric.net),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('净电耗 · 估算', style: theme.textTheme.labelSmall),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  text: value?.toStringAsFixed(0) ?? '—',
                  children: [
                    TextSpan(text: ' Wh/km', style: theme.textTheme.labelSmall),
                  ],
                ),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                pairedAvailable ? '同批有效能量与里程' : '点按查看电耗变化',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _costTile() {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      button: true,
      selected: metric == _Metric.cost,
      label: '已知充电费用 ${widget.currency.amount(charging?.totals.cost)}，仅含费用已知记录',
      excludeSemantics: true,
      onTap: () => setState(() => metric = _Metric.cost),
      child: CollageTile(
        padding: const EdgeInsets.all(12),
        child: InkWell(
          onTap: () => setState(() => metric = _Metric.cost),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('已知充电费用', style: theme.textTheme.labelSmall),
                  ),
                  const Icon(Icons.credit_card_outlined, size: 14),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.currency.amount(charging?.totals.cost),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${charging?.totals.sessions ?? 0} 次有记录',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricTabs() => Wrap(
    spacing: 6,
    children: [
      for (final (m, label) in [
        (_Metric.distance, '里程'),
        (_Metric.net, '电耗'),
        (_Metric.charge, '补能'),
        (_Metric.cost, '费用'),
      ])
        ChoiceChip(
          label: Text(label, style: Theme.of(context).textTheme.labelSmall),
          selected: metric == m,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          onSelected: (_) => setState(() => metric = m),
        ),
    ],
  );

  Widget _dailyChartCard() => CollageTile(
    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_metricTabs(), const SizedBox(height: 4), mainChart()],
    ),
  );

  Widget _insightStrip() => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, size: 15),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '按同车、同期归期时区统计；数据非实时，费用为已知记录。',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _chapterGrid() {
    if (widget.onInsight == null || range == null) {
      return const SizedBox.shrink();
    }
    final items = [
      ('usage', Icons.calendar_month_outlined, '节奏', '驾驶时间与单程'),
      ('energy', Icons.insights_outlined, '能耗', '温度与距离'),
      ('charging', Icons.bolt_outlined, '补能', '费用与结构'),
      ('long', Icons.battery_std_outlined, '长期', '续航与停放'),
    ];
    Widget card((String, IconData, String, String) item) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => item.$1 == 'charging'
            ? widget.onStatistics?.call('charging', range!.selection)
            : widget.onInsight!(item.$1, range!.selection),
        child: CollageTile(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.$3,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Icon(item.$2, size: 16),
                ],
              ),
              const SizedBox(height: 2),
              Text(item.$4, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('读下去 →', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 6),
          child: Text('四个问题', style: Theme.of(context).textTheme.labelMedium),
        ),
        for (var i = 0; i < items.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                card(items[i]),
                const SizedBox(width: 8),
                card(items[i + 1]),
              ],
            ),
          ),
      ],
    );
  }

  Widget _coveragePanel() => DataCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('已知费用的覆盖', style: Theme.of(context).textTheme.titleSmall),
        if (enhancedCharging case final s?) ...[
          Text(
            '费用有记录 ${s.totals.costKnownSessions} / ${s.totals.sessions} 次 · 对应入电 ${number(s.totals.costKnownEnergyKwh, 'kWh', decimals: 1)}',
          ),
          Text(
            '有效入电均价 ${widget.currency.amount(s.totals.unitCostAdded.value)}/kWh',
          ),
          const Text('已知支出不等于全部用车成本', style: TextStyle(fontSize: 12)),
        ] else
          const Text('费用覆盖字段缺失或不兼容，未按完整费用显示'),
      ],
    ),
  );
}

/// Minimal bar sparkline for the C 本月 tile (renders buckets as light bars).
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.values, this.height = 34});
  final List<double> values;
  final double height;
  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return SizedBox(height: height);
    final max = values.fold<double>(0, (a, b) => b > a ? b : a);
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(values, max, color),
        size: Size.infinite,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, this.max, this.color);
  final List<double> values;
  final double max;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || max <= 0) return;
    final gap = 2.0;
    final barWidth = (size.width - gap * (values.length - 1)) / values.length;
    final paint = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      final h = (values[i] / max) * size.height;
      final left = i * (barWidth + gap);
      final isLast = i == values.length - 1;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - h, barWidth, h),
          const Radius.circular(2),
        ),
        paint..color = color.withValues(alpha: isLast ? 1 : 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values || old.max != max || old.color != color;
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
      ],
    ),
  );
}
