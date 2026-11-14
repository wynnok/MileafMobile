import 'package:flutter/material.dart';

import 'number_format.dart';

import 'design/components/components.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'statistics_period.dart';
import 'statistics_usage_page.dart';
import 'statistics_conditions_page.dart';
import 'statistics_insights_page.dart';
import 'statistics_charging_page.dart';
import 'statistics_range_page.dart';
import 'statistics_parking_page.dart';
import 'driving_statistics_contract.g.dart' as dto;
import 'workspace.dart';
import 'reading_scope.dart';
import 'api.dart';
import 'currency.dart';
import 'charging_statistics_contract.g.dart' as charge;
import 'charging_experience_contract.g.dart' as expanded;

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({
    super.key,
    required this.workspace,
    required this.currency,
    this.onDrive,
    this.initialKind = 0,
    this.initialTopic,
    this.initialSelection = const StatisticsSelection(),
    this.topBar,
  });
  final ValueChanged<int>? onDrive;
  final VehicleWorkspace workspace;
  final CurrencySettings currency;
  final int initialKind;
  final String? initialTopic;
  final StatisticsSelection initialSelection;
  final Widget? topBar;
  @override
  State<StatisticsPage> createState() => _StatisticsEntryState();
}

class _StatisticsEntryState extends State<StatisticsPage> {
  @override
  Widget build(BuildContext context) {
    final page = StatisticsInsightsPage(
      workspace: widget.workspace,
      currency: widget.currency,
      initialSelection: widget.initialSelection,
      initialTopic:
          widget.initialTopic ??
          (widget.initialKind == 1 ? 'charging' : 'overview'),
      topics: {
        'energy': (c) =>
            StatisticsConditionsPage(source: c, onRecord: widget.onDrive),
        'charging': (context) => StatisticsChargingPage(context: context),
        'usage': (c) =>
            StatisticsUsagePage(source: c, onRecord: widget.onDrive),
        'range': (context) => RangeObservationPage(context: context),
        'parking': (context) => ParkingObservationPage(context: context),
      },
      legacyBuilder: (selection) => _LegacyStatisticsPage(
        workspace: widget.workspace,
        currency: widget.currency,
        initialKind: widget.initialKind,
        initialSelection: selection,
      ),
    );
    final bar = widget.topBar;
    if (bar == null) return MileafContent(child: page);
    return Column(
      children: [
        bar,
        Expanded(child: MileafContent(child: page)),
      ],
    );
  }
}

/// Legacy 0.1/0.2 fallback for sites without `statistics_insights-v1`.
///
/// It keeps the published totals/bucket semantics and now draws only A tokens
/// and components: no C tiles, cards or chart copies.
class _LegacyStatisticsPage extends StatefulWidget {
  const _LegacyStatisticsPage({
    required this.workspace,
    required this.currency,
    required this.initialKind,
    required this.initialSelection,
  });
  final VehicleWorkspace workspace;
  final CurrencySettings currency;
  final int initialKind;
  final StatisticsSelection initialSelection;
  @override
  State<_LegacyStatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<_LegacyStatisticsPage> {
  late int kind = widget.initialKind;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: MileafLayout.pagePadding(
          context,
          top: MileafSpace.s8,
          bottom: 0,
        ),
        child: ChipRow(
          children: [
            StatusChip(
              label: '驾驶统计',
              selected: kind == 0,
              onTap: () => setState(() => kind = 0),
            ),
            StatusChip(
              label: '充电统计',
              selected: kind == 1,
              onTap: () => setState(() => kind = 1),
            ),
          ],
        ),
      ),
      Expanded(
        child: IndexedStack(
          index: kind,
          children: [
            for (final index in [0, 1])
              _StatisticsView(
                workspace: widget.workspace,
                currency: widget.currency,
                kind: index == 0 ? 'driving' : 'charging',
                active: kind == index,
                initialSelection: widget.initialSelection,
              ),
          ],
        ),
      ),
    ],
  );
}

