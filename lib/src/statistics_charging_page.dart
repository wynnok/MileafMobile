import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'charging_page.dart';
import 'charging_detail.dart';
import 'charging_experience_contract.g.dart' as expanded;
import 'charging_statistics_contract.g.dart' as legacy;
import 'design/components/components.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'statistics_insights_page.dart';
import 'statistics_usage_page.dart';

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

  String _cost(num? value) => scope.currency.amountValue(value);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: scope.currency,
    builder: (context, _) {
      final stats = data, detail = richer;
      final totals = stats?.totals, rich = detail?.totals;
      final labels = ['入电量', '已知支出', '有效入电均价', '充电次数'];
      final units = [
        'kWh',
        scope.currency.symbol,
        '${scope.currency.symbol}/kWh',
        '次',
      ];
      final children = <Widget>[
        SectionHeader(
          title: '补能账目',
          range: '按结束日 · 仅已完成充电',
          action: TextButton(
            onPressed: loading ? null : () => load(force: true),
            child: const Text('刷新补能统计'),
          ),
        ),
        if (capabilityError != null)
          Padding(
            padding: const EdgeInsets.only(top: MileafSpace.s8),
            child: InlineBanner(
              message: capabilityError!,
              tone: BannerTone.warning,
              actionLabel: '重试补能能力',
              onAction: () => load(force: true),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: MileafSpace.s8),
            child: InlineBanner(
              message: error!,
              tone: BannerTone.error,
              actionLabel: '刷新补能统计',
              onAction: () => load(force: true),
            ),
          ),
        if (loading && totals != null)
          Padding(
            padding: const EdgeInsets.only(top: MileafSpace.s8),
            child: MileafProgressLine(),
          ),
        // 0 条记录不是「费用 0 元、0 次 0 kWh」：直接走空态，不画空账目。
        if (totals != null && totals.sessions > 0) ...[
          _conclusion(totals, rich),
          _trend(stats!, detail, labels, units),
          if (expandedAvailable && stats.buckets.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: openBucket,
                child: const Text('查看此期间补能'),
              ),
            ),
          const SizedBox(height: MileafSpace.section),
          _facts(totals, rich),
          const SizedBox(height: MileafSpace.section),
          _composition(totals, rich),
          if (expandedAvailable) ...[
            const SizedBox(height: MileafSpace.section),
            _locationSection(),
          ],
          const SizedBox(height: MileafSpace.section),
          _notes(detail),
        ] else if (!loading && error == null)
          const StateView(
            kind: StateViewKind.empty,
            title: '还没有充电记录',
            message: '尚无补能统计；换一个期间或继续记录。',
          ),
      ];
      return ListView(
        padding: MileafLayout.pagePadding(context, top: MileafSpace.s8),
        children: children,
      );
    },
  );

  Widget _conclusion(
    legacy.ChargingMetrics totals,
    expanded.ChargingMetrics? rich,
  ) {
    final colors = context.colors;
    final type = context.type;
    final known = rich?.costKnownSessions ?? 0;
    // 没有一条记录带费用时显示 `—`：没有记录不等于花了 0 元（Spec §9.5）。
    final cost = known == 0 ? '—' : scope.currency.amountValue(totals.cost);
    final coverage = totals.sessions == 0
        ? 0.0
        : (known / totals.sessions).clamp(0.0, 1.0);
    final note = scope.currency.amountNote;
    final costEnergy = rich == null
        ? '—'
        : '${rich.costKnownEnergyKwh.toStringAsFixed(1)} kWh';
    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '已知支出 · 覆盖同时看',
            style: type.label.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: MileafSpace.s4),
          MileafNumber(value: cost, scale: MetricValueScale.display),
          if (note != null) ...[
            const SizedBox(height: MileafSpace.s4),
            Text(note, style: type.micro.copyWith(color: colors.textFaint)),
          ],
          const SizedBox(height: MileafSpace.s8),
          Text(
            '有效入电均价 ${scope.currency.amountValue(rich?.unitCostAdded.value)}/kWh',
            style: type.body.copyWith(color: colors.text),
          ),
          const SizedBox(height: MileafSpace.s12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '费用覆盖',
                  style: type.label.copyWith(color: colors.textMuted),
                ),
              ),
              Text(
                '$known / ${totals.sessions} 次',
                style: type.label.copyWith(color: colors.text),
              ),
            ],
          ),
          const SizedBox(height: MileafSpace.s8),
          Semantics(
            label: '费用记录覆盖：$known/${totals.sessions}次',
            child: ClipRRect(
              borderRadius: MileafRadius.fullAll,
              child: Container(
                height: 4,
                color: colors.line,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: coverage,
                  heightFactor: 1,
                  child: ColoredBox(color: colors.accent),
                ),
              ),
            ),
          ),
          const SizedBox(height: MileafSpace.s8),
          Text(
            '费用有记录 $known / ${totals.sessions} 次 · '
            '对应入电 $costEnergy',
            style: type.micro.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _trend(
    legacy.ChargingStats stats,
    expanded.ChargingStats? detail,
    List<String> labels,
    List<String> units,
  ) {
    final buckets = stats.buckets;
    if (buckets.isEmpty) return const SizedBox.shrink();
    final values = [
      for (var i = 0; i < buckets.length; i++)
        switch (metric) {
          0 =>
            detail != null &&
                    detail.buckets[i].sessions > 0 &&
                    detail.buckets[i].energyKnownSessions == 0
                ? null
                : buckets[i].energyAddedKwh,
          1 => buckets[i].cost,
          2 =>
            detail?.buckets[i].unitCostAdded.value ??
                (detail == null ? buckets[i].costPerKwh : null),
          _ => buckets[i].sessions,
        },
    ];
    final selected = selectedBucket.clamp(0, buckets.length - 1);
    String tick(DateTime t) {
      final d = scope.workspace.calendar!.local(t);
      return '${d.month}/${d.day}';
    }

    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.s16),
      child: TimeSeriesChart(
        title: '${labels[metric]}走势',
        unit: units[metric],
        subtitle: '按结束日',
        times: [for (final bucket in buckets) bucket.bucketStart],
        series: [
          ChartSeries(
            label: labels[metric],
            values: values,
            style: metric == 2 ? ChartSeriesStyle.line : ChartSeriesStyle.bars,
          ),
        ],
        semanticsLabel: '补能走势图表',
        controls: Wrap(
          spacing: MileafSpace.s8,
          runSpacing: MileafSpace.s8,
          children: [
            for (var i = 0; i < labels.length; i++)
              ChoiceChip(
                label: Text(labels[i]),
                selected: metric == i,
                onSelected: (_) => setState(() => metric = i),
              ),
          ],
        ),
        selectedIndex: selected,
        onSelected: (value) => setState(() => selectedBucket = value),
        height: 118,
        tickLabel: tick,
        readout: (index) {
          if (index < 0 || index >= buckets.length) return '—';
          final value = values[index];
          final date = tick(buckets[index].bucketStart);
          return switch (metric) {
            0 =>
              '$date ${value == null ? '—' : '${value.toStringAsFixed(1)} kWh'}',
            1 => '$date ${_cost(value)}',
            2 => '$date ${value == null ? '—' : '${_cost(value)}/kWh'}',
            _ => '$date ${value == null ? '—' : '${value.toInt()} 次'}',
          };
        },
        trailing: Text(
          '点按读值',
          style: context.type.label.copyWith(color: context.colors.textFaint),
        ),
      ),
    );
  }

  Widget _facts(legacy.ChargingMetrics totals, expanded.ChargingMetrics? rich) {
    final energyMissing =
        rich != null && rich.sessions > 0 && rich.energyKnownSessions == 0;
    final durationMissing =
        rich != null && rich.sessions > 0 && rich.durationKnownSessions == 0;
    final energy = energyMissing
        ? '—'
        : totals.energyAddedKwh.toStringAsFixed(1);
    final duration = rich == null || durationMissing
        ? '—'
        : '${rich.durationMinTotal}';
    return StatisticsTopicFacts(
      facts: [
        StatisticsTopicFact(
          label: '充入电池',
          value: energy,
          unit: 'kWh',
          note: rich == null
              ? null
              : '${rich.energyKnownSessions}/${rich.sessions} 次有记录',
        ),
        StatisticsTopicFact(
          label: '充电次数',
          value: '${totals.sessions}',
          unit: '次',
          note: '已完成',
        ),
        StatisticsTopicFact(
          label: '记录时长',
          value: duration,
          unit: '分钟',
          note: rich == null
              ? null
              : '${rich.durationKnownSessions}/${rich.sessions} 次有记录 · 非等待时间',
        ),
        StatisticsTopicFact(
          label: '费用有记录',
          value: rich == null
              ? '—'
              : '${rich.costKnownSessions} / ${rich.sessions}',
          unit: '次',
        ),
        StatisticsTopicFact(
          label: 'DC 占已知分类',
          // 已知分类能量为 0 时分母为空：比例未知，不是 0%。
          value: energyMissing || totals.dcEnergyShare == null
              ? '—'
              : (totals.dcEnergyShare! * 100).toStringAsFixed(1),
          unit: '%',
        ),
      ],
    );
  }

  Widget _composition(
    legacy.ChargingMetrics totals,
    expanded.ChargingMetrics? rich,
  ) {
    final colors = context.colors;
    final type = context.type;
    final energyMissing =
        rich != null && rich.sessions > 0 && rich.energyKnownSessions == 0;
    final rows = <(String, num?)>[
      ('AC', energyMissing ? null : totals.acEnergyKwh),
      ('DC', energyMissing ? null : totals.dcEnergyKwh),
      if (rich != null) ('未知', energyMissing ? null : rich.unknownEnergyKwh),
    ];
    final durationMissing =
        rich != null && rich.sessions > 0 && rich.durationKnownSessions == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: '补能结构', range: 'AC / DC / 未知时间分布'),
        const SizedBox(height: MileafSpace.s8),
        MileafCompositionBar(segments: rows),
        const SizedBox(height: MileafSpace.s8),
        Wrap(
          spacing: MileafSpace.s16,
          runSpacing: MileafSpace.s4,
          children: [
            for (final (label, value) in rows)
              Text(
                '$label ${value == null ? '—' : '${value.toStringAsFixed(2)} kWh'}',
                style: type.micro.copyWith(color: colors.textMuted),
              ),
          ],
        ),
        const SizedBox(height: MileafSpace.s8),
        Text(
          'DC占已知分类 ${energyMissing || totals.dcEnergyShare == null ? '—' : '${(totals.dcEnergyShare! * 100).toStringAsFixed(1)}%'}',
          style: type.body.copyWith(color: colors.text),
        ),
        if (rich != null) ...[
          const SizedBox(height: MileafSpace.s4),
          Text(
            durationMissing
                ? '分类记录时长缺失'
                : '分类记录时长：AC ${rich.acDurationMin} / DC ${rich.dcDurationMin} / 未知 ${rich.unknownDurationMin} 分钟',
            style: type.body.copyWith(color: colors.textMuted),
          ),
        ],
        const SizedBox(height: MileafSpace.s4),
        Text(
          'DC 占比分母：AC + DC 已知分类能量 · 未知不归AC；记录时长不是等待时间',
          style: type.micro.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }

  Widget _locationSection() {
    final colors = context.colors;
    final type = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: '自己的地点账目'),
        if (locationsLoading) const MileafProgressLine(),
        if (locationsError != null)
          Padding(
            padding: const EdgeInsets.only(top: MileafSpace.s8),
            child: InlineBanner(
              message: locationsError!,
              tone: BannerTone.error,
              actionLabel: '重试地点账目',
              onAction: () => loadLocations(force: true),
            ),
          ),
        const SizedBox(height: MileafSpace.s4),
        if (locations.isEmpty && !locationsLoading && locationsError == null)
          Text('还没有地点账目', style: type.body.copyWith(color: colors.textMuted)),
        for (final place in locations)
          MileafDataRow(
            title: place.location.displayName ?? '未知地点',
            meta:
                '${place.sessions} 次 · '
                '${place.energyKnownSessions == 0 && place.sessions > 0 ? '—' : '${place.energyAddedKwh.toStringAsFixed(1)} kWh'} · '
                '费用有记录 ${place.costKnownSessions}/${place.sessions}次',
            topLine: true,
            showChevron: true,
            onTap: () => openRecords(place: place),
          ),
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
        const SizedBox(height: MileafSpace.s8),
        Wrap(
          spacing: MileafSpace.s8,
          runSpacing: MileafSpace.s8,
          children: [
            for (final entry in const {
              'ac': 'AC记录',
              'dc': 'DC记录',
              'unknown': '未知分类记录',
            }.entries)
              StatusChip(
                label: entry.value,
                onTap: () => openRecords(type: entry.key),
              ),
            StatusChip(label: '查看期间补能记录', onTap: () => openRecords()),
          ],
        ),
      ],
    );
  }

  Widget _notes(expanded.ChargingStats? rich) => StatisticsTopicNotes(
    children: [
      const Text('仅已结束充电按 ended_at 归期；充电列表按开始日，跨夜记录的日期可能不同。'),
      if (rich != null)
        Text(
          '入电配对费用 ${scope.currency.amountValue(rich.totals.unitCostAdded.numeratorCost)} / ${rich.totals.unitCostAdded.denominatorKwh} kWh；网侧配对费用 ${scope.currency.amountValue(rich.totals.unitCostGrid.numeratorCost)} / ${rich.totals.unitCostGrid.denominatorKwh} kWh。均价和总计直接来自服务端，不平均桶比率${scope.currency.amountNote == null ? '' : '；${scope.currency.amountNote}'}。',
        ),
      if (checkedAt != null)
        Text('查询校验 ${scope.workspace.calendar!.local(checkedAt!)}，不是车辆采样时间'),
    ],
  );
}
