import 'package:flutter/material.dart';

import 'api.dart';
import 'charging_cost.dart';
import 'copy/dates.dart' as copy;
import 'copy/durations.dart' as copy;
import 'copy/messages.dart' as messages;

import 'design/components/components.dart';
import 'design/icons.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'charging_detail_contract.g.dart' as dto;
import 'charging_experience_contract.g.dart' as expanded;
import 'currency.dart';
import 'workspace.dart';
import 'map/map_consent.dart';
import 'map/map_panel.dart';
import 'map/map_platform.dart';
import 'map/map_scene.dart';

Future<void> openChargingDetail(
  BuildContext context,
  VehicleWorkspace workspace,
  CurrencySettings currency,
  int id, {
  MapConsentController? mapConsent,
  MapPlatform? mapPlatform,
}) => Navigator.push<void>(
  context,
  MaterialPageRoute(
    builder: (_) => ChargingDetailPage(
      workspace: workspace,
      currency: currency,
      id: id,
      mapConsent: mapConsent,
      mapPlatform: mapPlatform,
    ),
  ),
);

class ChargingDetailPage extends StatefulWidget {
  const ChargingDetailPage({
    super.key,
    required this.workspace,
    required this.currency,
    required this.id,
    this.mapConsent,
    this.mapPlatform,
  });
  final VehicleWorkspace workspace;
  final CurrencySettings currency;
  final int id;
  final MapConsentController? mapConsent;
  final MapPlatform? mapPlatform;
  @override
  State<ChargingDetailPage> createState() => _ChargingDetailPageState();
}

