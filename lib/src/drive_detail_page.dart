import 'dart:async';

import 'package:flutter/material.dart';

import 'number_format.dart';

import 'api.dart';
import 'data_cards.dart';
import 'collage.dart';
import 'performance_trace.dart';
import 'map_candidate.dart';
import 'drive_detail_contract.g.dart' as dto;
import 'driving_statistics_contract.g.dart' as stats;
import 'sample_chart.dart';
import 'session.dart';
import 'workspace.dart';

class DriveDetailPage extends StatefulWidget {
  const DriveDetailPage({
    super.key,
    required this.workspace,
    required this.id,
    this.onReturnToList,
    this.performanceTrial,
    this.mapConfiguration,
  });
  final VehicleWorkspace workspace;
  final MapConfiguration? mapConfiguration;
  final int id;
  final int? performanceTrial;
  final VoidCallback? onReturnToList;
  @override
  State<DriveDetailPage> createState() => _DriveDetailPageState();
}

class _DriveDetailPageState extends State<DriveDetailPage>
    with WidgetsBindingObserver {
  late final SiteSession owner;
  late final int vehicle;
  dto.DriveDetail? detail;
  dto.DriveSeries? series;
  String? detailError, seriesError;
  bool detailLoading = false, seriesLoading = false;
  stats.DrivingStats? reference;
  String? referenceError;
  bool referenceLoading = false, paired = false;
  int referenceSequence = 0, selectedSample = 0;
  DateTime? referenceFrom, referenceTo;
  String? referenceZone;
  int detailSequence = 0, seriesSequence = 0, metric = 0;
  bool performanceReady = false;
  final defaultCurveKey = GlobalKey();
  final viewportKey = GlobalKey();
  bool get curveVisible {
    final curve = defaultCurveKey.currentContext?.findRenderObject();
    final viewport = viewportKey.currentContext?.findRenderObject();
    if (curve is! RenderBox ||
        viewport is! RenderBox ||
        !curve.hasSize ||
        !viewport.hasSize) {
      return false;
    }
    final rect = curve.localToGlobal(Offset.zero) & curve.size;
    final view = viewport.localToGlobal(Offset.zero) & viewport.size;
    return rect.height > 0 &&
        rect.width > 0 &&
        rect.top >= view.top &&
        rect.bottom <= view.bottom;
  }

  VehicleWorkspace get workspace => widget.workspace;
  @override
  void initState() {
    super.initState();
    owner = workspace.session.current!;
    vehicle = workspace.selectedId!;
    workspace.addListener(changed);
    WidgetsBinding.instance.addObserver(this);
    loadDetail();
    loadSeries();
  }

  bool get current =>
      mounted &&
      workspace.session.isCurrent(owner) &&
      workspace.selectedId == vehicle;
  void changed() {
    if (!current) {
      detailSequence++;
      seriesSequence++;
      referenceSequence++;
      setState(() {
        detail = null;
        series = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
    } else if (referenceZone != null &&
        referenceZone != workspace.calendar?.identifier) {
      referenceSequence++;
      setState(() {
        reference = null;
        referenceError = null;
        referenceLoading = false;
      });
      if (detail case final d?) unawaited(loadReference(d));
    }
  }

  @override
  void dispose() {
    workspace.removeListener(changed);
    WidgetsBinding.instance.removeObserver(this);
    detailSequence++;
    seriesSequence++;
    referenceSequence++;
    super.dispose();
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
      await Future.wait([loadDetail(force: false), loadSeries(force: false)]);
    }
  }

  String error(Object e, bool snapshot) =>
      '${e is ApiFailure
          ? e.message
          : e is FormatException
          ? '服务返回格式不兼容，请核对版本'
          : '数据读取失败，请重试'}${snapshot ? '；保留上次快照' : ''}';
  Future<void> loadDetail({bool force = true}) async {
    final attempt = ++detailSequence;
    setState(() {
      detailLoading = true;
      detailError = null;
    });
    try {
      final r = await workspace.cache.get(
        owner,
        'drives/${widget.id}',
        force: force,
      );
      final d = dto.DriveDetail.fromJson(r.body);
      if (d.id != widget.id || d.vehicleId != vehicle) {
        throw const FormatException();
      }
      if (current && attempt == detailSequence) {
        setState(() => detail = d);
        unawaited(loadReference(d, force: force));
        PerformanceTrace.mark(
          PerformancePoint.driveMetricsAvailable,
          trial: widget.performanceTrial,
        );
      }
    } catch (e) {
      if (current && attempt == detailSequence) {
        setState(() => detailError = error(e, detail != null));
        PerformanceTrace.mark(
          PerformancePoint.driveFailed,
          trial: widget.performanceTrial,
        );
      }
    } finally {
      if (current && attempt == detailSequence) {
        setState(() => detailLoading = false);
        traceReady();
      }
    }
  }

  Future<void> loadSeries({bool force = true}) async {
    final attempt = ++seriesSequence;
    setState(() {
      seriesLoading = true;
      seriesError = null;
    });
    try {
      final r = await workspace.cache.get(
        owner,
        'drives/${widget.id}/series',
        query: {'fields': 'speed,battery,elevation', 'points': '200'},
        force: force,
      );
      final d = dto.DriveSeries.fromJson(r.body);
      if (d.driveId != widget.id || d.points != d.series.length) {
        throw const FormatException();
      }
      if (current && attempt == seriesSequence) {
        setState(() {
          series = d;
          selectedSample = selectedSample.clamp(
            0,
            d.series.isEmpty ? 0 : d.series.length - 1,
          );
        });
        PerformanceTrace.mark(
          PerformancePoint.driveSeriesAvailable,
          trial: widget.performanceTrial,
        );
      }
    } catch (e) {
      if (current && attempt == seriesSequence) {
        setState(() => seriesError = error(e, series != null));
        PerformanceTrace.mark(
          PerformancePoint.driveFailed,
          trial: widget.performanceTrial,
        );
      }
    } finally {
      if (current && attempt == seriesSequence) {
        setState(() => seriesLoading = false);
        traceReady();
      }
    }
  }

  Future<void> loadReference(dto.DriveDetail d, {bool force = false}) async {
    final attempt = ++referenceSequence;
    final calendar = workspace.calendar!;
    if (d.endedAt == null ||
        d.consumptionWhKm == null ||
        d.distanceKm == null ||
        d.distanceKm! <= 0) {
      if (current) {
        setState(() {
          reference = null;
          referenceError = null;
          referenceLoading = false;
        });
      }
      return;
    }
    final day = calendar.local(d.startedAt);
    final first = DateTime(day.year, day.month, day.day - 30);
    final last = DateTime(day.year, day.month, day.day);
    final from = calendar.midnight(first), to = calendar.midnight(last);
    final query = {
      'kind': 'driving',
      'bucket': 'day',
      'tz': calendar.identifier,
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
    };
    bool valid() =>
        current &&
        attempt == referenceSequence &&
        workspace.calendar?.identifier == calendar.identifier &&
        detail?.startedAt == d.startedAt;
    setState(() {
      referenceLoading = true;
      referenceError = null;
      if (referenceFrom != from ||
          referenceTo != to ||
          referenceZone != calendar.identifier) {
        reference = null;
      }
      referenceZone = calendar.identifier;
    });
    try {
      final value = await workspace.cache.get(
        owner,
        'vehicles/$vehicle/stats',
        query: query,
        force: force,
      );
      final decoded = stats.DrivingStats.fromJson(value.body);
      if (valid()) {
        setState(() {
          reference = decoded;
          referenceFrom = from;
          referenceTo = to;
        });
      }
    } catch (e) {
      if (valid()) setState(() => referenceError = error(e, reference != null));
    } finally {
      if (valid()) setState(() => referenceLoading = false);
    }
  }

  void traceReady() {
    if (!PerformanceTrace.enabled ||
        performanceReady ||
        detail == null ||
        series == null ||
        detailLoading ||
        seriesLoading ||
        detailError != null ||
        seriesError != null ||
        metric != 0) {
      return;
    }
    PerformanceTrace.driveFrame(
      widget.performanceTrial,
      () =>
          current &&
          detail != null &&
          series != null &&
          detailError == null &&
          seriesError == null &&
          metric == 0 &&
          curveVisible &&
          !performanceReady &&
          (ModalRoute.of(context)?.isCurrent ?? false) &&
          (performanceReady = true),
    );
  }

  String number(num? value, String unit, {int decimals = 0}) =>
      value == null ? '—（缺失）' : '${grouped(value, decimals: decimals)} $unit';
  String time(DateTime t) =>
      workspace.calendar!.local(t).toString().split('.').first;

  /// True only when CandidateMap can actually draw tiles: a usable provider,
  /// an approved CRS and at least one coordinate. Otherwise the route caption
  /// is rendered as a fallback band so it never disappears (C05).
  bool get _mapRenderable {
    final config = widget.mapConfiguration;
    final provider = config?.provider;
    if (config == null ||
        provider == null ||
        !provider.isUsable ||
        config.sourceCrs != 'EPSG:4326' ||
        provider.coordinateSystem != config.sourceCrs) {
      return false;
    }
    final d = detail;
    final hasEndpoint = d != null && d.start.lat != null && d.start.lon != null;
    final hasSample = series?.series.any((p) => p.lat != null) ?? false;
    return hasEndpoint || hasSample;
  }

  bool _referenceUsable(dto.DriveDetail d) {
    final r = reference;
    return d.endedAt != null &&
        d.consumptionWhKm != null &&
        referenceZone == workspace.calendar?.identifier &&
        r != null &&
        r.totals.drives > 0 &&
        r.totals.distanceKm > 0 &&
        r.totals.consumptionWhKmNet != null;
  }

  /// 单行口径提示：本次电耗与个人 30 日整体参照并排说明，替代旧的对比卡。
  Widget _consumptionFootnote(BuildContext context, dto.DriveDetail d) {
    final style = Theme.of(context).textTheme.bodySmall;
    final ref = _referenceUsable(d) ? reference!.totals.consumptionWhKmNet : null;
    final buffer = StringBuffer('本次 ${number(d.consumptionWhKm, 'Wh/km')}');
    if (ref != null) {
      buffer.write(
        '，参考净电耗 ${number(ref, 'Wh/km')}'
        '（此前30个完整本地日 · 全部路线；服务端估算，样本覆盖未知）',
      );
    } else {
      buffer.write('，个人历史参照不可用');
    }
    buffer.write('；缺失不补点。');
    final text = Text(buffer.toString(), style: style);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ref == null
              ? text
              : Semantics(
                  container: true,
                  label: '参考净电耗 ${number(ref, 'Wh/km')}',
                  child: ExcludeSemantics(child: text),
                ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: '电耗参照说明',
          icon: const Icon(Icons.info_outline, size: 18),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('电耗参照说明'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '本次净电耗与历史参考均为服务端估算。历史参考为行程开始日前30个完整本地日、同车全部路线的整体净电耗，不含本次。',
                    ),
                    if (referenceFrom != null && referenceTo != null)
                      Text(
                        '参考区间：${time(referenceFrom!)} 至 ${time(referenceTo!)}（不含结束时刻）；归期时区：$referenceZone',
                      ),
                    const Text(
                      '样本覆盖情况未知；路线、温度和交通可能不同，不能据此判断驾驶好坏或耗电原因。',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('知道了'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _routeLines(dto.DriveDetail d) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '${shortDay(d.startedAt)} · 最近行程',
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
      Text(
        '${place(d.start.displayName)} → ${place(d.end.displayName)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      Text(
        '${time(d.startedAt)} → ${d.endedAt == null ? '进行中' : time(d.endedAt!)}',
        style: const TextStyle(color: Colors.white70, fontSize: 11),
      ),
      const Text(
        '路线示意 · 非导航',
        style: TextStyle(color: Colors.white60, fontSize: 11),
      ),
    ],
  );

  String shortDay(DateTime t) {
    final d = workspace.calendar!.local(t);
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String place(String? p) => p == null || p.trim().isEmpty ? '未知地点' : p;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('行程 #${widget.id}'),
      actions: [
        IconButton(
          tooltip: '刷新行程明细',
          onPressed: detailLoading ? null : loadDetail,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: '刷新行程采样',
          onPressed: seriesLoading ? null : loadSeries,
          icon: const Icon(Icons.show_chart),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () => Future.wait([loadDetail(), loadSeries()]),
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          traceReady();
          return false;
        },
        child: ListView(
          key: viewportKey,
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              width: double.infinity,
              child: CandidateMap(
                key: ValueKey('map:${owner.generation}:$vehicle:${widget.id}'),
                provider: widget.mapConfiguration?.provider,
                sourceCrs: widget.mapConfiguration?.sourceCrs,
                tileClient: widget.mapConfiguration?.tileClient,
                selected: series == null || series!.series.isEmpty
                    ? null
                    : MapCoordinate(
                        series!.series[selectedSample].lat?.toDouble(),
                        series!.series[selectedSample].lon?.toDouble(),
                      ),
                selectedLabel: series == null || series!.series.isEmpty
                    ? null
                    : '选中采样位置 ${time(series!.series[selectedSample].t)}',
                start: detail == null
                    ? null
                    : MapCoordinate(
                        detail!.start.lat?.toDouble(),
                        detail!.start.lon?.toDouble(),
                      ),
                end: detail == null
                    ? null
                    : MapCoordinate(
                        detail!.end.lat?.toDouble(),
                        detail!.end.lon?.toDouble(),
                      ),
                coordinates: [
                  for (final point in series?.series ?? <dto.DrivePoint>[])
                    MapCoordinate(point.lat?.toDouble(), point.lon?.toDouble()),
                ],
                heroHeight: detail == null || !_mapRenderable ? null : 300,
                overlay: detail == null || !_mapRenderable
                    ? null
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.62),
                            ],
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 30, 16, 14),
                          child: _routeLines(detail!),
                        ),
                      ),
              ),
            ),
            ...<Widget>[
              Text('行程地图', style: Theme.of(context).textTheme.labelSmall),
              if (!_mapRenderable && detail != null)
                CollageTile(
                  surface: CollageSurface.hero,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: _routeLines(detail!),
                ),
              if (detailLoading) const LinearProgressIndicator(),
              if (detailError != null) ...[
                Semantics(liveRegion: true, child: Text(detailError!)),
                TextButton(onPressed: loadDetail, child: const Text('重试行程明细')),
                TextButton(
                  onPressed: () {
                    widget.onReturnToList?.call();
                    Navigator.pop(context);
                  },
                  child: const Text('返回行程列表'),
                ),
              ],
              const SizedBox(height: 12),

              if (seriesLoading && series == null) const Text('正在读取轨迹采样'),
              if (seriesError != null && series == null)
                const Text('轨迹采样暂不可用，可在行程采样区域重试'),
              if (detail case final d?)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final large =
                        MediaQuery.textScalerOf(context).scale(12) > 18;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in [
                          ('距离', number(d.distanceKm, 'km', decimals: 1)),
                          ('时长', number(d.durationMin, '分钟')),
                          ('净电耗', number(d.consumptionWhKm, 'Wh/km')),
                        ])
                          SizedBox(
                            width: large
                                ? constraints.maxWidth
                                : (constraints.maxWidth - 16) / 3,
                            child: CollageTile(
                              padding: const EdgeInsets.all(10),
                              child: MetricTile(
                                label: entry.$1,
                                value: entry.$2,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              if (seriesLoading) const LinearProgressIndicator(),
              if (seriesError != null) ...[
                Semantics(liveRegion: true, child: Text(seriesError!)),
                TextButton(onPressed: loadSeries, child: const Text('重试行程采样')),
              ],
              if (series case final s?) ...[
                if (s.resolution != 'server_sampled') const Text('无采样数据'),
                ExpansionTile(
                  title: const Text('采样数据说明'),
                  children: [
                    Text(
                      s.resolution == 'server_sampled'
                          ? '服务端采样 ${s.points} 点'
                          : '无采样数据',
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < 3; i++)
                      ChoiceChip(
                        label: Text(['速度', '电量', '海拔'][i]),
                        selected: metric == i,
                        onSelected: (_) => setState(() => metric = i),
                      ),
                  ],
                ),
                SampleChart(
                  plotObserverKey: defaultCurveKey,
                  points: [
                    for (final p in s.series)
                      (
                        p.t,
                        switch (metric) {
                          0 => p.speedKmh,
                          1 => p.batteryLevel,
                          _ => p.elevationM,
                        },
                      ),
                  ],
                  label: ['速度', '电量', '海拔'][metric],
                  unit: ['km/h', '%', 'm'][metric],
                  timestamp: time,
                  selectedIndex: selectedSample,
                  onSelected: (i) => setState(() => selectedSample = i),
                ),
                if (metric != 1)
                  TextButton(
                    onPressed: () => setState(() => paired = !paired),
                    child: Text(paired ? '收起电量对照' : '对照电量'),
                  ),
                if (paired && metric != 1)
                  SampleChart(
                    points: [for (final p in s.series) (p.t, p.batteryLevel)],
                    label: '电量',
                    unit: '%',
                    timestamp: time,
                    selectedIndex: selectedSample,
                    onSelected: (i) => setState(() => selectedSample = i),
                    plotKey: const ValueKey('paired-sample-chart'),
                  ),
              ],
              if (detail case final d?) ...[
                CollageTile(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '行程电量区间',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      SocInterval(
                        start: d.start.batteryLevel,
                        end: d.end.batteryLevel,
                      ),
                      if (d.endedAt != null &&
                          d.start.batteryLevel != null &&
                          d.end.batteryLevel != null)
                        Text(
                          '电量${d.start.batteryLevel! >= d.end.batteryLevel! ? '下降' : '增加'} ${(d.start.batteryLevel! - d.end.batteryLevel!).abs()} 个百分点',
                        ),
                    ],
                  ),
                ),
              ],
              if (detail case final d?) ...[
                CollageTile(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '驾驶与环境',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      MetricGrid(
                        children: [
                          Text('平均速度 ${number(d.speedAvgKmh, 'km/h')}'),
                          Text('最高速度 ${number(d.speedMaxKmh, 'km/h')}'),
                          Text(
                            '车外均温 ${number(d.outsideTempCAvg, '°C', decimals: 1)}',
                          ),
                          Text(
                            '车内均温 ${number(d.insideTempCAvg, '°C', decimals: 1)}',
                          ),
                          Text('最大功率 ${number(d.powerMaxKw, 'kW')}'),
                        ],
                      ),
                    ],
                  ),
                ),
                CollageTile(
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('更多行程指标'),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    childrenPadding: const EdgeInsets.only(top: 12),
                    children: [
                      Text(
                        '${time(d.startedAt)} → ${d.endedAt == null ? '进行中' : time(d.endedAt!)}',
                      ),
                      for (final endpoint in [
                        ('起点', d.start),
                        ('终点', d.end),
                      ]) ...[
                        if (endpoint.$2.geofence?.trim().isNotEmpty == true &&
                            endpoint.$2.geofence != endpoint.$2.displayName)
                          Text('${endpoint.$1}围栏：${endpoint.$2.geofence}'),
                        if (endpoint.$2.address?.trim().isNotEmpty == true &&
                            endpoint.$2.address != endpoint.$2.displayName &&
                            endpoint.$2.address != endpoint.$2.geofence)
                          Text('${endpoint.$1}地址：${endpoint.$2.address}'),
                      ],
                      Text('净能量 ${number(d.energyKwh, 'kWh', decimals: 2)}'),
                      Text('起点电量 ${number(d.start.batteryLevel, '%')}'),
                      Text('终点电量 ${number(d.end.batteryLevel, '%')}'),
                      Text(
                        '续航口径：${d.rangeKind == 'rated'
                            ? '额定'
                            : d.rangeKind == 'ideal'
                            ? '理想（ideal）'
                            : '未知'}；以上为服务端公制结果，未二次换算',
                      ),
                    ],
                  ),
                ),
                _consumptionFootnote(context, d),
              ],
            ].map(
              (child) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: child,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
