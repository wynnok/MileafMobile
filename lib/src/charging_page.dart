import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'api.dart';
import 'charging_cost.dart';
import 'copy/dates.dart' as copy;
import 'copy/durations.dart' as copy;
import 'copy/page_actions.dart' as copy_actions;
import 'copy/messages.dart' as messages;
import 'copy/terms.dart' as terms;

import 'design/components/components.dart';
import 'design/icons.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';

import 'charging_contract.g.dart' as dto;
import 'charging_experience_contract.g.dart' as expanded;
import 'charging_method.dart';
import 'charging_statistics_contract.g.dart' as legacy;
import 'overview_contract.g.dart' as overview;
import 'reading_scope.dart';
import 'session.dart';
import 'statistics_period.dart';
import 'workspace.dart';
import 'currency.dart';

/// A server cursor that never advances would page forever; the ledger keeps
/// what it already read and reports it with the shared CP07 pagination message
/// instead of blaming the contract version.

class ChargingFilter {
  DateTime? first, last;
}

/// A frozen statistics query opening the existing charging ledger.
class ChargingEntry {
  const ChargingEntry({
    required this.from,
    required this.to,
    this.chargingType,
    this.locationId,
    this.locationName,
  });
  final DateTime from, to;
  final String? chargingType, locationId, locationName;
}

class ChargingPage extends StatefulWidget {
  const ChargingPage({
    super.key,
    required this.workspace,
    required this.currency,
    this.onRecord,
    this.initialEntry,
    this.topBar,
    required this.filter,
  });
  final VehicleWorkspace workspace;
  final CurrencySettings currency;
  final ChargingFilter filter;
  final ChargingEntry? initialEntry;
  final void Function(String kind, int id)? onRecord;
  final Widget? topBar;
  @override
  State<ChargingPage> createState() => _ChargingPageState();
}

