import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/workspace.dart';

import 'charging_test.dart' show MemoryCurrency;
import 'session_test.dart' show connect;
import 'support/battery_finder.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

Object sample(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync());
http.Response response(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  testWidgets('连接登录到四入口、两种详情、兼容信息及本地退出的完整闭环', (tester) async {
    final store = MemorySessionStore();
    final paths = <String>[];
    final client = MockClient((request) async {
      expect(request.url.host, 'example.com');
      expect(request.url.path.startsWith('/prefix/v1/'), isTrue);
      paths.add(request.url.path);
      final path = request.url.path.substring('/prefix/v1/'.length);
      if (path == 'health') {
        return response({'status': 'ok', 'version': '0.1.0'});
      }
      if (path == 'auth/login') {
        expect(request.method, 'POST');
        expect(request.headers.containsKey('authorization'), isFalse);
        return response({
          'token': 'synthetic-test-token',
          'expires_at': '2099-01-01T00:00:00Z',
        });
      }
      expect(request.method, 'GET');
      expect(request.headers['authorization'], 'Bearer synthetic-test-token');
      if (path == 'vehicles') return response(sample('vehicles'));
      if (path == 'meta') return response(sample('meta'));
      if (path == 'vehicles/1/summary') {
        final body = sample('summary') as Map<String, dynamic>;
        // Link the synthetic summary to the fixed detailed resources.
        body['last_drive']['id'] = 1;
        body['last_charge']['id'] = 1;
        return response(body);
      }
      if (path == 'vehicles/1/drives') {
        return response({
          'items': [sample('drive-detail')],
          'next_cursor': null,
        });
      }
      if (path == 'vehicles/1/charging-sessions') {
        return response({
          'items': [sample('charging-detail')],
          'next_cursor': null,
        });
      }
      if (path == 'drives/1') return response(sample('drive-detail'));
      if (path == 'drives/1/series') return response(sample('drive-series'));
      if (path == 'charging-sessions/1') {
        return response(sample('charging-detail'));
      }
      if (path == 'charging-sessions/1/series') {
        return response(sample('charging-series'));
      }
      if (path == 'vehicles/1/stats') {
        return response(
          sample(
            request.url.queryParameters['kind'] == 'charging'
                ? 'charging-stats'
                : 'driving-stats',
          ),
        );
      }
      fail('Unexpected API path');
    });
    await tester.pumpWidget(
      MileafApp(
        client: client,
        trustStore: MemoryTrustStore(),
        sessionStore: store,
        vehiclePreferences: MemoryVehiclePreferences(),
        currencyPreferences: MemoryCurrency(),
        now: () => DateTime.utc(2026, 3, 30, 12),
        calendar: () async => CalendarContext('UTC'),
      ),
    );
    await tester.pumpAndSettle();
    await connect(tester);
    await tester.enterText(find.byType(TextFormField), 'synthetic-password');
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
    expect(batteryText(68), findsWidgets);
    await tester.tap(find.text('行程').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('drive-1')).hitTestable(),
      140,
    );
    await tester.tap(find.byKey(const ValueKey('drive-1')));
    await tester.pumpAndSettle();
    expect(find.text('行程 #1'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('速度读数'), 250);
    expect(find.textContaining('速度读数'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('充电 #1 · 查看详情'), 250);
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电 #1 · 查看详情'));
    await tester.pumpAndSettle();
    expect(find.text('充电详情 #1'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('两类能量'), 180);
    await tester.pumpAndSettle();
    expect(find.text('电网侧'), findsOneWidget);
    expect(find.text('22.00 kWh'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('统计').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('总里程'), findsOneWidget);
    await tester.tap(find.text('充电统计'));
    await tester.pumpAndSettle();
    expect(find.textContaining('充入电池能量'), findsOneWidget);
    await tester.tap(find.text('驾驶统计'));
    await tester.pumpAndSettle();
    expect(find.textContaining('总里程'), findsOneWidget);
    await tester.tap(find.text('概览').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('服务版本与兼容性'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mileaf Server'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('退出此设备'));
    await tester.tap(find.text('退出此设备'));
    await tester.pumpAndSettle();
    expect(find.text('站点访问口令'), findsOneWidget);
    final saved = jsonDecode(store.value!) as Map<String, dynamic>;
    expect(saved['site'], 'https://example.com/prefix');
    expect(saved.containsKey('token'), isFalse);
    expect(saved.containsKey('expires_at'), isFalse);
    expect(paths.any((path) => path.endsWith('/series')), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
