import 'package:flutter/material.dart';

import 'api.dart';
import 'data_cards.dart';
import 'performance_trace.dart';
import 'map_candidate.dart';
import 'drive_detail_contract.g.dart' as dto;
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
  int detailSequence = 0, seriesSequence = 0, metric = 0;
  bool performanceReady = false;
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
      setState(() {
        detail = null;
        series = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
    }
  }

  @override
  void dispose() {
    workspace.removeListener(changed);
    WidgetsBinding.instance.removeObserver(this);
    detailSequence++;
    seriesSequence++;
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
        setState(() => series = d);
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
    performanceReady = true;
    PerformanceTrace.driveFrame(
      widget.performanceTrial,
      () =>
          current &&
          detail != null &&
          series != null &&
          detailError == null &&
          seriesError == null &&
          metric == 0 &&
          (ModalRoute.of(context)?.isCurrent ?? false),
    );
  }

  String number(num? value, String unit, {int decimals = 0}) =>
      value == null ? '—（缺失）' : '${value.toStringAsFixed(decimals)} $unit';
  String time(DateTime t) =>
      workspace.calendar!.local(t).toString().split('.').first;
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
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
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
          if (detail case final d?)
            DataCard(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final large = MediaQuery.textScalerOf(context).scale(12) > 18;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${place(d.start.displayName)} → ${place(d.end.displayName)}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (d.endedAt == null) const Text('进行中'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final entry in [
                            ('距离', number(d.distanceKm, 'km', decimals: 1)),
                            ('时长', number(d.durationMin, '分钟')),
                            ('净电耗', number(d.consumptionWhKm, 'Wh/km')),
                          ])
                            SizedBox(
                              width: large
                                  ? constraints.maxWidth
                                  : (constraints.maxWidth - 24) / 3,
                              child: Text.rich(
                                TextSpan(
                                  text: '${entry.$1} ',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium,
                                  children: [
                                    TextSpan(
                                      text: entry.$2,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          if (seriesLoading) const LinearProgressIndicator(),
          if (seriesError != null) ...[
            Semantics(liveRegion: true, child: Text(seriesError!)),
            TextButton(onPressed: loadSeries, child: const Text('重试行程采样')),
          ],
          if (series case final s?) ...[
            Text(
              s.resolution == 'server_sampled'
                  ? '服务端采样 ${s.points} 点'
                  : '无采样数据',
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
            ),
          ],
          const SizedBox(height: 12),
          Text('行程地图', style: Theme.of(context).textTheme.titleLarge),
          if (seriesLoading && series == null) const Text('正在读取轨迹采样'),
          if (seriesError != null && series == null)
            const Text('轨迹采样暂不可用，可在行程采样区域重试'),
          CandidateMap(
            key: ValueKey('map:${owner.generation}:$vehicle:${widget.id}'),
            provider: widget.mapConfiguration?.provider,
            sourceCrs: widget.mapConfiguration?.sourceCrs,
            tileClient: widget.mapConfiguration?.tileClient,
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
          ),
          if (detail case final d?) ...[
            DataCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('行程电量区间', style: Theme.of(context).textTheme.titleSmall),
                  SocInterval(
                    start: d.start.batteryLevel,
                    end: d.end.batteryLevel,
                  ),
                ],
              ),
            ),
            DataCard(
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('更多行程指标'),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                childrenPadding: const EdgeInsets.only(top: 12),
                children: [
                  Text(
                    '${time(d.startedAt)} → ${d.endedAt == null ? '进行中' : time(d.endedAt!)}',
                  ),
                  for (final endpoint in [('起点', d.start), ('终点', d.end)]) ...[
                    if (endpoint.$2.geofence?.trim().isNotEmpty == true &&
                        endpoint.$2.geofence != endpoint.$2.displayName)
                      Text('${endpoint.$1}围栏：${endpoint.$2.geofence}'),
                    if (endpoint.$2.address?.trim().isNotEmpty == true &&
                        endpoint.$2.address != endpoint.$2.displayName &&
                        endpoint.$2.address != endpoint.$2.geofence)
                      Text('${endpoint.$1}地址：${endpoint.$2.address}'),
                  ],
                  Text('净能量 ${number(d.energyKwh, 'kWh', decimals: 2)}'),
                  Text('平均速度 ${number(d.speedAvgKmh, 'km/h')}'),
                  Text('最高速度 ${number(d.speedMaxKmh, 'km/h')}'),
                  Text('最大功率 ${number(d.powerMaxKw, 'kW')}'),
                  Text('车外均温 ${number(d.outsideTempCAvg, '°C', decimals: 1)}'),
                  Text('车内均温 ${number(d.insideTempCAvg, '°C', decimals: 1)}'),
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
          ],
        ],
      ),
    ),
  );
}
