import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';

import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';

import 'package:mileaf/src/workspace.dart';

import 'widget_test.dart' show MemoryTrustStore;

http.Response overviewTrendResponse() => http.Response(
  File('test/fixtures/driving-stats.json').readAsStringSync(),
  200,
  headers: {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'max-age=30',
  },
);

void background(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void foreground(WidgetTester tester) {
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

void main() {
  testWidgets('概览读取固定后端样本，条件刷新304保留采样并显示独立校验时间', (tester) async {
    final store = MemorySessionStore()
      ..value = jsonEncode({
        'site': 'https://example.com/prefix',
        'token': 'test',
        'expires_at': '2099-01-01T00:00:00Z',
      });
    var refreshed = false;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/stats')) return overviewTrendResponse();
      if (request.url.path.endsWith('/vehicles')) {
        return http.Response(
          File('test/fixtures/vehicles.json').readAsStringSync(),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      expect(request.url.path, '/prefix/v1/vehicles/1/summary');
      expect(request.url.queryParameters['tz'], 'UTC');
      if (request.headers['if-none-match'] == '"summary"') {
        refreshed = true;
        return http.Response('', 304);
      }
      return http.Response(
        File('test/fixtures/summary.json').readAsStringSync(),
        200,
        headers: {
          'etag': '"summary"',
          'cache-control': 'max-age=30',
          'content-type': 'application/json; charset=utf-8',
        },
      );
    });
    await tester.pumpWidget(
      MileafApp(
        client: client,
        trustStore: MemoryTrustStore(),
        sessionStore: store,
        vehiclePreferences: MemoryVehiclePreferences(),
        calendar: () async => CalendarContext("UTC"),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('68 %'), findsOneWidget);
    expect(find.textContaining('320.0 km'), findsOneWidget);
    expect(find.textContaining('额定续航'), findsOneWidget);
    await tester.tap(find.byTooltip('刷新概览'));
    await tester.pumpAndSettle();
    expect(refreshed, isTrue);
    expect(find.textContaining('68 %'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('位置采样'), 300);
    expect(find.textContaining('位置采样'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('车辆与数据时间'), 300);
    await tester.tap(find.text('车辆与数据时间'));
    await tester.pumpAndSettle();
    final noVisibleBorderPaths = paints
      ..everything(
        (method, arguments) =>
            method != #drawPath || (arguments.last as Paint).color.a == 0,
      );
    expect(
      tester.renderObject(find.byType(ExpansionTile)),
      noVisibleBorderPaths,
      reason: '车辆与数据时间卡片展开后不应绘制额外的上下分隔线',
    );
    await tester.scrollUntilVisible(find.textContaining('校验时间'), 300);
    expect(find.textContaining('校验时间'), findsOneWidget);
    await tester.ensureVisible(find.text('车辆与数据时间'));
    await tester.tap(find.text('车辆与数据时间'));
    await tester.pumpAndSettle();
    expect(
      tester.renderObject(find.byType(ExpansionTile)),
      noVisibleBorderPaths,
      reason: '车辆与数据时间卡片收起后不应绘制额外的上下分隔线',
    );
  });
  testWidgets('快速切车不显示旧车迟到内容，选择能在重启恢复，刷新失败保留本车快照', (tester) async {
    final store = MemorySessionStore()
      ..value = jsonEncode({
        'site': 'https://example.com/prefix',
        'token': 'test',
        'expires_at': '2099-01-01T00:00:00Z',
      });
    final preferences = MemoryVehiclePreferences();
    final old = Completer<http.Response>();
    var fail = false;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/stats')) return overviewTrendResponse();
      if (request.url.path.endsWith('/vehicles')) {
        return http.Response(
          File('test/fixtures/vehicles.json').readAsStringSync(),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path.endsWith('/1/summary')) return old.future;
      if (fail) return http.Response('', 503);
      final body = jsonDecode(
        File('test/fixtures/summary.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      body['vehicle']['id'] = 2;
      body['battery']['level'] = 21;
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    Widget app(String key) => MileafApp(
      key: ValueKey(key),
      client: client,
      sessionStore: store,
      trustStore: MemoryTrustStore(),
      vehiclePreferences: preferences,
      calendar: () async => CalendarContext('Asia/Shanghai'),
    );
    await tester.pumpWidget(app('first'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text('行笺测试车'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Y · 尾号 0002'));
    await tester.pumpAndSettle();
    expect(find.textContaining('21 %'), findsOneWidget);
    old.complete(
      http.Response(
        File('test/fixtures/summary.json').readAsStringSync(),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('68 %'), findsNothing);
    fail = true;
    await tester.tap(find.byTooltip('刷新概览'));
    await tester.pumpAndSettle();
    expect(find.textContaining('21 %'), findsOneWidget);
    expect(find.textContaining('保留上次快照'), findsOneWidget);
    fail = false;
    await tester.pumpWidget(app('restart'));
    await tester.pumpAndSettle();
    expect(find.text('Y · 尾号 0002'), findsOneWidget);
    expect(find.textContaining('21 %'), findsOneWidget);
  });
  testWidgets('无缓存体304只普通GET恢复，前台换IANA和换日不复用旧查询', (tester) async {
    final store = MemorySessionStore()
      ..value = jsonEncode({
        'site': 'https://example.com/prefix',
        'token': 'test',
        'expires_at': '2099-01-01T00:00:00Z',
      });
    var zone = 'Asia/Shanghai';
    var now = DateTime.utc(2026, 3, 15, 15, 59);
    var unsolicited = true;
    final queries = <String>[];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/stats')) return overviewTrendResponse();
      if (request.url.path.endsWith('/vehicles')) {
        return http.Response(
          File('test/fixtures/vehicles.json').readAsStringSync(),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      queries.add(request.url.queryParameters['tz']!);
      if (unsolicited) {
        unsolicited = false;
        return http.Response('', 304);
      }
      expect(request.headers.containsKey('if-none-match'), isFalse);
      return http.Response(
        File('test/fixtures/summary.json').readAsStringSync(),
        200,
        headers: {
          'content-type': 'application/json; charset=utf-8',
          'cache-control': 'max-age=3600',
        },
      );
    });
    await tester.pumpWidget(
      MileafApp(
        client: client,
        sessionStore: store,
        trustStore: MemoryTrustStore(),
        vehiclePreferences: MemoryVehiclePreferences(),
        now: () => now,
        calendar: () async => CalendarContext(zone),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('68 %'), findsOneWidget);
    expect(queries, ['Asia/Shanghai', 'Asia/Shanghai']);
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(queries.length, 2);
    now = DateTime.utc(2026, 3, 15, 16, 1);
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(queries.length, 3);
    zone = 'America/New_York';
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(queries.last, 'America/New_York');
    expect(find.textContaining('归期时区：America/New_York'), findsOneWidget);
  });
  testWidgets('所选车辆404刷新车辆列表后恢复仍存在车辆并提示', (tester) async {
    final store = MemorySessionStore()
      ..value = jsonEncode({
        'site': 'https://example.com/prefix',
        'token': 'test',
        'expires_at': '2099-01-01T00:00:00Z',
      });
    var missing = false;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/stats')) return overviewTrendResponse();
      if (request.url.path.endsWith('/vehicles')) {
        final vehicles = jsonDecode(
          File('test/fixtures/vehicles.json').readAsStringSync(),
        ) as List;
        if (missing) vehicles.removeAt(0);
        return http.Response(
          jsonEncode(vehicles),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (missing && request.url.path.endsWith('/1/summary')) {
        return http.Response('', 404);
      }
      final body = jsonDecode(
        File('test/fixtures/summary.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      if (missing) {
        body['vehicle']['id'] = 2;
        body['battery']['level'] = 21;
      }
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await tester.pumpWidget(
      MileafApp(
        client: client,
        sessionStore: store,
        trustStore: MemoryTrustStore(),
        vehiclePreferences: MemoryVehiclePreferences(),
        calendar: () async => CalendarContext('UTC'),
      ),
    );
    await tester.pumpAndSettle();
    missing = true;
    await tester.tap(find.byTooltip('刷新概览'));
    await tester.pumpAndSettle();
    expect(find.text('Y · 尾号 0002'), findsOneWidget);
    expect(find.textContaining('21 %'), findsOneWidget);
    expect(find.textContaining('所选车辆已不可用'), findsOneWidget);
  });
  testWidgets('360宽200%字体深色可读，休眠与null和零分离，未测版本不冒充schema错误', (tester) async {
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
    final store = MemorySessionStore()
      ..value = jsonEncode({
        'site': 'https://example.com/prefix',
        'token': 'test',
        'expires_at': '2099-01-01T00:00:00Z',
      });
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/stats')) return overviewTrendResponse();
      if (request.url.path.endsWith('/vehicles')) {
        return http.Response(
          File('test/fixtures/vehicles.json').readAsStringSync(),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path.endsWith('/meta')) {
        return http.Response(
          '{"version":"0.1.0","teslamate_schema_version":null,"tested":false,"source_unit_of_length":"mi","freshness":{"last_position_at":null,"last_state_at":null}}',
          200,
        );
      }
      final body = jsonDecode(
        File('test/fixtures/summary.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      body['state']['value'] = 'asleep';
      body['battery']['level'] = 0;
      body['battery']['range_km'] = null;
      body['last_drive'] = null;
      body['period']['today']['distance_km'] = 0;
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await tester.pumpWidget(
      MileafApp(
        client: client,
        sessionStore: store,
        trustStore: MemoryTrustStore(),
        vehiclePreferences: MemoryVehiclePreferences(),
        calendar: () async => CalendarContext('UTC', fallback: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('无法读取设备 IANA'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('0 %'), 200);
    expect(find.text('0 %'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('—（缺失）'), 200);
    expect(find.text('—（缺失）'), findsOneWidget);
    expect(find.textContaining('最近充电功率'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('服务版本与兼容性'));
    await tester.pumpAndSettle();
    expect(find.textContaining('未声明已测兼容'), findsOneWidget);
    expect(find.text('schema 检查正常'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('设置当前401退出旧路由，不保留服务快照且不刷新被遮挡概览', (tester) async {
    final store = MemorySessionStore()
      ..value = jsonEncode({
        'site': 'https://example.com/prefix',
        'token': 'test',
        'expires_at': '2099-01-01T00:00:00Z',
      });
    var expired = false;
    final resumedPaths = <String>[];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/stats')) return overviewTrendResponse();
      if (expired) {
        resumedPaths.add(request.url.path);
        return http.Response('', 401);
      }
      if (request.url.path.endsWith('/vehicles')) {
        return http.Response(
          File('test/fixtures/vehicles.json').readAsStringSync(),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path.endsWith('/meta')) {
        return http.Response(
          '{"version":"0.1.0","teslamate_schema_version":null,"tested":true,"source_unit_of_length":"km","freshness":{"last_position_at":null,"last_state_at":null}}',
          200,
        );
      }
      return http.Response(
        File('test/fixtures/summary.json').readAsStringSync(),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await tester.pumpWidget(
      MileafApp(
        client: client,
        sessionStore: store,
        trustStore: MemoryTrustStore(),
        vehiclePreferences: MemoryVehiclePreferences(),
        calendar: () async => CalendarContext('UTC'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('服务版本与兼容性'));
    await tester.pumpAndSettle();
    expect(find.text('Mileaf Server 0.1.0'), findsOneWidget);
    expired = true;
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(find.text('站点访问口令'), findsOneWidget);
    expect(find.text('Mileaf Server 0.1.0'), findsNothing);
    expect(resumedPaths, ['/prefix/v1/meta']);
  });
}
