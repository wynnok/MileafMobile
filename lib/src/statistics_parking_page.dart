import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'data_cards.dart';
import 'statistics_insights_page.dart';
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
  String get identity {
    final c = widget.context;
    return '${c.workspace.session.current?.generation}/${c.workspace.selectedId}/${c.workspace.calendar?.identifier}/${c.workspace.revision}/${c.window.from}/${c.window.to}/${c.window.bucket}/${c.features['parking_observations']}';
  }

  late String loadedIdentity;
  @override
  void initState() {
    super.initState();
    loadedIdentity = identity;
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void didUpdateWidget(covariant ParkingObservationPage old) {
    super.didUpdateWidget(old);
    if (loadedIdentity != identity) {
      loadedIdentity = identity;
      data = null;
      items.clear();
      cursor = null;
      selected = 0;
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
        (ModalRoute.of(context)?.isCurrent ?? false)) {
      load();
    }
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
            data = response.body;
            items.clear();
            selected = 0;
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
  String change(Map? x) =>
      '${n(x?['soc_change_pp'])} pp · ${n(x?['soc_change_pp_per_24h'])} pp/24h';
  Widget states(Map row) {
    const names = {
      'online': '在线',
      'asleep': '睡眠',
      'offline': '离线',
      'unknown': '未知',
    };
    final colors = [Colors.teal, Colors.indigo, Colors.orange, Colors.grey];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 18,
          child: Row(
            children: [
              for (var i = 0; i < 4; i++)
                if (row['${names.keys.elementAt(i)}_share'] is num &&
                    (row['${names.keys.elementAt(i)}_share'] as num) > 0)
                  Expanded(
                    flex: math.max(
                      1,
                      ((row['${names.keys.elementAt(i)}_share'] as num) * 10000)
                          .round(),
                    ),
                    child: ColoredBox(
                      color: colors[i],
                      child: const SizedBox.expand(),
                    ),
                  ),
            ],
          ),
        ),
        for (final e in names.entries)
          Text(
            '${e.value} ${n(row['${e.key}_hours'])} h · ${row['${e.key}_share'] is num ? ((row['${e.key}_share'] as num) * 100).toStringAsFixed(1) : '—'}%',
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.context,
        d = data,
        t = d?['totals'] as Map?,
        compact = c.compact && !widget.expanded;
    if (c.features['parking_observations'] != true) {
      return const DataCard(child: Text('当前站点不支持停放观察'));
    }
    final rows = [
      if (d != null)
        for (final x in d['buckets'] as List)
          Map<String, dynamic>.from(x as Map),
    ];
    final body = DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '停放SOC变化',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: busy ? null : () => load(force: true),
                tooltip: '刷新停放观察',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          Text(change(t), style: Theme.of(context).textTheme.headlineSmall),
          Text(
            '有效窗口 ${t?['valid_windows'] ?? 0} · 观测 ${n(t?['observed_hours'])} h',
          ),
          if (busy) const LinearProgressIndicator(),
          if (error != null) Text(error!),
          if (error != null)
            TextButton(
              onPressed: () => load(force: true),
              child: const Text('重试停放观察'),
            ),
          if (!compact) ...[
            if (d != null) Text('状态：${d['status']} · 查询生成：${d['as_of']}'),
            const Text('SOC百分点变化 · 负值下降，正值回弹，零为不变；标准化率为已观测结果，不预测未来24小时。'),
            if (rows.isNotEmpty) ...[
              SizedBox(
                height: 190,
                child: LayoutBuilder(
                  builder: (context, box) => GestureDetector(
                    onTapDown: (p) => setState(
                      () => selected =
                          (p.localPosition.dx / box.maxWidth * rows.length)
                              .floor()
                              .clamp(0, rows.length - 1),
                    ),
                    onHorizontalDragUpdate: (p) => setState(
                      () => selected =
                          (p.localPosition.dx / box.maxWidth * rows.length)
                              .floor()
                              .clamp(0, rows.length - 1),
                    ),
                    child: CustomPaint(
                      key: const Key('parking-trend-chart'),
                      painter: _ParkingPainter(
                        rows,
                        selected,
                        Theme.of(context).colorScheme,
                        MediaQuery.textScalerOf(context).scale(11),
                      ),
                      size: Size(box.maxWidth, 190),
                    ),
                  ),
                ),
              ),
              Text(
                '${rows[selected]['bucket_start']} · ${change(rows[selected])}',
              ),
              Text(
                '有效 ${rows[selected]['valid_windows']} · 观测 ${n(rows[selected]['observed_hours'])} h',
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: selected > 0
                        ? () => setState(() => selected--)
                        : null,
                    child: const Text('前一点'),
                  ),
                  TextButton(
                    onPressed: selected + 1 < rows.length
                        ? () => setState(() => selected++)
                        : null,
                    child: const Text('后一点'),
                  ),
                ],
              ),
            ],
            if (t != null) ...[
              const Text('状态分布 · 以有效窗口观测小时为同一分母'),
              states(Map<String, dynamic>.from(t)),
              Text(
                '候选 ${t['candidate_windows']} · 排除 ${t['excluded_windows']} · 开放 ${t['open_windows']}',
              ),
              Text('排除原因：${t['excluded_by_reason']}'),
            ],
            const Text(
              '按窗口开始时间归期；闭合结束可晚于查询结束，但已发生且不晚于查询生成时间。不裁切或分摊SOC。精确事件边界取值，持续≥1h，绝对里程差<1km。状态仅代表记录，不归因车辆功能；离线不等于睡眠，开放状态归未知。',
            ),
            Text(
              '方法 closed-window-soc-v1 · provisional · 阈值 ${d?['thresholds'] ?? '默认：≥1h，绝对里程差<1km'}',
            ),
            Text(
              '匹配窗口 ${d?['matched_windows'] ?? 0} · 已载证据 ${items.length}（匹配数不等于有效数）',
            ),
            for (final row in items)
              ExpansionTile(
                title: Text(
                  '${row['window_id']} · ${row['included'] == true ? '有效' : '未计入'} · ${row['quality']}',
                ),
                subtitle: Text(
                  '${row['window_start']} → ${row['window_end'] ?? '开放尾段，无最终变化'}',
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
          ],
        ],
      ),
    );
    return compact
        ? body
        : LayoutBuilder(
            builder: (context, box) => box.hasBoundedHeight
                ? ListView(padding: const EdgeInsets.all(18), children: [body])
                : body,
          );
  }
}

