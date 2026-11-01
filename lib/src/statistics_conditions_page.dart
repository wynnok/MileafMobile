import 'package:flutter/material.dart';

import 'design/components/components.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'statistics_conditions_contract.g.dart' as dto;
import 'statistics_insights_page.dart';
import 'statistics_usage_page.dart';

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
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final e in usageMap(value).entries)
        if (e.value is Map)
          Padding(
            padding: const EdgeInsets.only(bottom: MileafSpace.s4),
            child: Text(
              '${e.key}：有效 ${conditionsValue(usageMap(e.value)['valid_count'])} 趟 / ${conditionsValue(usageMap(e.value)['valid_distance_km'])} km；排除 ${conditionsValue(usageMap(e.value)['excluded_count'])} 趟',
              style: context.type.micro.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (source.features['driving_analysis'] != true) {
      return const StateView(
        kind: StateViewKind.empty,
        title: '当前站点不支持能耗条件分析',
        message: '站点未声明能耗条件分析能力。',
      );
    }
    final d = data;
    final bins = usageItems(d?['temperature_bins']);
    final b = bins.isEmpty ? null : bins[selected.clamp(0, bins.length - 1)];
    final colors = context.colors;
    final type = context.type;
    final children = <Widget>[
      SectionHeader(
        title: '温度下的用车能耗',
        range: 'Wh/km',
        action: TextButton(
          onPressed: () => load(force: true),
          child: const Text('刷新能耗条件'),
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: MileafSpace.s8),
          child: InlineBanner(
            message: error!,
            tone: BannerTone.error,
            actionLabel: '重试能耗条件',
            onAction: () => load(force: true),
          ),
        ),
      if (d == null && error == null)
        const StateView(kind: StateViewKind.loading, title: '正在读取能耗条件')
      else if (d != null && d['status'] == 'unsupported')
        const StateView(
          kind: StateViewKind.empty,
          title: '当前站点不支持能耗条件分析',
          message: '站点未声明能耗条件分析能力。',
        )
      else if (d != null && d['status'] == 'no_records')
        const StateView(
          kind: StateViewKind.empty,
          title: '区间内无已完成行程',
          message: '这段时间没有可配对的已完成行程。',
        )
      else if (d != null && d['status'] == 'available') ...[
        const SizedBox(height: MileafSpace.s16),
        if (b == null)
          Text(
            '等待可用的温度与配对样本',
            style: type.body.copyWith(color: colors.textMuted),
          )
        else ...[
          Semantics(
            container: true,
            label:
                '室外均温 ${label(b)}，净电耗 ${conditionsValue(b['consumption_wh_km'])} Wh/km',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '所选温度组 · ${label(b)}',
                  style: type.label.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: MileafSpace.s4),
                MileafNumber(
                  value: b['consumption_wh_km'] == null
                      ? null
                      : conditionsValue(b['consumption_wh_km']),
                  unit: 'Wh/km',
                  scale: MetricValueScale.display,
                ),
                const SizedBox(height: MileafSpace.s4),
                Text(
                  switch (b['sample_status']) {
                    'adequate' => '样本达到暂定门槛',
                    'sparse' => '小样本，仅供点读',
                    _ => '配对样本不足',
                  },
                  style: type.body.copyWith(
                    color: colors.text,
                    fontWeight: MileafType.weightSemiBold,
                  ),
                ),
                const SizedBox(height: MileafSpace.s4),
                Text(
                  '关联观察，不代表因果或排名',
                  style: type.micro.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: MileafSpace.s16),
          Text(
            '未知温度 ${conditionsValue(d['unknown_temperature_drives'])} 趟',
            style: type.body.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: MileafSpace.s16),
          Text(
            '加权净电耗 · Wh/km',
            style: type.label.copyWith(color: colors.textMuted),
          ),
          Text(
            '行程室外均温 · 5°C半开分组',
            style: type.micro.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: MileafSpace.s8),
          Semantics(
            label: '温度分类点图，横向拖动选择温度组',
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                onTapDown: (p) => setState(
                  () => selected =
                      (p.localPosition.dx / constraints.maxWidth * bins.length)
                          .floor()
                          .clamp(0, bins.length - 1),
                ),
                onHorizontalDragUpdate: (p) => setState(
                  () => selected =
                      (p.localPosition.dx / constraints.maxWidth * bins.length)
                          .floor()
                          .clamp(0, bins.length - 1),
                ),
                child: SizedBox(
                  height: MileafLayout.largeText(context) ? 230 : 180,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _TemperaturePlot(
                      bins,
                      selected,
                      colors,
                      type.body.copyWith(color: colors.textFaint),
                      MileafLayout.largeText(context),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: MileafSpace.s8),
          Wrap(
            spacing: MileafSpace.s8,
            runSpacing: MileafSpace.s8,
            children: [
              for (var i = 0; i < bins.length; i++)
                ChoiceChip(
                  label: Text(label(bins[i])),
                  selected: selected == i,
                  onSelected: (_) => setState(() => selected = i),
                ),
            ],
          ),
          const SizedBox(height: MileafSpace.s8),
          Wrap(
            spacing: MileafSpace.s16,
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
          const SizedBox(height: MileafSpace.section),
          StatisticsTopicFacts(
            facts: [
              StatisticsTopicFact(
                label: '候选',
                value: conditionsValue(b['drives']),
                unit: '趟',
              ),
              StatisticsTopicFact(
                label: '已知里程',
                value: conditionsValue(b['distance_km']),
                unit: 'km',
              ),
              StatisticsTopicFact(
                label: '有效配对',
                value: conditionsValue(
                  usageMap(usageMap(b['coverage'])['paired'])['valid_count'],
                ),
                unit: '趟',
                note:
                    '${conditionsValue(b['paired_distance_km'])} km · '
                    '${conditionsValue(b['paired_energy_kwh'])} kWh',
              ),
              StatisticsTopicFact(
                label: '单程中位数',
                value: conditionsValue(b['median_drive_distance_km']),
                unit: 'km',
              ),
              StatisticsTopicFact(
                label: '平均记录速度',
                value: conditionsValue(b['mean_trip_speed_kmh']),
                unit: 'km/h',
              ),
            ],
          ),
          const SizedBox(height: MileafSpace.s16),
          StatisticsTopicNotes(
            title: '该组数据覆盖',
            children: [coverage(b['coverage'])],
          ),
          if (b['evidence_filter'] is Map)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => openDrivingEvidence(
                  context,
                  source,
                  usageMap(b['evidence_filter']),
                  title: '温度组行程证据',
                  onRecord: widget.onRecord,
                ),
                child: const Text('查看该温度组行程'),
              ),
            ),
        ],
        const SizedBox(height: MileafSpace.section),
        _distanceSection(d),
        const SizedBox(height: MileafSpace.section),
        _notesSection(d),
      ],
    ];
    return ListView(
      padding: MileafLayout.pagePadding(context, top: MileafSpace.s8),
      children: children,
    );
  }

  Widget _distanceSection(Map<String, dynamic> d) {
    final items = usageItems(d['distance_bins']);
    final total = usageMap(d['summary'])['driving_distance_km'] as num? ?? 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: '短途、中途与长途', range: 'Wh/km'),
        const SizedBox(height: MileafSpace.s4),
        for (final item in items) ...[
          MileafDataRow(
            title:
                '[${conditionsValue(item['lower_km'])}, ${item['upper_km'] == null ? '∞' : conditionsValue(item['upper_km'])}) km',
            meta:
                '${conditionsValue(item['drives'])} 趟 · 占比 '
                '${((item['distance_km'] as num? ?? 0) / total * 100).clamp(0, 100).toStringAsFixed(1)}% · '
                '配对 ${conditionsValue(item['paired_energy_kwh'])} kWh / ${conditionsValue(item['paired_distance_km'])} km',
            value: conditionsValue(item['consumption_wh_km']),
            unit: 'Wh/km',
            topLine: true,
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              '距离组数据覆盖',
              style: context.type.micro.copyWith(
                color: context.colors.textFaint,
              ),
            ),
            childrenPadding: const EdgeInsets.only(bottom: MileafSpace.s8),
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            children: [coverage(item['coverage'])],
          ),
        ],
      ],
    );
  }

  Widget _notesSection(Map<String, dynamic> d) => StatisticsTopicNotes(
    title: '数据覆盖与暂定口径',
    children: [
      Text(
        '快照 ${d['as_of']} · ${d['method']} v${d['version']} · ${d['validation']}',
      ),
      for (final e in usageMap(d['thresholds']).entries)
        Text('${e.key}：${conditionsValue(e.value)}'),
      coverage(usageMap(d['summary'])['coverage']),
      const Text('各指标有效集独立；配对总能量 / 配对总里程直接读取服务端，不平均逐趟比率。'),
    ],
  );
}

