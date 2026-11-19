import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'copy/dates.dart' as copy_dates;
import 'copy/messages.dart' as copy_msg;
import 'copy/state_feedback.dart';
import 'design/components/components.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'statistics_insights_page.dart';
import 'statistics_period.dart';

String usageValue(Object? value) => value is num
    ? value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)
    : '—';
Map<String, dynamic> usageMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<Map<String, dynamic>> usageItems(Object? value) =>
    value is List ? value.map(usageMap).toList() : [];

/// The evidence filter is supplied by the aggregate, never reconstructed from a page.
void openDrivingEvidence(
  BuildContext context,
  StatisticsInsightsContext source,
  Map<String, dynamic> filter, {
  String title = '行程证据',
  ValueChanged<int>? onRecord,
}) {
  Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => DrivingEvidencePage(
        source: source,
        filter: filter,
        title: title,
        onRecord: onRecord,
      ),
    ),
  );
}

/// One evidence fact on a statistics topic: label, number and unit.
class StatisticsTopicFact {
  const StatisticsTopicFact({
    required this.label,
    this.value,
    this.unit,
    this.note,
    this.hue,
  });
  final String label;
  final String? value;
  final String? unit;
  final String? note;

  /// CL01/CL12：这一格读数的数据域色相。缺省时由 [StatisticsTopicFacts]
  /// 的整组色相兜底，再缺省就是中性——缺失读数（「—」）永远中性（CL08）。
  final MileafHue? hue;
}

/// 样本明细卡（R25 专题骨架）：3–5 个证据事实，两列发丝分格、大字单列。
/// 证据事实仍是页面包语义，不再用「证据」当区块标题（CP02）。
class StatisticsTopicFacts extends StatelessWidget {
  const StatisticsTopicFacts({
    super.key,
    required this.facts,
    this.title = '样本明细',
    this.hue,
  });

  final List<StatisticsTopicFact> facts;
  final String title;

  /// CL12：整组读数的兜底色相（专题只有一个域时用它，避免逐格重复）。
  final MileafHue? hue;

  @override
  Widget build(BuildContext context) {
    if (facts.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final large = MileafLayout.largeText(context);
    Widget cell(
      StatisticsTopicFact fact, {
      required bool right,
      required bool bottom,
      bool second = false,
    }) => Container(
      padding: EdgeInsets.only(
        top: MileafSpace.s12,
        bottom: MileafSpace.s12,
        right: right ? MileafSpace.s12 : 0,
        left: second && !large ? MileafSpace.s12 : 0,
      ),
      decoration: BoxDecoration(
        border: Border(
          right: right ? BorderSide(color: colors.line) : BorderSide.none,
          bottom: bottom ? BorderSide(color: colors.line) : BorderSide.none,
        ),
      ),
      child: MetricBlock(
        label: fact.label,
        value: fact.value,
        unit: fact.unit,
        note: fact.note,
        // CL08：缺失读数不带色相（MetricBlock 只在有值时才把数字染成 strong）。
        hue: fact.value == null || fact.value == '—' ? null : fact.hue ?? hue,
        semanticLabel:
            '${fact.label} ${fact.value ?? '—'} ${fact.unit ?? ''}${fact.note == null ? '' : '，${fact.note}'}',
        scale: MetricValueScale.metricMd,
      ),
    );
    final blocks = <Widget>[];
    if (large) {
      for (var i = 0; i < facts.length; i++) {
        blocks.add(cell(facts[i], right: false, bottom: i < facts.length - 1));
      }
    } else {
      for (var i = 0; i < facts.length; i += 2) {
        final end = i + 1 >= facts.length;
        blocks.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: cell(
                  facts[i],
                  right: !end,
                  bottom: i + 2 < facts.length,
                ),
              ),
              if (!end)
                Expanded(
                  child: cell(
                    facts[i + 1],
                    right: false,
                    bottom: i + 2 < facts.length,
                    second: true,
                  ),
                ),
            ],
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: title),
        const SizedBox(height: MileafSpace.s8),
        MileafModuleCard(
          padding: const EdgeInsets.symmetric(horizontal: MileafSpace.s16),
          child: Column(children: blocks),
        ),
      ],
    );
  }
}

/// 说明行适配层（签名冻结，AP12b 仍在调用）：标签 + 默认折叠的说明内容。
/// 原实现直接使用 Material ExpansionTile（R30.3 已禁止），改为 MileafDisclosure。
class StatisticsTopicNotes extends StatelessWidget {
  const StatisticsTopicNotes({
    super.key,
    required this.children,
    this.title = '数据说明',
  });

  final List<Widget> children;
  final String title;

