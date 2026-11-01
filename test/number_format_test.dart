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
  test('相对时间人性化，不输出巨大分钟数', () {
    final now = DateTime.utc(2026, 10, 26, 18, 40);
    expect(relativeTime(now.subtract(const Duration(seconds: 20)), now), '刚刚');
    expect(relativeTime(now.subtract(const Duration(seconds: -60)), now), '刚刚');
    expect(relativeTime(now.subtract(const Duration(minutes: 2)), now), '2 分钟前');
    expect(relativeTime(now.subtract(const Duration(minutes: 59)), now), '59 分钟前');
    expect(relativeTime(now.subtract(const Duration(hours: 3)), now), '3 小时前');
    expect(
      relativeTime(now.subtract(const Duration(hours: 30)), now),
      '10/25',
    );
    final ancient = relativeTime(now.subtract(const Duration(days: 227)), now);
    expect(ancient, isNot(contains('分钟前')));
    expect(ancient, '3/13');
  });
}