class _StatisticsView extends StatefulWidget {
  const _StatisticsView({
    required this.workspace,
    required this.currency,
    required this.kind,
    required this.active,
    required this.initialSelection,
  });
  final VehicleWorkspace workspace;
  final CurrencySettings currency;
  final String kind;
  final bool active;
  final StatisticsSelection initialSelection;
  @override
  State<_StatisticsView> createState() => _StatisticsViewState();
}

class _StatisticsViewState extends State<_StatisticsView>
    with
        WidgetsBindingObserver,
        ReadingLifecycle<_StatisticsView>,
        CostAwareReading<_StatisticsView> {
  late StatisticsSelection selection = widget.initialSelection;
  dto.DrivingStats? data;
  charge.ChargingStats? chargingData;
  expanded.ChargingStats? expandedChargingData;
  String? resultZone, resultDay;
  bool get hasData => data != null || chargingData != null;
  CachedResult? result;
  Map<String, String>? resultQuery;
  StatisticsSelection? resultSelection;
  String? error;
  bool loading = false;
  int sequence = 0;
  int drivingMetric = 0;
  int chargingMetric = 0;
  final driving = _Sampling();
  final consumption = _Sampling();
  final charging = _Sampling();
  final classification = _Sampling();
  @override
  VehicleWorkspace get workspace => widget.workspace;
  @override
  void initState() {
    super.initState();
    initCostReading();
    workspace.addCostReader(refreshCost);
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) load();
  }

  @override
  void didUpdateWidget(covariant _StatisticsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (readingActive && widget.active && !oldWidget.active) {
      final calendar = workspace.calendar!;
      final costChanged = widget.kind == 'charging' && costPending;
      if (widget.kind != 'charging') consumeCost();
      load(
        force: costChanged,
        reset:
            resultZone != calendar.identifier ||
            resultDay != calendar.day(workspace.session.now()),
      );
    }
  }

  @override
  void dispose() {
    workspace.removeCostReader(refreshCost);
    sequence++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<bool> refreshCost() async {
    if (widget.kind != 'charging') {
      consumeCost();
      return true;
    }
    // A hidden or inactive charging view defers the fee refresh; the revision
    // is consumed when this view is visible again.
    if (!readingVisible || !widget.active) {
      deferCost();
      return false;
    }
    await load(force: true);
    final refreshed = error == null;
    if (refreshed) consumeCost();
    return refreshed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (readingVisible && widget.active && state == AppLifecycleState.resumed) {
      foreground();
    }
  }

  @override
  Future<void> resumeReading() async {
    if (widget.active) await foreground();
  }

  Future<void> foreground() async {
    final changed = await workspace.foreground();
    if (!mounted || !readingPresent || !widget.active) return;
    if (widget.kind != 'charging') consumeCost();
    if (costPending) {
      await load(force: true);
      if (mounted && error == null) consumeCost();
      return;
    }
    await load(reset: changed);
  }

  Future<void> load({bool force = false, bool reset = false}) async {
    final owner = workspace.session.current, calendar = workspace.calendar;
    final id = workspace.selectedId;
    if (owner == null || calendar == null || id == null) return;
    if (!force &&
        !reset &&
        resultQuery != null &&
        identical(resultSelection, selection) &&
        resultZone == calendar.identifier &&
        resultDay == calendar.day(workspace.session.now())) {
      final cached = workspace.cache.peek(
        owner,
        'vehicles/$id/stats',
        resultQuery!,
      );
      if (cached?.validUntil.isAfter(workspace.session.now()) ?? false) return;
    }
    final attempt = ++sequence;
    final requestedSelection = selection;
    final StatisticsWindow window;
    try {
      window = selection.resolve(calendar, workspace.session.now());
    } on FormatException catch (e) {
      setState(() {
        error = e.message;
        data = null;
        chargingData = null;
        expandedChargingData = null;
        loading = false;
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
      if (reset) {
        data = null;
        chargingData = null;
      }
    });
    try {
      final value = await workspace.cache.get(
        owner,
        'vehicles/$id/stats',
        query: window.query(widget.kind, calendar),
        force: force,
      );
      final body = widget.kind == 'driving'
          ? dto.DrivingStats.fromJson(value.body)
          : charge.ChargingStats.fromJson(value.body);
      final totals = value.body['totals'];
      final expandedBody =
          widget.kind == 'charging' &&
              totals is Map &&
              totals.containsKey('unit_cost_added')
          ? expanded.ChargingStats.fromJson(value.body)
          : null;
      if (!mounted ||
          attempt != sequence ||
          !workspace.session.isCurrent(owner) ||
          workspace.selectedId != id ||
          workspace.calendar?.identifier != calendar.identifier) {
        return;
      }
      setState(() {
        if (body is dto.DrivingStats) data = body;
        if (body is charge.ChargingStats) chargingData = body;
        expandedChargingData = expandedBody;
        resultZone = calendar.identifier;
        resultDay = calendar.day(workspace.session.now());
        result = value;
        resultQuery = window.query(widget.kind, calendar);
        resultSelection = requestedSelection;
      });
    } catch (e) {
      if (mounted &&
          attempt == sequence &&
          workspace.session.isCurrent(owner) &&
          workspace.selectedId == id) {
        setState(
          () => error = e is FormatException
              ? '服务返回格式不兼容，请核对版本'
              : '${e is ApiFailure ? e.message : '统计读取失败，请检查网络后重试'}${hasData ? '；保留上次快照，请重试' : ''}',
        );
      }
    } finally {
      if (mounted && attempt == sequence) setState(() => loading = false);
    }
  }

  String number(dynamic value, String unit, {int decimals = 0}) => value == null
      ? '—'
      : '${grouped(value as num, decimals: decimals)} $unit';
  Widget line(String label, dynamic value, String unit, {int decimals = 0}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: MileafSpace.s8),
        child: Text('$label  ${number(value, unit, decimals: decimals)}'),
      );

  /// A stepper row keeps the published 前/后一个采样 behaviour without the C
  /// chart widget; it mutates the chart's [_Sampling] so pages never carry the
  /// four selections themselves.
  Widget _steppers(_Sampling sampling, List<DateTime> times, {Key? nextKey}) {
    final selected = sampling.resolve(times);
    return Wrap(
      alignment: WrapAlignment.end,
      children: [
        TextButton(
          onPressed: selected > 0
              ? () => setState(() => sampling.select(times, selected - 1))
              : null,
          child: const Text('前一个采样'),
        ),
        TextButton(
          key: nextKey,
          onPressed: selected < times.length - 1
              ? () => setState(() => sampling.select(times, selected + 1))
              : null,
          child: const Text('后一个采样'),
        ),
      ],
    );
  }

  Widget _controls(
    List<String> labels,
    int selected,
    ValueChanged<int> onSelected,
  ) => ChipRow(
    equalWidth: true,
    children: [
      for (var i = 0; i < labels.length; i++)
        StatusChip(
          label: labels[i],
          selected: selected == i,
          onTap: () => onSelected(i),
        ),
    ],
  );

  Widget _metric(String label, num? value, String unit, {int decimals = 0}) =>
      MetricBlock(
        label: label,
        value: value == null ? null : grouped(value, decimals: decimals),
        unit: value == null ? null : unit,
        scale: MetricValueScale.metricLg,
      );

  @override
  Widget build(BuildContext context) {
    final calendar = workspace.calendar!;
    return ListenableBuilder(
      listenable: widget.currency,
      builder: (context, _) => RefreshIndicator(
        onRefresh: () => load(force: true),
        child: ListView(
          padding: MileafLayout.pagePadding(context, top: MileafSpace.s12),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.kind == 'driving' ? '驾驶结果' : '充电结果',
                    style: context.type.title,
                  ),
                ),
                IconButton(
                  onPressed: loading ? null : () => load(force: true),
                  icon: const Icon(Icons.refresh),
                  tooltip: '刷新统计',
                ),
              ],
            ),
            StatisticsPeriodControls(
              selection: selection,
              calendar: calendar,
              now: workspace.session.now(),
              // The dialog's own completion loads the picked period; closing
              // it must not revalidate the abandoned one as well.
              editor: readingEditor,
              onChanged: (value) {
                setState(() => selection = value);
                load(reset: true);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MileafSpace.s8),
              child: Text(
                '统计时区：${calendar.identifier}',
                style: context.type.micro.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
            ),
            if (calendar.fallback) const Text('无法读取设备 IANA 时区，暂按 UTC 展示与归期'),
            if (loading)
              MediaQuery.disableAnimationsOf(context)
                  ? const Text('正在读取统计…')
                  : const LinearProgressIndicator(),
            if (error != null) ...[
              Semantics(liveRegion: true, child: Text(error!)),
              TextButton(
                onPressed: () => load(force: true),
                child: const Text('重试统计'),
              ),
            ],
            if (data case final driving?)
              ..._driving(context, driving, calendar),
            if (chargingData case final charged?)
              ..._charging(context, charged, calendar),
          ],
        ),
      ),
    );
  }

  String _tick(CalendarContext calendar, DateTime time) {
    final local = calendar.local(time);
    return '${local.month}/${local.day}';
  }

  String _range(CalendarContext calendar) {
    final query = resultQuery;
    if (query == null) return '';
    final from = calendar.local(DateTime.parse(query['from']!));
    final to = calendar.local(
      DateTime.parse(query['to']!).subtract(const Duration(microseconds: 1)),
    );
    return '${statisticsDate(from)}—${statisticsDate(to)}';
  }

  List<Widget> _driving(
    BuildContext context,
    dto.DrivingStats stats,
    CalendarContext calendar,
  ) {
    final totals = stats.totals;
    final buckets = stats.buckets;
    final titles = ['里程', '次数', '能量', '最高速度'];
    final units = ['km', '次', 'kWh', 'km/h'];
    final title = titles[drivingMetric];
    final unit = units[drivingMetric];
    final values = <num?>[
      for (final bucket in buckets)
        switch (drivingMetric) {
          0 => bucket.distanceKm,
          1 => bucket.drives,
          2 => bucket.energyKwh,
          _ => bucket.speedMaxKmh,
        },
    ];
    final times = [for (final bucket in buckets) bucket.bucketStart];
    final decimals = switch (drivingMetric) {
      0 => 1,
      2 => 2,
      _ => 0,
    };
    final point = driving.resolve(times);
    return [
      Padding(
        padding: const EdgeInsets.only(top: MileafSpace.s8),
        child: MetricGrid(
          children: [
            _metric('总里程', totals.distanceKm, 'km', decimals: 1),
            _metric('行程数', totals.drives, '次'),
          ],
        ),
      ),
      const SizedBox(height: MileafSpace.section),
      TimeSeriesChart(
        key: ValueKey('driving-$drivingMetric'),
        title: '$title趋势',
        unit: unit,
        subtitle: _range(calendar),
        times: times,
        series: [
          ChartSeries(
            label: title,
            values: values,
            style: drivingMetric == 1
                ? ChartSeriesStyle.bars
                : ChartSeriesStyle.area,
          ),
        ],
        semanticsLabel: '$title趋势图表',
        controls: _controls(
          titles,
          drivingMetric,
          (index) => setState(() => drivingMetric = index),
        ),
        plotKey: const ValueKey('driving-statistics-chart'),
        tickLabel: (t) => _tick(calendar, t),
        selectedIndex: point,
        onSelected: (index) => setState(() => driving.select(times, index)),
        readout: (index) =>
            '$title读数 '
            '${index < values.length ? number(values[index], unit, decimals: decimals) : '—'}',
        emptyMessage: '区间内无趋势数据',
      ),
      if (times.isNotEmpty)
        _steppers(
          driving,
          times,
          nextKey: const ValueKey('statistics-driving-next'),
        ),
      const SizedBox(height: MileafSpace.section),
      _consumption(context, calendar, buckets, times),
      const SizedBox(height: MileafSpace.section),
      const SectionHeader(title: '区间指标'),
      const SizedBox(height: MileafSpace.s4),
      line('能量', totals.energyKwh, 'kWh', decimals: 2),
      line('净电耗', totals.consumptionWhKmNet, 'Wh/km'),
      line('毛电耗', totals.consumptionWhKmGross, 'Wh/km'),
      line('最高速度', totals.speedMaxKmh, 'km/h'),
      const SizedBox(height: MileafSpace.s12),
      Text(
        '按开始时间归期 · 仅统计已完成行程',
        style: context.type.micro.copyWith(color: context.colors.textMuted),
      ),
      if (totals.drives == 0)
        Padding(
          padding: const EdgeInsets.only(top: MileafSpace.s8),
          child: Text(
            '区间内无已完成行程；零值为服务端真实结果，比率缺失不补零。',
            style: context.type.body.copyWith(color: context.colors.textMuted),
          ),
        ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text('统计口径'),
        children: const [
          Text(
            '净电耗采用行程续航差与车辆效率估算能量／里程；毛电耗采用同区间已完成充电的充入电池能量（按结束时间归期）／驾驶里程。总计直接使用区间 totals，不平均各桶比率。',
          ),
        ],
      ),
      Text(
        '校验时间：${calendar.local(result!.checkedAt)}',
        style: context.type.micro.copyWith(color: context.colors.textMuted),
      ),
      const SizedBox(height: MileafSpace.section),
      const SectionHeader(title: '时间桶明细'),
      for (final bucket in buckets) _bucket(context, bucket, calendar),
    ];
  }

  /// 净 / 毛电耗 keeps both published series in one chart; missing stays broken.
  Widget _consumption(
    BuildContext context,
    CalendarContext calendar,
    List<dto.DrivingBucket> buckets,
    List<DateTime> times,
  ) {
    final point = consumption.resolve(times);
    final net = [for (final bucket in buckets) bucket.consumptionWhKmNet];
    final gross = [for (final bucket in buckets) bucket.consumptionWhKmGross];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TimeSeriesChart(
          title: '净 / 毛电耗',
          unit: 'Wh/km',
          subtitle: _range(calendar),
          times: times,
          series: [
            ChartSeries(label: '净电耗', values: net),
            ChartSeries(label: '毛电耗', values: gross),
          ],
          semanticsLabel: '净电耗与毛电耗图表',
          plotKey: const ValueKey('driving-consumption-chart'),
          tickLabel: (t) => _tick(calendar, t),
          selectedIndex: point,
          onSelected: (index) =>
              setState(() => consumption.select(times, index)),
          readout: (index) =>
              '净电耗读数 ${index < net.length ? number(net[index], 'Wh/km') : '—'}'
              '；毛电耗读数 ${index < gross.length ? number(gross[index], 'Wh/km') : '—'}',
          note: '不同能量口径分别阅读；缺失值断线，不补零。',
          emptyMessage: '区间内无趋势数据',
        ),
        if (times.isNotEmpty)
          _steppers(
            consumption,
            times,
            nextKey: const ValueKey('statistics-consumption-next'),
          ),
      ],
    );
  }

  String _share(num? value) =>
      value == null ? '—' : '${(value * 100).toStringAsFixed(2)} %';
  Widget textLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: MileafSpace.s8),
    child: Text('$label  $value'),
  );

  List<Widget> _charging(
    BuildContext context,
    charge.ChargingStats stats,
    CalendarContext calendar,
  ) {
    final totals = stats.totals;
    final buckets = stats.buckets;
    final richer = expandedChargingData;
    final labels = ['能量', '次数', '费用', '均价'];
    final titles = [
      '充入能量',
      '充电次数',
      '已知费用',
      richer == null ? '已知费用均价' : '有效入电均价',
    ];
    final currencyUnit = widget.currency.code ?? '币种未记录';
    final units = ['kWh', '次', currencyUnit, '$currencyUnit/kWh'];
    final unit = units[chargingMetric];
    final times = [for (final bucket in buckets) bucket.bucketStart];
    final values = <num?>[
      for (final (index, bucket) in buckets.indexed)
        switch (chargingMetric) {
          0 =>
            richer != null &&
                    richer.buckets[index].sessions > 0 &&
                    richer.buckets[index].energyKnownSessions == 0
                ? null
                : bucket.energyAddedKwh,
          1 => bucket.sessions,
          2 => bucket.cost,
          _ =>
            richer == null
                ? bucket.costPerKwh
                : richer.buckets[index].unitCostAdded.value,
        },
    ];
    final point = charging.resolve(times);
    // 没有一条记录带电量就是未知；真实 0 保留 0。
    final energyMissing =
        richer != null && richer.totals.energyKnownSessions == 0;
    final energy = energyMissing ? null : totals.energyAddedKwh;
    return [
      Padding(
        padding: const EdgeInsets.only(top: MileafSpace.s8),
        child: MetricGrid(
          children: [
            _metric('充入电池能量', energy, 'kWh', decimals: 2),
            MetricBlock(
              label: '已知费用合计',
              value: widget.currency.amountValue(totals.cost),
              scale: MetricValueScale.metricLg,
              note: widget.currency.amountNote,
            ),
          ],
        ),
      ),
      const SizedBox(height: MileafSpace.section),
      TimeSeriesChart(
        key: ValueKey('charging-$chargingMetric'),
        title: '${titles[chargingMetric]}趋势',
        unit: unit,
        subtitle: _range(calendar),
        times: times,
        series: [
          ChartSeries(
            label: labels[chargingMetric],
            values: values,
            style: switch (chargingMetric) {
              0 => ChartSeriesStyle.stem,
              1 || 2 => ChartSeriesStyle.bars,
              _ => ChartSeriesStyle.line,
            },
          ),
        ],
        semanticsLabel: '${titles[chargingMetric]}趋势图表',
        controls: _controls(
          labels,
          chargingMetric,
          (index) => setState(() => chargingMetric = index),
        ),
        plotKey: const ValueKey('charging-statistics-chart'),
        tickLabel: (t) => _tick(calendar, t),
        selectedIndex: point,
        onSelected: (index) => setState(() => charging.select(times, index)),
        readout: (index) {
          final value = index < values.length ? values[index] : null;
          if (chargingMetric >= 2) {
            return '${labels[chargingMetric]}读数 '
                '${widget.currency.amountValue(value)}'
                '${chargingMetric == 3 ? '/kWh' : ''}';
          }
          return '${labels[chargingMetric]}读数 '
              '${number(value, unit, decimals: chargingMetric == 0 ? 2 : 0)}';
        },
        note: chargingMetric >= 2
            ? richer == null
                  ? '仅费用已知记录；缺失费用不视为零，合计不保证覆盖全部花费。'
                  : '有效均价使用费用和入电均有效的同批记录；缺失费用不视为零。'
            : null,
        emptyMessage: '区间内无趋势数据',
      ),
      if (times.isNotEmpty)
        _steppers(
          charging,
          times,
          nextKey: const ValueKey('statistics-charging-next'),
        ),
      const SizedBox(height: MileafSpace.section),
      const SectionHeader(title: 'AC / DC 补能'),
      const SizedBox(height: MileafSpace.s8),
      MileafCategoryBars(
        values: [
          ('AC', energyMissing ? null : totals.acEnergyKwh),
          ('DC', energyMissing ? null : totals.dcEnergyKwh),
          if (richer != null)
            ('未知', energyMissing ? null : richer.totals.unknownEnergyKwh),
        ],
        note: '仅已知分类能量；未知分类不归入 AC。',
      ),
      textLine(
        'DC 能量占比（已知分类）',
        // 已知分类能量为 0 时分母为空，比例是未知而不是 0%。
        energyMissing ? '—' : _share(totals.dcEnergyShare),
      ),
      Text(
        '占比分母仅为 AC + DC 已知分类能量，不代表全部能量构成。',
        style: context.type.micro.copyWith(color: context.colors.textMuted),
      ),
      if (richer != null)
        Text(
          richer.totals.durationKnownSessions == 0
              ? '分类记录时长缺失'
              : 'AC ${decimal(richer.totals.acDurationMin)} 分钟 · DC ${decimal(richer.totals.dcDurationMin)} 分钟 · 未知 ${decimal(richer.totals.unknownDurationMin)} 分钟',
          style: context.type.micro.copyWith(color: context.colors.textMuted),
        ),
      const SizedBox(height: MileafSpace.section),
      _classification(context, calendar, buckets, richer, times),
      const SizedBox(height: MileafSpace.section),
      const SectionHeader(title: '区间指标'),
      const SizedBox(height: MileafSpace.s4),
      line('会话数', totals.sessions, '次'),
      _amountLine(
        richer == null ? '已知费用均价' : '有效入电均价',
        richer == null ? totals.costPerKwh : richer.totals.unitCostAdded.value,
        perKwh: true,
      ),
      if (richer != null) ...[
        Text(
          '费用有记录 ${richer.totals.costKnownSessions} / ${richer.totals.sessions} 次',
          style: context.type.body.copyWith(color: context.colors.text),
        ),
        Text(
          '对应入电 ${decimal(richer.totals.costKnownEnergyKwh)} kWh',
          style: context.type.body.copyWith(color: context.colors.text),
        ),
        Text(
          richer.totals.durationKnownSessions == 0
              ? '记录时长 —'
              : '记录时长 ${decimal(richer.totals.durationMinTotal)} 分钟 · ${richer.totals.durationKnownSessions} 次有效',
          style: context.type.body.copyWith(color: context.colors.text),
        ),
        _amountLine('有效网侧均价', richer.totals.unitCostGrid.value, perKwh: true),
      ],
      const SizedBox(height: MileafSpace.s12),
      Text(
        '按结束时间归期 · 仅统计已结束充电',
        style: context.type.micro.copyWith(color: context.colors.textMuted),
      ),
      if (totals.sessions == 0)
        Padding(
          padding: const EdgeInsets.only(top: MileafSpace.s8),
          child: Text(
            '区间内无已结束充电；零为真实结果，缺失比率不补零。',
            style: context.type.body.copyWith(color: context.colors.textMuted),
          ),
        ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text('统计口径'),
        children: const [
          Text(
            '充电统计按结束时间归期，进行中不计入。费用只合计已知记录；均价使用服务端对应口径。AC/DC 使用独立能量，不将已知分类强行归一成全部能量。',
          ),
        ],
      ),
      Text(
        '校验时间：${calendar.local(result!.checkedAt)}',
        style: context.type.micro.copyWith(color: context.colors.textMuted),
      ),
      const SizedBox(height: MileafSpace.section),
      const SectionHeader(title: '时间桶明细'),
      for (final (index, bucket) in buckets.indexed)
        _chargingBucket(context, bucket, calendar, richer?.buckets[index]),
    ];
  }

  /// A price line: amount plus a separate currency-note label (never brackets).
  Widget _amountLine(String label, num? value, {bool perKwh = false}) {
    final note = widget.currency.amountNote;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MileafSpace.s8),
      child: Wrap(
        spacing: MileafSpace.s8,
        runSpacing: MileafSpace.s4,
        children: [
          Text(
            '$label  ${widget.currency.amountValue(value)}'
            '${perKwh ? '/kWh' : ''}',
          ),
          if (note != null)
            Text(
              note,
              style: context.type.micro.copyWith(
                color: context.colors.textMuted,
              ),
            ),
        ],
      ),
    );
  }

  Widget _classification(
    BuildContext context,
    CalendarContext calendar,
    List<charge.ChargingBucket> buckets,
    expanded.ChargingStats? richer,
    List<DateTime> times,
  ) {
    final point = classification.resolve(times);
    final ac = [for (final b in buckets) b.acEnergyKwh];
    final dc = [for (final b in buckets) b.dcEnergyKwh];
    final unknown = richer == null
        ? const <num?>[]
        : [
            for (final bucket in richer.buckets)
              bucket.sessions > 0 && bucket.energyKnownSessions == 0
                  ? null
                  : bucket.unknownEnergyKwh,
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TimeSeriesChart(
          title: 'AC / DC 时间分布',
          unit: 'kWh',
          subtitle: _range(calendar),
          times: times,
          series: [
            ChartSeries(label: 'AC', values: ac),
            ChartSeries(label: 'DC', values: dc),
            if (richer != null) ChartSeries(label: '未知', values: unknown),
          ],
          semanticsLabel: 'AC 与 DC 时间分布图表',
          plotKey: const ValueKey('charging-classification-chart'),
          tickLabel: (t) => _tick(calendar, t),
          selectedIndex: point,
          onSelected: (index) =>
              setState(() => classification.select(times, index)),
          readout: (index) =>
              'AC读数 ${index < ac.length ? number(ac[index], 'kWh', decimals: 2) : '—'}',
          emptyMessage: '区间内无趋势数据',
        ),
        if (times.isNotEmpty) ...[
          // One reading per series keeps AC/DC/未知 separately readable.
          Text(
            'DC读数 ${number(point < dc.length ? dc[point] : null, 'kWh', decimals: 2)}',
            style: context.type.body.copyWith(color: context.colors.text),
          ),
          if (unknown.isNotEmpty)
            Text(
              '未知读数 ${number(point < unknown.length ? unknown[point] : null, 'kWh', decimals: 2)}',
              style: context.type.body.copyWith(color: context.colors.text),
            ),
          _steppers(
            classification,
            times,
            nextKey: const ValueKey('statistics-classification-next'),
          ),
        ],
      ],
    );
  }

  Widget _chargingBucket(
    BuildContext context,
    charge.ChargingBucket bucket,
    CalendarContext calendar,
    expanded.ChargingBucket? richer,
  ) {
    final note = widget.currency.amountNote;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(
        '${statisticsDate(calendar.local(bucket.bucketStart))} · ${number(richer != null && richer.sessions > 0 && richer.energyKnownSessions == 0 ? null : bucket.energyAddedKwh, 'kWh', decimals: 2)}',
      ),
      children: [
        line('会话数', bucket.sessions, '次'),
        textLine('已知费用合计', widget.currency.amountValue(bucket.cost)),
        if (note != null)
          Text(
            note,
            style: context.type.micro.copyWith(color: context.colors.textMuted),
          ),
        _amountLine(
          richer == null ? '已知费用均价' : '有效入电均价',
          richer == null ? bucket.costPerKwh : richer.unitCostAdded.value,
          perKwh: true,
        ),
        line('AC 充入能量', bucket.acEnergyKwh, 'kWh', decimals: 2),
        line('DC 充入能量', bucket.dcEnergyKwh, 'kWh', decimals: 2),
        textLine(
          'DC 能量占比（已知分类）',
          richer != null && richer.energyKnownSessions == 0
              ? '—'
              : _share(bucket.dcEnergyShare),
        ),
      ],
    );
  }

  Widget _bucket(
    BuildContext context,
    dto.DrivingBucket bucket,
    CalendarContext calendar,
  ) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: EdgeInsets.zero,
    title: Text(
      '${statisticsDate(calendar.local(bucket.bucketStart))} · ${number(bucket.distanceKm, 'km', decimals: 1)}',
    ),
    children: [
      line('行程数', bucket.drives, '次'),
      line('能量', bucket.energyKwh, 'kWh', decimals: 2),
      line('净电耗', bucket.consumptionWhKmNet, 'Wh/km'),
      line('毛电耗', bucket.consumptionWhKmGross, 'Wh/km'),
      line('最高速度', bucket.speedMaxKmh, 'km/h'),
    ],
  );
}

/// Selected sampling index for one chart.
///
/// The legacy page shows four charts; each keeps one of these instead of a raw
/// `int` plus its own clamp, so 「前/后一个采样」 behaves identically everywhere.
class _Sampling {
  int index = 0;
  DateTime? at;

  /// 0 for an empty bucket list, otherwise the index inside `0..length-1`.
  int clampedIndex(int length) => length <= 0 ? 0 : index.clamp(0, length - 1);

  /// Keeps a deliberate sample by its bucket date across a shifted window,
  /// then falls back to the nearest earlier sample that still exists.
  int resolve(List<DateTime> times) =>
      bucketIndexAt(times, at) ?? clampedIndex(times.length);

  void select(List<DateTime> times, int next) {
    index = next;
    at = next >= 0 && next < times.length ? times[next] : null;
  }
}
