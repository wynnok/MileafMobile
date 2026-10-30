import 'dart:convert';

import 'package:flutter/material.dart';

import 'support/statistics_insights_fixture.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'statistics_test.dart' show openStats, fixture;

Map<String, dynamic> setCoverage() => {
  'candidate_count': 20,
  'valid_count': 20,
  'excluded_count': 0,
  'candidate_distance_km': 300,
  'valid_distance_km': 300,
  'candidate_duration_min': 420,
  'valid_duration_min': 420,
  'unknown_distance_count': 0,
  'unknown_duration_count': 0,
  'excluded_by_reason': <String, int>{},
};
Map<String, dynamic> usageFixture() => {
  'view': 'usage',
  'method': 'usage-distribution-v1',
  'version': 1,
  'validation': 'provisional',
  'thresholds': <String, num>{},
  'as_of': '2026-10-28T11:00:00Z',
  'query': {
    'vehicle_id': 1,
    'from': '2026-10-01T00:00:00Z',
    'to': '2026-10-28T11:00:00Z',
    'tz': 'Asia/Shanghai',
    'bucket': null,
    'time_basis': 'started_at',
    'filters': {'completed_only': true},
  },
  'partial_today': true,
  'driving_distance_km': 300,
  'status': 'available',
  'active_days': 12,
  'driving_duration_min': 420,
  'distance_per_active_day_km': 25,
  'distance_p50_km': 14.5,
  'distance_p90_km': 76,
  'duration_p50_min': 22,
  'duration_p90_min': 91,
  'mean_speed_kmh': 43,
  'distance_bins': [
    {
      'status': 'available',
      'duration_min': 60,
      'paired_energy_kwh': 3.24,
      'paired_distance_km': 18,
      'coverage': {
        'distance': setCoverage(),
        'duration': setCoverage(),
        'paired': setCoverage(),
      },
      'drives': 3,
      'lower_km': 0,
      'upper_km': 10,
      'distance_km': 18,
      'consumption_wh_km': 180,
      'evidence_filter': {
        'from': '2026-10-01T00:00:00Z',
        'to': '2026-10-28T11:00:00Z',
        'tz': 'Asia/Shanghai',
        'completed_only': true,
        'distance_min_km': 0,
        'distance_max_km': 10,
        'method': 'driving-match-v1',
        'version': 1,
      },
    },
  ],
  'weekday_bins': [
    for (var i = 1; i <= 7; i++)
      {
        'weekday': i,
        'distance_km': i * 10,
        'drives': i,
        'duration_min': i * 15,
        'status': 'available',
        'coverage': {'distance': setCoverage(), 'duration': setCoverage()},
      },
  ],
  'coverage': {
    'candidate_count': 20,
    'distance': setCoverage(),
    'duration': setCoverage(),
    'speed': setCoverage(),
    'paired': setCoverage(),
  },
};
http.Client usageClient(
  List<Uri> seen, {
  bool empty = false,
  http.Response Function(http.Request)? evidence,
}) => MockClient((r) async {
  seen.add(r.url);
  if (r.url.path.endsWith('/drives') && evidence != null) return evidence(r);
  if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
  if (r.url.path.endsWith('/summary')) return fixture('summary');
  if (r.url.path.endsWith('/meta')) {
    return http.Response(
      jsonEncode({
        'statistics_insights': {
          'contract_version': 'statistics-insights-v1',
          'minimum_server_version': '0.3.0',
          'features': {'driving_coverage': true, 'driving_analysis': true},
        },
      }),
      200,
    );
  }
  if (r.url.path.endsWith('/driving-analysis')) {
    return http.Response(
      jsonEncode(
        empty
            ? {...usageFixture(), 'status': 'no_records', 'active_days': 0}
            : usageFixture(),
      ),
      200,
    );
  }
  return http.Response(jsonEncode(statisticsInsightsFixture(r.url)), 200);
});
void main() {
  testWidgets('统计节奏读取服务端摘要与分布而不从日桶计算', (tester) async {
    final seen = <Uri>[];
    await openStats(
      tester,
      usageClient(seen),
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await tester.scrollUntilVisible(find.text('活跃 12 天'), 200);
    expect(find.text('活跃 12 天'), findsOneWidget);
    expect(
      seen.any(
        (u) =>
            u.path.endsWith('/driving-analysis') &&
            u.queryParameters['view'] == 'usage',
      ),
      isTrue,
    );
  });
  testWidgets('无已完成行程与未知指标明确区分', (tester) async {
    await openStats(
      tester,
      usageClient([], empty: true),
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await tester.scrollUntilVisible(find.text('区间内无已完成行程'), 200);
    expect(find.text('区间内无已完成行程'), findsOneWidget);
  });
  testWidgets('距离分组使用完整证据筛选且翻页保持原截止', (tester) async {
    final seen = <Uri>[];
    var now = DateTime.utc(2026, 10, 28, 11);
    final client = usageClient(
      seen,
      evidence: (r) {
        final d = jsonDecode(fixture('drives').body) as Map<String, dynamic>;
        final all = d['items'] as List;
        return http.Response(
          jsonEncode({
            'items': r.url.queryParameters['cursor'] == null
                ? [all.first]
                : [all.last],
            'next_cursor': r.url.queryParameters['cursor'] == null
                ? 'next'
                : null,
            'matched_drives': 3,
          }),
          200,
        );
      },
    );
    await openStats(
      tester,
      client,
      () => now,
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await tester.scrollUntilVisible(find.text('展开用车节奏').hitTestable(), 200);
    await tester.tap(find.text('展开用车节奏'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('0–10 km').hitTestable(), 200);
    await tester.tap(find.text('0–10 km'));
    await tester.pumpAndSettle();
    expect(find.textContaining('完整匹配 3 趟'), findsOneWidget);
    now = now.add(const Duration(hours: 1));
    await tester.tap(find.text('加载更多行程'));
    await tester.pumpAndSettle();
    final queries = seen.where((u) => u.path.endsWith('/drives')).toList();
    expect(queries.length, 2);
    expect(queries.first.queryParameters['distance_max_km'], '10');
    expect(
      queries.last.queryParameters['to'],
      queries.first.queryParameters['to'],
    );
    expect(queries.last.queryParameters['cursor'], 'next');
  });
  testWidgets('360宽深色200%节奏展开与分布可读无布局异常', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });
    await openStats(
      tester,
      usageClient([]),
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await tester.scrollUntilVisible(find.text('展开用车节奏').hitTestable(), 200);
    await tester.tap(find.text('展开用车节奏'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('一周的用车节奏').hitTestable(), 200);
    expect(tester.takeException(), isNull);
  });
}
