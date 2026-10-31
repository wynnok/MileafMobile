import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/number_format.dart';

void main() {
  test('C 大数以千位分隔，小数位保留', () {
    expect(grouped(1198.6, decimals: 1), '1,198.6');
    expect(grouped(1280.6, decimals: 1), '1,280.6');
    expect(grouped(960), '960');
    expect(grouped(1000), '1,000');
    expect(grouped(1234567.891, decimals: 2), '1,234,567.89');
  });
  test('负数与零保持可读', () {
    expect(grouped(-1234.5, decimals: 1), '-1,234.5');
    expect(grouped(0, decimals: 1), '0.0');
  });
}
