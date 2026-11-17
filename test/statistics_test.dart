import 'dart:async';

import 'package:flutter/material.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

Future<void> openStats(
  WidgetTester tester,
  http.Client client,
  DateTime Function() now,
  String Function() zone, {
  bool statisticsInsights = false,
}) async {
  final store = MemorySessionStore()
    ..value = jsonEncode({
      'site': 'https://example.com/prefix',
      'token': 'test',
      'expires_at': '2099-01-01T00:00:00Z',
    });
  var statisticsVisible = false;
  final boundary = MockClient((request) async {
    if (!statisticsInsights && request.url.path.endsWith('/meta')) {
      return fixture('meta');
    }
    if (!statisticsVisible && request.url.path.endsWith('/stats')) {
      return fixture('driving-stats');
    }
    final forwarded = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return http.Response.fromStream(await client.send(forwarded));
  });
  await tester.pumpWidget(
    MileafApp(
      client: boundary,
      sessionStore: store,
      trustStore: MemoryTrustStore(),
      vehiclePreferences: MemoryVehiclePreferences(),
      now: now,
      calendar: () async => CalendarContext(zone()),
    ),
  );
  await tester.pumpAndSettle();
  statisticsVisible = true;
  await tester.tap(find.text('统计'));
  await tester.pumpAndSettle();
}

http.Response fixture(String name) => http.Response(
  File('test/fixtures/$name.json').readAsStringSync(),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// 刷新动作在页头，滚动后可能正好停在顶栏的淡出区内；先让它落到视口中部
/// 再点，避免「量到位置却点不中」的假失败。
Future<void> tapRefresh(WidgetTester tester) async {
  final action = find.byTooltip('刷新统计');
  for (var i = 0; i < 20 && action.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 300));
    await tester.pumpAndSettle();
  }
  await Scrollable.ensureVisible(tester.element(action), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
}

/// All periods share the same stable custom-date entry label.
Finder dateAction() => find.widgetWithText(StatusChip, '自定义日期');

Future<void> tapDateAction(WidgetTester tester) async {
  final action = dateAction();
  for (var i = 0; i < 20 && action.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 300));
    await tester.pumpAndSettle();
  }
  expect(action, findsOneWidget, reason: '统计期间入口滚动后仍不可达');
  await Scrollable.ensureVisible(tester.element(action), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
}

/// Opens the C 日期 sheet and picks a preset period (本周/本月/近7天/本年).
Future<void> pickPeriod(WidgetTester tester, String label) async {
  await tapDateAction(tester);
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(StatusChip, label),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openDateSheet(WidgetTester tester) async {
  await tapDateAction(tester);
}

Future<void> custom(WidgetTester tester, String start, String end) async {
  await openDateSheet(tester);
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, '开始日期'), start);
  await tester.enterText(find.widgetWithText(TextField, '结束日期（含）'), end);
  await tester.tap(find.text('应用区间'));
  await tester.pumpAndSettle();
}

void resume(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

http.Client statsClient(List<Map<String, String>> queries) =>
    MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      queries.add(r.url.queryParameters);
      return fixture('driving-stats');
    });
