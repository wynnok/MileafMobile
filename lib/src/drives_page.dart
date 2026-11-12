import 'number_format.dart';
import 'api.dart';
import 'reading_scope.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'design/components/components.dart';
import 'design/icons.dart';
import 'design/layout.dart';
import 'design/motion.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'driving_statistics_contract.g.dart' as stats;
import 'drives_contract.g.dart' as dto;
import 'workspace.dart';

/// A server cursor that never advances would page forever; the list keeps what
/// it already read and says so instead of blaming the contract version.
const _cursorStalled = '分页游标未前进，已保留现有行程，请刷新或手动重试';

class DrivesPage extends StatefulWidget {
  const DrivesPage({
    super.key,
    required this.workspace,
    this.onRecord,
    this.topBar,
  });
  final VehicleWorkspace workspace;
  final void Function(int id)? onRecord;
  final Widget? topBar;
  @override
  State<DrivesPage> createState() => _DrivesPageState();
}

class _DrivesPageState extends State<DrivesPage>
    with WidgetsBindingObserver, ReadingLifecycle<DrivesPage> {
  List<dto.Drive> items = [];
  String? error, pageError, cursor;
  bool loading = false, paging = false, loaded = false;
  int sequence = 0, revision = 0;
  DateTimeRange? custom;
  DateTime? selectedDay;
  int recentDays = 30, statsSequence = 0, chartDay = 0;
  bool chartDayTouched = false;
  stats.DrivingStats? driving;
  String? statsError;
  bool statsLoading = false;
  Map<String, String> statsQuery = {}, statsSnapshot = {};
  Map<String, String> query = const {};

  /// Reading range of the records on screen. The open end (`to`) follows the
  /// clock, so continuity is keyed on the start and page size instead.
  ({String from, String limit})? listRange;
  int loadedPages = 0;
  CachedResult? result;

  /// Set when a revalidation was cut short because the page stopped being
  /// visible. The records already on screen stay untouched, and the whole
  /// range is checked again on the next visible frame instead of being
  /// reported as refreshed.
  bool revalidatePending = false;
  VehicleWorkspace get workspace => widget.workspace;
  ({String from, String limit}) get _range =>
      (from: query['from'] ?? '', limit: query['limit'] ?? '');

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
    // A revision the owner cannot see (hidden tab, or a detail route on top)
    // stays unhandled here: the visible frame re-reads it with the current
    // calendar instead of fetching behind the detail.
    if (readingWasVisible && revision != workspace.revision) {
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
    if (readingVisible && state == AppLifecycleState.resumed) foreground();
  }

  @override
  Future<void> resumeReading() => foreground();

  Future<void> foreground() async {
    final changed = await workspace.foreground();
    // The owner may have hidden the page or opened a detail while the calendar
    // was read; then this pass must not start reads behind them.
    if (!mounted || !readingPresent) return;
    final stale = changed || revision != workspace.revision;
    revision = workspace.revision;
    if (stale) {
      revalidatePending = false;
      if (custom == null) selectedDay = null;
      resetQuery();
      await _revalidate();
      return;
    }
    if (revalidatePending) {
      // A read that was cut short by hiding still owes the whole read range;
      // the snapshot on screen was never replaced by a partial one.
      revalidatePending = false;
      await _revalidate();
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
    // The snapshot outlived its TTL: recompute the window, then either start a
    // new reading context or revalidate the range the owner already read.
    resetQuery(keepChartPoint: true);
    await _revalidate();
  }

  Future<void> _revalidate() async {
    if (listRange != _range) {
      await Future.wait([load(clear: true), loadStats(clear: true)]);
      return;
    }
    await Future.wait([load(preservePages: true), loadStats()]);
  }

  /// Rebuilds both queries from the current calendar, range and day filter.
  /// A return to the same range keeps the rhythm point the owner picked.
  void resetQuery({bool keepChartPoint = false}) {
    final touched = chartDayTouched;
    final previousRange = query.isEmpty ? null : _range;
    final clock = workspace.calendar!;
    final now = workspace.session.now();
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
    chartDayTouched = keepChartPoint && previousRange == _range
        ? touched
        : false;
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

  /// Loads the first page, appends one more cursor page, or — with
  /// [preservePages] — revalidates the whole range the owner already read.
  /// The swap happens once at the end, so a failed revalidation keeps the
  /// visible snapshot and its range instead of truncating it.
  Future<void> load({
    bool force = false,
    bool more = false,
    bool clear = false,
    bool preservePages = false,
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
        loadedPages = 0;
        listRange = null;
        error = '当前日期范围尚无可查询时段，请选择历史日期或稍后刷新';
      });
      return;
    }
    final session = workspace.session.current;
    final id = workspace.selectedId;
    if (session == null || id == null) return;
    final attempt = more ? sequence : ++sequence;
    final range = _range;
    // One fixed query snapshot per read. A page that arrives late must never
    // append its cursor to conditions the owner changed in the meantime.
    final requested = Map<String, String>.of(query);
    final startCursor = more ? cursor : null;
    final targetPages = preservePages ? (loadedPages < 1 ? 1 : loadedPages) : 1;
    setState(() {
      if (more) {
        paging = true;
        pageError = null;
      } else {
        loading = true;
        paging = false;
        error = null;
        pageError = null;
        // A cursor belongs to one range; a same-range refresh may keep it so a
        // failed attempt cannot strand the records already on screen.
        if (clear || listRange != range) cursor = null;
        if (clear) {
          items = [];
          loaded = false;
          loadedPages = 0;
          listRange = null;
          result = null;
        }
      }
    });
    bool current() =>
        mounted &&
        attempt == sequence &&
        workspace.session.isCurrent(session) &&
        workspace.selectedId == id;
    // A read still belongs to this page only while its own query is unchanged.
    bool owned() => current() && mapEquals(query, requested);
    try {
      final page = <dto.Drive>[];
      final visited = <String?>{};
      String? following = startCursor;
      CachedResult? value;
      var fetched = 0;
      var stalled = false;
      var interrupted = false;
      do {
        if (!visited.add(following)) {
          stalled = true;
          break;
        }
        value = await workspace.cache.get(
          session,
          'vehicles/$id/drives',
          query: {...requested, 'cursor': ?following},
          force: force,
        );
        // The request already in flight may finish; the next one may not be
        // started from a page the owner can no longer see.
        if (!owned()) return;
        if (!readingPresent) {
          interrupted = true;
          break;
        }
        final decoded = dto.DrivePage.fromJson(value.body);
        page.addAll(decoded.items);
        following = decoded.nextCursor;
        fetched++;
      } while (fetched < targetPages && following != null);
      if (!current()) return;
      if (interrupted) {
        // Keep the pages, their cursor and their range exactly as they were;
        // the abandoned read is retried when the page is visible again.
        if (!more) revalidatePending = true;
        return;
      }
      if (stalled) {
        // A cursor that stops advancing cannot rebuild the range the owner
        // read. Keep the pages on screen and name the real cause instead of
        // blaming the contract version (Spec #22: 失效旧查询游标，失败保留
        // 当前快照). The ledger reports the same condition the same way.
        setState(
          () => more ? pageError = _cursorStalled : error = _cursorStalled,
        );
        return;
      }
      setState(() {
        final seen = <int>{};
        items = [
          ...(more ? items : <dto.Drive>[]),
          ...page,
        ].where((item) => seen.add(item.id)).toList();
        cursor = following;
        if (more && cursor != null && cursor == startCursor) {
          pageError = _cursorStalled;
        }
        loadedPages = more ? loadedPages + fetched : fetched;
        listRange = range;
        loaded = true;
        result = value;
        if (!more) revalidatePending = false;
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
          revalidatePending = false;
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

  /// Manual retry of a failed read. A failed extra page keeps its own cursor;
  /// a failed revalidation keeps the range and pages already read instead of
  /// collapsing the list back to the first page (Spec #22: 失败保留当前快照
  /// 并提供重试). The ledger retries the same way.
  Future<void> retryLoad() async {
    if (pageError != null) {
      await load(more: true, force: true);
      return;
    }
    await load(force: true, preservePages: listRange == _range);
  }

  Future<void> chooseDates() async {
    final today = workspace.calendar!.local(workspace.session.now());
    final last = DateTime(today.year, today.month, today.day);
    // The picker is this page's own editor: its completion reloads the range
    // it returns, so closing it must not revalidate the abandoned range too.
    final range = await readingEditor(
      () => showDateRangePicker(
        context: context,
        firstDate: DateTime(1900),
        lastDate: last,
        initialDateRange: custom,
        initialEntryMode: DatePickerEntryMode.input,
        helpText: '选择行程日期（含首尾日期）',
      ),
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
      value == null ? '—' : '${grouped(value, decimals: decimals)} $unit';
  String date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  String timeRange(Map<String, String> range) {
    if (range.isEmpty) return '';
    final calendar = workspace.calendar!;
    return '${calendar.local(DateTime.parse(range['from']!)).toString().split('.').first} 至 ${calendar.local(DateTime.parse(range['to']!)).toString().split('.').first}';
  }

  String compactRange(Map<String, String> range) {
    if (range.isEmpty) return '';
    final calendar = workspace.calendar!;
    String md(DateTime t) {
      final d = calendar.local(t);
      final from = calendar.local(DateTime.parse(range['from']!));
      final to = calendar.local(DateTime.parse(range['to']!));
      final year = from.year != to.year ? '${d.year}/' : '';
      return '$year${d.month}/${d.day}';
    }

    return '${md(DateTime.parse(range['from']!))}—${md(DateTime.parse(range['to']!))}';
  }

  String _clock(DateTime value) {
    final local = workspace.calendar!.local(value);
    return '${local.month}/${local.day} · '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  String get _rangeLabel {
    if (custom != null) {
      return '${date(custom!.start)} 至 ${date(custom!.end)}（含首尾）';
    }
    if (statsSnapshot.isNotEmpty) return compactRange(statsSnapshot);
    return '近 $recentDays 天';
  }

  String _duration(dto.Drive d) =>
      d.durationMin == null ? '—' : '${d.durationMin} 分钟';

  String _net(dto.Drive d) => '净电耗 ${number(d.consumptionWhKm, 'Wh/km')}';

  String _route(dto.Drive d) =>
      '${place(d.start.displayName)} → ${place(d.end.displayName)}';

  String? _distance(dto.Drive d) =>
      d.distanceKm == null ? null : grouped(d.distanceKm!, decimals: 1);

  void _refresh() {
    resetQuery();
    load(force: true);
    loadStats(force: true);
  }

  Widget _pageHeader() {
    final type = context.type;
    final colors = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('行程', style: type.pageTitle),
              const SizedBox(height: MileafSpace.inline2),
              Text(
                _rangeLabel,
                style: type.label.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
        MileafIconButton(
          icon: MileafIconName.refresh,
          tooltip: '刷新行程',
          onPressed: loading ? null : _refresh,
        ),
      ],
    );
  }

  Widget _periodRow() {
    void selectDays(int days) {
      custom = null;
      selectedDay = null;
      recentDays = days;
      resetQuery();
      load(clear: true);
      loadStats(clear: true);
    }

    final recent = StatusChip(
      label: '近30天',
      selected: custom == null && recentDays == 30,
      onTap: () => selectDays(30),
    );
    final week = StatusChip(
      label: '近7天',
      selected: custom == null && recentDays == 7,
      onTap: () => selectDays(7),
    );
    final dateAction = TextButton(
      onPressed: chooseDates,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, MileafSpace.touch),
        padding: const EdgeInsets.symmetric(horizontal: MileafSpace.s8),
        visualDensity: VisualDensity.compact,
      ),
      child: const Text('日期'),
    );
    return ChipRow(children: [recent, week, dateAction]);
  }

  Widget _summarySkeleton() => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SkeletonBlock(width: 220, height: 56),
      SizedBox(height: MileafSpace.s8),
      SkeletonBlock(width: 250, height: 12),
    ],
  );

  Widget _summary(stats.DrivingStats? s, {required bool loadingFirst}) {
    final type = context.type;
    final colors = context.colors;
    if (s == null && loadingFirst) return _summarySkeleton();
    final totals = s?.totals;
    final distance = totals == null
        ? null
        : grouped(totals.distanceKm, decimals: 1);
    final drivesText = totals == null ? '— 趟' : '${totals.drives} 趟';
    final energyText = totals == null
        ? '估算 —'
        : '估算 ${number(totals.energyKwh, 'kWh', decimals: 2)}';
    final netText = totals == null
        ? '净电耗 —'
        : '净电耗 ${number(totals.consumptionWhKmNet, 'Wh/km')}';
    final metaStyle = type.label.copyWith(color: colors.textMuted);
    final large = MileafLayout.largeText(context);
    final facts = large
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(drivesText, style: metaStyle),
              const SizedBox(height: MileafSpace.s4),
              Text(energyText, style: metaStyle),
              const SizedBox(height: MileafSpace.s4),
              Text(netText, style: metaStyle),
            ],
          )
        : Wrap(
            spacing: MileafSpace.s8,
            runSpacing: MileafSpace.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(drivesText, style: metaStyle),
              Text('·', style: metaStyle),
              Text(energyText, style: metaStyle),
              Text('·', style: metaStyle),
              Text(netText, style: metaStyle),
            ],
          );
    return Semantics(
      container: true,
      label: '期间里程 ${distance ?? '—'} km，$drivesText，$energyText，$netText',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MileafNumber(
            value: distance,
            unit: 'km',
            scale: MetricValueScale.metricLg,
          ),
          const SizedBox(height: MileafSpace.s4),
          facts,
        ],
      ),
    );
  }

  Widget _rhythm(stats.DrivingStats? s) {
    final colors = context.colors;
    final type = context.type;
    if (s == null) {
      if (!statsLoading) return const SizedBox.shrink();
      return const Padding(
        padding: EdgeInsets.only(top: MileafSpace.section),
        child: SkeletonBlock(width: double.infinity, height: 132),
      );
    }
    final buckets = s.buckets;
    final active = buckets.any((b) => b.distanceKm > 0 || b.drives > 0);
    if (!active) {
      return Padding(
        padding: const EdgeInsets.only(top: MileafSpace.section),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: '出行节奏'),
            const SizedBox(height: MileafSpace.s8),
            Text(
              '这段时间还没有行程',
              style: type.body.copyWith(color: colors.textMuted),
            ),
          ],
        ),
      );
    }
    final lastActive = buckets.lastIndexWhere(
      (b) => b.distanceKm > 0 || b.drives > 0,
    );
    final selected = chartDayTouched
        ? chartDay.clamp(0, buckets.length - 1)
        : (lastActive < 0 ? buckets.length - 1 : lastActive);
    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.section),
      child: TimeSeriesChart(
        title: '出行节奏',
        unit: 'km',
        subtitle: statsSnapshot.isEmpty ? null : compactRange(statsSnapshot),
        times: [for (final b in buckets) b.bucketStart],
        series: [
          ChartSeries(
            label: '每日里程',
            values: [for (final b in buckets) b.distanceKm],
            style: ChartSeriesStyle.bars,
          ),
        ],
        semanticsLabel: '每日里程图表',
        selectedIndex: selected,
        onSelected: (index) => setState(() {
          chartDay = index;
          chartDayTouched = true;
        }),
        height: MileafSpace.rhythmHeight,
        readout: (index) {
          if (index < 0 || index >= buckets.length) return '—';
          final local = workspace.calendar!.local(buckets[index].bucketStart);
          return '${local.month}/${local.day} '
              '${number(buckets[index].distanceKm, 'km', decimals: 1)}';
        },
        tickLabel: (t) {
          final d = workspace.calendar!.local(t);
          return '${d.month}/${d.day}';
        },
        onActivateSelected: () {
          final local = workspace.calendar!.local(
            buckets[selected].bucketStart,
          );
          filterDay(DateTime(local.year, local.month, local.day));
        },
        activationLabel: '看当天',
      ),
    );
  }

  Widget _routeRow(dto.Drive d) {
    final distance = _distance(d);
    final meta = '${_clock(d.startedAt)} · ${_duration(d)}\n${_net(d)}';
    return MileafDataRow(
      key: ValueKey('drive-${d.id}'),
      title: _route(d),
      titleMaxLines: MediaQuery.textScalerOf(context).scale(14) > 14 ? null : 2,
      meta: meta,
      badge: d.endedAt == null
          ? Text(
              '进行中',
              style: context.type.micro.copyWith(color: context.colors.warning),
            )
          : null,
      value: distance,
      unit: distance == null ? null : 'km',
      bottomLine: true,
      onTap: () => widget.onRecord?.call(d.id),
      semanticLabel:
          '${_route(d)}，$meta${d.endedAt == null ? '，进行中' : ''}'
          '${distance == null ? '' : '，$distance km'}',
    );
  }

  String get _emptyListLabel =>
      selectedDay != null || custom != null ? '所选日期没有行程' : '这段时间还没有行程';

  Widget _recentSection() {
    if (!loaded && items.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final type = context.type;
    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.section),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: '最近的路'),
          const SizedBox(height: MileafSpace.s4),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MileafSpace.s16),
              child: Text(
                _emptyListLabel,
                style: type.body.copyWith(color: colors.textMuted),
              ),
            )
          else ...[
            _routeRow(items.first),
            for (final d in items.skip(1)) _routeRow(d),
          ],
        ],
      ),
    );
  }

  Widget _notes() {
    final type = context.type;
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.section),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: MileafSpace.s12),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text('数据说明', style: type.body.copyWith(color: colors.textMuted)),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '归期时区：${workspace.calendar!.identifier}',
                  style: type.micro.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: MileafSpace.s4),
                Text(
                  '已完成行程 · ${timeRange(statsSnapshot)}',
                  style: type.micro.copyWith(color: colors.textMuted),
                ),
                if (result != null) ...[
                  const SizedBox(height: MileafSpace.s4),
                  Text(
                    '校验时间：${workspace.calendar!.local(result!.checkedAt).toString().split('.').first}',
                    style: type.micro.copyWith(color: colors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String place(String? value) =>
      value == null || value.trim().isEmpty ? '未知地点' : value;

  @override
  Widget build(BuildContext context) {
    final inset = MileafLayout.pageInset(context);
    final colors = context.colors;
    final type = context.type;
    final content = RefreshIndicator(
      onRefresh: () {
        resetQuery();
        return Future.wait([load(force: true), loadStats(force: true)]);
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollUpdateNotification &&
              notification.dragDetails != null &&
              (notification.scrollDelta ?? 0) > 0 &&
              notification.metrics.extentAfter < 120 &&
              cursor != null &&
              pageError == null &&
              !paging) {
            load(more: true);
          }
          return false;
        },
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            MileafPageEnter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  inset,
                  MileafSpace.s8,
                  inset,
                  MileafSpace.s24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _pageHeader(),
                    const SizedBox(height: MileafSpace.s4),
                    _periodRow(),
                    if (workspace.calendar!.fallback)
                      Padding(
                        padding: const EdgeInsets.only(top: MileafSpace.s8),
                        child: Text(
                          '无法读取设备 IANA 时区，暂按 UTC 展示与归期',
                          style: type.micro.copyWith(color: colors.warning),
                        ),
                      ),
                    if (loading || statsLoading) const MileafProgressLine(),
                    if (error != null)
                      InlineBanner(
                        message: error!,
                        tone: BannerTone.error,
                        actionLabel: '重试行程',
                        onAction: retryLoad,
                      ),
                    if (statsError != null)
                      InlineBanner(
                        message: statsError!,
                        tone: BannerTone.error,
                        actionLabel: '重试行程统计',
                        onAction: () => loadStats(force: true),
                      ),
                    const SizedBox(height: MileafSpace.s20),
                    _summary(driving, loadingFirst: statsLoading),
                    _rhythm(driving),
                    if (selectedDay != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => filterDay(null),
                          child: const Text('返回完整区间'),
                        ),
                      ),
                    _recentSection(),
                    if (paging)
                      const Padding(
                        padding: EdgeInsets.only(top: MileafSpace.s12),
                        child: MileafProgressLine(),
                      ),
                    if (pageError != null)
                      InlineBanner(
                        message: pageError!,
                        tone: BannerTone.error,
                        actionLabel: '重试加载更多',
                        onAction: retryLoad,
                      ),
                    if (cursor != null &&
                        !loading &&
                        !paging &&
                        pageError == null)
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: () => load(more: true),
                          child: const Text('加载更多行程'),
                        ),
                      ),
                    if (loaded && cursor == null && items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: MileafSpace.s12),
                        child: Text(
                          '已显示全部行程',
                          textAlign: TextAlign.center,
                          style: type.micro.copyWith(color: colors.textFaint),
                        ),
                      ),
                    _notes(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final bar = widget.topBar;
    if (bar == null) return content;
    return Column(
      children: [
        bar,
        Expanded(child: content),
      ],
    );
  }
}
