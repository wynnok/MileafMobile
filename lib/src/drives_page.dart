import 'collage.dart';
import 'api.dart';

import 'package:flutter/material.dart';

import 'data_chart.dart';
import 'driving_statistics_contract.g.dart' as stats;
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
  DateTime? selectedDay;
  int recentDays = 30, statsSequence = 0, chartDay = 0, chartMetric = 0;
  stats.DrivingStats? driving;
  String? statsError;
  bool statsLoading = false;
  Map<String, String> statsQuery = {}, statsSnapshot = {};
  String? windowDay, windowZone;
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
    loadStats();
  }

  @override
  void didUpdateWidget(covariant DrivesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (revision != workspace.revision) {
      revision = workspace.revision;
      resetQuery();
      load(clear: true);
      loadStats(clear: true);
    }
  }

  @override
  void dispose() {
    sequence++;
    statsSequence++;
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
    final calendar = workspace.calendar!;
    if (windowDay != calendar.day(workspace.session.now()) ||
        windowZone != calendar.identifier) {
      if (custom == null) selectedDay = null;
      resetQuery();
      await Future.wait([load(clear: true), loadStats(clear: true)]);
      return;
    }
    final owner = workspace.session.current;
    final cached = owner == null
        ? null
        : workspace.cache.peek(
            owner,
            'vehicles/${workspace.selectedId}/drives',
            query,
          );
    if (cached?.validUntil.isAfter(workspace.session.now()) ?? false) {
      final statsCached = owner == null
          ? null
          : workspace.cache.peek(
              owner,
              'vehicles/${workspace.selectedId}/stats',
              statsQuery,
            );
      if (!(statsCached?.validUntil.isAfter(workspace.session.now()) ??
          false)) {
        await loadStats();
      }
      return;
    }
    resetQuery();
    await Future.wait([load(), loadStats()]);
  }

  void resetQuery() {
    final clock = workspace.calendar!;
    final now = workspace.session.now();
    windowDay = clock.day(now);
    windowZone = clock.identifier;
    final today = clock.local(now);
    final first =
        custom?.start ??
        DateTime(today.year, today.month, today.day - recentDays + 1);
    final last = custom?.end ?? DateTime(today.year, today.month, today.day);
    final end = clock.midnight(last, nextDays: 1);
    final from = clock.midnight(first);
    final to = (end.isAfter(now) ? now : end).toUtc();
    statsQuery = {
      'kind': 'driving',
      'bucket': 'day',
      'tz': clock.identifier,
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
    };
    if (selectedDay != null) {
      final selected = clock.midnight(selectedDay!);
      if (selected.isBefore(from) || !selected.isBefore(to)) selectedDay = null;
    }
    final dayFrom = selectedDay == null ? from : clock.midnight(selectedDay!);
    final dayEnd = selectedDay == null
        ? to
        : clock.midnight(selectedDay!, nextDays: 1);
    query = {
      'from': dayFrom.toIso8601String(),
      'to': (dayEnd.isAfter(to) ? to : dayEnd).toIso8601String(),
      'limit': '20',
    };
  }

  Future<void> loadStats({bool force = false, bool clear = false}) async {
    final owner = workspace.session.current, id = workspace.selectedId;
    final calendar = workspace.calendar;
    if (owner == null || id == null || calendar == null) return;
    final requested = Map<String, String>.of(statsQuery);
    final attempt = ++statsSequence;
    bool current() =>
        mounted &&
        attempt == statsSequence &&
        workspace.session.isCurrent(owner) &&
        workspace.selectedId == id &&
        workspace.calendar?.identifier == calendar.identifier &&
        statsQuery['from'] == requested['from'] &&
        statsQuery['to'] == requested['to'];
    final from = DateTime.parse(requested['from']!),
        to = DateTime.parse(requested['to']!);
    setState(() {
      statsLoading = true;
      statsError = null;
      if (clear ||
          (statsSnapshot.isNotEmpty &&
              (statsSnapshot['from'] != requested['from'] ||
                  statsSnapshot['tz'] != requested['tz']))) {
        driving = null;
        statsSnapshot = {};
        chartDay = 0;
      }
    });
    if (!to.isAfter(from) || to.difference(from) > const Duration(days: 730)) {
      if (current()) {
        setState(() {
          driving = null;
          statsLoading = false;
          statsError = '统计区间须大于0且不超过730天，行程列表仍可使用';
        });
      }
      return;
    }
    try {
      final value = await workspace.cache.get(
        owner,
        'vehicles/$id/stats',
        query: requested,
        force: force,
      );
      final decoded = stats.DrivingStats.fromJson(value.body);
      if (current()) {
        setState(() {
          driving = decoded;
          statsSnapshot = requested;
          chartDay = chartDay.clamp(
            0,
            decoded.buckets.isEmpty ? 0 : decoded.buckets.length - 1,
          );
        });
      }
    } catch (e) {
      if (current()) {
        setState(
          () => statsError =
              '${e is ApiFailure ? e.message : '行程统计读取失败'}${driving == null ? '' : '；保留上次统计快照'}',
        );
      }
    } finally {
      if (current()) setState(() => statsLoading = false);
    }
  }

  Future<void> load({
    bool force = false,
    bool more = false,
    bool clear = false,
  }) async {
    if (more && (loading || paging || cursor == null)) return;
    if (!DateTime.parse(query['from']!)
        .isBefore(DateTime.parse(query['to']!))) {
      sequence++;
      setState(() {
        items = [];
        loaded = false;
        cursor = null;
        loading = false;
        paging = false;
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
    selectedDay = null;
    resetQuery();
    await Future.wait([load(clear: true), loadStats(clear: true)]);
  }

  void filterDay(DateTime? day) {
    final period = statsSnapshot.isEmpty ? statsQuery : statsSnapshot;
    final from = DateTime.parse(period['from']!);
    final to = DateTime.parse(period['to']!);
    final calendar = workspace.calendar!;
    final selectedFrom = day == null ? from : calendar.midnight(day);
    final selectedTo = day == null ? to : calendar.midnight(day, nextDays: 1);
    if (selectedFrom.isBefore(from) || !selectedFrom.isBefore(to)) return;
    selectedDay = day;
    query = {
      'from': selectedFrom.toIso8601String(),
      'to': (selectedTo.isAfter(to) ? to : selectedTo).toIso8601String(),
      'limit': '20',
    };
    load(clear: true);
  }

  String number(num? value, String unit, {int decimals = 0}) =>
      value == null ? '—（缺失）' : '${value.toStringAsFixed(decimals)} $unit';
  String date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  String timeRange(Map<String, String> range) {
    if (range.isEmpty) return '';
    final calendar = workspace.calendar!;
    return '${calendar.local(DateTime.parse(range['from']!)).toString().split('.').first} 至 ${calendar.local(DateTime.parse(range['to']!)).toString().split('.').first}';
  }

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
      return Future.wait([load(force: true), loadStats(force: true)]);
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
        padding: const EdgeInsets.all(12),
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
                        loadStats(force: true);
                      },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              Text(
                custom == null
                    ? '最近$recentDays个本地日历日'
                    : '${date(custom!.start)} 至 ${date(custom!.end)}（含首尾）',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (workspace.calendar!.fallback)
            const Text('无法读取设备 IANA 时区，暂按 UTC 展示与归期'),
          Wrap(
            spacing: 8,
            children: [
              TextButton(onPressed: chooseDates, child: const Text('筛选日期')),
              for (final days in [30, 7])
                TextButton(
                  onPressed: () {
                    custom = null;
                    selectedDay = null;
                    recentDays = days;
                    resetQuery();
                    load(clear: true);
                    loadStats(clear: true);
                  },
                  child: Text('最近$days日'),
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
          if (statsLoading) const LinearProgressIndicator(),
          if (statsError != null) ...[
            Text(statsError!),
            TextButton(
              onPressed: () => loadStats(force: true),
              child: const Text('重试行程统计'),
            ),
          ],
          if (driving case final s?) ...[
            CollageTile(
              surface: CollageSurface.hero,
              child: Builder(
                builder: (context) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('已完成行程'),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '期间里程 ',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          TextSpan(
                            text: number(
                              s.totals.distanceKm,
                              'km',
                              decimals: 1,
                            ),
                          ),
                        ],
                      ),
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Wrap(
                      spacing: 10,
                      children: [
                        Text('期间行程 ${s.totals.drives} 次'),
                        Text(
                          '期间估算净能量 ${number(s.totals.energyKwh, 'kWh', decimals: 2)}',
                        ),
                        Text(
                          '期间估算净电耗 ${number(s.totals.consumptionWhKmNet, 'Wh/km')}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            TimeChart(
              title: '出行节奏',
              unit: chartMetric == 0 ? 'km' : 'Wh/km',
              times: s.buckets.map((b) => b.bucketStart).toList(),
              series: [
                ChartSeries(
                  label: chartMetric == 0 ? '每日里程' : '每日估算净电耗',
                  values: s.buckets
                      .map(
                        (b) => chartMetric == 0
                            ? b.distanceKm
                            : b.consumptionWhKmNet,
                      )
                      .toList(),
                ),
              ],
              timestamp: (t) =>
                  workspace.calendar!.local(t).toString().split('.').first,
              presentation: chartMetric == 0
                  ? ChartPresentation.bars
                  : ChartPresentation.line,
              selectedIndex: chartDay,
              height: 60,
              compact: true,
              onSelected: (i) => setState(() => chartDay = i),
              onActivateSelected: s.buckets.isEmpty
                  ? null
                  : () {
                      final local = workspace.calendar!.local(
                        s.buckets[chartDay].bucketStart,
                      );
                      filterDay(DateTime(local.year, local.month, local.day));
                    },
              controls: Wrap(
                spacing: 2,
                children: [
                  for (final entry in [(0, '里程', '每日里程'), (1, '电耗', '每日电耗')])
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      onPressed: () => setState(() => chartMetric = entry.$1),
                      child: Text(
                        entry.$2,
                        semanticsLabel: entry.$3,
                        style: TextStyle(
                          fontWeight: chartMetric == entry.$1
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (selectedDay != null)
            TextButton(
              onPressed: () {
                filterDay(null);
              },
              child: const Text('返回完整区间'),
            ),
          if (items.isNotEmpty) const Text('最近的路'),
          for (final (index, d) in items.indexed) ...[
            if (index == 0 ||
                recordDay(items[index - 1].startedAt) != recordDay(d.startedAt))
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 6),
                child: Text(
                  recordDay(d.startedAt),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            CollageTile(
              surface: index == 0 ? CollageSurface.mint : CollageSurface.paper,
              padding: EdgeInsets.zero,
              child: InkWell(
                key: ValueKey('drive-${d.id}'),
                onTap: () => widget.onRecord?.call(d.id),
                child: Padding(
                  padding: const EdgeInsets.all(12),
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
                      const SizedBox(height: 6),
                      Text(
                        '距离 ${number(d.distanceKm, 'km', decimals: 1)} · 时长 ${number(d.durationMin, '分钟')}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '估算净电耗 ${number(d.consumptionWhKm, 'Wh/km')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '估算净能量 ${number(d.energyKwh, 'kWh', decimals: 2)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
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
          ExpansionTile(
            title: const Text('数据说明'),
            children: [
              Text('归期时区：${workspace.calendar!.identifier}'),
              Text('已完成行程 · ${timeRange(statsSnapshot)}'),
              if (result != null)
                Text(
                  '校验时间：${workspace.calendar!.local(result!.checkedAt).toString().split('.').first}',
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
