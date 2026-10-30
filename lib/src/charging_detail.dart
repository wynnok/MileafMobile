import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'api.dart';
import 'data_cards.dart';
import 'data_chart.dart';
import 'charging_detail_contract.g.dart' as dto;
import 'charging_experience_contract.g.dart' as expanded;
import 'currency.dart';
import 'collage.dart';
import 'workspace.dart';

Future<void> openChargingDetail(
  BuildContext context,
  VehicleWorkspace workspace,
  CurrencySettings currency,
  int id,
) => Navigator.push<void>(
  context,
  MaterialPageRoute(
    builder: (_) =>
        ChargingDetailPage(workspace: workspace, currency: currency, id: id),
  ),
);

class ChargingDetailPage extends StatefulWidget {
  const ChargingDetailPage({
    super.key,
    required this.workspace,
    required this.currency,
    required this.id,
  });
  final VehicleWorkspace workspace;
  final CurrencySettings currency;
  final int id;
  @override
  State<ChargingDetailPage> createState() => _ChargingDetailPageState();
}

class _ChargingDetailPageState extends State<ChargingDetailPage>
    with WidgetsBindingObserver {
  VehicleWorkspace get workspace => widget.workspace;
  late final owner = workspace.session.current!;
  late final vehicle = workspace.selectedId!;
  dto.ChargingSessionDetail? detail;
  dto.ChargingSessionSeries? series;
  expanded.ChargingSessionDetail? expandedDetail;
  expanded.ChargingSessionSeries? expandedSeries;
  String? detailError, seriesError;
  bool detailLoading = false,
      seriesLoading = false,
      unavailable = false,
      leaving = false,
      ownershipMismatch = false;
  int detailSequence = 0, seriesSequence = 0;
  bool get current =>
      mounted &&
      workspace.session.isCurrent(owner) &&
      workspace.selectedId == vehicle;
  @override
  void initState() {
    super.initState();
    workspace.addListener(changed);
    WidgetsBinding.instance.addObserver(this);
    loadDetail();
    loadSeries();
  }

  @override
  void dispose() {
    detailSequence++;
    seriesSequence++;
    workspace.removeListener(changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void changed() {
    if (current || leaving) return;
    leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && route.isActive) {
        Navigator.of(context).removeRoute(route);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      foreground();
    }
  }

  Future<void> foreground() async {
    await workspace.foreground();
    if (current) {
      loadDetail();
      loadSeries();
    }
  }

  String failure(Object error, bool snapshot) =>
      '${error is FormatException
          ? '服务返回格式不兼容，请核对版本'
          : error is ApiFailure
          ? error.message
          : '读取失败，请重试'}${snapshot ? '；保留上次快照' : ''}';
  Future<void> loadDetail({bool force = false}) async {
    if (!current) return;
    final attempt = ++detailSequence;
    setState(() {
      detailLoading = true;
      detailError = null;
    });
    try {
      final result = await workspace.cache.get(
        owner,
        'charging-sessions/${widget.id}',
        force: force,
      );
      final value = dto.ChargingSessionDetail.fromJson(result.body);
      if (!current || attempt != detailSequence) return;
      if (value.id != widget.id || value.vehicleId != vehicle) {
        ownershipMismatch = true;
        series = null;
        expandedSeries = null;
        expandedDetail = null;
        throw const FormatException();
      }
      expanded.ChargingSessionDetail? additional;
      if (result.body['capabilities'] is Map) {
        additional = expanded.ChargingSessionDetail.fromJson(result.body);
      }
      setState(() {
        detail = value;
        expandedDetail = additional;
        unavailable = false;
        ownershipMismatch = false;
      });
      if (additional != null) loadSeries(extended: true);
    } catch (error) {
      if (current && attempt == detailSequence) {
        setState(() {
          unavailable = error is BusinessFailure && error.status == 404;
          detailError = unavailable
              ? '该充电记录已不可用，可返回上一页'
              : failure(error, detail != null);
        });
      }
    } finally {
      if (current && attempt == detailSequence) {
        setState(() => detailLoading = false);
      }
    }
  }

  Future<void> loadSeries({bool force = false, bool? extended}) async {
    if (!current) return;
    final useExpanded = extended ?? expandedDetail != null;
    final capabilities = expandedDetail?.capabilities?.fields ?? {};
    final fields = [
      'power',
      'soc',
      if (useExpanded)
        for (final name in [
          'voltage_v',
          'actual_current_a',
          'pilot_current_a',
          'outside_temp_c',
          'rated_range_km',
          'ideal_range_km',
          'charge_energy_added_kwh',
          'battery_heater',
          'battery_heater_on',
          'battery_heater_no_power',
          'not_enough_power_to_heat',
        ])
          if (capabilities[name] == true) name,
    ];
    final attempt = ++seriesSequence;
    setState(() {
      seriesLoading = true;
      seriesError = null;
    });
    try {
      final result = await workspace.cache.get(
        owner,
        'charging-sessions/${widget.id}/series',
        query: {'fields': fields.join(','), 'points': '200'},
        force: force,
      );
      final value = dto.ChargingSessionSeries.fromJson(result.body);
      final additional = useExpanded
          ? expanded.ChargingSessionSeries.fromJson(result.body)
          : null;
      if (!current || attempt != seriesSequence) return;
      if (value.sessionId != widget.id) throw const FormatException();
      if (!ownershipMismatch) {
        setState(() {
          series = value;
          expandedSeries = additional;
        });
      }
    } catch (error) {
      if (current && attempt == seriesSequence) {
        setState(() => seriesError = failure(error, series != null));
      }
    } finally {
      if (current && attempt == seriesSequence) {
        setState(() => seriesLoading = false);
      }
    }
  }

  String number(num? value, String unit, {bool temperature = false}) =>
      value == null
      ? '—（缺失）'
      : '${temperature ? value.toStringAsFixed(1) : decimal(value)} $unit';
  String time(DateTime? value) => value == null
      ? '—（缺失）'
      : workspace.calendar!.local(value).toString().split('.').first;
  String windowReason(String status) => switch (status) {
    'incomplete_session' => '充电进行中',
    'insufficient_samples' => '有效电量采样不足',
    'not_reached' => '未记录到所需电量区间',
    'gap_or_ambiguous' => '采样间隔或电量变化不足以确认',
    _ => '数据不足',
  };
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.currency,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(expandedDetail == null ? '充电详情 #${widget.id}' : '充电回顾'),
        actions: [
          IconButton(
            onPressed: detailLoading ? null : () => loadDetail(force: true),
            icon: const Icon(Icons.refresh),
            tooltip: '刷新充电明细',
          ),
          IconButton(
            onPressed: seriesLoading ? null : () => loadSeries(force: true),
            icon: const Icon(Icons.show_chart),
            tooltip: '刷新充电曲线',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (detailLoading) const LinearProgressIndicator(),
            if (detailError != null) ...[
              Semantics(liveRegion: true, child: Text(detailError!)),
              if (!unavailable)
                TextButton(
                  onPressed: detailLoading
                      ? null
                      : () => loadDetail(force: true),
                  child: const Text('重试充电明细'),
                ),
            ],
            if (unavailable)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回上一页'),
              ),
            if (detail case final d?) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  d.location.displayName?.trim().isNotEmpty == true
                      ? d.location.displayName!
                      : '未知地点',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              CollageTile(
                surface: CollageSurface.hero,
                child: Builder(
                  builder: (context) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('电量变化'),
                      SizedBox(
                        height: 36,
                        child: CustomPaint(
                          painter: _BatteryArc(
                            d.startSoc,
                            d.endSoc,
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                      Text(
                        '${d.startSoc ?? '—'}% → ${d.endSoc ?? '—'}%',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(d.isActive ? '充电进行中，当前指标不代表最终结果' : '充电已结束'),
                    ],
                  ),
                ),
              ),
              CollageTile(
                surface: CollageSurface.mint,
                child: Wrap(
                  spacing: 18,
                  runSpacing: 6,
                  children: [
                    Text(
                      '充入电池 ${number(d.energyAddedKwh, 'kWh')}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('费用 ${widget.currency.amount(d.cost)}'),
                    Text('时长 ${number(d.durationMin, '分钟')}'),
                    Text(
                      d.isDc == null
                          ? '分类未知'
                          : d.isDc!
                          ? 'DC'
                          : 'AC',
                    ),
                  ],
                ),
              ),
            ],
            if (seriesLoading) const LinearProgressIndicator(),
            if (seriesError != null) ...[
              Semantics(liveRegion: true, child: Text(seriesError!)),
              TextButton(
                onPressed: seriesLoading ? null : () => loadSeries(force: true),
                child: const Text('重试充电曲线'),
              ),
            ],
            if (!ownershipMismatch && expandedSeries != null)
              ExpandedChargingCurve(
                key: ValueKey(
                  '${widget.id}:${identityHashCode(expandedSeries)}',
                ),
                series: expandedSeries!,
                calendar: workspace.calendar!,
              )
            else if (!ownershipMismatch && series != null)
              ChargingCurve(
                key: ValueKey('${widget.id}:${identityHashCode(series)}'),
                series: series!,
                calendar: workspace.calendar!,
              ),
            if (detail case final d?) ...[
              DataCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('两类能量', style: Theme.of(context).textTheme.titleSmall),
                    EnergyComparison(
                      values: [
                        ('充入电池', d.energyAddedKwh),
                        ('电网侧', d.energyUsedKwh),
                      ],
                      note: '两类能量分别记录，不相加。',
                    ),
                  ],
                ),
              ),
              ExpansionTile(
                title: const Text('过程数据说明'),
                children: [
                  if (expandedDetail?.processMetrics case final process?)
                    DataCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('原始功率峰值 ${number(process.powerMaxKw, 'kW')}'),
                          Text(
                            '记录平均功率 ${number(process.powerTimeWeightedKw, 'kW')}',
                          ),
                          Text(
                            '有效采样 ${process.powerValidSamples} 点 · 覆盖 ${decimal(process.observedSeconds)} 秒 · 未覆盖 ${decimal(process.uncoveredSeconds)} 秒',
                          ),
                          for (final window in process.socWindows)
                            Text(
                              !d.isActive &&
                                      window.status == 'available' &&
                                      window.elapsedSeconds != null
                                  ? '${window.thresholdPrecision == 'exact' ? '记录达到' : '记录跨越'} ${window.startObservedSoc ?? '—'}% → ${window.endObservedSoc ?? '—'}% · ${decimal(window.elapsedSeconds! / 60)} 分钟'
                                  : '20% → 80% 记录用时不可用：${windowReason(d.isActive ? 'incomplete_session' : window.status)}',
                            ),
                          const Text('结果来自原始记录；抽样曲线不用于计算峰值或时长。'),
                        ],
                      ),
                    ),
                  if (expandedDetail != null &&
                      expandedDetail!.processMetrics == null)
                    const Text('原始充电过程指标暂不可用。'),
                ],
              ),
              if (expandedDetail case final extra?) ...[
                DataCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '这一次的账',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text('已记录费用 ${widget.currency.amount(d.cost)}'),
                      Text(
                        '每入电 kWh ${widget.currency.amount(extra.unitCostAdded?.value)}/kWh',
                      ),
                      Text(
                        '每网侧 kWh ${widget.currency.amount(extra.unitCostGrid?.value)}/kWh',
                      ),
                      const Text('均价按服务端有效配对计算；费用未知不代表免费。'),
                    ],
                  ),
                ),
                DataCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '车辆与环境',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '室外温度均值 ${number(d.outsideTempCAvg, '°C', temperature: true)}',
                      ),
                      Text(
                        extra.capabilities?.fields['start_rated_range_km'] ==
                                    true &&
                                extra
                                        .capabilities
                                        ?.fields['end_rated_range_km'] ==
                                    true
                            ? '额定续航 ${number(extra.startRatedRangeKm, 'km')} → ${number(extra.endRatedRangeKm, 'km')}'
                            : '额定续航未受站点支持',
                      ),
                      Text(
                        extra.capabilities?.fields['start_ideal_range_km'] ==
                                    true &&
                                extra
                                        .capabilities
                                        ?.fields['end_ideal_range_km'] ==
                                    true
                            ? '理想续航 ${number(extra.startIdealRangeKm, 'km')} → ${number(extra.endIdealRangeKm, 'km')}'
                            : '理想续航未受站点支持',
                      ),
                      Text(
                        '充电器品牌 ${extra.charger?.fastChargerBrand ?? '—（缺失）'}',
                      ),
                      Text(
                        '充电器类型 ${extra.charger?.fastChargerType ?? '—（缺失）'}',
                      ),
                      Text('充电线 ${extra.charger?.connChargeCable ?? '—（缺失）'}'),
                      if (extra.charger?.sourceSampleAt != null)
                        Text('充电器记录时间 ${time(extra.charger!.sourceSampleAt)}'),
                      const Text('温度为室外均值；续航是额定或理想口径，不代表实际可达距离。'),
                    ],
                  ),
                ),
              ],
              DataCard(
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('更多充电信息'),
                  childrenPadding: const EdgeInsets.only(top: 12),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('开始 ${time(d.startedAt)}'),
                    Text('结束 ${time(d.endedAt)}'),
                    if (d.location.geofence != null)
                      Text('围栏：${d.location.geofence}'),
                    if (d.location.address != null &&
                        d.location.address != d.location.displayName)
                      Text('地址：${d.location.address}'),
                    Text(
                      '平均外温 ${number(d.outsideTempCAvg, '°C', temperature: true)}',
                    ),
                    Text('充电相数 ${d.chargerPhasesMode ?? '—（缺失）'}'),
                    Text(
                      '车辆 ID $vehicle · 时区：${workspace.calendar?.identifier ?? 'UTC'}',
                    ),
                    const Text('历史结果只读；— 表示缺失，不代表零。'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class ExpandedChargingCurve extends StatefulWidget {
  const ExpandedChargingCurve({
    super.key,
    required this.series,
    required this.calendar,
  });
  final expanded.ChargingSessionSeries series;
  final CalendarContext calendar;
  @override
  State<ExpandedChargingCurve> createState() => _ExpandedChargingCurveState();
}

class _ExpandedChargingCurveState extends State<ExpandedChargingCurve> {
  String metric = 'power';
  bool socAxis = false;
  int selected = 0;

  static const choices = <(String, String, String)>[
    ('power', '功率', 'kW'),
    ('soc', '电量', '%'),
    ('voltage_v', '电压', 'V'),
    ('actual_current_a', '实际电流', 'A'),
    ('pilot_current_a', '引导电流', 'A'),
    ('outside_temp_c', '室外温度', '°C'),
    ('rated_range_km', '额定续航', 'km'),
    ('ideal_range_km', '理想续航', 'km'),
    ('charge_energy_added_kwh', '累计入电', 'kWh'),
  ];

  num? reading(expanded.ChargePoint point) => switch (metric) {
    'power' => point.power,
    'soc' => point.soc,
    'voltage_v' => point.voltageV,
    'actual_current_a' => point.actualCurrentA,
    'pilot_current_a' => point.pilotCurrentA,
    'outside_temp_c' => point.outsideTempC,
    'rated_range_km' => point.ratedRangeKm,
    'ideal_range_km' => point.idealRangeKm,
    _ => point.chargeEnergyAddedKwh,
  };

  @override
  Widget build(BuildContext context) {
    final points = widget.series.series;
    final choice = choices.firstWhere((entry) => entry.$1 == metric);
    final available = widget.series.capabilities.fields;
    final events = widget.series.stateEvents;
    final controls = Wrap(
      spacing: 8,
      children: [
        for (final entry in choices)
          if (entry.$1 == 'power' ||
              entry.$1 == 'soc' ||
              available[entry.$1] == true)
            ChoiceChip(
              label: Text('${entry.$2} ${entry.$3}'),
              selected: metric == entry.$1,
              onSelected: (_) => setState(() => metric = entry.$1),
            ),
        ChoiceChip(
          label: const Text('按时间'),
          selected: !socAxis,
          onSelected: (_) => setState(() => socAxis = false),
        ),
        ChoiceChip(
          label: const Text('按电量'),
          selected: socAxis,
          onSelected: (_) => setState(() => socAxis = true),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!socAxis)
          TimeChart(
            title: '充电曲线',
            unit: choice.$3,
            times: points.map((point) => point.t).toList(),
            series: [
              ChartSeries(
                label: choice.$2,
                values: points.map(reading).toList(),
              ),
            ],
            timestamp: (time) =>
                widget.calendar.local(time).toString().split('.').first,
            presentation: ChartPresentation.line,
            minimum: metric == 'soc' ? 0 : null,
            maximum: metric == 'soc' ? 100 : null,
            plotKey: const Key('charging-time-chart'),
            controls: controls,
            selectedIndex: selected,
            onSelected: (index) => setState(() => selected = index),
          )
        else
          DataCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '充电曲线 · ${choice.$2}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                controls,
                const Text('横轴为电量；相同电量的采样按时间顺序保留。'),
                if (points.isEmpty)
                  const Text('此充电没有序列采样')
                else ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      void pick(Offset local) {
                        final soc =
                            ((local.dx - 38) /
                                    (constraints.maxWidth - 56) *
                                    100)
                                .clamp(0, 100);
                        int? nearest;
                        for (var index = 0; index < points.length; index++) {
                          final value = points[index].soc;
                          if (value == null || value < 0 || value > 100) {
                            continue;
                          }
                          if (nearest == null ||
                              (value - soc).abs() <
                                  (points[nearest].soc! - soc).abs()) {
                            nearest = index;
                          }
                        }
                        if (nearest != null) {
                          setState(() => selected = nearest!);
                        }
                      }

                      String describe(int index) {
                        final point = points[index];
                        return '电量 ${point.soc ?? '缺失'}%，${choice.$2} ${reading(point) ?? '缺失'} ${choice.$3}';
                      }

                      return Semantics(
                        label: '按电量的${choice.$2}图表',
                        value: describe(selected),
                        increasedValue: selected < points.length - 1
                            ? describe(selected + 1)
                            : null,
                        decreasedValue: selected > 0
                            ? describe(selected - 1)
                            : null,
                        onIncrease: selected < points.length - 1
                            ? () => setState(() => selected++)
                            : null,
                        onDecrease: selected > 0
                            ? () => setState(() => selected--)
                            : null,
                        child: GestureDetector(
                          onTapUp: (event) => pick(event.localPosition),
                          onHorizontalDragUpdate: (event) =>
                              pick(event.localPosition),
                          child: CustomPaint(
                            key: const Key('charging-soc-chart'),
                            size: Size(constraints.maxWidth, 160),
                            painter: _ChargingSocPainter(
                              points: points,
                              values: points.map(reading).toList(),
                              selected: selected,
                              color: Theme.of(context).colorScheme.primary,
                              grid: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
                              text: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontFamily:
                                  Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.fontFamily ??
                                  'Roboto',
                              scale:
                                  MediaQuery.textScalerOf(context).scale(10) /
                                  10,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Text(
                    '电量 ${points[selected].soc ?? '—'}% · ${choice.$2} ${reading(points[selected]) ?? '—'} ${choice.$3}',
                  ),
                  Text(
                    widget.calendar
                        .local(points[selected].t)
                        .toString()
                        .split('.')
                        .first,
                  ),
                  Wrap(
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton(
                        onPressed: selected > 0
                            ? () => setState(() => selected--)
                            : null,
                        child: const Text('前一个采样'),
                      ),
                      TextButton(
                        onPressed: selected < points.length - 1
                            ? () => setState(() => selected++)
                            : null,
                        child: const Text('后一个采样'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ExpansionTile(
          title: const Text('曲线数据说明'),
          children: [
            Text('服务端采样 ${widget.series.points} 点'),
            const Text('缺失值断线，不补点、不补零；采样峰值不等同原始峰值。累计入电可能重置，续航不是实际可达距离。'),
          ],
        ),
        if (points.isEmpty) const Text('此充电没有序列采样'),
        if (points.isNotEmpty &&
            points.where((p) => reading(p) != null).length < 2)
          const Text('有效采样不足两点，仅显示可用点与读数'),
        if (events != null)
          ExpansionTile(
            title: const Text('电池加热状态变化'),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('状态记录不代表加热耗能；时间为原始状态变化。'),
                  if (events.truncated)
                    Text(
                      '仅显示 ${events.events.length} / ${events.totalEvents} 条事件，状态记录已截断。',
                    ),
                  if (events.events.isEmpty) const Text('没有可用状态变化'),
                  if (events.events.isNotEmpty) ...[
                    const Text('● 是  ○ 否  × 未知；重合事件可展开查看'),
                    for (final field
                        in events.events.map((e) => e.field).toSet()) ...[
                      Text(heatingLabel(field)),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final samples = widget.series.series;
                          final start = samples.isEmpty
                              ? events.events.first.t
                              : samples.first.t;
                          final end = samples.isEmpty
                              ? events.events.last.t
                              : samples.last.t;
                          final span = end.difference(start).inMicroseconds;
                          final width = math.max(
                            1.0,
                            constraints.maxWidth - 16,
                          );
                          return SizedBox(
                            key: ValueKey('charging-heater-$field'),
                            height: 24,
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 8,
                                  right: 8,
                                  top: 11,
                                  child: Divider(
                                    height: 1,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outlineVariant,
                                  ),
                                ),
                                for (final event in events.events.where(
                                  (e) => e.field == field,
                                ))
                                  Positioned(
                                    left:
                                        (span <= 0
                                                ? 0.0
                                                : event.t
                                                          .difference(start)
                                                          .inMicroseconds /
                                                      span *
                                                      width)
                                            .clamp(0.0, width),
                                    child: Semantics(
                                      label:
                                          '${heatingLabel(field)} ${event.value == null
                                              ? '未知'
                                              : event.value!
                                              ? '是'
                                              : '否'} ${widget.calendar.local(event.t)}',
                                      child: Text(
                                        event.value == null
                                            ? '×'
                                            : event.value!
                                            ? '●'
                                            : '○',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                    ExpansionTile(
                      title: const Text('状态变化明细'),
                      tilePadding: EdgeInsets.zero,
                      children: [
                        for (final event in events.events)
                          ListTile(
                            dense: true,
                            title: Text(heatingLabel(event.field)),
                            subtitle: Text(
                              widget.calendar
                                  .local(event.t)
                                  .toString()
                                  .split('.')
                                  .first,
                            ),
                            trailing: Text(
                              event.value == null
                                  ? '未知'
                                  : event.value!
                                  ? '是'
                                  : '否',
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
      ],
    );
  }
}

String heatingLabel(String field) => switch (field) {
  'battery_heater' => '电池加热',
  'battery_heater_on' => '电池加热开启',
  'battery_heater_no_power' => '电池加热无功率',
  _ => '加热功率不足',
};

class _ChargingSocPainter extends CustomPainter {
  _ChargingSocPainter({
    required this.points,
    required this.values,
    required this.selected,
    required this.color,
    required this.grid,
    required this.text,
    required this.fontFamily,
    required this.scale,
  });
  final List<expanded.ChargePoint> points;
  final List<num?> values;
  final int selected;
  final Color color, grid, text;
  final String fontFamily;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final known = values.whereType<num>().toList();
    final low = math
        .min(0, known.isEmpty ? 0 : known.reduce(math.min))
        .toDouble();
    var high = math
        .max(0, known.isEmpty ? 1 : known.reduce(math.max))
        .toDouble();
    if (high == low) high = low + 1;
    final plot = Rect.fromLTRB(38, 8, size.width - 18, size.height - 25);
    double x(num soc) => plot.left + plot.width * soc / 100;
    double y(num value) =>
        plot.bottom - plot.height * (value - low) / (high - low);
    void label(String value, Offset offset) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 10 * math.min(scale, 1.5),
            color: text,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, offset);
    }

    for (final fraction in [0.0, .5, 1.0]) {
      final yy = plot.bottom - plot.height * fraction;
      canvas.drawLine(
        Offset(plot.left, yy),
        Offset(plot.right, yy),
        Paint()..color = grid,
      );
      label(
        (low + (high - low) * fraction).toStringAsFixed(0),
        Offset(0, yy - 7),
      );
      label(
        '${(fraction * 100).toInt()}%',
        Offset(x(fraction * 100) - (fraction == 1 ? 20 : 0), plot.bottom + 6),
      );
    }
    Offset? previous;
    for (var i = 0; i < points.length; i++) {
      final soc = points[i].soc;
      final value = values[i];
      if (soc == null || soc < 0 || soc > 100 || value == null) {
        previous = null;
        continue;
      }
      final next = Offset(x(soc), y(value));
      if (previous != null) {
        canvas.drawLine(
          previous,
          next,
          Paint()
            ..color = color
            ..strokeWidth = 2,
        );
      }
      canvas.drawCircle(next, i == selected ? 4 : 2, Paint()..color = color);
      previous = next;
    }
  }

  @override
  bool shouldRepaint(covariant _ChargingSocPainter oldDelegate) => true;
}

class ChargingCurve extends StatefulWidget {
  const ChargingCurve({
    super.key,
    required this.series,
    required this.calendar,
  });
  final dto.ChargingSessionSeries series;
  final CalendarContext calendar;
  @override
  State<ChargingCurve> createState() => _ChargingCurveState();
}

class _ChargingCurveState extends State<ChargingCurve> {
  bool power = true;
  num? value(dto.ChargePoint p) => power ? p.power : p.soc;
  @override
  Widget build(BuildContext context) {
    final points = widget.series.series;
    final valid = points.where((p) => value(p) != null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TimeChart(
          title: '充电曲线',
          unit: power ? 'kW' : '%',
          times: [for (final p in points) p.t],
          series: [
            ChartSeries(
              label: power ? '功率' : '电量',
              values: [for (final p in points) value(p)],
            ),
          ],
          timestamp: (t) =>
              widget.calendar.local(t).toString().split('.').first,
          presentation: ChartPresentation.line,
          minimum: power ? null : 0,
          maximum: power ? null : 100,
          plotKey: const Key('charging-time-chart'),
          controls: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('功率 kW'),
                selected: power,
                onSelected: (_) => setState(() => power = true),
              ),
              ChoiceChip(
                label: const Text('电量 %'),
                selected: !power,
                onSelected: (_) => setState(() => power = false),
              ),
            ],
          ),
        ),
        ExpansionTile(
          title: const Text('曲线数据说明'),
          children: [
            Text('服务端采样 ${widget.series.points} 点 · 当前指标有效 $valid 点'),
            const Text('缺失值断线，不补点、不补零；采样峰值不等同原始峰值。累计入电可能重置，续航不是实际可达距离。'),
          ],
        ),
        if (points.isEmpty) const Text('此充电没有序列采样'),
        if (points.isNotEmpty && valid < 2) const Text('有效采样不足两点，仅显示可用点与读数'),
      ],
    );
  }
}

/// Endpoints are independent observations; missing endpoints never draw a range.
class _BatteryArc extends CustomPainter {
  _BatteryArc(this.start, this.end, this.color);
  final num? start, end;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, 32),
      width: 128,
      height: 48,
    );
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: .18);
    canvas.drawArc(rect, math.pi, math.pi, false, pen);
    if (start != null && end != null) {
      pen.color = color;
      final low = math.min(start!, end!).clamp(0, 100) / 100;
      final high = math.max(start!, end!).clamp(0, 100) / 100;
      canvas.drawArc(
        rect,
        math.pi + math.pi * low,
        math.pi * (high - low),
        false,
        pen,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BatteryArc old) =>
      start != old.start || end != old.end || color != old.color;
}
