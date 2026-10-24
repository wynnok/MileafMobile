import 'package:flutter/material.dart';

import 'drives_contract.g.dart' as dto;
import 'workspace.dart';

class DrivesPage extends StatefulWidget {
  const DrivesPage({super.key, required this.workspace, this.onRecord});
  final VehicleWorkspace workspace;
  final void Function(int id)? onRecord;
  @override
  State<DrivesPage> createState() => _DrivesPageState();
}

class _DrivesPageState extends State<DrivesPage> {
  List<dto.Drive> items = [];
  String? error;
  bool loading = false;
  VehicleWorkspace get workspace => widget.workspace;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final session = workspace.session.current;
    final id = workspace.selectedId;
    final clock = workspace.calendar;
    if (session == null || id == null || clock == null) return;
    setState(() => loading = true);
    try {
      final now = workspace.session.now();
      final today = clock.local(now);
      final value = await workspace.cache.get(
        session,
        'vehicles/$id/drives',
        query: {
          'from': clock
              .midnight(DateTime(today.year, today.month, today.day - 29))
              .toIso8601String(),
          'to': now.toUtc().toIso8601String(),
          'limit': '20',
        },
      );
      final page = dto.DrivePage.fromJson(value.body);
      if (mounted &&
          workspace.session.isCurrent(session) &&
          workspace.selectedId == id)
        setState(() => items = page.items);
    } catch (_) {
      if (mounted) setState(() => error = '行程读取失败，请重试');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String number(num? value, String unit, {int decimals = 0}) =>
      value == null ? '—（缺失）' : '${value.toStringAsFixed(decimals)} $unit';
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('行程记录', style: Theme.of(context).textTheme.headlineSmall),
      if (loading) const LinearProgressIndicator(),
      if (error != null) Text(error!),
      for (final d in items)
        Card(
          child: InkWell(
            key: ValueKey('drive-${d.id}'),
            onTap: () => widget.onRecord?.call(d.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workspace.calendar!
                        .local(d.startedAt)
                        .toString()
                        .split('.')
                        .first,
                  ),
                  Text(
                    '${d.start.displayName ?? '未知地点'} → ${d.end.displayName ?? '未知地点'}',
                  ),
                  Text(
                    '距离 ${number(d.distanceKm, 'km', decimals: 1)} · 时长 ${number(d.durationMin, '分钟')}',
                  ),
                  Text('净电耗 ${number(d.consumptionWhKm, 'Wh/km')}'),
                  if (d.endedAt == null) const Text('进行中'),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}
