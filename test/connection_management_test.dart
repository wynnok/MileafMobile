import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/api.dart';

import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';

import 'package:mileaf/src/workspace.dart';

import 'widget_test.dart' show MemoryTrustStore;

String vehicles(String name) => jsonEncode([
  {
    'id': 1,
    'name': name,
    'model': null,
    'vin_suffix': '',
    'state': null,
    'battery': null,
    'freshness': {'last_position_at': null, 'last_state_at': null},
  },
]);
MemorySessionStore saved() => MemorySessionStore()
  ..value = jsonEncode({
    'site': 'https://old.example/prefix',
    'token': 'old-token',
    'expires_at': '2099-01-01T00:00:00Z',
  });

/// VA02: the vehicle list refresh lives inside the vehicle sheet.
Future<void> refreshVehicles(WidgetTester tester, String current) async {
  await tester.tap(find.text(current).first);
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('刷新车辆'));
  await tester.pump();
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('设置'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('站点连接'));
  await tester.pumpAndSettle();
}

Future<void> backToWorkspace(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
}

Future<void> replace(WidgetTester tester, String site) async {
  if (find.byType(TextFormField).evaluate().isEmpty) {
    await tester.tap(find.text('更换连接'));
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.widgetWithText(TextFormField, '服务根地址'), site);
  await tester.enterText(
    find.widgetWithText(TextFormField, '站点访问口令'),
    'candidate-password',
  );
  await tester.tap(find.text('验证并替换连接'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('候选登录失败保留旧站点；成功替换及重启仅读取新站点', (tester) async {
    final store = saved();
    var rejected = true;
    final client = MockClient((request) async {
      if (request.url.host == 'old.example') {
        expect(request.headers['authorization'], 'Bearer old-token');
        return http.Response(
          vehicles('旧站点车辆'),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path.endsWith('/health')) {
        expect(request.headers['authorization'], isNull);
        return http.Response('{"status":"ok","version":"0.1"}', 200);
      }
      if (request.url.path.endsWith('/auth/login')) {
        expect(request.headers['authorization'], isNull);
        return http.Response(
          rejected
              ? '{}'
              : '{"token":"new-token","expires_at":"2099-01-01T00:00:00Z"}',
          rejected ? 401 : 200,
        );
      }
      expect(request.headers['authorization'], 'Bearer new-token');
      return http.Response(
        vehicles('新站点车辆'),
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
    await openSettings(tester);
    await replace(tester, 'https://new.example/prefix');
    expect(find.textContaining('口令错误'), findsOneWidget);
    await backToWorkspace(tester);
    await tester.pumpAndSettle();
    expect(find.text('旧站点车辆'), findsOneWidget);
    rejected = false;
    await openSettings(tester);
    await replace(tester, 'https://new.example/prefix');
    expect(find.text('新站点车辆'), findsOneWidget);
    expect(find.text('旧站点车辆'), findsNothing);
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
    expect(find.text('新站点车辆'), findsOneWidget);
  });
  for (final target in ['old.example', 'new.example']) {
    for (final lateStatus in [200, 401]) {
      testWidgets('$target 重新登录创建新代次，旧$lateStatus不能覆盖新车辆或退出新授权', (
        tester,
      ) async {
        final store = saved();
        final late = Completer<http.Response>();
        var delayOld = false;
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/health')) {
            return http.Response('{"status":"ok","version":"0.1"}', 200);
          }
          if (request.url.path.endsWith('/auth/login')) {
            expect(request.headers['authorization'], isNull);
            return http.Response(
              '{"token":"new-token","expires_at":"2099-01-01T00:00:00Z"}',
              200,
            );
          }
          if (request.headers['authorization'] == 'Bearer old-token') {
            if (delayOld) return late.future;
            return http.Response(
              vehicles('旧代次车辆'),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          expect(request.headers['authorization'], 'Bearer new-token');
          return http.Response(
            vehicles('新代次车辆'),
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
        delayOld = true;
        await refreshVehicles(tester, '旧代次车辆');
        await openSettings(tester);
        await tester.tap(find.text('重新登录当前站点'));
        await tester.pumpAndSettle();
        await replace(tester, 'https://$target/prefix');
        expect(find.text('新代次车辆'), findsOneWidget);
        late.complete(
          http.Response(
            vehicles('迟到旧车辆'),
            lateStatus,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('新代次车辆'), findsOneWidget);
        expect(find.text('迟到旧车辆'), findsNothing);
        expect(find.text('站点访问口令'), findsNothing);
      });
      testWidgets('退出后晚到$lateStatus无权恢复访问，重启保留可编辑地址', (tester) async {
        final store = saved();
        final late = Completer<http.Response>();
        var delayed = false;
        final client = MockClient((request) async {
          if (delayed) return late.future;
          return http.Response(
            vehicles('旧车辆'),
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
        delayed = true;
        await refreshVehicles(tester, '旧车辆');
        await openSettings(tester);
        await tester.ensureVisible(find.text('退出此设备'));
        await tester.tap(find.text('退出此设备'));
        await tester.pumpAndSettle();
        expect(find.text('站点访问口令'), findsOneWidget);
        late.complete(
          http.Response(
            vehicles('旧车辆'),
            lateStatus,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('旧车辆'), findsNothing);
        await tester.pumpWidget(
          MileafApp(
            key: const ValueKey('logout-restart'),
            client: client,
            trustStore: MemoryTrustStore(),
            sessionStore: store,
            vehiclePreferences: MemoryVehiclePreferences(),
            calendar: () async => CalendarContext("UTC"),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('https://old.example/prefix'), findsOneWidget);
        expect(find.text('站点访问口令'), findsOneWidget);
        expect(find.text('旧车辆'), findsNothing);
      });
    }
  }
  testWidgets('候选登录在退出后才返回也不能恢复授权或污染重启记录', (tester) async {
    final store = saved();
    final login = Completer<http.Response>();
    final client = MockClient((request) async {
      if (request.url.host == 'old.example') return http.Response('[]', 200);
      if (request.url.path.endsWith('/health')) {
        return http.Response('{"status":"ok","version":"0.1"}', 200);
      }
      if (request.url.path.endsWith('/auth/login')) return login.future;
      return http.Response('[]', 200);
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
    await openSettings(tester);
    await tester.tap(find.text('更换连接'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '服务根地址'),
      'https://new.example',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '站点访问口令'),
      'candidate-password',
    );
    await tester.tap(find.text('验证并替换连接'));
    await tester.pumpAndSettle();
    await backToWorkspace(tester);
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tester.ensureVisible(find.text('退出此设备'));
    await tester.tap(find.text('退出此设备'));
    await tester.pumpAndSettle();
    login.complete(
      http.Response(
        '{"token":"candidate-token","expires_at":"2099-01-01T00:00:00Z"}',
        200,
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MileafApp(
        key: const ValueKey('pending-restart'),
        client: client,
        trustStore: MemoryTrustStore(),
        sessionStore: store,
        vehiclePreferences: MemoryVehiclePreferences(),
        calendar: () async => CalendarContext("UTC"),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('站点访问口令'), findsOneWidget);
    expect(find.text('https://old.example/prefix'), findsOneWidget);
  });
  testWidgets('退出保留地址可编辑且健康检查成功后才进入新站点登录', (tester) async {
    final store = saved();
    final client = MockClient((request) async {
      if (request.url.host == 'new.example') {
        expect(request.url.path, '/proxy/v1/health');
        expect(request.headers['authorization'], isNull);
        return http.Response('{"status":"ok","version":"0.1"}', 200);
      }
      return http.Response('[]', 200);
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
    await openSettings(tester);
    await tester.ensureVisible(find.text('退出此设备'));
    await tester.tap(find.text('退出此设备'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑服务地址'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '服务根地址'),
      'https://new.example/proxy',
    );
    await tester.tap(find.text('检查连接'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('登录此站点'));
    await tester.pumpAndSettle();
    expect(find.text('https://new.example/proxy'), findsOneWidget);
    expect(find.text('站点访问口令'), findsOneWidget);
  });
  testWidgets('可信HTTP授权严格绑定端口和代理前缀，不向未授权候选发送口令', (tester) async {
    final store = saved();
    final trust = MemoryTrustStore();
    await trust.setTrusted(
      SiteAddress.parse('http://private.example:8080/a'),
      true,
    );
    final client = MockClient((request) async {
      expect(request.url.host, 'old.example');
      return http.Response(
        vehicles('原连接'),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await tester.pumpWidget(
      MileafApp(
        client: client,
        trustStore: trust,
        sessionStore: store,
        vehiclePreferences: MemoryVehiclePreferences(),
        calendar: () async => CalendarContext("UTC"),
      ),
    );
    await tester.pumpAndSettle();
    await openSettings(tester);
    await replace(tester, 'http://private.example:8080/b');
    expect(find.textContaining('请先确认此站点'), findsOneWidget);
    await backToWorkspace(tester);
    await tester.pumpAndSettle();
    expect(find.text('原连接'), findsOneWidget);
  });
  testWidgets('候选车辆失败或安全保存失败都保留旧连接，退出存储失败可重试清除', (tester) async {
    final store = FailingStore()..value = saved().value;
    var vehicleStatus = 503;
    final client = MockClient((request) async {
      if (request.url.host == 'old.example') {
        return http.Response(
          vehicles('原连接车辆'),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path.endsWith('/health')) {
        return http.Response('{"status":"ok","version":"0.1"}', 200);
      }
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response(
          '{"token":"candidate-token","expires_at":"2099-01-01T00:00:00Z"}',
          200,
        );
      }
      return http.Response('[]', vehicleStatus);
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
    await openSettings(tester);
    await replace(tester, 'https://new.example');
    expect(find.textContaining('暂不可用'), findsOneWidget);
    await backToWorkspace(tester);
    await tester.pumpAndSettle();
    expect(find.text('原连接车辆'), findsOneWidget);
    vehicleStatus = 200;
    store.fail = true;
    await openSettings(tester);
    await replace(tester, 'https://new.example');
    expect(find.textContaining('安全保存'), findsOneWidget);
    await backToWorkspace(tester);
    await tester.pumpAndSettle();
    expect(find.text('原连接车辆'), findsOneWidget);
    await openSettings(tester);
    await tester.ensureVisible(find.text('退出此设备'));
    await tester.tap(find.text('退出此设备'));
    await tester.pumpAndSettle();
    expect(find.textContaining('清理失败'), findsOneWidget);
    store.fail = false;
    await tester.ensureVisible(find.text('退出此设备'));
    await tester.tap(find.text('退出此设备'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MileafApp(
        key: const ValueKey('failed-logout-restart'),
        client: client,
        trustStore: MemoryTrustStore(),
        sessionStore: store,
        vehiclePreferences: MemoryVehiclePreferences(),
        calendar: () async => CalendarContext("UTC"),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('站点访问口令'), findsOneWidget);
    expect(find.text('原连接车辆'), findsNothing);
  });
}

class FailingStore extends MemorySessionStore {
  bool fail = false;
  @override
  Future<void> write(String record) async {
    if (fail) throw Exception('Synthetic storage failure');
    await super.write(record);
  }
}
