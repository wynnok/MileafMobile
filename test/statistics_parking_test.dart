import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'statistics_test.dart' show openStats, fixture;
import 'support/statistics_insights_fixture.dart';

Map<String, dynamic> aggregate({bool empty = false}) => {
  'candidate_windows': 4,
  'valid_windows': empty ? 0 : 2,
  'excluded_windows': 1,
  'open_windows': 1,
  'observed_hours': empty ? 0 : 12,
  'soc_change_pp': empty ? null : -2,
  'soc_change_pp_per_24h': empty ? null : -4,
  'online_hours': 2,
  'asleep_hours': 6,
  'offline_hours': 1,
  'unknown_hours': 3,
  'online_share': 1 / 6,
  'asleep_share': .5,
  'offline_share': 1 / 12,
  'unknown_share': .25,
  'excluded_by_reason': {'missing_soc': 1},
};
Map<String, dynamic> parkingResponse(Uri uri, {bool empty = false}) => {
  'status': empty ? 'insufficient_data' : 'available',
  'query': {
    'vehicle_id': 1,
    ...Map<String, String>.from(uri.queryParameters)..remove('cursor'),
    'time_basis': 'window_start',
    'filters': {},
  },
  'as_of': '2026-10-29T12:00:00Z',
  'totals': aggregate(empty: empty),
  'buckets': [
    for (final change in [-2, 0, 1])
      {
        'bucket_start': uri.queryParameters['from'],
        ...aggregate(empty: empty),
        'soc_change_pp': empty ? null : change,
      },
  ],
  'matched_windows': 4,
  'next_cursor': uri.queryParameters.containsKey('cursor') ? null : 'page2',
  'items': [
    if (!uri.queryParameters.containsKey('cursor'))
      for (final quality in ['complete', 'partial_state_coverage', 'excluded'])
        {
          'window_id': quality,
          'start_event': {'type': 'drive', 'id': 1},
          'end_event': {'type': 'charge', 'id': 2},
          'window_start': '2026-10-27T22:00:00Z',
          'window_end': '2026-10-28T12:00:00Z',
          'duration_hours': 14,
          'start': {
            'raw_time': '2026-10-27T22:00:00Z',
            'soc': 70,
            'soc_source': 'drive_end_position',
            'odometer_km': 100,
            'odometer_source': 'drive_end_position',
            'position_id': 1,
          },
          'end': {
            'raw_time': '2026-10-28T12:00:00Z',
            'soc': quality == 'excluded' ? null : 69,
            'soc_source': 'charging_start_battery_level',
            'odometer_km': 99.8,
            'odometer_source': 'charging_start_position',
            'position_id': 2,
          },
          'included': quality != 'excluded',
          'quality': quality,
          'exclusion_reason': quality == 'excluded' ? 'missing_soc' : null,
          'soc_change_pp': quality == 'excluded' ? null : -1,
          'soc_change_pp_per_24h': quality == 'excluded' ? null : -1.714,
          'odometer_change_km': -.2,
          'negative_odometer_change': true,
          'online_hours': 2,
          'asleep_hours': 8,
          'offline_hours': 1,
          'unknown_hours': 3,
        },
    if (uri.queryParameters.containsKey('cursor'))
      {
        'window_id': uri.queryParameters.containsKey('cursor')
            ? 'open-tail'
            : 'closed-1',
        'start_event': {'type': 'drive', 'id': 1},
        'end_event': null,
        'window_start': '2026-10-28T00:00:00Z',
        'window_end': null,
        'duration_hours': null,
        'start': {
          'raw_time': '2026-10-28T00:00:00Z',
          'soc': 70,
          'soc_source': 'drive_end_position',
          'odometer_km': 100,
          'odometer_source': 'drive_end_position',
          'position_id': 1,
          'rated_range_km': 300,
        },
        'end': {},
        'included': false,
        'quality': 'open_window',
        'exclusion_reason': null,
        'soc_change_pp': null,
        'soc_change_pp_per_24h': null,
        'odometer_change_km': null,
        'negative_odometer_change': false,
        'online_hours': 0,
        'asleep_hours': 0,
        'offline_hours': 0,
        'unknown_hours': 1,
      },
  ],
};
Future<void> openParking(
  WidgetTester tester,
  List<Uri> requests, {
  bool empty = false,
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
              features: {
                'driving_coverage': true,
                'parking_observations': true,
              },
            ),
          ),
          200,
        );
      }
      if (r.url.path.endsWith('/parking-observations')) {
        requests.add(r.url);
        if (fail) return http.Response('{}', 503);
        return http.Response(
          jsonEncode(parkingResponse(r.url, empty: empty)),
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
  testWidgets('360宽双倍字号完整页可滚动无溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await openParking(tester, <Uri>[]);
    await tester.ensureVisible(find.text('展开停放观察'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('展开停放观察'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('加载更多窗口'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('停车资源失败保留统计承载并可独立重试', (tester) async {
    final requests = <Uri>[];
    await openParking(tester, requests, fail: true);
    expect(find.text('停放观察读取失败'), findsOneWidget);
    await tester.ensureVisible(find.text('重试停放观察'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重试停放观察'));
    await tester.pumpAndSettle();
    expect(requests.length, 2);
    expect(find.text('用车洞察'), findsOneWidget);
  });
  testWidgets('停车服务端汇总与冻结分页证据独立显示', (tester) async {
    final requests = <Uri>[];
    await openParking(tester, requests);
    expect(find.textContaining('停放SOC变化'), findsWidgets);
    await tester.ensureVisible(find.text('展开停放观察'));
    await tester.tap(find.text('展开停放观察'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('parking-trend-chart')), findsOneWidget);
    expect(find.textContaining('-2.0 pp'), findsWidgets);
    await tester.ensureVisible(find.text('后一点'));
    await tester.tap(find.text('后一点'));
    await tester.pumpAndSettle();
    expect(find.textContaining('0.0 pp'), findsWidgets);
    await tester.tap(find.text('后一点'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1.0 pp'), findsWidgets);
    await tester.ensureVisible(find.text('加载更多窗口'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加载更多窗口'));
    await tester.pumpAndSettle();
    expect(
      requests.last.queryParameters['to'],
      requests.first.queryParameters['to'],
    );
    expect(requests.last.queryParameters['cursor'], 'page2');
    expect(find.textContaining('open-tail'), findsWidgets);
    expect(find.textContaining('-2.0 pp'), findsWidgets);
    expect(find.textContaining('partial_state_coverage'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('无有效窗口不展示零损耗', (tester) async {
    await openParking(tester, <Uri>[], empty: true);
    expect(find.textContaining('— pp'), findsWidgets);
  });
}
