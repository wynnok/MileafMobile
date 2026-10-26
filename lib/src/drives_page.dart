import 'api.dart';

import 'package:flutter/material.dart';

import 'drives_contract.g.dart' as dto;
import 'workspace.dart';

class DrivesPage extends StatefulWidget {
  const DrivesPage({super.key, required this.workspace, this.onRecord});
  final VehicleWorkspace workspace;
  final void Function(int id)? onRecord;
  @override
  State<DrivesPage> createState() => _DrivesPageState();
}

class _DrivesPageState extends State<DrivesPage> with WidgetsBindingObserver {
  List<dto.Drive> items = [];
  String? error, pageError, cursor;
  bool loading = false, paging = false, loaded = false;
  int sequence = 0, revision = 0;
  DateTimeRange? custom;
  late Map<String, String> query;
  CachedResult? result;
  VehicleWorkspace get workspace => widget.workspace;
  @override
  void initState() {
    super.initState();
    revision = workspace.revision;
    WidgetsBinding.instance.addObserver(this);
    resetQuery();
    load();
  }

  @override
  void didUpdateWidget(covariant DrivesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (revision != workspace.revision) {
      revision = workspace.revision;
      resetQuery();
      load(clear: true);
    }
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
    if (!mounted || changed) return;
    final owner = workspace.session.current;
    final cached = owner == null
        ? null
        : workspace.cache.peek(
            owner,
            'vehicles/${workspace.selectedId}/drives',
            query,
          );
    if (cached?.validUntil.isAfter(workspace.session.now()) ?? false) return;
    resetQuery();
    await load();
  }

  void resetQuery() {
    final clock = workspace.calendar!;
    final now = workspace.session.now();
    final today = clock.local(now);
    final first =
        custom?.start ?? DateTime(today.year, today.month, today.day - 29);
    final last = custom?.end ?? DateTime(today.year, today.month, today.day);
    final end = clock.midnight(last, nextDays: 1);
    query = {
      'from': clock.midnight(first).toIso8601String(),
      'to': (end.isAfter(now) ? now : end).toUtc().toIso8601String(),
      'limit': '20',
    };
  }

