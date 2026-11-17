import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/design/components/components.dart';

import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';

import 'package:mileaf/src/workspace.dart';

import 'widget_test.dart' show MemoryTrustStore;

Future<void> connect(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextFormField),
    'https://example.com/prefix',
  );
  await tester.tap(find.text('检查连接'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('登录此站点'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('接入健康检查与登录使用稳定错误提示且可手动恢复', (tester) async {
    var healthFails = true, loginFails = true;
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/health')) {
        return healthFails
            ? http.Response(
                '{"error":{"code":"upstream_timeout","message":"private-token"}}',
                503,
              )
            : http.Response('{"status":"ok","version":"0.1"}', 200);
      }
      if (r.url.path.endsWith('/auth/login')) {
        return loginFails
            ? http.Response(
                '{"error":{"code":"internal_error","message":"private-token"}}',
                500,
              )
            : http.Response(
                '{"token":"test","expires_at":"2099-01-01T00:00:00Z"}',
                200,
              );
      }
      return http.Response('[]', 200);
    });
    await tester.pumpWidget(
      MileafApp(
        client: client,
        trustStore: MemoryTrustStore(),
        sessionStore: MemorySessionStore(),
        vehiclePreferences: MemoryVehiclePreferences(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'https://example.com/prefix',
    );
    await tester.tap(find.text('检查连接'));
    await tester.pumpAndSettle();
    expect(find.textContaining('上游服务超时'), findsOneWidget);
    expect(find.textContaining('private-token'), findsNothing);
    healthFails = false;
    await tester.tap(find.text('检查连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('登录此站点'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'test-password');
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
    expect(find.textContaining('服务内部错误'), findsOneWidget);
    expect(find.textContaining('private-token'), findsNothing);
    loginFails = false;
    await tester.enterText(find.byType(TextFormField), 'test-password');
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
    expect(find.textContaining('暂无车辆'), findsOneWidget);
  });

  testWidgets('已有站点登录后读取顶层车辆数组，重启安全恢复，不重复输入口令', (tester) async {
    final store = MemorySessionStore();
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/summary')) return http.Response('', 503);
      if (request.url.path.endsWith('/health')) {
        return http.Response('{"status":"ok","version":"0.1"}', 200);
      }
      if (request.url.path.endsWith('/auth/login')) {
        expect(jsonDecode(request.body), {'password': 'test-password'});
        expect(request.headers.containsKey('authorization'), isFalse);
        return http.Response(
          '{"token":"opaque-test-token","expires_at":"2099-01-01T00:00:00Z"}',
          200,
        );
      }
      expect(request.url.toString(), 'https://example.com/prefix/v1/vehicles');
      expect(request.headers['authorization'], 'Bearer opaque-test-token');
      return http.Response(
        '[{"id":1,"name":"行笺测试车","model":"3","vin_suffix":"0001","state":null,"battery":null,"freshness":{"last_position_at":null,"last_state_at":null}}]',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
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
    await connect(tester);
    await tester.enterText(find.byType(TextFormField), 'test-password');
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
    expect(find.text('行笺测试车'), findsOneWidget);
    await tester.pumpWidget(
      MileafApp(
        key: const ValueKey('restart'),
        client: client,
        trustStore: MemoryTrustStore(),
        sessionStore: store,
        vehiclePreferences: MemoryVehiclePreferences(),
        calendar: () async => CalendarContext("UTC"),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('行笺测试车'), findsOneWidget);
    expect(find.text('站点访问口令'), findsNothing);
  });
  testWidgets('限流期间不能再次提交，Retry-After 到期后可手动重试且口令已清空', (tester) async {
    var now = DateTime.utc(2026, 10, 23);
    var attempts = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/summary')) return http.Response('', 503);
      if (request.url.path.endsWith('/health')) {
        return http.Response('{"status":"ok","version":"0.1"}', 200);
      }
      attempts++;
      return http.Response('busy', 429, headers: {'retry-after': '2'});
    });
    await tester.pumpWidget(
      MileafApp(
        client: client,
        trustStore: MemoryTrustStore(),
        sessionStore: MemorySessionStore(),
        now: () => now,
      ),
    );
    await tester.pumpAndSettle();
    await connect(tester);
    await tester.enterText(find.byType(TextFormField), 'wrong');
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
    expect(find.textContaining('请求过于频繁'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      isEmpty,
    );
    expect(
      tester
          .widget<MileafButton>(find.widgetWithText(MileafButton, '登录'))
          .onPressed,
      isNull,
    );
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester
          .widget<MileafButton>(find.widgetWithText(MileafButton, '登录'))
          .onPressed,
      isNotNull,
    );
    expect(attempts, 1);
  });
  testWidgets('多车辆使用名称、车型与尾号、车辆ID回退，不显示完整标识', (tester) async {
    final store = MemorySessionStore()
      ..value = jsonEncode({
        'site': 'https://example.com/prefix',
        'token': 'restored-token',
        'expires_at': '2099-01-01T00:00:00Z',
      });
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode([
          {
            'id': 1,
            'name': '命名车辆',
            'model': '3',
            'vin_suffix': '0001',
            'state': null,
            'battery': null,
            'freshness': {'last_position_at': null, 'last_state_at': null},
          },
          {
            'id': 2,
            'name': ' ',
            'model': 'Y',
            'vin_suffix': 'VIN-SYNTHETIC-1234',
            'state': null,
            'battery': null,
            'freshness': {'last_position_at': null, 'last_state_at': null},
          },
          {
            'id': 3,
            'name': null,
            'model': null,
            'vin_suffix': '',
            'state': null,
            'battery': null,
            'freshness': {'last_position_at': null, 'last_state_at': null},
          },
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
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
    expect(find.text('命名车辆'), findsOneWidget);
    await tester.tap(find.text('命名车辆'));
    await tester.pumpAndSettle();
    // P16：车辆行写「型号，尾号 1234」（CP09.1 逗号，不用「·」）。
    expect(find.text('Y，尾号 1234'), findsOneWidget);
    expect(find.text('车辆 3'), findsOneWidget);
    expect(find.textContaining('VIN-SYNTHETIC'), findsNothing);
  });
  testWidgets('当前401清空车辆和凭据，重启仍保留站点供重新登录', (tester) async {
    final store = MemorySessionStore()
      ..value = jsonEncode({
        'site': 'https://example.com/prefix',
        'token': 'expired-on-server',
        'expires_at': '2099-01-01T00:00:00Z',
      });
    final client = MockClient(
      (request) async => http.Response('unauthorized', 401),
    );
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
    expect(find.text('站点访问口令'), findsOneWidget);
    expect(find.text('站点车辆'), findsNothing);
    await tester.pumpWidget(
      MileafApp(
        key: const ValueKey('after401'),
        client: client,
        trustStore: MemoryTrustStore(),
        sessionStore: store,
        vehiclePreferences: MemoryVehiclePreferences(),
        calendar: () async => CalendarContext("UTC"),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('https://example.com/prefix'), findsOneWidget);
    expect(find.text('站点访问口令'), findsOneWidget);
  });
  testWidgets('本地到期不发送旧token，旧401最后返回也不注销新代次', (tester) async {
    var now = DateTime.utc(2026, 10, 23);
    final store = MemorySessionStore()
      ..value = jsonEncode({
        'site': 'https://example.com/prefix',
        'token': 'old-token',
        'expires_at': now.add(const Duration(seconds: 1)).toIso8601String(),
      });
    final oldResponse = Completer<http.Response>();
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/summary')) return http.Response('', 503);
      if (request.headers['authorization'] == 'Bearer old-token') {
        return oldResponse.future;
      }
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response(
          '{"token":"new-token","expires_at":"2099-01-01T00:00:00Z"}',
          200,
        );
      }
      expect(request.headers['authorization'], 'Bearer new-token');
      return http.Response('[]', 200);
    });
    await tester.pumpWidget(
      MileafApp(
        client: client,
        trustStore: MemoryTrustStore(),
        sessionStore: store,
        vehiclePreferences: MemoryVehiclePreferences(),
        calendar: () async => CalendarContext("UTC"),
        now: () => now,
      ),
    );
    await tester.pump();
    await tester.pump();
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('站点访问口令'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'new-password');
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
    expect(find.textContaining('此站点暂无车辆'), findsOneWidget);
    oldResponse.complete(http.Response('', 401));
    await tester.pumpAndSettle();
    expect(find.text('站点车辆'), findsOneWidget);
    expect(find.text('站点访问口令'), findsNothing);
  });

  testWidgets('口令错误只提示登录失败，不触发初始化；无Retry-After不编造等待期', (tester) async {
    var status = 401;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/summary')) return http.Response('', 503);
      if (request.url.path.endsWith('/health')) {
        return http.Response('{"status":"ok","version":"0.1"}', 200);
      }
      expect(request.url.path, '/prefix/v1/auth/login');
      return http.Response('<html>proxy</html>', status);
    });
    await tester.pumpWidget(
      MileafApp(
        client: client,
        trustStore: MemoryTrustStore(),
        sessionStore: MemorySessionStore(),
      ),
    );
    await tester.pumpAndSettle();
    await connect(tester);
    await tester.enterText(find.byType(TextFormField), 'wrong');
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
    expect(find.textContaining('口令错误'), findsOneWidget);
    status = 429;
    await tester.enterText(find.byType(TextFormField), 'wrong');
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
    expect(find.textContaining('请求过于频繁'), findsOneWidget);
    expect(
      tester
          .widget<MileafButton>(find.widgetWithText(MileafButton, '登录'))
          .onPressed,
      isNotNull,
    );
    expect(find.textContaining('服务要求等待'), findsNothing);
  });

  for (final entry in <String, String>{
    '空车辆': '[]',
    '错误结构': '{}',
    '缺字段': '[{"id":1}]',
    '反代错误': '<html>bad gateway</html>',
  }.entries) {
    testWidgets('车辆读取${entry.key}不伪造车辆，错误可手动恢复', (tester) async {
      final store = MemorySessionStore()
        ..value = jsonEncode({
          'site': 'https://example.com/prefix',
          'token': 'test-token',
          'expires_at': '2099-01-01T00:00:00Z',
        });
      var response = entry.value;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/summary')) {
          return http.Response('', 503);
        }
        expect(request.method, 'GET');
        expect(request.url.path, '/prefix/v1/vehicles');
        return http.Response(response, 200);
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
      if (entry.key == '空车辆') {
        expect(find.textContaining('此站点暂无车辆'), findsOneWidget);
      } else {
        expect(find.textContaining('格式不兼容'), findsOneWidget);
        response = '[]';
        await tester.tap(find.text('重试车辆读取'));
        await tester.pumpAndSettle();
        expect(find.textContaining('此站点暂无车辆'), findsOneWidget);
      }
    });
  }
  testWidgets('已过期安全记录启动时回登录而不发送业务请求', (tester) async {
    final store = MemorySessionStore()
      ..value = jsonEncode({
        'site': 'https://example.com/prefix',
        'token': 'old-token',
        'expires_at': '2020-01-01T00:00:00Z',
      });
    final client = MockClient((request) async => throw StateError('不得联网'));
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
    expect(find.text('站点访问口令'), findsOneWidget);
    expect(find.textContaining('会话已到期'), findsOneWidget);
  });
  testWidgets('固定后端实际响应样本可经App解码，nullable状态保留并展示两车', (tester) async {
    final store = MemorySessionStore()
      ..value = jsonEncode({
        'site': 'https://example.com/prefix',
        'token': 'test-token',
        'expires_at': '2099-01-01T00:00:00Z',
      });
    final response = File('test/fixtures/vehicles.json').readAsStringSync();
    final client = MockClient(
      (request) async => http.Response(
        response,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
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
    expect(find.text('行笺测试车'), findsOneWidget);
    await tester.tap(find.text('行笺测试车'));
    await tester.pumpAndSettle();
    expect(find.text('Y，尾号 0002'), findsOneWidget);
  });
}
