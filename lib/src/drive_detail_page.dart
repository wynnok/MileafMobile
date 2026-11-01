import 'dart:async';

import 'package:flutter/material.dart';

import 'number_format.dart';

import 'api.dart';
import 'data_cards.dart';

import 'design/components/components.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'performance_trace.dart';
import 'map/drive_map_page.dart';
import 'map/map_consent.dart';
import 'map/map_panel.dart';
import 'map/map_platform.dart';
import 'map/map_scene.dart';
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
    this.mapConsent,
    this.mapPlatform,
  });
  final VehicleWorkspace workspace;
  final MapConsentController? mapConsent;
  final MapPlatform? mapPlatform;
  final int id;
  final int? performanceTrial;
  final VoidCallback? onReturnToList;
  @override
  State<DriveDetailPage> createState() => _DriveDetailPageState();
}

/// 过程图可选指标：标签、图卡标题与单位在一处定义，避免并行数组各改一处。
const _sampleMetrics = [
  (label: '速度', title: '速度过程', unit: 'km/h'),
  (label: '电量', title: '电量过程', unit: '%'),
  (label: '海拔', title: '海拔过程', unit: 'm'),
];

class _DriveDetailPageState extends State<DriveDetailPage>
    with WidgetsBindingObserver {
  late final SiteSession owner;
  late final int vehicle;
  late final _mapConsent = widget.mapConsent ?? MapConsentController();
  late final _mapPlatform = widget.mapPlatform ?? defaultMapPlatform();
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
    final ref = _referenceUsable(d)
        ? reference!.totals.consumptionWhKmNet
        : null;
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
    final line = Row(
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
                    const Text('样本覆盖情况未知；路线、温度和交通可能不同，不能据此判断驾驶好坏或耗电原因。'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line,
        if (referenceLoading) const LinearProgressIndicator(),
        if (referenceError != null)
          Row(
            children: [
              Expanded(child: Text('个人历史参照：$referenceError', style: style)),
              TextButton(
                onPressed: () => loadReference(d, force: true),
                child: const Text('重试历史参照'),
              ),
            ],
          ),
      ],
    );
  }

  String shortDay(DateTime t) {
    final d = workspace.calendar!.local(t);
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String place(String? p) => p == null || p.trim().isEmpty ? '未知地点' : p;
  MapScene _mapScene({required bool interactive}) {
    final points = series?.series ?? const <dto.DrivePoint>[];
    final selected = points.isEmpty
        ? null
        : MapCoordinate(
            points[selectedSample].lat?.toDouble(),
            points[selectedSample].lon?.toDouble(),
          );
    return driveScene(
      coordinates: [
        for (final point in points)
          MapCoordinate(point.lat?.toDouble(), point.lon?.toDouble()),
      ],
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
      selected: selected,
      selectedLabel: points.isEmpty
          ? null
          : '选中采样位置 ${time(points[selectedSample].t)}',
      brightness: Theme.of(context).brightness,
      interactive: interactive,
    );
  }

  void _openFullMap(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => DriveMapPage(
          scene: _mapScene(interactive: true),
          consent: _mapConsent,
          platform: _mapPlatform,
        ),
      ),
    );
  }

  Widget _coverageBand(dto.DriveDetail d) {
    final colors = context.colors;
    final type = context.type;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MileafLayout.pageInset(context),
        MileafSpace.s12,
        MileafLayout.pageInset(context),
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${shortDay(d.startedAt)} · 最近行程',
            style: type.micro.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: MileafSpace.s4),
          Text(
            '${place(d.start.displayName)} → ${place(d.end.displayName)}',
            style: type.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: MileafSpace.s4),
          Text(
            '${time(d.startedAt)} → ${d.endedAt == null ? '进行中' : time(d.endedAt!)}'
            ' · ${number(d.distanceKm, 'km', decimals: 1)}'
            ' · ${number(d.durationMin, '分钟')}',
            style: type.body.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: MileafSpace.s4),
          Text(
            '路线示意 · 非导航',
            style: type.micro.copyWith(color: colors.textFaint),
          ),
        ],
      ),
    );
  }

  Widget _results(dto.DriveDetail d) {
    final cells = [
      MetricBlock(
        label: '距离',
        value: number(d.distanceKm, 'km', decimals: 1).replaceAll(' km', ''),
        unit: d.distanceKm == null ? null : 'km',
        scale: MetricValueScale.metricMd,
        semanticLabel: '距离 ${number(d.distanceKm, 'km', decimals: 1)}',
      ),
      MetricBlock(
        label: '时长',
        value: d.durationMin == null ? '—' : '${d.durationMin}',
        unit: d.durationMin == null ? null : '分钟',
        scale: MetricValueScale.metricMd,
        semanticLabel: '时长 ${number(d.durationMin, '分钟')}',
      ),
      MetricBlock(
        label: '净电耗',
        value: d.consumptionWhKm == null ? '—' : grouped(d.consumptionWhKm!),
        unit: d.consumptionWhKm == null ? null : 'Wh/km',
        scale: MetricValueScale.metricMd,
        semanticLabel: '净电耗 ${number(d.consumptionWhKm, 'Wh/km')}',
      ),
    ];
    if (MileafLayout.largeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cells[0]),
              const SizedBox(width: MileafSpace.s16),
              Expanded(child: cells[1]),
            ],
          ),
          const SizedBox(height: MileafSpace.s20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cells[2]),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: cells[0]),
        const SizedBox(width: MileafSpace.s16),
        Expanded(child: cells[1]),
        const SizedBox(width: MileafSpace.s16),
        Expanded(child: cells[2]),
      ],
    );
  }

  Widget _batterySection(dto.DriveDetail d) {
    final colors = context.colors;
    final type = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: '行程电量区间'),
        const SizedBox(height: MileafSpace.s8),
        SocInterval(start: d.start.batteryLevel, end: d.end.batteryLevel),
        if (d.endedAt != null &&
            d.start.batteryLevel != null &&
            d.end.batteryLevel != null)
          Text(
            '电量${d.start.batteryLevel! >= d.end.batteryLevel! ? '下降' : '增加'} '
            '${(d.start.batteryLevel! - d.end.batteryLevel!).abs()} 个百分点',
            style: type.micro.copyWith(color: colors.textMuted),
          ),
      ],
    );
  }

  Widget _techSection(dto.DriveDetail d) {
    final colors = context.colors;
    final type = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: '驾驶与环境'),
        const SizedBox(height: MileafSpace.s4),
        Text(
          '平均速度 ${number(d.speedAvgKmh, 'km/h')}',
          style: type.body.copyWith(color: colors.text),
        ),
        Text(
          '最高速度 ${number(d.speedMaxKmh, 'km/h')}',
          style: type.body.copyWith(color: colors.text),
        ),
        Text(
          '车外均温 ${number(d.outsideTempCAvg, '°C', decimals: 1)}',
          style: type.body.copyWith(color: colors.text),
        ),
        Text(
          '车内均温 ${number(d.insideTempCAvg, '°C', decimals: 1)}',
          style: type.body.copyWith(color: colors.text),
        ),
        Text(
          '最大功率 ${number(d.powerMaxKw, 'kW')}',
          style: type.body.copyWith(color: colors.text),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(
            '更多行程指标',
            style: type.body.copyWith(color: colors.textMuted),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${time(d.startedAt)} → ${d.endedAt == null ? '进行中' : time(d.endedAt!)}',
                    style: type.micro.copyWith(color: colors.textMuted),
                  ),
                  for (final endpoint in [('起点', d.start), ('终点', d.end)]) ...[
                    if (endpoint.$2.geofence?.trim().isNotEmpty == true &&
                        endpoint.$2.geofence != endpoint.$2.displayName)
                      Text(
                        '${endpoint.$1}围栏：${endpoint.$2.geofence}',
                        style: type.micro.copyWith(color: colors.textMuted),
                      ),
                    if (endpoint.$2.address?.trim().isNotEmpty == true &&
                        endpoint.$2.address != endpoint.$2.displayName &&
                        endpoint.$2.address != endpoint.$2.geofence)
                      Text(
                        '${endpoint.$1}地址：${endpoint.$2.address}',
                        style: type.micro.copyWith(color: colors.textMuted),
                      ),
                  ],
                  Text(
                    '净能量 ${number(d.energyKwh, 'kWh', decimals: 2)}',
                    style: type.micro.copyWith(color: colors.textMuted),
                  ),
                  Text(
                    '起点电量 ${number(d.start.batteryLevel, '%')}',
                    style: type.micro.copyWith(color: colors.textMuted),
                  ),
                  Text(
                    '终点电量 ${number(d.end.batteryLevel, '%')}',
                    style: type.micro.copyWith(color: colors.textMuted),
                  ),
                  Text(
                    '续航口径：${d.rangeKind == 'rated'
                        ? '额定'
                        : d.rangeKind == 'ideal'
                        ? '理想（ideal）'
                        : '未知'}；以上为服务端公制结果，未二次换算',
                    style: type.micro.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final inset = MileafLayout.pageInset(context);
    final large = MileafLayout.largeText(context);
    return Scaffold(
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
              MapPanel(
                key: ValueKey('map:${owner.generation}:$vehicle:${widget.id}'),
                scene: _mapScene(interactive: false),
                consent: _mapConsent,
                platform: _mapPlatform,
                height: large ? 240 : 320,
                borderRadius: BorderRadius.zero,
                onExpand: () => _openFullMap(context),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(inset, MileafSpace.s8, inset, 0),
                child: Text(
                  '行程地图',
                  style: context.type.micro.copyWith(
                    color: context.colors.textFaint,
                  ),
                ),
              ),
              if (detail case final d?) _coverageBand(d),
              if (detailLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: MileafProgressLine(),
                ),
              if (detailError != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(inset, MileafSpace.s8, inset, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InlineBanner(
                        message: detailError!,
                        tone: BannerTone.error,
                        actionLabel: '重试行程明细',
                        onAction: loadDetail,
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            widget.onReturnToList?.call();
                            Navigator.pop(context);
                          },
                          child: const Text('返回行程列表'),
                        ),
                      ),
                    ],
                  ),
                ),
              if (seriesLoading && series == null)
                Padding(
                  padding: EdgeInsets.fromLTRB(inset, MileafSpace.s8, inset, 0),
                  child: Text(
                    '正在读取轨迹采样',
                    style: context.type.micro.copyWith(
                      color: context.colors.textMuted,
                    ),
                  ),
                ),
              if (seriesError != null && series == null)
                Padding(
                  padding: EdgeInsets.fromLTRB(inset, MileafSpace.s8, inset, 0),
                  child: Text(
                    '轨迹采样暂不可用，可在行程采样区域重试',
                    style: context.type.micro.copyWith(
                      color: context.colors.textMuted,
                    ),
                  ),
                ),
              if (detail case final d?)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    MileafSpace.s20,
                    inset,
                    0,
                  ),
                  child: _results(d),
                ),
              if (seriesLoading)
                Padding(
                  padding: EdgeInsets.fromLTRB(inset, MileafSpace.s8, inset, 0),
                  child: const MileafProgressLine(),
                ),
              if (seriesError != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(inset, MileafSpace.s8, inset, 0),
                  child: InlineBanner(
                    message: seriesError!,
                    tone: BannerTone.error,
                    actionLabel: '重试行程采样',
                    onAction: loadSeries,
                  ),
                ),
              if (series case final s?)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    MileafSpace.section,
                    inset,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (s.resolution != 'server_sampled')
                        Text(
                          '无采样数据',
                          style: context.type.body.copyWith(
                            color: context.colors.textMuted,
                          ),
                        ),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        shape: const Border(),
                        collapsedShape: const Border(),
                        title: Text(
                          '采样数据说明',
                          style: context.type.body.copyWith(
                            color: context.colors.textMuted,
                          ),
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              s.resolution == 'server_sampled'
                                  ? '服务端采样 ${s.points} 点'
                                  : '无采样数据',
                              style: context.type.micro.copyWith(
                                color: context.colors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: MileafSpace.s8,
                        runSpacing: MileafSpace.s8,
                        children: [
                          for (var i = 0; i < _sampleMetrics.length; i++)
                            StatusChip(
                              label: _sampleMetrics[i].label,
                              selected: metric == i,
                              onTap: () => setState(() => metric = i),
                            ),
                        ],
                      ),
                      const SizedBox(height: MileafSpace.s12),
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
                        label: _sampleMetrics[metric].label,
                        title: _sampleMetrics[metric].title,
                        subtitle: '点按图形读值',
                        unit: _sampleMetrics[metric].unit,
                        timestamp: time,
                        selectedIndex: selectedSample,
                        onSelected: (i) => setState(() => selectedSample = i),
                      ),
                      if (metric != 1)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => setState(() => paired = !paired),
                            child: Text(paired ? '收起电量对照' : '对照电量'),
                          ),
                        ),
                      if (paired && metric != 1)
                        SampleChart(
                          points: [
                            for (final p in s.series) (p.t, p.batteryLevel),
                          ],
                          label: '电量',
                          subtitle: '点按图形读值',
                          unit: '%',
                          timestamp: time,
                          selectedIndex: selectedSample,
                          onSelected: (i) => setState(() => selectedSample = i),
                          plotKey: const ValueKey('paired-sample-chart'),
                        ),
                    ],
                  ),
                ),
              if (detail case final d?)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    MileafSpace.section,
                    inset,
                    0,
                  ),
                  child: _batterySection(d),
                ),
              if (detail case final d?)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    MileafSpace.section,
                    inset,
                    0,
                  ),
                  child: _techSection(d),
                ),
              if (detail case final d?)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    MileafSpace.s20,
                    inset,
                    MileafSpace.s24,
                  ),
                  child: _consumptionFootnote(context, d),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
