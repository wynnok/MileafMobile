import 'package:flutter/material.dart';

import 'charging_contract.g.dart' as dto;
import 'workspace.dart';
import 'currency.dart';

class ChargingFilter {
  DateTime? first, last;
}

class ChargingPage extends StatefulWidget {
  const ChargingPage({
    super.key,
    required this.workspace,
    required this.currency,
    this.onRecord,
    required this.filter,
  });
  final VehicleWorkspace workspace;
  final CurrencySettings currency;
  final ChargingFilter filter;
  final void Function(String kind, int id)? onRecord;
  @override
  State<ChargingPage> createState() => _ChargingPageState();
}

class _ChargingPageState extends State<ChargingPage>
    with WidgetsBindingObserver {
  final items = <dto.ChargingSession>[];
  String? next, error;
  bool loading = false, loaded = false, failedMore = false;
  int revision = 0;
  int sequence = 0;
  late DateTime from, to;
  VehicleWorkspace get workspace => widget.workspace;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    workspace.addListener(contextChanged);
    revision = workspace.revision;
    interval();
    load();
  }

  void contextChanged() {
    if (!mounted ||
        revision == workspace.revision ||
        workspace.calendar == null) {
      return;
    }
    revision = workspace.revision;
    interval();
    items.clear();
    next = null;
    loaded = false;
    load();
  }

  void interval() {
    final local = workspace.calendar!.local(workspace.session.now());
    from = workspace.calendar!.midnight(
      widget.filter.first ?? DateTime(local.year, local.month, local.day - 29),
    );
    final end = widget.filter.last;
    final endBoundary = end == null
        ? workspace.session.now().toUtc()
        : workspace.calendar!.midnight(end, nextDays: 1);
    final now = workspace.session.now().toUtc();
    to = endBoundary.isAfter(now) ? now : endBoundary;
  }

  @override
  void dispose() {
    sequence++;
    workspace.removeListener(contextChanged);
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
    if (mounted && !changed) await load();
  }

  Future<void> load({bool more = false, bool force = false}) async {
    if (more && (loading || next == null)) return;
    if (!more && force) {
      interval();
      next = null;
    }
    if (!from.isBefore(to)) {
      setState(() {
        error = '日期区间尚无已发生时间，请调整日期';
        loading = false;
      });
      return;
    }
    final session = workspace.session.current;
    final id = workspace.selectedId;
    if (session == null || id == null) return;
    final attempt = ++sequence;
    final cursor = more ? next : null;
    setState(() {
      loading = true;
      error = null;
      failedMore = more;
    });
    try {
      final value = await workspace.cache.get(
        session,
        'vehicles/$id/charging-sessions',
        query: {
          'from': from.toIso8601String(),
          'to': to.toIso8601String(),
          'limit': '20',
          'cursor': ?cursor,
        },
        force: force,
      );
      final decoded = dto.ChargingSessionPage.fromJson(value.body);
      final page = decoded.items;
      final following = decoded.nextCursor;
      if (!mounted ||
          attempt != sequence ||
          !workspace.session.isCurrent(session) ||
          workspace.selectedId != id) {
        return;
      }
      setState(() {
        if (!more) items.clear();
        final ids = items.map((v) => v.id).toSet();
        for (final v in page) {
          if (ids.add(v.id)) items.add(v);
        }
        next = following;
        loaded = true;
      });
    } catch (e) {
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
              : items.isEmpty
              ? '充电读取失败，请重试'
              : '读取失败，保留已加载记录，请重试',
        );
      }
    } finally {
      if (mounted && attempt == sequence) setState(() => loading = false);
    }
  }

  Future<void> filterDates() async {
    final calendar = workspace.calendar!;
    final today = calendar.local(workspace.session.now());
    String day(DateTime value) =>
        '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    var start = day(widget.filter.first ?? calendar.local(from));
    var end = day(widget.filter.last ?? today);
    String? validation;
    DateTime? parse(String text) {
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return null;
      final date = DateTime.tryParse(text);
      return date != null && day(date) == text ? date : null;
    }

    final dates = await showDialog<List<DateTime>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('筛选充电日期'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: start,
                  onChanged: (value) => start = value,
                  decoration: const InputDecoration(
                    labelText: '开始日期 YYYY-MM-DD',
                  ),
                  keyboardType: TextInputType.datetime,
                ),
                TextFormField(
                  initialValue: end,
                  onChanged: (value) => end = value,
                  decoration: const InputDecoration(
                    labelText: '结束日期 YYYY-MM-DD',
                  ),
                  keyboardType: TextInputType.datetime,
                ),
                const Text('含首尾日期；今天截至当前时刻。按充电开始时间归期。'),
                if (validation != null) Text(validation!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final a = parse(start), b = parse(end);
                if (a == null ||
                    b == null ||
                    a.year < 1970 ||
                    a.isAfter(b) ||
                    day(b).compareTo(day(today)) > 0) {
                  update(() => validation = '请输入有效日期，开始不晚于结束，且不能选择未来日期');
                  return;
                }
                Navigator.pop(context, [a, b]);
              },
              child: const Text('应用日期'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || dates == null) return;
    widget.filter.first = dates.first;
    widget.filter.last = dates.last;
    interval();
    items.clear();
    next = null;
    loaded = false;
    await load(force: true);
  }

  String number(num? v, String unit) =>
      v == null ? '—（缺失）' : '${decimal(v)} $unit';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.currency,
    builder: (context, _) => RefreshIndicator(
      onRefresh: () => load(force: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (event) {
          if (event.metrics.extentAfter < 120 &&
              loaded &&
              next != null &&
              !loading &&
              error == null) {
            load(more: true);
          }
          return false;
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '充电历史',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: loading ? null : () => load(force: true),
                  icon: const Icon(Icons.refresh),
                  tooltip: '刷新充电',
                ),
              ],
            ),
            Text('按开始时间归期 · 时区：${workspace.calendar!.identifier}'),
            Text(
              '${widget.filter.first == null ? '近30日本地日历日' : '自定义日期'} · ${workspace.calendar!.local(from).toString().split(' ').first} 起',
            ),
            TextButton(onPressed: filterDates, child: const Text('筛选充电日期')),
            if (widget.filter.first != null)
              TextButton(
                onPressed: () {
                  widget.filter.first = null;
                  widget.filter.last = null;
                  interval();
                  items.clear();
                  next = null;
                  loaded = false;
                  load(force: true);
                },
                child: const Text('恢复近30日'),
              ),
            const Text('— 表示数据缺失；进行中指标不代表最终结果'),
            if (workspace.calendar!.fallback)
              const Text('无法读取设备 IANA 时区，暂按 UTC'),
            if (loading) const LinearProgressIndicator(),
            if (error != null) ...[
              Semantics(liveRegion: true, child: Text(error!)),
              TextButton(
                onPressed: () => load(more: failedMore, force: true),
                child: const Text('重试充电'),
              ),
            ],
            if (loaded && items.isEmpty) const Text('此区间无充电记录'),
            for (final v in items)
              Card(
                child: InkWell(
                  onTap: () => widget.onRecord?.call('charge', v.id),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.location.displayName?.trim().isNotEmpty == true
                              ? v.location.displayName!
                              : '未知地点',
                        ),
                        if (v.location.geofence != null)
                          Text('围栏：${v.location.geofence}'),
                        if (v.location.address != null &&
                            v.location.address != v.location.displayName)
                          Text('地址：${v.location.address}'),
                        Text(
                          '${workspace.calendar!.local(v.startedAt).toString().split('.').first} · ${v.isActive ? '进行中' : '已结束'}',
                        ),
                        Text(
                          v.isDc == null
                              ? '分类未知'
                              : v.isDc!
                              ? 'DC'
                              : 'AC',
                        ),
                        Text(
                          '电量 ${number(v.startSoc, '%')} → ${number(v.endSoc, '%')}',
                        ),
                        Text('充入电池 ${number(v.energyAddedKwh, 'kWh')}'),
                        Text('电网侧 ${number(v.energyUsedKwh, 'kWh')}'),
                        Text('费用 ${widget.currency.amount(v.cost)}'),
                        Text('时长 ${number(v.durationMin, '分钟')}'),
                        Text('充电 #${v.id} · 查看详情'),
                      ],
                    ),
                  ),
                ),
              ),
            if (loaded && next != null)
              TextButton(
                onPressed: loading ? null : () => load(more: true),
                child: const Text('加载更多充电'),
              ),
            if (loaded && next == null && items.isNotEmpty)
              const Text('已到最后一条'),
          ],
        ),
      ),
    ),
  );
}