class _ChargingPageState extends State<ChargingPage>
    with
        WidgetsBindingObserver,
        ReadingLifecycle<ChargingPage>,
        CostAwareReading<ChargingPage> {
  final items = <dto.ChargingSession>[];
  String? next, error;
  bool loading = false, loaded = false, failedMore = false;

  /// 当最近一次成功读取的 `checkedAt`：失败且有已读页时，CP07 的「失败有旧
  /// 数据」用它说明当前显示的是什么时候的数据。
  DateTime? listCheckedAt;

  /// Set when a revalidation was cut short because the ledger stopped being
  /// visible. The records already on screen keep their range and cursor, and
  /// the whole read range is checked again on the next visible frame.
  bool revalidatePending = false;
  int revision = 0;
  int loadedPages = 0;
  int sequence = 0;
  int statsSequence = 0, capabilitySequence = 0;
  int locationSequence = 0, activeSequence = 0;
  int vehicleStateSequence = 0;
  bool expandedAvailable = false, statsLoading = false;
  bool costSupported = false, costSheetOpen = false;
  bool recordsOnly = false;
  bool capabilityChecked = false;
  bool locationsLoading = false;
  bool locationFailedMore = false;
  String? statsError, capabilityError;
  String? locationError, locationCursor, locationName;
  final locations = <expanded.ChargingLocation>[];
  final activeItems = <dto.ChargingSession>[];
  String? activeError;

  /// Latest `state.value` from `/vehicles/{id}/summary`; null means unknown.
  String? vehicleState;
  final search = TextEditingController();
  final scroll = ScrollController();
  String searchTerm = '', chargeType = 'all', costStatus = 'all';
  String sort = 'ended_desc';
  String? locationId;
  DateTime? selectedDay;
  int chartMetric = 0;

  /// Calendar date of the bucket the owner picked. The chart re-resolves it
  /// against the buckets it is given, so a refresh keeps the point by date and
  /// only an explicit condition change drops it.
  DateTime? chartDayAt;
  int recentDays = 30;
  int? matchedSessions;
  String? statsKey, locationsKey;
  DateTime? statsCheckedAt, locationsCheckedAt;
  expanded.ChargingStats? expandedStats;
  legacy.ChargingStats? legacyStats;
  late DateTime from, to;

  /// Identity of the records on screen: the range start and page size. The
  /// open end of a relative window follows the clock, so it is freshness, not
  /// reading identity — a revalidation keeps the pages already read.
  ({String from, String limit})? listRange;
  ({String from, String limit}) get _range {
    final query = listQuery();
    return (from: query['from']!, limit: query['limit']!);
  }

  @override
  VehicleWorkspace get workspace => widget.workspace;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    workspace.addListener(contextChanged);
    workspace.addCostReader(refreshCost);
    initCostReading();
    revision = workspace.revision;
    _owner = workspace.session.current;
    _vehicle = workspace.selectedId;
    interval();
    final entry = widget.initialEntry;
    if (entry != null) {
      from = entry.from;
      to = entry.to;
      chargeType = entry.chargingType ?? 'all';
      locationId = entry.locationId;
      locationName = entry.locationName;
      recordsOnly = true;
    } else {
      load();
    }
    loadCapability();
  }

  /// Set when the vehicle/session/calendar context changed while this tab was
  /// hidden or covered by a record detail: the stale reading state is dropped
  /// at once, the reads wait until the ledger is visible again.
  bool deferredContext = false;

  @override
  bool get readingDeferred => super.readingDeferred || deferredContext;

  SiteSession? _owner;
  int? _vehicle;

  void contextChanged() {
    if (!mounted ||
        revision == workspace.revision ||
        workspace.calendar == null) {
      return;
    }
    revision = workspace.revision;
    // A rebuilt context reads from scratch; a note from an interrupted read on
    // the old context must not force a second pass.
    revalidatePending = false;
    final owner = workspace.session.current, vehicle = workspace.selectedId;
    // A vehicle, site or session change has no reading context to keep. A
    // calendar change only invalidates the window-bound queries and cursors;
    // the owner's legal conditions and chosen dates stay as they were.
    final reset = owner != _owner || vehicle != _vehicle;
    _owner = owner;
    _vehicle = vehicle;
    interval();
    items.clear();
    next = null;
    loaded = false;
    loadedPages = 0;
    listRange = null;
    expandedStats = null;
    legacyStats = null;
    statsKey = null;
    locationsKey = null;
    statsSequence++;
    locationSequence++;
    activeSequence++;
    vehicleStateSequence++;
    activeItems.clear();
    vehicleState = null;
    locations.clear();
    locationCursor = null;
    matchedSessions = null;
    if (!reset && selectedDay != null && !_dayInRange(selectedDay!)) {
      selectedDay = null;
    }
    if (reset) {
      expandedAvailable = false;
      costSupported = false;
      recordsOnly = false;
      capabilityChecked = false;
      locationId = null;
      locationName = null;
      selectedDay = null;
      search.clear();
      searchTerm = '';
      chargeType = 'all';
      costStatus = 'all';
      sort = 'ended_desc';
      chartDayAt = null;
    }
    if (!readingVisible) {
      deferredContext = true;
      // The rebuild below refetches every charge-derived resource, so the fee
      // revision is settled here rather than forcing a second pass.
      consumeCost();
      return;
    }
    deferredContext = false;
    consumeCost();
    load();
    loadCapability();
  }

  /// Whether a selected day still falls inside the current window.
  bool _dayInRange(DateTime day) {
    final start = workspace.calendar!.midnight(day);
    return !start.isBefore(from) && start.isBefore(to);
  }

  void interval() {
    final local = workspace.calendar!.local(workspace.session.now());
    from = workspace.calendar!.midnight(
      widget.filter.first ??
          DateTime(local.year, local.month, local.day - recentDays + 1),
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
    statsSequence++;
    capabilitySequence++;
    locationSequence++;
    activeSequence++;
    vehicleStateSequence++;
    search.dispose();
    scroll.dispose();
    workspace.removeListener(contextChanged);
    workspace.removeCostReader(refreshCost);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> loadCapability({
    bool force = false,
    bool refreshData = true,
  }) async {
    final owner = workspace.session.current;
    final vehicle = workspace.selectedId;
    if (owner == null || vehicle == null) return;
    final attempt = ++capabilitySequence;
    var available = expandedAvailable;
    var costAvailable = costSupported;
    var recognized = capabilityChecked;
    String? failure;
    try {
      final meta = await workspace.cache.get(owner, 'meta', force: force);
      final version = meta.body['version'];
      costAvailable = supportsChargingCost(version);
      final capability = meta.body['charging_experience'];
      final parts = version is String
          ? RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(version)
          : null;
      recognized = parts != null;
      available =
          parts != null &&
          (int.parse(parts[1]!) > 0 || int.parse(parts[2]!) >= 2) &&
          capability is Map &&
          capability['contract_version'] == 'charging-experience-v1' &&
          capability['fields'] is Map;
    } catch (_) {
      failure = '无法更新站点能力；已有记录仍可查看';
    }
    if (!mounted ||
        attempt != capabilitySequence ||
        !workspace.session.isCurrent(owner) ||
        workspace.selectedId != vehicle) {
      return;
    }
    if (!readingPresent && !costSheetOpen) {
      return;
    }
    final changed = available != expandedAvailable;
    setState(() {
      expandedAvailable = available;
      costSupported = costAvailable;
      capabilityChecked = recognized;
      capabilityError = failure;
    });
    if (widget.initialEntry != null && !available) {
      setState(() {
        items.clear();
        next = null;
        loaded = false;
        error = '${messages.unsupportedMessage('按结束日筛选')}，请更新能力后重试';
      });
      return;
    }
    if (changed) {
      next = null;
      items.clear();
      loaded = false;
      // The old page range belonged to the previous contract; re-read from the
      // first page rather than replaying it with the new one.
      loadedPages = 0;
      listRange = null;
      activeSequence++;
      locationSequence++;
      activeItems.clear();
      vehicleState = null;
      vehicleStateSequence++;
      locations.clear();
      locationCursor = null;
      matchedSessions = null;
      selectedDay = null;
      if (!available) {
        recordsOnly = false;
        locationId = null;
        locationName = null;
        search.clear();
        searchTerm = '';
        chargeType = 'all';
        costStatus = 'all';
        sort = 'ended_desc';
      }
      if (refreshData) load(force: true);
    }
    if (refreshData && mounted && attempt == capabilitySequence && recognized) {
      await Future.wait([
        loadStats(),
        if (available) loadLocations(),
        if (available && widget.initialEntry == null) loadActive(),
      ]);
    }
  }

  Map<String, String> get queryFilters => {
    if (expandedAvailable && searchTerm.isNotEmpty) 'query': searchTerm,
    if (expandedAvailable && chargeType != 'all') 'charging_type': chargeType,
    if (expandedAvailable && costStatus != 'all') 'cost_status': costStatus,
    if (expandedAvailable && locationId != null) 'location_id': locationId!,
  };

  bool get hasFilters =>
      searchTerm.isNotEmpty ||
      chargeType != 'all' ||
      costStatus != 'all' ||
      locationId != null;

  void clearFilters() {
    search.clear();
    chargeType = 'all';
    costStatus = 'all';
    locationId = null;
    locationName = null;
    sort = 'ended_desc';
    applyFilters();
  }

  Map<String, String> get sharedQuery => {
    'from': from.toIso8601String(),
    'to': to.toIso8601String(),
    'tz': workspace.calendar!.identifier,
    'time_basis': 'ended_at',
    ...queryFilters,
  };

  Map<String, String> listQuery({String? cursor}) {
    final day = selectedDay;
    final dayFrom = day == null ? from : workspace.calendar!.midnight(day);
    final dayTo = day == null
        ? to
        : workspace.calendar!.midnight(day, nextDays: 1);
    return {
      'from': dayFrom.toIso8601String(),
      'to': (dayTo.isAfter(to) ? to : dayTo).toIso8601String(),
      'limit': '20',
      if (expandedAvailable) ...{
        'tz': workspace.calendar!.identifier,
        'time_basis': 'ended_at',
        'sort': sort,
        ...queryFilters,
      },
      'cursor': ?cursor,
    };
  }

  void applyFilters() {
    setState(() {
      searchTerm = search.text.trim();
      selectedDay = null;
      next = null;
      locationCursor = null;
      locations.clear();
      expandedStats = null;
      legacyStats = null;
      statsKey = null;
      locationsKey = null;
      items.clear();
      activeItems.clear();
      matchedSessions = null;
      loaded = false;
      chartDayAt = null;
    });
    load();
    loadStats();
    loadLocations();
    loadActive();
  }

  /// `is_active` only means the upstream charging process has no end time yet
  /// (an offline mid-charge session keeps it open). Only the vehicle's own
  /// state may claim "正在充电"; anything else keeps the row hidden.
  bool get activeConfirmed => vehicleState == 'charging';

  /// Reads the vehicle state shared with the overview page. Failure keeps
  /// [vehicleState] null: without proof the row stays hidden.
  Future<void> loadVehicleState({bool force = false}) async {
    final owner = workspace.session.current;
    final vehicle = workspace.selectedId;
    final calendar = workspace.calendar;
    if (owner == null || vehicle == null || calendar == null) return;
    final attempt = ++vehicleStateSequence;
    String? value;
    try {
      final result = await workspace.cache.get(
        owner,
        'vehicles/$vehicle/summary',
        query: {'tz': calendar.identifier},
        force: force,
      );
      final decoded = overview.Summary.fromJson(result.body);
      if (decoded.vehicle.id != vehicle) throw const FormatException();
      value = decoded.state?.value;
    } catch (_) {
      value = null;
    }
    if (!mounted ||
        attempt != vehicleStateSequence ||
        !workspace.session.isCurrent(owner) ||
        workspace.selectedId != vehicle) {
      return;
    }
    if (value != vehicleState) setState(() => vehicleState = value);
  }

  Future<void> loadActive({bool force = false}) async {
    final owner = workspace.session.current;
    final vehicle = workspace.selectedId;
    if (!expandedAvailable || owner == null || vehicle == null) return;
    final attempt = ++activeSequence;
    await loadVehicleState(force: force);
    if (!mounted ||
        !readingPresent ||
        attempt != activeSequence ||
        !workspace.session.isCurrent(owner) ||
        workspace.selectedId != vehicle) {
      return;
    }
    try {
      final result = await workspace.cache.get(
        owner,
        'vehicles/$vehicle/charging-sessions',
        query: {
          ...sharedQuery,
          'time_basis': 'started_at',
          'sort': 'started_desc',
          'limit': '20',
        },
        force: force,
      );
      final page = expanded.ChargingSessionPage.fromJson(result.body);
      final legacyPage = dto.ChargingSessionPage.fromJson(result.body);
      if (!mounted ||
          attempt != activeSequence ||
          !workspace.session.isCurrent(owner) ||
          workspace.selectedId != vehicle) {
        return;
      }
      final activeIds = page.items
          .where((item) => item.isActive)
          .map((item) => item.id)
          .toSet();
      setState(() {
        activeItems
          ..clear()
          ..addAll(
            legacyPage.items.where((item) => activeIds.contains(item.id)),
          );
        activeError = null;
      });
    } catch (_) {
      if (mounted &&
          attempt == activeSequence &&
          workspace.session.isCurrent(owner) &&
          workspace.selectedId == vehicle) {
        setState(() => activeError = messages.readFailedMessage('进行中的充电'));
      }
    }
  }

  Future<void> loadLocations({bool more = false, bool force = false}) async {
    final owner = workspace.session.current;
    final vehicle = workspace.selectedId;
    if (!expandedAvailable || owner == null || vehicle == null) return;
    if (more && (locationsLoading || locationCursor == null)) return;
    final attempt = ++locationSequence;
    if (!from.isBefore(to) || to.difference(from) > const Duration(days: 730)) {
      setState(() {
        locations.clear();
        locationCursor = null;
        locationsLoading = false;
        locationError = '充电地点最长支持 730 天的区间';
      });
      return;
    }
    final cursor = more ? locationCursor : null;
    final key = Uri(queryParameters: sharedQuery).query;
    setState(() {
      if (!more && locationsKey != key) {
        locations.clear();
        locationCursor = null;
      }
      locationsLoading = true;
      locationError = null;
      locationFailedMore = more;
    });
    try {
      final result = await workspace.cache.get(
        owner,
        'vehicles/$vehicle/charging-locations',
        query: {...sharedQuery, 'limit': '20', 'cursor': ?cursor},
        force: force,
      );
      final page = expanded.ChargingLocationPage.fromJson(result.body);
      if (!mounted ||
          attempt != locationSequence ||
          !workspace.session.isCurrent(owner) ||
          workspace.selectedId != vehicle) {
        return;
      }
      setState(() {
        if (!more) locations.clear();
        final ids = locations.map((location) => location.locationId).toSet();
        locations.addAll(page.items.where((item) => ids.add(item.locationId)));
        locationCursor = page.nextCursor;
        locationsKey = key;
        locationsCheckedAt = result.checkedAt;
        if (more && page.nextCursor != null && page.nextCursor == cursor) {
          locationError = messages.paginationFailedMessage('地点');
        }
      });
    } catch (_) {
      if (mounted &&
          attempt == locationSequence &&
          workspace.session.isCurrent(owner) &&
          workspace.selectedId == vehicle) {
        final hadSnapshot = locationsKey == key && locationsCheckedAt != null;
        setState(
          () => locationError = hadSnapshot
              ? messages.staleMessage(
                  workspace.calendar!.local(locationsCheckedAt!),
                  workspace.calendar!.local(workspace.session.now()),
                )
              : messages.readFailedMessage('充电地点'),
        );
      }
    } finally {
      if (mounted && attempt == locationSequence) {
        setState(() => locationsLoading = false);
      }
    }
  }

  Future<void> loadStats({bool force = false}) async {
    final owner = workspace.session.current;
    final vehicle = workspace.selectedId;
    if (owner == null || vehicle == null) return;
    final attempt = ++statsSequence;
    final useExpanded = expandedAvailable;
    final statsQuery = {
      'kind': 'charging',
      'bucket': 'day',
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
      'tz': workspace.calendar!.identifier,
      if (useExpanded) 'time_basis': 'ended_at',
      ...queryFilters,
    };
    final key = Uri(queryParameters: statsQuery).query;
    if (!from.isBefore(to) || to.difference(from) > const Duration(days: 730)) {
      setState(() {
        expandedStats = null;
        legacyStats = null;
        statsLoading = false;
        statsError = '统计最长支持 730 天，请缩短时间段';
      });
      return;
    }
    setState(() {
      if (statsKey != key) {
        expandedStats = null;
        legacyStats = null;
      }
      statsLoading = true;
      statsError = null;
    });
    try {
      final result = await workspace.cache.get(
        owner,
        'vehicles/$vehicle/stats',
        query: statsQuery,
        force: force,
      );
      final value = useExpanded
          ? expanded.ChargingStats.fromJson(result.body)
          : legacy.ChargingStats.fromJson(result.body);
      if (!mounted ||
          attempt != statsSequence ||
          !workspace.session.isCurrent(owner) ||
          workspace.selectedId != vehicle) {
        return;
      }
      setState(() {
        expandedStats = value is expanded.ChargingStats ? value : null;
        legacyStats = value is legacy.ChargingStats ? value : null;
        statsKey = key;
        statsCheckedAt = result.checkedAt;
      });
    } catch (_) {
      if (mounted &&
          attempt == statsSequence &&
          workspace.session.isCurrent(owner) &&
          workspace.selectedId == vehicle) {
        final hadSnapshot = statsKey == key && statsCheckedAt != null;
        setState(
          () => statsError = hadSnapshot
              ? messages.staleMessage(
                  workspace.calendar!.local(statsCheckedAt!),
                  workspace.calendar!.local(workspace.session.now()),
                )
              : messages.readFailedMessage('充电统计'),
        );
      }
    } finally {
      if (mounted && attempt == statsSequence) {
        setState(() => statsLoading = false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (readingVisible && state == AppLifecycleState.resumed) foreground();
  }

  @override
  Future<void> resumeReading() => foreground();

  Future<void> foreground() async {
    final changed = await workspace.foreground();
    // The owner may have hidden the ledger or opened a detail while the
    // calendar was read; then this pass must not start reads behind them.
    if (!mounted || !readingPresent) return;
    // Work deferred while hidden runs first: a dropped context is rebuilt from
    // scratch, a deferred fee refresh revalidates the pages already read.
    if (deferredContext) {
      deferredContext = false;
      revalidatePending = false;
      consumeCost();
      await Future.wait([load(), loadCapability()]);
      return;
    }
    if (costPending) {
      final owner = workspace.session.current;
      final vehicle = workspace.selectedId;
      final range = _range;
      // The fee is pending while the site may also have changed capability;
      // check that first so the revalidation never speaks for an old contract.
      await loadCapability(refreshData: false);
      if (!mounted ||
          (!readingPresent && !costSheetOpen) ||
          !identical(workspace.session.current, owner) ||
          workspace.selectedId != vehicle ||
          _range != range) {
        return;
      }
      final refreshed = await _refreshCostData();
      if (mounted && refreshed) consumeCost();
      return;
    }
    if (revalidatePending) {
      // A read cut short by hiding still owes the whole range the owner read.
      revalidatePending = false;
      interval();
      final previous = listRange;
      final same = previous != null && previous == _range;
      await Future.wait([
        load(preservePages: same),
        loadStats(),
        if (expandedAvailable) loadLocations(),
        if (expandedAvailable) loadActive(),
      ]);
      return;
    }
    if (changed) return;
    final session = workspace.session.current;
    final vehicle = workspace.selectedId;
    if (session == null || vehicle == null) return;
    final range = _range;
    await loadCapability(refreshData: false);
    if (!mounted ||
        _range != range ||
        (!readingPresent && !costSheetOpen) ||
        !workspace.session.isCurrent(session) ||
        workspace.selectedId != vehicle) {
      return;
    }
    final owner = workspace.session.current;
    final cached = owner == null
        ? null
        : workspace.cache.peek(
            owner,
            'vehicles/${workspace.selectedId}/charging-sessions',
            listQuery(),
          );
    if (cached?.validUntil.isAfter(workspace.session.now()) ?? false) {
      await Future.wait([
        if (!loaded) load(),
        loadStats(),
        if (expandedAvailable) loadLocations(),
        if (expandedAvailable) loadActive(),
      ]);
      return;
    }
    interval();
    final previous = listRange;
    final same = previous != null && previous == _range;
    await Future.wait([
      load(preservePages: same),
      loadStats(),
      if (expandedAvailable) loadLocations(),
      if (expandedAvailable) loadActive(),
    ]);
  }

  Future<void> refreshAll() async {
    final owner = workspace.session.current;
    final vehicle = workspace.selectedId;
    if (owner == null || vehicle == null) return;
    interval();
    await loadCapability(force: true, refreshData: false);
    if (!mounted ||
        (!readingPresent && !costSheetOpen) ||
        !workspace.session.isCurrent(owner) ||
        workspace.selectedId != vehicle) {
      return;
    }
    await Future.wait([
      load(force: true),
      loadStats(force: true),
      if (expandedAvailable) loadLocations(force: true),
      if (expandedAvailable) loadActive(force: true),
    ]);
  }

  Future<bool> refreshCost() async {
    // A hidden ledger, or one covered by a record detail, keeps its snapshot
    // and revalidates the pages already read on its next visible frame. The
    // fee sheet is this page's own reading context, so that one refreshes
    // inline and can report its real result instead of a deferral.
    if (!readingVisible && !costSheetOpen) {
      deferCost();
      return false;
    }
    final refreshed = await _refreshCostData();
    if (refreshed) consumeCost();
    return refreshed;
  }

  Future<bool> _refreshCostData() async {
    await Future.wait([
      load(force: true, preservePages: true),
      loadStats(force: true),
      if (expandedAvailable) loadLocations(force: true),
    ]);
    return error == null && statsError == null && locationError == null;
  }

  Future<void> load({
    bool more = false,
    bool force = false,
    bool preservePages = false,
  }) async {
    if (widget.initialEntry != null && !expandedAvailable) {
      await loadCapability(force: force);
      return;
    }
    if (more && (loading || next == null)) return;
    if (!more && force && !preservePages) {
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
    final range = _range;
    // One fixed query snapshot per read: a page that arrives late must never
    // append its cursor to conditions the owner changed in the meantime.
    final requested = listQuery();
    setState(() {
      loading = true;
      error = null;
      failedMore = more;
    });
    bool current() =>
        mounted &&
        attempt == sequence &&
        workspace.session.isCurrent(session) &&
        workspace.selectedId == id;
    bool owned() => current() && mapEquals(listQuery(), requested);
    try {
      final page = <dto.ChargingSession>[];
      String? following = cursor;
      int? matched;
      var pages = 0;
      final targetPages = preservePages
          ? (loadedPages < 1 ? 1 : loadedPages)
          : 1;
      final visited = <String?>{};
      var stalled = false;
      var interrupted = false;
      do {
        if (!visited.add(following)) {
          stalled = true;
          break;
        }
        final value = await workspace.cache.get(
          session,
          'vehicles/$id/charging-sessions',
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
        final decoded = dto.ChargingSessionPage.fromJson(value.body);
        listCheckedAt = value.checkedAt;
        matched = expandedAvailable
            ? expanded.ChargingSessionPage.fromJson(value.body).matchedSessions
            : null;
        page.addAll(decoded.items);
        following = decoded.nextCursor;
        pages++;
      } while (preservePages && pages < targetPages && following != null);
      if (!current()) return;
      if (interrupted) {
        // Keep the pages, their cursor and their range exactly as they were;
        // the abandoned read is retried when the ledger is visible again. An
        // interrupted "load more" leaves no failure for the retry action.
        if (more) {
          failedMore = false;
        } else {
          revalidatePending = true;
        }
        return;
      }
      if (stalled) {
        // A cursor that stops advancing cannot rebuild the range the owner
        // read, so the visible pages and their cursor stay exactly as they
        // were instead of being replaced by a truncated list.
        setState(() {
          error = messages.paginationFailedMessage('充电');
          failedMore = false;
        });
        return;
      }
      setState(() {
        if (!more) items.clear();
        final ids = items.map((v) => v.id).toSet();
        for (final v in page) {
          if (ids.add(v.id)) items.add(v);
        }
        next = following;
        loadedPages = more ? loadedPages + pages : pages;
        listRange = range;
        matchedSessions = matched;
        if (more && following != null && following == cursor) {
          error = messages.paginationFailedMessage('充电');
          failedMore = false;
        }
        loaded = true;
        if (!more) revalidatePending = false;
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
        final clock = workspace.calendar!.local(workspace.session.now());
        final snapshot = items.isNotEmpty && listCheckedAt != null;
        setState(() {
          error = e is FormatException
              ? messages.versionIncompatibleMessage()
              : e is ApiFailure
              ? e.message
              : messages.readFailedMessage('充电记录');
          if (snapshot) {
            error = messages.staleMessage(
              workspace.calendar!.local(listCheckedAt!),
              clock,
            );
          }
          if (!more) revalidatePending = false;
        });
      }
    } finally {
      if (mounted && attempt == sequence) setState(() => loading = false);
    }
  }

  /// Manual retry of a failed read. A failed extra page keeps its own cursor;
  /// a failed revalidation keeps the range and pages already read instead of
  /// collapsing the ledger back to the first page.
  Future<void> retryLoad() async {
    if (failedMore) {
      await load(more: true, force: true);
      return;
    }
    await load(force: true, preservePages: listRange == _range);
  }

  Future<void> filterDates() async {
    final calendar = workspace.calendar!;
    final today = calendar.local(workspace.session.now());
    final last = DateTime(today.year, today.month, today.day);
    // R27/PD10：三套日期输入合并为共享弹层。默认区间沿用本页的原窗口；归期
    // 口径与原校验（开始不晚于结束、不选未来日期）由本页注入，730 天上限仍由
    // 统计与地点的读取路径执行，组件不内置业务规则。
    final initial = DateTimeRange(
      start:
          widget.filter.first ?? DateTime(today.year, today.month, today.day),
      end: widget.filter.last ?? last,
    );
    final range = await readingEditor(
      () => showMileafDateRangeSheet(
        context: context,
        initialRange: initial,
        firstDate: DateTime(1900),
        lastDate: last,
        today: today,
        validator: (start, end) {
          if (end.isAfter(last)) return '结束日期不能晚于今天';
          if (start.isAfter(end)) return '开始日期不能晚于结束日期';
          if (start.year < 1970) return '开始日期不能早于 1970 年';
          return null;
        },
      ),
    );
    if (!mounted || range == null) return;
    widget.filter.first = range.start;
    widget.filter.last = range.end;
    interval();
    items.clear();
    next = null;
    loaded = false;
    selectedDay = null;
    matchedSessions = null;
    expandedStats = null;
    legacyStats = null;
    statsKey = null;
    chartDayAt = null;
    locationsKey = null;
    locations.clear();
    await Future.wait([
      load(force: true),
      loadStats(force: true),
      if (expandedAvailable) loadLocations(force: true),
      if (expandedAvailable) loadActive(force: true),
    ]);
  }

  String number(num? v, String unit) => v == null ? '—' : '${decimal(v)} $unit';
  DateTime get _today => workspace.calendar!.local(workspace.session.now());
  String recordDay(DateTime value) {
    final local = workspace.calendar!.local(value);
    return '${local.year}年${local.month}月${local.day}日';
  }

  DateTime recordTime(dto.ChargingSession value) =>
      expandedAvailable ? value.endedAt ?? value.startedAt : value.startedAt;

  void showDay(DateTime? day) {
    if (day != null) {
      final start = workspace.calendar!.midnight(day);
      if (start.isBefore(from) || !start.isBefore(to)) return;
    }
    setState(() {
      selectedDay = day;
      if (day != null) recordsOnly = true;
      next = null;
      matchedSessions = null;
      items.clear();
      loaded = false;
    });
    if (day != null) scrollToTop();
    load();
  }

  /// 回到顶部：先同步跳到 0，再等这一帧结束后兜底一次。内容模式切换会让
  /// 页面骤然变短，若等到下一帧才收敛位置，视口会在布局阶段因夹紧而发出滚动
  /// 通知，外层外壳的滚动监听因此会在布局中被唤醒（「Build scheduled during
  /// frame」）。先跳再换内容就不会走到那条路径。
  void scrollToTop() {
    if (scroll.hasClients && scroll.offset > 0) scroll.jumpTo(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients && scroll.offset > 0) scroll.jumpTo(0);
    });
  }

  /// P03 账目卡：已记录费用（metricLg）+ 覆盖句 + 币种注。三格（充入电量 /
  /// 充入均价 / 充电时长）按 §6 退让阶梯第 4 步移到每日充电图之后（见
  /// [_accountCellsCard]）；充入均价的口径限定语随格就近出现（CP08）。
  Widget _accountCard(expanded.ChargingStats stats) {
    final type = context.type;
    final colors = context.colors;
    final total = stats.totals;
    final missing = total.cost == null || total.costKnownSessions == 0;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MileafLayout.pageInset(context),
        MileafSpace.s4,
        MileafLayout.pageInset(context),
        0,
      ),
      child: MileafModuleCard(
        // §6 阶梯第 2 步：焦点卡内边 16 → 12。
        padding: const EdgeInsets.all(MileafSpace.cardInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              terms.recordedCost,
              style: type.subheadline.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: MileafSpace.s4),
            // S06：0 元是真实 0，只有「无费用记录」才显示 —。
            MileafNumber(
              value: missing ? null : widget.currency.amountValue(total.cost),
              scale: MetricValueScale.metricLg,
            ),
            const SizedBox(height: MileafSpace.s4),
            Text(
              // CP02 覆盖句式：9 次中 8 次有费用，对应充入 214 kWh。
              '${total.sessions} 次中 ${total.costKnownSessions} 次有费用，'
              '对应充入 ${decimal(total.costKnownEnergyKwh)} kWh',
              style: type.subheadline.copyWith(color: colors.textSecondary),
            ),
            if (widget.currency.amountNote case final note?) ...[
              const SizedBox(height: MileafSpace.s4),
              Text(
                note,
                style: type.footnote.copyWith(color: colors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// §6 阶梯第 4 步：账目三格（充入电量 / 充入均价 / 充电时长，R21.5 只用
  /// metricSm）放在每日充电图之后，保住「无进行中时第一条记录完整」的首屏预算。
  Widget _accountCellsCard(expanded.ChargingStats stats) {
    final total = stats.totals;
    final energyMissing = total.energyKnownSessions == 0;
    final durationMissing = total.durationKnownSessions == 0;
    final unitCost = total.unitCostAdded.value;
    final energy = energyMissing ? null : decimal(total.energyAddedKwh);
    final energyNote =
        total.sessions > 0 && total.energyKnownSessions < total.sessions
        ? '${total.sessions} 次中 ${total.energyKnownSessions} 次有记录'
        : null;
    final cells = [
      MetricBlock(
        label: terms.chargedEnergy,
        value: energy,
        unit: energyMissing ? null : 'kWh',
        scale: MetricValueScale.metricSm,
        note: energyNote,
        semanticLabel: energyMissing
            ? '${terms.chargedEnergy}未知'
            : '${terms.chargedEnergy} ${decimal(total.energyAddedKwh)} 千瓦时',
      ),
      MetricBlock(
        label: terms.averagePrice,
        value: unitCost == null ? null : decimal(unitCost),
        unit: unitCost == null ? null : '${widget.currency.symbol}/kWh',
        scale: MetricValueScale.metricSm,
        note: '按充入电池的电量计，仅含有费用的充电',
        semanticLabel: unitCost == null
            ? '${terms.averagePrice}未知'
            : '${terms.averagePrice} ${decimal(unitCost)}，按充入电池的电量计',
      ),
      MetricBlock(
        label: '充电时长',
        value: durationMissing
            ? null
            : copy.duration(Duration(minutes: total.durationMinTotal.round())),
        scale: MetricValueScale.metricSm,
        semanticLabel: durationMissing
            ? '充电时长未知'
            : '充电时长 ${copy.duration(Duration(minutes: total.durationMinTotal.round()))}',
      ),
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MileafLayout.pageInset(context),
        MileafSpace.s12,
        MileafLayout.pageInset(context),
        0,
      ),
      child: MileafModuleCard(
        padding: const EdgeInsets.all(MileafSpace.cardInset),
        child: MileafLayout.largeText(context)
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final cell in cells) ...[
                    cell,
                    const SizedBox(height: MileafSpace.s12),
                  ],
                ],
              )
            : // R21.5：三列网格只用 metricSm；放不下时网格先两列再单列。
              MetricGrid(columns: 3, spacing: MileafSpace.s12, children: cells),
      ),
    );
  }

  /// P03 每日充电卡：分段（电量/费用/均价/次数）+ 紧凑读数行 + 88 高的图（R29）。
  Widget _trendCard(expanded.ChargingStats stats) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MileafLayout.pageInset(context),
        MileafSpace.s8,
        MileafLayout.pageInset(context),
        0,
      ),
      child: MileafModuleCard(
        // §6 阶梯第 2 步：卡内边 16 → 12。
        padding: const EdgeInsets.all(MileafSpace.cardInset),
        child: _trend(stats),
      ),
    );
  }

  Widget _trend(expanded.ChargingStats stats) {
    final active = stats.buckets.any((bucket) => bucket.sessions > 0);
    if (!active) {
      final colors = context.colors;
      final type = context.type;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('每日充电', style: type.headline.copyWith(color: colors.text)),
          const SizedBox(height: MileafSpace.s8),
          Text(
            // CP07 空：这段时间没有充电（与方式的首次空「还没有充电记录」区分）。
            messages.emptyMessage('充电'),
            style: type.body.copyWith(color: colors.textSecondary),
          ),
        ],
      );
    }
    final entries = [
      ('电量', 'kWh'),
      ('费用', widget.currency.symbol),
      ('均价', '${widget.currency.symbol}/kWh'),
      ('次数', '次'),
    ];
    final metric = entries[chartMetric];
    // AP05 的图表按本地墙钟写轴与读数；bucket_start 是 UTC 瞬时，先换墙钟，
    // 否则读数行与 X 轴会比站点日历早一天（与 AP07 概览/行程同一修正）。
    final times = [
      for (final bucket in stats.buckets)
        workspace.calendar!.local(bucket.bucketStart),
    ];
    final lastActive = stats.buckets.lastIndexWhere((b) => b.sessions > 0);
    final selected =
        bucketIndexAt(times, chartDayAt) ??
        (stats.buckets.isEmpty
            ? 0
            : (lastActive < 0 ? stats.buckets.length - 1 : lastActive));
    final values = [
      for (final bucket in stats.buckets)
        switch (chartMetric) {
          0 =>
            bucket.sessions > 0 && bucket.energyKnownSessions == 0
                ? null
                : bucket.energyAddedKwh,
          1 => bucket.cost,
          2 => bucket.unitCostAdded.value,
          _ => bucket.sessions,
        },
    ];
    return StemChart(
      title: '每日充电',
      unit: metric.$2,
      times: times,
      values: values,
      semanticsLabel: '每日充电图表',
      plotKey: const Key('charging-briefing-chart'),
      selectedIndex: selected,
      onSelected: (index) => setState(() => chartDayAt = times[index]),
      height: MileafSpace.rhythmHeight,
      // R29 紧凑读数行：一行内日期、数值与行尾下钻；朗读句用 DF1 日期。
      compactReadout: true,
      readout: (index) {
        if (index < 0 || index >= stats.buckets.length) return '—';
        final bucket = stats.buckets[index];
        final day = copy.formatDay(times[index], _today);
        final value = switch (chartMetric) {
          0 =>
            bucket.sessions > 0 && bucket.energyKnownSessions == 0
                ? '—'
                : '${decimal(bucket.energyAddedKwh)} kWh',
          1 => widget.currency.amountValue(bucket.cost),
          2 => switch (bucket.unitCostAdded.value) {
            final value? => '${decimal(value)} ${widget.currency.symbol}/kWh',
            null => '—',
          },
          _ => '${bucket.sessions} 次',
        };
        return '$day，$value';
      },
      onActivateSelected: stats.buckets.isEmpty
          ? null
          : () {
              final local = times[selected];
              showDay(DateTime(local.year, local.month, local.day));
            },
      activationLabel: '查看这一天的充电',
      headerTrailing: ChipRow(
        equalWidth: true,
        children: [
          for (final (index, entry) in entries.indexed)
            StatusChip(
              label: entry.$1,
              selected: chartMetric == index,
              onTap: () => setState(() => chartMetric = index),
            ),
        ],
      ),
    );
  }

  /// 「充电方式」：一句结论（类型未知分行）→ 构成环 + 图例 → 三列绝对量 →
  /// 分母口径脚注。
  ///
  /// The ring shares the exact denominator of \`dc_energy_share\` (AC + DC known
  /// energy); unknown energy is declared in the note instead of becoming a
  /// third arc, so one screen never shows two different DC percentages.
  Widget _methodCard(expanded.ChargingStats stats) {
    final reading = ChargingMethodReading.from(stats.totals);
    final colors = context.colors;
    final type = context.type;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MileafLayout.pageInset(context),
        MileafSpace.section,
        MileafLayout.pageInset(context),
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: '充电方式'),
          const SizedBox(height: MileafSpace.s8),
          MileafModuleCard(
            padding: const EdgeInsets.fromLTRB(
              MileafSpace.s8,
              MileafSpace.s12,
              MileafSpace.s8,
              MileafSpace.s12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  reading.conclusion,
                  style: type.body.copyWith(color: colors.text),
                ),
                if (reading.unknownLine.isNotEmpty) ...[
                  const SizedBox(height: MileafSpace.s4),
                  // CP09：类型未知不拼进结论句，单独一行。
                  Text(
                    reading.unknownLine,
                    style: type.body.copyWith(color: colors.text),
                  ),
                ],
                const SizedBox(height: MileafSpace.s16),
                _supplyRing(reading),
                if (reading.categories.isNotEmpty) ...[
                  const SizedBox(height: MileafSpace.s20),
                  Container(height: 1, color: colors.line),
                  const SizedBox(height: MileafSpace.s16),
                  _categoryColumns(reading.categories),
                ],
                if (reading.note.isNotEmpty) ...[
                  const SizedBox(height: MileafSpace.s12),
                  Text(
                    reading.note,
                    style: type.footnote.copyWith(color: colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _supplyRing(ChargingMethodReading reading) {
    final colors = context.colors;
    final ring = MileafShareRing(
      segments: [
        ShareRingSegment(
          label: 'AC',
          value: reading.acShare,
          color: colors.seriesPrimary,
        ),
        ShareRingSegment(
          label: 'DC',
          value: reading.dcShare,
          color: colors.seriesSecondary,
        ),
      ],
      centerValue: reading.centerValue,
      centerLabel: reading.centerLabel,
    );
    if (!reading.showLegend) {
      return Center(child: ring);
    }
    Widget legend(
      String label,
      String share,
      Color color,
      String chargeFilter,
    ) => ShareRingLegendRow(
      color: color,
      label: label,
      share: share,
      onTap: () => openType(chargeFilter),
      semanticsLabel: '查看 $label 充电记录',
    );
    final rows = <Widget>[
      legend(
        'AC',
        '${decimal(reading.acShare * 100)}%',
        colors.seriesPrimary,
        'ac',
      ),
      legend(
        'DC',
        '${decimal(reading.dcShare * 100)}%',
        colors.seriesSecondary,
        'dc',
      ),
    ];
    if (MileafLayout.largeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: ring),
          const SizedBox(height: MileafSpace.s16),
          ...rows,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ring,
        const SizedBox(width: MileafSpace.s24),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        ),
      ],
    );
  }

  Widget _categoryColumns(List<ChargingMethodCategory> categories) {
    final columns = [
      for (final category in categories) _categoryColumn(category),
    ];
    if (MileafLayout.largeText(context) || columns.length == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < columns.length; i++) ...[
            if (i > 0) const SizedBox(height: MileafSpace.s16),
            columns[i],
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < columns.length; i++) ...[
          if (i > 0) const SizedBox(width: MileafSpace.s16),
          Expanded(child: columns[i]),
        ],
      ],
    );
  }

  Widget _categoryColumn(ChargingMethodCategory category) {
    final colors = context.colors;
    final type = context.type;
    return Semantics(
      key: ValueKey('charging-method-column-${category.label}'),
      container: true,
      label:
          '${category.label} ${category.value}'
          '${category.unit == null ? '' : ' ${category.unit}'}，${category.note}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            category.label,
            style: type.subheadline.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: MileafSpace.s4),
          // 单位紧跟在空格之后：列宽不够时由文本引擎把它换到下一行，
          // 不缩小字号、不用 FittedBox（Spec §10.1）。
          Text.rich(
            TextSpan(
              text: category.value,
              style: type.metricMd.copyWith(color: colors.text),
              children: [
                if (category.unit != null)
                  TextSpan(
                    text: ' ${category.unit}',
                    style: type.footnote.copyWith(color: colors.textFaint),
                  ),
              ],
            ),
          ),
          const SizedBox(height: MileafSpace.s4),
          Text(
            category.note,
            style: type.footnote.copyWith(color: colors.textFaint),
          ),
        ],
      ),
    );
  }

  /// Jump to the record list pre-filtered by charging type (Spec §9).
  void openType(String value) {
    chargeType = value;
    recordsOnly = true;
    applyFilters();
    scrollToTop();
  }

  Widget _compositionSkeleton() {
    final inset = MileafLayout.pageInset(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, MileafSpace.section, inset, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: '充电方式'),
          const SizedBox(height: MileafSpace.s8),
          const SkeletonBlock(width: 160, height: 14),
          const SizedBox(height: MileafSpace.s16),
          const Row(
            children: [
              SkeletonBlock(
                width: MileafShareRingMetrics.diameter,
                height: MileafShareRingMetrics.diameter,
                radius: MileafShareRingMetrics.diameter / 2,
              ),
              SizedBox(width: MileafSpace.s24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBlock(width: 120, height: 12),
                  SizedBox(height: MileafSpace.s16),
                  SkeletonBlock(width: 96, height: 12),
                ],
              ),
            ],
          ),
          const SizedBox(height: MileafSpace.s20),
          const Row(
            children: [
              SkeletonBlock(width: 64, height: 40),
              SizedBox(width: MileafSpace.s16),
              SkeletonBlock(width: 64, height: 40),
              SizedBox(width: MileafSpace.s16),
              SkeletonBlock(width: 64, height: 40),
            ],
          ),
        ],
      ),
    );
  }

  Widget filterControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const Key('charging-search'),
        controller: search,
        maxLength: 100,
        decoration: const InputDecoration(labelText: '搜索地点'),
        onSubmitted: (_) => applyFilters(),
      ),
      Wrap(
        spacing: MileafSpace.s12,
        runSpacing: MileafSpace.s8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // R27：筛选改小胶囊下拉，按钮文字即当前值；菜单按 R28。
          MileafPullDown<String>(
            label: '类型',
            value: chargeType,
            onChanged: (value) {
              chargeType = value;
              applyFilters();
            },
            options: const [
              MileafPullDownOption(value: 'all', label: '全部类型'),
              MileafPullDownOption(value: 'ac', label: 'AC'),
              MileafPullDownOption(value: 'dc', label: 'DC'),
              MileafPullDownOption(value: 'unknown', label: '类型未知'),
            ],
          ),
          MileafPullDown<String>(
            label: '费用',
            value: costStatus,
            onChanged: (value) {
              costStatus = value;
              applyFilters();
            },
            options: const [
              MileafPullDownOption(value: 'all', label: '全部费用'),
              MileafPullDownOption(value: 'known', label: '费用已知'),
              MileafPullDownOption(value: 'unknown', label: '费用未知'),
              MileafPullDownOption(value: 'zero', label: '费用为零'),
            ],
          ),
          MileafPullDown<String>(
            label: '排序',
            value: sort,
            onChanged: (value) {
              sort = value;
              applyFilters();
            },
            options: const [
              MileafPullDownOption(value: 'ended_desc', label: '最近结束'),
              MileafPullDownOption(value: 'started_desc', label: '最近开始'),
              MileafPullDownOption(
                value: 'unit_cost_added_asc',
                label: '充入均价从低到高',
              ),
              MileafPullDownOption(value: 'duration_desc', label: '充电时长从长到短'),
            ],
          ),
          TextButton(onPressed: applyFilters, child: const Text('查找')),
          if (locationId != null)
            TextButton(
              onPressed: () {
                locationId = null;
                locationName = null;
                applyFilters();
              },
              child: Text('清除地点 ${locationName ?? ''}'),
            ),
        ],
      ),
    ],
  );

  /// 全部记录 ↔ 账本：入口在「最近充电」区块标题尾部的「查看全部」（CP06），
  /// 进入后顶部是一条二级导航（返回 + 标题「全部充电记录」），返回时沿用
  /// 原有的「退出日筛选」行为。
  void _toggleRecords({required bool open}) {
    final returning = recordsOnly;
    setState(() => recordsOnly = open);
    scrollToTop();
    if (returning && !open && selectedDay != null) showDay(null);
  }

  Widget _periodRow() {
    StatusChip chip(String label, int days) => StatusChip(
      label: label,
      selected: widget.filter.first == null && recentDays == days,
      onTap: () {
        recentDays = days;
        widget.filter.first = null;
        widget.filter.last = null;
        interval();
        applyFilters();
      },
    );
    final zone = workspace.calendar!;
    final start = zone.local(from);
    final end = zone.local(to.subtract(const Duration(microseconds: 1)));
    final range = copy.formatRange(start, end);
    final date = StatusChip(
      // CP06「同一位置的同类操作用同一个词」：四个根页期间行的自定义入口
      // 与行程页一致写「自定义」；完整区间与归期口径由语义标签补全。
      label: '自定义',
      selected: widget.filter.first != null,
      semanticLabel: '自定义日期，$range，按${expandedAvailable ? '结束' : '开始'}时间归期',
      onTap: filterDates,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // R25/R27：期间分段占剩余宽度，行尾是唯一的刷新圆钮——四个根页的
        // 期间行位置一致，不再出现「一行动作 + 一行胶囊」的两行结构。
        MileafPeriodRow(
          trailing: MileafIconButton(
            icon: MileafIconName.refresh,
            tooltip: '刷新充电',
            fill: MileafIconButtonFill.track,
            onPressed: loading ? null : refreshAll,
          ),
          children: [
            if (expandedAvailable) ...[chip('近30天', 30), chip('近7天', 7)],
            date,
          ],
        ),
        if (widget.filter.first != null || !expandedAvailable) ...[
          const SizedBox(height: MileafSpace.s8),
          Text(range, style: context.type.footnote),
        ],
      ],
    );
  }

  Widget _activeRow(dto.ChargingSession value) {
    final colors = context.colors;
    final type = context.type;
    return InkWell(
      key: ValueKey('charge-${value.id}'),
      onTap: () => widget.onRecord?.call('charge', value.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MileafSpace.s12),
        child: Row(
          children: [
            MileafIcon(
              MileafIconName.bolt,
              size: MileafIconMetrics.inline,
              color: colors.accent,
            ),
            const SizedBox(width: MileafSpace.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '正在充电，${value.location.displayName ?? '未知地点'}',
                    maxLines: MileafLayout.largeText(context) ? null : 2,
                    overflow: MileafLayout.largeText(context)
                        ? null
                        : TextOverflow.ellipsis,
                    style: type.headline,
                  ),
                  const SizedBox(height: MileafSpace.inline2),
                  Text(
                    // CP02/CP08：已充入 X kWh，结束后计入统计。
                    '已充入 ${number(value.energyAddedKwh, 'kWh')}，结束后计入统计',
                    style: type.footnote.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            MileafIcon(
              MileafIconName.chevron,
              size: MileafIconMetrics.inline,
              color: colors.textFaint,
            ),
          ],
        ),
      ),
    );
  }

  Widget _legacySummary(legacy.ChargingStats stats) {
    final type = context.type;
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // 0.1/0.2 合约没有费用覆盖计数，无法区分「未知」与「0 元」。
          '${terms.recordedCost} ${widget.currency.amountValue(stats.totals.cost)}',
          style: type.headline.copyWith(color: colors.text),
        ),
        if (widget.currency.amountNote case final note?)
          Text(note, style: type.footnote.copyWith(color: colors.textFaint)),
        const SizedBox(height: MileafSpace.s4),
        Text(
          '充入电量 ${number(stats.totals.energyAddedKwh, 'kWh')}，'
          '已完成 ${stats.totals.sessions} 次',
          style: type.body.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: MileafSpace.s4),
        Text(
          '当前服务未提供费用覆盖和充入均价。',
          style: type.footnote.copyWith(color: colors.textFaint),
        ),
      ],
    );
  }

  Widget _locationRow(expanded.ChargingLocation place) {
    final energy = place.sessions > 0 && place.energyKnownSessions == 0
        ? '充入电量缺失'
        : '${decimal(place.energyAddedKwh)} kWh';
    final unitCost = place.unitCostAdded.value;
    return MileafDataRow(
      title: place.location.displayName ?? '未知地点',
      // CP09：元信息分行，不用「·」串；覆盖句式沿用 CP02。
      meta:
          '${place.sessions} 次，充入 $energy\n'
          '${place.sessions} 次中 ${place.costKnownSessions} 次有费用\n'
          '充入均价 ${unitCost == null ? '—' : decimal(unitCost)} ${widget.currency.symbol}/kWh',
      showChevron: true,
      onTap: () {
        locationId = place.locationId;
        locationName = place.location.displayName;
        recordsOnly = true;
        applyFilters();
        scrollToTop();
      },
    );
  }

  Widget _recordRow(dto.ChargingSession value) {
    final colors = context.colors;
    final type = context.type;
    final local = workspace.calendar!.local(value.startedAt);
    // CP10：未知类型用独立人话小标签，不再写「充电类型未知」。
    final kind = value.isDc == null ? '类型未知' : (value.isDc! ? 'DC' : 'AC');
    final amount = widget.currency.amountValue(value.cost);
    final note = widget.currency.amountNote;
    return InkWell(
      key: ValueKey('charge-${value.id}'),
      onTap: () => widget.onRecord?.call('charge', value.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MileafSpace.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    value.location.displayName?.trim().isNotEmpty == true
                        ? value.location.displayName!
                        : '未知地点',
                    maxLines: MileafLayout.largeText(context) ? null : 2,
                    overflow: MileafLayout.largeText(context)
                        ? null
                        : TextOverflow.ellipsis,
                    // R22：记录类行标题用 headline（bodyStrong 别名同值）。
                    style: type.headline,
                  ),
                ),
                // R31：进行中用小胶囊标签；AC/DC 是独立小标签（CP09）。
                if (value.isActive) ...[
                  const SizedBox(width: MileafSpace.s8),
                  const MileafRunningPill(),
                ],
                const SizedBox(width: MileafSpace.s8),
                StatusChip(label: kind),
              ],
            ),
            const SizedBox(height: MileafSpace.inline2),
            // CP04：3月29日 07:10，34 分钟（DF5 + CP03 时长）。
            Text(
              '${copy.formatDayTime(local, _today)}，${value.durationMin == null ? '—' : copy.duration(Duration(minutes: value.durationMin!.round()))}',
              style: type.footnote.copyWith(color: colors.textSecondary),
            ),
            SocIntervalBar(
              start: value.startSoc,
              end: value.endSoc,
              compact: true,
              // D-AP10-03：充电记录行端点按对照表写「开始/结束」；行程侧
              // 「出发/到达」由组件默认值保持。
              beginLabel: '开始',
              endLabel: '结束',
            ),
            const SizedBox(height: MileafSpace.s4),
            Wrap(
              spacing: MileafSpace.s8,
              runSpacing: MileafSpace.s4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // CP02：结果行写「充入」「电网用电」，单位跟随数值。
                Text.rich(
                  TextSpan(
                    text: '充入 ',
                    style: type.subheadline.copyWith(color: colors.textMuted),
                    children: [
                      TextSpan(
                        text: value.energyAddedKwh == null
                            ? '—'
                            : decimal(value.energyAddedKwh!),
                        // R22：记录尾值用 metricSm（详情三格同角色）。
                        style: type.metricSm.copyWith(color: colors.text),
                      ),
                      if (value.energyAddedKwh != null)
                        TextSpan(text: ' kWh', style: type.subheadline),
                    ],
                  ),
                ),
                Text(
                  '电网用电 ${number(value.energyUsedKwh, 'kWh')}',
                  style: type.footnote.copyWith(color: colors.textSecondary),
                ),
                Text(
                  '费用 $amount${note == null ? '' : '，$note'}',
                  style: type.footnote.copyWith(color: colors.textSecondary),
                ),
                if (costSupported &&
                    canFillChargingCost(
                      cost: value.cost,
                      active: value.isActive,
                      endedAt: value.endedAt,
                      added: value.energyAddedKwh,
                      used: value.energyUsedKwh,
                    ))
                  // P03：补录是独立小胶囊，点按不触发行导航（S06/S07 沿旧）。
                  ChargingCostAction(
                    identityLabel:
                        '${value.location.displayName ?? '未知地点'} $local 充电 #${value.id}',
                    onPressed: () async {
                      if (costSheetOpen) return;
                      // The sheet is this ledger's own fee context: the
                      // refresh it triggers must run inline, so the flag
                      // has to drop even if the sheet throws.
                      costSheetOpen = true;
                      try {
                        await readingEditor(
                          () => showChargingCostSheet(
                            context,
                            workspace,
                            widget.currency,
                            value.id,
                          ),
                        );
                      } finally {
                        costSheetOpen = false;
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// R24：记录行走分组卡，行间一物理像素分隔线，末行无线（与行程页同一语法）。
  Widget _recordCard(List<dto.ChargingSession> rows) => MileafGroupCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, value) in rows.indexed) ...[
          if (index > 0) _hairline(),
          _recordRow(value),
        ],
      ],
    ),
  );

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

  Widget _recordsSection() {
    final colors = context.colors;
    final type = context.type;
    final empty = expandedAvailable
        ? messages.emptyMessage('已完成的充电')
        : messages.emptyMessage('充电记录');
    if (items.isEmpty) {
      if (error != null || !loaded) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: MileafSpace.s16),
        child: Text(
          empty,
          style: type.body.copyWith(color: colors.textSecondary),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.s4),
      child: _recordCard(items),
    );
  }

  /// P03：最近充电是固定的一段——区块标题（尾部「查看全部」）+ 记录行；
  /// 没有记录时标题与入口仍在，空态由记录区自己说明，用户依然能进全部记录去
  /// 搜索与筛选。
  /// P03：最近充电是固定的一段——区块标题（尾部「查看全部」）+ 分组卡；
  /// 没有记录时标题与入口仍在，空态由记录区自己说明，用户依然能进全部记录去
  /// 搜索与筛选。
  Widget _recentSection() {
    if (!expandedAvailable || recordsOnly) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MileafLayout.pageInset(context),
        MileafSpace.s16,
        MileafLayout.pageInset(context),
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: '最近充电',
            // CP05/CP06：入口是区块标题尾部的「查看全部」，不再保留整行按钮。
            action: TextButton(
              onPressed: () => _toggleRecords(open: true),
              child: const Text('查看全部'),
            ),
          ),
          const SizedBox(height: MileafSpace.s8),
          _recordsSection(),
        ],
      ),
    );
  }

  /// R30.2：页尾「关于这些数据」，说明行按五类分组；精确时间（DF8）只在
  /// 说明层出现，主界面不重复区间与单位。
  Widget _notes() {
    final groups = <MileafDataNoteGroup>[
      MileafDataNoteGroup(
        category: DataNoteCategory.caliber,
        note:
            '按${expandedAvailable ? '结束' : '开始'}时间归期。'
            '构成环只含 AC / DC 已知分类能量，类型未知的能量单列显示，不并入任何一类。'
            '充电时长按分类累计，不等于等待时间。',
      ),
      MileafDataNoteGroup(
        category: DataNoteCategory.time,
        note: '按站点时区 ${workspace.calendar!.identifier} 显示与归期。',
      ),
      MileafDataNoteGroup(
        category: DataNoteCategory.source,
        note: [
          '来源：当前站点的充电记录与服务端统计。',
          if (statsCheckedAt != null)
            '统计生成于 ${copy.formatPrecise(workspace.calendar!.local(statsCheckedAt!))}',
          if (locationsCheckedAt != null && locations.isNotEmpty)
            '地点数据生成于 ${copy.formatPrecise(workspace.calendar!.local(locationsCheckedAt!))}',
        ].join(' '),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.s4),
      child: MileafDataNotes(groups: groups),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inset = MileafLayout.pageInset(context);
    final colors = context.colors;
    final type = context.type;
    final stats = expandedStats;
    final content = ListenableBuilder(
      listenable: widget.currency,
      builder: (context, _) => RefreshIndicator(
        onRefresh: refreshAll,
        child: NotificationListener<ScrollNotification>(
          onNotification: (event) {
            if (event is ScrollUpdateNotification &&
                event.dragDetails != null &&
                (event.scrollDelta ?? 0) > 0 &&
                event.metrics.extentAfter < 120 &&
                loaded &&
                next != null &&
                !loading &&
                error == null) {
              load(more: true);
            }
            return false;
          },
          child: ListView(
            controller: scroll,
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (widget.topBar == null)
                SizedBox(height: MileafLayout.rootTopClearance(context)),
              // P03/CP06：全部记录模式顶部是二级导航（返回 + 标题
              // 「全部充电记录」），取代原来的页头文字按钮。宿主已提供页头
              // （统计专题以 initialEntry 推入本页，标题「补能记录」）时不重复。
              if (recordsOnly && widget.initialEntry == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: MileafSpace.s4),
                  child: MileafNavigationRow(
                    title: const Text('全部充电记录'),
                    onBack: () => _toggleRecords(open: false),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(inset, MileafSpace.s8, inset, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _periodRow(),
                    if (widget.filter.first != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            widget.filter.first = null;
                            widget.filter.last = null;
                            recentDays = 30;
                            interval();
                            items.clear();
                            next = null;
                            loaded = false;
                            applyFilters();
                          },
                          child: const Text('恢复近 30 天'),
                        ),
                      ),
                    if (expandedAvailable && hasFilters)
                      Padding(
                        padding: const EdgeInsets.only(top: MileafSpace.s8),
                        child: Wrap(
                          spacing: MileafSpace.s8,
                          runSpacing: MileafSpace.s4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // CP09：多个条件分项显示，不用「·」串成一行。
                            if (searchTerm.isNotEmpty)
                              Text(
                                '地点搜索：$searchTerm',
                                style: type.footnote.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                            if (locationId != null)
                              Text(
                                '地点：${locationName ?? '未知地点'}',
                                style: type.footnote.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                            if (chargeType != 'all')
                              Text(
                                '类型：${switch (chargeType) {
                                  'ac' => 'AC',
                                  'dc' => 'DC',
                                  _ => '未知',
                                }}',
                                style: type.footnote.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                            if (costStatus != 'all')
                              Text(
                                '费用：${switch (costStatus) {
                                  'known' => '已知',
                                  'unknown' => '未知',
                                  _ => '为零',
                                }}',
                                style: type.footnote.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                            TextButton(
                              onPressed: clearFilters,
                              child: const Text('清除筛选'),
                            ),
                          ],
                        ),
                      ),
                    if (!expandedAvailable)
                      Padding(
                        padding: const EdgeInsets.only(top: MileafSpace.s8),
                        child: Text(
                          '— 表示数据缺失；进行中指标不代表最终结果',
                          style: type.footnote.copyWith(
                            color: colors.textFaint,
                          ),
                        ),
                      ),
                    if (workspace.calendar!.fallback)
                      Padding(
                        padding: const EdgeInsets.only(top: MileafSpace.s8),
                        child: Text(
                          messages.timezoneUnreadableMessage(),
                          style: type.footnote.copyWith(color: colors.warning),
                        ),
                      ),
                    if (capabilityChecked && !expandedAvailable)
                      Padding(
                        padding: const EdgeInsets.only(top: MileafSpace.s8),
                        child: Text(
                          '${messages.unsupportedMessage('扩展充电数据')}，显示已有记录。',
                          style: type.footnote.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    if (capabilityError != null)
                      InlineBanner(
                        message: capabilityError!,
                        tone: BannerTone.error,
                        actionLabel: '重试',
                        actionSemanticLabel: copy_actions.retryCapabilities,
                        onAction: () => loadCapability(force: true),
                      ),
                    if (activeError != null)
                      InlineBanner(
                        message: activeError!,
                        tone: BannerTone.error,
                        actionLabel: '重试',
                        actionSemanticLabel: copy_actions.retryChargingActive,
                        onAction: () => loadActive(force: true),
                      ),
                    if (activeConfirmed &&
                        activeItems.isNotEmpty &&
                        (!recordsOnly || selectedDay == null))
                      Padding(
                        padding: const EdgeInsets.only(top: MileafSpace.s12),
                        child: MileafModuleCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final (index, active)
                                  in activeItems.indexed) ...[
                                if (index > 0) ...[
                                  const SizedBox(height: MileafSpace.s8),
                                  Container(height: 1, color: colors.line),
                                  const SizedBox(height: MileafSpace.s8),
                                ],
                                _activeRow(active),
                              ],
                            ],
                          ),
                        ),
                      ),
                    if (loading || statsLoading) const MileafProgressLine(),
                    if (statsError != null)
                      InlineBanner(
                        message: statsError!,
                        tone: BannerTone.error,
                        actionLabel: '重试',
                        actionSemanticLabel: copy_actions.retryChargingStats,
                        onAction: () => loadStats(force: true),
                      ),
                  ],
                ),
              ),
              if (stats == null && statsLoading && !recordsOnly)
                _compositionSkeleton(),
              if (stats != null && !recordsOnly) ...[
                _accountCard(stats),
                _trendCard(stats),
                if (stats.totals.unitCostAdded.excludedCostSessions > 0)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      inset,
                      MileafSpace.s8,
                      inset,
                      0,
                    ),
                    child: Text(
                      '充入均价不含 ${stats.totals.unitCostAdded.excludedCostSessions} 次能量无效的已记录费用。',
                      style: type.footnote.copyWith(color: colors.textMuted),
                    ),
                  ),
              ] else if (legacyStats != null && !recordsOnly)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    MileafSpace.s20,
                    inset,
                    0,
                  ),
                  child: _legacySummary(legacyStats!),
                ),
              if (expandedAvailable && recordsOnly)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    MileafSpace.s16,
                    inset,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      filterControls(),
                      if (selectedDay != null)
                        Padding(
                          padding: const EdgeInsets.only(top: MileafSpace.s8),
                          child: Wrap(
                            spacing: MileafSpace.s8,
                            runSpacing: MileafSpace.s4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '只看 ${copy.formatDay(selectedDay!, _today)}结束的充电',
                                style: type.footnote.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                              TextButton(
                                onPressed: () => showDay(null),
                                child: const Text('查看完整区间'),
                              ),
                            ],
                          ),
                        ),
                      if (sort == 'unit_cost_added_asc')
                        Padding(
                          padding: const EdgeInsets.only(top: MileafSpace.s4),
                          child: Text(
                            '按充入均价从低到高排序；单次均价可在详情查看。',
                            style: type.footnote.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                      if (matchedSessions != null)
                        Padding(
                          padding: const EdgeInsets.only(top: MileafSpace.s4),
                          child: Text(
                            '匹配 $matchedSessions 次充电',
                            style: type.footnote.copyWith(
                              color: colors.textFaint,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (!recordsOnly) _recentSection(),
              if (stats != null && !recordsOnly) _accountCellsCard(stats),
              if (stats != null && !recordsOnly) _methodCard(stats),
              if (expandedAvailable && !recordsOnly)
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
                      const SectionHeader(title: '充电地点'),
                      const SizedBox(height: MileafSpace.s8),
                      if (locationsLoading) const MileafProgressLine(),
                      if (locationError != null)
                        InlineBanner(
                          message: locationError!,
                          tone: BannerTone.error,
                          actionLabel: '重试',
                          actionSemanticLabel:
                              copy_actions.retryChargingLocations,
                          onAction: () => loadLocations(
                            more: locationFailedMore,
                            force: true,
                          ),
                        ),
                      if (locations.isNotEmpty)
                        MileafGroupCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final (index, place)
                                  in locations.indexed) ...[
                                if (index > 0) _hairline(),
                                _locationRow(place),
                              ],
                            ],
                          ),
                        ),
                      if (locationCursor != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(top: MileafSpace.s4),
                            child: TextButton(
                              onPressed: locationsLoading
                                  ? null
                                  : () => loadLocations(more: true),
                              child: const Text('加载更多地点'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (!expandedAvailable || recordsOnly)
                Padding(
                  padding: EdgeInsets.fromLTRB(inset, 0, inset, 0),
                  child: _recordsSection(),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  inset,
                  MileafSpace.s8,
                  inset,
                  MileafLayout.rootNavigationClearance(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (loading) const MileafProgressLine(),
                    if (error != null)
                      InlineBanner(
                        message: error!,
                        tone: BannerTone.error,
                        actionLabel: '重试',
                        actionSemanticLabel: copy_actions.retryChargingRecords,
                        onAction: retryLoad,
                      ),
                    if (loaded &&
                        next != null &&
                        (!expandedAvailable || recordsOnly))
                      Align(
                        alignment: Alignment.center,
                        child: TextButton(
                          onPressed: loading
                              ? null
                              : () => load(more: true, force: error != null),
                          child: const Text('加载更多充电'),
                        ),
                      ),
                    if (loaded &&
                        next == null &&
                        items.isNotEmpty &&
                        (!expandedAvailable || recordsOnly))
                      Padding(
                        padding: const EdgeInsets.only(top: MileafSpace.s8),
                        child: Text(
                          '已显示全部充电',
                          textAlign: TextAlign.center,
                          style: type.footnote.copyWith(
                            color: colors.textFaint,
                          ),
                        ),
                      ),
                    _notes(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final bar = widget.topBar;
    if (bar == null) return MileafContent(child: content);
    return Column(
      children: [
        bar,
        Expanded(child: MileafContent(child: content)),
      ],
    );
  }
}
