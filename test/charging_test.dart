import 'dart:convert';
import 'dart:async';

import 'package:mileaf/src/currency.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;
import 'overview_test.dart' show background, foreground;

Map<String, dynamic> chargingFixture() =>
    jsonDecode(File('test/fixtures/charging-sessions.json').readAsStringSync())
        as Map<String, dynamic>;
http.Response jsonResponse(
  Object body, {
  Map<String, String> headers = const {},
}) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8', ...headers},
);
MemorySessionStore sessionStore() => MemorySessionStore()
  ..value = jsonEncode({
    'site': 'https://example.com/prefix',
    'token': 'test',
    'expires_at': '2099-01-01T00:00:00Z',
  });
Widget app(
  http.Client client, {
  Key? key,
  CurrencyPreferenceStore? currency,
  DateTime Function()? now,
  Future<CalendarContext> Function()? calendar,
}) => MileafApp(
  key: key,
  currencyPreferences: currency,
  client: client,
  trustStore: MemoryTrustStore(),
  sessionStore: sessionStore(),
  vehiclePreferences: MemoryVehiclePreferences(),
  now: now ?? () => DateTime.utc(2026, 3, 30, 12),
  calendar: calendar ?? () async => CalendarContext('UTC'),
);
http.Response initial(http.Request request) =>
    request.url.path.endsWith('/stats')
    ? http.Response(
        File('test/fixtures/driving-stats.json').readAsStringSync(),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      )
    : request.url.path.endsWith('/vehicles')
    ? http.Response(
        File('test/fixtures/vehicles.json').readAsStringSync(),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      )
    : http.Response(
        File('test/fixtures/summary.json').readAsStringSync(),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

class MemoryCurrency implements CurrencyPreferenceStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String site) async => values[site];
  @override
  Future<void> write(String site, String? code) async {
    if (code == null) {
      values.remove(site);
    } else {
      values[site] = code;
    }
  }
}

class DelayedCurrency implements CurrencyPreferenceStore {
  final pending = Completer<String?>();
  String? written;
  @override
  Future<String?> read(String site) => pending.future;
  @override
  Future<void> write(String site, String? code) async {
    written = code;
  }
}

