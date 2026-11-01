import 'package:flutter/material.dart';

import 'design/components/components.dart';
import 'workspace.dart';

enum StatisticsPeriod { week, recent, month, year, custom }

/// Inclusive calendar dates are kept separately from their UTC query boundaries.
class StatisticsSelection {
  const StatisticsSelection({
    this.period = StatisticsPeriod.month,
    this.start,
    this.end,
  });
  final StatisticsPeriod period;
  final DateTime? start, end;

  StatisticsWindow resolve(CalendarContext calendar, DateTime now) {
    final local = calendar.local(now);
    final today = DateTime.utc(local.year, local.month, local.day);
    final first = switch (period) {
      StatisticsPeriod.week => today.subtract(
        Duration(days: today.weekday - 1),
      ),
      StatisticsPeriod.recent => today.subtract(const Duration(days: 6)),
      StatisticsPeriod.month => DateTime.utc(local.year, local.month),
      StatisticsPeriod.year => DateTime.utc(local.year),
      StatisticsPeriod.custom => start!,
    };
    final last = period == StatisticsPeriod.custom ? end! : today;
    if (last.isBefore(first) || last.isAfter(today)) {
      throw const FormatException('请选择开始日期不晚于结束日期、且不含未来日期的区间');
    }
    final from = calendar.midnight(first);
    final to = last == today
        ? now.toUtc()
        : calendar.midnight(last, nextDays: 1);
    final duration = to.difference(from);
    if (duration <= Duration.zero || duration > const Duration(days: 730)) {
      throw const FormatException('统计区间须大于 0 且不超过 730×24 小时，请缩小区间');
    }
    final days = last.difference(first).inDays + 1;
    final bucket = switch (period) {
      StatisticsPeriod.week ||
      StatisticsPeriod.recent ||
      StatisticsPeriod.month => 'day',
      StatisticsPeriod.year => 'month',
      StatisticsPeriod.custom =>
        days <= 31
            ? 'day'
            : days <= 180
            ? 'week'
            : 'month',
    };
    return StatisticsWindow(from, to, bucket);
  }
}

class StatisticsWindow {
  const StatisticsWindow(this.from, this.to, this.bucket);
  final DateTime from, to;
  final String bucket;
  Map<String, String> query(String kind, CalendarContext calendar) => {
    'kind': kind,
    'bucket': bucket,
    'from': from.toIso8601String(),
    'to': to.toIso8601String(),
    'tz': calendar.identifier,
  };
}

String statisticsDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class StatisticsPeriodControls extends StatelessWidget {
  const StatisticsPeriodControls({
    super.key,
    required this.selection,
    required this.calendar,
    required this.now,
    required this.onChanged,
  });
  final StatisticsSelection selection;
  final CalendarContext calendar;
  final DateTime now;
  final ValueChanged<StatisticsSelection> onChanged;
  Future<void> custom(BuildContext context) async {
    final today = calendar.local(now);
    final start = TextEditingController(
      text: statisticsDate(
        selection.start ?? DateTime(today.year, today.month),
      ),
    );
    final end = TextEditingController(
      text: statisticsDate(selection.end ?? today),
    );
    String? error;
    final route = DialogRoute<StatisticsSelection>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('自定义统计日期'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChipRow(
                  alignment: WrapCrossAlignment.start,
                  children: [
                    for (final preset in const {
                      StatisticsPeriod.week: '本周',
                      StatisticsPeriod.recent: '近7天',
                      StatisticsPeriod.month: '本月',
                      StatisticsPeriod.year: '本年',
                    }.entries)
                      ActionChip(
                        label: Text(preset.value),
                        onPressed: () => Navigator.pop(
                          context,
                          StatisticsSelection(period: preset.key),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('日期格式 YYYY-MM-DD；结束日期包含当天，今天截至当前时刻。'),
                const SizedBox(height: 24),
                TextField(
                  controller: start,
                  decoration: const InputDecoration(labelText: '开始日期'),
                  keyboardType: TextInputType.datetime,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: end,
                  decoration: const InputDecoration(labelText: '结束日期（含）'),
                  keyboardType: TextInputType.datetime,
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                DateTime? parse(String value) {
                  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
                    return null;
                  }
                  final d = DateTime.tryParse('${value}T00:00:00Z');
                  return d != null && statisticsDate(d) == value ? d : null;
                }

                final from = parse(start.text.trim()),
                    to = parse(end.text.trim());
                if (from == null || to == null) {
                  setState(() => error = '请输入有效日历日期 YYYY-MM-DD');
                  return;
                }
                final next = StatisticsSelection(
                  period: StatisticsPeriod.custom,
                  start: from,
                  end: to,
                );
                try {
                  next.resolve(calendar, now);
                } on FormatException catch (e) {
                  setState(() => error = e.message);
                  return;
                }
                Navigator.pop(context, next);
              },
              child: const Text('应用区间'),
            ),
          ],
        ),
      ),
    );
    final value = await Navigator.of(context).push(route);
    await route.completed;
    if (value != null && context.mounted) onChanged(value);
    start.dispose();
    end.dispose();
  }

  /// Two quick ranges plus the 日期 sheet action, all A chips; custom/week/year
  /// stay reachable from the sheet. Chips wrap instead of scrolling at 200%.
  @override
  Widget build(BuildContext context) => ChipRow(
    children: [
      StatusChip(
        label: '本月',
        selected: selection.period == StatisticsPeriod.month,
        onTap: () => onChanged(
          const StatisticsSelection(period: StatisticsPeriod.month),
        ),
      ),
      StatusChip(
        label: '近7天',
        selected: selection.period == StatisticsPeriod.recent,
        onTap: () => onChanged(
          const StatisticsSelection(period: StatisticsPeriod.recent),
        ),
      ),
      StatusChip(
        label: switch (selection.period) {
          StatisticsPeriod.week => '本周',
          StatisticsPeriod.year => '本年',
          StatisticsPeriod.custom =>
            '${statisticsDate(selection.start!)} 至 ${statisticsDate(selection.end!)}',
          _ => '日期',
        },
        selected: switch (selection.period) {
          StatisticsPeriod.week ||
          StatisticsPeriod.year ||
          StatisticsPeriod.custom => true,
          _ => false,
        },
        onTap: () => custom(context),
      ),
    ],
  );
}
