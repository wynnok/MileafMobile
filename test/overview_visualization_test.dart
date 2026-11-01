import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/workspace.dart';
import 'package:mileaf/src/currency.dart';

import 'overview_test.dart' show background, foreground;
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

Finder battery(int level) => find.bySemanticsLabel('电池电量 $level%');

Map<String, dynamic> overviewFixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
        as Map<String, dynamic>;
Map<String, dynamic> monthTrend({num firstDistance = 30.5}) {
  final body = overviewFixture('driving-stats');
  final bucket = Map<String, dynamic>.from(body['buckets'][0] as Map);
  body['buckets'] = [
    {
      ...bucket,
      'bucket_start': '2026-02-28T16:00:00Z',
      'distance_km': firstDistance,
    },
    {...bucket, 'bucket_start': '2026-03-01T16:00:00Z', 'distance_km': 0.0},
  ];
  return body;
}

http.Response overviewResponse(Object body, {String? etag, int maxAge = 30}) =>
    http.Response(
      jsonEncode(body),
      200,
      headers: {
        'content-type': 'application/json; charset=utf-8',
        'cache-control': 'max-age=$maxAge',
        'etag': ?etag,
      },
    );
Future<void> openOverviewVisual(
  WidgetTester tester,
  Future<http.Response> Function(http.Request request) handler, {
  DateTime Function()? now,
  Future<CalendarContext> Function()? calendar,
  bool settle = true,
  bool briefing = false,
  bool ownerCapabilities = false,
  CurrencyPreferenceStore? currencyPreferences,
}) async {
  final store = MemorySessionStore()
    ..value = jsonEncode({
      'site': 'https://example.com/prefix',
      'token': 'test',
      'expires_at': '2099-01-01T00:00:00Z',
    });
  await tester.pumpWidget(
    MileafApp(
      client: MockClient((request) async {
        if (!ownerCapabilities && request.url.path.endsWith('/meta')) {
          return overviewResponse(overviewFixture('meta'));
        }
        if (request.url.path.endsWith('/vehicles')) {
          return overviewResponse(
            jsonDecode(File('test/fixtures/vehicles.json').readAsStringSync()),
          );
        }
        // The original suite isolates summary/current driving. The briefing
        // suite opts in to all newly added HTTP resources and their races.
        if (!briefing && request.url.path.endsWith('/stats')) {
          if (request.url.queryParameters['kind'] == 'charging') {
            return overviewResponse(overviewFixture('charging-stats'));
          }
          final cutoff = DateTime.parse(request.url.queryParameters['to']!);
          if (cutoff.isBefore(
            (now?.call() ?? DateTime.utc(2026, 3, 15, 12)).subtract(
              const Duration(days: 20),
            ),
          )) {
            return overviewResponse(overviewFixture('driving-stats'));
          }
        }
        return handler(request);
      }),
      sessionStore: store,
      trustStore: MemoryTrustStore(),
      vehiclePreferences: MemoryVehiclePreferences(),
      now: now ?? () => DateTime.utc(2026, 3, 15, 12),
      calendar: calendar ?? () async => CalendarContext('Asia/Shanghai'),
      currencyPreferences: currencyPreferences,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }
  }
}

