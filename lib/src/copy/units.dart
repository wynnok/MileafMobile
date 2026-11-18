/// CP03 数字与单位、CP11 单位中文朗读。
///
/// 数字与单位之间一个空格；%、°C 紧贴数值；负数用真负号 −（U+2212）。
/// 币种符号紧贴在前的处理在 currency.dart（业务逻辑，不在此处重复）。
library;

import 'package:mileaf/src/number_format.dart' show applyMinusSign, grouped;

/// 数值 + 单位。一般单位一个空格（60.0 km、52 趟）；%、°C 紧贴。
String valueUnit(num value, String unit, {int decimals = 0}) {
  final text = applyMinusSign(grouped(value, decimals: decimals));
  if (unit == '%' || unit == '°C') return '$text$unit';
  return '$text $unit';
}

/// CP11 semanticsUnit：单位朗读用中文。未知单位原样返回。
String semanticsUnit(String unit) => switch (unit) {
  'km' => '公里',
  'kWh' => '千瓦时',
  'Wh/km' => '瓦时每公里',
  'kW' => '千瓦',
  '%' => '百分之',
  _ => unit,
};