void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('自定义统计日期在360宽${brightness.name} 字体缩放 $scale 下内容保持间距', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
          tester.platformDispatcher.clearPlatformBrightnessTestValue();
        });
        final queries = <Map<String, String>>[];
        await openStats(
          tester,
          statsClient(queries),
          () => DateTime.utc(2026, 10, 26, 12),
          () => 'Asia/Shanghai',
        );
        await openDateSheet(tester);
        final description = find.text('日期格式 YYYY-MM-DD；结束日期包含当天，今天截至当前时刻。');
        final start = find.widgetWithText(TextField, '开始日期');
        final end = find.widgetWithText(TextField, '结束日期（含）');
        expect(
          tester.getTopLeft(start).dy - tester.getBottomLeft(description).dy,
          greaterThanOrEqualTo(16),
        );
        expect(
          tester.getTopLeft(end).dy - tester.getBottomLeft(start).dy,
          greaterThanOrEqualTo(16),
        );
        await tester.enterText(start, 'invalid');
        await tester.tap(find.text('应用区间'));
        await tester.pumpAndSettle();
        final error = find.text('请输入有效日历日期 YYYY-MM-DD');
        expect(error, findsOneWidget);
        expect(
          tester.getTopLeft(error).dy - tester.getBottomLeft(end).dy,
          greaterThanOrEqualTo(12),
        );
        await tester.ensureVisible(end);
        await tester.pumpAndSettle();
        expect(end.hitTestable(), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('驾驶图表切换指标读取真实负值且不额外请求统计', (tester) async {
    final requests = <http.Request>[];
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      requests.add(r);
      final body =
          jsonDecode(fixture('driving-stats').body) as Map<String, dynamic>;
      body['buckets'][0]['energy_kwh'] = -3;
      body['buckets'][0]['consumption_wh_km_net'] = -25;
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 4, 2),
      () => 'Asia/Shanghai',
    );
    expect(find.widgetWithText(StatusChip, '里程'), findsOneWidget);
    final requestCount = requests.length;
    await tester.tap(find.widgetWithText(StatusChip, '能量'));
    await tester.pumpAndSettle();
    expect(find.text('能量趋势'), findsOneWidget);
    // R29：读数头数值行按共享格式化器输出「−3 kWh」。
    expect(find.text('−3 kWh'), findsWidgets);
    expect(requests.length, requestCount);
    await tester.scrollUntilVisible(find.text('净 / 毛电耗'), 250);
    expect(find.text('净 / 毛电耗'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('统计换区间失败后前台不能被旧区间有效缓存阻止恢复', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    var fail = false;
    final queries = <Map<String, String>>[];
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      queries.add(r.url.queryParameters);
      if (fail) return http.Response('', 503);
      return http.Response(
        fixture('driving-stats').body,
        200,
        headers: {
          'content-type': 'application/json; charset=utf-8',
          'cache-control': 'max-age=30',
        },
      );
    });
    await openStats(tester, client, () => now, () => 'UTC');
    fail = true;
    await pickPeriod(tester, '本周');
    await tester.pumpAndSettle();
    expect(find.textContaining('服务暂不可用'), findsOneWidget);
    fail = false;
    final count = queries.length;
    now = DateTime.utc(2026, 3, 30, 12, 0, 20);
    resume(tester);
    await tester.pumpAndSettle();
    expect(queries.length, count + 1);
    expect(queries.last['from'], '2026-03-30T00:00:00.000Z');
    expect(find.text('49 次'), findsOneWidget);
  });

  for (final range in ['default', 'today', 'history']) {
    testWidgets('统计当前kind前台遵守TTL且过期推进今天 $range', (tester) async {
      var now = DateTime.utc(2026, 3, 30, 12);
      final queries = <Map<String, String>>[];
      final client = MockClient((r) async {
        if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
        if (r.url.path.endsWith('/summary')) return fixture('summary');
        queries.add(r.url.queryParameters);
        return http.Response(
          fixture('driving-stats').body,
          200,
          headers: {
            'content-type': 'application/json; charset=utf-8',
            'cache-control': 'max-age=30',
          },
        );
      });
      await openStats(tester, client, () => now, () => 'UTC');
      if (range != 'default') {
        await custom(
          tester,
          '2026-03-29',
          range == 'today' ? '2026-03-30' : '2026-03-29',
        );
      }
      final first = queries.last;
      final count = queries.length;
      now = DateTime.utc(2026, 3, 30, 12, 0, 20);
      resume(tester);
      await tester.pumpAndSettle();
      expect(queries.length, count);
      now = DateTime.utc(2026, 3, 30, 14);
      resume(tester);
      await tester.pumpAndSettle();
      expect(queries.length, count + 1);
      expect(
        queries.last['to'],
        range == 'history' ? first['to'] : '2026-03-30T14:00:00.000Z',
      );
      expect(queries.last['from'], first['from']);
      expect(queries.every((q) => q['kind'] == 'driving'), isTrue);
    });
  }

  testWidgets('快速变更区间与切车时迟到统计不能覆盖当前结果', (tester) async {
    final pending = Completer<http.Response>();
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      if (r.url.queryParameters['bucket'] == 'month' &&
          r.url.path.contains('/1/')) {
        return pending.future;
      }
      final body = jsonDecode(
        File('test/fixtures/driving-stats.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      if (r.url.path.contains('/2/')) body['totals']['drives'] = 8;
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 3, 15, 12),
      () => 'UTC',
    );
    await pickPeriod(tester, '本年');
    await tester.pump();
    await tester.tap(find.text('行笺测试车'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Y · 尾号 0002'));
    await tester.pumpAndSettle();
    expect(find.text('8 次'), findsOneWidget);
    pending.complete(fixture('driving-stats'));
    await tester.pumpAndSettle();
    expect(find.text('49 次'), findsNothing);
    expect(find.text('8 次'), findsOneWidget);
  });
  testWidgets('360宽200%深色下桶文字读数可展开且null不同于真实零', (tester) async {
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
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      final body = jsonDecode(
        File('test/fixtures/driving-stats.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      body['totals']['drives'] = 0;
      body['totals']['distance_km'] = 0;
      body['totals']['energy_kwh'] = 0;
      body['totals']['consumption_wh_km_net'] = null;
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 5, 15, 12),
      () => 'UTC',
    );
    await tester.scrollUntilVisible(find.text('0 次'), 300);
    expect(find.text('0 次'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('净电耗  —'), 300);
    expect(find.text('净电耗  —'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('2025-12-31 · 620.0 km'),
      300,
    );
    // 200% 下该行停在视口边缘，滚动到“已构建”不等于可命中；先整行可见再展开。
    await tester.ensureVisible(find.textContaining('2025-12-31 · 620.0 km'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('2025-12-31 · 620.0 km'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('行程数  31 次'), 200);
    expect(find.text('行程数  31 次'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('周一和年起点、当前截止时间、31/32/180/181天分桶均通过App选择', (tester) async {
    final queries = <Map<String, String>>[];
    await openStats(
      tester,
      statsClient(queries),
      () => DateTime.utc(2026, 9, 15, 12),
      () => 'Asia/Shanghai',
    );
    await pickPeriod(tester, '本周');
    await tester.pumpAndSettle();
    expect(queries.last['from'], '2026-09-13T16:00:00.000Z');
    expect(queries.last['to'], '2026-09-15T12:00:00.000Z');
    expect(queries.last['bucket'], 'day');
    await pickPeriod(tester, '本年');
    await tester.pumpAndSettle();
    expect(queries.last['from'], '2025-12-31T16:00:00.000Z');
    expect(queries.last['bucket'], 'month');
    await custom(tester, '2026-01-01', '2026-01-31');
    expect(queries.last['bucket'], 'day');
    await tester.tap(dateAction());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '结束日期（含）'),
      '2026-02-01',
    );
    await tester.tap(find.text('应用区间'));
    await tester.pumpAndSettle();
    expect(queries.last['bucket'], 'week');
    await tester.tap(dateAction());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '结束日期（含）'),
      '2026-06-29',
    );
    await tester.tap(find.text('应用区间'));
    await tester.pumpAndSettle();
    expect(queries.last['bucket'], 'week');
    await tester.tap(dateAction());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '结束日期（含）'),
      '2026-06-30',
    );
    await tester.tap(find.text('应用区间'));
    await tester.pumpAndSettle();
    expect(queries.last['bucket'], 'month');
  });
  testWidgets('DST历史完整日期转为23小时和25小时UTC区间', (tester) async {
    final queries = <Map<String, String>>[];
    await openStats(
      tester,
      statsClient(queries),
      () => DateTime.utc(2026, 12, 15, 12),
      () => 'America/New_York',
    );
    await custom(tester, '2026-03-08', '2026-03-08');
    expect(queries.last['from'], '2026-03-08T05:00:00.000Z');
    expect(queries.last['to'], '2026-03-09T04:00:00.000Z');
    await tester.tap(dateAction());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '开始日期'),
      '2026-11-01',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '结束日期（含）'),
      '2026-11-01',
    );
    await tester.tap(find.text('应用区间'));
    await tester.pumpAndSettle();
    expect(queries.last['from'], '2026-11-01T04:00:00.000Z');
    expect(queries.last['to'], '2026-11-02T05:00:00.000Z');
  });
  testWidgets('UTC730天上界可查、731天和零跨度不发请求', (tester) async {
    final queries = <Map<String, String>>[];
    await openStats(
      tester,
      statsClient(queries),
      () => DateTime.utc(2026, 3, 16),
      () => 'UTC',
    );
    await custom(tester, '2024-03-16', '2026-03-15');
    expect(queries.last['from'], '2024-03-16T00:00:00.000Z');
    expect(queries.last['to'], '2026-03-16T00:00:00.000Z');
    final before = queries.length;
    await tester.tap(dateAction());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '开始日期'),
      '2024-03-15',
    );
    await tester.tap(find.text('应用区间'));
    await tester.pumpAndSettle();
    expect(find.textContaining('不超过 730×24 小时'), findsOneWidget);
    expect(queries.length, before);
    await tester.enterText(
      find.widgetWithText(TextField, '开始日期'),
      '2026-03-16',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '结束日期（含）'),
      '2026-03-16',
    );
    await tester.tap(find.text('应用区间'));
    await tester.pumpAndSettle();
    expect(queries.length, before);
    expect(find.textContaining('须大于 0'), findsOneWidget);
  });

  testWidgets('前台换时区保留自定义日历日期，旧时区快照立即清除', (tester) async {
    var zone = 'Asia/Shanghai';
    final pending = Completer<http.Response>();
    final queries = <Map<String, String>>[];
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      queries.add(r.url.queryParameters);
      if (zone == 'UTC') return pending.future;
      return fixture('driving-stats');
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 3, 15, 12),
      () => zone,
    );
    await custom(tester, '2026-03-01', '2026-03-02');
    expect(queries.last['from'], '2026-02-28T16:00:00.000Z');
    expect(queries.last['to'], '2026-03-02T16:00:00.000Z');
    zone = 'UTC';
    resume(tester);
    await tester.pump();
    await tester.pump();
    expect(find.text('49 次'), findsNothing);
    expect(queries.last['from'], '2026-03-01T00:00:00.000Z');
    expect(queries.last['to'], '2026-03-03T00:00:00.000Z');
    pending.complete(fixture('driving-stats'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026-03-01 至 2026-03-02'), findsOneWidget);
  });

  testWidgets('驾驶统计默认本月，真实响应totals不平均桶比率，手动304与失败保留快照', (tester) async {
    final requests = <http.Request>[];
    var fail = false;
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/meta')) return fixture('meta');
      if (r.url.path.endsWith('/vehicles')) {
        return http.Response(
          File('test/fixtures/vehicles.json').readAsStringSync(),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (r.url.path.endsWith('/summary')) {
        return http.Response(
          File('test/fixtures/summary.json').readAsStringSync(),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      requests.add(r);
      if (fail) return http.Response('', 503);
      if (r.headers['if-none-match'] != null) return http.Response('', 304);
      return http.Response(
        File('test/fixtures/driving-stats.json').readAsStringSync(),
        200,
        headers: {
          'content-type': 'application/json; charset=utf-8',
          'etag': '"driving"',
          'cache-control': 'max-age=30',
        },
      );
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 3, 15, 12),
      () => 'Asia/Shanghai',
    );
    expect(requests.single.url.queryParameters, {
      'kind': 'driving',
      'bucket': 'day',
      'from': '2026-02-28T16:00:00.000Z',
      'to': '2026-03-15T12:00:00.000Z',
      'tz': 'Asia/Shanghai',
    });
    expect(find.text('49 次'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('毛电耗  167 Wh/km'), 250);
    expect(find.text('毛电耗  167 Wh/km'), findsOneWidget);
    await tapRefresh(tester);
    await tester.pumpAndSettle();
    expect(requests.last.headers['if-none-match'], '"driving"');
    await tester.scrollUntilVisible(find.text('毛电耗  167 Wh/km'), 250);
    expect(find.text('毛电耗  167 Wh/km'), findsOneWidget);
    fail = true;
    await tapRefresh(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('保留上次快照'), findsOneWidget);
    expect(find.text('49 次'), findsOneWidget);
  });
}
