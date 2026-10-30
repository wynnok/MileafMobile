import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'charging_page.dart';
import 'charging_detail.dart';
import 'charging_experience_contract.g.dart' as expanded;
import 'charging_statistics_contract.g.dart' as legacy;
import 'data_cards.dart';
import 'collage.dart';
import 'data_chart.dart';
import 'statistics_insights_page.dart';

class StatisticsChargingPage extends StatefulWidget {
  const StatisticsChargingPage({super.key, required this.context});
  final StatisticsInsightsContext context;
  @override
  State<StatisticsChargingPage> createState() => _StatisticsChargingPageState();
}

class _StatisticsChargingPageState extends State<StatisticsChargingPage> {
  legacy.ChargingStats? data;
  expanded.ChargingStats? richer;
  String? error, capabilityError;
  String? locationsError, locationCursor, queryIdentity;
  Object? queryOwner;
  final locations = <expanded.ChargingLocation>[];
  bool locationsLoading = false, expandedAvailable = false;
  int locationSequence = 0;
  bool loading = false;
  int sequence = 0, metric = 0, selectedBucket = 0;
  DateTime? checkedAt;
  StatisticsInsightsContext get scope => widget.context;
  String identity(StatisticsInsightsContext c) =>
      '${c.workspace.revision}/${c.workspace.selectedId}/${c.workspace.calendar!.identifier}/${c.window.from}/${c.window.to}/${c.window.bucket}';
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant StatisticsChargingPage old) {
    super.didUpdateWidget(old);
    if (queryIdentity != identity(scope) ||
        !identical(queryOwner, scope.workspace.session.current)) {
      data = null;
      richer = null;
      checkedAt = null;
      locations.clear();
      locationCursor = null;
      locationSequence++;
      load();
    }
  }

  @override
  void dispose() {
    sequence++;
    locationSequence++;
    super.dispose();
  }

  Future<void> load({bool force = false}) async {
    final workspace = scope.workspace, owner = scope.workspace.session.current;
    final vehicle = workspace.selectedId, key = identity(scope);
    if (owner == null || vehicle == null) return;
    queryIdentity = key;
    queryOwner = owner;
    final request = ++sequence;
    setState(() {
      loading = true;
      error = null;
      capabilityError = null;
    });
    bool valid() =>
        mounted &&
        request == sequence &&
        workspace.session.isCurrent(owner) &&
        identity(scope) == key;
    var available = expandedAvailable;
    try {
      final result = await workspace.cache.get(owner, 'meta', force: force);
      final capability = result.body['charging_experience'];
      available =
          capability is Map &&
          capability['contract_version'] == 'charging-experience-v1' &&
          capability['fields'] is Map;
    } catch (_) {
      if (valid()) setState(() => capabilityError = '补能能力暂不可用，保留基础统计');
    }
    if (!valid()) return;
    expandedAvailable = available;
    if (available) unawaited(loadLocations(force: force));
    try {
      final query = scope.window.query('charging', workspace.calendar!);
      if (available) query['time_basis'] = 'ended_at';
      final result = await workspace.cache.get(
        owner,
        'vehicles/$vehicle/stats',
        query: query,
        force: force,
      );
      final basic = legacy.ChargingStats.fromJson(result.body);
      final detail = available
          ? expanded.ChargingStats.fromJson(result.body)
          : null;
      if (valid()) {
        setState(() {
          data = basic;
          richer = detail;
          checkedAt = result.checkedAt;
          selectedBucket = 0;
        });
      }
    } catch (failure) {
      if (valid()) {
        setState(
          () => error =
              '${failure is ApiFailure ? failure.message : '补能统计暂不可用'}${data != null ? '；保留上次快照' : ''}',
        );
      }
    } finally {
      if (valid()) setState(() => loading = false);
    }
  }

  Map<String, String> get sharedQuery => {
    'from': scope.window.from.toIso8601String(),
    'to': scope.window.to.toIso8601String(),
    'tz': scope.workspace.calendar!.identifier,
    'time_basis': 'ended_at',
  };

  Future<void> loadLocations({bool force = false, bool more = false}) async {
    final workspace = scope.workspace, owner = scope.workspace.session.current;
    final vehicle = workspace.selectedId, key = identity(scope);
    if (owner == null || vehicle == null) return;
    final attempt = ++locationSequence;
    final cursor = more ? locationCursor : null;
    setState(() {
      locationsLoading = true;
      locationsError = null;
    });
    bool valid() =>
        mounted &&
        attempt == locationSequence &&
        workspace.session.isCurrent(owner) &&
        identity(scope) == key;
    try {
      final response = await workspace.cache.get(
        owner,
        'vehicles/$vehicle/charging-locations',
        query: {...sharedQuery, 'limit': '20', 'cursor': ?cursor},
        force: force,
      );
      final page = expanded.ChargingLocationPage.fromJson(response.body);
      if (valid()) {
        setState(() {
          if (!more) locations.clear();
          final ids = locations.map((p) => p.locationId).toSet();
          locations.addAll(page.items.where((p) => ids.add(p.locationId)));
          locationCursor = page.nextCursor;
        });
      }
    } catch (_) {
      if (valid()) {
        setState(
          () => locationsError =
              '地点账目暂不可用${locations.isNotEmpty ? '；保留上次快照' : ''}',
        );
      }
    } finally {
      if (valid()) setState(() => locationsLoading = false);
    }
  }

  void openRecords({
    String? type,
    expanded.ChargingLocation? place,
    DateTime? from,
    DateTime? to,
  }) {
    final window = scope.window, calendar = scope.workspace.calendar!;
    final start = from ?? window.from, end = to ?? window.to;
    final first = calendar.local(start);
    final last = calendar.local(end.subtract(const Duration(microseconds: 1)));
    final filter = ChargingFilter()
      ..first = DateTime.utc(first.year, first.month, first.day)
      ..last = DateTime.utc(last.year, last.month, last.day);
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('补能记录')),
          body: ChargingPage(
            workspace: scope.workspace,
            currency: scope.currency,
            filter: filter,
            initialEntry: ChargingEntry(
              from: start,
              to: end,
              chargingType: type,
              locationId: place?.locationId,
              locationName: place?.location.displayName,
            ),
            onRecord: (_, id) => openChargingDetail(
              context,
              scope.workspace,
              scope.currency,
              id,
            ),
          ),
        ),
      ),
    );
  }

  void openBucket() {
    final buckets = data?.buckets;
    if (buckets == null || buckets.isEmpty) return;
    final calendar = scope.workspace.calendar!, window = scope.window;
    final start = buckets[selectedBucket].bucketStart;
    final local = calendar.local(start);
    final nextDate = switch (window.bucket) {
      'day' => DateTime.utc(local.year, local.month, local.day + 1),
      'week' => DateTime.utc(local.year, local.month, local.day + 7),
      'month' => DateTime.utc(local.year, local.month + 1),
      _ => DateTime.utc(local.year + 1),
    };
    final next = calendar.midnight(nextDate);
    final from = start.isBefore(window.from) ? window.from : start;
    final to = next.isAfter(window.to) ? window.to : next;
    if (from.isBefore(to)) openRecords(from: from, to: to);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: scope.currency,
    builder: (context, _) {
      final stats = data, detail = richer;
      final totals = stats?.totals, rich = detail?.totals;
      final labels = ['入电量', '已知支出', '有效入电均价', '充电次数'];
      final units = [
        'kWh',
        scope.currency.code ?? '币种未知',
        '${scope.currency.code ?? '币种未知'}/kWh',
        '次',
      ];
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text('补能账目', style: Theme.of(context).textTheme.headlineSmall),
          const Text('按结束日 · 仅已完成充电'),
          if (capabilityError != null) Text(capabilityError!),
          if (error != null) Text(error!),
          if (loading) const LinearProgressIndicator(),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: loading ? null : () => load(force: true),
              child: const Text('刷新补能统计'),
            ),
          ),
          if (totals != null) ...[
            CollageTile(
              surface: CollageSurface.hero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '已知支出 · 覆盖同时看',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  MetricTile(
                    label: '已知充电支出',
                    value: scope.currency.amount(totals.cost),
                    emphasize: true,
                  ),
                  Text(
                    rich == null
                        ? '费用覆盖未提供，已知支出不代表全部用车成本'
                        : '费用有记录 ${rich.costKnownSessions} / ${rich.sessions} 次',
                  ),
                  if (rich != null) Text('对应入电 ${rich.costKnownEnergyKwh} kWh'),
                ],
              ),
            ),
            TimeChart(
              selectedIndex: selectedBucket,
              onSelected: (value) => setState(() => selectedBucket = value),
              title: '${labels[metric]}走势',
              unit: units[metric],
              times: [for (final bucket in stats!.buckets) bucket.bucketStart],
              series: [
                ChartSeries(
                  label: labels[metric],
                  values: [
                    for (var i = 0; i < stats.buckets.length; i++)
                      switch (metric) {
                        0 =>
                          detail != null &&
                                  detail.buckets[i].sessions > 0 &&
                                  detail.buckets[i].energyKnownSessions == 0
                              ? null
                              : stats.buckets[i].energyAddedKwh,
                        1 => stats.buckets[i].cost,
                        2 =>
                          detail?.buckets[i].unitCostAdded.value ??
                              (detail == null
                                  ? stats.buckets[i].costPerKwh
                                  : null),
                        _ => stats.buckets[i].sessions,
                      },
                  ],
                ),
              ],
              timestamp: (t) => scope.workspace.calendar!
                  .local(t)
                  .toString()
                  .split('.')
                  .first,
              tickLabel: (t) {
                final d = scope.workspace.calendar!.local(t);
                return '${d.month}/${d.day}';
              },
              presentation: metric == 2
                  ? ChartPresentation.line
                  : ChartPresentation.bars,
              controls: Wrap(
                spacing: 6,
                children: [
                  for (var i = 0; i < labels.length; i++)
                    ChoiceChip(
                      label: Text(labels[i]),
                      selected: metric == i,
                      onSelected: (_) => setState(() => metric = i),
                    ),
                ],
              ),
            ),
            if (expandedAvailable && stats.buckets.isNotEmpty)
              TextButton(onPressed: openBucket, child: const Text('查看此期间补能')),
            CollageTile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MetricTile(
                    label: '充入电池',
                    value:
                        '${rich != null && rich.sessions > 0 && rich.energyKnownSessions == 0 ? '—' : totals.energyAddedKwh} kWh',
                  ),
                  Text('充电 ${totals.sessions} 次'),
                  if (rich != null) ...[
                    Text(
                      '能量有记录 ${rich.energyKnownSessions} / ${rich.sessions} 次',
                    ),
                    Text(
                      '有效入电均价 ${scope.currency.amount(rich.unitCostAdded.value)}/kWh',
                    ),
                    Text(
                      '有效网侧均价 ${scope.currency.amount(rich.unitCostGrid.value)}/kWh',
                    ),
                    Text(
                      '入电均价有效分母 ${rich.unitCostAdded.denominatorKwh} kWh；网侧 ${rich.unitCostGrid.denominatorKwh} kWh',
                    ),
                    Text(
                      '记录时长 ${rich.sessions > 0 && rich.durationKnownSessions == 0 ? '—' : rich.durationMinTotal} 分钟 · 有效 ${rich.durationKnownSessions} / ${rich.sessions} 次',
                    ),
                  ],
                ],
              ),
            ),
            CollageTile(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('补能结构', style: Theme.of(context).textTheme.titleMedium),
                  EnergyComparison(
                    values: [
                      (
                        'AC',
                        rich != null &&
                                rich.sessions > 0 &&
                                rich.energyKnownSessions == 0
                            ? null
                            : totals.acEnergyKwh,
                      ),
                      (
                        'DC',
                        rich != null &&
                                rich.sessions > 0 &&
                                rich.energyKnownSessions == 0
                            ? null
                            : totals.dcEnergyKwh,
                      ),
                      if (rich != null)
                        (
                          '未知',
                          rich.sessions > 0 && rich.energyKnownSessions == 0
                              ? null
                              : rich.unknownEnergyKwh,
                        ),
                    ],
                  ),
                  Text(
                    'DC占已知分类 ${totals.dcEnergyShare == null ? '—' : '${(totals.dcEnergyShare! * 100).toStringAsFixed(1)}%'}',
                  ),
                  if (rich != null)
                    Text(
                      rich.sessions > 0 && rich.durationKnownSessions == 0
                          ? '分类记录时长缺失'
                          : '分类记录时长：AC ${rich.acDurationMin} / DC ${rich.dcDurationMin} / 未知 ${rich.unknownDurationMin} 分钟',
                    ),
                  const Text('DC 占比分母：AC + DC 已知分类能量'),
                  const Text('未知不归AC；记录时长不是等待时间'),
                ],
              ),
            ),
            TimeChart(
              title: 'AC / DC / 未知时间分布',
              unit: 'kWh',
              times: [for (final bucket in stats.buckets) bucket.bucketStart],
              series: [
                for (final kind in ['AC', 'DC', if (detail != null) '未知'])
                  ChartSeries(
                    label: kind,
                    values: [
                      for (var i = 0; i < stats.buckets.length; i++)
                        if (detail != null &&
                            detail.buckets[i].sessions > 0 &&
                            detail.buckets[i].energyKnownSessions == 0)
                          null
                        else
                          switch (kind) {
                            'AC' => stats.buckets[i].acEnergyKwh,
                            'DC' => stats.buckets[i].dcEnergyKwh,
                            _ => detail!.buckets[i].unknownEnergyKwh,
                          },
                    ],
                  ),
              ],
              timestamp: (t) => scope.workspace.calendar!
                  .local(t)
                  .toString()
                  .split('.')
                  .first,
              tickLabel: (t) {
                final d = scope.workspace.calendar!.local(t);
                return '${d.month}/${d.day}';
              },
              presentation: ChartPresentation.bars,
            ),
          ] else if (!loading && error == null)
            const Text('尚无补能统计'),
          if (expandedAvailable) ...[
            Text('自己的地点账目', style: Theme.of(context).textTheme.titleMedium),
            if (locationsLoading) const LinearProgressIndicator(),
            if (locationsError != null) Text(locationsError!),
            if (locationsError != null)
              TextButton(
                onPressed: locationsLoading
                    ? null
                    : () => loadLocations(force: true),
                child: const Text('重试地点账目'),
              ),
            for (final place in locations)
              ListTile(
                title: Text(place.location.displayName ?? '未知地点'),
                subtitle: Text(
                  '${place.sessions} 次 · ${place.energyKnownSessions == 0 && place.sessions > 0 ? '—' : place.energyAddedKwh} kWh · 费用有记录 ${place.costKnownSessions}/${place.sessions}次',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openRecords(place: place),
              ),
            if (locationCursor != null)
              TextButton(
                onPressed: locationsLoading
                    ? null
                    : () => loadLocations(more: true),
                child: const Text('加载更多地点'),
              ),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in const {
                  'ac': 'AC记录',
                  'dc': 'DC记录',
                  'unknown': '未知分类记录',
                }.entries)
                  TextButton(
                    onPressed: () => openRecords(type: entry.key),
                    child: Text(entry.value),
                  ),
              ],
            ),
            TextButton(
              onPressed: () => openRecords(),
              child: const Text('查看期间补能记录'),
            ),
          ],
          ExpansionTile(
            title: const Text('数据说明'),
            children: [
              const ListTile(
                title: Text('仅已结束充电按 ended_at 归期；充电列表按开始日，跨夜记录的日期可能不同。'),
              ),
              if (rich != null)
                ListTile(
                  title: Text(
                    '入电配对费用 ${scope.currency.amount(rich.unitCostAdded.numeratorCost)} / ${rich.unitCostAdded.denominatorKwh} kWh；网侧配对费用 ${scope.currency.amount(rich.unitCostGrid.numeratorCost)} / ${rich.unitCostGrid.denominatorKwh} kWh。均价和总计直接来自服务端，不平均桶比率。',
                  ),
                ),
              if (checkedAt != null)
                Text(
                  '查询校验 ${scope.workspace.calendar!.local(checkedAt!)}，不是车辆采样时间',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ],
      );
    },
  );
}
