import 'package:flutter/material.dart';

import 'api.dart';
import 'charging_cost.dart';

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
import 'workspace.dart';
import 'currency.dart';

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
    with WidgetsBindingObserver {
  final items = <dto.ChargingSession>[];
  String? next, error;
  bool loading = false, loaded = false, failedMore = false;
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
  int chartMetric = 0, chartDay = 0;
  int recentDays = 30;
  int? matchedSessions;
  String? statsKey, locationsKey;
  DateTime? statsCheckedAt, locationsCheckedAt;
  expanded.ChargingStats? expandedStats;
  legacy.ChargingStats? legacyStats;
  late DateTime from, to;
  VehicleWorkspace get workspace => widget.workspace;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    workspace.addListener(contextChanged);
    workspace.addCostReader(refreshCost);
    revision = workspace.revision;
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
    expandedAvailable = false;
    costSupported = false;
    recordsOnly = false;
    capabilityChecked = false;
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
    locationId = null;
    locationName = null;
    selectedDay = null;
    matchedSessions = null;
    search.clear();
    searchTerm = '';
    chargeType = 'all';
    costStatus = 'all';
    sort = 'ended_desc';
    load();
    loadCapability();
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
        error = '站点暂不支持此结束日筛选，请更新能力后重试';
      });
      return;
    }
    if (changed) {
      next = null;
      items.clear();
      loaded = false;
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
      chartDay = 0;
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
        setState(() => activeError = '进行中充电暂时不可用，请重试');
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
        locationError = '地点账目仅支持不超过730天的区间';
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
          locationError = '地点分页游标未前进，请重试';
        }
      });
    } catch (_) {
      if (mounted &&
          attempt == locationSequence &&
          workspace.session.isCurrent(owner) &&
          workspace.selectedId == vehicle) {
        setState(
          () => locationError =
              '地点账目暂时不可用，请重试${locationsKey == key ? '；保留上次快照' : ''}',
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
        statsError = '此日期范围无法显示统计，请选择不超过730天的区间';
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
        final int activeIndex;
        if (value is expanded.ChargingStats) {
          final last = value.buckets.lastIndexWhere((b) => b.sessions > 0);
          activeIndex = value.buckets.isEmpty
              ? 0
              : (last < 0 ? value.buckets.length - 1 : last);
        } else {
          final legacyValue = value as legacy.ChargingStats;
          final last = legacyValue.buckets.lastIndexWhere(
            (b) => b.sessions > 0,
          );
          activeIndex = legacyValue.buckets.isEmpty
              ? 0
              : (last < 0 ? legacyValue.buckets.length - 1 : last);
        }
        chartDay = activeIndex;
      });
    } catch (_) {
      if (mounted &&
          attempt == statsSequence &&
          workspace.session.isCurrent(owner) &&
          workspace.selectedId == vehicle) {
        setState(
          () => statsError = '充电统计暂时不可用，请重试${statsKey == key ? '；保留上次快照' : ''}',
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
    if (state == AppLifecycleState.resumed &&
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      foreground();
    }
  }

  Future<void> foreground() async {
    final changed = await workspace.foreground();
    if (!mounted || changed) return;
    final session = workspace.session.current;
    final vehicle = workspace.selectedId;
    if (session == null || vehicle == null) return;
    await loadCapability(refreshData: false);
    if (!mounted ||
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
    next = null;
    await Future.wait([
      load(),
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
    setState(() {
      loading = true;
      error = null;
      failedMore = more;
    });
    try {
      final page = <dto.ChargingSession>[];
      String? following = cursor;
      int? matched;
      var pages = 0;
      final targetPages = preservePages
          ? loadedPages.clamp(1, loadedPages + 1)
          : 1;
      final visited = <String?>{};
      do {
        if (!visited.add(following)) {
          throw const FormatException('Repeated cursor');
        }
        final value = await workspace.cache.get(
          session,
          'vehicles/$id/charging-sessions',
          query: listQuery(cursor: following),
          force: force,
        );
        final decoded = dto.ChargingSessionPage.fromJson(value.body);
        matched = expandedAvailable
            ? expanded.ChargingSessionPage.fromJson(value.body).matchedSessions
            : null;
        page.addAll(decoded.items);
        following = decoded.nextCursor;
        pages++;
      } while (preservePages && pages < targetPages && following != null);
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
        loadedPages = more ? loadedPages + pages : pages;
        matchedSessions = matched;
        if (more && following != null && following == cursor) {
          error = '分页游标未前进，已保留现有充电，请刷新或手动重试';
          failedMore = true;
        }
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
              : '${e is ApiFailure ? e.message : '充电读取失败，请重试'}${items.isEmpty ? '' : '；保留已加载记录，请重试'}',
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
          title: const Text('按日期筛选'),
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
                Text(
                  '含首尾日期；今天截至当前时刻。按充电${expandedAvailable ? '结束' : '开始'}时间归期。',
                ),
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
    selectedDay = null;
    matchedSessions = null;
    expandedStats = null;
    legacyStats = null;
    statsKey = null;
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

  void scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) scroll.jumpTo(0);
    });
  }

  Widget _hero(expanded.ChargingStats stats) {
    final total = stats.totals;
    final colors = context.colors;
    final type = context.type;
    final inset = MileafLayout.heroInset(context);
    // 无一条记录带费用时，0 不是「花了 ¥0」而是「未知」（Spec §9.5 空态）。
    final cost = total.cost == null || total.costKnownSessions == 0
        ? '—'
        : widget.currency.amountValue(total.cost);
    final unitCost = total.unitCostAdded.value == null
        ? '—'
        : decimal(total.unitCostAdded.value!);
    final note = widget.currency.amountNote;
    final coverage = total.sessions == 0
        ? 0.0
        : (total.costKnownSessions / total.sessions).clamp(0.0, 1.0);
    final currencyLabel = widget.currency.code ?? note ?? '';
    return MileafHero(
      semanticLabel:
          '已知充电费用 $cost；费用有记录 ${total.costKnownSessions} / ${total.sessions} 次',
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          inset,
          MileafSpace.s20,
          inset,
          MileafSpace.s20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '已知充电费用',
                    style: type.label.copyWith(color: colors.heroMuted),
                  ),
                ),
                if (currencyLabel.isNotEmpty)
                  Text(
                    currencyLabel,
                    style: type.micro.copyWith(color: colors.heroFaint),
                  ),
              ],
            ),
            const SizedBox(height: MileafSpace.s8),
            MileafNumber(
              value: cost,
              scale: MetricValueScale.display,
              onHero: true,
            ),
            if (note != null) ...[
              const SizedBox(height: MileafSpace.s4),
              Text(note, style: type.micro.copyWith(color: colors.heroFaint)),
            ],
            const SizedBox(height: MileafSpace.s12),
            Semantics(
              label: '有效入电均价 $unitCost ${widget.currency.symbol}/kWh',
              child: Text(
                '有效入电均价 $unitCost ${widget.currency.symbol}/kWh',
                style: type.body.copyWith(color: colors.heroMuted),
              ),
            ),
            const SizedBox(height: MileafSpace.s16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '费用覆盖',
                    style: type.label.copyWith(color: colors.heroMuted),
                  ),
                ),
                Text(
                  '${total.costKnownSessions} / ${total.sessions} 次',
                  style: type.label.copyWith(color: colors.heroText),
                ),
              ],
            ),
            const SizedBox(height: MileafSpace.s8),
            Semantics(
              label: '费用记录覆盖：${total.costKnownSessions}/${total.sessions}次',
              child: ClipRRect(
                borderRadius: MileafRadius.fullAll,
                child: Container(
                  height: 4,
                  color: colors.heroText.withValues(alpha: .14),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: coverage,
                    heightFactor: 1,
                    child: ColoredBox(color: colors.accentHero),
                  ),
                ),
              ),
            ),
            const SizedBox(height: MileafSpace.s8),
            Text(
              '费用有记录 ${total.costKnownSessions} / ${total.sessions} 次 · '
              '对应入电 ${decimal(total.costKnownEnergyKwh)} kWh',
              style: type.micro.copyWith(color: colors.heroFaint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readings(expanded.ChargingStats stats) {
    final total = stats.totals;
    // 「0/0 次有记录」说明能量与时长未知，而不是 0（Spec §9.5 空态）。
    final energyMissing = total.energyKnownSessions == 0;
    final durationMissing = total.durationKnownSessions == 0;
    final energy = energyMissing ? '—' : decimal(total.energyAddedKwh);
    final duration = durationMissing
        ? '—'
        : _formatDuration(total.durationMinTotal);
    final energyBlock = MetricBlock(
      label: '补入电池',
      value: energy,
      unit: energyMissing ? null : 'kWh',
      note: '${total.energyKnownSessions}/${total.sessions}次有记录',
      semanticLabel: '补入电池 $energy${energyMissing ? '' : ' kWh'}',
    );
    final countBlock = MetricBlock(
      label: '充电次数',
      value: '${total.sessions}',
      unit: '次',
      note: '已完成',
      semanticLabel: '充电次数 ${total.sessions} 次',
    );
    final durationBlock = MetricBlock(
      label: '记录时长',
      value: duration,
      note: '${total.durationKnownSessions}/${total.sessions}次有记录 · 非等待时间',
      semanticLabel:
          '记录时长 $duration，${total.durationKnownSessions}/${total.sessions}次有记录 · 非等待时间',
    );
    final content = MileafLayout.largeText(context)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: energyBlock),
                  const SizedBox(width: MileafSpace.s16),
                  Expanded(child: durationBlock),
                ],
              ),
              const SizedBox(height: MileafSpace.s20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: countBlock),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: energyBlock),
              const SizedBox(width: MileafSpace.s16),
              Expanded(child: countBlock),
              const SizedBox(width: MileafSpace.s16),
              Expanded(child: durationBlock),
            ],
          );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MileafLayout.pageInset(context),
        MileafSpace.s12,
        MileafLayout.pageInset(context),
        0,
      ),
      child: content,
    );
  }

  Widget trend(expanded.ChargingStats stats) {
    final active = stats.buckets.any((bucket) => bucket.sessions > 0);
    if (!active) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          MileafLayout.pageInset(context),
          MileafSpace.section,
          MileafLayout.pageInset(context),
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: '每日补能'),
            const SizedBox(height: MileafSpace.s8),
            Text(
              '这段时间还没有充电记录',
              style: context.type.body.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ],
        ),
      );
    }
    final entries = [
      ('电量', 'kWh'),
      ('费用', widget.currency.symbol),
      ('均价', '${widget.currency.symbol}/kWh'),
      ('次数', '次'),
    ];
    final metric = entries[chartMetric];
    final zone = workspace.calendar!;
    final start = zone.local(from);
    final end = zone.local(to.subtract(const Duration(microseconds: 1)));
    String md(DateTime value) => '${value.month}/${value.day}';
    final selected = stats.buckets.isEmpty
        ? 0
        : chartDay.clamp(0, stats.buckets.length - 1);
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
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MileafLayout.pageInset(context),
        MileafSpace.section,
        MileafLayout.pageInset(context),
        0,
      ),
      child: StemChart(
        title: '每日补能',
        unit: metric.$2,
        subtitle:
            '${widget.filter.first == null ? '近$recentDays天' : '自定义日期'} · '
            '${md(start)} — ${md(end)} · 按结束时间归期',
        times: [for (final bucket in stats.buckets) bucket.bucketStart],
        values: values,
        semanticsLabel: '每日补能图表',
        plotKey: const Key('charging-briefing-chart'),
        selectedIndex: selected,
        onSelected: (index) => setState(() => chartDay = index),
        height: 96,
        readout: (index) {
          if (index < 0 || index >= stats.buckets.length) return '—';
          final bucket = stats.buckets[index];
          final local = workspace.calendar!.local(bucket.bucketStart);
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
          return '${local.month}/${local.day} $value';
        },
        onActivateSelected: stats.buckets.isEmpty
            ? null
            : () {
                final local = workspace.calendar!.local(
                  stats.buckets[selected].bucketStart,
                );
                showDay(DateTime(local.year, local.month, local.day));
              },
        activationLabel: '查看这一天的充电',
        controls: Wrap(
          spacing: MileafSpace.s8,
          runSpacing: MileafSpace.s8,
          children: [
            for (final (index, entry) in entries.indexed)
              StatusChip(
                label: entry.$1,
                selected: chartMetric == index,
                onTap: () => setState(() => chartMetric = index),
              ),
          ],
        ),
        note: '费用与均价仅包含有效记录；缺失不补零。',
      ),
    );
  }

  /// 「我的补能方式」：一句结论 → 构成环 + 图例 → 三列绝对量 → 一句口径。
  ///
  /// The ring shares the exact denominator of `dc_energy_share` (AC + DC known
  /// energy); unknown energy is declared in the note instead of becoming a
  /// third arc, so one screen never shows two different DC percentages.
  Widget _composition(expanded.ChargingStats stats) {
    final reading = ChargingMethodReading.from(stats.totals);
    final colors = context.colors;
    final type = context.type;
    final inset = MileafLayout.pageInset(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, MileafSpace.section, inset, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: '我的补能方式'),
          const SizedBox(height: MileafSpace.s8),
          Text(
            reading.conclusion,
            style: type.body.copyWith(color: colors.text),
          ),
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
              style: type.micro.copyWith(color: colors.textFaint),
            ),
          ],
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
            style: type.label.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: MileafSpace.inline6),
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
                    style: type.micro.copyWith(color: colors.textFaint),
                  ),
              ],
            ),
          ),
          const SizedBox(height: MileafSpace.inline6),
          Text(
            category.note,
            style: type.micro.copyWith(color: colors.textFaint),
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
          const SectionHeader(title: '我的补能方式'),
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
        decoration: const InputDecoration(labelText: '搜索充电地点'),
        onSubmitted: (_) => applyFilters(),
      ),
      Wrap(
        spacing: 12,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DropdownButton<String>(
            value: chargeType,
            onChanged: (value) {
              if (value == null) return;
              chargeType = value;
              applyFilters();
            },
            items: const [
              DropdownMenuItem(value: 'all', child: Text('全部类型')),
              DropdownMenuItem(value: 'ac', child: Text('AC')),
              DropdownMenuItem(value: 'dc', child: Text('DC')),
              DropdownMenuItem(value: 'unknown', child: Text('类型未知')),
            ],
          ),
          DropdownButton<String>(
            value: costStatus,
            onChanged: (value) {
              if (value == null) return;
              costStatus = value;
              applyFilters();
            },
            items: const [
              DropdownMenuItem(value: 'all', child: Text('全部费用')),
              DropdownMenuItem(value: 'known', child: Text('费用已知')),
              DropdownMenuItem(value: 'unknown', child: Text('费用未知')),
              DropdownMenuItem(value: 'zero', child: Text('费用为零')),
            ],
          ),
          DropdownButton<String>(
            value: sort,
            onChanged: (value) {
              if (value == null) return;
              sort = value;
              applyFilters();
            },
            items: const [
              DropdownMenuItem(value: 'ended_desc', child: Text('最近结束')),
              DropdownMenuItem(value: 'started_desc', child: Text('最近开始')),
              DropdownMenuItem(
                value: 'unit_cost_added_asc',
                child: Text('入电均价从低到高'),
              ),
              DropdownMenuItem(value: 'duration_desc', child: Text('记录时长从长到短')),
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

  Widget _pageHeader() {
    final type = context.type;
    final colors = context.colors;
    final title = recordsOnly
        ? '充电记录'
        : expandedAvailable
        ? '充电'
        : '充电历史';
    final subtitle = '近$recentDays天 · 按${expandedAvailable ? '结束' : '开始'}时间归期';
    final actions = <Widget>[
      if (expandedAvailable)
        TextButton(
          onPressed: () {
            final returning = recordsOnly;
            setState(() => recordsOnly = !recordsOnly);
            scrollToTop();
            if (returning && selectedDay != null) showDay(null);
          },
          child: Text(recordsOnly ? '返回账本' : '全部记录'),
        ),
      MileafIconButton(
        icon: MileafIconName.refresh,
        tooltip: '刷新充电',
        onPressed: loading ? null : refreshAll,
      ),
    ];
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: type.title),
        const SizedBox(height: MileafSpace.inline2),
        Text(subtitle, style: type.label.copyWith(color: colors.textMuted)),
      ],
    );
    if (MileafLayout.largeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleBlock,
          Align(
            alignment: Alignment.centerRight,
            child: Row(mainAxisSize: MainAxisSize.min, children: actions),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: titleBlock),
        ...actions,
      ],
    );
  }

  Widget _periodRow() {
    Widget chip(String label, int days) => StatusChip(
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
    final date = TextButton(
      onPressed: filterDates,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, MileafSpace.touch),
        padding: const EdgeInsets.symmetric(horizontal: MileafSpace.s8),
        visualDensity: VisualDensity.compact,
      ),
      child: const Text('日期'),
    );
    if (!expandedAvailable) {
      return Align(alignment: Alignment.centerLeft, child: date);
    }
    if (MileafLayout.largeText(context)) {
      return Wrap(
        spacing: MileafSpace.s8,
        runSpacing: MileafSpace.s8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [chip('近30天', 30), chip('近7天', 7), date],
      );
    }
    return Row(
      children: [
        chip('近30天', 30),
        const SizedBox(width: MileafSpace.s8),
        chip('近7天', 7),
        const Spacer(),
        date,
      ],
    );
  }

  Widget _activeRow(dto.ChargingSession value) {
    final colors = context.colors;
    final type = context.type;
    return InkWell(
      onTap: () => widget.onRecord?.call('charge', value.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: MileafSpace.s8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.line)),
        ),
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
                    '正在充电 · ${value.location.displayName ?? '未知地点'}',
                    style: type.body.copyWith(
                      color: colors.text,
                      fontWeight: MileafType.weightSemiBold,
                    ),
                  ),
                  const SizedBox(height: MileafSpace.inline2),
                  Text(
                    '已补入 ${number(value.energyAddedKwh, 'kWh')} · 不计入已完成统计',
                    style: type.micro.copyWith(color: colors.textMuted),
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
          '已知充电费用 ${widget.currency.amountValue(stats.totals.cost)}',
          style: type.title.copyWith(color: colors.text),
        ),
        if (widget.currency.amountNote case final note?)
          Text(note, style: type.micro.copyWith(color: colors.textFaint)),
        const SizedBox(height: MileafSpace.s4),
        Text(
          '补入电池 ${number(stats.totals.energyAddedKwh, 'kWh')} · '
          '已完成 ${stats.totals.sessions} 次',
          style: type.body.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: MileafSpace.s4),
        Text(
          '当前服务未提供费用覆盖和配对有效均价。',
          style: type.micro.copyWith(color: colors.textFaint),
        ),
      ],
    );
  }

  Widget _locationRow(expanded.ChargingLocation place) {
    final colors = context.colors;
    final type = context.type;
    final energy = place.sessions > 0 && place.energyKnownSessions == 0
        ? '入电量缺失'
        : '${decimal(place.energyAddedKwh)} kWh';
    final unit = place.unitCostAdded.value == null
        ? '—'
        : decimal(place.unitCostAdded.value!);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        place.location.displayName ?? '未知地点',
        style: type.body.copyWith(
          color: colors.text,
          fontWeight: MileafType.weightSemiBold,
        ),
      ),
      subtitle: Text(
        '${place.sessions} 次 · $energy · '
        '费用有记录 ${place.costKnownSessions}/${place.sessions} 次\n'
        '有效入电均价 $unit ${widget.currency.symbol}/kWh',
        style: type.micro.copyWith(color: colors.textMuted),
      ),
      trailing: MileafIcon(
        MileafIconName.chevron,
        size: MileafIconMetrics.inline,
        color: colors.textFaint,
      ),
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
    final status = value.isActive ? '进行中' : '已结束';
    final kind = value.isDc == null
        ? '充电类型未知'
        : '充电类型 ${value.isDc! ? 'DC' : 'AC'}';
    final amount = widget.currency.amountValue(value.cost);
    final note = widget.currency.amountNote;
    final extra = [
      if (value.location.geofence != null) '围栏：${value.location.geofence}',
      if (value.location.address != null &&
          value.location.address != value.location.displayName)
        '地址：${value.location.address}',
    ];
    return InkWell(
      onTap: () => widget.onRecord?.call('charge', value.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: MileafSpace.s12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    value.location.displayName?.trim().isNotEmpty == true
                        ? value.location.displayName!
                        : '未知地点',
                    style: type.body.copyWith(
                      color: colors.text,
                      fontWeight: MileafType.weightSemiBold,
                    ),
                  ),
                ),
                const SizedBox(width: MileafSpace.s8),
                Text(
                  status,
                  style: type.micro.copyWith(
                    color: value.isActive ? colors.warning : colors.textFaint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MileafSpace.inline2),
            Text(
              '${local.toString().split('.').first} · $kind',
              style: type.micro.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: MileafSpace.s4),
            Text(
              '电量 ${number(value.startSoc, '%')} → ${number(value.endSoc, '%')}',
              style: type.label.copyWith(color: colors.textMuted),
            ),
            SocIntervalBar(start: value.startSoc, end: value.endSoc),
            const SizedBox(height: MileafSpace.s4),
            Text(
              '充入电池 ${number(value.energyAddedKwh, 'kWh')}',
              style: type.body.copyWith(
                color: colors.text,
                fontWeight: MileafType.weightSemiBold,
              ),
            ),
            const SizedBox(height: MileafSpace.inline2),
            Text(
              '电网侧 ${number(value.energyUsedKwh, 'kWh')}',
              style: type.micro.copyWith(color: colors.textMuted),
            ),
            Wrap(
              spacing: MileafSpace.s8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '费用 $amount${note == null ? '' : ' · $note'}',
                  style: type.micro.copyWith(color: colors.textMuted),
                ),
                if (costSupported &&
                    canFillChargingCost(
                      cost: value.cost,
                      active: value.isActive,
                      endedAt: value.endedAt,
                      added: value.energyAddedKwh,
                      used: value.energyUsedKwh,
                    ))
                  SizedBox(
                    width: MileafLayout.largeText(context)
                        ? double.infinity
                        : null,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: 1,
                      child: ChargingCostAction(
                        identityLabel:
                            '${value.location.displayName ?? '未知地点'} $local 充电 #${value.id}',
                        onPressed: () async {
                          if (costSheetOpen) return;
                          costSheetOpen = true;
                          await showChargingCostSheet(
                            context,
                            workspace,
                            widget.currency,
                            value.id,
                          );
                          costSheetOpen = false;
                        },
                      ),
                    ),
                  ),
              ],
            ),
            Text(
              '时长 ${number(value.durationMin, '分钟')}',
              style: type.micro.copyWith(color: colors.textMuted),
            ),
            if (extra.isNotEmpty) ...[
              const SizedBox(height: MileafSpace.inline2),
              Text(
                extra.join(' · '),
                style: type.micro.copyWith(color: colors.textFaint),
              ),
            ],
            const SizedBox(height: MileafSpace.s4),
            Text(
              '充电 #${value.id} · 查看详情',
              style: type.micro.copyWith(color: colors.textFaint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordsSection() {
    final colors = context.colors;
    final type = context.type;
    final empty = expandedAvailable ? '此区间无已完成充电记录' : '此区间无充电记录';
    if (items.isEmpty) {
      if (error != null || !loaded) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: MileafSpace.s16),
        child: Text(empty, style: type.body.copyWith(color: colors.textMuted)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final value in items) _recordRow(value)],
    );
  }

  Widget _recentSection() {
    if (!expandedAvailable || recordsOnly) return const SizedBox.shrink();
    if (items.isEmpty) {
      return Padding(
        padding: MileafLayout.pageHorizontal(context),
        child: _recordsSection(),
      );
    }
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
          const SectionHeader(title: '最近的充电'),
          const SizedBox(height: MileafSpace.s4),
          for (final value in items.take(3)) _recordRow(value),
          if (items.length > 3 || next != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  setState(() => recordsOnly = true);
                  scrollToTop();
                },
                child: const Text('查看全部充电记录'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _notes() {
    final colors = context.colors;
    final type = context.type;
    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.section),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
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
                  '按${expandedAvailable ? '结束' : '开始'}时间归期 · '
                  '时区：${workspace.calendar!.identifier}；费用与均价仅包含有效记录。',
                  style: type.micro.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: MileafSpace.s4),
                Text(
                  '构成环只含 AC / DC 已知分类能量；类型未知的能量单列显示，不并入任何一类。',
                  style: type.micro.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: MileafSpace.s4),
                Text(
                  '记录时长按分类累计，不等于等待时间。',
                  style: type.micro.copyWith(color: colors.textMuted),
                ),
                if (statsCheckedAt != null) ...[
                  const SizedBox(height: MileafSpace.s4),
                  Text(
                    '统计校验时间 ${workspace.calendar!.local(statsCheckedAt!).toString().split('.').first}',
                    style: type.micro.copyWith(color: colors.textFaint),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
              Padding(
                padding: EdgeInsets.fromLTRB(inset, MileafSpace.s8, inset, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _pageHeader(),
                    const SizedBox(height: MileafSpace.s4),
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
                          child: const Text('恢复近30日'),
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
                            Text(
                              [
                                if (searchTerm.isNotEmpty) '地点搜索：$searchTerm',
                                if (locationId != null)
                                  '地点：${locationName ?? '未知地点'}',
                                if (chargeType != 'all')
                                  '类型：${switch (chargeType) {
                                    'ac' => 'AC',
                                    'dc' => 'DC',
                                    _ => '未知',
                                  }}',
                                if (costStatus != 'all')
                                  '费用：${switch (costStatus) {
                                    'known' => '已知',
                                    'unknown' => '未知',
                                    _ => '为零',
                                  }}',
                              ].join(' · '),
                              style: type.micro.copyWith(
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
                          style: type.micro.copyWith(color: colors.textFaint),
                        ),
                      ),
                    if (workspace.calendar!.fallback)
                      Padding(
                        padding: const EdgeInsets.only(top: MileafSpace.s8),
                        child: Text(
                          '无法读取设备 IANA 时区，暂按 UTC',
                          style: type.micro.copyWith(color: colors.warning),
                        ),
                      ),
                    if (capabilityChecked && !expandedAvailable)
                      Padding(
                        padding: const EdgeInsets.only(top: MileafSpace.s8),
                        child: Text(
                          '当前站点未提供充电扩展能力，显示已有记录。',
                          style: type.micro.copyWith(color: colors.textMuted),
                        ),
                      ),
                    if (capabilityError != null)
                      InlineBanner(
                        message: capabilityError!,
                        tone: BannerTone.error,
                        actionLabel: '重试站点能力',
                        onAction: () => loadCapability(force: true),
                      ),
                    if (activeError != null)
                      InlineBanner(
                        message: activeError!,
                        tone: BannerTone.error,
                        actionLabel: '重试进行中充电',
                        onAction: () => loadActive(force: true),
                      ),
                    for (final active in activeItems)
                      if (activeConfirmed &&
                          (!recordsOnly || selectedDay == null))
                        _activeRow(active),
                    if (loading || statsLoading) const MileafProgressLine(),
                    if (statsError != null)
                      InlineBanner(
                        message: statsError!,
                        tone: BannerTone.error,
                        actionLabel: '重试充电统计',
                        onAction: () => loadStats(force: true),
                      ),
                  ],
                ),
              ),
              if (stats == null && statsLoading && !recordsOnly)
                _compositionSkeleton(),
              if (stats != null && !recordsOnly) ...[
                _hero(stats),
                _readings(stats),
                trend(stats),
                if (stats.totals.unitCostAdded.excludedCostSessions > 0)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      inset,
                      MileafSpace.s8,
                      inset,
                      0,
                    ),
                    child: Text(
                      '均价不含 ${stats.totals.unitCostAdded.excludedCostSessions} 次能量无效的已知费用。',
                      style: type.micro.copyWith(color: colors.textMuted),
                    ),
                  ),
                _composition(stats),
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
                                '仅看 ${selectedDay!.year}年${selectedDay!.month}月${selectedDay!.day}日结束的充电',
                                style: type.micro.copyWith(
                                  color: colors.textMuted,
                                ),
                              ),
                              TextButton(
                                onPressed: () => showDay(null),
                                child: const Text('返回完整区间'),
                              ),
                            ],
                          ),
                        ),
                      if (sort == 'unit_cost_added_asc')
                        Padding(
                          padding: const EdgeInsets.only(top: MileafSpace.s4),
                          child: Text(
                            '按服务端有效入电均价排序；单次均价可在详情查看。',
                            style: type.micro.copyWith(color: colors.textMuted),
                          ),
                        ),
                      if (matchedSessions != null)
                        Padding(
                          padding: const EdgeInsets.only(top: MileafSpace.s4),
                          child: Text(
                            '匹配 $matchedSessions 次充电',
                            style: type.micro.copyWith(color: colors.textFaint),
                          ),
                        ),
                    ],
                  ),
                ),
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
                      const SectionHeader(title: '地点账目'),
                      const SizedBox(height: MileafSpace.s4),
                      if (locationsLoading) const MileafProgressLine(),
                      if (locationError != null)
                        InlineBanner(
                          message: locationError!,
                          tone: BannerTone.error,
                          actionLabel: '重试地点账目',
                          onAction: () => loadLocations(
                            more: locationFailedMore,
                            force: true,
                          ),
                        ),
                      if (locationsCheckedAt != null && locations.isNotEmpty)
                        Text(
                          '地点校验时间 ${workspace.calendar!.local(locationsCheckedAt!).toString().split('.').first}',
                          style: type.micro.copyWith(color: colors.textFaint),
                        ),
                      for (final place in locations) _locationRow(place),
                      if (locationCursor != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: locationsLoading
                                ? null
                                : () => loadLocations(more: true),
                            child: const Text('加载更多地点'),
                          ),
                        ),
                    ],
                  ),
                ),
              if (!recordsOnly) _recentSection(),
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
                  MileafSpace.s24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (loading) const MileafProgressLine(),
                    if (error != null)
                      InlineBanner(
                        message: error!,
                        tone: BannerTone.error,
                        actionLabel: '重试充电',
                        onAction: () => load(more: failedMore, force: true),
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
                          '已到最后一条',
                          textAlign: TextAlign.center,
                          style: type.micro.copyWith(color: colors.textFaint),
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
    if (bar == null) return content;
    return Column(
      children: [
        bar,
        Expanded(child: content),
      ],
    );
  }
}

/// Compact C duration: 34 分钟, 2h05, 5h10.
String _formatDuration(num minutes) {
  final total = minutes.round();
  if (total < 60) return '$total 分钟';
  final hours = total ~/ 60;
  final rest = total % 60;
  return rest == 0
      ? '${hours}h'
      : '${hours}h${rest.toString().padLeft(2, '0')}';
}
