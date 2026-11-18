/// CP03 时长分级：小于 60 分钟「N 分钟」；60 分钟及以上「N 小时」/「N 小时 M 分钟」；
/// 24 小时及以上「N 天」/「N 天 M 分钟」/「N 天 H 小时」（分钟非零时附「M 分钟」）。
/// 负时长用真负号 −（U+2212）。
library;

import 'package:mileaf/src/number_format.dart' show minusSign;

String duration(Duration value) {
  if (value < Duration.zero) return '$minusSign${duration(-value)}';
  final minutes = value.inMinutes;
  if (minutes < 60) return '$minutes 分钟';
  if (minutes < 1440) {
    final hours = minutes ~/ 60, rem = minutes % 60;
    return rem == 0 ? '$hours 小时' : '$hours 小时 $rem 分钟';
  }
  final days = minutes ~/ 1440, rem = minutes % 1440;
  if (rem == 0) return '$days 天';
  if (rem < 60) return '$days 天 $rem 分钟';
  final hours = rem ~/ 60, mins = rem % 60;
  return mins == 0 ? '$days 天 $hours 小时' : '$days 天 $hours 小时 $mins 分钟';
}
