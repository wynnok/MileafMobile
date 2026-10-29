import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'statistics_test.dart' show openStats, fixture;

void main() {
  testWidgets('统计洞察使用能力声明展示总览与配对净电耗', (tester) async {
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      if (r.url.path.endsWith('/meta')) {
        return http.Response(
          jsonEncode({
            'statistics_insights': {
              'contract_version': 'statistics-insights-v1',
              'minimum_server_version': '0.3.0',
              'features': {'driving_coverage': true},
            },
          }),
          200,
        );
      }
      final d =
          jsonDecode(fixture('driving-stats').body) as Map<String, dynamic>;
      d['range_kind'] = 'rated';
      d['totals']['net_consumption_paired'] = {
        'value_wh_km': 187.5,
        'method': 'paired-net-consumption-v1',
        'version': 1,
      };
      d['totals']['comparison_quality'] = {'sample_status': 'adequate'};
      return http.Response(jsonEncode(d), 200);
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    expect(find.text('用车洞察'), findsOneWidget);
    expect(find.textContaining('187.5'), findsWidgets);
  });
  testWidgets('统计能力读取失败时仍可阅读旧统计', (tester) async {
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      if (r.url.path.endsWith('/meta')) return http.Response('{}', 503);
      return fixture('driving-stats');
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
    );
    expect(find.text('驾驶统计'), findsOneWidget);
  });
}
