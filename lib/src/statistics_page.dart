import 'package:flutter/material.dart';

import 'statistics_period.dart';
import 'driving_statistics_contract.g.dart' as dto;
import 'workspace.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key, required this.workspace});
  final VehicleWorkspace workspace;
  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage>
    with WidgetsBindingObserver {
  StatisticsSelection selection = const StatisticsSelection();
  dto.DrivingStats? data;
  CachedResult? result;
  String? error;
  bool loading = false;
  int sequence = 0;
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
    WidgetsBinding.instance.removeObserver(this);
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
    final changed = await workspace.foreground();
    if (mounted) await load(reset: changed);
  }

  Future<void> load({bool force = false, bool reset = false}) async {
    final owner = workspace.session.current, calendar = workspace.calendar;
    final id = workspace.selectedId;
    if (owner == null || calendar == null || id == null) return;
    final attempt = ++sequence;
    final StatisticsWindow window;
    try {
      window = selection.resolve(calendar, workspace.session.now());
    } on FormatException catch (e) {
      setState(() {
        error = e.message;
        data = null;
        loading = false;
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
      if (reset) data = null;
    });
    try {
      final value = await workspace.cache.get(
        owner,
        'vehicles/$id/stats',
        query: window.query('driving', calendar),
        force: force,
      );
      final body = dto.DrivingStats.fromJson(value.body);
      if (!mounted ||
          attempt != sequence ||
          !workspace.session.isCurrent(owner) ||
          workspace.selectedId != id ||
          workspace.calendar?.identifier != calendar.identifier) {
        return;
      }
      setState(() {
        data = body;
        result = value;
      });
    } catch (e) {
      if (mounted &&
          attempt == sequence &&
          workspace.session.isCurrent(owner) &&
          workspace.selectedId == id) {
        setState(
          () => error = e is FormatException
              ? '服务返回格式不兼容，请核对版本'
              : data == null
              ? '统计读取失败，请检查网络后重试'
              : '刷新失败，保留上次快照，请重试',
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
    return RefreshIndicator(
      onRefresh: () => load(force: true),
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '驾驶统计',
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
          Wrap(
            spacing: 8,
            children: [
              const ChoiceChip(label: Text('驾驶'), selected: true),
              ActionChip(
                label: const Text('充电统计（待交付）'),
                onPressed: () => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('充电统计将在后续功能切片接入'))),
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
          const Text(
            '仅统计已完成行程，按开始时间 started_at 归期。净电耗采用行程续航差与车辆效率估算能量／里程；毛电耗采用同区间已完成充电的充入电池能量（按结束时间归期）／驾驶里程。总计直接使用区间 totals。',
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
            if (totals.drives == 0) const Text('区间内无已完成行程；零值为服务端真实结果，比率缺失不补零。'),
            Text('校验时间：${calendar.local(result!.checkedAt)}'),
          ],
          if (buckets != null) ...[
            const Divider(),
            Text('里程趋势', style: Theme.of(context).textTheme.titleLarge),
            const Text('按服务端时间桶展示；空桶保留零，缺失比率显示 —。点击每个时间桶可阅读完整指标。'),
            if (buckets.isEmpty) const Text('区间内无趋势数据'),
            for (final raw in buckets) _bucket(context, raw, calendar, buckets),
          ],
        ],
      ),
    );
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
