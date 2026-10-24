import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'api.dart';
import 'charging_detail_contract.g.dart' as dto;
import 'currency.dart';
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
        throw const FormatException();
      }
      setState(() {
        detail = value;
        unavailable = false;
        ownershipMismatch = false;
      });
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

  Future<void> loadSeries({bool force = false}) async {
    if (!current) return;
    final attempt = ++seriesSequence;
    setState(() {
      seriesLoading = true;
      seriesError = null;
    });
    try {
      final result = await workspace.cache.get(
        owner,
        'charging-sessions/${widget.id}/series',
        query: {'fields': 'power,soc', 'points': '200'},
        force: force,
      );
      final value = dto.ChargingSessionSeries.fromJson(result.body);
      if (!current || attempt != seriesSequence) return;
      if (value.sessionId != widget.id) throw const FormatException();
      if (!ownershipMismatch) setState(() => series = value);
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
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.currency,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text('充电详情 #${widget.id}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '车辆 ID $vehicle · 时区：${workspace.calendar?.identifier ?? 'UTC'}',
            ),
            const Text('历史结果只读；— 表示缺失，不代表零。'),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('充电明细', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  onPressed: detailLoading
                      ? null
                      : () => loadDetail(force: true),
                  icon: const Icon(Icons.refresh),
                  tooltip: '刷新充电明细',
                ),
              ],
            ),
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
              Text(d.isActive ? '充电进行中，当前指标不代表最终结果' : '充电已结束'),
              Text(
                d.location.displayName?.trim().isNotEmpty == true
                    ? d.location.displayName!
                    : '未知地点',
              ),
              if (d.location.geofence != null)
                Text('围栏：${d.location.geofence}'),
              if (d.location.address != null &&
                  d.location.address != d.location.displayName)
                Text('地址：${d.location.address}'),
              Text('开始 ${time(d.startedAt)}'),
              Text('结束 ${time(d.endedAt)}'),
              Text(
                d.isDc == null
                    ? '分类未知'
                    : d.isDc!
                    ? 'DC'
                    : 'AC',
              ),
              Text('电量 ${number(d.startSoc, '%')} → ${number(d.endSoc, '%')}'),
              Text('充入电池 ${number(d.energyAddedKwh, 'kWh')}'),
              Text('电网侧 ${number(d.energyUsedKwh, 'kWh')}'),
              Text('费用 ${widget.currency.amount(d.cost)}'),
              Text('时长 ${number(d.durationMin, '分钟')}'),
              Text(
                '平均外温 ${number(d.outsideTempCAvg, '°C', temperature: true)}',
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('充电曲线', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  onPressed: seriesLoading
                      ? null
                      : () => loadSeries(force: true),
                  icon: const Icon(Icons.refresh),
                  tooltip: '刷新充电曲线',
                ),
              ],
            ),
            if (seriesLoading) const LinearProgressIndicator(),
            if (seriesError != null) ...[
              Semantics(liveRegion: true, child: Text(seriesError!)),
              TextButton(
                onPressed: seriesLoading ? null : () => loadSeries(force: true),
                child: const Text('重试充电曲线'),
              ),
            ],
            if (!ownershipMismatch && series != null)
              ChargingCurve(
                key: ValueKey('${widget.id}:${identityHashCode(series)}'),
                series: series!,
                calendar: workspace.calendar!,
              ),
          ],
        ),
      ),
    ),
  );
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
  int? selected;
  num? value(dto.ChargePoint p) => power ? p.power : p.soc;
  String get unit => power ? 'kW' : '%';
  String stamp(dto.ChargePoint p) =>
      widget.calendar.local(p.t).toString().split('.').first;
  String reading(dto.ChargePoint p) =>
      '${stamp(p)} · ${value(p) == null ? '—（缺失）' : '${decimal(value(p)!)} $unit'}';
  @override
  Widget build(BuildContext context) {
    final points = widget.series.series;
    final valid = points.where((p) => value(p) != null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
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
        Text('服务端采样 ${widget.series.points} 点 · 当前指标有效 $valid 点'),
        const Text('真实时间轴；低强调连线仅示意采样，不代表连续观测。缺失值断线，不补点、不补零；采样峰值不等同原始峰值。'),
        if (points.isEmpty) const Text('此充电没有序列采样'),
        if (points.isNotEmpty && valid < 2) const Text('有效采样不足两点，仅显示可用点与读数'),
        if (points.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) => Semantics(
              label: '${power ? '功率' : '电量'}随真实时间变化的采样曲线；下方可逐点读取',
              child: GestureDetector(
                onTapDown: (event) {
                  final earliest = points
                      .map((p) => p.t.microsecondsSinceEpoch)
                      .reduce(math.min);
                  final latest = points
                      .map((p) => p.t.microsecondsSinceEpoch)
                      .reduce(math.max);
                  final fraction =
                      ((event.localPosition.dx - 16) /
                              (constraints.maxWidth - 32))
                          .clamp(0.0, 1.0);
                  final target = earliest + (latest - earliest) * fraction;
                  var index = 0;
                  for (var i = 1; i < points.length; i++) {
                    if ((points[i].t.microsecondsSinceEpoch - target).abs() <
                        (points[index].t.microsecondsSinceEpoch - target)
                            .abs()) {
                      index = i;
                    }
                  }
                  setState(() => selected = index);
                },
                child: SizedBox(
                  key: const Key('charging-time-chart'),
                  height: 180,
                  child: CustomPaint(
                    painter: _ChargingPainter(
                      points,
                      power,
                      Theme.of(context).colorScheme.primary,
                      selected,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (points.isNotEmpty)
          Text('${stamp(points.first)} → ${stamp(points.last)}'),
        if (selected != null)
          Semantics(
            liveRegion: true,
            child: Text('选中 ${reading(points[selected!])}'),
          ),
        const Text('点选曲线或以下文字采样记录读取数值'),
        for (var i = 0; i < points.length; i++)
          TextButton(
            onPressed: () => setState(() => selected = i),
            child: Text(reading(points[i])),
          ),
      ],
    );
  }
}

class _ChargingPainter extends CustomPainter {
  _ChargingPainter(this.points, this.power, this.color, this.selected);
  final List<dto.ChargePoint> points;
  final bool power;
  final Color color;
  final int? selected;
  num? value(dto.ChargePoint p) => power ? p.power : p.soc;
  @override
  void paint(Canvas canvas, Size size) {
    final values = points.map(value).whereType<num>().toList();
    if (values.isEmpty) return;
    final minTime = points
        .map((p) => p.t.microsecondsSinceEpoch)
        .reduce(math.min);
    final maxTime = points
        .map((p) => p.t.microsecondsSinceEpoch)
        .reduce(math.max);
    final minValue = values.reduce(math.min),
        maxValue = values.reduce(math.max);
    final stroke = Paint()
      ..color = color.withValues(alpha: .45)
      ..strokeWidth = 1.5;
    Offset? previous;
    for (var i = 0; i < points.length; i++) {
      final v = value(points[i]);
      if (v == null) {
        previous = null;
        continue;
      }
      final x = maxTime == minTime
          ? size.width / 2
          : 16 +
                (points[i].t.microsecondsSinceEpoch - minTime) /
                    (maxTime - minTime) *
                    (size.width - 32);
      final y = maxValue == minValue
          ? size.height / 2
          : size.height -
                16 -
                (v - minValue) / (maxValue - minValue) * (size.height - 32);
      final point = Offset(x, y);
      if (previous != null) canvas.drawLine(previous, point, stroke);
      canvas.drawCircle(point, selected == i ? 5 : 2.5, Paint()..color = color);
      previous = point;
    }
  }

  @override
  bool shouldRepaint(covariant _ChargingPainter old) =>
      old.points != points ||
      old.power != power ||
      old.color != color ||
      old.selected != selected;
}
