import 'statistics_period.dart';
import 'workspace.dart';

enum OverviewPeriod { month, recent }

/// Calendar dates, rather than UTC durations, define both comparison windows.
class OverviewWindow {
  OverviewWindow(
    OverviewPeriod period,
    CalendarContext calendar,
    DateTime now,
  ) {
    final local = calendar.local(now);
    final today = DateTime.utc(local.year, local.month, local.day);
    first = period == OverviewPeriod.month
        ? DateTime.utc(local.year, local.month)
        : today.subtract(const Duration(days: 6));
    last = today;
    current = StatisticsWindow(calendar.midnight(first), now.toUtc(), 'day');
    if (!current.to.isAfter(current.from)) {
      throw const FormatException('本期尚无可统计时间，请稍后刷新');
    }
    final previousLast = period == OverviewPeriod.month
        ? DateTime.utc(local.year, local.month - 1, local.day)
        : today.subtract(const Duration(days: 7));
    final previousMonth = DateTime.utc(local.year, local.month - 1);
    if (period == OverviewPeriod.month &&
        previousLast.month != previousMonth.month) {
      return;
    }
    final previousFirst = period == OverviewPeriod.month
        ? previousMonth
        : first.subtract(const Duration(days: 7));
    final wall = DateTime.utc(
      previousLast.year,
      previousLast.month,
      previousLast.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
    final candidates = <DateTime>{};
    // Nearby offsets cover both sides of a DST transition. Only a unique
    // round-trip to the requested wall clock is accepted.
    for (final days in [-2, 0, 2]) {
      final offset = calendar
          .local(wall.add(Duration(days: days)))
          .timeZoneOffset;
      final candidate = wall.subtract(offset);
      final check = calendar.local(candidate);
      if (check.year == wall.year &&
          check.month == wall.month &&
          check.day == wall.day &&
          check.hour == wall.hour &&
          check.minute == wall.minute &&
          check.second == wall.second &&
          check.millisecond == wall.millisecond &&
          check.microsecond == wall.microsecond) {
        candidates.add(candidate);
      }
    }
    if (candidates.length != 1) return;
    final from = calendar.midnight(previousFirst), to = candidates.single;
    if (to.isAfter(from)) previous = StatisticsWindow(from, to, 'day');
  }
  late final StatisticsWindow current;
  StatisticsWindow? previous;
  late final DateTime first, last;
  StatisticsSelection get selection => StatisticsSelection(
    period: StatisticsPeriod.custom,
    start: first,
    end: last,
  );
}
