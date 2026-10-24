import 'package:flutter/material.dart';

import 'statistics_period.dart';
import 'driving_statistics_contract.g.dart' as dto;
import 'workspace.dart';
import 'api.dart';
import 'currency.dart';
import 'charging_statistics_contract.g.dart' as charge;

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({
    super.key,
    required this.workspace,
    required this.currency,
  });
  final VehicleWorkspace workspace;
  final CurrencySettings currency;
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  int kind = 0;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('驾驶统计'),
              selected: kind == 0,
              onSelected: (_) => setState(() => kind = 0),
            ),
            ChoiceChip(
              label: const Text('充电统计'),
              selected: kind == 1,
              onSelected: (_) => setState(() => kind = 1),
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
  });
  final VehicleWorkspace workspace;
  final CurrencySettings currency;
  final String kind;
  final bool active;
  @override
  State<_StatisticsView> createState() => _StatisticsViewState();
}

class _StatisticsViewState extends State<_StatisticsView>
    with WidgetsBindingObserver {
  StatisticsSelection selection = const StatisticsSelection();
  dto.DrivingStats? data;
  charge.ChargingStats? chargingData;
  String? resultZone, resultDay;
  bool get hasData => data != null || chargingData != null;
  CachedResult? result;
  Map<String, String>? resultQuery;
  StatisticsSelection? resultSelection;
  String? error;
  bool loading = false;
  int sequence = 0;
  VehicleWorkspace get workspace => widget.workspace;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) load();
  }

  @override
  void didUpdateWidget(covariant _StatisticsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      final calendar = workspace.calendar!;
      load(
        reset:
            resultZone != calendar.identifier ||
            resultDay != calendar.day(workspace.session.now()),
      );
    }
  }

  @override
  void dispose() {
    sequence++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.active &&
        state == AppLifecycleState.resumed &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      foreground();
    }
  }

  Future<void> foreground() async {
    final changed = await workspace.foreground();
    if (mounted) await load(reset: changed);
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
      ? '—（缺失）'
      : '${(value as num).toStringAsFixed(decimals)} $unit';
  Widget line(String label, dynamic value, String unit, {int decimals = 0}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text('$label  ${number(value, unit, decimals: decimals)}'),
      );
  @override
  Widget build(BuildContext context) {
    final calendar = workspace.calendar!;
    final totals = data?.totals;
    final buckets = data?.buckets;
    return ListenableBuilder(
      listenable: widget.currency,
      builder: (context, _) => RefreshIndicator(
        onRefresh: () => load(force: true),
        child: ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.kind == 'driving' ? '驾驶结果' : '充电结果',
                    style: Theme.of(context).textTheme.headlineSmall,
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
              onChanged: (value) {
                setState(() => selection = value);
                load(reset: true);
              },
            ),
            Text('统计时区：${calendar.identifier}'),
            if (calendar.fallback) const Text('无法读取设备 IANA 时区，暂按 UTC 展示与归期'),
            if (widget.kind == 'driving')
              const Text(
                '仅统计已完成行程，按开始时间 started_at 归期。净电耗采用行程续航差与车辆效率估算能量／里程；毛电耗采用同区间已完成充电的充入电池能量（按结束时间归期）／驾驶里程。总计直接使用区间 totals。',
              ),
            if (widget.kind == 'charging')
              const Text(
                '仅统计已结束充电，按结束时间 ended_at 归期；列表按开始时间 started_at 归期，因此跨日会话的数量可能不同。进行中不计入。费用仅合计已知记录，均价仅使用费用已知记录对应能量，不能保证全部费用已记录。DC 占比分母为 AC+DC 已知分类能量，未知分类不归入 AC；不推导未知能量。',
              ),
            if (loading) const LinearProgressIndicator(),
            if (error != null) ...[
              Semantics(liveRegion: true, child: Text(error!)),
              TextButton(
                onPressed: () => load(force: true),
                child: const Text('重试统计'),
              ),
            ],
            if (totals != null) ...[
              line('行程数', totals.drives, '次'),
              line('总里程', totals.distanceKm, 'km', decimals: 1),
              line('能量', totals.energyKwh, 'kWh', decimals: 2),
              line('净电耗', totals.consumptionWhKmNet, 'Wh/km'),
              line('毛电耗', totals.consumptionWhKmGross, 'Wh/km'),
              line('最高速度', totals.speedMaxKmh, 'km/h'),
              if (totals.drives == 0)
                const Text('区间内无已完成行程；零值为服务端真实结果，比率缺失不补零。'),
              Text('校验时间：${calendar.local(result!.checkedAt)}'),
            ],
            if (chargingData case final charged?)
              ..._charging(context, charged, calendar),
            if (buckets != null) ...[
              const Divider(),
              Text('里程趋势', style: Theme.of(context).textTheme.titleLarge),
              const Text('按服务端时间桶展示；空桶保留零，缺失比率显示 —。点击每个时间桶可阅读完整指标。'),
              if (buckets.isEmpty) const Text('区间内无趋势数据'),
              for (final raw in buckets)
                _bucket(context, raw, calendar, buckets),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _charging(
    BuildContext context,
    charge.ChargingStats stats,
    CalendarContext calendar,
  ) {
    final totals = stats.totals;
    final max = stats.buckets.fold<num>(
      0,
      (value, b) => b.energyAddedKwh > value ? b.energyAddedKwh : value,
    );
    String share(num? value) =>
        value == null ? '—（缺失）' : '${(value * 100).toStringAsFixed(2)} %';
    Widget text(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text('$label  $value'),
    );
    return [
      line('会话数', totals.sessions, '次'),
      line('充入电池能量', totals.energyAddedKwh, 'kWh', decimals: 2),
      text('已知费用合计', widget.currency.amount(totals.cost)),
      text('已知费用均价', '${widget.currency.amount(totals.costPerKwh)}/kWh'),
      line('AC 充入能量', totals.acEnergyKwh, 'kWh', decimals: 2),
      line('DC 充入能量', totals.dcEnergyKwh, 'kWh', decimals: 2),
      text('DC 能量占比（已知分类）', share(totals.dcEnergyShare)),
      if (totals.sessions == 0) const Text('区间内无已结束充电；零为真实结果，缺失比率不补零。'),
      Text('校验时间：${calendar.local(result!.checkedAt)}'),
      const Divider(),
      Text('充入能量趋势', style: Theme.of(context).textTheme.titleLarge),
      const Text('时间桶按充电结束时间归期。点击时间桶阅读完整指标；条形仅展示充入能量，不将 AC/DC 归一成全部能量。'),
      if (stats.buckets.isEmpty) const Text('区间内无趋势数据'),
      for (final b in stats.buckets)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            '${statisticsDate(calendar.local(b.bucketStart))} · ${number(b.energyAddedKwh, 'kWh', decimals: 2)}',
          ),
          subtitle: Semantics(
            label: '充入能量柱形，${number(b.energyAddedKwh, 'kWh', decimals: 2)}',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(
                  value: max == 0 ? 0 : b.energyAddedKwh / max,
                  minHeight: 8,
                ),
              ),
            ),
          ),
          children: [
            line('会话数', b.sessions, '次'),
            text('已知费用合计', widget.currency.amount(b.cost)),
            text('已知费用均价', '${widget.currency.amount(b.costPerKwh)}/kWh'),
            line('AC 充入能量', b.acEnergyKwh, 'kWh', decimals: 2),
            line('DC 充入能量', b.dcEnergyKwh, 'kWh', decimals: 2),
            text('DC 能量占比（已知分类）', share(b.dcEnergyShare)),
          ],
        ),
    ];
  }

  Widget _bucket(
    BuildContext context,
    dto.DrivingBucket bucket,
    CalendarContext calendar,
    List<dto.DrivingBucket> buckets,
  ) {
    final date = calendar.local(bucket.bucketStart);
    final max = buckets.fold<num>(
      0,
      (v, b) => (b.distanceKm) > v ? b.distanceKm : v,
    );
    final distance = bucket.distanceKm;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        '${statisticsDate(date)} · ${number(distance, 'km', decimals: 1)}',
      ),
      subtitle: Semantics(
        label: '里程柱形，${number(distance, 'km', decimals: 1)}',
        child: ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(
              value: max == 0 ? 0 : distance / max,
              minHeight: 8,
            ),
          ),
        ),
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
}
