/// CP04 日期与时间格式化（DF1–DF9）。
///
/// 纯字符串化：输入为已按站点日历本地化的墙钟 DateTime，「今天/现在」由调用方
/// 传入参照。本文件不做任何时区换算（S04 归期逻辑不变）。
///
/// 输入约定：墙钟值用朴素 UTC DateTime（字段即墙钟）或 tz.TZDateTime（字段为
/// 该时区墙钟）；不要传入带偏移量的 DateTime（其字段跟随机器时区）。
library;

/// DF3 区间的连接号（U+2013）。呈现层（卡片标签）也要靠它选中唯一的换行点，
/// 因此公开而不是各写一份。
const String rangeSeparator = '\u2013';

String _pad2(int value) => value.toString().padLeft(2, '0');

String _monthDay(DateTime time) => '${time.month}月${time.day}日';

String _yearMonthDay(DateTime time) =>
    '${time.year}年${time.month}月${time.day}日';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _yesterday(DateTime now) =>
    DateTime.utc(now.year, now.month, now.day - 1);

const List<String> _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/// DF1 单日：M月D日；非今年加年。
String formatDay(DateTime time, DateTime today) =>
    time.year == today.year ? _monthDay(time) : _yearMonthDay(time);

/// DF2 记录分组标题：今天 / 昨天 / M月D日 周X。
String formatDayGroup(DateTime time, DateTime today) {
  if (_sameDay(time, today)) return '今天';
  if (_sameDay(time, _yesterday(today))) return '昨天';
  return '${formatDay(time, today)} ${_weekdays[time.weekday - 1]}';
}

/// DF3 日期区间：连接号 –（U+2013）；同月省日首，跨月两端带月，跨年两端带年。
String formatRange(DateTime from, DateTime to) =>
    _rangeText(from, to, rangeSeparator);

String _rangeText(DateTime from, DateTime to, String separator) {
  if (from.year != to.year) {
    return '${_yearMonthDay(from)}$separator${_yearMonthDay(to)}';
  }
  if (from.month == to.month) {
    return '${from.month}月${from.day}日$separator${to.day}日';
  }
  return '${_monthDay(from)}$separator${_monthDay(to)}';
}

/// DF4 时间：HH:mm。
String formatTime(DateTime time) => '${_pad2(time.hour)}:${_pad2(time.minute)}';

/// DF4 时间段：同日 HH:mm–HH:mm；跨日写全两端。
String formatTimeRange(DateTime from, DateTime to, {required DateTime today}) {
  if (_sameDay(from, to)) {
    return '${formatTime(from)}$rangeSeparator${formatTime(to)}';
  }
  return '${formatDay(from, today)} ${formatTime(from)}$rangeSeparator'
      '${formatDay(to, today)} ${formatTime(to)}';
}

/// DF5 日期加时间。
String formatDayTime(DateTime time, DateTime today) =>
    '${formatDay(time, today)} ${formatTime(time)}';

/// DF6 月份：M月；非今年加年。
String formatMonth(DateTime time, DateTime today) =>
    time.year == today.year ? '${time.month}月' : '${time.year}年${time.month}月';

/// DF6 月区间：M月–M月；跨年两端带年；非今年整体加年。
String formatMonthRange(DateTime from, DateTime to, DateTime today) {
  if (from.year == to.year) {
    final prefix = from.year == today.year ? '' : '${from.year}年';
    return '$prefix${from.month}月$rangeSeparator${to.month}月';
  }
  return '${from.year}年${from.month}月$rangeSeparator${to.year}年${to.month}月';
}

/// DF7 相对时间（数据新鲜度）：刚刚（<1 分钟）、N 分钟前（<60）、
/// 今天 HH:mm、昨天 HH:mm，其余 DF5。bareToday：当天只写 HH:mm（CP07 新鲜度读法）。
String _relativeText(DateTime time, DateTime now, {required bool bareToday}) {
  final diff = now.difference(time);
  if (diff.isNegative || diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (_sameDay(time, now)) {
    return bareToday ? formatTime(time) : '今天 ${formatTime(time)}';
  }
  if (_sameDay(time, _yesterday(now))) return '昨天 ${formatTime(time)}';
  return formatDayTime(time, now);
}

String formatRelative(DateTime time, DateTime now) =>
    _relativeText(time, now, bareToday: false);

/// DF8 精确时间（仅「关于这些数据」与技术详情，可复制）。
String formatPrecise(DateTime time) =>
    '${time.year}-${_pad2(time.month)}-${_pad2(time.day)} ${formatTime(time)}:${_pad2(time.second)}';

/// DF9 图轴·日级：首刻度与每月第一个刻度写 M月D日，其余写 D日。
List<String> formatAxisDayTicks(List<DateTime> ticks, DateTime today) {
  final out = <String>[];
  for (var i = 0; i < ticks.length; i++) {
    final tick = ticks[i];
    if (i == 0 || tick.month != ticks[i - 1].month) {
      out.add(formatDay(tick, today));
    } else {
      out.add('${tick.day}日');
    }
  }
  return out;
}

/// DF9 图轴·周级分桶：每桶首日 M月D日。
String formatAxisWeekBucket(DateTime bucketStart, DateTime today) =>
    formatDay(bucketStart, today);

/// DF9 图轴·月级：M月；非今年加年。
String formatAxisMonth(DateTime time, DateTime today) =>
    formatMonth(time, today);

/// DF9 图轴·时间级：HH:mm。
String formatAxisTime(DateTime time) => formatTime(time);

/// CP07 数据新鲜度读法（staleMessage 用）：与 DF7 的差异是当天只写 HH:mm。
String formatFreshness(DateTime time, DateTime now) =>
    _relativeText(time, now, bareToday: true);

/// CP04 读屏读法：区间分隔读作「至」。
String formatRangeReading(DateTime from, DateTime to) =>
    _rangeText(from, to, '至');