  @override
  Widget build(BuildContext context) => MileafDisclosure(
    label: title,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class StatisticsUsagePage extends StatefulWidget {
  const StatisticsUsagePage({super.key, required this.source, this.onRecord});
  final StatisticsInsightsContext source;
  final ValueChanged<int>? onRecord;
  @override
  State<StatisticsUsagePage> createState() => _StatisticsUsagePageState();
}

class _StatisticsUsagePageState extends State<StatisticsUsagePage> {
  Map<String, dynamic>? data, calendar;
  String? error, calendarError;
  int sequence = 0;
  bool loading = false;
  String? loadedScope;
  DateTime? selectedDay;
  String get scope =>
      '${identityHashCode(source.workspace.session.current)}:${source.workspace.selectedId}:${source.workspace.calendar?.identifier}:${source.window.from}:${source.window.to}';
  StatisticsInsightsContext get source => widget.source;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant StatisticsUsagePage old) {
    super.didUpdateWidget(old);
    if (loadedScope != scope) {
      data = null;
      calendar = null;
      selectedDay = null;
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
        zone = source.workspace.calendar!;
    if (owner == null || id == null) return;
    loadedScope = scope;
    final attempt = ++sequence, window = source.window;
    final query = {
      'from': window.from.toIso8601String(),
      'to': window.to.toIso8601String(),
      'tz': zone.identifier,
      'view': 'usage',
    };
    bool valid() =>
        mounted &&
        attempt == sequence &&
        ws.session.isCurrent(owner) &&
        ws.selectedId == id &&
        ws.calendar?.identifier == zone.identifier;
    setState(() {
      error = null;
      calendarError = null;
      loading = true;
    });
    try {
      final response = await ws.cache.get(
        owner,
        'vehicles/$id/driving-analysis',
        query: query,
        force: force,
      );
      if (valid()) setState(() => data = response.body);
    } catch (_) {
      if (valid()) setState(() => error = _failureNotice(data?['as_of']));
    }
    try {
      final response = await ws.cache.get(
        owner,
        'vehicles/$id/stats',
        query: {...window.query('driving', zone), 'bucket': 'day'},
        force: force,
      );
      if (valid()) setState(() => calendar = response.body);
    } catch (_) {
      if (valid()) {
        setState(() => calendarError = _failureNotice(calendar?['as_of']));
      }
    }
    if (valid()) setState(() => loading = false);
  }

  /// CP07/R31：失败且无旧数据说「没能读取…」；有旧数据说「没能更新，
  /// 显示的是 … 的数据」。快照原值只进技术详情，不进主界面。
  String _failureNotice(Object? asOf) {
    if (asOf is! String) return copy_msg.readFailedMessage('用车节奏');
    final at = DateTime.tryParse(asOf);
    if (at == null) return copy_msg.readFailedMessage('用车节奏');
    final zone = source.workspace.calendar!;
    return copy_msg.staleMessage(
      zone.local(at),
      zone.local(source.workspace.session.now()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (source.features['driving_analysis'] != true) {
      return const StateView(
        kind: StateViewKind.empty,
        title: '当前站点不支持用车节奏分析',
        message: '站点未声明用车节奏分析能力。',
      );
    }
    final d = data;
    final children = <Widget>[
      _identity(),
      if (loading && (data != null || calendar != null)) ...[
        const MileafProgressLine(),
        const Text('正在更新'),
      ],
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: MileafSpace.s12),
          child: _retryNotice(
            error!,
            tone: BannerTone.error,
            actionLabel: '重试用车节奏',
          ),
        ),
      if (d == null && calendarError != null && error == null)
        InlineBanner(message: calendarError!, tone: BannerTone.warning),
      if (d?['status'] == 'no_records')
        // MG09 空态分档：无数据档现状句与建议动作走共享构造。
        _empty(EmptyStateTier.noData, object: '已完成行程', message: '换一个期间或继续记录。')
      else if (d?['status'] == 'unsupported')
        // 能力缺失不属于四档原因，维持领域空态，不提供无效动作。
        const StateView(
          kind: StateViewKind.empty,
          title: '当前站点不支持用车节奏分析',
          message: '站点未声明用车节奏分析能力。',
        )
      else if (d != null) ...[
        _conclusion(d),
        _calendarSection(),
        _factsSection(d),
        _distanceSection(d),
        _weekdaySection(d),
        _dataNotes(d),
      ] else if (calendar != null)
        _calendarSection()
      else if (error == null)
        StateView(
          kind: StateViewKind.loading,
          title: copy_msg.loadingMessage('用车节奏'),
        ),
    ];
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
    return source.compact
        ? column
        : MileafContent(
            child: SingleChildScrollView(
              padding: MileafLayout.pagePadding(context, top: MileafSpace.s8),
              child: column,
            ),
          );
  }

  /// R25 专题骨架身份块：问题式标题 + 区间与统计口径一句；区间只在这里出现。
  Widget _identity() {
    final colors = context.colors;
    final type = context.type;
    final zone = source.workspace.calendar!;
    final first = zone.local(source.window.from);
    final last = zone.local(
      source.window.to.subtract(const Duration(microseconds: 1)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('用车节奏', style: type.title2.copyWith(color: colors.text)),
        const SizedBox(height: MileafSpace.s4),
        Text(
          '${copy_dates.formatRange(first, last)}，按开始日期统计',
          style: type.subheadline.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }

  /// MG09 空态四档分档：现状句与建议动作取自 `emptyStateCopy`（state_feedback），
  /// 下一步动作即原地强制刷新。
  Widget _empty(EmptyStateTier tier, {String? object, String? message}) {
    final copy = emptyStateCopy(tier, object: object);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StateView(
          kind: StateViewKind.empty,
          title: copy.status,
          message: message,
          actionLabel: copy.action,
          onAction: () => load(force: true),
        ),
      ],
    );
  }

  Widget _retryNotice(
    String message, {
    required BannerTone tone,
    required String actionLabel,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InlineBanner(message: message, tone: tone),
      Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          container: true,
          label: actionLabel,
          child: TextButton(
            onPressed: loading ? null : () => load(force: true),
            child: const Text('重试'),
          ),
        ),
      ),
    ],
  );

  /// P07 结论卡：主值 metricLg、一句上下文与必要限定。
  Widget _conclusion(Map<String, dynamic> d) {
    final colors = context.colors;
    final type = context.type;
    final activeDays = d['active_days'];
    final partial = d['partial_today'] == true;
    return MileafModuleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '用车 ',
                  style: type.body.copyWith(color: colors.textSecondary),
                ),
                TextSpan(
                  text: activeDays == null ? '—' : usageValue(activeDays),
                  style: (activeDays == null ? type.metricMd : type.metricLg)
                      .copyWith(color: colors.text),
                ),
                TextSpan(
                  text: ' 天',
                  style: type.body.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: MileafSpace.s4),
          Text(
            '共 ${usageValue(d['driving_distance_km'])} km，'
            '平均每个用车日 ${usageValue(d['distance_per_active_day_km'])} km',
            style: type.subheadline.copyWith(color: colors.textSecondary),
          ),
          if (activeDays == null)
            Text(
              '暂无活跃天数',
              style: type.footnote.copyWith(color: colors.textSecondary),
            ),
          if (partial)
            Text(
              '今天尚未结束',
              style: type.footnote.copyWith(color: colors.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _calendarSection() {
    final colors = context.colors;
    final type = context.type;
    final zone = source.workspace.calendar!;
    final byDate = {
      for (final bucket in usageItems(calendar?['buckets']))
        statisticsDate(
          zone.local(DateTime.parse(bucket['bucket_start'] as String)),
        ): bucket,
    };
    final first = zone.local(source.window.from);
    final last = zone.local(
      source.window.to.subtract(const Duration(microseconds: 1)),
    );
    // Civil dates are advanced before midnight conversion, including DST days.
    final buckets = <Map<String, dynamic>>[
      if (calendar != null)
        for (
          var date = DateTime.utc(first.year, first.month, first.day);
          !date.isAfter(DateTime.utc(last.year, last.month, last.day));
          date = date.add(const Duration(days: 1))
        )
          byDate[statisticsDate(date)] ??
              {'bucket_start': zone.midnight(date).toIso8601String()},
    ];
    // CP04 DF9：日历格日期走共享格式化器（首格与每月首格 M月D日，其余 D日）。
    final dayLabels = copy_dates.formatAxisDayTicks([
      for (final bucket in buckets)
        zone.local(DateTime.parse(bucket['bucket_start'] as String)),
    ], zone.local(source.workspace.session.now()));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (calendarError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: MileafSpace.s8),
            child: _retryNotice(
              calendarError!,
              tone: BannerTone.warning,
              actionLabel: '重试每日里程',
            ),
          ),
        if (buckets.isEmpty)
          Text(
            calendarError != null && calendar == null
                ? copy_msg.readFailedMessage('每日里程')
                : calendar == null
                ? copy_msg.loadingMessage('每日里程')
                : copy_msg.emptyMessage('每日里程'),
            style: type.body.copyWith(color: colors.textSecondary),
          )
        else ...[
          const SectionHeader(title: '每日里程'),
          const SizedBox(height: MileafSpace.s8),
          // P07 七列要求 ≥390 宽放下 7×44；卡内边 16 会吃掉可用宽，
          // 日历卡不用默认内边，图例与脚注单独给 16。不裁剪：模块卡的
          // 圆角裁剪会把首末格的外侧角变成点击死区（u09a 四角命中）。
          MileafGroupCard(
            padding: EdgeInsets.zero,
            clip: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // P07：七列（≥390 且 <150%）或四列日期矩阵；大字单列。日历离卡缘
                // 8（避免模块卡圆角吃掉首末格外侧角的点击），格距 2 保证 7 格
                // 每格 ≥44。
                // inline2：基线微调档（R24），为七列每格 ≥44 让位。
                const gap = MileafSpace.inline2;
                const inset = MileafSpace.s8;
                final large = MileafLayout.largeText(context);
                final seven =
                    !large &&
                    MediaQuery.sizeOf(context).width >=
                        MileafBreakpoints.wide &&
                    constraints.maxWidth - 2 * inset >=
                        7 * MileafSpace.touch + 6 * gap;
                final columns = large ? 1 : (seven ? 7 : 4);
                final inner = constraints.maxWidth - 2 * inset;
                final width = (inner - gap * (columns - 1)) / columns;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: inset),
                      child: Wrap(
                        key: const ValueKey('usage-daily-plot'),
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final (index, bucket) in buckets.indexed)
                            _dayCell(
                              bucket,
                              dayLabel: dayLabels[index],
                              width: width,
                              large: large,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: MileafSpace.s12),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MileafSpace.cardPad,
                      ),
                      child: Wrap(
                        spacing: MileafSpace.s12,
                        runSpacing: MileafSpace.s8,
                        children: [
                          for (final (value, label) in <(num?, String)>[
                            (0, '0 km'),
                            (1, '大于0且小于50 km'),
                            (50, '50至小于100 km'),
                            (100, '≥100 km'),
                            (null, '— 未知'),
                          ])
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _UsageSwatch(value: value),
                                const SizedBox(width: MileafSpace.s4),
                                Flexible(
                                  child: Text(
                                    label,
                                    style: type.footnote.copyWith(
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: MileafSpace.s4),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MileafSpace.cardPad,
                      ),
                      child: Text(
                        '缺日为未知，未来日期不补零。',
                        style: type.footnote.copyWith(color: colors.textMuted),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  /// P07 日历格：无描边框，按四档用填充加纹理区分；零显示 0、未知显示 —；
  /// 选中为 2 像素 accent 环；焦点仍用 accentStrong 描边（键盘可达）。
  Widget _dayCell(
    Map<String, dynamic> b, {
    required String dayLabel,
    required double width,
    required bool large,
  }) {
    final colors = context.colors;
    final type = context.type;
    final local = source.workspace.calendar!.local(
      DateTime.parse(b['bucket_start'] as String),
    );
    final km = b['distance_km'] as num?;
    final at = DateTime.parse(b['bucket_start'] as String);
    final selected = selectedDay == at;
    final fill = km == null
        ? colors.surface
        : km == 0
        ? colors.segmentTrack
        : colors.accentSoft;
    final label =
        '${local.month}月${local.day}日 ${km == null ? '未知里程' : '${usageValue(km)}公里'}';
    return Semantics(
      button: true,
      selected: selected,
      label: '$label，查看当天行程',
      excludeSemantics: true,
      onTap: () => _selectDay(at, local),
      child: SizedBox(
        width: width,
        child: TextButton(
          onPressed: () => _selectDay(at, local),
          style: ButtonStyle(
            animationDuration: Duration.zero,
            minimumSize: const WidgetStatePropertyAll(
              Size(MileafSpace.touch, MileafSpace.touch),
            ),
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(
                vertical: MileafSpace.s4,
                horizontal: large ? MileafSpace.s8 : 0,
              ),
            ),
            backgroundColor: WidgetStatePropertyAll(fill),
            shape: WidgetStateProperty.resolveWith((states) {
              // P07：格子无可见描边框（未选中描边与填充同色，纯为保住完整
              // 44×44 命中区）；选中为 2 像素 accent 环，焦点 accentStrong。
              final side = states.contains(WidgetState.focused)
                  ? BorderSide(color: colors.accentStrong, width: 2)
                  : selected
                  ? BorderSide(color: colors.accent, width: 2)
                  : BorderSide(color: fill, width: 1);
              return RoundedRectangleBorder(
                borderRadius: MileafRadius.mdAll,
                side: side,
              );
            }),
            overlayColor: WidgetStatePropertyAll(colors.pressOverlay),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dayLabel,
                style: type.caption.copyWith(color: colors.textSecondary),
              ),
              Text(
                '${usageValue(km)}${large ? ' km' : ''}',
                style: type.subheadline.copyWith(
                  color: colors.text,
                  fontWeight: MileafType.weightSemiBold,
                ),
              ),
              const SizedBox(height: MileafSpace.s4),
              _UsagePattern(value: km, color: colors.controlBorder),
            ],
          ),
        ),
      ),
    );
  }

  void _selectDay(DateTime at, DateTime local) {
    setState(() => selectedDay = at);
    _openDay(local);
  }

  void _openDay(DateTime local) {
    final date = DateTime.utc(local.year, local.month, local.day);
    openDrivingEvidence(
      context,
      source,
      {
        'from': source.workspace.calendar!.midnight(date).toIso8601String(),
        'to':
            source.workspace.calendar!
                .midnight(date, nextDays: 1)
                .isAfter(source.window.to)
            ? source.window.to.toIso8601String()
            : source.workspace.calendar!
                  .midnight(date, nextDays: 1)
                  .toIso8601String(),
        'tz': source.workspace.calendar!.identifier,
        'completed_only': true,
      },
      title: '${local.month}月${local.day}日的行程',
      onRecord: widget.onRecord,
    );
  }

  Widget _factsSection(Map<String, dynamic> d) => StatisticsTopicFacts(
    facts: [
      StatisticsTopicFact(
        label: '驾驶记录时长',
        value: usageValue(d['driving_duration_min']),
        unit: '分钟',
        note: _coverageNote(usageMap(d['coverage'])['duration']),
      ),
      StatisticsTopicFact(
        label: '每活跃日',
        value: usageValue(d['distance_per_active_day_km']),
        unit: 'km',
        note: _coverageNote(usageMap(d['coverage'])['distance']),
      ),
      StatisticsTopicFact(
        label: '单程中位数',
        value: usageValue(d['distance_p50_km']),
        unit: 'km',
        note: _coverageNote(usageMap(d['coverage'])['distance']),
      ),
      StatisticsTopicFact(
        label: '较长单程 P90',
        value: usageValue(d['distance_p90_km']),
        unit: 'km',
        note: _coverageNote(usageMap(d['coverage'])['distance']),
      ),
      StatisticsTopicFact(
        label: '平均速度',
        value: usageValue(d['mean_speed_kmh']),
        unit: 'km/h',
        note: _coverageNote(usageMap(d['coverage'])['speed']),
      ),
    ],
  );

  String _coverageNote(Object? value) {
    final coverage = usageMap(value);
    return '有效 ${usageValue(coverage['valid_count'])} 趟，排除 ${usageValue(coverage['excluded_count'])} 趟';
  }

  Widget _distanceSection(Map<String, dynamic> d) {
    final bins = usageItems(d['distance_bins']);
    if (bins.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: '短途、中途与长途'),
        const SizedBox(height: MileafSpace.s8),
        MileafGroupCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, b) in bins.indexed) ...[
                if (index > 0) _hairline(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MileafSpace.cardPad,
                  ),
                  child: MileafDataRow(
                    title:
                        '${usageValue(b['lower_km'])}–${b['upper_km'] == null ? '以上' : usageValue(b['upper_km'])} km',
                    meta:
                        '${usageValue(b['drives'])} 趟，${usageValue(b['distance_km'])} km\n'
                        '配对估算\n${_coverageNote(usageMap(b['coverage'])['paired'])}',
                    value: usageValue(b['consumption_wh_km']),
                    unit: 'Wh/km',
                    showChevron: b['evidence_filter'] is Map,
                    onTap: b['evidence_filter'] is Map
                        ? () => openDrivingEvidence(
                            context,
                            source,
                            usageMap(b['evidence_filter']),
                            onRecord: widget.onRecord,
                          )
                        : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// R24：发丝线只画在行与行之间，从卡内文字起始处到卡片右缘。
  Widget _hairline() => Container(
    height: 0,
    margin: const EdgeInsets.only(left: MileafSpace.cardPad),
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(
          color: context.colors.line,
          width: MileafStroke.hairline,
        ),
      ),
    ),
  );

  Widget _weekdaySection(Map<String, dynamic> d) {
    final bins = usageItems(d['weekday_bins']);
    if (bins.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final type = context.type;
    final max = bins.fold<double>(
      1,
      (m, b) => (b['distance_km'] as num? ?? 0) > m
          ? (b['distance_km'] as num).toDouble()
          : m,
    );
    final names = ['一', '二', '三', '四', '五', '六', '日'];
    final scaler = MediaQuery.textScalerOf(context);
    final barArea = MileafSpace.rhythmHeight;
    final available =
        math.min(
          MediaQuery.sizeOf(context).width,
          MileafBreakpoints.maxContent,
        ) -
        2 * MileafLayout.pageInset(context);
    final tooWide = bins.any((b) {
      final painter = TextPainter(
        text: TextSpan(
          text: usageValue(b['distance_km']),
          style: type.footnote,
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      final tooWide = painter.width + MileafSpace.s8 > available / bins.length;
      painter.dispose();
      return tooWide;
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: '一周的用车节奏'),
        const SizedBox(height: MileafSpace.s8),
        if (MileafLayout.largeText(context) || tooWide)
          for (final b in bins)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MileafSpace.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '周${names[((b['weekday'] as int) - 1).clamp(0, 6)]}  ${usageValue(b['distance_km'])} km',
                    style: type.body,
                  ),
                  const SizedBox(height: MileafSpace.s8),
                  LayoutBuilder(
                    builder: (context, constraints) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: b['distance_km'] == 0
                            ? MileafChartMetrics.barMaxWidth
                            : b['distance_km'] == null
                            ? 0
                            : (b['distance_km'] as num).clamp(0, max) /
                                  max *
                                  constraints.maxWidth,
                        height: b['distance_km'] == 0
                            ? 1
                            : MileafChartMetrics.barMaxWidth,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            )
        else ...[
          SizedBox(
            height:
                barArea +
                scaler.scale(MileafType.footnoteHeight) +
                MileafSpace.s4,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final b in bins)
                  Expanded(
                    child: Semantics(
                      label:
                          '周${names[((b['weekday'] as int) - 1).clamp(0, 6).toInt()]} '
                          '${usageValue(b['distance_km'])} 公里',
                      excludeSemantics: true,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            usageValue(b['distance_km']),
                            style: type.footnote.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: MileafSpace.s4),
                          Container(
                            width: MileafChartMetrics.barMaxWidth,
                            height: b['distance_km'] == 0
                                ? 1
                                : (b['distance_km'] as num? ?? 0).clamp(
                                        0,
                                        max,
                                      ) /
                                      max *
                                      barArea,
                            decoration: BoxDecoration(
                              color: colors.accent,
                              borderRadius: BorderRadius.circular(
                                MileafChartMetrics.barRadius,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(height: 1, color: colors.line),
          const SizedBox(height: MileafSpace.s4),
          Row(
            children: [
              for (final b in bins)
                Expanded(
                  child: Text(
                    '周${names[((b['weekday'] as int) - 1).clamp(0, 6).toInt()]}',
                    textAlign: TextAlign.center,
                    style: type.caption.copyWith(color: colors.textFaint),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: MileafSpace.s8),
        Text(
          '按开始日分组。星期分布仅供观察，不自动判断通勤。',
          style: type.footnote.copyWith(color: colors.textMuted),
        ),
        for (final b in bins)
          if (usageMap(usageMap(b['coverage'])['distance'])['excluded_count'] !=
              0)
            Text(
              '周${names[((b['weekday'] as int) - 1).clamp(0, 6)]} ${_coverageNote(usageMap(b['coverage'])['distance'])}',
              style: type.footnote,
            ),
      ],
    );
  }

  /// R30.2 页尾「关于这些数据」：口径、记录与缺失、时间、来源、技术详情。
  /// 服务端字段名、算法版本与快照原值只进技术详情（R30.4，可复制）。
  Widget _dataNotes(Map<String, dynamic> d) {
    final zone = source.workspace.calendar!;
    final coverageNames = <String, String>{
      'distance': '距离',
      'duration': '时长',
      'speed': '速度',
      'paired': '配对',
    };
    final records = StringBuffer(
      '候选 ${usageValue(usageMap(d['coverage'])['candidate_count'])} 趟，各指标有效集独立。',
    );
    for (final entry in usageMap(d['coverage']).entries) {
      if (entry.value is! Map) continue;
      final c = usageMap(entry.value);
      records.write(
        '${coverageNames[entry.key] ?? '部分指标'}：'
        '有效 ${usageValue(c['valid_count'])} 趟，排除 ${usageValue(c['excluded_count'])} 趟。',
      );
    }
    final asOf = DateTime.tryParse(d['as_of'] as String? ?? '');
    return MileafDataNotes(
      groups: [
        const MileafDataNoteGroup(
          category: DataNoteCategory.caliber,
          note: '按开始日归期；日桶来自服务端日聚合，不从单次行程重算。中位数与 P90 直接使用完整查询结果。',
        ),
        MileafDataNoteGroup(
          category: DataNoteCategory.records,
          note: records.toString(),
        ),
        if (asOf != null)
          MileafDataNoteGroup(
            category: DataNoteCategory.time,
            note:
                '统计截至 ${copy_dates.formatPrecise(zone.local(asOf))}；'
                '站点时区 ${zone.identifier}。',
          ),
        const MileafDataNoteGroup(
          category: DataNoteCategory.source,
          note: '由服务端用车分布接口汇总生成，不是车辆原始采样。',
        ),
        MileafDataNoteGroup(
          category: DataNoteCategory.technical,
          copyable: true,
          note:
              'method ${d['method'] ?? '—'}，version ${usageValue(d['version'])}，'
              'validation ${d['validation'] ?? '—'}，as_of ${d['as_of'] ?? '—'}。',
        ),
      ],
    );
  }
}

/// Redundant non-colour encoding shared by dates and their exact legend.
class _UsagePattern extends StatelessWidget {
  const _UsagePattern({required this.value, required this.color});
  final num? value;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: const Size(MileafSpace.s24, MileafSpace.s12),
      painter: _UsagePatternPainter(value, color),
    ),
  );
}

/// 图例色板：档位填充 + 同一套纹理（与格子的非颜色编码完全一致）。
class _UsageSwatch extends StatelessWidget {
  const _UsageSwatch({required this.value});
  final num? value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fill = value == null
        ? colors.surface
        : value == 0
        ? colors.segmentTrack
        : colors.accentSoft;
    return Container(
      width: MileafSpace.s24,
      height: MileafSpace.s12,
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: colors.line, width: MileafStroke.hairline),
        borderRadius: MileafRadius.xsAll,
      ),
      alignment: Alignment.center,
      child: _UsagePattern(value: value, color: colors.controlBorder),
    );
  }
}

class _UsagePatternPainter extends CustomPainter {
  /// 斜线纹理步距（原 inline6；图形绘制参数，非布局间距，本地化保留原值）。
  static const _hatchStep = 6.0;

  const _UsagePatternPainter(this.value, this.color);
  final num? value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // P07：格子无描边框，纹理只承担「同档内一致」的非颜色编码。
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final bounds = (Offset.zero & size).deflate(.5);
    canvas.save();
    canvas.clipRect(bounds);
    if (value == null) {
      canvas.drawLine(bounds.topLeft, bounds.bottomRight, paint);
      canvas.drawLine(bounds.bottomLeft, bounds.topRight, paint);
    } else if (value! > 0 && value! < 50) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
    } else if (value! >= 50) {
      for (var x = -size.height; x < size.width; x += _hatchStep) {
        canvas.drawLine(
          Offset(x, size.height),
          Offset(x + size.height, 0),
          paint,
        );
        if (value! >= 100) {
          canvas.drawLine(
            Offset(x, 0),
            Offset(x + size.height, size.height),
            paint,
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_UsagePatternPainter oldDelegate) =>
      value != oldDelegate.value || color != oldDelegate.color;
}

class DrivingEvidencePage extends StatefulWidget {
  const DrivingEvidencePage({
    super.key,
    required this.source,
    required this.filter,
    required this.title,
    this.onRecord,
  });
  final StatisticsInsightsContext source;
  final Map<String, dynamic> filter;
  final String title;
  final ValueChanged<int>? onRecord;
  @override
  State<DrivingEvidencePage> createState() => _DrivingEvidencePageState();
}

class _DrivingEvidencePageState extends State<DrivingEvidencePage> {
  List<Map<String, dynamic>> items = [];
  String? cursor, error;
  num? matched;
  bool loading = false, invalid = false;
  late final Object? ownerSnapshot;
  late final int? vehicleSnapshot;
  late final String? zoneSnapshot;
  void changed() {
    final ws = widget.source.workspace;
    if (!identical(ownerSnapshot, ws.session.current) ||
        vehicleSnapshot != ws.selectedId ||
        zoneSnapshot != ws.calendar?.identifier) {
      if (mounted) {
        setState(() {
          invalid = true;
          sequence++;
          items = [];
          loading = false;
        });
      }
    }
  }

  int sequence = 0;
  late final Map<String, String> query = {
    for (final e in widget.filter.entries)
      if (e.value != null) e.key: e.value.toString(),
  };
  @override
  void initState() {
    super.initState();
    ownerSnapshot = widget.source.workspace.session.current;
    vehicleSnapshot = widget.source.workspace.selectedId;
    zoneSnapshot = widget.source.workspace.calendar?.identifier;
    widget.source.workspace.addListener(changed);
    load();
  }

  @override
  void dispose() {
    sequence++;
    widget.source.workspace.removeListener(changed);
    super.dispose();
  }

  Future<void> load({bool more = false}) async {
    final ws = widget.source.workspace,
        owner = widget.source.workspace.session.current,
        id = widget.source.workspace.selectedId;
    if (invalid || owner == null || id == null || loading) return;
    final attempt = ++sequence;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await ws.cache.get(
        owner,
        'vehicles/$id/drives',
        query: {
          ...query,
          'limit': '20',
          if (more && cursor != null) 'cursor': cursor!,
        },
      );
      if (mounted &&
          attempt == sequence &&
          ws.session.isCurrent(owner) &&
          ws.selectedId == id) {
        setState(() {
          if (!more) items = [];
          final ids = items.map((x) => x['id']).toSet();
          items.addAll(
            usageItems(r.body['items']).where((x) => !ids.contains(x['id'])),
          );
          matched = r.body['matched_drives'] as num?;
          cursor = r.body['next_cursor'] as String?;
        });
      }
    } catch (_) {
      if (mounted && attempt == sequence) {
        // CP07：翻页失败说清已保留的列表；首次读取失败用共享句。
        setState(
          () => error = more
              ? copy_msg.paginationFailedMessage('行程')
              : copy_msg.readFailedMessage('行程证据'),
        );
      }
    } finally {
      if (mounted && attempt == sequence) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: mileafPageBar(context, title: Text(widget.title)),
    body: SafeArea(
      top: false,
      child: MileafContent(
        child: invalid
            ? const Center(child: Text('车辆或会话已改变，请返回统计'))
            : ListView(
                padding: MileafLayout.pagePadding(context, top: MileafSpace.s8),
                children: [
                  // CP02 对照表：完整匹配数只写数量；区间与归期写进元信息。
                  Text(
                    '${usageValue(matched)} 趟',
                    style: context.type.title2.copyWith(
                      color: context.colors.text,
                    ),
                  ),
                  Text(
                    '${_rangeLabel()}，按开始日期统计',
                    style: context.type.subheadline.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: MileafSpace.s12),
                  if (error != null)
                    InlineBanner(message: error!, tone: BannerTone.error),
                  if (!loading && error == null && items.isEmpty)
                    // MG09 空态分档：筛选无结果档；下一步动作是返回调整筛选。
                    StateView(
                      kind: StateViewKind.empty,
                      title: emptyStateCopy(
                        EmptyStateTier.filterNoMatch,
                        object: '已完成行程',
                      ).status,
                      message: '可以返回调整日期或分组。',
                      actionLabel: '调整筛选',
                      actionSemanticLabel: '返回调整行程筛选',
                      onAction: () => Navigator.of(context).maybePop(),
                    ),
                  for (final d in items)
                    MileafDataRow(
                      title:
                          '${usageMap(d['start'])['display_name'] ?? '未知起点'} → ${usageMap(d['end'])['display_name'] ?? '未知终点'}',
                      titleMaxLines: MileafLayout.largeText(context) ? null : 2,
                      meta:
                          '${_recordTime(d)}\n${usageValue(d['duration_min'])} 分钟\n电耗 ${usageValue(d['consumption_wh_km'])} Wh/km',
                      value: d['distance_km'] == null
                          ? null
                          : usageValue(d['distance_km']),
                      unit: 'km',
                      showChevron: true,
                      onTap: widget.onRecord == null
                          ? null
                          : () => widget.onRecord!(d['id'] as int),
                    ),
                  if (loading) ...[
                    const MileafProgressLine(),
                    Text(
                      copy_msg.loadingMessage('行程证据'),
                      style: context.type.body.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                  if (error != null || cursor != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        container: true,
                        label: error != null ? '重试行程证据' : null,
                        child: TextButton(
                          onPressed: loading
                              ? null
                              : () => load(more: items.isNotEmpty),
                          child: Text(error != null ? '重试' : '加载更多行程'),
                        ),
                      ),
                    ),
                  MileafDataNotes(
                    groups: [
                      const MileafDataNoteGroup(
                        category: DataNoteCategory.caliber,
                        note:
                            '沿用统计筛选；完整匹配数来自服务端，'
                            '不从已加载分页重算。按开始日期统计。',
                      ),
                      MileafDataNoteGroup(
                        category: DataNoteCategory.technical,
                        copyable: true,
                        note: [
                          for (final entry in query.entries)
                            '${entry.key} ${entry.value}',
                        ].join('\n'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    ),
  );

  String _rangeLabel() {
    final zone = widget.source.workspace.calendar!;
    final from = DateTime.tryParse(query['from'] ?? '');
    final to = DateTime.tryParse(query['to'] ?? '');
    if (from == null || to == null) return '期间未知';
    final last = zone.local(to.subtract(const Duration(microseconds: 1)));
    final first = zone.local(from);
    final sameDay =
        first.year == last.year &&
        first.month == last.month &&
        first.day == last.day;
    return sameDay
        ? copy_dates.formatDay(
            first,
            zone.local(widget.source.workspace.session.now()),
          )
        : copy_dates.formatRange(first, last);
  }

  String _recordTime(Map<String, dynamic> record) {
    final zone = widget.source.workspace.calendar!;
    final from = DateTime.tryParse(record['started_at'] as String? ?? '');
    final to = DateTime.tryParse(record['ended_at'] as String? ?? '');
    if (from == null) return '开始时间未知';
    final start = zone.local(from);
    String clock(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final date = statisticsDate(start);
    if (to == null) return '$date ${clock(start)}，结束时间未知';
    final end = zone.local(to);
    return '$date ${clock(start)}–${statisticsDate(end) == date ? '' : '${statisticsDate(end)} '}${clock(end)}';
  }
}
