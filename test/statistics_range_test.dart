import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'statistics_test.dart' show openStats, fixture;

Map<String, dynamic> rangeResponse({bool sparse = false}) => {
  'query': {
    'vehicle_id': 1,
    'from': '2026-05-01T00:00:00Z',
    'to': '2026-10-28T11:00:00Z',
    'tz': 'Asia/Shanghai',
    'filters': {'months': 6},
  },
  'as_of': '2026-10-28T11:00:00Z',
  'first_observed_at': '2026-05-02T00:00:00Z',
  'first_observed_scope': 'query',
  'totals': {
    'status': 'available',
    'sample_status': sparse ? 'sparse' : 'adequate',
  },
  'buckets': [
    for (var m = 5; m <= 10; m++)
      {
        'bucket_start': '2026-${m.toString().padLeft(2, '0')}-01T00:00:00Z',
        'partial': m == 10,
        'status': 'available',
        'sample_status': sparse ? 'sparse' : 'adequate',
        'median_range_km': m == 10 ? 432 : 440,
        'p10_range_km': 422,
        'p90_range_km': 449,
        'coverage': {'valid_days': sparse ? 2 : 8},
      },
  ],
};
Future<void> openRange(
  WidgetTester tester,
  List<int> requests, {
  bool sparse = false,
}) async {
  await openStats(
    tester,
    MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      if (r.url.path.endsWith('/meta')) {
        return http.Response(
          jsonEncode({
            'statistics_insights': {
              'contract_version': 'statistics-insights-v1',
              'minimum_server_version': '0.3.0',
              'features': {
                'driving_coverage': true,
                'range_observations': true,
              },
            },
          }),
          200,
        );
      }
      if (r.url.path.endsWith('/range-observations')) {
        expect(r.url.queryParameters.containsKey('from'), isFalse);
        requests.add(int.parse(r.url.queryParameters['months']!));
        return http.Response(jsonEncode(rangeResponse(sparse: sparse)), 200);
      }
      return fixture('driving-stats');
    }),
    () => DateTime.utc(2026, 10, 28, 11),
    () => 'Asia/Shanghai',
    statisticsInsights: true,
  );
  await tester.tap(find.text('长期'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('续航专题读取6/12月服务端波动带和原值', (tester) async {
    final requests = <int>[];
    await openRange(tester, requests);
    expect(find.textContaining('满电等效额定续航'), findsWidgets);

    expect(find.byKey(const Key('range-observation-chart')), findsOneWidget);
    expect(find.textContaining('P10–P90'), findsWidgets);
    expect(find.textContaining('432'), findsWidgets);
    await tester.tap(find.text('12个月'));
    await tester.pumpAndSettle();
    expect(requests.last, 12);
  });
  testWidgets('续航available但仅两有效日时明确稀疏，保留服务端点读', (tester) async {
    await openRange(tester, <int>[], sparse: true);
    expect(find.textContaining('样本稀疏，仅供点读'), findsOneWidget);
    expect(find.textContaining('432'), findsWidgets);
    await tester.ensureVisible(find.text('前一个月'));
    await tester.tap(find.text('前一个月'));
    await tester.pumpAndSettle();
    expect(find.textContaining('440'), findsWidgets);
  });
}
