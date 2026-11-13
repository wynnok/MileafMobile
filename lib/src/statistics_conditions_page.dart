import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design/components/components.dart';
import 'design/icons.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'statistics_conditions_contract.g.dart' as dto;
import 'statistics_insights_page.dart';
import 'statistics_usage_page.dart';

String conditionsValue(Object? value) =>
    value is num ? value.toString().replaceFirst(RegExp(r'\.0$'), '') : '—';

String _signed(Object? value) => conditionsValue(value).replaceFirst('-', '−');

/// P08/R09：组标签使用易读短名（如「−5至0°C」）；精确半开区间保留在读屏与说明。
String conditionsShortLabel(Map<String, dynamic> b) {
  final upper = b['upper_c'];
  if (upper == null) return '≥${_signed(b['lower_c'])}°C';
  return '${_signed(b['lower_c'])}至${_signed(upper)}°C';
}

/// 精确区间读屏文本，明确左闭右开。
String conditionsPreciseLabel(Map<String, dynamic> b) {
  final upper = b['upper_c'];
  if (upper == null) return '≥${_signed(b['lower_c'])} °C';
  return '[${_signed(b['lower_c'])}, ${_signed(upper)}) °C';
}

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
  bool loading = false;
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
    setState(() {
      error = null;
      loading = true;
    });
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
        setState(() {
          data = result.body;
          // 同期间强刷可能返回更少的温度组；选中组随之收敛，不越过有效范围。
          final bins = usageItems(result.body['temperature_bins']);
          if (bins.isEmpty) {
            selected = 0;
          } else if (selected > bins.length - 1) {
            selected = bins.length - 1;
          }
        });
      }
    } catch (_) {
      if (mounted && attempt == sequence && requestedScope == scope) {
        setState(
          () => error =
              '能耗条件读取失败${data == null ? '' : '，保留上次结果（${data!['as_of'] ?? '校验时间未知'}）'}',
        );
      }
    }
    if (mounted && attempt == sequence && requestedScope == scope) {
      setState(() => loading = false);
    }
  }

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
        action: MileafIconButton(
          icon: MileafIconName.refresh,
          tooltip: '刷新能耗条件',
          onPressed: loading ? null : () => load(force: true),
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
        if (loading && data != null) ...[
          const MileafProgressLine(),
          const Text('能耗条件更新中'),
        ],
        const SizedBox(height: MileafSpace.s16),
        if (b == null)
          Text(
            '等待可用的温度与配对样本',
            style: type.body.copyWith(color: colors.textMuted),
          )
        else ...[
          _selectedGroup(b),
          const SizedBox(height: MileafSpace.s16),
          _plotSection(bins),
          const SizedBox(height: MileafSpace.s12),
          _groupControls(bins),
          const SizedBox(height: MileafSpace.s16),
          Text(
            '未知温度 ${conditionsValue(d['unknown_temperature_drives'])} 趟',
            style: type.body.copyWith(color: colors.textMuted),
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
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    // R01：专题主体沿共享内容限宽，与其他专题页一致。
    return source.compact
        ? column
        : MileafContent(
            child: SingleChildScrollView(
              padding: MileafLayout.pagePadding(context, top: MileafSpace.s8),
              child: column,
            ),
          );
  }

  /// P08：所选组净电耗 36（metricLg）与样本限定、相关非因果就近。
  Widget _selectedGroup(Map<String, dynamic> b) {
    final colors = context.colors;
    final type = context.type;
    return Semantics(
      container: true,
      label:
          '所选温度组 ${conditionsPreciseLabel(b)}，左闭右开，净电耗 ${conditionsValue(b['consumption_wh_km'])} Wh/km',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '所选温度组 · ${conditionsShortLabel(b)}',
            style: type.label.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: MileafSpace.s4),
          MileafNumber(
            value: b['consumption_wh_km'] == null
                ? null
                : conditionsValue(b['consumption_wh_km']),
            unit: 'Wh/km',
            scale: MetricValueScale.metricLg,
          ),
          // R02：缺失主值「—」配明确口径，不用巨大符号充当主视觉。
          if (b['consumption_wh_km'] == null)
            Text('暂无净电耗', style: type.micro.copyWith(color: colors.textMuted))
          else
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
    );
  }

  /// R06：条件分组点图；轴留白按实际文字度量并应用完整 TextScaler，
  /// 大字减少刻度而不是隐藏轴；无样本不画点也不伪造刻度。
  Widget _plotSection(List<Map<String, dynamic>> bins) {
    final colors = context.colors;
    final type = context.type;
    final large = MileafLayout.largeText(context);
    final axisStyle = type.micro.copyWith(color: colors.textFaint);
    final valueStyle = type.label.copyWith(color: colors.accentStrong);
    final scale = _BinScale(bins, large);
    final leftPad = scale.leftPadFor(
      axisStyle,
      MediaQuery.textScalerOf(context),
    );
    String plotSemantics() {
      // P08：读屏逐组保留精确半开区间。
      final parts = <String>[
        for (final bin in bins)
          '${conditionsShortLabel(bin)}（${conditionsPreciseLabel(bin)}，左闭右开）'
              '${bin['consumption_wh_km'] is num ? '净电耗 ${conditionsValue(bin['consumption_wh_km'])} Wh/km' : '无样本'}',
      ];
      return '温度分组点图，横向拖动或点按选择温度组。${parts.join('；')}。';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          container: true,
          label: plotSemantics(),
          onIncrease: selected < bins.length - 1
              ? () => setState(() => selected++)
              : null,
          onDecrease: selected > 0 ? () => setState(() => selected--) : null,
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                return KeyEventResult.ignored;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                  selected > 0) {
                setState(() => selected--);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
                  selected < bins.length - 1) {
                setState(() => selected++);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: MileafFocusRing(
              child: LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  onTapDown: (p) => _pickBin(
                    p.localPosition.dx,
                    constraints.maxWidth,
                    leftPad,
                    bins.length,
                  ),
                  onHorizontalDragUpdate: (p) => _pickBin(
                    p.localPosition.dx,
                    constraints.maxWidth,
                    leftPad,
                    bins.length,
                  ),
                  child: SizedBox(
                    key: const ValueKey('conditions-plot'),
                    height: large ? 240 : 200,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _TemperaturePlot(
                        bins,
                        selected,
                        colors,
                        axisStyle,
                        valueStyle,
                        MediaQuery.textScalerOf(context),
                        large,
                        scale,
                        leftPad,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: MileafSpace.s8),
        Text(
          '分组为左闭右开区间，例如 −5至0°C 表示 [−5, 0) °C；无样本的温度组不显示点。',
          style: type.micro.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }

  void _pickBin(double dx, double width, double leftPad, int count) {
    if (count <= 0 || width <= leftPad) return;
    final plotWidth = width - leftPad;
    setState(() {
      selected = ((dx - leftPad) / plotWidth * count).floor().clamp(
        0,
        count - 1,
      );
    });
  }

  Widget _groupControls(List<Map<String, dynamic>> bins) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // R05：互斥选择共用 ChipRow/StatusChip，44 高、12 圆角、160ms 选中反馈；
      // 大字换行重排，不产生三行胶囊残片。
      ChipRow(
        children: [
          for (var i = 0; i < bins.length; i++)
            StatusChip(
              label: conditionsShortLabel(bins[i]),
              selected: selected == i,
              onTap: () => setState(() => selected = i),
            ),
        ],
      ),
      const SizedBox(height: MileafSpace.s8),
      Wrap(
        spacing: MileafSpace.s16,
        children: [
          TextButton(
            onPressed: selected > 0 ? () => setState(() => selected--) : null,
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
  );

  Widget _distanceSection(Map<String, dynamic> d) {
    final items = usageItems(d['distance_bins']);
    final total = usageMap(d['summary'])['driving_distance_km'] as num? ?? 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: '短途、中途与长途', range: 'Wh/km'),
        const SizedBox(height: MileafSpace.s4),
        for (final item in items)
          Builder(
            builder: (context) {
              final upper = item['upper_km'];
              final short = upper == null
                  ? '≥${_signed(item['lower_km'])} km'
                  : '${_signed(item['lower_km'])}–${_signed(upper)} km';
              final precise = upper == null
                  ? '≥${_signed(item['lower_km'])} km'
                  : '[${_signed(item['lower_km'])}, ${_signed(upper)}) km';
              final meta =
                  '${conditionsValue(item['drives'])} 趟 · 占比 '
                  '${((item['distance_km'] as num? ?? 0) / total * 100).clamp(0, 100).toStringAsFixed(1)}% · '
                  '配对 ${conditionsValue(item['paired_energy_kwh'])} kWh / ${conditionsValue(item['paired_distance_km'])} km';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MileafDataRow(
                    title: short,
                    meta: meta,
                    value: conditionsValue(item['consumption_wh_km']),
                    unit: 'Wh/km',
                    semanticLabel: '$short（$precise，左闭右开），$meta',
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
                    childrenPadding: const EdgeInsets.only(
                      bottom: MileafSpace.s8,
                    ),
                    expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [coverage(item['coverage'])],
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _notesSection(Map<String, dynamic> d) => StatisticsTopicNotes(
    title: '数据说明',
    children: [
      const Text('温度组与距离组均为左闭右开区间；组标签如 −5至0°C 表示 [−5, 0) °C，只显示真实分组值，不在组间插值。'),
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
    this.axisStyle,
    this.valueStyle,
    this.textScaler,
    this.largeText,
    this.scale,
    this.leftPad,
  );
  final List<Map<String, dynamic>> bins;
  final int selected;
  final MileafColors colors;
  final TextStyle axisStyle;
  final TextStyle valueStyle;
  final TextScaler textScaler;
  final bool largeText;

  /// 与命中映射共享的刻度尺，保证点按位置与绘制槽位同源。
  final _BinScale scale;
  final double leftPad;

  TextPainter _measure(String text, TextStyle style) => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final low = scale.low, span = scale.span;
    final tickCount = scale.tickCount;
    final tickPainters = [
      for (final text in scale.tickTexts) _measure(text, axisStyle),
    ];
    // R06.4：大字减少轴刻度；X 组标签隔组绘制，完整列表由分组控件与语义承载。
    final xStep = largeText ? 2 : 1;
    final xPainters = [
      for (var i = 0; i < bins.length; i++)
        if (i % xStep == 0) _measure(conditionsShortLabel(bins[i]), axisStyle),
    ];
    final valuePainters = [
      for (final b in bins)
        if (b['consumption_wh_km'] is num)
          _measure(conditionsValue(b['consumption_wh_km']), valueStyle),
    ];
    var labelHeight = 0.0, valueHeight = 0.0;
    for (final p in xPainters) {
      if (p.height > labelHeight) labelHeight = p.height;
    }
    for (final p in valuePainters) {
      if (p.height > valueHeight) valueHeight = p.height;
    }
    // R06.4：左侧留白由共享刻度尺给出（最长刻度宽 + 8），底部按实际行高 + 8。
    final plotBottom = size.height - labelHeight - MileafSpace.s8;
    final plotTop = valueHeight + MileafSpace.s4;
    final plotHeight = (plotBottom - plotTop).clamp(1.0, size.height);
    // Baseline and slot labels exist even when every group lacks samples.
    canvas.drawLine(
      Offset(leftPad, plotBottom),
      Offset(size.width, plotBottom),
      Paint()..color = colors.line,
    );
    final slot = (size.width - leftPad) / (bins.isEmpty ? 1 : bins.length);
    var xIndex = 0;
    double? lastRight;
    for (var i = 0; i < bins.length; i++) {
      if (i % xStep != 0) continue;
      final p = xPainters[xIndex++];
      final center = leftPad + slot * (i + .5);
      final x = (center - p.width / 2).clamp(leftPad, size.width - p.width);
      // R06.3：轴标签以可读为先，与前一个重叠时跳过；完整组名由分组控件与语义承载。
      if (lastRight != null && x < lastRight + MileafSpace.s4) continue;
      p.paint(canvas, Offset(x, plotBottom + MileafSpace.s8));
      lastRight = x + p.width;
    }
    for (var i = 0; i < tickPainters.length; i++) {
      final value = low + span * i / (tickCount - 1);
      final y = plotBottom - (value - low) / span * plotHeight;
      // R06.5：最多 3 条轻细网格线，基线之外不与数据抢对比。
      if (i > 0 && y >= plotTop) {
        canvas.drawLine(
          Offset(leftPad, y),
          Offset(size.width, y),
          Paint()..color = colors.line,
        );
      }
      final p = tickPainters[i];
      p.paint(
        canvas,
        Offset(leftPad - MileafSpace.s4 - p.width, y - p.height / 2),
      );
    }
    var valueIndex = 0;
    for (var i = 0; i < bins.length; i++) {
      final v = bins[i]['consumption_wh_km'];
      if (v is! num) continue;
      final center = leftPad + slot * (i + .5);
      final point = Offset(
        center,
        plotBottom - (v.toDouble() - low) / span * plotHeight,
      );
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
      final p = valuePainters[valueIndex++];
      p.paint(
        canvas,
        Offset(
          (point.dx - p.width / 2).clamp(leftPad, size.width - p.width),
          point.dy - p.height - MileafSpace.s4,
        ),
      );
    }
    for (final p in [...tickPainters, ...xPainters, ...valuePainters]) {
      p.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant _TemperaturePlot old) =>
      old.selected != selected ||
      old.bins != bins ||
      old.largeText != largeText ||
      old.textScaler != textScaler ||
      old.axisStyle != axisStyle ||
      old.valueStyle != valueStyle ||
      old.scale != scale ||
      old.leftPad != leftPad;
}

/// 点图的共享刻度尺：零基线量程与刻度文本由数据决定，
/// 绘制与命中映射使用同一实例，避免轴留白与选组偏移分叉。
class _BinScale {
  _BinScale(List<Map<String, dynamic>> bins, bool largeText) {
    final values = [
      for (final b in bins)
        if (b['consumption_wh_km'] is num)
          (b['consumption_wh_km'] as num).toDouble(),
    ];
    for (final v in values) {
      if (v < low) low = v;
      if (v > high) high = v;
    }
    span = (high - low).abs() < .001 ? 1.0 : high - low;
    // R06.4：大字减少刻度；无样本时不伪造刻度。
    tickCount = largeText ? 2 : 3;
    tickTexts = [
      if (values.isNotEmpty)
        for (var i = 0; i < tickCount; i++)
          (low + span * i / (tickCount - 1)).toStringAsFixed(0),
    ];
  }

  double low = 0, high = 1, span = 1;
  late int tickCount;
  late List<String> tickTexts;

  /// R06.4：左侧留白按最长刻度宽 + 8，应用完整 TextScaler。
  double leftPadFor(TextStyle style, TextScaler scaler) {
    if (tickTexts.isEmpty) return 0;
    var widest = 0.0;
    for (final text in tickTexts) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest + MileafSpace.s8;
  }
}
