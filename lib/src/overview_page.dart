import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'currency.dart';
import 'data_cards.dart';
import 'data_chart.dart';
import 'driving_statistics_contract.g.dart' as stats;
import 'charging_statistics_contract.g.dart' as charge;
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
    final values = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '最近记录 · $status',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            IconButton(
              onPressed: loading ? null : () => loadSummary(force: true),
              icon: const Icon(Icons.refresh, size: 16),
              tooltip: '刷新概览',
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          number(d.battery?.rangeKm, 'km', decimals: 1),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(rangeLabel, style: theme.textTheme.labelSmall),
      ],
    );
    final battery = BatteryLevelIndicator(
      level: d.battery?.level,
      size: 80 * scale,
    );
    return DataCard(
      padding: const EdgeInsets.all(12),
      color: Color.alphaBlend(
        theme.colorScheme.primary.withValues(alpha: .08),
        theme.colorScheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (scale > 1.4) ...[
            values,
            Align(alignment: Alignment.centerRight, child: battery),
          ] else
            Row(
              children: [
                Expanded(child: values),
                battery,
              ],
            ),
          const SizedBox(height: 6),
          Text(
            '位置采样 ${shortStamp(d.freshness.lastPositionAt)} · 非实时',
            style: theme.textTheme.labelSmall,
          ),
          if (d.state?.value == 'charging' && d.chargingPowerKw != null)
            Text(
              '最近充电功率 ${number(d.chargingPowerKw, 'kW', decimals: 2)}',
              style: theme.textTheme.labelSmall,
            ),
          const Divider(height: 12),
          Text(
            '今日里程 ${number(d.period.today.distanceKm, 'km', decimals: 1)} · ${d.period.today.drives} 次行程 · 估算消耗 ${number(d.period.today.energyKwh, 'kWh', decimals: 2)}',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  Widget metricCard(String label, String value, String note, _Metric target) {
    final theme = Theme.of(context);
    final parts = RegExp(r'^(-?[0-9][0-9.,]*)(.*)$').firstMatch(value);
    return Semantics(
      container: true,
      button: true,
      selected: metric == target,
      label: '$label $value，$note',
      excludeSemantics: true,
      onTap: () => setState(() => metric = target),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        color: metric == target
            ? theme.colorScheme.primaryContainer.withValues(alpha: .35)
            : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => metric = target),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelSmall),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    text: parts?.group(1) ?? value,
                    children: [
                      if (parts != null)
                        TextSpan(
                          text: parts.group(2),
                          style: theme.textTheme.labelSmall,
                        ),
                    ],
                  ),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(note, style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
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
    final isCharging = metric == _Metric.charge || metric == _Metric.cost;
    final displayed = ranges[isCharging ? 'charging' : 'driving']?.current;
    if ((isCharging ? charging : driving) == null) return const SizedBox();
    final (title, label, unit) = switch (metric) {
      _Metric.distance => (
        period == OverviewPeriod.month ? '本月里程' : '近7天里程',
        '里程',
        'km',
      ),
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
            for (final b in driving!.buckets)
              switch (metric) {
                _Metric.net => b.consumptionWhKmNet,
                _Metric.energy => b.energyKwh,
                _ => b.distanceKm,
              },
          ];
    return TimeChart(
      key: chartKey,
      plotKey: plotKey,
      title: title,
      unit: unit,
      times: chartTimes,
      series: [ChartSeries(label: label, values: values)],
      timestamp: timestamp,
      tickLabel: (t) {
        final d = workspace.calendar!.local(t);
        return '${d.month}/${d.day}';
      },
      height: 110,
      presentation: metric == _Metric.net
          ? ChartPresentation.line
          : ChartPresentation.bars,
      subtitle:
          '${shortStamp(displayed?.from)}—${shortStamp(displayed?.to)} · ${workspace.calendar!.identifier}',
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
            label: '已知费用均价',
            value: '${widget.currency.amount(charging!.totals.costPerKwh)}/kWh',
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
        subtitle: Text(
          d.lastCharge == null
              ? '无记录'
              : '${timestamp(d.lastCharge!.startedAt)}\n充入 ${number(d.lastCharge!.energyKwh, 'kWh', decimals: 2)} · 结束电量 ${number(d.lastCharge!.endSoc, '%')}',
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (workspace.calendar?.fallback ?? false)
              const Text('无法读取设备 IANA 时区，暂按 UTC 展示与归期'),
            if (loading) const LinearProgressIndicator(),
            if (data == null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: loading ? null : () => loadSummary(force: true),
                    icon: const Icon(Icons.refresh, size: 19),
                    tooltip: '刷新概览',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            if (error != null) ...[
              Semantics(liveRegion: true, child: Text(error!)),
              TextButton(
                onPressed: () => loadSummary(force: true),
                child: const Text('重试概览'),
              ),
            ],
            if (data != null) summary(context, data!),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '用车简报',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final item in OverviewPeriod.values)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: ChoiceChip(
                      label: Text(
                        item == OverviewPeriod.month ? '本月' : '近7天',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      selected: period == item,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => changePeriod(item),
                    ),
                  ),
                IconButton(
                  onPressed: pending.contains('driving')
                      ? null
                      : () => loadStats('driving', force: true),
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: '刷新里程趋势',
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            resourceStatus('driving', '重试里程趋势'),
            resourceStatus('charging', '重试补能'),
            pairs([
              metricCard(
                '驾驶里程',
                number(driving?.totals.distanceKm, 'km', decimals: 1),
                driving == null ? '等待读取' : '${driving!.totals.drives} 次行程',
                _Metric.distance,
              ),
              metricCard(
                '驾驶净电耗 · 估算',
                number(driving?.totals.consumptionWhKmNet, 'Wh/km'),
                '点按查看电耗变化',
                _Metric.net,
              ),
            ]),
            pairs([
              metricCard(
                '充入电池',
                number(charging?.totals.energyAddedKwh, 'kWh', decimals: 1),
                charging == null ? '等待读取' : '${charging!.totals.sessions} 次充电',
                _Metric.charge,
              ),
              metricCard(
                '已知充电费用',
                widget.currency.amount(charging?.totals.cost),
                '仅含费用已知记录',
                _Metric.cost,
              ),
            ]),
            mainChart(),
            if (widget.onInsight != null && range != null) ...[
              const SizedBox(height: 12),
              Text('读懂这辆车', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final item in [
                (
                  'usage',
                  Icons.calendar_month_outlined,
                  '我的用车节奏',
                  '驾驶时间、常见单程与每周分布',
                ),
                (
                  'energy',
                  Icons.insights_outlined,
                  '什么影响了电耗',
                  '按温度与距离看记录，了解样本差异',
                ),
                (
                  'long',
                  Icons.battery_std_outlined,
                  '续航与停放观察',
                  '额定续航长期记录、停放电量变化',
                ),
              ])
                InsightLink(
                  icon: item.$2,
                  title: item.$3,
                  subtitle: item.$4,
                  onTap: () => widget.onInsight!(item.$1, range!.selection),
                ),
            ],
            if (driving != null) comparisonCard(),
            if (driving != null) drivingCard(),
            if (charging != null) chargingCard(),
            if (data != null) ...records(data!),
          ],
        ),
      );
    },
  );
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
