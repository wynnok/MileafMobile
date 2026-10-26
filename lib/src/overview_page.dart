import 'api.dart';
import 'performance_trace.dart';

import 'package:flutter/material.dart';

import 'data_cards.dart';
import 'data_chart.dart';
import 'driving_statistics_contract.g.dart' as stats;
import 'overview_contract.g.dart' as dto;
import 'statistics_period.dart';
import 'workspace.dart';
import 'session.dart' show SiteSession;

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key, required this.workspace, this.onRecord});
  final VehicleWorkspace workspace;
  final void Function(String kind, int id)? onRecord;
  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage>
    with WidgetsBindingObserver {
  dto.Summary? data;
  CachedResult? result;
  String? error;
  bool loading = false;
  int sequence = 0;
  stats.DrivingStats? trend;
  CachedResult? trendResult;
  Map<String, String>? trendQuery;
  String? trendDay, trendZone, trendError;
  bool trendLoading = false;
  int trendSequence = 0;
  final plotKey = GlobalKey();
  final chartKey = GlobalKey();
  final viewportKey = GlobalKey();
  VehicleWorkspace get workspace => widget.workspace;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    sequence++;
    trendSequence++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get readable =>
      data != null &&
      trend != null &&
      !loading &&
      !trendLoading &&
      error == null &&
      trendError == null &&
      trendZone == workspace.calendar?.identifier &&
      trendDay == workspace.calendar?.day(workspace.session.now());

  // A framework candidate requires the actual current chart drawing to be in
  // the viewport. It still does not prove raster completion or OS present.
  bool get chartVisible {
    final chart = (trend?.buckets.isEmpty ?? true)
        ? chartKey.currentContext?.findRenderObject()
        : plotKey.currentContext?.findRenderObject();
    final viewport = viewportKey.currentContext?.findRenderObject();
    if (chart is! RenderBox ||
        viewport is! RenderBox ||
        !chart.hasSize ||
        !viewport.hasSize) {
      return false;
    }
    final plotRect = chart.localToGlobal(Offset.zero) & chart.size;
    final viewRect = viewport.localToGlobal(Offset.zero) & viewport.size;
    return plotRect.width > 0 &&
        plotRect.height > 0 &&
        plotRect.top >= viewRect.top &&
        plotRect.bottom <= viewRect.bottom;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      final owner = workspace.session.current;
      if (readable && owner != null) {
        PerformanceTrace.warmOverviewFrame(
          () =>
              mounted &&
              workspace.session.isCurrent(owner) &&
              readable &&
              chartVisible &&
              (ModalRoute.of(context)?.isCurrent ?? false),
        );
      }
      foreground();
    }
  }

  Future<void> foreground() async {
    final changed = await workspace.foreground();
    if (mounted && !changed) await load();
  }

  Future<void> load({bool force = false}) =>
      Future.wait([loadSummary(force: force), loadTrend(force: force)]);

  Future<void> loadSummary({bool force = false}) async {
    final session = workspace.session.current;
    final id = workspace.selectedId;
    final calendar = workspace.calendar;
    if (session == null || id == null || calendar == null) return;
    final attempt = ++sequence;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final value = await workspace.cache.get(
        session,
        'vehicles/$id/summary',
        query: {'tz': calendar.identifier},
        force: force,
      );
      final decoded = dto.Summary.fromJson(value.body);
      if (!mounted ||
          attempt != sequence ||
          !workspace.session.isCurrent(session) ||
          workspace.selectedId != id ||
          workspace.calendar?.identifier != calendar.identifier) {
        return;
      }
      if (decoded.vehicle.id != id) throw const FormatException();
      setState(() {
        data = decoded;
        result = value;
      });
    } catch (e) {
      if (mounted &&
          attempt == sequence &&
          workspace.session.isCurrent(session)) {
        PerformanceTrace.mark(PerformancePoint.overviewFailed);
      }
      if (e is BusinessFailure &&
          e.status == 404 &&
          mounted &&
          workspace.session.isCurrent(session) &&
          workspace.selectedId == id) {
        await workspace.session.loadVehicles();
      }
      if (mounted &&
          attempt == sequence &&
          workspace.session.isCurrent(session) &&
          workspace.selectedId == id) {
        setState(
          () => error = e is FormatException
              ? '服务返回格式不兼容，请核对版本'
              : e is ApiFailure
              ? '${e.message}${data == null ? '' : '；保留上次快照'}'
              : data == null
              ? '数据读取失败，请检查网络后重试'
              : '刷新失败，保留上次快照，请重试',
        );
      }
    } finally {
      if (mounted && attempt == sequence) setState(() => loading = false);
    }
  }

  Future<void> loadTrend({bool force = false}) async {
    final owner = workspace.session.current, calendar = workspace.calendar;
    final id = workspace.selectedId;
    if (owner == null || calendar == null || id == null) return;
    final now = workspace.session.now();
    final day = calendar.day(now);
    if (!force &&
        trendQuery != null &&
        trendZone == calendar.identifier &&
        trendDay == day) {
      final cached = workspace.cache.peek(
        owner,
        'vehicles/$id/stats',
        trendQuery!,
      );
      if (cached?.validUntil.isAfter(workspace.session.now()) ?? false) return;
    }
    final attempt = ++trendSequence;
    final Map<String, String> query;
    try {
      query = const StatisticsSelection()
          .resolve(calendar, now)
          .query('driving', calendar);
    } on FormatException {
      setState(() {
        trend = null;
        trendResult = null;
        trendLoading = false;
        trendError = '本月尚无可统计时间，稍后刷新里程趋势';
      });
      return;
    }
    setState(() {
      trendLoading = true;
      trendError = null;
      if (trendZone != calendar.identifier || trendDay != day) {
        trend = null;
        trendResult = null;
      }
    });
    try {
      final value = await workspace.cache.get(
        owner,
        'vehicles/$id/stats',
        query: query,
        force: force,
      );
      final decoded = stats.DrivingStats.fromJson(value.body);
      if (!mounted ||
          attempt != trendSequence ||
          !workspace.session.isCurrent(owner) ||
          workspace.selectedId != id ||
          workspace.calendar?.identifier != calendar.identifier) {
        return;
      }
      setState(() {
        trend = decoded;
        trendResult = value;
        trendQuery = query;
        trendZone = calendar.identifier;
        trendDay = day;
      });
    } catch (e) {
      if (mounted &&
          attempt == trendSequence &&
          workspace.session.isCurrent(owner) &&
          workspace.selectedId == id) {
        PerformanceTrace.mark(PerformancePoint.overviewFailed);
        setState(
          () => trendError = e is FormatException
              ? '里程趋势返回格式不兼容，请核对版本'
              : '${e is ApiFailure ? e.message : '里程趋势读取失败'}${trend == null ? '' : '；保留上次趋势快照'}',
        );
      }
    } finally {
      if (mounted && attempt == trendSequence) {
        setState(() => trendLoading = false);
      }
    }
  }

  String timestamp(DateTime? time) => time == null
      ? '未知'
      : workspace.calendar!.local(time).toString().split('.').first;
  String number(num? value, String unit, {int decimals = 0}) =>
      value == null ? '—（缺失）' : '${value.toStringAsFixed(decimals)} $unit';
  Widget line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text('$label  $value'),
  );

  Widget summary(BuildContext context, dto.Summary d) {
    final scheme = Theme.of(context).colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final status = switch (d.state?.value) {
      'online' => '在线',
      'asleep' => '休眠',
      'offline' => '离线',
      'charging' => '充电中',
      _ => '未知',
    };
    final range = MetricTile(
      label: switch (d.battery?.rangeKind) {
        'rated' => '额定续航',
        'ideal' => '理想续航（ideal）',
        _ => '续航（未知口径）',
      },
      value: number(d.battery?.rangeKm, 'km', decimals: 1),
      emphasize: true,
    );
    final battery = BatteryLevelIndicator(
      level: d.battery?.level,
      size: 96 * scale,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DataCard(
          color: Color.alphaBlend(
            scheme.primary.withValues(alpha: .09),
            scheme.surfaceContainerLow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('最近记录', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(width: 10),
                  Icon(Icons.circle, size: 5, color: scheme.primary),
                  const SizedBox(width: 5),
                  Text(
                    status,
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: scheme.primary),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: loading ? null : () => loadSummary(force: true),
                    icon: const Icon(Icons.refresh, size: 19),
                    tooltip: '刷新概览',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (scale > 1.4) ...[
                range,
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerRight, child: battery),
              ] else
                Row(
                  children: [
                    Expanded(child: range),
                    const SizedBox(width: 16),
                    battery,
                  ],
                ),
              const SizedBox(height: 12),
              Text(
                '位置采样 ${timestamp(d.freshness.lastPositionAt)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                '车辆状态来自最近采样，并非实时车况',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              if (d.state?.value == 'charging' && d.chargingPowerKw != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '最近充电功率 ${number(d.chargingPowerKw, 'kW', decimals: 2)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, c) {
            final children = [
              MetricTile(
                label: '今日里程',
                value: number(d.period.today.distanceKm, 'km', decimals: 1),
                note: '今日行程 ${d.period.today.drives} 次',
              ),
              MetricTile(
                label: '本月里程',
                value: number(d.period.month.distanceKm, 'km', decimals: 1),
                note: '本月行程 ${d.period.month.drives} 次',
              ),
            ];
            if (scale > 1.4) {
              return Column(
                children: [
                  for (final child in children) DataCard(child: child),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: DataCard(child: children.first)),
                const SizedBox(width: 10),
                Expanded(child: DataCard(child: children.last)),
              ],
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final t = trend;
    if (readable) {
      final owner = workspace.session.current;
      PerformanceTrace.overviewFrame(
        () =>
            mounted &&
            owner != null &&
            workspace.session.isCurrent(owner) &&
            readable &&
            chartVisible &&
            (ModalRoute.of(context)?.isCurrent ?? false),
      );
    }
    return RefreshIndicator(
      key: viewportKey,
      onRefresh: () => load(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (workspace.calendar?.fallback ?? false)
            const Text('无法读取设备 IANA 时区，暂按 UTC 展示与归期'),
          if (d == null)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: loading ? null : () => loadSummary(force: true),
                tooltip: '刷新概览',
                icon: const Icon(Icons.refresh),
              ),
            ),
          if (loading) const LinearProgressIndicator(),

          if (error != null) ...[
            Semantics(liveRegion: true, child: Text(error!)),
            TextButton(
              onPressed: () => loadSummary(force: true),
              child: const Text('重试概览'),
            ),
          ],
          if (d != null) summary(context, d),
          if (trendLoading) const LinearProgressIndicator(),
          if (trendError != null) ...[
            Semantics(liveRegion: true, child: Text(trendError!)),
            TextButton(
              onPressed: () => loadTrend(force: true),
              child: const Text('重试里程趋势'),
            ),
          ],
          if (t != null)
            TimeChart(
              key: chartKey,
              plotKey: plotKey,
              title: '本月里程',
              unit: 'km',
              times: t.buckets.map((b) => b.bucketStart).toList(),
              series: [
                ChartSeries(
                  label: '里程',
                  values: t.buckets.map((b) => b.distanceKm).toList(),
                ),
              ],
              timestamp: (time) => timestamp(time),
              tickLabel: (time) {
                final local = workspace.calendar!.local(time);
                return '${local.month}/${local.day}';
              },
              height: 140,
              subtitle: '按日 · 归期时区：${workspace.calendar!.identifier}',
              controls: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: trendLoading ? null : () => loadTrend(force: true),
                  tooltip: '刷新里程趋势',
                  icon: const Icon(Icons.refresh, size: 18),
                ),
              ),
            ),
          if (d != null) ...[
            const SizedBox(height: 5),
            InkWell(
              onTap: d.lastDrive == null
                  ? null
                  : () => widget.onRecord?.call('drive', d.lastDrive!.id),
              child: Text(
                '最近行程',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            if (d.lastDrive == null)
              const DataCard(child: Text('无记录'))
            else
              DataCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  title: Text(
                    timestamp(d.lastDrive!.startedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  subtitle: Text(
                    '${number(d.lastDrive!.distanceKm, 'km', decimals: 1)} · 净电耗 ${number(d.lastDrive!.consumptionWhKm, 'Wh/km')}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => widget.onRecord?.call('drive', d.lastDrive!.id),
                ),
              ),
            const SizedBox(height: 4),
            InkWell(
              onTap: d.lastCharge == null
                  ? null
                  : () => widget.onRecord?.call('charging', d.lastCharge!.id),
              child: Text(
                '最近充电',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            if (d.lastCharge == null)
              const DataCard(child: Text('无记录'))
            else
              DataCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  title: Text(
                    timestamp(d.lastCharge!.startedAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  subtitle: Text(
                    '充入 ${number(d.lastCharge!.energyKwh, 'kWh', decimals: 2)} · 结束电量 ${number(d.lastCharge!.endSoc, '%')}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      widget.onRecord?.call('charging', d.lastCharge!.id),
                ),
              ),
            DataCard(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                title: const Text('车辆与数据时间'),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  line('状态开始', timestamp(d.state?.since)),
                  line('里程表', number(d.odometerKm, 'km', decimals: 1)),
                  line('固件', d.firmware?.version ?? '未知'),
                  line('最近状态区间起始', timestamp(d.freshness.lastStateAt)),
                  line('校验时间', timestamp(result?.checkedAt)),
                  if (trendResult != null)
                    line('趋势已校验', timestamp(trendResult!.checkedAt)),
                  line('归期时区：${workspace.calendar?.identifier ?? 'UTC'}', ''),
                  const Text('旧采样或长时间休眠不等同系统故障。'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class MetaPage extends StatefulWidget {
  const MetaPage({super.key, required this.workspace});
  final VehicleWorkspace workspace;
  @override
  State<MetaPage> createState() => _MetaPageState();
}

class _MetaPageState extends State<MetaPage> with WidgetsBindingObserver {
  late final SiteSession? owner;
  dto.Meta? data;
  String? error;
  @override
  void initState() {
    super.initState();
    owner = widget.workspace.session.current;
    widget.workspace.session.addListener(sessionChanged);
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  void sessionChanged() {
    if (owner != null && !widget.workspace.session.isCurrent(owner!)) {
      setState(() {
        data = null;
        error = "会话已失效，请重新登录";
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      load(force: false);
    }
  }

  @override
  void dispose() {
    widget.workspace.session.removeListener(sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> load({bool force = true}) async {
    final s = widget.workspace.session.current;
    if (s == null) return;
    try {
      final r = await widget.workspace.cache.get(s, 'meta', force: force);
      final d = dto.Meta.fromJson(r.body);
      if (mounted && widget.workspace.session.isCurrent(s)) {
        setState(() => data = d);
      }
    } catch (_) {
      if (mounted) setState(() => error = '服务元信息读取失败，请重试');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('设置与服务')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (data == null && error == null) const LinearProgressIndicator(),
        if (error != null) ...[
          Text(error!),
          TextButton(
            onPressed: () {
              setState(() => error = null);
              load();
            },
            child: const Text('重试'),
          ),
        ],
        if (data case final d?) ...[
          Text('Mileaf Server ${d.version}'),
          Text('TeslaMate schema ${d.teslamateSchemaVersion ?? '未知'}'),
          Text(d.tested ? '此版本在服务端已测兼容范围' : '此版本未声明已测兼容；这不代表 schema 不兼容'),
          Text(d.schemaOk ? 'schema 检查正常' : 'schema 检查未通过'),
          const Text('数值使用公制；源单位不进行二次换算'),
        ],
      ],
    ),
  );
}
