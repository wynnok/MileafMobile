/// C prototypes print large results with a thousands separator (`1,198.6`).
/// Small values keep the plain form so chips and notes stay stable.
String grouped(num value, {int decimals = 0}) {
  if (!value.isFinite) return '—';
  return groupedText(value.toStringAsFixed(decimals));
}

/// Same grouping for values that are already formatted (see `decimal`).
String groupedText(String text) {
  final dot = text.indexOf('.');
  final whole = dot < 0 ? text : text.substring(0, dot);
  final fraction = dot < 0 ? '' : text.substring(dot);
  final negative = whole.startsWith('-');
  final digits = negative ? whole.substring(1) : whole;
  final buffer = StringBuffer(negative ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '$buffer$fraction';
}

/// Human relative time: 刚刚 / N 分钟前 / N 小时前 / M/D. Never "326880 分钟前".
String relativeTime(DateTime time, DateTime now) {
  final diff = now.difference(time);
  if (diff.isNegative || diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
  if (diff.inHours < 24) return '${diff.inHours} 小时前';
  return '${time.month}/${time.day}';
}

/// 两位小数、去掉尾零：`40.18` / `45` / `0`。金额、占比、kWh 同一处理。
String decimal(num value) =>
    groupedText(value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), ''));