class _ParkingPainter extends CustomPainter {
  _ParkingPainter(this.rows, this.selected, this.colors, this.fontSize);
  final double fontSize;
  final List<Map<String, dynamic>> rows;
  final int selected;
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = [
      1.0,
      for (final r in rows)
        if (r['soc_change_pp'] is num)
          (r['soc_change_pp'] as num).abs().toDouble(),
    ].reduce(math.max);
    final middle = size.height / 2;
    void label(String text, Offset p) {
      final t = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: colors.onSurface, fontSize: fontSize),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(canvas, p);
    }

    canvas.drawLine(
      Offset(72, middle),
      Offset(size.width, middle),
      Paint()..color = colors.outline,
    );
    label('0 pp', Offset(0, middle));
    label('+${maxValue.toStringAsFixed(0)} pp', const Offset(0, 0));
    label(
      '-${maxValue.toStringAsFixed(0)} pp',
      Offset(0, size.height - fontSize * 1.3),
    );
    for (var i = 0; i < rows.length; i++) {
      final v = rows[i]['soc_change_pp'];
      if (v is! num) continue;
      final x = 72 + (i + .5) * (size.width - 80) / rows.length,
          y = middle - v / maxValue * (middle - 20);
      canvas.drawLine(
        Offset(x, middle),
        Offset(x, y),
        Paint()
          ..color = v < 0 ? colors.tertiary : colors.primary
          ..strokeWidth = math.min(12, (size.width - 80) / rows.length * .6),
      );
      canvas.drawCircle(
        Offset(x, y),
        i == selected ? 5 : 3,
        Paint()..color = colors.primary,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParkingPainter old) => true;
}
