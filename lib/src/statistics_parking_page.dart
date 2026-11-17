import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'copy/dates.dart' as copy;
import 'copy/durations.dart' as durations;
import 'copy/labels.dart' as labels;
import 'copy/messages.dart' as messages;
import 'copy/terms.dart' as terms;
import 'copy/units.dart' as units;
import 'design/components/components.dart';
import 'design/icons.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';

import 'number_format.dart' as nf;
import 'reading_scope.dart';
import 'statistics_insights_page.dart';
import 'workspace.dart';
import 'parking_observations_contract.g.dart' as dto;

/// 状态四类共用一套键与名称（图例、占比条、表格行、语义同源）。
const _stateNames = <String, String>{
  'online': '在线',
  'asleep': '睡眠',
  'offline': '离线',
  'unknown': '未知',
};

/// 记录明细里的事件类型人话标签（原值保留在明细行内）。
const _eventTypes = <String, String>{'drive': '行车', 'charge': '充电'};

class ParkingObservationPage extends StatefulWidget {
  const ParkingObservationPage({
    super.key,
    required this.context,
    this.expanded = false,
  });
  final StatisticsInsightsContext context;
  final bool expanded;
  @override
  State<ParkingObservationPage> createState() => _ParkingObservationPageState();
}

class _ParkingObservationPageState extends State<ParkingObservationPage>
    with WidgetsBindingObserver {
  Map<String, dynamic>? data;
  final List<Map<String, dynamic>> items = [];
  String? cursor, error;
  bool busy = false;
  int sequence = 0, selected = 0;

  /// The owner is actually looking at this topic: its own route is on top and
  /// the statistics tab it lives in is the selected one.
  bool get readingNow =>
      ReadingScope.isActive(context) &&
      (ModalRoute.of(context)?.isCurrent ?? false);

  String get identity {
    final c = widget.context;
    return '${c.workspace.session.current?.generation}/${c.workspace.selectedId}/${c.workspace.calendar?.identifier}/${c.workspace.revision}/${c.window.from}/${c.window.to}/${c.window.bucket}/${c.features['parking_observations']}';
  }

  String get readingIdentity {
    final c = widget.context;
    return '${c.workspace.session.current?.generation}/${c.workspace.selectedId}/${c.workspace.calendar?.identifier}/${c.selection.period}/${c.selection.start}/${c.selection.end}';
  }

  late String loadedReadingIdentity;
  late String loadedIdentity;
  @override
  void initState() {
    super.initState();
    loadedIdentity = identity;
    loadedReadingIdentity = readingIdentity;
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void didUpdateWidget(covariant ParkingObservationPage old) {
    super.didUpdateWidget(old);
    // A hidden or covered topic records nothing and reads nothing; the next
    // visible rebuild picks the change up.
    if ((loadedIdentity != identity ||
            loadedReadingIdentity != readingIdentity) &&
        readingNow) {
      loadedIdentity = identity;
      if (loadedReadingIdentity != readingIdentity) {
        data = null;
        selected = 0;
      }
      loadedReadingIdentity = readingIdentity;
      items.clear();
      cursor = null;
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
    if (state == AppLifecycleState.resumed && mounted && readingNow) load();
  }

  Future<void> load({bool more = false, bool force = false}) async {
    final c = widget.context,
        w = c.workspace,
        owner = c.workspace.session.current,
        id = c.workspace.selectedId,
        cal = c.workspace.calendar;
    if (owner == null ||
        id == null ||
        cal == null ||
        c.features['parking_observations'] != true) {
      return;
    }
    final ticket = ++sequence, captured = identity;
    bool valid() =>
        mounted &&
        ticket == sequence &&
        captured == identity &&
        w.session.isCurrent(owner);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final query = c.window.query('parking', cal)..remove('kind');
      if (more && cursor != null) query['cursor'] = cursor!;
      final response = await w.cache.get(
        owner,
        'vehicles/$id/parking-observations',
        query: query,
        force: force,
      );
      final parsed = dto.ParkingObservations.fromJson(response.body),
          q = parsed.query;
      if (q.vehicleId != id ||
          q.tz != cal.identifier ||
          q.from != c.window.from ||
          q.to != c.window.to ||
          q.bucket != c.window.bucket ||
          q.timeBasis != 'window_start' ||
          parsed.method != 'closed-window-soc-v1' ||
          parsed.version != 1 ||
          parsed.validation != 'provisional' ||
          (response.body['query']['filters'] as Map?)?.isNotEmpty == true) {
        throw const FormatException('Parking context mismatch');
      }
      if (valid()) {
        setState(() {
          if (!more) {
            final oldRows = data?['buckets'] as List? ?? const [];
            final newRows = response.body['buckets'] as List;
            // Dates can repeat. Evidence values distinguish those rows, and
            // occurrence rank distinguishes otherwise identical observations.
            Object pointIdentity(dynamic row) => (
              row['bucket_start'],
              row['soc_change_pp'],
              row['soc_change_pp_per_24h'],
              row['observed_hours'],
              row['valid_windows'],
            );
            final picked = selected < oldRows.length
                ? pointIdentity(oldRows[selected])
                : null;
            final rank = oldRows
                .take(selected)
                .where((row) => pointIdentity(row) == picked)
                .length;
            final matches = [
              for (var i = 0; i < newRows.length; i++)
                if (pointIdentity(newRows[i]) == picked) i,
            ];
            selected = rank < matches.length ? matches[rank] : 0;
            data = response.body;
            items.clear();
          }
          items.addAll([
            for (final x in response.body['items'] as List)
              Map<String, dynamic>.from(x as Map),
          ]);
          cursor = parsed.nextCursor;
        });
      }
    } catch (_) {
      if (valid()) {
        setState(() {
          // CP07：分页失败与「失败有旧数据」走共享状态句；staleMessage 用
          // 本次读取时刻近似（错误路径没有独立时间戳）。
          error = more
              ? messages.paginationFailedMessage('停放记录')
              : data == null
              ? messages.readFailedMessage('停放观察')
              : messages.staleMessage(
                  _local(data?['as_of']),
                  c.workspace.session.now(),
                );
        });
      }
    } finally {
      if (valid()) setState(() => busy = false);
    }
  }

  String n(Object? x) => x is num ? x.toStringAsFixed(1) : '—';

  /// CP03：小时数转时长读法（12.0 h → 12 小时）。
  String hours(Object? x) {
    if (x is! num) return '—';
    return durations.duration(
      Duration(milliseconds: (x * Duration.millisecondsPerHour).round()),
    );
  }

  /// CP03/CP02：电量变化读法，真负号 + 个百分点，不用 pp。
  String ppValue(Object? x) =>
      x is num ? units.valueUnit(x, terms.percentagePoint, decimals: 1) : '—';

  /// R02/R09：站点日历本地时间。
  DateTime _local(Object? iso) {
    final parsed = iso is String ? DateTime.tryParse(iso) : null;
    final calendar = widget.context.workspace.calendar;
    if (parsed == null || calendar == null) {
      return widget.context.workspace.session.now();
    }
    return calendar.local(parsed);
  }

  /// P11/R09：排除原因不输出 map 字面量；原值经 CP10 人话标签，逐项计段。
  String? excludedReasons(Object? reasons) {
    if (reasons is! Map || reasons.isEmpty) return null;
    return [
      for (final e in reasons.entries)
        '${labels.exclusionReasonLabel('${e.key}')} ${e.value} 段',
    ].join('、');
  }

  /// P11：窗口统计人话标签（候选/未计入/尚未结束）。
  String windowSummary(Map? t) {
    if (t == null) return '—';
    final candidate = t['candidate_windows'],
        excluded = t['excluded_windows'],
        open = t['open_windows'];
    final parts = [
      '共 ${candidate ?? '—'} 段',
      if (excluded is num && excluded > 0) '未计入 $excluded 段',
      if (open is num && open > 0) '尚未结束 $open 段',
    ];
    return parts.join('，');
  }

  /// R06.10：状态时间分布。在线实色，睡眠中性实色+斜线，离线中性实色+
  /// 点纹，未知空底+描边；窄片段按真实比例，不设最小宽，靠图例辨识。
  Widget stateDistribution(BuildContext context, Map totals) {
    final colors = context.colors;
    final names = _stateNames;
    final segments = <(String, String, double?)>[
      for (final MapEntry(:key, :value) in names.entries)
        (
          key,
          value,
          totals['${key}_share'] is num
              ? (totals['${key}_share'] as num).toDouble()
              : null,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 图例与条使用同一套编码绘制；纹理来自Painter，不新增素材。
        Wrap(
          spacing: MileafSpace.s16,
          runSpacing: MileafSpace.s4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final MapEntry(:key, :value) in _stateNames.entries)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 10,
                    child: CustomPaint(
                      painter: _StateSegmentPainter(
                        key,
                        colors,
                        MileafRadius.xsAll,
                      ),
                    ),
                  ),
                  const SizedBox(width: MileafSpace.s4),
                  // R03：大字下图例文字换行重排，色样固定，不横向溢出。
                  Flexible(
                    child: Text(
                      value,
                      style: context.type.label.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: MileafSpace.s8),
        Semantics(
          container: true,
          label: '停车时状态占比条，${_stateSemantics(totals)}；编码见图例。',
          child: SizedBox(
            key: const Key('parking-state-bar'),
            height: 18,
            child: LayoutBuilder(
              builder: (context, box) {
                // R06.10：宽度按观测小时占比直接映射；share 缺失时留空，
                // 不把缺失份额摊给其他类别（Expanded 归一会伪造比例）。
                return Row(
                  children: [
                    for (final (key, _, share) in segments)
                      if (share != null && share > 0)
                        SizedBox(
                          width:
                              share.clamp(0.0, 1.0).toDouble() * box.maxWidth,
                          child: CustomPaint(
                            painter: _StateSegmentPainter(key, colors, null),
                            child: const SizedBox.expand(),
                          ),
                        ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: MileafSpace.s4),
        // P11：状态、时长、占比的表格行；share 缺失显示 —，不补 0%。
        MileafGroupCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, (key, name, share)) in segments.indexed)
                MileafGroupRow(
                  title: name,
                  meta: hours(totals['${key}_hours']),
                  value: share == null
                      ? '—'
                      : '${(share * 100).toStringAsFixed(1)}%',
                  topLine: index > 0,
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _stateSemantics(Map totals) => [
    for (final MapEntry(:key, :value) in _stateNames.entries)
      '$value ${hours(totals['${key}_hours'])}，占比 ${totals['${key}_share'] is num ? ((totals['${key}_share'] as num) * 100).toStringAsFixed(1) : '—'}%',
  ].join('；');

  /// R29：读数头在绘图区之上；步进圆钮替代文字按钮；缺失值不补零、口径就近。
  Widget _readout(BuildContext context, Map row) {
    final colors = context.colors;
    final type = context.type;
    final missing = row['soc_change_pp'] is! num;
    return MileafChartReadout(
      sentence: _readoutSentence(row),
      date: copy.formatDay(
        _local(row['bucket_start']),
        widget.context.workspace.session.now(),
      ),
      value: missing ? '—' : ppValue(row['soc_change_pp']),
      contextLine: missing
          ? '缺失，不补零'
          : '折合每天 ${ppValue(row['soc_change_pp_per_24h'])}，观测 ${hours(row['observed_hours'])}',
      dateStyle: type.subheadline.copyWith(color: colors.textSecondary),
      // R29：专题读数头数值用 metricSm（R21.3）。
      valueStyle: type.metricSm.copyWith(color: colors.text),
      contextStyle: type.subheadline.copyWith(color: colors.textSecondary),
      colors: colors,
      type: type,
      onPrevious: selected > 0 ? () => setState(() => selected--) : null,
      onNext: selected + 1 < ((data?['buckets'] as List?)?.length ?? 0)
          ? () => setState(() => selected++)
          : null,
    );
  }

  String _readoutSentence(Map row) {
    final date = copy.formatDay(
      _local(row['bucket_start']),
      widget.context.workspace.session.now(),
    );
    if (row['soc_change_pp'] is! num) {
      return '$date停车电量变化缺失，不补零';
    }
    return '$date停车电量变化 ${ppValue(row['soc_change_pp'])}'
        '${row['soc_change_pp_per_24h'] is num ? '，折合每天 ${ppValue(row['soc_change_pp_per_24h'])}' : ''}${row['observed_hours'] is num ? '，观测 ${hours(row['observed_hours'])}' : ''}';
  }

  /// R25 专题骨架：身份块 → 结论卡 → 主图卡 → 停车时状态 → 停车记录 →
  /// 关于这些数据。
  @override
  Widget build(BuildContext context) {
    final c = widget.context,
        d = data,
        t = d?['totals'] as Map?,
        compact = c.compact && !widget.expanded;
    if (c.features['parking_observations'] != true) {
      return StateView(
        kind: StateViewKind.empty,
        title: messages.unsupportedMessage('停放观察'),
      );
    }
    final rows = [
      if (d != null)
        for (final x in d['buckets'] as List)
          Map<String, dynamic>.from(x as Map),
    ];
    final totalMissing = t == null || t['soc_change_pp'] is! num;
    final allBucketsMissing =
        rows.isNotEmpty && rows.every((row) => row['soc_change_pp'] == null);
    final reasons = excludedReasons(t?['excluded_by_reason']);
    final content = <Widget>[
      // 身份块：问题式标题 + 统计口径一句；刷新沿既有圆钮。
      SectionHeader(
        title: terms.parkingSocChange,
        action: MileafIconButton(
          icon: MileafIconName.refresh,
          tooltip: '刷新停放观察',
          onPressed: busy ? null : () => load(force: true),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: MileafSpace.s4),
        child: Text(
          '统计有效停车窗口，按窗口开始时间归期',
          style: context.type.subheadline.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      ),
      if (busy) const MileafProgressLine(),
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
      // 结论卡：主值 metricLg + 不预测限定（§6 第 2 步收紧内边到 12）。
      Padding(
        padding: const EdgeInsets.only(top: MileafSpace.s12),
        child: MileafModuleCard(
          padding: const EdgeInsets.all(MileafSpace.cardInset),
          child: MetricBlock(
            value: totalMissing
                ? null
                : nf.applyMinusSign(n(t['soc_change_pp'])),
            unit: terms.percentagePoint,
            scale: MetricValueScale.metricLg,
            note: '只反映已记录的变化，不预测未来。',
            semanticLabel: _conclusionSemantics(t, totalMissing),
          ),
        ),
      ),
      if (t != null && totalMissing)
        Padding(
          padding: const EdgeInsets.only(top: MileafSpace.s4),
          child: Text(
            t['valid_windows'] == 0 ? '暂无有效停车窗口，无法判断电量变化' : '暂无有效窗口样本',
            style: context.type.footnote.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        )
      else if (t != null)
        Padding(
          padding: const EdgeInsets.only(top: MileafSpace.s4),
          child: Text(
            // P11/R08：总量上下文一句；无数据时按「—」呈现，不输出假值。
            '${t['valid_windows']} 段停车，共 ${hours(t['observed_hours'])}；折合每天 ${ppValue(t['soc_change_pp_per_24h'])}',
            style: context.type.subheadline.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
      // 主图卡：读数头 → 绘图区与 X 轴（R29）；全部缺失时保留说明不画零。
      if (!compact && rows.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: MileafSpace.s12),
          child: MileafModuleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MileafGroupHeader(
                  title: '每段停车',
                  footnote: allBucketsMissing ? '分桶电量变化缺失，不补零' : null,
                ),
                const SizedBox(height: MileafSpace.s8),
                Builder(
                  builder: (chartContext) {
                    final large = MileafLayout.largeText(context);
                    final axisStyle = context.type.micro.copyWith(
                      color: context.colors.textFaint,
                    );
                    final scale = _ParkingScale(rows, large);
                    final axisPad = scale.axisPadFor(
                      axisStyle,
                      MediaQuery.textScalerOf(context),
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _readout(
                          context,
                          rows[selected.clamp(0, rows.length - 1)],
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
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      // 停车时状态：占比条 + 状态、时长、占比表格；分母说明进分组脚注。
      if (!compact && t != null)
        Padding(
          padding: const EdgeInsets.only(top: MileafSpace.s12),
          child: MileafModuleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MileafGroupHeader(
                  title: '停车时状态',
                  footnote:
                      '按有效停车时长计算占比${t['observed_hours'] is num && (t['observed_hours'] as num) <= 0 ? '，暂无观测小时' : ''}',
                ),
                const SizedBox(height: MileafSpace.s8),
                stateDistribution(context, Map<String, dynamic>.from(t)),
                const SizedBox(height: MileafSpace.s8),
                Text(
                  windowSummary(t),
                  style: context.type.footnote.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                if (reasons != null)
                  Padding(
                    padding: const EdgeInsets.only(top: MileafSpace.s4),
                    child: Text(
                      '未计入原因：$reasons',
                      style: context.type.footnote.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      _records(context),
      // 分页游标存在时给出加载更多；分页语义沿既有 S 边界。
      if (cursor != null)
        Padding(
          padding: const EdgeInsets.only(top: MileafSpace.s4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: busy ? null : () => load(more: true),
              child: const Text('加载更多停车记录'),
            ),
          ),
        ),
      _notes(context),
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

  String _conclusionSemantics(Map? t, bool totalMissing) {
    if (totalMissing) return '暂无有效窗口样本，停车电量变化缺失，不补零';
    return '停车电量变化 ${nf.applyMinusSign(n(t!['soc_change_pp']))} ${terms.percentagePoint}，折合每天 ${ppValue(t['soc_change_pp_per_24h'])}，只反映已记录的变化，不预测未来';
  }

  /// P11：停车记录逐行明细保留原位折叠（R30.3 内容类）；行标题用人话标签。
  Widget _records(BuildContext context) {
    final d = data;
    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.s12),
      child: MileafGroupCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MileafSpace.cardPad,
                MileafSpace.s12,
                MileafSpace.cardPad,
                0,
              ),
              child: MileafGroupHeader(
                title: terms.parkingRecord,
                footnote:
                    '已载入 ${items.length} 条记录，匹配 ${d?['matched_windows'] ?? '—'} 段；匹配数不等于有效数',
              ),
            ),
            for (final (index, row) in items.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MileafSpace.cardPad,
                ),
                child: MileafDisclosure(
                  label: labels.parkingQualityLabel('${row['quality']}'),
                  meta: _recordMeta(row),
                  topLine: index > 0,
                  child: _recordDetail(row),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 记录行元信息：窗口起止按站点日历本地时间显示（CP04）。
  String _recordMeta(Map row) {
    final start = _local(row['window_start']);
    final now = widget.context.workspace.session.now();
    final end = row['window_end'];
    if (end == null) {
      return '${copy.formatDay(start, now)} 起，开放尾段，无最终变化';
    }
    return '${copy.formatDayTime(start, now)}–${copy.formatTime(_local(end))}';
  }

  /// 逐行明细：观测原值就近可查；事件类型与来源等原值保留在折叠明细内。
  Widget _recordDetail(Map row) {
    final excluded = row['exclusion_reason'];
    final missing = row['soc_change_pp'] == null;
    const lineStyle = TextStyle(height: 1.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('编号 ${row['window_id']}', style: lineStyle),
        Text(
          '持续 ${hours(row['duration_hours'])}，变化 ${ppValue(row['soc_change_pp'])}，折合每天 ${ppValue(row['soc_change_pp_per_24h'])}${missing ? '（缺失，不补零）' : ''}',
          style: lineStyle,
        ),
        if (excluded != null)
          Text(
            '未计入原因：${labels.exclusionReasonLabel('$excluded')}',
            style: lineStyle,
          ),
        Text(
          '里程变化 ${n(row['odometer_change_km'])} km${row['negative_odometer_change'] == true ? '，里程表读数回退' : ''}',
          style: lineStyle,
        ),
        for (final edge in ['start', 'end'])
          Text(
            '${edge == 'start' ? '起点' : '终点'} ${_eventType(row['${edge}_event'])}，${row[edge]['raw_time'] == null ? '时间缺失' : copy.formatDayTime(_local(row[edge]['raw_time']), widget.context.workspace.session.now())}，电量 ${row[edge]['soc'] ?? '—'}%（${row[edge]['soc_source'] ?? '缺失'}），里程 ${row[edge]['odometer_km'] ?? '—'} km（${row[edge]['odometer_source'] ?? '缺失'}），位置 ${row[edge]['position_id'] ?? '—'}',
            style: lineStyle,
          ),
        for (final MapEntry(:key, :value) in _stateNames.entries)
          Text('$value ${hours(row['${key}_hours'])}', style: lineStyle),
      ],
    );
  }

  String _eventType(Object? event) => event is Map && event['type'] is String
      ? (_eventTypes[event['type']] ?? event['type'])
      : '未知事件';

  /// R30：页尾「关于这些数据」五类；服务端原值只进技术详情（可复制）。
  Widget _notes(BuildContext context) {
    final c = widget.context, d = data;
    final calendar = c.workspace.calendar;
    return Padding(
      padding: const EdgeInsets.only(top: MileafSpace.section),
      child: MileafDataNotes(
        groups: [
          const MileafDataNoteGroup(
            category: DataNoteCategory.caliber,
            note: '按窗口开始时间归期；闭合结束可晚于查询结束，但已发生且不晚于查询生成时间。不裁切或分摊SOC。精确事件边界取值，持续 ≥1 小时，绝对里程差 <1 km。状态仅代表记录，不归因车辆功能；离线不等于睡眠，开放状态归未知。状态记录不完整的窗口仍计入统计。',
          ),
          MileafDataNoteGroup(
            category: DataNoteCategory.records,
            note:
                '窗口先按候选、未计入与尚未结束统计，未计入原因逐项列出；开放窗口没有最终变化。已载入 ${items.length} 条记录，匹配 ${d?['matched_windows'] ?? '—'} 段；匹配数不等于有效数。',
          ),
          MileafDataNoteGroup(
            category: DataNoteCategory.time,
            note: '所有时间按站点日历显示，统计时区 ${calendar?.identifier ?? '—'}。',
          ),
          if (d != null)
            MileafDataNoteGroup(
              category: DataNoteCategory.source,
              note: '查询生成于 ${copy.formatPrecise(_local(d['as_of']))}。',
            ),
          if (d != null)
            MileafDataNoteGroup(
              category: DataNoteCategory.technical,
              copyable: true,
              // copy-guard: technical — 状态、算法版本与阈值原值只在技术详情。
              note:
                  'status ${d['status']}；method closed-window-soc-v1；validation provisional；thresholds ${d['thresholds'] ?? '默认：≥1h，绝对里程差<1km'}；from ${c.window.from}；to ${c.window.to}；bucket ${c.window.bucket}',
            ),
        ],
      ),
    );
  }

  /// R29/R06.3/R06.4：正负柱图沿专题200（大字240）；Y 轴刻度右置；X 轴
  /// 日期去重；点按/横拖映射与绘制共用同一刻度尺；键盘左右与语义增减选择
  /// 分桶。零基线居中，负值保留负轴，null 留槽不补零。
  Widget _trendChart(
    BuildContext context,
    List<Map<String, dynamic>> rows, {
    required CalendarContext calendar,
    required bool large,
    required _ParkingScale scale,
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
      label: '每段停车电量变化正负柱图，横向拖动或键盘左右键选择分桶',
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
                // R06.3：专题主图200；大字240沿U09b/c/d专题主图先例。
                height: large ? 240 : MileafSpace.detailChartHeight,
                width: double.infinity,
                child: CustomPaint(
                  key: const Key('parking-trend-chart'),
                  size: Size(
                    box.maxWidth,
                    large ? 240 : MileafSpace.detailChartHeight,
                  ),
                  painter: _ParkingPainter(
                    rows,
                    selected.clamp(0, rows.length - 1),
                    calendar,
                    context.colors,
                    context.type.micro.copyWith(
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
}

/// 停放正负柱图的共享刻度尺：对称量程由数据决定，绘制与命中映射使用同一
/// 实例，避免轴留白与选桶偏移分叉（对齐长期续航的_RangeScale）。
class _ParkingScale {
  _ParkingScale(List<Map<String, dynamic>> rows, bool largeText) {
    final values = [
      for (final r in rows)
        if (r['soc_change_pp'] is num) (r['soc_change_pp'] as num).toDouble(),
    ];
    if (values.isNotEmpty) {
      final maxAbs = values.fold<double>(
        0,
        (m, v) => v.abs() > m ? v.abs() : m,
      );
      // 全零分桶也是合法输入（真实停放零变化）：量程下限 1，避免
      // log(0) 崩溃；零柱仍画在基线上。
      bound = _niceCeil(math.max(1.0, maxAbs));
    }
    span = bound * 2;
    // R06.4：大字减少刻度；两端与零基线保留，单位由就近说明承载。
    tickCount = largeText ? 2 : 3;
    tickTexts = [
      for (var i = 0; i < tickCount; i++)
        _tickText(-bound + span * i / (tickCount - 1)),
    ];
  }

  double bound = 1;
  late double span;
  late int tickCount;
  late List<String> tickTexts;

  /// 1/2/5×10^k 向上取整，保证柱零基线与量程不被夸大。
  static double _niceCeil(double v) {
    final magnitude = math
        .pow(10, (math.log(v) / math.ln10).floor())
        .toDouble();
    for (final m in const [1, 2, 5, 10]) {
      if (m * magnitude >= v) return m * magnitude;
    }
    return 10 * magnitude;
  }

  static String _tickText(double v) {
    final text = v == v.roundToDouble()
        ? v.abs().toStringAsFixed(0)
        : v.abs().toStringAsFixed(1);
    if (v == 0) return '0';
    return '${v > 0 ? '+' : '-'}$text';
  }

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

  // R10：shouldRepaint 依赖值相等；同数据/同字号下跳过重绘。
  @override
  bool operator ==(Object other) =>
      other is _ParkingScale &&
      other.bound == bound &&
      other.tickCount == tickCount &&
      _listEquals(other.tickTexts, tickTexts);

  @override
  int get hashCode => Object.hash(bound, tickCount, tickTexts.length);
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class _ParkingPainter extends CustomPainter {
  _ParkingPainter(
    this.rows,
    this.selected,
    this.calendar,
    this.colors,
    this.axisStyle,
    this.textScaler,
    this.largeText,
    this.scale,
    this.axisPad,
  );
  final List<Map<String, dynamic>> rows;
  final int selected;
  final CalendarContext calendar;
  final MileafColors colors;
  final TextStyle axisStyle;
  final TextScaler textScaler;
  final bool largeText;

  /// 与命中映射共享的刻度尺，保证点按位置与绘制槽位同源。
  final _ParkingScale scale;

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
    final bound = scale.bound, span = scale.span;
    final tickPainters = [for (final text in scale.tickTexts) _measure(text)];
    // R29：X 轴首、中、末至多 3 个刻度；大字只留首末。
    final xLabels = largeText
        ? {0, rows.length - 1}
        : {0, ((rows.length - 1) / 2).round(), rows.length - 1};
    final xPainters = <int, (TextPainter, String)>{
      for (final i in xLabels)
        if (i >= 0 && i < rows.length)
          i: () {
            final local = calendar.local(
              DateTime.parse(rows[i]['bucket_start'] as String),
            );
            // CP04：同日多桶去重；去重键带月日与时间粒度外的标记不必要，
            // 键直接用月-日文本（同日才可能重键）。
            return (
              _measure('${local.month}/${local.day}'),
              '${local.month}-${local.day}',
            );
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
    // 对称量程：0 基线在绘图区垂直中点，正值向上、负值向下。
    double y(num v) =>
        plotBottom -
        ((v.toDouble() + bound) / span).clamp(0.0, 1.0) * plotHeight;
    final zeroY = y(0);
    // R06.5：基线加至多3条轻细网格线，只有数据/选中线需要高对比。
    canvas.drawLine(
      Offset(0, zeroY),
      Offset(plotWidth, zeroY),
      Paint()..color = colors.line,
    );
    for (final edge in [plotTop, plotBottom]) {
      if ((edge - zeroY).abs() > 1) {
        canvas.drawLine(
          Offset(0, edge),
          Offset(plotWidth, edge),
          Paint()..color = colors.line,
        );
      }
    }
    // R29：Y 轴刻度文字在绘图区右侧。
    for (var i = 0; i < tickPainters.length; i++) {
      final value = -bound + span * i / (scale.tickCount - 1);
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
    for (var i = 0; i < rows.length; i++) {
      final v = rows[i]['soc_change_pp'];
      if (v is! num) continue; // R06.8：null 留槽，不补零。
      // R06.5：普通柱宽上限12、端圆角2；槽位按真实比例，不设最小宽。
      final barWidth = math.min(12.0, plotWidth / rows.length * .6);
      final top = v >= 0 ? y(v) : zeroY;
      final bottom = v >= 0 ? zeroY : y(v);
      final rect = Rect.fromLTRB(
        x(i) - barWidth / 2,
        top,
        x(i) + barWidth / 2,
        bottom,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: Radius.circular(MileafRadius.xs),
          topRight: Radius.circular(MileafRadius.xs),
          bottomLeft: Radius.circular(MileafRadius.xs),
          bottomRight: Radius.circular(MileafRadius.xs),
        ),
        Paint()..color = colors.accent,
      );
      final point = Offset(x(i), y(v));
      if (i == selected) {
        canvas.drawCircle(
          point,
          MileafChartGrammar.selectionDot + MileafChartGrammar.selectionRing,
          Paint()..color = colors.surface,
        );
      }
      canvas.drawCircle(
        point,
        i == selected
            ? MileafChartGrammar.selectionDot
            : MileafChartMetrics.pointRadius,
        Paint()..color = colors.accent,
      );
    }
    // R29：选中补 1 逻辑像素竖线。
    final selection = selected.clamp(0, rows.length - 1);
    if (rows[selection]['soc_change_pp'] is num) {
      canvas.drawLine(
        Offset(x(selection), plotTop),
        Offset(x(selection), plotBottom),
        Paint()
          ..color = colors.textSecondary
          ..strokeWidth = MileafChartGrammar.selectionLine,
      );
    }
    for (final (p, _) in xPainters.values) {
      p.dispose();
    }
    for (final p in tickPainters) {
      p.dispose();
    }
  }

  /// build 每次重建 rows，恒等比较恒真会让 _ParkingScale 的值相等修复
  /// 失效；逐行比较绘制输入（日期槽位与数值），既正确又让同数据跳过重绘。
  bool rowsChanged(covariant _ParkingPainter old) {
    if (old.rows.length != rows.length) return true;
    for (var i = 0; i < rows.length; i++) {
      if (old.rows[i]['bucket_start'] != rows[i]['bucket_start'] ||
          old.rows[i]['soc_change_pp'] != rows[i]['soc_change_pp']) {
        return true;
      }
    }
    return false;
  }

  @override
  bool shouldRepaint(covariant _ParkingPainter old) =>
      old.selected != selected ||
      rowsChanged(old) ||
      old.largeText != largeText ||
      old.textScaler != textScaler ||
      old.axisStyle != axisStyle ||
      old.scale != scale ||
      old.axisPad != axisPad ||
      old.calendar != calendar;
}

/// R06.10 状态编码：在线实色（accent），睡眠中性实色+斜线，离线中性实色+
/// 点纹，未知空底+描边。纹理线1、间隔6；颜色取现有palette，不做新token。
class _StateSegmentPainter extends CustomPainter {
  _StateSegmentPainter(this.category, this.colors, this.radius);

  final String category;
  final MileafColors colors;
  final BorderRadius? radius;

  void paintRect(Canvas canvas, Rect rect) {
    final fill = switch (category) {
      'online' => colors.accent,
      'asleep' || 'offline' => colors.textFaint,
      _ => null,
    };
    final shape = radius == null
        ? RRect.fromRectAndRadius(rect, Radius.zero)
        : RRect.fromRectAndCorners(
            rect,
            topLeft: radius!.topLeft,
            topRight: radius!.topRight,
            bottomLeft: radius!.bottomLeft,
            bottomRight: radius!.bottomRight,
          );
    if (fill != null) {
      canvas.drawRRect(shape, Paint()..color = fill);
    } else {
      // 未知：空底+描边。
      canvas.drawRRect(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = colors.lineStrong,
      );
    }
    if (category == 'asleep' || category == 'offline') {
      // 纹理线1、间隔6，用画布底色把实色刻出纹理；点纹直径2。
      final texture = Paint()
        ..color = colors.canvas
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      if (category == 'asleep') {
        // 斜线：沿对角方向，水平间隔6。
        for (var dx = -rect.height; dx < rect.width; dx += 6) {
          canvas.drawLine(
            Offset(rect.left + dx, rect.bottom),
            Offset(rect.left + dx + rect.height, rect.top),
            texture,
          );
        }
      } else {
        for (var dx = 3.0; dx < rect.width; dx += 6) {
          for (var dy = 3.0; dy < rect.height; dy += 6) {
            canvas.drawCircle(
              Offset(rect.left + dx, rect.top + dy),
              1,
              texture,
            );
          }
        }
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    paintRect(canvas, Offset.zero & size);
  }

  @override
  bool shouldRepaint(covariant _StateSegmentPainter old) =>
      old.category != category || old.colors != colors || old.radius != radius;
}
