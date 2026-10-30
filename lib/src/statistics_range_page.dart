import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'statistics_insights_page.dart';
import 'data_cards.dart';
import 'collage.dart';
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
    if (identity != currentIdentity) {
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
        (ModalRoute.of(context)?.isCurrent ?? false) &&
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
        setState(() => error = '续航观察读取失败${data == null ? '' : '，保留上次结果'}');
      }
    } finally {
      if (valid()) setState(() => loading = false);
    }
  }

  String value(Object? x) => x is num ? x.toStringAsFixed(1) : '—';
  @override
  Widget build(BuildContext context) {
    final c = widget.context;
    if (c.features['range_observations'] != true) {
      return const DataCard(child: Text('当前站点不支持长期续航观察'));
    }
    final d = data, totals = d?['totals'] as Map?;
    final rows = d == null
        ? <Map<String, dynamic>>[]
        : [
            for (final row in d['buckets'] as List)
              Map<String, dynamic>.from(row as Map),
          ];
    final compact = c.compact && !widget.expanded;
    final contents = <Widget>[
      Row(
        children: [
          Expanded(
            child: Text(
              '满电等效额定续航',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: () => load(force: true),
            icon: const Icon(Icons.refresh),
            tooltip: '刷新续航观察',
          ),
        ],
      ),
      if (loading) const LinearProgressIndicator(),
      if (error != null) Text(error!),
      if (error != null)
        TextButton(
          onPressed: () => load(force: true),
          child: const Text('重试续航观察'),
        ),
      if (d != null && totals?['status'] == 'unsupported')
        const Text('当前数据源不支持额定续航观察'),
      if (d != null && totals?['status'] == 'no_records')
        const Text('观察窗口内无充电记录'),
      if (d != null && totals?['status'] == 'insufficient_data')
        const Text('尚无有效续航样本'),
      if (compact) ...[
        Text(
          '${value(totals?['median_range_km'])} km',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ] else ...[
        Wrap(
          spacing: 8,
          children: [
            for (final m in [6, 12])
              ChoiceChip(
                label: Text('$m个月'),
                selected: months == m,
                onSelected: (_) {
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
        const Text('月中位数 · P10–P90有效日波动带（km）'),
        if (rows.isNotEmpty) ...[
          SizedBox(
            height: 210,
            child: LayoutBuilder(
              builder: (context, box) => GestureDetector(
                onTapDown: (p) {
                  final i =
                      ((p.localPosition.dx - 42) /
                              (box.maxWidth - 58) *
                              rows.length)
                          .floor()
                          .clamp(0, rows.length - 1);
                  setState(() => selected = i);
                },
                onHorizontalDragUpdate: (p) {
                  final i =
                      ((p.localPosition.dx - 42) /
                              (box.maxWidth - 58) *
                              rows.length)
                          .floor()
                          .clamp(0, rows.length - 1);
                  setState(() => selected = i);
                },
                child: CustomPaint(
                  key: const Key('range-observation-chart'),
                  size: Size(box.maxWidth, 210),
                  painter: _RangePainter(
                    rows,
                    selected,
                    Theme.of(context).colorScheme,
                    c.workspace.calendar!,
                    MediaQuery.textScalerOf(context).scale(11),
                    Theme.of(context).textTheme.bodySmall ?? const TextStyle(),
                  ),
                ),
              ),
            ),
          ),
          Builder(
            builder: (_) {
              final row = rows[selected], coverage = row['coverage'] as Map?;
              final date = c.workspace.calendar!.local(
                DateTime.parse(row['bucket_start'] as String),
              );
              return Semantics(
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${date.year}/${date.month} · ${row['partial'] == true ? '未结束月' : '完整月'}',
                    ),
                    Text(
                      '中位 ${value(row['median_range_km'])} km · P10 ${value(row['p10_range_km'])} / P90 ${value(row['p90_range_km'])} km',
                    ),
                    Text(
                      '有效日 ${coverage?['valid_days'] ?? 0} · ${row['sample_status'] == 'sparse'
                          ? '样本稀疏，仅供点读'
                          : row['sample_status'] == 'adequate'
                          ? '有效样本'
                          : '无有效样本'}',
                    ),
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: selected > 0
                              ? () => setState(() => selected--)
                              : null,
                          child: const Text('前一个月'),
                        ),
                        TextButton(
                          onPressed: selected + 1 < rows.length
                              ? () => setState(() => selected++)
                              : null,
                          child: const Text('后一个月'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
        ExpansionTile(
          title: const Text('样本与估计方法'),
          children: [
            const Text(
              '固定使用额定续航和仪表电量，同点电量20–90%；先求单次充电中位数，再求每日中位数和月分位数。筛选阈值为首版产品规则，非显著性或健康检测标准。',
            ),
            Text('窗口内首次有效采样：${d?['first_observed_at'] ?? '—'}（仅查询窗口，不是新车基线）'),
            for (final row in rows)
              Text(
                '${widget.context.workspace.calendar!.local(DateTime.parse(row['bucket_start'] as String)).year}/${widget.context.workspace.calendar!.local(DateTime.parse(row['bucket_start'] as String)).month} · 有效日 ${(row['coverage'] as Map?)?['valid_days'] ?? 0} · 有效会话 ${(row['coverage'] as Map?)?['valid_sessions'] ?? 0} · 有效采样 ${(row['coverage'] as Map?)?['valid_points'] ?? 0}',
              ),
          ],
        ),
      ],
    ];
    final chosen = rows.isEmpty ? null : rows[selected];
    final headline = CollageTile(
      surface: CollageSurface.hero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('所选月中位数'),
          Text(
            '${value(chosen?['median_range_km'])} km',
            style: Theme.of(context).textTheme.displaySmall
                ?.copyWith(color: const Color(0xFFEEF7EF)),
          ),
          Text('独立$months个月观察窗口'),
          const Text('满电等效额定续航 · 记录估计'),
          const Text('非电池健康检测 · 非实际可开距离'),
          if (chosen?['sample_status'] == 'sparse') const Text('覆盖不足 · 仅供点读'),
        ],
      ),
    );
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compact) headline,
        CollageTile(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: contents,
          ),
        ),
        if (!compact && d != null)
          ExpansionTile(
            title: const Text('数据说明'),
            children: [
              Text('$months个本地月 · ${d['query']['from']} 至 ${d['query']['to']}'),
              Text('查询生成时间：${d['as_of']}（非采样时间）'),
              const Text('此窗口独立于首页期间；不代表 SOH、容量或衰减。'),
            ],
          ),
      ],
    );
    return compact
        ? body
        : LayoutBuilder(
            builder: (context, constraints) => constraints.hasBoundedHeight
                ? ListView(padding: const EdgeInsets.all(12), children: [body])
                : body,
          );
  }
}

class _RangePainter extends CustomPainter {
  _RangePainter(
    this.rows,
    this.selected,
    this.colors,
    this.calendar,
    this.fontSize,
    this.labelStyle,
  );
  final List<Map<String, dynamic>> rows;
  final int selected;
  final ColorScheme colors;
  final CalendarContext calendar;
  final double fontSize;
  final TextStyle labelStyle;
  @override
  void paint(Canvas canvas, Size size) {
    final values = [
      for (final r in rows)
        for (final k in ['p10_range_km', 'median_range_km', 'p90_range_km'])
          if (r[k] is num) (r[k] as num).toDouble(),
    ];
    final low = values.isEmpty
        ? 0.0
        : (values.reduce(math.min) / 10).floor() * 10.0 - 10;
    final high = values.isEmpty
        ? 100.0
        : (values.reduce(math.max) / 10).ceil() * 10.0 + 10;
    const left = 42.0, top = 15.0;
    final width = size.width - 58, height = size.height - 45;
    double x(int i) => left + (i + .5) * width / rows.length;
    double y(num n) => top + height - (n - low) / (high - low) * height;
    void label(String text, Offset p) {
      final t = TextPainter(
        text: TextSpan(
          text: text,
          style: labelStyle.copyWith(
            color: colors.onSurfaceVariant,
            fontSize: fontSize,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(canvas, p);
    }

    for (var i = 0; i < 3; i++) {
      final n = low + (high - low) * i / 2;
      canvas.drawLine(
        Offset(left, y(n)),
        Offset(size.width - 8, y(n)),
        Paint()..color = colors.outlineVariant,
      );
      label(n.toStringAsFixed(0), Offset(0, y(n) - 7));
    }
    bool known(int i) =>
        rows[i]['status'] == 'available' && rows[i]['median_range_km'] is num;
    bool adequate(int i) =>
        known(i) &&
        rows[i]['sample_status'] == 'adequate' &&
        rows[i]['p10_range_km'] is num &&
        rows[i]['p90_range_km'] is num;
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final date = calendar.local(DateTime.parse(r['bucket_start'] as String));
      if (fontSize > 15
          ? i == 0 || i == rows.length - 1
          : rows.length <= 6 || i.isEven) {
        label('${date.month}月', Offset(x(i) - 10, top + height + 9));
      }
      if (i > 0 && adequate(i - 1) && adequate(i)) {
        final a = rows[i - 1];
        final band = Path()
          ..moveTo(x(i - 1), y(a['p10_range_km'] as num))
          ..lineTo(x(i), y(r['p10_range_km'] as num))
          ..lineTo(x(i), y(r['p90_range_km'] as num))
          ..lineTo(x(i - 1), y(a['p90_range_km'] as num))
          ..close();
        canvas.drawPath(
          band,
          Paint()..color = colors.primary.withValues(alpha: .15),
        );
        canvas.drawLine(
          Offset(x(i - 1), y(a['median_range_km'] as num)),
          Offset(x(i), y(r['median_range_km'] as num)),
          Paint()
            ..color = colors.primary
            ..strokeWidth = 2,
        );
      }
      if (known(i)) {
        final p = Paint()
          ..color = colors.primary
          ..strokeWidth = 2
          ..style = adequate(i) ? PaintingStyle.fill : PaintingStyle.stroke;
        canvas.drawCircle(
          Offset(x(i), y(r['median_range_km'] as num)),
          i == selected ? 5 : 3,
          p,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RangePainter old) => true;
}
