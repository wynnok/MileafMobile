import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'copy/dates.dart' as copy;
import 'copy/messages.dart' as messages;
import 'copy/terms.dart' as terms;
import 'copy/units.dart' as units;
import 'design/components/components.dart';
import 'design/icons.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'reading_scope.dart';
import 'statistics_insights_page.dart';
import 'statistics_usage_page.dart';
import 'workspace.dart';
import 'range_observations_contract.g.dart' as dto;

class RangeObservationPage extends StatefulWidget {
  const RangeObservationPage({
    super.key,
    required this.context,
    this.expanded = false,
  });
  final StatisticsInsightsContext context;
  final bool expanded;
  @override
  State<RangeObservationPage> createState() => _RangeObservationPageState();
}

class _RangeObservationPageState extends State<RangeObservationPage>
    with WidgetsBindingObserver {
  Map<String, dynamic>? data;
  String? error;
  bool loading = false;
  int months = 6, sequence = 0, selected = 0;
  String? identity;
  DateTime? checkedAt;

  /// The owner is actually looking at this topic: its own route is on top and
  /// the statistics tab it lives in is the selected one.
  bool get readingNow =>
      ReadingScope.isActive(context) &&
      (ModalRoute.of(context)?.isCurrent ?? false);

  String get currentIdentity {
    final c = widget.context;
    return '${c.workspace.session.current?.generation}/${c.workspace.selectedId}/${c.workspace.calendar?.identifier}/${c.workspace.revision}/${c.features['range_observations']}/${c.workspace.calendar?.day(c.workspace.session.now())}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    identity = currentIdentity;
    load();
  }

  @override
  void didUpdateWidget(covariant RangeObservationPage old) {
    super.didUpdateWidget(old);
    // A hidden or covered topic records nothing and reads nothing; the next
    // visible rebuild picks the change up.
    if (identity != currentIdentity && readingNow) {
      identity = currentIdentity;
      data = null;
      load();
    }
  }

  @override
  void dispose() {
    sequence++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        readingNow &&
        (checkedAt == null ||
            widget.context.workspace.session
                    .now()
                    .difference(checkedAt!)
                    .inSeconds >=
                30 ||
            identity != currentIdentity)) {
      if (identity != currentIdentity) {
        identity = currentIdentity;
        data = null;
      }
      load();
    }
  }

  Future<void> load({bool force = false}) async {
    final c = widget.context,
        w = c.workspace,
        owner = w.session.current,
        id = w.selectedId,
        cal = w.calendar;
    final attempt = ++sequence;
    if (c.features['range_observations'] != true ||
        owner == null ||
        id == null ||
        cal == null) {
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    final captured = currentIdentity;
    bool valid() =>
        mounted &&
        sequence == attempt &&
        captured == currentIdentity &&
        w.session.isCurrent(owner);
    try {
      final r = await w.cache.get(
        owner,
        'vehicles/$id/range-observations',
        query: {
          'months': '$months',
          'to': w.session.now().toUtc().toIso8601String(),
          'tz': cal.identifier,
        },
        force: force,
      );
      final parsed = dto.RangeObservations.fromJson(r.body);
      if (parsed.query.vehicleId != id ||
          parsed.query.tz != cal.identifier ||
          parsed.query.filters['months'] != months ||
          parsed.query.timeBasis != 'ended_at' ||
          parsed.method != 'session-day-rated-range-v1' ||
          parsed.version != 1 ||
          parsed.rangeKind != 'rated' ||
          parsed.socSource != 'battery_level') {
        throw const FormatException('Mismatched range observation context');
      }
      if (valid()) {
        setState(() {
          checkedAt = w.session.now();
          data = r.body;
          selected = math.max(0, (data!['buckets'] as List).length - 1);
        });
      }
    } catch (_) {
      if (valid()) {
        setState(() {
          error = data == null
              ? messages.readFailedMessage('续航观察')
              // CP07：失败且有旧数据时说明快照时间。
              : messages.staleMessage(checkedAt!, w.session.now());
        });
      }
    } finally {
      if (valid()) setState(() => loading = false);
    }
  }

  String value(Object? x) => x is num ? x.toStringAsFixed(1) : '—';

  DateTime _local(Object? iso) {
    final parsed = iso is String ? DateTime.tryParse(iso) : null;
    final calendar = widget.context.workspace.calendar;
    if (parsed == null || calendar == null) {
      return widget.context.workspace.session.now();
    }
    return calendar.local(parsed);
  }

  /// P10/R02：月中读数行的日期与未结束标识；缺失月不补零。
  String _monthHeading(Map row) {
    final date = _local(row['bucket_start']);
    final now = widget.context.workspace.session.now();
    return row['partial'] == true
        ? '${copy.formatMonth(date, now)}（本月未结束）'
        : copy.formatMonth(date, now);
  }

  /// R06：趋势图例用真实编码色样，区分月中位数折线与波动带。
  Widget _legend(BuildContext context) {
    final colors = context.colors;
    final style = context.type.subheadline.copyWith(color: colors.textMuted);
    return Wrap(
      spacing: MileafSpace.s16,
      runSpacing: MileafSpace.s4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 16, height: 2, color: colors.accent),
            const SizedBox(width: MileafSpace.s4),
            // R03：大字下图例文字换行重排，色样固定，不横向溢出。
            Flexible(child: Text('月中位数', style: style)),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 10,
              decoration: BoxDecoration(
                color: colors.accent.withValues(
                  alpha: MileafChartMetrics.areaMaxOpacity,
                ),
                borderRadius: BorderRadius.circular(MileafRadius.xs),
              ),
            ),
            const SizedBox(width: MileafSpace.s4),
            Flexible(child: Text('日常波动范围（P10–P90）', style: style)),
          ],
        ),
      ],
    );
  }

  /// R29：绘图区右缘刻度、X 轴首中末刻度、1px 竖线加描边点选中；键盘左右
  /// 与语义增减选择月份。点按/拖动映射与绘制共用同一刻度尺。
  Widget _trendChart(
    BuildContext context,
    List<Map<String, dynamic>> rows, {
    required CalendarContext calendar,
    required bool large,
    required _RangeScale scale,
    required double axisPad,
  }) {
    void pick(double dx, double width) {
      final plotWidth = width - axisPad;
      if (plotWidth <= 0) return;
      setState(() {
        selected = (dx / plotWidth * rows.length).floor().clamp(
          0,
          rows.length - 1,
        );
      });
    }

    return Semantics(
      container: true,
      label: '月续航走势图表，横向拖动或键盘左右键选择月份',
      onIncrease: selected < rows.length - 1
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
              selected < rows.length - 1) {
            setState(() => selected++);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MileafFocusRing(
          child: LayoutBuilder(
            builder: (context, box) => GestureDetector(
              onTapDown: (p) => pick(p.localPosition.dx, box.maxWidth),
              onHorizontalDragUpdate: (p) =>
                  pick(p.localPosition.dx, box.maxWidth),
              child: SizedBox(
                // R06.3：专题主图200；大字240与U09c专题主图一致。
                height: large ? 240 : MileafSpace.detailChartHeight,
                width: double.infinity,
                child: CustomPaint(
                  key: const Key('range-observation-chart'),
                  size: Size(
                    box.maxWidth,
                    large ? 240 : MileafSpace.detailChartHeight,
                  ),
                  painter: _RangePainter(
                    rows,
                    selected.clamp(0, rows.length - 1),
                    context.colors,
                    calendar,
                    context.type.caption.copyWith(
                      color: context.colors.textFaint,
                    ),
                    MediaQuery.textScalerOf(context),
                    large,
                    scale,
                    axisPad,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// R25 专题骨架：身份块 → 结论卡 → 主图卡 → 样本明细 → 关于这些数据。
  @override
  Widget build(BuildContext context) {
    final c = widget.context;
    if (c.features['range_observations'] != true) {
      return StateView(
        kind: StateViewKind.empty,
        title: messages.unsupportedMessage('额定续航观察'),
        message: '站点未声明额定续航观察能力。',
      );
    }
    final d = data, totals = d?['totals'] as Map?;
    final rows = d == null
        ? <Map<String, dynamic>>[]
        : [
            for (final row in d['buckets'] as List)
              Map<String, dynamic>.from(row as Map),
          ];
    final compact = c.compact && !widget.expanded;
    final chosen = rows.isEmpty
        ? null
        : rows[selected.clamp(0, rows.length - 1)];
    final missingMonth = chosen == null || chosen['median_range_km'] is! num;
    final content = <Widget>[
      // 身份块：问题式标题 + 统计口径一句；刷新沿既有圆钮。
      SectionHeader(
        title: terms.ratedRange,
        action: MileafIconButton(
          icon: MileafIconName.refresh,
          tooltip: '刷新续航观察',
          onPressed: loading ? null : () => load(force: true),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: MileafSpace.s4),
        child: Text(
          '独立本地月窗口，逐月估算额定续航',
          style: context.type.subheadline.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ),
      if (loading) const MileafProgressLine(),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: MileafSpace.s8),
          child: InlineBanner(
            message: error!,
            tone: BannerTone.error,
            actionLabel: '重试',
            onAction: () => load(force: true),
          ),
        ),
      if (d != null && totals?['status'] == 'unsupported')
        StateView(
          kind: StateViewKind.empty,
          title: messages.unsupportedMessage('额定续航观察'),
        )
      else if (d != null && totals?['status'] == 'no_records')
        const StateView(
          kind: StateViewKind.empty,
          title: '观察窗口内没有充电记录',
          message: '换一个观察窗口，或继续记录充电。',
        )
      else if (d != null && totals?['status'] == 'insufficient_data')
        const StateView(
          kind: StateViewKind.empty,
          title: '尚无有效续航样本',
          message: '有效样本不足时不推算额定续航。',
        )
      else ...[
        // 结论卡：月中位数 metricLg + 必要限定（§6 第 2 步收紧内边到 12）。
        Padding(
          padding: const EdgeInsets.only(top: MileafSpace.s12),
          child: MileafModuleCard(
            padding: const EdgeInsets.all(MileafSpace.cardInset),
            child: MetricBlock(
              label: '月中位数',
              value: missingMonth ? null : value(chosen['median_range_km']),
              unit: 'km',
              scale: MetricValueScale.metricLg,
              note: missingMonth ? '暂无有效月样本' : '根据行程记录估算，不是电池健康检测',
              semanticLabel: _conclusionSemantics(chosen),
            ),
          ),
        ),
        // 主图卡：分段 → 读数头 → 绘图区与 X 轴 → 图例 → 限定脚注（R29）。
        Padding(
          padding: const EdgeInsets.only(top: MileafSpace.s12),
          child: MileafModuleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ChipRow(
                  children: [
                    for (final m in [6, 12])
                      StatusChip(
                        label: '$m个月',
                        selected: months == m,
                        onTap: () {
                          if (m != months) {
                            setState(() {
                              months = m;
                              data = null;
                            });
                            load();
                          }
                        },
                      ),
                  ],
                ),
                if (rows.isNotEmpty) ...[
                  const SizedBox(height: MileafSpace.s12),
                  Builder(
                    builder: (chartContext) {
                      final large = MileafLayout.largeText(context);
                      final axisStyle = context.type.caption.copyWith(
                        color: context.colors.textFaint,
                      );
                      final scale = _RangeScale(rows, large);
                      final axisPad = scale.axisPadFor(
                        axisStyle,
                        MediaQuery.textScalerOf(context),
                      );
                      final row = rows[selected.clamp(0, rows.length - 1)];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          MileafChartReadout(
                            sentence: _readoutSentence(row),
                            date: _monthHeading(row),
                            value: row['median_range_km'] is num
                                ? units.valueUnit(
                                    row['median_range_km'] as num,
                                    'km',
                                    decimals: 1,
                                  )
                                : '—',
                            contextLine: _readoutContext(row),
                            dateStyle: context.type.subheadline.copyWith(
                              color: context.colors.textSecondary,
                            ),
                            // R29：专题读数头数值用 metricSm（R21.3）。
                            valueStyle: context.type.metricSm.copyWith(
                              color: context.colors.text,
                            ),
                            // 第三行与完整读数头一致：footnote 小一号，单行读感。
                            contextStyle: context.type.footnote.copyWith(
                              color: context.colors.textSecondary,
                            ),
                            colors: context.colors,
                            type: context.type,
                            onPrevious: selected > 0
                                ? () => setState(() => selected--)
                                : null,
                            onNext: selected + 1 < rows.length
                                ? () => setState(() => selected++)
                                : null,
                          ),
                          const SizedBox(height: MileafSpace.s8),
                          _trendChart(
                            chartContext,
                            rows,
                            calendar: c.workspace.calendar!,
                            large: large,
                            scale: scale,
                            axisPad: axisPad,
                          ),
                          _legend(chartContext),
                          // R06.2：非零起点时可见标注轴范围起点。
                          if (scale.low > 0)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: MileafSpace.s4,
                              ),
                              child: Text(
                                '纵轴从 ${scale.low.toStringAsFixed(0)} km 起',
                                style: context.type.footnote.copyWith(
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        // 样本明细：证据事实沿共享组件（AP12a 签名冻结）。
        if (rows.isNotEmpty) ...[
          const SizedBox(height: MileafSpace.section),
          Builder(
            builder: (_) {
              final coverage =
                  (chosen?['coverage'] as Map?) ?? const <String, dynamic>{};
              final sparse = chosen?['sample_status'] == 'sparse';
              return StatisticsTopicFacts(
                facts: [
                  StatisticsTopicFact(
                    label: '有效天数',
                    value: coverage['valid_days']?.toString(),
                    unit: '天',
                    note: sparse ? '样本较少，仅供参考' : null,
                  ),
                  StatisticsTopicFact(
                    label: '有效会话',
                    value: coverage['valid_sessions']?.toString(),
                    unit: '次',
                  ),
                  StatisticsTopicFact(
                    label: '有效采样',
                    value: coverage['valid_points']?.toString(),
                    unit: '点',
                  ),
                  StatisticsTopicFact(
                    label: 'P10',
                    value: value(chosen?['p10_range_km']),
                    unit: 'km',
                  ),
                  StatisticsTopicFact(
                    label: 'P90',
                    value: value(chosen?['p90_range_km']),
                    unit: 'km',
                  ),
                ],
              );
            },
          ),
        ],
        _notes(context, rows),
      ],
    ];
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: content,
    );
    if (compact) return body;
    // R01：专题主体沿共享内容限宽560，与其他专题页一致；compact分支保留。
    return MileafContent(
      child: SingleChildScrollView(
        padding: MileafLayout.pagePadding(context, top: MileafSpace.s8),
        child: body,
      ),
    );
  }

  String _conclusionSemantics(Map? chosen) {
    if (chosen == null || chosen['median_range_km'] is! num) {
      return '暂无有效月样本，月中位数缺失';
    }
    final median = chosen['median_range_km'] as num;
    return '月中位数 ${median.toStringAsFixed(1)} ${units.semanticsUnit('km')}，根据行程记录估算，不是电池健康检测';
  }

  String _readoutSentence(Map row) {
    final heading = _monthHeading(row);
    if (row['median_range_km'] is! num) {
      return '$heading暂无有效样本，月中位数缺失，不补零';
    }
    final median = row['median_range_km'] as num;
    final km = units.semanticsUnit('km');
    final p10 = row['p10_range_km'];
    final p90 = row['p90_range_km'];
    final coverage = (row['coverage'] as Map?) ?? const <String, dynamic>{};
    return '$heading满电额定续航中位数 ${median.toStringAsFixed(1)} $km'
        '${p10 is num ? '，P10 ${p10.toStringAsFixed(1)} $km' : ''}'
        '${p90 is num ? '，P90 ${p90.toStringAsFixed(1)} $km' : ''}'
        '，有效天数 ${coverage['valid_days'] ?? 0} 天'
        '${row['sample_status'] == 'sparse' ? '，样本较少，仅供参考' : ''}';
  }

  String? _readoutContext(Map row) {
    final p10 = row['p10_range_km'], p90 = row['p90_range_km'];
    if (p10 is! num || p90 is! num) return null;
    return 'P10 ${units.valueUnit(p10, 'km', decimals: 1)}，'
        'P90 ${units.valueUnit(p90, 'km', decimals: 1)}';
  }

  /// R30：页尾「关于这些数据」五类；服务端原值只进技术详情（可复制）。
  Widget _notes(BuildContext context, List<Map<String, dynamic>> rows) {
    final d = data;
    final calendar = widget.context.workspace.calendar;
    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.section),
      child: MileafDataNotes(
        groups: [
          if (d != null) ...[
            const MileafDataNoteGroup(
              category: DataNoteCategory.caliber,
              note: '固定使用额定续航和仪表电量，同点电量 20–90%；先求单次充电中位数，再求每日中位数和月分位数。筛选阈值为首版产品规则，非显著性或健康检测标准。此窗口独立于首页期间；不代表 SOH、容量或衰减。',
            ),
            if (rows.isNotEmpty)
              MileafDataNoteGroup(
                category: DataNoteCategory.records,
                note: [
                  for (final row in rows)
                    '${copy.formatMonth(_local(row['bucket_start']), widget.context.workspace.session.now())}：有效天数 ${(row['coverage'] as Map?)?['valid_days'] ?? 0} 天、有效会话 ${(row['coverage'] as Map?)?['valid_sessions'] ?? 0} 次、有效采样 ${(row['coverage'] as Map?)?['valid_points'] ?? 0} 点',
                ].join('\n'),
              ),
            MileafDataNoteGroup(
              category: DataNoteCategory.time,
              note:
                  '所有时间按站点日历显示，统计时区 ${calendar?.identifier ?? '—'}；观察窗口为 $months 个独立本地月。',
            ),
            MileafDataNoteGroup(
              category: DataNoteCategory.source,
              note:
                  '查询生成于 ${copy.formatPrecise(_local(d['as_of']))}（非采样时间）${d['first_observed_at'] == null ? '' : '；窗口内首次有效采样 ${copy.formatPrecise(_local(d['first_observed_at']))}'}。首次有效采样仅限查询窗口，不是新车基线。',
            ),
            MileafDataNoteGroup(
              category: DataNoteCategory.technical,
              copyable: true,
              // copy-guard: technical — 算法版本与查询原值只在技术详情出现。
              note:
                  'method session-day-rated-range-v1 v1；range_kind rated；soc_source battery_level；time_basis ended_at；months $months；from ${d['query']['from']}；to ${d['query']['to']}；tz ${calendar?.identifier ?? '—'}',
            ),
          ],
        ],
      ),
    );
  }
}

/// 长期续航趋势的共享刻度尺：量程与刻度文本由数据决定，绘制与命中映射
/// 使用同一实例，避免轴留白与选月偏移分叉（对齐能耗条件点图的_BinScale）。
class _RangeScale {
  _RangeScale(List<Map<String, dynamic>> rows, bool largeText) {
    final values = [
      for (final r in rows)
        for (final k in const [
          'p10_range_km',
          'median_range_km',
          'p90_range_km',
        ])
          if (r[k] is num) (r[k] as num).toDouble(),
    ];
    if (values.isNotEmpty) {
      low = (values.reduce(math.min) / 10).floor() * 10.0 - 10;
      high = (values.reduce(math.max) / 10).ceil() * 10.0 + 10;
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

  double low = 0, high = 10, span = 10;
  late int tickCount;
  late List<String> tickTexts;

  /// R29：右侧留白按最长刻度宽 + 8，应用完整 TextScaler。
  double axisPadFor(TextStyle style, TextScaler scaler) {
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

  // R10：shouldRepaint 依赖值相等；同数据/同字号下跳过重绘。不引入新依赖。
  @override
  bool operator ==(Object other) =>
      other is _RangeScale &&
      other.low == low &&
      other.high == high &&
      other.tickCount == tickCount &&
      _listEquals(other.tickTexts, tickTexts);

  @override
  int get hashCode => Object.hash(low, high, tickCount, tickTexts.length);
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class _RangePainter extends CustomPainter {
  _RangePainter(
    this.rows,
    this.selected,
    this.colors,
    this.calendar,
    this.axisStyle,
    this.textScaler,
    this.largeText,
    this.scale,
    this.axisPad,
  );
  final List<Map<String, dynamic>> rows;
  final int selected;
  final MileafColors colors;
  final CalendarContext calendar;
  final TextStyle axisStyle;
  final TextScaler textScaler;
  final bool largeText;

  /// 与命中映射共享的刻度尺，保证点按位置与绘制槽位同源。
  final _RangeScale scale;

  /// R29：Y 轴刻度在绘图区右侧，绘图区让出该宽度。
  final double axisPad;

  TextPainter _measure(String text) => TextPainter(
    text: TextSpan(text: text, style: axisStyle),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final low = scale.low, span = scale.span;
    final tickPainters = [for (final text in scale.tickTexts) _measure(text)];
    // R29：X 轴首、中、末至多 3 个刻度；大字只留首末。
    final xLabels = largeText
        ? {0, rows.length - 1}
        : {0, ((rows.length - 1) / 2).round(), rows.length - 1};
    // R29：X 轴首、中、末至多 3 个刻度；大字只留首末。刻度文字按 CP04
    // DF9 月级（跨年带年），去重键用标签文本。
    final axisIndices = xLabels.where((i) => i >= 0 && i < rows.length).toList()
      ..sort();
    final xPainters = <int, (TextPainter, String)>{
      for (final i in axisIndices)
        i: () {
          final date = calendar.local(
            DateTime.parse(rows[i]['bucket_start'] as String),
          );
          final anchor = calendar.local(
            DateTime.parse(rows[rows.length - 1]['bucket_start'] as String),
          );
          final label = copy.formatAxisMonth(date, anchor);
          return (_measure(label), label);
        }(),
    };
    var xHeight = 0.0;
    for (final (painter, _) in xPainters.values) {
      if (painter.height > xHeight) xHeight = painter.height;
    }
    // R06.4：底部按实际行高 + 8；顶部留白给选中标记。
    final plotBottom = size.height - xHeight - MileafSpace.s8;
    final plotTop = MileafChartGrammar.selectionDot * 2 + MileafSpace.s4;
    final plotHeight = (plotBottom - plotTop).clamp(1.0, size.height);
    final plotWidth = size.width - axisPad;
    if (rows.isEmpty || plotWidth <= 0) {
      for (final (p, _) in xPainters.values) {
        p.dispose();
      }
      for (final p in tickPainters) {
        p.dispose();
      }
      return;
    }
    double x(int i) => (i + .5) * plotWidth / rows.length;
    double y(num n) => plotBottom - (n.toDouble() - low) / span * plotHeight;
    // R06.5：基线加至多3条轻细网格线，只有数据/选中线需要高对比。
    canvas.drawLine(
      Offset(0, plotBottom),
      Offset(plotWidth, plotBottom),
      Paint()..color = colors.line,
    );
    for (var i = 1; i < tickPainters.length; i++) {
      final value = low + span * i / (scale.tickCount - 1);
      final gridY = y(value);
      if (gridY >= plotTop) {
        canvas.drawLine(
          Offset(0, gridY),
          Offset(plotWidth, gridY),
          Paint()..color = colors.line,
        );
      }
    }
    // R29：Y 轴刻度文字在绘图区右侧。
    for (var i = 0; i < tickPainters.length; i++) {
      final value = low + span * i / (scale.tickCount - 1);
      final p = tickPainters[i];
      p.paint(
        canvas,
        Offset(plotWidth + MileafSpace.s4, y(value) - p.height / 2),
      );
    }
    // X 轴标签：同文本去重（CP04），再按相邻重叠跳过。
    var lastRight = double.negativeInfinity;
    var lastKey = '';
    for (final key in xPainters.keys.toList()..sort()) {
      final (p, text) = xPainters[key]!;
      if (text == lastKey) continue;
      final center = x(key);
      final left = (center - p.width / 2).clamp(0.0, plotWidth - p.width);
      // R06.3：轴标签以可读为先，与前一个重叠时跳过。
      if (left < lastRight + MileafSpace.s4) continue;
      p.paint(canvas, Offset(left, plotBottom + MileafSpace.s8));
      lastRight = left + p.width;
      lastKey = text;
    }
    bool known(int i) =>
        rows[i]['status'] == 'available' && rows[i]['median_range_km'] is num;
    bool adequate(int i) =>
        known(i) &&
        rows[i]['sample_status'] == 'adequate' &&
        rows[i]['p10_range_km'] is num &&
        rows[i]['p90_range_km'] is num;
    for (var i = 1; i < rows.length; i++) {
      if (adequate(i - 1) && adequate(i)) {
        final a = rows[i - 1], r = rows[i];
        final band = Path()
          ..moveTo(x(i - 1), y(a['p10_range_km'] as num))
          ..lineTo(x(i), y(r['p10_range_km'] as num))
          ..lineTo(x(i), y(r['p90_range_km'] as num))
          ..lineTo(x(i - 1), y(a['p90_range_km'] as num))
          ..close();
        canvas.drawPath(
          band,
          Paint()
            ..color = colors.accent.withValues(
              alpha: MileafChartMetrics.areaMaxOpacity,
            ),
        );
      }
      if (known(i - 1) && known(i)) {
        canvas.drawLine(
          Offset(x(i - 1), y(rows[i - 1]['median_range_km'] as num)),
          Offset(x(i), y(rows[i]['median_range_km'] as num)),
          Paint()
            ..color = colors.accent
            ..strokeWidth = MileafChartMetrics.lineStroke
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    // R29：选中为 1 逻辑像素竖线 + 半径 4 的 accent 点和 2 像素底色描边。
    final selection = selected.clamp(0, rows.length - 1);
    if (known(selection)) {
      final lineX = x(selection);
      canvas.drawLine(
        Offset(lineX, plotTop),
        Offset(lineX, plotBottom),
        Paint()
          ..color = colors.textSecondary
          ..strokeWidth = MileafChartGrammar.selectionLine,
      );
    }
    for (var i = 0; i < rows.length; i++) {
      if (!known(i)) continue;
      final point = Offset(x(i), y(rows[i]['median_range_km'] as num));
      if (i == selection) {
        canvas.drawCircle(
          point,
          MileafChartGrammar.selectionDot + MileafChartGrammar.selectionRing,
          Paint()..color = colors.surface,
        );
      }
      canvas.drawCircle(
        point,
        i == selection
            ? MileafChartGrammar.selectionDot
            : MileafChartMetrics.pointRadius,
        Paint()
          ..color = colors.accent
          ..style = adequate(i) ? PaintingStyle.fill : PaintingStyle.stroke
          ..strokeWidth = MileafChartMetrics.lineStroke,
      );
    }
    for (final (p, _) in xPainters.values) {
      p.dispose();
    }
    for (final p in tickPainters) {
      p.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant _RangePainter old) =>
      old.selected != selected ||
      old.rows != rows ||
      old.largeText != largeText ||
      old.textScaler != textScaler ||
      old.axisStyle != axisStyle ||
      old.scale != scale ||
      old.axisPad != axisPad;
}