void main() {
  testWidgets('C概览每日统计查询保留时区和当前截止，零桶不崩溃', (tester) async {
    final semantics = tester.ensureSemantics();
    final queries = <Map<String, String>>[];
    await openOverviewVisual(tester, (request) async {
      if (request.url.path.endsWith('/summary')) {
        return overviewResponse(overviewFixture('summary'));
      }
      expect(request.url.path, '/prefix/v1/vehicles/1/stats');
      queries.add(request.url.queryParameters);
      return overviewResponse(monthTrend());
    });
    expect(queries, [
      {
        'kind': 'driving',
        'bucket': 'day',
        'from': '2026-02-28T16:00:00.000Z',
        'to': '2026-03-15T12:00:00.000Z',
        'tz': 'Asia/Shanghai',
      },
    ]);
    expect(find.bySemanticsLabel('每日里程图表'), findsOneWidget);
    // C removes the A 前一个/后一个采样 steppers; readings stay reachable
    // through the chart itself and its selected-value footer.
    expect(find.text('前一个采样'), findsNothing);
    expect(find.text('后一个采样'), findsNothing);
    expect(find.textContaining('30.5 km'), findsWidgets);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
  for (final failedResource in ['summary', 'stats']) {
    testWidgets('C概览$failedResource局部失败不遮蔽另一区域，重试只读失败资源', (tester) async {
      final semantics = tester.ensureSemantics();
      final calls = <String, int>{'summary': 0, 'stats': 0};
      var failing = true;
      await openOverviewVisual(tester, (request) async {
        final resource = request.url.path.endsWith('/summary')
            ? 'summary'
            : 'stats';
        calls[resource] = calls[resource]! + 1;
        if (failing && resource == failedResource) {
          return http.Response('', 503);
        }
        return overviewResponse(
          resource == 'summary' ? overviewFixture('summary') : monthTrend(),
        );
      });
      if (failedResource == 'stats') {
        expect(battery(68), findsOneWidget);
      } else {
        expect(find.textContaining('960'), findsOneWidget);
      }
      expect(find.textContaining('服务暂不可用'), findsOneWidget);
      failing = false;
      final retry = find.text(failedResource == 'stats' ? '重试里程趋势' : '重试概览');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(calls[failedResource], 2);
      expect(calls[failedResource == 'stats' ? 'summary' : 'stats'], 1);
      await tester.scrollUntilVisible(battery(68), -150);
      await tester.pumpAndSettle();
      expect(battery(68), findsOneWidget);
      expect(find.textContaining('960'), findsOneWidget);
      expect(find.textContaining('服务暂不可用'), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
  testWidgets('C概览趋势前台遵守TTL，过期推进截止，独立304和刷新失败保留图形', (tester) async {
    final semantics = tester.ensureSemantics();
    var now = DateTime.utc(2026, 3, 15, 12);
    final requests = <http.Request>[];
    var fail = false;
    await openOverviewVisual(tester, (request) async {
      if (request.url.path.endsWith('/summary')) {
        return overviewResponse(overviewFixture('summary'));
      }
      requests.add(request);
      if (fail) return http.Response('', 503);
      if (request.headers['if-none-match'] == '"trend"') {
        return http.Response('', 304);
      }
      return overviewResponse(monthTrend(), etag: '"trend"');
    }, now: () => now);
    now = now.add(const Duration(seconds: 20));
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    now = now.add(const Duration(seconds: 20));
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
    expect(requests.last.url.queryParameters['to'], '2026-03-15T12:00:40.000Z');
    await tester.drag(find.byType(RefreshIndicator), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(requests, hasLength(3));
    expect(requests.last.headers['if-none-match'], '"trend"');
    expect(find.textContaining('960'), findsOneWidget);
    fail = true;
    await tester.drag(find.byType(RefreshIndicator), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(requests, hasLength(4));
    await tester.scrollUntilVisible(find.textContaining('保留上次趋势快照'), -150);
    expect(find.textContaining('保留上次趋势快照'), findsOneWidget);
    expect(find.textContaining('960'), findsOneWidget);
    await tester.scrollUntilVisible(battery(68), -150);
    expect(battery(68), findsOneWidget);
    semantics.dispose();
  });
  testWidgets('C概览切车后迟到旧趋势不覆盖新车summary', (tester) async {
    final semantics = tester.ensureSemantics();
    final old = Completer<http.Response>();
    await openOverviewVisual(tester, (request) async {
      if (request.url.path.endsWith('/summary')) {
        final body = overviewFixture('summary');
        if (request.url.path.contains('/2/')) {
          body['vehicle']['id'] = 2;
          body['battery']['level'] = 21;
        }
        return overviewResponse(body);
      }
      if (request.url.path.contains('/1/')) return old.future;
      return overviewResponse(monthTrend(firstDistance: 88));
    }, settle: false);
    expect(battery(68), findsOneWidget);
    await tester.tap(find.text('行笺测试车'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Y · 尾号 0002'));
    await tester.pumpAndSettle();
    expect(battery(21), findsOneWidget);
    expect(find.textContaining('88.0 km'), findsWidgets);
    old.complete(overviewResponse(monthTrend(firstDistance: 4)));
    await tester.pumpAndSettle();
    expect(battery(21), findsOneWidget);
    expect(battery(68), findsNothing);
    expect(find.textContaining('4.0 km'), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
  testWidgets('C概览360x800首屏露出车况hero、本月主数与每日里程绘图区', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final semantics = tester.ensureSemantics();
    await openOverviewVisual(
      tester,
      (request) async => overviewResponse(
        request.url.path.endsWith('/summary')
            ? overviewFixture('summary')
            : monthTrend(),
      ),
    );
    expect(
      tester.getSize(find.bySemanticsLabel('本月驾驶里程 960.0 km，49 趟')).width,
      greaterThan(150),
    );
    final graph = tester.getRect(find.bySemanticsLabel('每日里程图表'));
    final viewport = tester.getRect(find.byType(RefreshIndicator));
    expect(graph.top, greaterThanOrEqualTo(viewport.top));
    expect(graph.bottom, lessThanOrEqualTo(viewport.bottom));
    expect(battery(68), findsOneWidget);
    expect(find.textContaining('320').hitTestable(), findsWidgets);
    expect(find.text('今日 km').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