class _ChargingDetailPageState extends State<ChargingDetailPage>
    with WidgetsBindingObserver {
  VehicleWorkspace get workspace => widget.workspace;
  late final owner = workspace.session.current!;
  late final vehicle = workspace.selectedId!;
  late final _mapConsent = widget.mapConsent ?? MapConsentController();
  late final _mapPlatform = widget.mapPlatform ?? defaultMapPlatform();
  dto.ChargingSessionDetail? detail;
  dto.ChargingSessionSeries? series;
  expanded.ChargingSessionDetail? expandedDetail;
  expanded.ChargingSessionSeries? expandedSeries;
  String? detailError, seriesError;
  DateTime? detailCheckedAt, seriesCheckedAt;
  bool detailLoading = false,
      seriesLoading = false,
      unavailable = false,
      leaving = false,
      ownershipMismatch = false;
  int detailSequence = 0, seriesSequence = 0;
  String processMetric = 'power';
  bool costSupported = false;
  bool costSheetOpen = false;
  bool get current =>
      mounted &&
      workspace.session.isCurrent(owner) &&
      workspace.selectedId == vehicle;
  @override
  void initState() {
    super.initState();
    workspace.addListener(changed);
    workspace.addCostReader(refreshCost);
    WidgetsBinding.instance.addObserver(this);
    loadDetail();
    loadSeries();
    loadCostCapability();
  }

  Future<void> loadCostCapability() async {
    try {
      final meta = await workspace.cache.get(owner, 'meta');
      if (current) {
        setState(
          () => costSupported = supportsChargingCost(meta.body['version']),
        );
      }
    } catch (_) {
      // Older or unreachable sites remain fully readable.
    }
  }

  Future<void> fillCost() async {
    if (costSheetOpen || !current) return;
    costSheetOpen = true;
    await showChargingCostSheet(context, workspace, widget.currency, widget.id);
    costSheetOpen = false;
  }

  Future<bool> refreshCost() async {
    if (!current) return true;
    await loadDetail(force: true, refreshSeries: false);
    return detailError == null;
  }

  @override
  void dispose() {
    detailSequence++;
    seriesSequence++;
    workspace.removeListener(changed);
    workspace.removeCostReader(refreshCost);
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

  /// CP07：失败有旧数据用共享构造函数说明快照时间；技术原因进说明层。
  String failure(
    Object error, {
    required bool snapshot,
    required String object,
    DateTime? checkedAt,
  }) {
    if (snapshot && checkedAt != null) {
      return messages.staleMessage(
        workspace.calendar!.local(checkedAt),
        workspace.calendar!.local(workspace.session.now()),
      );
    }
    return error is FormatException
        ? messages.versionIncompatibleMessage()
        : error is ApiFailure
        ? error.message
        : messages.readFailedMessage(object);
  }

  Future<void> loadDetail({
    bool force = false,
    bool refreshSeries = true,
  }) async {
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
        detailCheckedAt = result.checkedAt;
        unavailable = false;
        ownershipMismatch = false;
      });
      if (additional != null && refreshSeries) loadSeries(extended: true);
    } catch (error) {
      if (current && attempt == detailSequence) {
        setState(() {
          unavailable = error is BusinessFailure && error.status == 404;
          detailError = unavailable
              ? '该充电记录已不可用，可返回上一页'
              : failure(
                  error,
                  snapshot: detail != null,
                  object: '充电明细',
                  checkedAt: detailCheckedAt,
                );
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
          seriesCheckedAt = result.checkedAt;
        });
      }
    } catch (error) {
      if (current && attempt == seriesSequence) {
        setState(
          () => seriesError = failure(
            error,
            snapshot: series != null,
            object: '充电曲线',
            checkedAt: seriesCheckedAt,
          ),
        );
      }
    } finally {
      if (current && attempt == seriesSequence) {
        setState(() => seriesLoading = false);
      }
    }
  }

  String number(num? value, String unit, {bool temperature = false}) =>
      value == null
      ? '—'
      : '${temperature ? value.toStringAsFixed(1) : decimal(value)} $unit';
  String time(DateTime? value) => value == null
      ? '—'
      : workspace.calendar!.local(value).toString().split('.').first;
  String precise(DateTime? value) => value == null
      ? '—'
      : copy.formatPrecise(workspace.calendar!.local(value));
  String windowReason(String status) => switch (status) {
    'incomplete_session' => '充电进行中',
    'insufficient_samples' => '有效电量采样不足',
    'not_reached' => '未记录到所需电量区间',
    'gap_or_ambiguous' => '采样间隔或电量变化不足以确认',
    _ => '数据不足',
  };

  /// R24 模块卡：卡与卡之间 12 间距；P05 每张卡内边 16。
  Widget _card(Widget child) => _inset(
    Padding(
      padding: const EdgeInsets.only(bottom: MileafSpace.s12),
      child: MileafModuleCard(child: child),
    ),
  );

  Widget _inset(Widget child) =>
      Padding(padding: MileafLayout.pageHorizontal(context), child: child);

  DateTime get _today => workspace.calendar!.local(workspace.session.now());

  /// CP04 身份行：10月26日 周一 06:10–06:44。
  String _when(dto.ChargingSessionDetail d) {
    final start = workspace.calendar!.local(d.startedAt);
    // 身份行要绝对日期：用早三天的参照日让 formatDayGroup 走「M月D日 周X」分支，
    // 不写成「今天/昨天」，且在同年内不带年。
    final day = copy.formatDayGroup(
      start,
      start.subtract(const Duration(days: 3)),
    );
    if (d.endedAt == null) return '$day ${copy.formatTime(start)} 起';
    final end = workspace.calendar!.local(d.endedAt!);
    return '$day ${copy.formatTimeRange(start, end, today: _today)}';
  }

  Widget _identity(dto.ChargingSessionDetail d) {
    final type = context.type;
    final name = d.location.displayName?.trim() ?? '';
    return _inset(
      Padding(
        padding: const EdgeInsets.only(
          top: MileafSpace.s8,
          bottom: MileafSpace.s16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.isEmpty ? '未知地点' : name,
              style: type.title2.copyWith(color: context.colors.text),
            ),
            const SizedBox(height: MileafSpace.s4),
            Text(
              _when(d),
              style: type.subheadline.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stateLine(dto.ChargingSessionDetail d) => Text(
    d.isActive ? '充电中，已充入 ${number(d.energyAddedKwh, 'kWh')}，结束后计入统计' : '已结束',
    style: context.type.footnote.copyWith(color: context.colors.textSecondary),
  );

  /// P05 电量卡：电量环 + 起始到结束 + 状态 + 类型标签，分隔线之下三格。
  Widget _socCard(dto.ChargingSessionDetail d) {
    final colors = context.colors;
    final type = context.type;
    final large = MileafLayout.largeText(context);
    final fillable =
        d.cost == null &&
        costSupported &&
        !ownershipMismatch &&
        !unavailable &&
        canFillChargingCost(
          cost: d.cost,
          active: d.isActive,
          endedAt: d.endedAt,
          added: d.energyAddedKwh,
          used: d.energyUsedKwh,
        );
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (large) ...[
            Text(
              '${d.startSoc ?? '—'}% → ${d.endSoc ?? '—'}%',
              style: type.metricMd.copyWith(color: colors.text),
            ),
            const SizedBox(height: MileafSpace.s8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _socArc(d, large: true),
                const SizedBox(width: MileafSpace.s12),
                Expanded(child: _stateLine(d)),
                if (d.isDc != null) StatusChip(label: d.isDc! ? 'DC' : 'AC'),
              ],
            ),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _socArc(d, large: false),
                const SizedBox(width: MileafSpace.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${d.startSoc ?? '—'}% → ${d.endSoc ?? '—'}%',
                        style: type.metricMd.copyWith(color: colors.text),
                      ),
                      const SizedBox(height: MileafSpace.s4),
                      _stateLine(d),
                    ],
                  ),
                ),
                if (d.isDc != null) StatusChip(label: d.isDc! ? 'DC' : 'AC'),
              ],
            ),
          const SizedBox(height: MileafSpace.s12),
          Container(height: 1, color: colors.line),
          const SizedBox(height: MileafSpace.s12),
          if (large)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final cell in _plates(d, fillable: fillable))
                  Padding(
                    padding: const EdgeInsets.only(bottom: MileafSpace.s8),
                    child: cell,
                  ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (index, cell) in _plates(
                  d,
                  fillable: fillable,
                ).indexed) ...[
                  if (index > 0) const SizedBox(width: MileafSpace.s12),
                  Expanded(child: cell),
                ],
              ],
            ),
          if (widget.currency.amountNote case final note?) ...[
            const SizedBox(height: MileafSpace.s8),
            Text(note, style: type.footnote.copyWith(color: colors.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _socArc(dto.ChargingSessionDetail d, {required bool large}) =>
      BatteryArc(
        level: d.endSoc,
        start: d.startSoc,
        label: '',
        showLabel: true,
        size: large
            ? MileafBatteryMetrics.largeTextSize
            : MileafBatteryMetrics.size,
        semanticsLabel: '结束电量 ${d.endSoc ?? '—'}%',
      );

  /// P05 / R21.5：三格同排，仅用 metricSm；大字时改成一列。
  List<Widget> _plates(dto.ChargingSessionDetail d, {required bool fillable}) =>
      [
        MetricBlock(
          label: '充入电量',
          value: d.energyAddedKwh == null ? null : decimal(d.energyAddedKwh!),
          unit: 'kWh',
          scale: MetricValueScale.metricSm,
        ),
        _costCell(d, fillable: fillable),
        MetricBlock(
          label: '时长',
          value: d.durationMin == null
              ? null
              : copy.duration(Duration(minutes: d.durationMin!.round())),
          scale: MetricValueScale.metricSm,
        ),
      ];

  Widget _costCell(dto.ChargingSessionDetail d, {required bool fillable}) {
    final colors = context.colors;
    final type = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('费用', style: type.subheadline.copyWith(color: colors.textFaint)),
        const SizedBox(height: MileafSpace.s4),
        if (fillable)
          Align(
            alignment: Alignment.centerLeft,
            child: StatusChip(
              label: '补录',
              onTap: fillCost,
              semanticLabel: '补录费用',
            ),
          )
        else
          // 读屏读成「费用 12」，与旧结果行一致（语义不随版式丢失）。
          Semantics(
            label: '费用 ${widget.currency.amountValue(d.cost)}',
            excludeSemantics: true,
            child: MileafNumber(
              value: widget.currency.amountValue(d.cost),
              scale: MetricValueScale.metricSm,
            ),
          ),
      ],
    );
  }

  /// P05 充电过程卡：标题与指标控件在读数头之上，绘图区 200、步进圆钮。
  Widget _processCard() {
    final points = expandedSeries?.series;
    final basic = series?.series ?? const <dto.ChargePoint>[];
    // 图表按站点墙钟时间作图与写轴（R29 + CP04）：先把 UTC 采样换成本地墙钟。
    final times = <DateTime>[
      if (points != null)
        for (final point in points) workspace.calendar!.local(point.t)
      else
        for (final point in basic) workspace.calendar!.local(point.t),
    ];
    final power = <num?>[
      if (points != null)
        for (final point in points) point.power
      else
        for (final point in basic) point.power,
    ];
    final soc = <num?>[
      if (points != null)
        for (final point in points) point.soc
      else
        for (final point in basic) point.soc,
    ];
    final fields =
        expandedSeries?.capabilities.fields ?? const <String, bool>{};
    final extras = <String, (String, String, List<num?>)>{
      for (final entry in const [
        ('voltage_v', '电压', 'V'),
        ('actual_current_a', '实际电流', 'A'),
        ('pilot_current_a', '引导电流', 'A'),
        ('outside_temp_c', '室外温度', '°C'),
        ('rated_range_km', '额定续航', 'km'),
        ('ideal_range_km', '理想续航', 'km'),
        ('charge_energy_added_kwh', '累计充入', 'kWh'),
      ])
        if (points != null && fields[entry.$1] == true)
          entry.$1: (
            entry.$2,
            entry.$3,
            [
              for (final point in points)
                switch (entry.$1) {
                  'voltage_v' => point.voltageV,
                  'actual_current_a' => point.actualCurrentA,
                  'pilot_current_a' => point.pilotCurrentA,
                  'outside_temp_c' => point.outsideTempC,
                  'rated_range_km' => point.ratedRangeKm,
                  'ideal_range_km' => point.idealRangeKm,
                  _ => point.chargeEnergyAddedKwh,
                },
            ],
          ),
    };
    final extra = extras[processMetric];
    final label = switch (processMetric) {
      'power' => '功率',
      'soc' => '电量',
      _ => extra?.$1 ?? '功率',
    };
    final unit = switch (processMetric) {
      'power' => 'kW',
      'soc' => '%',
      _ => extra?.$2 ?? 'kW',
    };
    final values = switch (processMetric) {
      'power' => power,
      'soc' => soc,
      _ => extra?.$3 ?? power,
    };
    return _card(
      TimeSeriesChart(
        title: '充电过程',
        unit: unit,
        times: times,
        series: [ChartSeries(label: label, values: values)],
        semanticsLabel: '$label充电曲线',
        plotKey: const Key('charging-time-chart'),
        height: MileafSpace.detailChartHeight,
        showYAxis: true,
        yRange: processMetric == 'soc' ? (0, 100) : null,
        tickLabel: copy.formatAxisTime,
        readoutDate: copy.formatAxisTime,
        readoutScale: ChartReadoutScale.detail,
        emptyMessage: '这次充电没有采样点',
        headerTrailing: ChipRow(
          children: [
            StatusChip(
              label: '功率',
              selected: processMetric == 'power',
              onTap: () => setState(() => processMetric = 'power'),
            ),
            StatusChip(
              label: '电量',
              selected: processMetric == 'soc',
              onTap: () => setState(() => processMetric = 'soc'),
            ),
            for (final entry in extras.entries)
              StatusChip(
                label: entry.value.$1,
                selected: processMetric == entry.key,
                onTap: () => setState(() => processMetric = entry.key),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mapCard(dto.ChargingSessionDetail d) => _group(
    title: '充电地点',
    rows: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          MileafSpace.cardPad,
          0,
          MileafSpace.cardPad,
          MileafSpace.cardPad,
        ),
        child: MapPanel(
          key: ValueKey(
            'charging-map:${owner.generation}:$vehicle:${widget.id}',
          ),
          scene: placeScene(
            location: MapCoordinate(
              d.location.lat?.toDouble(),
              d.location.lon?.toDouble(),
            ),
            brightness: Theme.of(context).brightness,
            interactive: false,
          ),
          consent: _mapConsent,
          platform: _mapPlatform,
          height: MileafLayout.mapHeight(context, normal: 180),
          borderRadius: BorderRadius.circular(MileafRadius.lg),
        ),
      ),
    ],
  );

  /// 分组标题 + 分组卡 + 可选脚注。
  Widget _group({
    required String title,
    required List<Widget> rows,
    String? footnote,
    EdgeInsetsGeometry padding = const EdgeInsets.only(bottom: MileafSpace.s16),
  }) => _inset(
    Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MileafGroupHeader(title: title),
          const SizedBox(height: MileafSpace.s8),
          MileafGroupCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...rows,
                if (footnote != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MileafSpace.cardPad,
                      MileafSpace.s8,
                      MileafSpace.cardPad,
                      MileafSpace.s12,
                    ),
                    child: Text(
                      footnote,
                      style: context.type.footnote.copyWith(
                        color: context.colors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  /// D-AP07-05 同类处理：大字时行尾值移到第二行，避免 320/360 下溢出。
  Widget _factRow({
    required String title,
    String? value,
    bool bottomLine = false,
  }) {
    final large = MileafLayout.largeText(context);
    return MileafGroupRow(
      title: title,
      value: large ? null : value,
      meta: large ? value : null,
      bottomLine: bottomLine,
    );
  }

  Widget _energyCard(dto.ChargingSessionDetail d) => _group(
    title: '电量计量',
    rows: [
      _factRow(title: '充入电池', value: number(d.energyAddedKwh, 'kWh')),
      _factRow(
        title: '电网用电',
        value: d.energyUsedKwh == null
            ? '—'
            : '${d.energyUsedKwh!.toStringAsFixed(2)} kWh',
        bottomLine: true,
      ),
    ],
    footnote: '两项分别计量，不能相加。',
  );

  Widget _costCard(dto.ChargingSessionDetail d) {
    final extra = expandedDetail!;
    return _group(
      title: '费用明细',
      rows: [
        _factRow(title: '已记录费用', value: widget.currency.amountValue(d.cost)),
        _factRow(
          title: '每度充入电',
          value:
              '${widget.currency.amountValue(extra.unitCostAdded?.value)}/kWh',
        ),
        _factRow(
          title: '每度电网用电',
          value:
              '${widget.currency.amountValue(extra.unitCostGrid?.value)}/kWh',
          bottomLine: true,
        ),
      ],
      footnote: '均价按对应电量计，仅含有费用的充电；费用未知不代表免费。',
    );
  }

  Widget _vehicleCard(dto.ChargingSessionDetail d) {
    final extra = expandedDetail!;
    final fields = extra.capabilities?.fields ?? const <String, bool>{};
    String? range(num? start, num? end, String field) => fields[field] == true
        ? '${number(start, 'km')} → ${number(end, 'km')}'
        : '未受站点支持';
    return _group(
      title: '车辆与环境',
      rows: [
        _factRow(
          title: '室外温度均值',
          value: number(d.outsideTempCAvg, '°C', temperature: true),
        ),
        _factRow(
          title: '额定续航',
          value: range(
            extra.startRatedRangeKm,
            extra.endRatedRangeKm,
            'start_rated_range_km',
          ),
        ),
        _factRow(
          title: '理想续航',
          value: range(
            extra.startIdealRangeKm,
            extra.endIdealRangeKm,
            'start_ideal_range_km',
          ),
        ),
        _factRow(title: '充电器品牌', value: extra.charger?.fastChargerBrand ?? '—'),
        _factRow(title: '充电器类型', value: extra.charger?.fastChargerType ?? '—'),
        _factRow(title: '充电线', value: extra.charger?.connChargeCable ?? '—'),
        if (extra.charger?.sourceSampleAt != null)
          _factRow(
            title: '充电器记录时间',
            value: time(extra.charger!.sourceSampleAt),
          ),
      ],
      footnote: '温度为室外均值；续航是额定或理想口径，不代表实际可达距离。',
    );
  }

  /// P05 电池加热：图例行写开启、关闭、未知，脚注说明时间重叠。
  Widget _heaterCard(dto.ChargingSessionDetail d) {
    final events = [
      for (final event
          in expandedSeries?.stateEvents?.events ??
              const <expanded.StateEvent>[])
        if (event.field == 'battery_heater' ||
            event.field == 'battery_heater_on')
          event,
    ]..sort((a, b) => a.t.compareTo(b.t));
    final spans = <String, Duration>{};
    if (events.isNotEmpty) {
      for (var index = 0; index < events.length; index++) {
        final from = events[index].t;
        final to = index + 1 < events.length
            ? events[index + 1].t
            : (d.endedAt ?? workspace.session.now());
        if (!to.isAfter(from)) continue;
        final label = switch (events[index].value) {
          true => '开启',
          false => '关闭',
          null => '未知',
        };
        spans[label] = (spans[label] ?? Duration.zero) + to.difference(from);
      }
    }
    return _group(
      title: '电池加热',
      rows: [
        for (final label in const ['开启', '关闭', '未知'])
          _factRow(
            title: label,
            value: spans[label] == null ? '—' : copy.duration(spans[label]!),
            bottomLine: label == '未知',
          ),
      ],
      footnote: events.isEmpty ? '没有记录到电池加热的状态变化。' : '时间重叠的记录可展开查看。',
    );
  }

  Widget _notes(dto.ChargingSessionDetail d) {
    final process = expandedDetail?.processMetrics;
    final windows = [
      for (final window in process?.socWindows ?? const <expanded.SocWindow>[])
        !d.isActive &&
                window.status == 'available' &&
                window.elapsedSeconds != null
            ? '${window.thresholdPrecision == 'exact' ? '记录达到' : '记录跨越'} ${window.startObservedSoc ?? '—'}% → ${window.endObservedSoc ?? '—'}%，用时 ${decimal(window.elapsedSeconds! / 60)} 分钟'
            : '20% → 80% 用时暂不可用：${windowReason(d.isActive ? 'incomplete_session' : window.status)}',
    ];
    return MileafDataNotes(
      groups: [
        MileafDataNoteGroup(
          category: DataNoteCategory.caliber,
          note: process == null
              ? '原始充电过程指标暂不可用；— 表示缺失，不代表零。'
              : '服务器返回 ${process.powerValidSamples} 个有效功率采样，覆盖 ${decimal(process.observedSeconds)} 秒、未覆盖 ${decimal(process.uncoveredSeconds)} 秒；— 表示缺失，不代表零。',
        ),
        if (windows.isNotEmpty)
          MileafDataNoteGroup(
            category: DataNoteCategory.records,
            note: windows.join('；'),
          ),
        MileafDataNoteGroup(
          category: DataNoteCategory.time,
          note:
              '时间按站点时区（${workspace.calendar?.identifier ?? 'UTC'}）显示；历史数据按站点记录归属。',
        ),
        MileafDataNoteGroup(
          category: DataNoteCategory.source,
          note: '结果来自原始记录；抽样曲线不用于计算峰值或时长。',
        ),
        MileafDataNoteGroup(
          category: DataNoteCategory.technical,
          note: [
            '原始功率峰值 ${number(process?.powerMaxKw, 'kW')}',
            '记录平均功率 ${number(process?.powerTimeWeightedKw, 'kW')}',
            '记录编号 ${d.id}',
            '开始 ${precise(d.startedAt)}',
            '结束 ${precise(d.endedAt)}',
            if (d.location.geofence != null) '围栏 ${d.location.geofence}',
            if (d.location.address != null &&
                d.location.address != d.location.displayName)
              '地址 ${d.location.address}',
            '充电相数 ${d.chargerPhasesMode ?? '—'}',
            '序列分辨率 ${series?.resolution ?? '—'}',
          ].join('；'),
          copyable: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.currency,
    builder: (context, _) => Scaffold(
      appBar: mileafPageBar(
        context,
        title: const Text('充电详情'),
        actions: [
          MileafIconButton(
            icon: MileafIconName.refresh,
            tooltip: '刷新充电明细',
            fill: MileafIconButtonFill.track,
            onPressed: detailLoading
                ? null
                : () async {
                    // P05 只留一个刷新：明细与曲线一起更新（AU13）。
                    await loadDetail(force: true, refreshSeries: false);
                    loadSeries(force: true);
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: MileafContent(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (detailLoading || seriesLoading) const MileafProgressLine(),
              if (detailError != null)
                _inset(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(liveRegion: true, child: Text(detailError!)),
                      if (!unavailable)
                        TextButton(
                          onPressed: detailLoading
                              ? null
                              : () => loadDetail(force: true),
                          child: const Text('重试'),
                        ),
                    ],
                  ),
                ),
              if (unavailable)
                _inset(
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('返回上一页'),
                    ),
                  ),
                ),
              if (detail case final d?) ...[_identity(d), _socCard(d)],
              if (seriesError != null)
                _inset(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(liveRegion: true, child: Text(seriesError!)),
                      TextButton(
                        onPressed: seriesLoading
                            ? null
                            : () => loadSeries(force: true),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              if (!ownershipMismatch &&
                  (series != null || expandedSeries != null))
                _processCard(),
              if (detail case final d?) ...[
                _mapCard(d),
                _energyCard(d),
                if (expandedDetail != null) ...[_costCard(d), _vehicleCard(d)],
                _heaterCard(d),
                _inset(
                  Padding(
                    padding: const EdgeInsets.only(
                      top: MileafSpace.s8,
                      bottom: MileafSpace.s24,
                    ),
                    child: _notes(d),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
