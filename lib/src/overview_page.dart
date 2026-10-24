import 'api.dart';
import 'performance_trace.dart';

import 'package:flutter/material.dart';

import 'overview_contract.g.dart' as dto;
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
      final owner = workspace.session.current;
      if (data != null && owner != null) {
        PerformanceTrace.warmOverviewFrame(
          () =>
              mounted &&
              workspace.session.isCurrent(owner) &&
              data != null &&
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

  Future<void> load({bool force = false}) async {
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
          workspace.selectedId != id) {
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

  String timestamp(DateTime? time) => time == null
      ? '未知'
      : workspace.calendar!.local(time).toString().split('.').first;
  String number(num? value, String unit, {int decimals = 0}) =>
      value == null ? '—（缺失）' : '${value.toStringAsFixed(decimals)} $unit';
  Widget line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text('$label  $value'),
  );
  @override
  Widget build(BuildContext context) {
    final d = data;
    if (d != null && !loading && error == null) {
      final owner = workspace.session.current;
      PerformanceTrace.overviewFrame(
        () =>
            mounted &&
            owner != null &&
            workspace.session.isCurrent(owner) &&
            data != null &&
            !loading &&
            error == null &&
            (ModalRoute.of(context)?.isCurrent ?? false),
      );
    }
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
                  '最近记录',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                onPressed: loading ? null : () => load(force: true),
                icon: const Icon(Icons.refresh),
                tooltip: '刷新概览',
              ),
            ],
          ),
          const Text('车辆状态来自最近采样，并非实时车况'),
          Text('归期时区：${workspace.calendar?.identifier ?? 'UTC'}'),
          if (workspace.calendar?.fallback ?? false)
            const Text('无法读取设备 IANA 时区，暂按 UTC 展示与归期'),
          if (loading) const LinearProgressIndicator(),
          if (error != null) ...[
            Semantics(liveRegion: true, child: Text(error!)),
            TextButton(
              onPressed: () => load(force: true),
              child: const Text('重试概览'),
            ),
          ],
          if (d != null) ...[
            line('状态', switch (d.state?.value) {
              'online' => '在线',
              'asleep' => '休眠',
              'offline' => '离线',
              'charging' => '充电',
              _ => '未知',
            }),
            line('状态开始', timestamp(d.state?.since)),
            line('电量', number(d.battery?.level, '%')),
            line(switch (d.battery?.rangeKind) {
              'rated' => '额定续航',
              'ideal' => '理想续航（ideal）',
              _ => '续航（未知口径）',
            }, number(d.battery?.rangeKm, 'km', decimals: 1)),
            if (d.state?.value == 'charging' && d.chargingPowerKw != null)
              line('最近充电功率', number(d.chargingPowerKw, 'kW', decimals: 2)),
            const Divider(),
            line('今日里程', number(d.period.today.distanceKm, 'km', decimals: 1)),
            line('今日行程', '${d.period.today.drives} 次'),
            line('本月里程', number(d.period.month.distanceKm, 'km', decimals: 1)),
            line('本月行程', '${d.period.month.drives} 次'),
            const Divider(),
            if (d.lastDrive == null)
              line('最近行程', '无记录')
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('最近行程'),
                subtitle: Text(
                  '${timestamp(d.lastDrive!.startedAt)}\n${number(d.lastDrive!.distanceKm, 'km', decimals: 1)} · 净电耗 ${number(d.lastDrive!.consumptionWhKm, 'Wh/km')}',
                ),
                onTap: () => widget.onRecord?.call('drive', d.lastDrive!.id),
              ),
            if (d.lastCharge == null)
              line('最近充电', '无记录')
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('最近充电'),
                subtitle: Text(
                  '${timestamp(d.lastCharge!.startedAt)}\n充入 ${number(d.lastCharge!.energyKwh, 'kWh', decimals: 2)} · 结束电量 ${number(d.lastCharge!.endSoc, '%')}',
                ),
                onTap: () =>
                    widget.onRecord?.call('charging', d.lastCharge!.id),
              ),
            line('里程表', number(d.odometerKm, 'km', decimals: 1)),
            line('固件', d.firmware?.version ?? '未知'),
            line('位置采样', timestamp(d.freshness.lastPositionAt)),
            line('最近状态区间起始', timestamp(d.freshness.lastStateAt)),
            line('校验时间', timestamp(result?.checkedAt)),
            const Text('旧采样或长时间休眠不等同系统故障。'),
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
