import 'package:flutter/material.dart';

import 'api.dart';
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
  });
  final VehicleWorkspace workspace;
  final int id;
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
      if (current && attempt == detailSequence) setState(() => detail = d);
    } catch (e) {
      if (current && attempt == detailSequence) {
        setState(() => detailError = error(e, detail != null));
      }
    } finally {
      if (current && attempt == detailSequence) {
        setState(() => detailLoading = false);
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
      if (current && attempt == seriesSequence) setState(() => series = d);
    } catch (e) {
      if (current && attempt == seriesSequence) {
        setState(() => seriesError = error(e, series != null));
      }
    } finally {
      if (current && attempt == seriesSequence) {
        setState(() => seriesLoading = false);
      }
    }
  }

  String number(num? value, String unit, {int decimals = 0}) =>
      value == null ? '—（缺失）' : '${value.toStringAsFixed(decimals)} $unit';
  String time(DateTime t) =>
      workspace.calendar!.local(t).toString().split('.').first;
  String place(String? p) => p == null || p.trim().isEmpty ? '未知地点' : p;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('行程 #${widget.id}')),
    body: RefreshIndicator(
      onRefresh: () => Future.wait([loadDetail(), loadSeries()]),
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '行程明细',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: '刷新行程明细',
                onPressed: detailLoading ? null : loadDetail,
                icon: const Icon(Icons.refresh),
              ),
            ],
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
          if (detail case final d?) ...[
            Text(
              '${time(d.startedAt)} → ${d.endedAt == null ? '进行中' : time(d.endedAt!)}',
            ),
            Text('${place(d.start.displayName)} → ${place(d.end.displayName)}'),
            Text('距离 ${number(d.distanceKm, 'km', decimals: 1)}'),
            Text('时长 ${number(d.durationMin, '分钟')}'),
            Text('净电耗 ${number(d.consumptionWhKm, 'Wh/km')}'),
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
          const Divider(),
          const Text('地图将在后续地图切片接入'),
          const Divider(),
          Row(
            children: [
              Expanded(
                child: Text(
                  '行程采样',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: '刷新行程采样',
                onPressed: seriesLoading ? null : loadSeries,
                icon: const Icon(Icons.refresh),
              ),
            ],
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
        ],
      ),
    ),
  );
}
