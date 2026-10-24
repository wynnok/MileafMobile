import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';

import 'session_test.dart' show connect;
import 'support/session_store.dart';
import 'widget_test.dart' show MemoryTrustStore;

void main() {
  testWidgets('仅主动初始化后设置口令，再登录并读取车辆', (tester) async {
    final routes = <String>[];
    final client = MockClient((request) async {
      routes.add(request.url.path);
      if (request.url.path.endsWith('/health')) {
        return http.Response('{"status":"ok","version":"0.1"}', 200);
      }
      if (request.url.path.endsWith('/auth/setup')) {
        expect(request.headers.containsKey('authorization'), isFalse);
        expect(jsonDecode(request.body), {'password': 'new-site-password'});
        return http.Response('{"status":"ok"}', 200);
      }
      if (request.url.path.endsWith('/auth/login')) {
        return http.Response(
          '{"token":"synthetic-token","expires_at":"2099-01-01T00:00:00Z"}',
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
      ),
    );
    await tester.pumpAndSettle();
    await connect(tester);
    expect(routes.where((p) => p.endsWith('/auth/setup')), isEmpty);
    await tester.tap(find.text('首次设置站点口令'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '新站点口令'),
      'new-site-password',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '再次输入口令'),
      'new-site-password',
    );
    await tester.tap(find.text('设置口令并登录'));
    await tester.pumpAndSettle();
    expect(routes, [
      '/prefix/v1/health',
      '/prefix/v1/auth/setup',
      '/prefix/v1/auth/login',
      '/prefix/v1/vehicles',
    ]);
    expect(find.textContaining('此站点暂无车辆'), findsOneWidget);
  });
  testWidgets('登录401不自动初始化，显式setup冲突回已有登录且不自动登录', (tester) async {
    var setupRequests = 0;
    var loginRequests = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/health')) {
        return http.Response('{"status":"ok","version":"0.1"}', 200);
      }
      if (request.url.path.endsWith('/auth/setup')) {
        setupRequests++;
        return http.Response(
          '{"error":{"code":"already_initialized","message":"Already initialized"}}',
          409,
        );
      }
      loginRequests++;
      return http.Response(
        '{"error":{"code":"unauthorized","message":"Unauthorized"}}',
        401,
      );
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
    await tester.enterText(find.byType(TextFormField), 'existing-password');
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
    expect(setupRequests, 0);
    await tester.tap(find.text('首次设置站点口令'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '新站点口令'),
      'new-site-password',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '再次输入口令'),
      'new-site-password',
    );
    await tester.tap(find.text('设置口令并登录'));
    await tester.pumpAndSettle();
    expect(find.text('站点访问口令'), findsOneWidget);
    expect(find.text('站点已初始化，请使用已有口令登录'), findsOneWidget);
    expect(setupRequests, 1);
    expect(loginRequests, 1);
  });
  testWidgets('初始化校验最少10个Unicode码点且两次一致，非法输入不请求', (tester) async {
    var writes = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/health')) {
        return http.Response('{"status":"ok","version":"0.1"}', 200);
      }
      writes++;
      return http.Response('{"error":{"code":"invalid_request"}}', 400);
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
    await tester.tap(find.text('首次设置站点口令'));
    await tester.pumpAndSettle();
    final password = find.widgetWithText(TextFormField, '新站点口令');
    final confirmation = find.widgetWithText(TextFormField, '再次输入口令');
    await tester.enterText(password, 'short');
    await tester.enterText(confirmation, 'short');
    await tester.tap(find.text('设置口令并登录'));
    await tester.pumpAndSettle();
    expect(find.text('口令至少需要 10 个字符'), findsOneWidget);
    await tester.enterText(password, 'long-test-password');
    await tester.enterText(confirmation, 'different-test-password');
    await tester.tap(find.text('设置口令并登录'));
    await tester.pumpAndSettle();
    expect(find.text('两次输入的口令不一致'), findsOneWidget);
    await tester.enterText(password, '🌿🌿🌿🌿🌿');
    await tester.enterText(confirmation, '🌿🌿🌿🌿🌿');
    await tester.tap(find.text('设置口令并登录'));
    await tester.pumpAndSettle();
    expect(find.text('口令至少需要 10 个字符'), findsOneWidget);
    expect(writes, 0);
  });
  testWidgets('setup超时说明结果未确定，不自动重发，可返回尝试登录', (tester) async {
    var setups = 0, logins = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/health')) {
        return http.Response('{"status":"ok","version":"0.1"}', 200);
      }
      if (request.url.path.endsWith('/auth/setup')) {
        setups++;
        throw TimeoutException('synthetic deadline');
      }
      logins++;
      return http.Response('{"error":{"code":"unauthorized"}}', 401);
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
    await tester.tap(find.text('首次设置站点口令'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '新站点口令'),
      'new-site-password',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '再次输入口令'),
      'new-site-password',
    );
    await tester.tap(find.text('设置口令并登录'));
    await tester.pumpAndSettle();
    expect(find.textContaining('初始化结果未确定'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(setups, 1);
    expect(logins, 0);
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, '新站点口令'))
          .controller!
          .text,
      isEmpty,
    );
    await tester.tap(find.text('返回登录'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'new-site-password');
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
    expect(setups, 1);
    expect(logins, 1);
  });
  testWidgets('360宽200%字体下未授权HTTP初始化不发送请求并可恢复登录', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response('{}', 500);
    });
    final store = MemorySessionStore()
      ..value = jsonEncode({'site': 'http://192.168.1.2:8000/prefix'});
    await tester.pumpWidget(
      MileafApp(
        client: client,
        trustStore: MemoryTrustStore(),
        sessionStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('首次设置站点口令'));
    await tester.tap(find.text('首次设置站点口令'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '新站点口令'),
      'new-site-password',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '再次输入口令'),
      'new-site-password',
    );
    await tester.ensureVisible(find.text('设置口令并登录'));
    await tester.tap(find.text('设置口令并登录'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('请先确认此站点使用可信网络'));
    expect(find.textContaining('请先确认此站点使用可信网络'), findsOneWidget);
    expect(requests, 0);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('返回登录'));
    await tester.tap(find.text('返回登录'));
    await tester.pumpAndSettle();
    expect(find.text('站点访问口令'), findsOneWidget);
  });
}
