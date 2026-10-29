import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'statistics_test.dart' show openStats, fixture;
import 'support/statistics_insights_fixture.dart';

Map<String, dynamic> rangeResponse({
  int months = 6,
  bool sparse = false,
  bool missing = false,
}) => {
  'query': {
    'vehicle_id': 1,
    'from': DateTime.utc(
      2026,
      11 - months,
      1,
    ).subtract(const Duration(hours: 8)).toIso8601String(),
    'to': '2026-10-28T11:00:00Z',
    'tz': 'Asia/Shanghai',
    'filters': {'months': months},
  },
  'as_of': '2026-10-28T11:00:00Z',
  'first_observed_at': '2026-05-02T00:00:00Z',
  'first_observed_scope': 'query',
  'totals': {
    'status': 'available',
    'sample_status': sparse ? 'sparse' : 'adequate',
  },
  'buckets': [
    for (var m = 0; m < months; m++)
      {
        'bucket_start': DateTime.utc(
          2026,
          11 - months + m,
          1,
        ).subtract(const Duration(hours: 8)).toIso8601String(),
        'partial': m == months - 1,
        'status': missing && m == months - 1 ? 'no_records' : 'available',
        'sample_status': missing && m == months - 1
            ? 'insufficient_data'
            : sparse
            ? 'sparse'
            : 'adequate',
        'median_range_km': missing && m == months - 1
            ? null
            : m == months - 1
            ? 432
            : 440,
        'p10_range_km': missing && m == months - 1 ? null : 422,
        'p90_range_km': missing && m == months - 1 ? null : 449,
        'coverage': {
          'valid_days': missing && m == months - 1
              ? 0
              : sparse
              ? 2
              : 8,
          'candidate_sessions': missing && m == months - 1 ? 0 : 10,
          'valid_sessions': missing && m == months - 1 ? 0 : 10,
          'candidate_points': missing && m == months - 1 ? 0 : 120,
          'valid_points': missing && m == months - 1 ? 0 : 120,
          'excluded_points': 0,
        },
      },
  ],
};
Future<void> openRange(
  WidgetTester tester,
  List<int> requests, {
  bool sparse = false,
  bool missing = false,
  bool fail = false,
}) async {
  await openStats(
    tester,
    MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      if (r.url.path.endsWith('/meta')) {
        return http.Response(
          jsonEncode(
            statisticsInsightsMeta(
              features: {'driving_coverage': true, 'range_observations': true},
            ),
          ),
          200,
        );
      }
      if (r.url.path.endsWith('/range-observations')) {
        expect(r.url.queryParameters.containsKey('from'), isFalse);
        requests.add(int.parse(r.url.queryParameters['months']!));
        if (fail) return http.Response('{}', 503);
        return http.Response(
          jsonEncode(
            rangeResponse(
              sparse: sparse,
              missing: missing,
              months: int.parse(r.url.queryParameters['months']!),
            ),
          ),
          200,
        );
      }
      return http.Response(jsonEncode(statisticsInsightsFixture(r.url)), 200);
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
  testWidgets('缺月保留破折号及未结束标识，前后读取不补零', (tester) async {
    await openRange(tester, <int>[], missing: true);
    expect(find.textContaining('中位 — km'), findsOneWidget);
    expect(find.textContaining('未结束月'), findsOneWidget);
    await tester.ensureVisible(find.text('前一个月'));
    await tester.tap(find.text('前一个月'));
    await tester.pumpAndSettle();
    expect(find.textContaining('440'), findsWidgets);
  });
  testWidgets('续航资源失败不清除统计承载并提供独立重试', (tester) async {
    await openRange(tester, <int>[], fail: true);
    expect(find.text('续航观察读取失败'), findsOneWidget);
    expect(find.text('重试续航观察'), findsOneWidget);
    expect(find.text('用车洞察'), findsOneWidget);
  });
}
