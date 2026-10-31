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
