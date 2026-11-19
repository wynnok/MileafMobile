import 'number_format.dart';
import 'api.dart';
import 'reading_scope.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'copy/dates.dart' as copy;
import 'copy/messages.dart' as messages;
import 'copy/state_feedback.dart' as feedback;
import 'copy/terms.dart' as terms;
import 'design/components/components.dart';
import 'design/icons.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'driving_statistics_contract.g.dart' as stats;
import 'drives_contract.g.dart' as dto;
import 'workspace.dart';

/// A server cursor that never advances would page forever; the list keeps what
/// it already read and says so instead of blaming the contract version.
const _cursorStalled = '没能加载更多行程，已保留当前列表';

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
  DateTime? statsCheckedAt;
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
          statsError = '统计最长支持 730 天，行程列表不受影响';
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
          statsCheckedAt = value.checkedAt;
          chartDay = chartDay.clamp(
            0,
            decoded.buckets.isEmpty ? 0 : decoded.buckets.length - 1,
          );
        });
      }
    } catch (e) {
      if (current()) {
        // MG09 三要素：现状句（原因）留在正文，缓存统计的时间要素走
        // statusLine「数据截至 HH:mm」（state_feedback 共享构造），不再把
        // 时间拼进原因句；动作沿下方状态条的「重试行程统计」。
        setState(
          () => statsError = e is FormatException
              ? messages.versionIncompatibleMessage()
              : e is ApiFailure
              ? e.message
              : messages.readFailedMessage('行程统计'),
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
        // CP07：分页失败与「失败有旧数据」都来自共享构造函数，页面不拼句子。
        final clock = workspace.calendar!.local(workspace.session.now());
        final message = more
            ? messages.paginationFailedMessage('行程')
            : result != null
            ? messages.staleMessage(
                workspace.calendar!.local(result!.checkedAt),
                clock,
              )
            : e is FormatException
            ? messages.versionIncompatibleMessage()
            : e is ApiFailure
            ? e.message
            : messages.readFailedMessage('行程');
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
    // R27/PD10：三套日期输入合并为共享的 MileafDateRangeSheet。默认区间沿用
    // 本页原来的近 30 天窗口；含首尾的语义、可选范围与校验仍由本页注入，
    // 组件不内置业务规则。
    final initial =
        custom ??
        DateTimeRange(
          start: DateTime(last.year, last.month, last.day - recentDays + 1),
          end: last,
        );
    // The sheet is this page's own editor: its completion reloads the range
    // it returns, so closing it must not revalidate the abandoned range too.
    final range = await readingEditor(
      () => showMileafDateRangeSheet(
        context: context,
        initialRange: initial,
        firstDate: DateTime(1900),
        lastDate: last,
        today: last,
        validator: (start, end) {
          if (end.isAfter(last)) return '结束日期不能晚于今天';
          if (start.isAfter(end)) return '开始日期不能晚于结束日期';
          return null;
        },
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

  String _recordTime(dto.Drive drive) {
    final calendar = workspace.calendar!;
    final start = calendar.local(drive.startedAt);
    String hm(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
    final end = drive.endedAt;
    if (end == null) return hm(start);
    final localEnd = calendar.local(end);
    final endDate = date(start) == date(localEnd) ? '' : '${date(localEnd)} ';
    return '${hm(start)}–$endDate${hm(localEnd)}';
  }

  String _route(dto.Drive d) =>
      '${place(d.start.displayName)} → ${place(d.end.displayName)}';

  String? _distance(dto.Drive d) =>
      d.distanceKm == null ? null : grouped(d.distanceKm!, decimals: 1);

  void _refresh() {
    resetQuery();
    load(force: true);
    loadStats(force: true);
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
    final dateAction = StatusChip(
      label: '自定义',
      selected: custom != null,
      onTap: chooseDates,
    );
    return MileafPeriodRow(
      trailing: MileafIconButton(
        icon: MileafIconName.refresh,
        tooltip: '刷新行程',
        fill: MileafIconButtonFill.track,
        onPressed: loading ? null : _refresh,
      ),
      children: [recent, week, dateAction],
    );
  }

  /// 期间名（分段已选定；区间只在卡片标签出现一次，R21.4）。
  String get _periodName {
    if (custom != null) return '自定义区间';
    return recentDays == 7 ? '近 7 天' : '近 30 天';
  }

  /// DF3 区间（本地日历），只用共享格式化器；同一窗位另有读屏读法（「至」）。
  ({String text, String reading})? get _periodRange {
    if (statsSnapshot.isEmpty) return null;
    final calendar = workspace.calendar!;
    final from = calendar.local(DateTime.parse(statsSnapshot['from']!));
    final to = calendar.local(
      DateTime.parse(statsSnapshot['to']!)
          .subtract(const Duration(microseconds: 1)),
    );
    return (
      text: copy.formatRange(from, to),
      reading: copy.formatRangeReading(from, to),
    );
  }

  Widget _summarySkeleton() => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SkeletonBlock(width: 220, height: 56),
      SizedBox(height: MileafSpace.s8),
      SkeletonBlock(width: 250, height: 12),
    ],
  );

  /// P02 焦点模块卡：期间主值（里程）→ 三格。节奏图按用户裁定 B 移到记录之后。
  Widget _summary(stats.DrivingStats? s, {required bool loadingFirst}) {
    if (s == null && loadingFirst) return _summarySkeleton();
    final totals = s?.totals;
    final distance = totals == null
        ? null
        : grouped(totals.distanceKm, decimals: 1);
    final large = MileafLayout.largeText(context);
    // CL01/CL12：焦点卡的里程与行程数属 journey 域，电耗属 efficiency 域；读数
    // 取 `strong`（浅色 5.90:1），标签仍中性。CL07：本页首屏已有 journey（焦点
    // 卡 + 焦点值）、dwell（记录行时长）、efficiency（电耗）三个色相，「估算
    // 耗电」若再上 energy 就是 4 个，故按条款留同级中性。
    final journey = MileafDataDomain.journey.hue;
    final cells = [
      MetricBlock(
        label: '行程',
        value: totals == null ? null : '${totals.drives}',
        unit: totals == null ? null : '趟',
        scale: MetricValueScale.metricSm,
        hue: journey,
      ),
      MetricBlock(
        label: '估算耗电',
        value: totals?.energyKwh == null
            ? null
            : grouped(totals!.energyKwh!, decimals: 2),
        unit: totals == null ? null : 'kWh',
        scale: MetricValueScale.metricSm,
      ),
      MetricBlock(
        label: '电耗',
        value: totals?.consumptionWhKmNet == null
            ? null
            : grouped(totals!.consumptionWhKmNet!, decimals: 0),
        unit: totals == null ? null : 'Wh/km',
        scale: MetricValueScale.metricSm,
        hue: MileafDataDomain.efficiency.hue,
      ),
    ];
    return MileafModuleCard(
      // CL02/CL06：焦点卡是首屏最大的面，只叠 8% journey tint（不叠 alpha、
      // 不加深色材质）；描边与内边仍走既有档位。
      hue: journey,
      // §6 退让阶梯第 2 步：焦点卡内边 16 → 12。
      padding: const EdgeInsets.all(MileafSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // R21.4：区间只在这里出现一次。一行放得下时区间靠右与卡片右沿同线，
          // 放不下时整段落到期间名下一行——由实际宽度决定，不再用 150% 阈值近似。
          MileafPeriodHeader(label: _periodName, range: _periodRange),
          // PD12（MG06/D1）：卡头 → 焦点值间距 s4 → s12。
          const SizedBox(height: MileafSpace.s12),
          Semantics(
            container: true,
            label:
                '$_periodName ${distance ?? '—'} 公里，'
                '${totals?.drives ?? '—'} 趟，'
                '估算耗电 ${number(totals?.energyKwh, 'kWh', decimals: 2)}，'
                '电耗 ${number(totals?.consumptionWhKmNet, 'Wh/km')}',
            excludeSemantics: true,
            child: MetricBlock(
              value: distance,
              unit: 'km',
              scale: MetricValueScale.metricLg,
              // CL12：焦点值取 journey.strong（浅色 5.90:1 / 深色 7.42:1）。
              hue: journey,
            ),
          ),
          const SizedBox(height: MileafSpace.s12),
          if (large)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final cell in cells)
                  Padding(
                    padding: const EdgeInsets.only(bottom: MileafSpace.s4),
                    child: cell,
                  ),
              ],
            )
          else
            // R21.5：三列只用 metricSm；网格按最小格宽收列，放不下时先两列。
            MetricGrid(spacing: MileafSpace.s8, children: cells),
        ],
      ),
    );
  }

  /// P02 节奏图：用户裁定 B（交付手册 §6 第 5 步）——节奏图移到记录之后，
  /// 不再挤占首屏的记录空间；它仍是独立模块卡，读数行保持 R29 紧凑形态。
  Widget _rhythmSection(stats.DrivingStats? s) {
    final chart = _rhythm(s);
    if (chart == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.s12),
      child: MileafModuleCard(
        padding: const EdgeInsets.all(MileafSpace.s12),
        child: chart,
      ),
    );
  }

  Widget? _rhythm(stats.DrivingStats? s) {
    final colors = context.colors;
    final type = context.type;
    if (s == null) {
      if (!statsLoading) return null;
      return const SkeletonBlock(width: double.infinity, height: 132);
    }
    final buckets = s.buckets;
    final active = buckets.any((b) => b.distanceKm > 0 || b.drives > 0);
    if (!active) {
      return Text(
        '这段时间没有行程',
        style: type.body.copyWith(color: colors.textSecondary),
      );
    }
    final lastActive = buckets.lastIndexWhere(
      (b) => b.distanceKm > 0 || b.drives > 0,
    );
    final selected = chartDayTouched
        ? chartDay.clamp(0, buckets.length - 1)
        : (lastActive < 0 ? buckets.length - 1 : lastActive);
    // AP05 的图表以本地墙钟格式化日期；bucket_start 是 UTC 瞬时，先换墙钟，
    // 否则读数头与 X 轴会比站点日历早一天。
    final wall = [
      for (final b in buckets) workspace.calendar!.local(b.bucketStart),
    ];
    return TimeSeriesChart(
      title: '每日里程',
      unit: 'km',
      // CL12/CL15：图表绘图区与图例取 journey.solid；参照系列仍走中性。
      hue: MileafDataDomain.journey.hue,
      times: wall,
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
      // R29 紧凑读数行：一行内日期、数值（body 600）与行尾下钻。
      compactReadout: true,
      readout: (index) {
        if (index < 0 || index >= buckets.length) return '—';
        final day = copy.formatDay(
          wall[index],
          workspace.calendar!.local(workspace.session.now()),
        );
        return '$day，${number(buckets[index].distanceKm, 'km', decimals: 1)}';
      },
      onActivateSelected: () {
        final local = workspace.calendar!.local(buckets[selected].bucketStart);
        filterDay(DateTime(local.year, local.month, local.day));
      },
      activationLabel: '查看当天',
    );
  }

  /// MG05 记录行句法统一（与充电记录行同构，charging-rows 先例）：标题行
  /// （起讫时刻，headline；日期由分组头承担）+ 路线一行 + 三格 metricSm 读值
  /// 网格（里程/时长/电耗，标签在上、数值同基线成列，第三格放不下时换行）。
  /// 整行可点；进行中徽标留在标题行尾。读屏沿元素顺序朗读：起讫时刻、路线，
  /// 再逐格「标签 数值 单位」，与充电记录行一致，不再合成 meta 串。
  Widget _routeRow(dto.Drive d) {
    final colors = context.colors;
    final type = context.type;
    final distance = _distance(d);
    final duration = d.durationMin?.toString();
    final net = d.consumptionWhKm == null
        ? null
        : grouped(d.consumptionWhKm!, decimals: 0);
    final large = MileafLayout.largeText(context);
    // CL01/CL12：记录行三格按域取色（里程 journey / 时长 dwell / 电耗
    // efficiency），行首图标取 journey.strong。
    final journey = MileafDataDomain.journey.hue;
    return InkWell(
      key: ValueKey('drive-${d.id}'),
      onTap: () => widget.onRecord?.call(d.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MileafSpace.s12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CL12/CL13：行首身份图标（inline 16 + s8），与充电记录行的行首
            // 图标同构（MG05 句法统一）；发丝线仍从卡内 16 起（R24），与图标
            // 左缘同线。s4 是 CL20 的基线微调：16 图标与 headline 首行光学居中。
            Padding(
              padding: const EdgeInsets.only(top: MileafSpace.s4),
              child: MileafIcon(
                MileafIconName.route,
                size: MileafIconMetrics.inline,
                color: journey.strong(colors),
              ),
            ),
            const SizedBox(width: MileafSpace.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          _recordTime(d),
                          maxLines: large ? null : 1,
                          overflow: large ? null : TextOverflow.ellipsis,
                          // R22：记录类行标题用 headline（与充电记录行同角色）。
                          style: type.headline,
                        ),
                      ),
                      if (d.endedAt == null) ...[
                        const SizedBox(width: MileafSpace.s8),
                        Text(
                          '进行中',
                          style: type.footnote.copyWith(color: colors.warning),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: MileafSpace.inline2),
                  Text(
                    _route(d),
                    maxLines: large ? null : 2,
                    overflow: large ? null : TextOverflow.ellipsis,
                    style: type.subheadline.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: MileafSpace.s8),
                  // R21 第 5 条/R21.5：固定读值网格取代 meta 串；MileafNumber
                  // 先量后画，360 宽先收列、200% 单列堆叠，数值与单位不拆行。
                  MetricGrid(
                    spacing: MileafSpace.s8,
                    children: [
                      MetricBlock(
                        label: '里程',
                        value: distance,
                        unit: distance == null ? null : 'km',
                        scale: MetricValueScale.metricSm,
                        semanticLabel: distance == null
                            ? '里程未记录'
                            : '里程 $distance km',
                        hue: journey,
                      ),
                      MetricBlock(
                        label: '时长',
                        value: duration,
                        unit: duration == null ? null : '分钟',
                        scale: MetricValueScale.metricSm,
                        hue: MileafDataDomain.dwell.hue,
                      ),
                      MetricBlock(
                        label: terms.energyPerKm,
                        value: net,
                        unit: net == null ? null : 'Wh/km',
                        scale: MetricValueScale.metricSm,
                        hue: MileafDataDomain.efficiency.hue,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _emptyListLabel =>
      selectedDay != null ? '所选日期没有行程' : messages.emptyMessage('行程');

  /// R24 分隔线：一物理像素，从行内文字起始处（卡内 16）到卡片右缘。
  Widget _hairline() => Container(
    height: 0,
    margin: const EdgeInsets.only(left: MileafSpace.cardPad),
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(
          color: context.colors.line,
          width: MileafStroke.hairline,
        ),
      ),
    ),
  );

  /// P02 记录按天分组：分组标题「今天 / 昨天 / 10月24日 周六」，每天一张分组卡。
  Widget _recentSection() {
    if (!loaded && items.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final type = context.type;
    if (items.isEmpty) {
      // MG09 空态分档：无筛选即 noData 档，现状句走 state_feedback 共享构造，
      // 下一步动作给 compact 文字动作槽；带日期筛选时空态的动作就是上方
      // 已有的「返回完整区间」，不另造第二个入口。
      if (selectedDay == null) {
        final empty = feedback.emptyStateCopy(
          feedback.EmptyStateTier.noData,
          object: '行程',
        );
        return StateView(
          kind: StateViewKind.empty,
          compact: true,
          title: empty.status,
          textActionLabel: empty.action,
          onTextAction: _refresh,
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: MileafSpace.s16),
        child: Text(
          _emptyListLabel,
          style: type.body.copyWith(color: colors.textSecondary),
        ),
      );
    }
    final today = workspace.calendar!.local(workspace.session.now());
    final groups = <String, List<dto.Drive>>{};
    for (final drive in items) {
      groups
          .putIfAbsent(
            copy.formatDayGroup(
              workspace.calendar!.local(drive.startedAt),
              today,
            ),
            () => [],
          )
          .add(drive);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: MileafSpace.s20),
            // MG05b：分组标题对齐卡内起始线（页面边距 + 16，R24 两条起始线）。
            child: MileafGroupHeader(
              title: entry.key,
              inset: MileafSpace.cardPad,
            ),
          ),
          const SizedBox(height: MileafSpace.s8),
          // R24：记录行走组卡，卡内横向内边 16；发丝线只画在行与行之间
          // （从卡内 16 到卡片右缘），每天最后一行不画线，卡片裁到圆角。
          MileafGroupCard(
            // CL57：一整组行程卡取 journey 洗底，列表页因此也有彩色面。
            hue: MileafDataDomain.journey.hue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < entry.value.length; index++) ...[
                  if (index > 0) _hairline(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MileafSpace.cardPad,
                    ),
                    child: _routeRow(entry.value[index]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// R30.2 页尾「关于这些数据」：时间与时区、记录与缺失、来源与生成时间。
  Widget _notes() => Padding(
    padding: const EdgeInsets.only(top: MileafSpace.section),
    child: MileafDataNotes(
      groups: [
        MileafDataNoteGroup(
          category: DataNoteCategory.time,
          note: '统计时区 ${workspace.calendar!.identifier}。',
        ),
        if (statsSnapshot.isNotEmpty)
          MileafDataNoteGroup(
            category: DataNoteCategory.records,
            note: '统计范围 ${timeRange(statsSnapshot)}。',
          ),
        if (result != null)
          MileafDataNoteGroup(
            category: DataNoteCategory.source,
            copyable: true,
            note:
                '数据生成时间 '
                '${copy.formatPrecise(workspace.calendar!.local(result!.checkedAt))}',
          ),
      ],
    ),
  );

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
            if (widget.topBar == null)
              SizedBox(height: MileafLayout.rootTopClearance(context)),
            MileafContent(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  inset,
                  MileafSpace.s8,
                  inset,
                  MileafLayout.rootNavigationClearance(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _periodRow(),
                    if (workspace.calendar!.fallback)
                      Padding(
                        padding: const EdgeInsets.only(top: MileafSpace.s8),
                        child: Text(
                          messages.timezoneUnreadableMessage(),
                          style: type.footnote.copyWith(color: colors.warning),
                        ),
                      ),
                    if (loading || statsLoading) ...[
                      const MileafProgressLine(),
                      Text(
                        loaded ? '正在更新' : messages.loadingMessage('行程'),
                        style: type.footnote.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
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
                        // MG09 时间要素：显示的仍是截至该时刻的缓存统计
                        //（state_feedback 共享构造，页面不写时间字面量）。
                        statusLine: driving == null || statsCheckedAt == null
                            ? null
                            : feedback.dataAsOfLine(statsCheckedAt!),
                        actionLabel: '重试行程统计',
                        onAction: () => loadStats(force: true),
                      ),
                    const SizedBox(height: MileafSpace.s12),
                    _summary(driving, loadingFirst: statsLoading),
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
                          '已显示全部 ${items.length} 趟',
                          textAlign: TextAlign.center,
                          style: type.footnote.copyWith(
                            color: colors.textFaint,
                          ),
                        ),
                      ),
                    _rhythmSection(driving),
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