class _TemperaturePlot extends CustomPainter {
  _TemperaturePlot(
    this.bins,
    this.selected,
    this.colors,
    this.labelStyle,
    this.largeText,
  );
  final List<Map<String, dynamic>> bins;
  final int selected;
  final MileafColors colors;
  final TextStyle labelStyle;
  final bool largeText;

  @override
  void paint(Canvas canvas, Size size) {
    final values = bins.map((b) => b['consumption_wh_km']).whereType<num>();
    if (values.isEmpty) return;
    var low = 0.0, high = 1.0;
    for (final v in values) {
      if (v < low) low = v.toDouble();
      if (v > high) high = v.toDouble();
    }
    final fontSize = labelStyle.fontSize ?? 9;
    final plotTop = fontSize * 2 + MileafSpace.s8;
    final plotBottom = size.height - fontSize * 2 - 4;
    final plotHeight = (plotBottom - plotTop).clamp(1.0, size.height);
    final span = (high - low).abs() < .001 ? 1.0 : high - low;
    canvas.drawLine(
      Offset(0, plotBottom),
      Offset(size.width, plotBottom),
      Paint()..color = colors.line,
    );
    if (!largeText) {
      for (var i = 0; i < 3; i++) {
        final value = low + span * i / 2;
        _text(
          canvas,
          value.toStringAsFixed(0),
          Offset(0, plotBottom - (value - low) / span * plotHeight - fontSize),
          colors.textFaint,
        );
      }
    }
    for (var i = 0; i < bins.length; i++) {
      final center = (i + .5) * size.width / bins.length;
      _text(
        canvas,
        '${conditionsValue(bins[i]['lower_c'])}–${conditionsValue(bins[i]['upper_c'])}',
        Offset(
          (center - size.width / bins.length / 2).clamp(0, size.width),
          size.height - fontSize * 1.4,
        ),
        colors.textFaint,
      );
      final v = bins[i]['consumption_wh_km'];
      if (v is! num) continue;
      final point = Offset(center, plotBottom - (v - low) / span * plotHeight);
      if (i == selected) {
        canvas.drawCircle(
          point,
          MileafChartMetrics.currentHalo,
          Paint()..color = colors.accent.withValues(alpha: .2),
        );
      }
      canvas.drawCircle(
        point,
        i == selected
            ? MileafChartMetrics.currentPoint
            : MileafChartMetrics.pointRadius,
        Paint()
          ..color = colors.accent
          ..style = bins[i]['sample_status'] == 'adequate'
              ? PaintingStyle.fill
              : PaintingStyle.stroke
          ..strokeWidth = MileafChartMetrics.lineStroke,
      );
      _text(
        canvas,
        conditionsValue(v),
        Offset(
          (point.dx - fontSize * 1.5).clamp(0, size.width),
          point.dy - fontSize * 1.6,
        ),
        colors.accent,
      );
    }
  }

  void _text(Canvas canvas, String text, Offset at, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: labelStyle.copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(canvas, at);
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant _TemperaturePlot old) => true;
}
