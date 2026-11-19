import 'dart:async';

import 'package:flutter/material.dart';

import 'number_format.dart';

import 'api.dart';
import 'copy/dates.dart' as copy;
import 'copy/messages.dart' as messages;
import 'copy/units.dart' as units;

import 'design/components/components.dart';
import 'design/components/icons.dart';
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

/// 过程图可选指标：卡片标题是「行驶过程」，分段只切换指标（P04/R21.4）。
const _sampleLabels = ['速度', '电量', '海拔'];
const _sampleUnits = ['km/h', '%', 'm'];

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
  DateTime? detailCheckedAt, seriesCheckedAt;
  stats.DrivingStats? reference;
  String? referenceError;
  bool referenceLoading = false, batteryPaired = false;
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

  /// R27/PD10：详情页两个刷新合一。一次点按依次调用原明细与曲线两个刷新，
  /// 请求与原先分别点按两次相同；某个资源失败时只在该资源处就地重试。
  Future<void> refreshAll() async {
    await loadDetail();
    if (!mounted) return;
    await loadSeries();
  }

  String error(Object e, String object) {
    if (e is FormatException) return messages.versionIncompatibleMessage();
    if (e is ApiFailure) return e.message;
    return messages.readFailedMessage(object);
  }

  String _staleText(DateTime? snapshot) => messages.staleMessage(
    local(snapshot ?? workspace.session.now()),
    local(workspace.session.now()),
  );

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
        setState(() {
          detail = d;
          detailCheckedAt = r.checkedAt;
        });
        unawaited(loadReference(d, force: force));
        PerformanceTrace.mark(
          PerformancePoint.driveMetricsAvailable,
          trial: widget.performanceTrial,
        );
      }
    } catch (e) {
      if (current && attempt == detailSequence) {
        setState(
          () => detailError = detail == null
              ? error(e, '行程明细')
              : _staleText(detailCheckedAt),
        );
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
          seriesCheckedAt = r.checkedAt;
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
        setState(
          () => seriesError = series == null
              ? error(e, '行程数据')
              : _staleText(seriesCheckedAt),
        );
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
      if (valid()) {
        setState(
          () => referenceError = reference == null
              ? error(e, '近 30 天电耗')
              : _staleText(referenceFrom),
        );
      }
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
      value == null ? '—' : units.valueUnit(value, unit, decimals: decimals);
  String place(String? p) => p == null || p.trim().isEmpty ? '未知地点' : p;

  /// 站点日历可能在退出登录的那一帧被清掉；这一帧仍要能安全绘制。
  DateTime local(DateTime value) => workspace.calendar?.local(value) ?? value;
  String clock(DateTime value) => copy.formatTime(local(value));

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

  num? _sampleValue(dto.DrivePoint point) => switch (metric) {
    0 => point.speedKmh,
    1 => point.batteryLevel,
    _ => point.elevationM,
  };

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
          : '选中采样位置 ${clock(points[selectedSample].t)}',
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

  /// R25 二级页身份块（画布层）：路线 title2 + 一行 subheadline 元信息（CP04）。
  Widget _identity(dto.DriveDetail d) {
    final colors = context.colors;
    final type = context.type;
    final today = local(workspace.session.now());
    final start = local(d.startedAt);
    final end = d.endedAt == null ? null : local(d.endedAt!);
    final meta = end == null
        ? '${copy.formatDay(start, today)} ${copy.formatTime(start)}，进行中'
        : '${copy.formatDay(start, today)} '
              '${copy.formatTimeRange(start, end, today: today)}';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MileafLayout.pageInset(context),
        MileafSpace.s8,
        MileafLayout.pageInset(context),
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${place(d.start.displayName)} → ${place(d.end.displayName)}',
            style: type.title2.copyWith(color: colors.text),
          ),
          const SizedBox(height: MileafSpace.s4),
          Text(
            meta,
            style: type.subheadline.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// P04 地图卡：220 高、半径 20，卡下脚注说明路线示意（CP09 用逗号）。
  /// 首次加载还没有明细与轨迹时给同形骨架（R31），不说「没有有效轨迹坐标」。
  Widget _mapCard(BuildContext context) {
    final inset = MileafLayout.pageInset(context);
    final firstLoad = detail == null && series == null && seriesLoading;
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, MileafSpace.s12, inset, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (firstLoad)
            const SkeletonBlock(
              width: double.infinity,
              height: MapPanel.detailHeight,
            )
          else
            MapPanel(
              key: ValueKey('map:${owner.generation}:$vehicle:${widget.id}'),
              scene: _mapScene(interactive: false),
              consent: _mapConsent,
              platform: _mapPlatform,
              height: MapPanel.detailHeight,
              borderRadius: BorderRadius.circular(MileafRadius.lg),
              onExpand: () => _openFullMap(context),
            ),
          const SizedBox(height: MileafSpace.s8),
          Text(
            '路线示意，非导航路线',
            style: context.type.footnote.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// R21.5：详情页三列关键值只用 metricSm，放不下时网格自己收列。
  Widget _keyValues(dto.DriveDetail d) {
    final cells = [
      MetricBlock(
        label: '距离',
        // R22：数值与单位各占一个角色，值里不再重复单位。
        value: d.distanceKm == null
            ? null
            : grouped(d.distanceKm!, decimals: 1),
        unit: d.distanceKm == null ? null : 'km',
        scale: MetricValueScale.metricSm,
        semanticLabel: '距离 ${number(d.distanceKm, 'km', decimals: 1)}',
      ),
      MetricBlock(
        label: '时长',
        value: d.durationMin == null ? '—' : '${d.durationMin}',
        unit: d.durationMin == null ? null : '分钟',
        scale: MetricValueScale.metricSm,
        semanticLabel: '时长 ${number(d.durationMin, '分钟')}',
      ),
      MetricBlock(
        label: '电耗',
        value: d.consumptionWhKm == null ? '—' : grouped(d.consumptionWhKm!),
        unit: d.consumptionWhKm == null ? null : 'Wh/km',
        scale: MetricValueScale.metricSm,
        semanticLabel: '电耗 ${number(d.consumptionWhKm, 'Wh/km')}',
      ),
    ];
    return MetricGrid(spacing: MileafSpace.s12, children: cells);
  }

  Widget _segments() => ChipRow(
    children: [
      for (var i = 0; i < _sampleLabels.length; i++)
        StatusChip(
          label: _sampleLabels[i],
          selected: metric == i,
          onTap: () => setState(() => metric = i),
        ),
    ],
  );

  /// 过程曲线：完整读数头（R29，detail 尺度）+ 步进 + 绘图区 200。
  /// 读数头日期行用 CP04 DF9 时间级 HH:mm；精确时间进「关于这些数据」。
  Widget _processChart(dto.DriveSeries s) {
    // 图表按站点墙钟画轴与读数：数据点的时间是 UTC 瞬时，先换成站点日历，
    // 否则 X 轴会比读数头早 8 小时（与概览/行程节奏图同一处理）。
    final wall = [for (final point in s.series) local(point.t)];
    return KeyedSubtree(
      key: defaultCurveKey,
      child: TimeSeriesChart(
        // R21.4：卡片标题只写一次「行驶过程」，分段紧接标题，读数头在分段之下。
        title: '行驶过程',
        controls: _segments(),
        unit: _sampleUnits[metric],
        times: wall,
        series: [
          ChartSeries(
            label: _sampleLabels[metric],
            values: [for (final point in s.series) _sampleValue(point)],
          ),
        ],
        semanticsLabel: '${_sampleLabels[metric]}过程图表',
        height: MileafSpace.detailChartHeight,
        showYAxis: true,
        yRange: metric == 1 ? (0, 100) : null,
        selectedIndex: selectedSample,
        onSelected: (index) => setState(() => selectedSample = index),
        readoutScale: ChartReadoutScale.detail,
        readoutDate: copy.formatTime,
        plotKey: const ValueKey('sample-chart'),
        emptyMessage: '没有采样点',
      ),
    );
  }

  /// P04 行驶过程卡：卡片标题 + 分段 + 读数头与绘图区。
  Widget _processCard() {
    final colors = context.colors;
    final type = context.type;
    final s = series;
    return MileafModuleCard(
      // 交付手册 §6 退让阶梯第 1、2 步：卡片标题与图表标题只留一处，
      // 焦点卡内边 16 → 8（AP07 统计卡的同一取舍）。
      padding: const EdgeInsets.all(MileafSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (s == null && seriesLoading)
            const SkeletonBlock(width: double.infinity, height: 160),
          if (s == null && !seriesLoading && seriesError != null)
            InlineBanner(
              message: seriesError!,
              tone: BannerTone.error,
              actionLabel: '重试',
              onAction: loadSeries,
            ),
          if (s != null) _processChart(s),
          if (s != null && s.resolution != 'server_sampled')
            Padding(
              padding: const EdgeInsets.only(top: MileafSpace.s8),
              child: Text(
                '无采样数据',
                style: type.footnote.copyWith(color: colors.textSecondary),
              ),
            ),
          if (seriesLoading && s != null)
            const Padding(
              padding: EdgeInsets.only(top: MileafSpace.s8),
              child: MileafProgressLine(),
            ),
          if (seriesError != null && s != null)
            Padding(
              padding: const EdgeInsets.only(top: MileafSpace.s8),
              child: InlineBanner(
                message: seriesError!,
                tone: BannerTone.error,
                actionLabel: '重试',
                onAction: loadSeries,
              ),
            ),
          // CP07：单点与当前指标全空各有一个人话句，不画假的趋势。
          if (s != null && s.series.length == 1)
            Padding(
              padding: const EdgeInsets.only(top: MileafSpace.s8),
              child: Text(
                '只有 1 个数据点，无法画出变化',
                style: type.footnote.copyWith(color: colors.textSecondary),
              ),
            ),
          if (s != null &&
              s.series.isNotEmpty &&
              s.series.every((point) => _sampleValue(point) == null))
            Padding(
              padding: const EdgeInsets.only(top: MileafSpace.s8),
              child: Text(
                '这一项没有记录',
                style: type.footnote.copyWith(color: colors.textSecondary),
              ),
            ),
          // 电量对照是这张图的追加动作：上方 1px 分隔线把它与图表分开，
          // 展开后就地长出第二张图（P04 只改名称，结构不变）；切到电量指标时
          // 这一行卸载，切回时由页面状态恢复展开。
          if (s != null && metric != 1) ...[
            const SizedBox(height: MileafSpace.s12),
            MileafDisclosure(
              key: const ValueKey('battery-pair'),
              label: '同时查看电量',
              meta: '与行驶过程同屏',
              emphasis: true,
              topLine: true,
              expanded: batteryPaired,
              onExpandedChanged: (value) =>
                  setState(() => batteryPaired = value),
              child: TimeSeriesChart(
                title: '电量过程',
                unit: '%',
                times: [for (final point in s.series) local(point.t)],
                series: [
                  ChartSeries(
                    label: '电量',
                    values: [for (final point in s.series) point.batteryLevel],
                  ),
                ],
                semanticsLabel: '电量过程图表',
                height: MileafSpace.detailChartHeight,
                showYAxis: true,
                yRange: (0, 100),
                selectedIndex: selectedSample,
                onSelected: (index) => setState(() => selectedSample = index),
                readoutScale: ChartReadoutScale.detail,
                readoutDate: copy.formatTime,
                plotKey: const ValueKey('paired-sample-chart'),
                emptyMessage: '没有采样点',
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// P04 电量变化卡：区间端点 + 百分点差；未知端点不伪造补能或零。
  Widget _batteryCard(dto.DriveDetail d) {
    final colors = context.colors;
    final type = context.type;
    final known =
        d.endedAt != null &&
        d.start.batteryLevel != null &&
        d.end.batteryLevel != null;
    final delta = known
        ? (d.start.batteryLevel! - d.end.batteryLevel!).abs()
        : null;
    // CP03：增减只在句子里写「下降 / 增加」，不用箭头符号。
    final verb = !known
        ? null
        : (d.start.batteryLevel! >= d.end.batteryLevel! ? '下降' : '增加');
    return MileafModuleCard(
      padding: const EdgeInsets.all(MileafSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('电量变化', style: type.headline.copyWith(color: colors.text)),
          const SizedBox(height: MileafSpace.s12),
          SocIntervalBar(start: d.start.batteryLevel, end: d.end.batteryLevel),
          if (delta != null && verb != null) ...[
            const SizedBox(height: MileafSpace.s8),
            Text(
              '电量$verb $delta 个百分点',
              style: type.footnote.copyWith(color: colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  /// 驾驶与环境：字段名 / 值两列，数字右边缘落同一条竖线（事实表组件）。
  Widget _factsCard(dto.DriveDetail d) {
    String? value(num? raw, {int decimals = 0}) =>
        raw == null ? null : grouped(raw, decimals: decimals);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: '驾驶与环境'),
        const SizedBox(height: MileafSpace.s8),
        MileafFactList(
          key: const ValueKey('drive-facts'),
          facts: [
            MileafFact(
              label: '平均速度',
              value: value(d.speedAvgKmh),
              unit: 'km/h',
            ),
            MileafFact(
              label: '最高速度',
              value: value(d.speedMaxKmh),
              unit: 'km/h',
            ),
            MileafFact(
              label: '车外均温',
              value: value(d.outsideTempCAvg, decimals: 1),
              unit: '°C',
            ),
            MileafFact(
              label: '车内均温',
              value: value(d.insideTempCAvg, decimals: 1),
              unit: '°C',
            ),
            MileafFact(label: '最大功率', value: value(d.powerMaxKw), unit: 'kW'),
          ],
        ),
      ],
    );
  }

  /// P04 参考电耗卡「与近 30 天相比」：本次与近 30 天两个值 + 一句共享限定。
  Widget _referenceCard(dto.DriveDetail d) {
    final colors = context.colors;
    final type = context.type;
    final ref = _referenceUsable(d)
        ? reference!.totals.consumptionWhKmNet
        : null;
    final cells = <Widget>[
      MetricBlock(
        label: '本次',
        value: d.consumptionWhKm == null ? '—' : grouped(d.consumptionWhKm!),
        unit: d.consumptionWhKm == null ? null : 'Wh/km',
        scale: MetricValueScale.metricSm,
        semanticLabel: '本次 ${number(d.consumptionWhKm, 'Wh/km')}',
      ),
      if (ref != null)
        MetricBlock(
          label: '近 30 天',
          value: grouped(ref),
          unit: 'Wh/km',
          scale: MetricValueScale.metricSm,
          semanticLabel: '近 30 天 ${number(ref, 'Wh/km')}',
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: '与近 30 天相比'),
        const SizedBox(height: MileafSpace.s8),
        MileafModuleCard(
          padding: const EdgeInsets.all(MileafSpace.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MetricGrid(spacing: MileafSpace.s12, children: cells),
              const SizedBox(height: MileafSpace.s8),
              Text(
                '均为服务器估算；路线、天气和交通不同，不代表驾驶好坏。',
                style: type.footnote.copyWith(color: colors.textSecondary),
              ),
              if (referenceLoading)
                Padding(
                  padding: const EdgeInsets.only(top: MileafSpace.s8),
                  child: MediaQuery.disableAnimationsOf(context)
                      ? Text(
                          '正在读取近 30 天电耗',
                          style: type.footnote.copyWith(
                            color: colors.textSecondary,
                          ),
                        )
                      : const LinearProgressIndicator(),
                ),
              if (referenceError != null)
                Padding(
                  padding: const EdgeInsets.only(top: MileafSpace.s8),
                  child: InlineBanner(
                    message: referenceError!,
                    tone: BannerTone.error,
                    actionLabel: '重试',
                    onAction: () => loadReference(d, force: true),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// R30.2 页尾「关于这些数据」五类，缺哪类就不出现；技术详情可复制。
  Widget _notes(dto.DriveDetail d) {
    final s = series;
    final valid = s == null
        ? 0
        : s.series.where((point) => _sampleValue(point) != null).length;
    final reference = _referenceUsable(d);
    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.section),
      child: MileafDataNotes(
        groups: [
          MileafDataNoteGroup(
            category: DataNoteCategory.caliber,
            note:
                '速度数据、电量与海拔来自服务器数据点，连线只表示采样顺序，缺失点断线，不补点也不补零。${reference ? '近 30 天为行程开始日前 30 个完整本地日、同车全部路线的整体电耗，均为服务器估算；路线、天气和交通不同，不代表驾驶好坏。' : ''}',
          ),
          if (s != null)
            MileafDataNoteGroup(
              category: DataNoteCategory.records,
              note: s.resolution == 'server_sampled'
                  ? '服务器返回 ${s.points} 个数据点，其中当前指标有效 $valid 个。'
                  : '这段行程没有服务端采样数据点。',
            ),
          MileafDataNoteGroup(
            category: DataNoteCategory.time,
            note:
                '所有时间按站点日历显示，统计时区 ${workspace.calendar?.identifier ?? '—'}；行程开始于 ${copy.formatPrecise(local(d.startedAt))}。',
          ),
          if (detailCheckedAt != null)
            MileafDataNoteGroup(
              category: DataNoteCategory.source,
              copyable: true,
              note: '数据生成时间 ${copy.formatPrecise(local(detailCheckedAt!))}。',
            ),
          MileafDataNoteGroup(
            category: DataNoteCategory.technical,
            copyable: true,
            note: _recordInfo(d),
          ),
        ],
      ),
    );
  }

  String _recordInfo(dto.DriveDetail d) {
    final buffer = StringBuffer('行程记录 ${d.id}');
    for (final endpoint in [('起点', d.start), ('终点', d.end)]) {
      final place = endpoint.$2;
      if (place.geofence?.trim().isNotEmpty == true &&
          place.geofence != place.displayName) {
        buffer.write('；${endpoint.$1}围栏 ${place.geofence}');
      }
      if (place.address?.trim().isNotEmpty == true &&
          place.address != place.displayName &&
          place.address != place.geofence) {
        buffer.write('；${endpoint.$1}地址 ${place.address}');
      }
    }
    buffer.write('；净能量 ${number(d.energyKwh, 'kWh', decimals: 2)}');
    buffer.write('；起点电量 ${number(d.start.batteryLevel, '%')}');
    buffer.write('；终点电量 ${number(d.end.batteryLevel, '%')}');
    buffer.write('；续航口径 ${rangeKindFor(d.rangeKind)}');
    return buffer.toString();
  }

  String rangeKindFor(String? kind) => kind == 'rated'
      ? '额定'
      : kind == 'ideal'
      ? '理想'
      : '未知';

  @override
  Widget build(BuildContext context) {
    final inset = MileafLayout.pageInset(context);
    final d = detail;
    return Scaffold(
      appBar: mileafPageBar(
        context,
        title: const Text('行程详情'),
        actions: [
          MileafIconButton(
            icon: MileafIconName.refresh,
            tooltip: '刷新行程详情',
            onPressed: detailLoading || seriesLoading ? null : refreshAll,
          ),
        ],
      ),
      body: MileafContent(
        child: RefreshIndicator(
          onRefresh: refreshAll,
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
                if (d != null) _identity(d),
                _mapCard(context),
                if (detailLoading && d == null)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: inset,
                      vertical: MileafSpace.s12,
                    ),
                    child: const MileafProgressLine(),
                  ),
                if (detailError != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      inset,
                      MileafSpace.s12,
                      inset,
                      0,
                    ),
                    child: d == null
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              InlineBanner(
                                message: detailError!,
                                tone: BannerTone.error,
                                actionLabel: '重试',
                                onAction: loadDetail,
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: MileafButton(
                                  label: '返回行程列表',
                                  kind: MileafButtonKind.ghost,
                                  onPressed: () {
                                    widget.onReturnToList?.call();
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                            ],
                          )
                        : InlineBanner(
                            message: detailError!,
                            tone: BannerTone.error,
                            actionLabel: '重试',
                            onAction: loadDetail,
                          ),
                  ),
                if (d != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      inset,
                      MileafSpace.s24,
                      inset,
                      0,
                    ),
                    child: _keyValues(d),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    MileafSpace.s24,
                    inset,
                    0,
                  ),
                  child: _processCard(),
                ),
                if (d != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      inset,
                      MileafSpace.s24,
                      inset,
                      0,
                    ),
                    child: _batteryCard(d),
                  ),
                if (d != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      inset,
                      MileafSpace.s32,
                      inset,
                      0,
                    ),
                    child: _factsCard(d),
                  ),
                if (d != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      inset,
                      MileafSpace.s32,
                      inset,
                      0,
                    ),
                    child: _referenceCard(d),
                  ),
                if (d != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      inset,
                      MileafSpace.s32,
                      inset,
                      MileafSpace.s32,
                    ),
                    child: _notes(d),
                  ),
                if (d == null)
                  SizedBox(
                    height: MileafLayout.rootNavigationClearance(context),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
