import 'package:flutter/material.dart';

import 'statistics_insights_page.dart';
import 'statistics_usage_page.dart';
import 'statistics_conditions_contract.g.dart' as dto;

String conditionsValue(Object? value) =>
    value is num ? value.toString().replaceFirst(RegExp(r'\.0$'), '') : '—';

class StatisticsConditionsPage extends StatefulWidget {
  const StatisticsConditionsPage({
    super.key,
    required this.source,
    this.onRecord,
  });
  final StatisticsInsightsContext source;
  final ValueChanged<int>? onRecord;
  @override
  State<StatisticsConditionsPage> createState() => _ConditionsState();
}

class _ConditionsState extends State<StatisticsConditionsPage> {
  Map<String, dynamic>? data;
  String? error, loadedScope;
  int sequence = 0, selected = 0;
  StatisticsInsightsContext get source => widget.source;
  String get scope =>
      '${identityHashCode(source.workspace.session.current)}:${source.workspace.selectedId}:${source.workspace.calendar?.identifier}:${source.window.from}:${source.window.to}';
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant StatisticsConditionsPage old) {
    super.didUpdateWidget(old);
    if (loadedScope != scope) {
      data = null;
      selected = 0;
      load();
    }
  }

  @override
  void dispose() {
    sequence++;
    super.dispose();
  }

  Future<void> load({bool force = false}) async {
    if (source.features['driving_analysis'] != true) return;
    final ws = source.workspace,
        owner = source.workspace.session.current,
        id = source.workspace.selectedId,
        zone = source.workspace.calendar;
    if (owner == null || id == null || zone == null) return;
    loadedScope = scope;
    final attempt = ++sequence, requestedScope = scope;
    setState(() => error = null);
    try {
      final result = await ws.cache.get(
        owner,
        'vehicles/$id/driving-analysis',
        query: {
          'view': 'conditions',
          'from': source.window.from.toIso8601String(),
          'to': source.window.to.toIso8601String(),
          'tz': zone.identifier,
        },
        force: force,
      );
      dto.DrivingAnalysisConditions.fromJson(result.body);
      if (mounted &&
          attempt == sequence &&
          requestedScope == scope &&
          ws.session.isCurrent(owner)) {
        setState(() => data = result.body);
      }
    } catch (_) {
      if (mounted && attempt == sequence && requestedScope == scope) {
        setState(() => error = '能耗条件读取失败${data == null ? '' : '，保留上次快照'}');
      }
    }
  }

  String label(Map<String, dynamic> b) =>
      '[${conditionsValue(b['lower_c'])}, ${conditionsValue(b['upper_c'])}) °C';
  Widget coverage(Object? value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final e in usageMap(value).entries)
        if (e.value is Map)
          Text(
            '${e.key}：有效 ${conditionsValue(usageMap(e.value)['valid_count'])} 趟 / ${conditionsValue(usageMap(e.value)['valid_distance_km'])} km；排除 ${conditionsValue(usageMap(e.value)['excluded_count'])} 趟',
          ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    if (source.features['driving_analysis'] != true) {
      return const Center(child: Text('当前站点不支持能耗条件分析'));
    }
    final d = data;
    final bins = usageItems(d?['temperature_bins']);
    final b = bins.isEmpty ? null : bins[selected.clamp(0, bins.length - 1)];
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text('温度与能耗', style: Theme.of(context).textTheme.headlineSmall),
        const Text('行程室外均温 · 5°C半开分组 · 关联观察，不代表因果或排名'),
        if (error != null) Text(error!),
        if (d != null)
          TextButton(
            onPressed: () => load(force: true),
            child: const Text('刷新能耗条件'),
          ),
        if (error != null || d == null)
          TextButton(
            onPressed: () => load(force: true),
            child: const Text('重试能耗条件'),
          ),
        if (d != null) ...[
          if (d['status'] == 'unsupported')
            const Text('当前站点不支持能耗条件分析')
          else if (d['status'] == 'no_records')
            const Text('区间内无已完成行程')
          else ...[
            Text('未知温度 ${conditionsValue(d['unknown_temperature_drives'])} 趟'),
            Text(
              '完整区间 ${conditionsValue(usageMap(d['summary'])['driving_distance_km'])} km · 单程中位数 ${conditionsValue(usageMap(d['summary'])['distance_p50_km'])} km',
            ),
            const SizedBox(height: 16),
            const Text('加权净电耗 · Wh/km'),
            if (bins.isNotEmpty) ...[
              Semantics(
                label: '温度分类点图，横向拖动选择温度组',
                child: LayoutBuilder(
                  builder: (context, constraints) => GestureDetector(
                    onTapDown: (p) => setState(
                      () => selected =
                          (p.localPosition.dx /
                                  constraints.maxWidth *
                                  bins.length)
                              .floor()
                              .clamp(0, bins.length - 1),
                    ),
                    onHorizontalDragUpdate: (p) => setState(
                      () => selected =
                          (p.localPosition.dx /
                                  constraints.maxWidth *
                                  bins.length)
                              .floor()
                              .clamp(0, bins.length - 1),
                    ),
                    child: SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _TemperaturePlot(
                          bins,
                          selected,
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < bins.length; i++)
                    ChoiceChip(
                      label: Text(label(bins[i])),
                      selected: selected == i,
                      onSelected: (_) => setState(() => selected = i),
                    ),
                ],
              ),
              Wrap(
                spacing: 16,
                children: [
                  TextButton(
                    onPressed: selected > 0
                        ? () => setState(() => selected--)
                        : null,
                    child: const Text('上一温度组'),
                  ),
                  TextButton(
                    onPressed: selected < bins.length - 1
                        ? () => setState(() => selected++)
                        : null,
                    child: const Text('下一温度组'),
                  ),
                ],
              ),
            ],
            if (b != null) ...[
              Text(label(b), style: Theme.of(context).textTheme.titleLarge),
              Text(
                '${conditionsValue(b['consumption_wh_km'])} Wh/km',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(switch (b['sample_status']) {
                'adequate' => '样本达到暂定门槛',
                'sparse' => '小样本，仅供点读',
                _ => '配对样本不足',
              }),
              Text(
                '候选 ${conditionsValue(b['drives'])} 趟 · 已知里程 ${conditionsValue(b['distance_km'])} km',
              ),
              Text(
                '有效配对 ${conditionsValue(usageMap(usageMap(b['coverage'])['paired'])['valid_count'])} 趟 · ${conditionsValue(b['paired_distance_km'])} km',
              ),
              Text(
                '配对原值 ${conditionsValue(b['paired_energy_kwh'])} kWh / ${conditionsValue(b['paired_distance_km'])} km',
              ),
              Text(
                '单程中位数 ${conditionsValue(b['median_drive_distance_km'])} km · 平均记录速度 ${conditionsValue(b['mean_trip_speed_kmh'])} km/h',
              ),
              coverage(b['coverage']),
              if (b['evidence_filter'] is Map)
                TextButton(
                  onPressed: () => openDrivingEvidence(
                    context,
                    source,
                    usageMap(b['evidence_filter']),
                    title: '温度组行程证据',
                    onRecord: widget.onRecord,
                  ),
                  child: const Text('查看该温度组行程'),
                ),
            ],
            const SizedBox(height: 16),
            Text('短途、中途与长途', style: Theme.of(context).textTheme.titleMedium),
            for (final item in usageItems(d['distance_bins'])) ...[
              Text(
                '[${conditionsValue(item['lower_km'])}, ${item['upper_km'] == null ? '∞' : conditionsValue(item['upper_km'])}) km · ${conditionsValue(item['consumption_wh_km'])} Wh/km',
              ),
              LinearProgressIndicator(
                value:
                    ((item['distance_km'] as num? ?? 0) /
                            (usageMap(d['summary'])['driving_distance_km']
                                    as num? ??
                                1))
                        .clamp(0, 1)
                        .toDouble(),
              ),
              Text(
                '${conditionsValue(item['drives'])} 趟 · 配对 ${conditionsValue(item['paired_energy_kwh'])} kWh / ${conditionsValue(item['paired_distance_km'])} km',
              ),
              coverage(item['coverage']),
            ],
            ExpansionTile(
              title: const Text('数据覆盖与暂定口径'),
              children: [
                Text(
                  '快照 ${d['as_of']} · ${d['method']} v${d['version']} · ${d['validation']}',
                ),
                for (final e in usageMap(d['thresholds']).entries)
                  Text('${e.key}：${conditionsValue(e.value)}'),
                coverage(usageMap(d['summary'])['coverage']),
                const Text('各指标有效集独立；配对总能量 / 配对总里程直接读取服务端，不平均逐趟比率。'),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

class _TemperaturePlot extends CustomPainter {
  _TemperaturePlot(this.bins, this.selected, this.color, this.axis);
  final List<Map<String, dynamic>> bins;
  final int selected;
  final Color color, axis;
  @override
  void paint(Canvas canvas, Size size) {
    final values = bins.map((b) => b['consumption_wh_km']).whereType<num>();
    var low = 0.0, high = 1.0;
    for (final v in values) {
      if (v < low) low = v.toDouble();
      if (v > high) high = v.toDouble();
    }
    final baseline = 140 - (0 - low) / (high - low) * 120;
    canvas.drawLine(
      Offset(0, baseline),
      Offset(size.width, baseline),
      Paint()..color = axis,
    );
    for (var i = 0; i < bins.length; i++) {
      final label = TextPainter(
        text: TextSpan(
          text:
              '${conditionsValue(bins[i]['lower_c'])}–${conditionsValue(bins[i]['upper_c'])}',
          style: TextStyle(color: axis, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
        canvas,
        Offset(
          ((i + .5) * size.width / bins.length - label.width / 2).clamp(
            0,
            size.width - label.width,
          ),
          145,
        ),
      );
      final v = bins[i]['consumption_wh_km'];

      if (v is! num) continue;
      final point = Offset(
        (i + .5) * size.width / bins.length,
        140 - (v - low) / (high - low) * 120,
      );
      canvas.drawCircle(
        point,
        i == selected ? 7 : 4,
        Paint()
          ..color = color
          ..style = (bins[i]['sample_status'] == 'adequate'
              ? PaintingStyle.fill
              : PaintingStyle.stroke)
          ..strokeWidth = 2,
      );
      final text = TextPainter(
        text: TextSpan(
          text: conditionsValue(v),
          style: TextStyle(color: color, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(
          (point.dx - text.width / 2).clamp(0, size.width - text.width),
          point.dy - 20,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TemperaturePlot old) => true;
}
