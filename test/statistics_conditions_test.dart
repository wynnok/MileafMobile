import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'statistics_test.dart' show openStats, pickPeriod, fixture;
import 'statistics_usage_test.dart' show usageClient, usageFixture, setCoverage;

Map<String, dynamic> conditionsFixture() => {
  'view': 'conditions',
  'status': 'available',
  'as_of': '2026-10-28T11:00:00Z',
  'method': 'temperature-association-v1',
  'version': 1,
  'validation': 'provisional',
  'query': usageFixture()['query'],
  'summary': usageFixture(),
  'distance_bins': usageFixture()['distance_bins'],
  'unknown_temperature_drives': 2,
  'thresholds': {'minimum_paired_drives': 5, 'minimum_paired_distance_km': 50},
  'temperature_bins': [
    for (final lower in [-5, 0, 5])
      {
        'lower_c': lower,
        'upper_c': lower + 5,
        'drives': 3,
        'distance_km': 30,
        'paired_energy_kwh': 5.25,
        'paired_distance_km': 25,
        'consumption_wh_km': lower == 5 ? null : 210,
        'median_drive_distance_km': 8,
        'mean_trip_speed_kmh': 32,
        'coverage': {
          ...(usageFixture()['coverage'] as Map<String, dynamic>),
          'candidate_count': 3,
          'paired': {
            ...setCoverage(),
            'valid_count': 2,
            'valid_distance_km': 25,
          },
        },
        'sample_status': lower == 5 ? 'insufficient_data' : 'sparse',
        'evidence_filter': {
          ...((usageFixture()['distance_bins'] as List).first['evidence_filter']
              as Map),
          'outside_temp_min_c': lower,
          'outside_temp_max_c': lower + 5,
        },
      },
  ],
};
Future<void> openConditions(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('能耗').hitTestable(), 200);
  await tester.tap(find.text('能耗').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('能耗条件显示负温度半开组与服务端配对值并下钻完整证据', (tester) async {
    final seen = <Uri>[];
    final base = usageClient(
      seen,
      evidence: (r) => http.Response(
        jsonEncode({
          'items': (jsonDecode(fixture('drives').body) as Map)['items'],
          'next_cursor': r.url.queryParameters['cursor'] == null
              ? 'temperature-next'
              : null,
          'matched_drives': 3,
        }),
        200,
      ),
    );
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/driving-analysis') &&
          r.url.queryParameters['view'] == 'conditions') {
        seen.add(r.url);
        return http.Response(jsonEncode(conditionsFixture()), 200);
      }
      return base.get(r.url);
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await openConditions(tester);
    expect(find.text('温度下的用车能耗'), findsOneWidget);
    expect(find.text('未知温度 2 趟'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.widgetWithText(ChoiceChip, '[-5, 0) °C'),
      120,
    );
    expect(find.text('[-5, 0) °C'), findsWidgets);
    await tester.scrollUntilVisible(find.textContaining('210 Wh/km'), -150);
    expect(find.textContaining('210 Wh/km'), findsWidgets);
    await tester.scrollUntilVisible(find.text('查看该温度组行程').hitTestable(), 200);
    await tester.tap(find.text('查看该温度组行程'));
    await tester.pumpAndSettle();
    expect(find.textContaining('完整匹配 3 趟'), findsOneWidget);
    expect(seen.last.queryParameters['outside_temp_min_c'], '-5');
    expect(seen.last.queryParameters['outside_temp_max_c'], '0');
    final firstQuery = Map<String, String>.from(seen.last.queryParameters);
    await tester.tap(find.text('加载更多行程'));
    await tester.pumpAndSettle();
    expect(seen.last.queryParameters['cursor'], 'temperature-next');
    expect({...seen.last.queryParameters}..remove('cursor'), firstQuery);
    expect(find.textContaining('完整匹配 3 趟'), findsOneWidget);
  });
  testWidgets('360宽深色200%温度选组区分零与缺失', (tester) async {
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
    final base = usageClient([]);
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/driving-analysis') &&
          r.url.queryParameters['view'] == 'conditions') {
        final d = conditionsFixture();
        (d['temperature_bins'] as List)[1]['consumption_wh_km'] = 0;
        return http.Response(jsonEncode(d), 200);
      }
      return base.get(r.url);
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await openConditions(tester);
    await tester.scrollUntilVisible(find.text('[0, 5) °C').hitTestable(), 120);
    await tester.tap(find.text('[0, 5) °C'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('0 Wh/km'), -120);
    expect(find.text('0 Wh/km'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('下一温度组').hitTestable(), 120);
    await tester.tap(find.text('下一温度组'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('— Wh/km'), -120);
    expect(find.text('配对样本不足'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('条件请求失败独立重试并保留上次快照', (tester) async {
    final base = usageClient([]);
    var fail = true;
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/driving-analysis') &&
          r.url.queryParameters['view'] == 'conditions') {
        return fail
            ? http.Response('{}', 500)
            : http.Response(jsonEncode(conditionsFixture()), 200);
      }
      return base.get(r.url);
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await openConditions(tester);
    expect(find.text('能耗条件读取失败'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('重试能耗条件'));
    await tester.pumpAndSettle();
    expect(find.text('未知温度 2 趟'), findsOneWidget);
    fail = true;
    await tester.tap(find.text('刷新能耗条件'));
    await tester.pumpAndSettle();
    expect(find.text('能耗条件读取失败，保留上次快照'), findsOneWidget);
    expect(find.text('未知温度 2 趟'), findsOneWidget);
  });
  testWidgets('章节专题返回后切换期间仅按新期间请求', (tester) async {
    final seen = <Uri>[];
    final base = usageClient(seen);
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/driving-analysis') &&
          r.url.queryParameters['view'] == 'conditions') {
        seen.add(r.url);
        return http.Response(jsonEncode(conditionsFixture()), 200);
      }
      return base.get(r.url);
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    expect(
      seen.where((u) => u.queryParameters['view'] == 'conditions'),
      isEmpty,
    );
    await openConditions(tester);
    final month = seen.last.queryParameters;
    expect(month['from'], '2026-09-30T16:00:00.000Z');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await pickPeriod(tester, '本周');
    await openConditions(tester);
    final week = seen.last.queryParameters;
    expect(week['from'], '2026-10-25T16:00:00.000Z');
    expect(week['tz'], 'Asia/Shanghai');
    expect(week['to'], month['to']);
    expect(seen.last.path, contains('/vehicles/1/'));
  });
  testWidgets('切车后迟到条件结果不能覆盖新车', (tester) async {
    final pending = Completer<http.Response>();
    final base = usageClient([]);
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/driving-analysis') &&
          r.url.queryParameters['view'] == 'conditions') {
        if (r.url.path.contains('/1/')) return pending.future;
        return http.Response(
          jsonEncode({...conditionsFixture(), 'unknown_temperature_drives': 7}),
          200,
        );
      }
      return base.get(r.url);
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await openConditions(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('行笺测试车'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Y · 尾号 0002'));
    await tester.pumpAndSettle();
    await openConditions(tester);
    expect(find.text('未知温度 7 趟'), findsOneWidget);
    pending.complete(http.Response(jsonEncode(conditionsFixture()), 200));
    await tester.pumpAndSettle();
    expect(find.text('未知温度 2 趟'), findsNothing);
    expect(find.text('未知温度 7 趟'), findsOneWidget);
  });
}