  Future<void> load({
    bool force = false,
    bool more = false,
    bool clear = false,
  }) async {
    if (more && (loading || paging || cursor == null)) return;
    if (!DateTime.parse(query['from']!)
        .isBefore(DateTime.parse(query['to']!))) {
      setState(() {
        items = [];
        loaded = false;
        cursor = null;
        error = '当前日期范围尚无可查询时段，请选择历史日期或稍后刷新';
      });
      return;
    }
    final session = workspace.session.current;
    final id = workspace.selectedId;
    if (session == null || id == null) return;
    final attempt = more ? sequence : ++sequence;
    final requested = {...query, if (more) 'cursor': cursor!};
    setState(() {
      if (more) {
        paging = true;
        pageError = null;
      } else {
        loading = true;
        paging = false;
        error = null;
        pageError = null;
        cursor = null;
        if (clear) {
          items = [];
          loaded = false;
          result = null;
        }
      }
    });
    bool current() =>
        mounted &&
        attempt == sequence &&
        workspace.session.isCurrent(session) &&
        workspace.selectedId == id;
    try {
      final value = await workspace.cache.get(
        session,
        'vehicles/$id/drives',
        query: requested,
        force: force,
      );
      final page = dto.DrivePage.fromJson(value.body);
      if (!current()) return;
      setState(() {
        final seen = <int>{};
        items = [
          ...(more ? items : <dto.Drive>[]),
          ...page.items,
        ].where((item) => seen.add(item.id)).toList();
        cursor = page.nextCursor;
        if (more && cursor != null && cursor == requested['cursor']) {
          pageError = '分页游标未前进，已保留现有行程，请刷新或重试';
        }
        loaded = true;
        result = value;
      });
    } catch (e) {
      if (!current()) return;
      setState(() {
        final message = e is FormatException
            ? '服务返回格式不兼容，请核对版本'
            : e is ApiFailure
            ? '${e.message}${more
                  ? '；已保留现有行程'
                  : loaded
                  ? '；保留上次快照'
                  : ''}'
            : more
            ? '加载失败，已保留现有行程'
            : loaded
            ? '刷新失败，保留上次快照'
            : '行程读取失败，请检查网络后重试';
        if (more) {
          pageError = message;
        } else {
          error = message;
        }
      });
      if (e is BusinessFailure && e.status == 404) {
        await workspace.session.loadVehicles();
      }
    } finally {
      if (current()) {
        setState(() {
          if (more) {
            paging = false;
          } else {
            loading = false;
          }
        });
      }
    }
  }

  Future<void> chooseDates() async {
    final today = workspace.calendar!.local(workspace.session.now());
    final last = DateTime(today.year, today.month, today.day);
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: last,
      initialDateRange: custom,
      initialEntryMode: DatePickerEntryMode.input,
      helpText: '选择行程日期（含首尾日期）',
    );
    if (!mounted || range == null) return;
    custom = range;
    resetQuery();
    await load(clear: true);
  }

  String number(num? value, String unit, {int decimals = 0}) =>
      value == null ? '—（缺失）' : '${value.toStringAsFixed(decimals)} $unit';
  String date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  String place(String? value) =>
      value == null || value.trim().isEmpty ? '未知地点' : value;
  String recordDay(DateTime value) {
    final local = workspace.calendar!.local(value);
    return '${local.year}年${local.month}月${local.day}日';
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () {
      resetQuery();
      return load(force: true);
    },
    child: NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification &&
            notification.dragDetails != null &&
            (notification.scrollDelta ?? 0) > 0 &&
            notification.metrics.extentAfter < 100 &&
            cursor != null &&
            pageError == null) {
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
                  '行程记录',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: '刷新行程',
                onPressed: loading
                    ? null
                    : () {
                        resetQuery();
                        load(force: true);
                      },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          Text(
            custom == null
                ? '最近30个本地日历日'
                : '${date(custom!.start)} 至 ${date(custom!.end)}（含首尾）',
          ),
          Text('归期时区：${workspace.calendar!.identifier}'),
          if (workspace.calendar!.fallback)
            const Text('无法读取设备 IANA 时区，暂按 UTC 展示与归期'),
          Wrap(
            spacing: 8,
            children: [
              TextButton(onPressed: chooseDates, child: const Text('筛选日期')),
              if (custom != null)
                TextButton(
                  onPressed: () {
                    custom = null;
                    resetQuery();
                    load(clear: true);
                  },
                  child: const Text('最近30日'),
                ),
            ],
          ),
          if (loading) const LinearProgressIndicator(),
          if (error != null) ...[
            Semantics(liveRegion: true, child: Text(error!)),
            TextButton(
              onPressed: () => load(force: true),
              child: const Text('重试行程'),
            ),
          ],
          if (loaded && items.isEmpty) const Text('所选日期没有行程'),
          for (final (index, d) in items.indexed) ...[
            if (index == 0 ||
                recordDay(items[index - 1].startedAt) != recordDay(d.startedAt))
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 10),
                child: Text(
                  recordDay(d.startedAt),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            Card(
              child: InkWell(
                key: ValueKey('drive-${d.id}'),
                onTap: () => widget.onRecord?.call(d.id),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workspace.calendar!
                            .local(d.startedAt)
                            .toString()
                            .split('.')
                            .first,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      Text(
                        '${place(d.start.displayName)} → ${place(d.end.displayName)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '距离 ${number(d.distanceKm, 'km', decimals: 1)} · 时长 ${number(d.durationMin, '分钟')}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text('净电耗 ${number(d.consumptionWhKm, 'Wh/km')}'),
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

                      if (d.endedAt == null) const Text('进行中'),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (pageError != null)
            Semantics(liveRegion: true, child: Text(pageError!)),
          if (paging) const Center(child: CircularProgressIndicator()),
          if (cursor != null && !loading && !paging)
            TextButton(
              onPressed: () => load(more: true, force: pageError != null),
              child: Text(pageError == null ? '加载更多行程' : '重试加载更多'),
            ),
          if (loaded && cursor == null && items.isNotEmpty)
            const Text('已显示全部行程'),
          if (result != null)
            Text(
              '校验时间：${workspace.calendar!.local(result!.checkedAt).toString().split('.').first}',
            ),
        ],
      ),
    ),
  );
}
