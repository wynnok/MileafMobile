import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design/components/components.dart';
import 'design/icons.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';

import 'reading_scope.dart';
import 'statistics_insights_page.dart';
import 'workspace.dart';
import 'parking_observations_contract.g.dart' as dto;

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
        setState(
          () => error = more
              ? '窗口证据读取失败'
              : '停放观察读取失败${data == null ? '' : '，保留上次结果'}',
        );
      }
    } finally {
      if (valid()) setState(() => busy = false);
    }
  }

  String n(Object? x) => x is num ? x.toStringAsFixed(1) : '—';

  /// 分桶起点按本地日历显示，不把服务端 ISO 原样贴进读数行。
  String stamp(Object? iso) => localStamp(iso);

  /// R02/R09：站点日历本地时间；withTime 用于窗口起止与查询生成。
  String localStamp(Object? iso, {bool withTime = false}) {
    final parsed = iso is String ? DateTime.tryParse(iso) : null;
    final calendar = widget.context.workspace.calendar;
    if (parsed == null || calendar == null) return '—';
    final local = calendar.local(parsed);
    final base = '${local.year}/${local.month}/${local.day}';
    if (!withTime) return base;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$base $hh:$mm';
  }

  /// R09：排除原因不输出 map 字面量；键为服务端枚举，落在说明层。
  String excludedReasons(Object? reasons) {
    if (reasons is! Map || reasons.isEmpty) return '无';
    return [for (final e in reasons.entries) '${e.key} ×${e.value}'].join('、');
  }

  String change(Map? x) =>
      '${n(x?['soc_change_pp'])} pp · ${n(x?['soc_change_pp_per_24h'])} pp/24h';

  /// P11/R06.10：状态时间分布。在线实色，睡眠中性实色+斜线，离线中性实色+
  /// 点纹，未知空底+描边；窄片段按真实比例，不设最小宽，靠图例辨识。
  Widget stateDistribution(BuildContext context, Map totals) {
    final colors = context.colors;
    const names = {
      'online': '在线',
      'asleep': '睡眠',
      'offline': '离线',
      'unknown': '未知',
    };
    final segments = <(String, double?)>[
      for (final e in names.entries)
        (
          e.value,
          totals['${e.key}_share'] is num
              ? (totals['${e.key}_share'] as num).toDouble()
              : null,
        ),
    ];
    final details = <String>[
      for (final e in names.entries)
        '${e.value} ${n(totals['${e.key}_hours'])} h · ${totals['${e.key}_share'] is num ? ((totals['${e.key}_share'] as num) * 100).toStringAsFixed(1) : '—'}%',
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
            for (final name in const ['在线', '睡眠', '离线', '未知'])
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 10,
                    child: CustomPaint(
                      painter: _StateSegmentPainter(
                        name,
                        colors,
                        MileafRadius.xsAll,
                      ),
                    ),
                  ),
                  const SizedBox(width: MileafSpace.s4),
                  // R03：大字下图例文字换行重排，色样固定，不横向溢出。
                  Flexible(
                    child: Text(
                      name,
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
          label: '状态时间分布条形图，${details.join('，')}；编码见图例。',
          child: SizedBox(
            height: 18,
            child: LayoutBuilder(
              builder: (context, box) {
                // R06.10：宽度按观测小时占比直接映射；share 缺失时留空，
                // 不把缺失份额摊给其他类别（Expanded 归一会伪造比例）。
                return Row(
                  children: [
                    for (final (name, share) in segments)
                      if (share != null && share > 0)
                        SizedBox(
                          width:
                              share.clamp(0.0, 1.0).toDouble() * box.maxWidth,
                          child: CustomPaint(
                            painter: _StateSegmentPainter(name, colors, null),
                            child: const SizedBox.expand(),
                          ),
                        ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: MileafSpace.s8),
        // R06.10：类别名、小时、百分比始终并列可查。
        for (final detail in details)
          Text(
            detail,
            style: context.type.body.copyWith(color: colors.textMuted),
          ),
      ],
    );
  }

  /// R06.6/R06.7：读值结构「日期 → 当前值+单位 → 标准化率 → 覆盖」，前后
  /// 按钮保留；缺失值不补零、口径就近。
  Widget reading(BuildContext context, Map row, int rowCount) {
    final colors = context.colors;
    final missing = row['soc_change_pp'] is! num;
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            stamp(row['bucket_start']),
            style: context.type.body.copyWith(color: colors.text),
          ),
          const SizedBox(height: MileafSpace.s4),
          Text(
            '变化 ${missing ? '—' : n(row['soc_change_pp'])} pp${missing ? '（缺失，不补零）' : ''}',
            style: context.type.body.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: MileafSpace.s4),
          Text(
            '标准化率 ${n(row['soc_change_pp_per_24h'])} pp/24h',
            style: context.type.body.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: MileafSpace.s4),
          Text(
            '有效窗口 ${row['valid_windows']} · 观测 ${n(row['observed_hours'])} h',
            style: context.type.micro.copyWith(color: colors.textMuted),
          ),
          // R01：读值到下钻动作8。
          const SizedBox(height: MileafSpace.s8),
          Wrap(
            children: [
              TextButton(
                onPressed: selected > 0
                    ? () => setState(() => selected--)
                    : null,
                child: const Text('前一点'),
              ),
              TextButton(
                onPressed: selected + 1 < rowCount
                    ? () => setState(() => selected++)
                    : null,
                child: const Text('后一点'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.context,
        d = data,
        t = d?['totals'] as Map?,
        compact = c.compact && !widget.expanded;
    if (c.features['parking_observations'] != true) {
      return const StateView(
        kind: StateViewKind.empty,
        title: '当前站点不支持停放观察',
        message: '站点未声明停放观察能力。',
      );
    }
    final rows = [
      if (d != null)
        for (final x in d['buckets'] as List)
          Map<String, dynamic>.from(x as Map),
    ];
    final totalMissing = t == null || t['soc_change_pp'] is! num;
    final content = <Widget>[
      SectionHeader(
        title: '有效窗口SOC变化',
        action: MileafIconButton(
          icon: MileafIconName.refresh,
          tooltip: '刷新停放观察',
          onPressed: busy ? null : () => load(force: true),
        ),
      ),
      if (busy) const MileafProgressLine(),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: MileafSpace.s8),
          child: InlineBanner(
            message: error!,
            tone: BannerTone.error,
            actionLabel: '重试停放观察',
            onAction: () => load(force: true),
          ),
        ),
      // P11/R02：同底主值 metricLg 36，单位百分点，pp 就近定义。MileafNumber
      // 缺失时自动降到 24 号「—」，不把缺失符号放大成主视觉。
      Text(
        'pp = SOC 百分点',
        style: context.type.micro.copyWith(color: context.colors.textMuted),
      ),
      const SizedBox(height: MileafSpace.s4),
      MileafNumber(
        value: totalMissing ? null : n(t['soc_change_pp']),
        unit: 'pp',
        scale: MetricValueScale.metricLg,
      ),
      const SizedBox(height: MileafSpace.s4),
      Text(
        // R08/G04：无数据时按「—」呈现，不输出「0」假值或存在性结论。
        '有效窗口 ${t?['valid_windows'] ?? '—'} · 观测 ${n(t?['observed_hours'])} h · 标准化率 ${n(t?['soc_change_pp_per_24h'])} pp/24h',
        style: context.type.body.copyWith(color: context.colors.textMuted),
      ),
      const SizedBox(height: MileafSpace.s4),
      Text(
        '正值回升、负值下降都只是观测变化；标准化率为已观测结果，不预测未来24小时。',
        style: context.type.micro.copyWith(color: context.colors.textMuted),
      ),
      if (totalMissing && t != null)
        Text(
          t['valid_windows'] == 0 ? '暂无有效窗口，不能判断SOC变化' : '暂无有效窗口样本',
          style: context.type.micro.copyWith(color: context.colors.textMuted),
        ),
      if (!compact && rows.isNotEmpty) ...[
        const SizedBox(height: MileafSpace.section),
        const SectionHeader(title: '停放SOC变化'),
        if (rows.every((row) => row['soc_change_pp'] == null))
          Padding(
            padding: const EdgeInsets.only(top: MileafSpace.s4),
            child: Text(
              '分桶SOC变化缺失，不补零',
              style: context.type.micro.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ),
        const SizedBox(height: MileafSpace.s8),
        Builder(
          builder: (chartContext) {
            final large = MileafLayout.largeText(context);
            final axisStyle = context.type.micro.copyWith(
              color: context.colors.textFaint,
            );
            final scale = _ParkingScale(rows, large);
            final leftPad = scale.leftPadFor(
              axisStyle,
              MediaQuery.textScalerOf(context),
            );
            return _trendChart(
              chartContext,
              rows,
              calendar: c.workspace.calendar!,
              large: large,
              scale: scale,
              leftPad: leftPad,
            );
          },
        ),
        const SizedBox(height: MileafSpace.s8),
        Builder(
          builder: (_) => reading(
            context,
            rows[selected.clamp(0, rows.length - 1)],
            rows.length,
          ),
        ),
      ],
      if (!compact && t != null) ...[
        const SizedBox(height: MileafSpace.section),
        const SectionHeader(title: '状态时间分布'),
        Padding(
          padding: const EdgeInsets.only(top: MileafSpace.s4),
          child: Text(
            // P11：分母严格为有效窗口观测小时；局部缺失不伪造全日状态。
            '分母为有效窗口观测小时${t['observed_hours'] is num && (t['observed_hours'] as num) <= 0 ? '，暂无观测小时' : ''}',
            style: context.type.micro.copyWith(color: context.colors.textMuted),
          ),
        ),
        const SizedBox(height: MileafSpace.s8),
        stateDistribution(context, Map<String, dynamic>.from(t)),
        const SizedBox(height: MileafSpace.s8),
        Text(
          '候选 ${t['candidate_windows']} · 排除 ${t['excluded_windows']} · 开放 ${t['open_windows']}',
          style: context.type.micro.copyWith(color: context.colors.textMuted),
        ),
        Text(
          '排除原因：${excludedReasons(t['excluded_by_reason'])}',
          style: context.type.micro.copyWith(color: context.colors.textMuted),
        ),
      ],
      Text(
        // R08：无数据时不输出「0」，按「—」呈现。
        '匹配窗口 ${d?['matched_windows'] ?? '—'} · 已载证据 ${items.length}（匹配数不等于有效数）',
        style: context.type.micro.copyWith(color: context.colors.textMuted),
      ),
      for (final row in items)
        ExpansionTile(
          title: Text(
            '${row['window_id']} · ${row['included'] == true ? '有效' : '未计入'} · ${row['quality']}',
          ),
          subtitle: Text(
            // R02/R09：窗口起止按站点日历本地时间显示。
            '${localStamp(row['window_start'], withTime: true)} → ${row['window_end'] == null ? '开放尾段，无最终变化' : localStamp(row['window_end'], withTime: true)}',
          ),
          children: [
            Text('持续 ${n(row['duration_hours'])} h · ${change(row)}'),
            Text(
              '排除：${row['exclusion_reason'] ?? '无'} · partial_state_coverage 表示部分状态覆盖，仍可有效',
            ),
            Text(
              '里程变化 ${n(row['odometer_change_km'])} km · 负里程诊断 ${row['negative_odometer_change']}',
            ),
            for (final edge in ['start', 'end'])
              Text(
                '${edge == 'start' ? '起点' : '终点'} 事件 ${row['${edge}_event']} · 时间 ${row[edge]['raw_time'] ?? '缺失'} · SOC ${row[edge]['soc'] ?? '—'}%（${row[edge]['soc_source'] ?? '缺失'}）· 里程 ${row[edge]['odometer_km'] ?? '—'} km（${row[edge]['odometer_source'] ?? '缺失'}）· 位置 ${row[edge]['position_id'] ?? '—'}',
              ),
            Text(
              '在线 ${n(row['online_hours'])} h · 睡眠 ${n(row['asleep_hours'])} h · 离线 ${n(row['offline_hours'])} h · 未知 ${n(row['unknown_hours'])} h',
            ),
          ],
        ),
      if (cursor != null)
        TextButton(
          onPressed: busy ? null : () => load(more: true),
          child: const Text('加载更多窗口'),
        ),
      // P11/R09：数据说明在章节尾部，位于证据列表与加载更多之后。
      ExpansionTile(
        title: const Text('数据说明'),
        children: [
          if (d != null)
            Text(
              // R02/R09：查询生成按站点日历本地时间显示。
              '状态：${d['status']} · 查询生成：${localStamp(d['as_of'], withTime: true)}',
            ),
          const Text(
            '按窗口开始时间归期；闭合结束可晚于查询结束，但已发生且不晚于查询生成时间。不裁切或分摊SOC。精确事件边界取值，持续≥1h，绝对里程差<1km。状态仅代表记录，不归因车辆功能；离线不等于睡眠，开放状态归未知。',
          ),
          Text(
            '方法 closed-window-soc-v1 · provisional · 阈值 ${d?['thresholds'] ?? '默认：≥1h，绝对里程差<1km'}',
          ),
        ],
      ),
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

  /// R06.3/R06.4/R06.7：正负柱图沿专题200（大字240）；轴文字应用完整
  /// TextScaler；点按/横拖映射与绘制共用同一刻度尺和轴留白；键盘左右与
  /// 语义增减选择分桶。零基线居中，负值保留负轴，null 留槽不补零。
  Widget _trendChart(
    BuildContext context,
    List<Map<String, dynamic>> rows, {
    required CalendarContext calendar,
    required bool large,
    required _ParkingScale scale,
    required double leftPad,
  }) {
    void pick(double dx, double width) {
      if (width <= leftPad) return;
      setState(() {
        selected = ((dx - leftPad) / (width - leftPad) * rows.length)
            .floor()
            .clamp(0, rows.length - 1);
      });
    }

    return Semantics(
      container: true,
      label: '停放SOC变化正负柱图，横向拖动或键盘左右键选择分桶',
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
                  context.type.micro.copyWith(color: context.colors.textFaint),
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
    this.leftPad,
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
  final double leftPad;

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
    // R06.4：大字减少X标签到首末；端点留白给选中标记。
    final xLabels = largeText
        ? {0, rows.length - 1}
        : {0, ((rows.length - 1) / 2).round(), rows.length - 1};
    final xPainters = <int, TextPainter>{
      for (final i in xLabels)
        if (i >= 0 && i < rows.length)
          i: _measure(() {
            final local = calendar.local(
              DateTime.parse(rows[i]['bucket_start'] as String),
            );
            return '${local.month}/${local.day}';
          }()),
    };
    var tickHeight = 0.0, xHeight = 0.0;
    for (final p in tickPainters) {
      if (p.height > tickHeight) tickHeight = p.height;
    }
    for (final p in xPainters.values) {
      if (p.height > xHeight) xHeight = p.height;
    }
    // R06.4：底部按实际行高 + 8；顶部留白给选中标记（halo 8 + 余量4）。
    final plotBottom = size.height - xHeight - MileafSpace.s8;
    final plotTop = MileafChartMetrics.currentHalo + MileafSpace.s4;
    final plotHeight = (plotBottom - plotTop).clamp(1.0, size.height);
    if (rows.isEmpty || size.width <= leftPad) {
      for (final p in [...tickPainters, ...xPainters.values]) {
        p.dispose();
      }
      return;
    }
    final plotWidth = size.width - leftPad;
    double x(int i) => leftPad + (i + .5) * plotWidth / rows.length;
    // 对称量程：0 基线在绘图区垂直中点，正值向上、负值向下。
    double y(num v) =>
        plotBottom -
        ((v.toDouble() + bound) / span).clamp(0.0, 1.0) * plotHeight;
    final zeroY = y(0);
    // R06.5：基线加至多3条轻细网格线，只有数据/选中线需要高对比。
    canvas.drawLine(
      Offset(leftPad, zeroY),
      Offset(size.width, zeroY),
      Paint()..color = colors.line,
    );
    for (final edge in [plotTop, plotBottom]) {
      if ((edge - zeroY).abs() > 1) {
        canvas.drawLine(
          Offset(leftPad, edge),
          Offset(size.width, edge),
          Paint()..color = colors.line,
        );
      }
    }
    for (var i = 0; i < tickPainters.length; i++) {
      final value = -bound + span * i / (scale.tickCount - 1);
      final p = tickPainters[i];
      p.paint(
        canvas,
        Offset(leftPad - MileafSpace.s4 - p.width, y(value) - p.height / 2),
      );
    }
    var lastRight = double.negativeInfinity;
    for (final entry in xPainters.entries) {
      final p = entry.value;
      final center = x(entry.key);
      final left = (center - p.width / 2).clamp(leftPad, size.width - p.width);
      // R06.3：轴标签以可读为先，与前一个重叠时跳过。
      if (left < lastRight + MileafSpace.s4) continue;
      p.paint(canvas, Offset(left, plotBottom + MileafSpace.s8));
      lastRight = left + p.width;
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
          MileafChartMetrics.currentHalo,
          Paint()..color = colors.accent.withValues(alpha: .2),
        );
      }
      canvas.drawCircle(
        point,
        i == selected
            ? MileafChartMetrics.currentPoint
            : MileafChartMetrics.pointRadius,
        Paint()..color = colors.accent,
      );
    }
    for (final p in [...tickPainters, ...xPainters.values]) {
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
      old.leftPad != leftPad ||
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
      '在线' => colors.accent,
      '睡眠' || '离线' => colors.textFaint,
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
    if (category == '睡眠' || category == '离线') {
      // 纹理线1、间隔6，用画布底色把实色刻出纹理；点纹直径2。
      final texture = Paint()
        ..color = colors.canvas
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      if (category == '睡眠') {
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
