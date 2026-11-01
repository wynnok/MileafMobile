import 'package:flutter/material.dart';

import 'api.dart';
import 'data_cards.dart';
import 'collage.dart';
import 'period_chips.dart';
import 'data_chart.dart';

import 'charging_contract.g.dart' as dto;
import 'charging_experience_contract.g.dart' as expanded;
import 'charging_statistics_contract.g.dart' as legacy;
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
  int sequence = 0;
  int statsSequence = 0, capabilitySequence = 0;
  int locationSequence = 0, activeSequence = 0;
  bool expandedAvailable = false, statsLoading = false;
  bool recordsOnly = false;
  bool capabilityChecked = false;
  bool locationsLoading = false;
  bool locationFailedMore = false;
  String? statsError, capabilityError;
  String? locationError, locationCursor, locationName;
  final locations = <expanded.ChargingLocation>[];
  final activeItems = <dto.ChargingSession>[];
  String? activeError;
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
    recordsOnly = false;
    capabilityChecked = false;
    expandedStats = null;
    legacyStats = null;
    statsKey = null;
    locationsKey = null;
    statsSequence++;
    locationSequence++;
    activeSequence++;
    activeItems.clear();
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
    search.dispose();
    scroll.dispose();
    workspace.removeListener(contextChanged);
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
    var recognized = capabilityChecked;
    String? failure;
    try {
      final meta = await workspace.cache.get(owner, 'meta', force: force);
      final version = meta.body['version'];
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

  Future<void> loadActive({bool force = false}) async {
    final owner = workspace.session.current;
    final vehicle = workspace.selectedId;
    if (!expandedAvailable || owner == null || vehicle == null) return;
    final attempt = ++activeSequence;
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

  Future<void> load({bool more = false, bool force = false}) async {
    if (widget.initialEntry != null && !expandedAvailable) {
      await loadCapability(force: force);
      return;
    }
    if (more && (loading || next == null)) return;
    if (!more && force) {
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
        query: listQuery(cursor: cursor),
        force: force,
      );
      final decoded = dto.ChargingSessionPage.fromJson(value.body);
      final matched = expandedAvailable
          ? expanded.ChargingSessionPage.fromJson(value.body).matchedSessions
          : null;
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

  String number(num? v, String unit) =>
      v == null ? '—（缺失）' : '${decimal(v)} $unit';
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

  Widget summary(expanded.ChargingStats stats) {
    final total = stats.totals;
    final energy = total.sessions > 0 && total.energyKnownSessions == 0
        ? '—（缺失）'
        : '${decimal(total.energyAddedKwh)} kWh';
    final minutes = total.sessions > 0 && total.durationKnownSessions == 0
        ? '—（缺失）'
        : _formatDuration(total.durationMinTotal);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CollageTile(
          surface: CollageSurface.hero,
          child: Builder(
            builder: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('已知充电费用')),
                    Text(
                      widget.currency.code ?? '币种未知',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                Text(
                  total.cost == null
                      ? '—（缺失）'
                      : '${widget.currency.code == null ? '' : widget.currency.symbol}${decimal(total.cost!)}',
                  style: Theme.of(context).textTheme.displaySmall
                      ?.copyWith(fontSize: 44),
                ),
                const SizedBox(height: 6),
                Text(
                  '有效入电均价 ${total.unitCostAdded.value == null ? '—（缺失）' : decimal(total.unitCostAdded.value!)} ${widget.currency.symbol}/kWh',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Text('费用覆盖'),
                Text(
                  '费用有记录 ${total.costKnownSessions} / ${total.sessions} 次 · 对应入电 ${decimal(total.costKnownEnergyKwh)} kWh',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (total.sessions > 0) ...[
                  const SizedBox(height: 8),
                  Semantics(
                    label:
                        '费用记录覆盖：${total.costKnownSessions}/${total.sessions}次',
                    child: LinearProgressIndicator(
                      value: total.costKnownSessions / total.sessions,
                      minHeight: 4,
                      color: const Color(0xFF8AD6AF),
                      backgroundColor: const Color(0xFF315344),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        CollageBento(
          lead: CollageTile(
            surface: CollageSurface.mint,
            child: MetricTile(
              label: '补入电池',
              value: energy,
              note: '${total.energyKnownSessions}/${total.sessions}次有记录',
            ),
          ),
          evidence: [
            CollageTile(
              surface: CollageSurface.sand,
              child: MetricTile(
                label: '记录时长',
                value: minutes,
                note:
                    '${total.durationKnownSessions}/${total.sessions}次有记录 · 非等待时间',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget trend(expanded.ChargingStats stats) {
    final entries = [
      ('电量', 'kWh'),
      ('费用', widget.currency.symbol),
      ('均价', '${widget.currency.symbol}/kWh'),
      ('次数', '次'),
    ];
    final metric = entries[chartMetric];
    final zone = workspace.calendar!;
    String day(DateTime instant) =>
        zone.local(instant).toString().split(' ').first;
    return TimeChart(
      title: '每日补能',
      subtitle:
          '${widget.filter.first == null ? '近$recentDays天' : '自定义日期'} · '
          '${day(from)} 至 ${day(to.subtract(const Duration(microseconds: 1)))} · 按结束时间归期',
      unit: metric.$2,
      times: stats.buckets.map((bucket) => bucket.bucketStart).toList(),
      series: [
        ChartSeries(
          label: metric.$1,
          values: stats.buckets.map((bucket) {
            return switch (chartMetric) {
              0 =>
                bucket.sessions > 0 && bucket.energyKnownSessions == 0
                    ? null
                    : bucket.energyAddedKwh,
              1 => bucket.cost,
              2 => bucket.unitCostAdded.value,
              _ => bucket.sessions,
            };
          }).toList(),
        ),
      ],
      timestamp: (time) =>
          workspace.calendar!.local(time).toString().split('.').first,
      selectedIndex: chartDay,
      showSteppers: false,
      tickLabel: (t) {
        final d = workspace.calendar!.local(t);
        return '${d.month}/${d.day}';
      },
      readout: (index) {
        if (index >= stats.buckets.length) return '—';
        final bucket = stats.buckets[index];
        final local = workspace.calendar!.local(bucket.bucketStart);
        final value = switch (chartMetric) {
          0 =>
            bucket.sessions > 0 && bucket.energyKnownSessions == 0
                ? '—'
                : '${decimal(bucket.energyAddedKwh)} kWh',
          1 => widget.currency.amount(bucket.cost),
          2 => switch (bucket.unitCostAdded.value) {
            final value? => '${decimal(value)} /kWh',
            null => '—',
          },
          _ => '${bucket.sessions} 次',
        };
        return '${local.month}/${local.day} $value';
      },
      onSelected: (index) => setState(() => chartDay = index),
      onActivateSelected: stats.buckets.isEmpty
          ? null
          : () {
              final local = workspace.calendar!.local(
                stats.buckets[chartDay].bucketStart,
              );
              showDay(DateTime(local.year, local.month, local.day));
            },
      activationLabel: '查看这一天的充电',
      plotKey: const Key('charging-briefing-chart'),
      height: 75,
      compact: true,
      controls: Wrap(
        spacing: 2,
        children: [
          for (final (index, entry) in entries.indexed)
            Semantics(
              selected: chartMetric == index,
              child: TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  backgroundColor: chartMetric == index
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                ),
                onPressed: () => setState(() => chartMetric = index),
                child: Text(entry.$1),
              ),
            ),
        ],
      ),
      note: '费用与均价仅包含有效记录；缺失不补零。',
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

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.all(12),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            () {
              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recordsOnly
                        ? '充电记录'
                        : expandedAvailable
                        ? '充电'
                        : '充电历史',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    '近$recentDays天 · 按${expandedAvailable ? '结束' : '开始'}时间归期',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
              final actions = [
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
                IconButton(
                  onPressed: loading ? null : refreshAll,
                  icon: const Icon(Icons.refresh),
                  tooltip: '刷新充电',
                ),
              ];
              // 200% 文本下标题会换行，动作另起一行靠右，避免与标题挤在一行。
              return largeText(context)
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        title,
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: actions,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: title),
                        ...actions,
                      ],
                    );
            }(),
            if (expandedAvailable)
              PeriodChips(
                labels: const ['近30天', '近7天'],
                selected: widget.filter.first == null
                    ? (recentDays == 30 ? 0 : 1)
                    : -1,
                onSelected: (index) {
                  recentDays = index == 0 ? 30 : 7;
                  widget.filter.first = null;
                  widget.filter.last = null;
                  interval();
                  applyFilters();
                },
                trailing: OutlinedButton.icon(
                  onPressed: filterDates,
                  icon: const Icon(Icons.calendar_today_outlined, size: 14),
                  label: const Text('日期'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              )
            else
              TextButton(onPressed: filterDates, child: const Text('日期')),
            if (widget.filter.first != null)
              TextButton(
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
            if (expandedAvailable && hasFilters)
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    [
                      if (searchTerm.isNotEmpty) '地点搜索：$searchTerm',
                      if (locationId != null) '地点：${locationName ?? '未知地点'}',
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
                  ),
                  TextButton(
                    onPressed: clearFilters,
                    child: const Text('清除筛选'),
                  ),
                ],
              ),
            if (!expandedAvailable) const Text('— 表示数据缺失；进行中指标不代表最终结果'),
            if (workspace.calendar!.fallback)
              const Text('无法读取设备 IANA 时区，暂按 UTC'),
            if (capabilityChecked && !expandedAvailable)
              const Text('当前站点未提供充电扩展能力，显示已有记录。'),
            if (capabilityError != null) ...[
              Text(capabilityError!),
              TextButton(
                onPressed: () => loadCapability(force: true),
                child: const Text('重试站点能力'),
              ),
            ],
            if (activeError != null) ...[
              Text(activeError!),
              TextButton(
                onPressed: () => loadActive(force: true),
                child: const Text('重试进行中充电'),
              ),
            ],
            for (final active in activeItems)
              if (!recordsOnly || selectedDay == null)
                Card(
                  child: ListTile(
                    title: Text(
                      '正在充电 · ${active.location.displayName ?? '未知地点'}',
                    ),
                    subtitle: Text(
                      '已补入 ${number(active.energyAddedKwh, 'kWh')} · 不计入已完成统计',
                    ),
                    onTap: () => widget.onRecord?.call('charge', active.id),
                  ),
                ),
            if (statsLoading) const LinearProgressIndicator(),
            if (statsError != null) ...[
              Text(statsError!),
              TextButton(
                onPressed: () => loadStats(force: true),
                child: const Text('重试充电统计'),
              ),
            ],
            if (legacyStats case final stats?)
              DataCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('已知充电费用 ${widget.currency.amount(stats.totals.cost)}'),
                    Text(
                      '补入电池 ${number(stats.totals.energyAddedKwh, 'kWh')} · 已完成 ${stats.totals.sessions} 次',
                    ),
                    const Text('当前服务未提供费用覆盖和配对有效均价。'),
                  ],
                ),
              ),
            if (expandedStats case final stats? when !recordsOnly) ...[
              summary(stats),
              trend(stats),
              if (stats.totals.unitCostAdded.excludedCostSessions > 0)
                Text(
                  '均价不含 ${stats.totals.unitCostAdded.excludedCostSessions} 次能量无效的已知费用。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              CollageTile(
                surface: CollageSurface.sand,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '我的补能方式',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    EnergyComparison(
                      values: [
                        (
                          'AC',
                          stats.totals.sessions > 0 &&
                                  stats.totals.energyKnownSessions == 0
                              ? null
                              : stats.totals.acEnergyKwh,
                        ),
                        (
                          'DC',
                          stats.totals.sessions > 0 &&
                                  stats.totals.energyKnownSessions == 0
                              ? null
                              : stats.totals.dcEnergyKwh,
                        ),
                        (
                          '未知',
                          stats.totals.sessions > 0 &&
                                  stats.totals.energyKnownSessions == 0
                              ? null
                              : stats.totals.unknownEnergyKwh,
                        ),
                      ],
                      note:
                          'DC占已知分类能量 ${stats.totals.dcEnergyShare == null ? '—' : decimal(stats.totals.dcEnergyShare! * 100)}%；各分类只含已记录电量，未知不并入AC。',
                    ),
                    Text(
                      stats.totals.sessions > 0 &&
                              stats.totals.durationKnownSessions == 0
                          ? '分类记录时长缺失'
                          : 'AC ${decimal(stats.totals.acDurationMin)} 分钟 · DC ${decimal(stats.totals.dcDurationMin)} 分钟 · 未知 ${decimal(stats.totals.unknownDurationMin)} 分钟',
                    ),
                    Text(
                      '分类已知 ${stats.totals.classificationKnownSessions} / ${stats.totals.sessions} 次',
                    ),
                  ],
                ),
              ),
              if (statsCheckedAt != null)
                Text(
                  '统计校验时间 ${workspace.calendar!.local(statsCheckedAt!).toString().split('.').first}',
                ),
            ],
            if (expandedAvailable && recordsOnly) ...[
              filterControls(),
              if (selectedDay != null)
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '仅看 ${selectedDay!.year}年${selectedDay!.month}月${selectedDay!.day}日结束的充电',
                    ),
                    TextButton(
                      onPressed: () => showDay(null),
                      child: const Text('返回完整区间'),
                    ),
                  ],
                ),
              if (sort == 'unit_cost_added_asc')
                const Text('按服务端有效入电均价排序；单次均价可在详情查看。'),
              if (matchedSessions != null) Text('匹配 $matchedSessions 次充电'),
            ],
            if (expandedAvailable && !recordsOnly) ...[
              Text('地点账目', style: Theme.of(context).textTheme.titleMedium),
              if (locationsLoading) const LinearProgressIndicator(),
              if (locationError != null) ...[
                Text(locationError!),
                TextButton(
                  onPressed: () =>
                      loadLocations(more: locationFailedMore, force: true),
                  child: const Text('重试地点账目'),
                ),
              ],
              if (locationsCheckedAt != null && locations.isNotEmpty)
                Text(
                  '地点校验时间 ${workspace.calendar!.local(locationsCheckedAt!).toString().split('.').first}',
                ),
              for (final place in locations)
                Card(
                  child: ListTile(
                    title: Text(place.location.displayName ?? '未知地点'),
                    subtitle: Text(
                      '${place.sessions} 次 · ${place.sessions > 0 && place.energyKnownSessions == 0 ? '入电量缺失' : '${decimal(place.energyAddedKwh)} kWh'} · 费用有记录 ${place.costKnownSessions}/${place.sessions} 次\n有效入电均价 ${place.unitCostAdded.value == null ? '—' : decimal(place.unitCostAdded.value!)} ${widget.currency.code ?? '币种未知'}/kWh',
                    ),
                    onTap: () {
                      locationId = place.locationId;
                      locationName = place.location.displayName;
                      recordsOnly = true;
                      applyFilters();
                      scrollToTop();
                    },
                  ),
                ),
              if (locationCursor != null)
                TextButton(
                  onPressed: locationsLoading
                      ? null
                      : () => loadLocations(more: true),
                  child: const Text('加载更多地点'),
                ),
            ],
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('数据说明'),
              children: [
                Text(
                  '按${expandedAvailable ? '结束' : '开始'}时间归期 · 时区：${workspace.calendar!.identifier}；费用与均价仅包含有效记录。',
                ),
              ],
            ),
            if (loading) const LinearProgressIndicator(),
            if (error != null) ...[
              Semantics(liveRegion: true, child: Text(error!)),
              TextButton(
                onPressed: () => load(more: failedMore, force: true),
                child: const Text('重试充电'),
              ),
            ],
            if (loaded && items.isEmpty)
              Text(expandedAvailable ? '此区间无已完成充电记录' : '此区间无充电记录'),
            if (expandedAvailable && !recordsOnly && items.isNotEmpty)
              Text('最近的充电', style: Theme.of(context).textTheme.titleMedium),
            for (final (index, v) in items.indexed) ...[
              if (!expandedAvailable || recordsOnly || index < 3) ...[
                if (index == 0 ||
                    recordDay(recordTime(items[index - 1])) !=
                        recordDay(recordTime(v)))
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 10),
                    child: Text(
                      recordDay(recordTime(v)),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
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
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${workspace.calendar!.local(v.startedAt).toString().split('.').first} · ${v.isActive ? '进行中' : '已结束'}',
                          ),
                          Text(
                            v.isDc == null
                                ? '充电类型未知'
                                : '充电类型 ${v.isDc! ? 'DC' : 'AC'}',
                          ),
                          Text(
                            '电量 ${number(v.startSoc, '%')} → ${number(v.endSoc, '%')}',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          SocInterval(start: v.startSoc, end: v.endSoc),
                          const SizedBox(height: 8),
                          Text(
                            '充入电池 ${number(v.energyAddedKwh, 'kWh')}',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '电网侧 ${number(v.energyUsedKwh, 'kWh')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '费用 ${widget.currency.amount(v.cost)}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '时长 ${number(v.durationMin, '分钟')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (v.location.geofence != null)
                            Text('围栏：${v.location.geofence}'),
                          if (v.location.address != null &&
                              v.location.address != v.location.displayName)
                            Text('地址：${v.location.address}'),

                          Text('充电 #${v.id} · 查看详情'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
            if (loaded &&
                expandedAvailable &&
                !recordsOnly &&
                (items.length > 3 || next != null))
              TextButton(
                onPressed: () {
                  setState(() => recordsOnly = true);
                  scrollToTop();
                },
                child: const Text('查看全部充电记录'),
              ),
            if (loaded && next != null && (!expandedAvailable || recordsOnly))
              TextButton(
                onPressed: loading
                    ? null
                    : () => load(more: true, force: error != null),
                child: const Text('加载更多充电'),
              ),
            if (loaded &&
                next == null &&
                items.isNotEmpty &&
                (!expandedAvailable || recordsOnly))
              const Text('已到最后一条'),
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