void main() {
  testWidgets('充电卡片按本地日期分组并以统一尺度呈现真实起止电量', (tester) async {
    final client = MockClient(
      (r) async => r.url.path.endsWith('/charging-sessions')
          ? jsonResponse(chargingFixture())
          : initial(r),
    );
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('电量区间.*40.*70.*尺度0至100%')),
      findsOneWidget,
    );
    expect(find.text('2026年3月29日'), findsWidgets);
  });
  testWidgets('用户已选币种不被迟到的旧偏好恢复覆盖', (tester) async {
    final currency = DelayedCurrency();
    final client = MockClient(
      (r) async => r.url.path.endsWith('/charging-sessions')
          ? jsonResponse(chargingFixture())
          : initial(r),
    );
    await tester.pumpWidget(app(client, currency: currency));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('站点币种'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD'));
    await tester.pumpAndSettle();
    expect(currency.written, 'USD');
    currency.pending.complete('CNY');
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    expect(find.text('费用 12 USD'), findsWidgets);
    expect(find.textContaining('CNY'), findsNothing);
  });

  testWidgets('充电程序滚动不翻页，重复游标停止自动请求且可手动恢复', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final requests = <Uri>[];
    var recover = false;
    final client = MockClient((r) async {
      if (!r.url.path.endsWith('/charging-sessions')) return initial(r);
      requests.add(r.url);
      final body = chargingFixture();
      body['items'] = [body['items'][0]];
      body['next_cursor'] = recover ? null : 'same-cursor';
      return jsonResponse(body);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('充电 #9 · 查看详情'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('加载更多充电'));
    await tester.pumpAndSettle();
    expect(requests.length, 1);
    await tester.tap(find.text('加载更多充电'));
    await tester.pumpAndSettle();
    expect(requests.length, 2);
    await tester.scrollUntilVisible(find.textContaining('分页游标未前进'), -300);
    await tester.pumpAndSettle();
    expect(find.textContaining('分页游标未前进'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(requests.length, 2);
    expect(find.text('充电 #9 · 查看详情'), findsOneWidget);
    recover = true;
    await tester.scrollUntilVisible(find.text('重试充电'), -300);
    await tester.tap(find.text('重试充电'));
    await tester.pumpAndSettle();
    expect(requests.length, 3);
    expect(find.textContaining('分页游标未前进'), findsNothing);
    await tester.scrollUntilVisible(find.text('已到最后一条'), 200);
    expect(find.text('已到最后一条'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final range in ['default', 'today', 'history']) {
    testWidgets('充电前台按TTL校验并推进含今天窗口 $range', (tester) async {
      var now = DateTime.utc(2026, 3, 30, 12);
      final queries = <Map<String, String>>[];
      final client = MockClient((r) async {
        if (!r.url.path.endsWith('/charging-sessions')) return initial(r);
        queries.add(r.url.queryParameters);
        return jsonResponse(
          {'items': [], 'next_cursor': 'page2'},
          headers: {'cache-control': 'max-age=30'},
        );
      });
      await tester.pumpWidget(app(client, now: () => now));
      await tester.pumpAndSettle();
      await tester.tap(find.text('充电'));
      await tester.pumpAndSettle();
      if (range != 'default') {
        await tester.tap(find.text('筛选充电日期'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, '开始日期 YYYY-MM-DD'),
          '2026-03-29',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, '结束日期 YYYY-MM-DD'),
          range == 'today' ? '2026-03-30' : '2026-03-29',
        );
        await tester.tap(find.text('应用日期'));
        await tester.pumpAndSettle();
      }
      final initialQuery = queries.last;
      final count = queries.length;
      now = DateTime.utc(2026, 3, 30, 12, 0, 20);
      background(tester);
      foreground(tester);
      await tester.pumpAndSettle();
      expect(queries.length, count);
      now = DateTime.utc(2026, 3, 30, 14);
      background(tester);
      foreground(tester);
      await tester.pumpAndSettle();
      expect(queries.length, count + 1);
      expect(
        queries.last['to'],
        range == 'history' ? initialQuery['to'] : '2026-03-30T14:00:00.000Z',
      );
      expect(queries.last['from'], initialQuery['from']);
      expect(queries.last.containsKey('cursor'), isFalse);
    });
  }

  testWidgets('充电tab读取固定后端分页样本并区分能量、进行中和未知币种', (tester) async {
    final client = MockClient((request) async {
      if (!request.url.path.endsWith('/charging-sessions')) {
        return initial(request);
      }
      expect(request.url.path, '/prefix/v1/vehicles/1/charging-sessions');
      expect(request.url.queryParameters, {
        'limit': '20',
        'from': '2026-03-01T00:00:00.000Z',
        'to': '2026-03-30T12:00:00.000Z',
      });
      return jsonResponse(chargingFixture());
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    expect(find.textContaining('充入电池 20 kWh'), findsWidgets);
    expect(find.textContaining('电网侧 22 kWh'), findsWidgets);
    expect(find.textContaining('费用 12（币种未知）'), findsWidgets);
    await tester.scrollUntilVisible(find.textContaining('· 进行中'), 200);
    expect(find.textContaining('· 进行中'), findsOneWidget);
    expect(find.textContaining('AC'), findsWidgets);
    expect(find.textContaining('¥'), findsNothing);
  });
  testWidgets('翻页失败保留、重试去重、刷新回首游标且304复用首响应', (tester) async {
    var fail = true;
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      if (!request.url.path.endsWith('/charging-sessions')) {
        return initial(request);
      }
      requests.add(request);
      if (request.url.queryParameters.containsKey('cursor')) {
        if (fail) return http.Response('', 503);
        final body = chargingFixture();
        final extra = Map<String, dynamic>.from((body['items'] as List).first)
          ..['id'] = 7;
        body['items'] = [(body['items'] as List).last, extra];
        body['next_cursor'] = null;
        return jsonResponse(body);
      }
      if (request.headers['if-none-match'] == '"charges"') {
        return http.Response('', 304);
      }
      return jsonResponse(
        chargingFixture(),
        headers: {'etag': '"charges"', 'cache-control': 'max-age=60'},
      );
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('加载更多充电'), 400);
    await tester.tap(find.text('加载更多充电'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('保留已加载记录'), -300);
    expect(find.textContaining('保留已加载记录'), findsOneWidget);
    fail = false;
    await tester.scrollUntilVisible(find.text('重试充电'), -300);
    await tester.tap(find.text('重试充电'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('充电 #7 · 查看详情'), 300);
    expect(find.text('充电 #7 · 查看详情'), findsOneWidget);
    expect(
      requests.last.url.queryParameters['cursor'],
      'MjAyNi0wMy0xNVQxMTowMDowMCswMDowMHw4',
    );
    await tester.scrollUntilVisible(find.byTooltip('刷新充电'), -500);
    await tester.tap(find.byTooltip('刷新充电'));
    await tester.pumpAndSettle();
    expect(requests.last.url.queryParameters.containsKey('cursor'), isFalse);
    expect(requests.last.headers['if-none-match'], '"charges"');
    expect(find.text('充电 #7 · 查看详情'), findsNothing);
  });
  testWidgets('历史日期含首尾且跨DST使用日历边界，区间改变清除旧内容', (tester) async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      if (!request.url.path.endsWith('/charging-sessions')) {
        return initial(request);
      }
      requests.add(request);
      return jsonResponse(chargingFixture());
    });
    await tester.pumpWidget(
      app(client, calendar: () async => CalendarContext('America/New_York')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('筛选充电日期'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '开始日期 YYYY-MM-DD'),
      '2026-03-08',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '结束日期 YYYY-MM-DD'),
      '2026-03-08',
    );
    await tester.tap(find.text('应用日期'));
    await tester.pumpAndSettle();
    expect(
      requests.last.url.queryParameters['from'],
      '2026-03-08T05:00:00.000Z',
    );
    expect(requests.last.url.queryParameters['to'], '2026-03-09T04:00:00.000Z');
    expect(requests.last.url.queryParameters.containsKey('cursor'), isFalse);
  });
  testWidgets('费用零和缺失不混淆，设置只改当前站点标签，重启后可恢复', (tester) async {
    final currency = MemoryCurrency();
    final client = MockClient((request) async {
      if (!request.url.path.endsWith('/charging-sessions')) {
        return initial(request);
      }
      final body = chargingFixture();
      body['items'][0]['cost'] = 0;
      body['items'][0]['is_dc'] = null;
      body['items'][0]['location']['display_name'] = null;
      body['items'][1]['cost'] = null;
      body['next_cursor'] = null;
      return jsonResponse(body);
    });
    await tester.pumpWidget(
      app(client, currency: currency, key: const ValueKey('first')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    expect(find.text('费用 0（币种未知）'), findsOneWidget);
    expect(find.text('分类未知'), findsOneWidget);
    expect(find.text('未知地点'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('费用 —（缺失）'), 200);
    expect(find.text('费用 —（缺失）'), findsOneWidget);
    await tester.tap(find.text('概览'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('站点币种'));
    await tester.pumpAndSettle();
    expect(find.textContaining('不换汇'), findsOneWidget);
    await tester.tap(find.text('USD'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    expect(find.text('费用 0 USD'), findsOneWidget);
    await tester.pumpWidget(
      app(client, currency: currency, key: const ValueKey('restart')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    expect(find.text('费用 0 USD'), findsOneWidget);
    expect(currency.values, {'https://example.com/prefix': 'USD'});
  });
  testWidgets('快速切车旧页最后完成不能串车，前台换日和时区按当前车重新取数', (tester) async {
    final old = Completer<http.Response>();
    var now = DateTime.utc(2026, 3, 30, 23, 59);
    var zone = 'UTC';
    final queries = <Uri>[];
    final client = MockClient((request) async {
      if (!request.url.path.endsWith('/charging-sessions')) {
        return initial(request);
      }
      queries.add(request.url);
      if (request.url.path.contains('/1/')) return old.future;
      final body = chargingFixture();
      body['items'] = [
        Map<String, dynamic>.from(body['items'][0])..['id'] = 77,
      ];
      body['next_cursor'] = null;
      return jsonResponse(body, headers: {'cache-control': 'max-age=3600'});
    });
    await tester.pumpWidget(
      app(client, now: () => now, calendar: () async => CalendarContext(zone)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pump();
    await tester.tap(find.text('行笺测试车'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Y · 尾号 0002'));
    await tester.pumpAndSettle();
    old.complete(jsonResponse(chargingFixture()));
    await tester.pumpAndSettle();
    expect(find.text('充电 #9 · 查看详情'), findsNothing);
    await tester.scrollUntilVisible(find.text('充电 #77 · 查看详情'), 300);
    expect(find.text('充电 #77 · 查看详情'), findsOneWidget);
    now = DateTime.utc(2026, 3, 31, 0, 1);
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(queries.last.queryParameters['from'], '2026-03-02T00:00:00.000Z');
    zone = 'Asia/Shanghai';
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(queries.last.path, '/prefix/v1/vehicles/2/charging-sessions');
    expect(queries.last.queryParameters['from'], '2026-03-01T16:00:00.000Z');
    await tester.scrollUntilVisible(
      find.textContaining('时区：Asia/Shanghai'),
      -300,
    );
    expect(find.textContaining('时区：Asia/Shanghai'), findsOneWidget);
  });
  testWidgets('360宽200%字深色下日期错误不发请求，空列表与详情目标可恢复导航', (tester) async {
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
    var empty = false;
    final requests = <Uri>[];
    final client = MockClient((request) async {
      if (!request.url.path.endsWith('/charging-sessions')) {
        return initial(request);
      }
      requests.add(request.url);
      return jsonResponse(
        empty ? {'items': [], 'next_cursor': null} : chargingFixture(),
      );
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('筛选充电日期'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '开始日期 YYYY-MM-DD'),
      '2026-02-30',
    );
    await tester.tap(find.text('应用日期'));
    await tester.pumpAndSettle();
    expect(find.textContaining('请输入有效日期'), findsOneWidget);
    expect(requests.length, 1);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('充电 #9 · 查看详情').hitTestable(),
      200,
    );
    await tester.tap(find.text('充电 #9 · 查看详情').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('充电详情 #9'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    empty = true;
    await tester.scrollUntilVisible(find.byTooltip('刷新充电'), -400);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('刷新充电'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('此区间无充电记录'), 200);
    expect(find.text('此区间无充电记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('手动刷新今天窗口截到新的当前时刻且不携旧游标', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final requests = <Uri>[];
    final client = MockClient((request) async {
      if (!request.url.path.endsWith('/charging-sessions')) {
        return initial(request);
      }
      requests.add(request.url);
      return jsonResponse(chargingFixture());
    });
    await tester.pumpWidget(app(client, now: () => now));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    now = DateTime.utc(2026, 3, 30, 12, 5);
    await tester.tap(find.byTooltip('刷新充电'));
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['to'], '2026-03-30T12:05:00.000Z');
    expect(requests.last.queryParameters.containsKey('cursor'), isFalse);
  });
}
