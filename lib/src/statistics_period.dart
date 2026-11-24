import 'package:flutter/material.dart';

import 'copy/dates.dart' as copy_dates;
import 'design/components/components.dart';
import 'design/tokens.dart';
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
    if (duration <= Duration.zero) {
      throw const FormatException('请选择开始日期早于结束日期的区间');
    }
    if (duration > const Duration(days: 730)) {
      // CP07：上界文案按文案规范改写（原「统计区间须大于 0 且不超过 730×24
      // 小时，请缩小区间」）。
      throw const FormatException('最长可选 730 天，请缩短时间段');
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

/// The bucket at [at], else the nearest earlier bucket, else 0. Null when
/// there is no date to preserve or no bucket to land on.
int? bucketIndexAt(List<DateTime> times, DateTime? at) {
  if (at == null || times.isEmpty) return null;
  for (var i = 0; i < times.length; i++) {
    if (times[i].isAtSameMomentAs(at)) return i;
  }
  for (var i = times.length - 1; i >= 0; i--) {
    if (!times[i].isAfter(at)) return i;
  }
  return 0;
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
    this.editor,
  });
  final StatisticsSelection selection;
  final CalendarContext calendar;
  final DateTime now;
  final ValueChanged<StatisticsSelection> onChanged;

  /// Wraps the page-owned modal date editor, so closing it is not mistaken for
  /// a reading-route return: the editor's own completion already loads the
  /// period the owner picked.
  final Future<R> Function<R>(Future<R> Function())? editor;

  /// R27/PD10：自定义期间走共享日期区间弹层；本周/本年等预设在弹层内，
  /// 校验（不晚于今天、最长 730×24 小时）与回调由本页注入。
  Future<void> custom(BuildContext context) async {
    final today = calendar.local(now);
    Future<Object?> open() => showMileafSheet<Object>(
      context: context,
      title: '选择日期',
      style: MileafSheetStyle.edge,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                StatusChip(
                  label: preset.value,
                  onTap: () => Navigator.pop(
                    sheetContext,
                    StatisticsSelection(period: preset.key),
                  ),
                ),
            ],
          ),
          const SizedBox(height: MileafSpace.s12),
          MileafDateRangeSheet(
            initialRange: DateTimeRange(
              start: selection.start ?? DateTime(today.year, today.month),
              end: selection.end ?? today,
            ),
            firstDate: DateTime(today.year, today.month, today.day - 730),
            lastDate: today,
            today: today,
            validator: (start, end) {
              try {
                StatisticsSelection(
                  period: StatisticsPeriod.custom,
                  start: DateTime.utc(start.year, start.month, start.day),
                  end: DateTime.utc(end.year, end.month, end.day),
                ).resolve(calendar, now);
                return null;
              } on FormatException catch (e) {
                return e.message;
              }
            },
          ),
        ],
      ),
    );
    final value = await (editor?.call(open) ?? open());
    if (value is StatisticsSelection && context.mounted) {
      onChanged(value);
    } else if (value is DateTimeRange && context.mounted) {
      onChanged(
        StatisticsSelection(
          period: StatisticsPeriod.custom,
          start: DateTime.utc(
            value.start.year,
            value.start.month,
            value.start.day,
          ),
          end: DateTime.utc(value.end.year, value.end.month, value.end.day),
        ),
      );
    }
  }

  /// Quick periods and the shared custom-date entry, with a visible custom range.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      MileafPeriodRow(
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
            // R27/CP06：与充电页统一为「自定义」（D-AP07-20）。
            label: '自定义',
            selected: switch (selection.period) {
              StatisticsPeriod.week ||
              StatisticsPeriod.year ||
              StatisticsPeriod.custom => true,
              _ => false,
            },
            onTap: () => custom(context),
          ),
        ],
      ),
      if (selection.period == StatisticsPeriod.custom) ...[
        const SizedBox(height: MileafSpace.s8),
        Text(copy_dates.formatRange(selection.start!, selection.end!)),
      ],
    ],
  );
}
