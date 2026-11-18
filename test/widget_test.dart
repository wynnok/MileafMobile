import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/design/components/components.dart';

import 'support/session_store.dart';
import 'support/test_trust_store.dart';

void main() {
  testWidgets('授权偏好读取失败时拒绝联网并提示恢复', (tester) async {
    final client = MockClient((request) async => throw StateError('不得联网'));
    await tester.pumpWidget(
      MileafApp(
        sessionStore: MemorySessionStore(),
        client: client,
        trustStore: UnavailableTrustStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'http://192.168.1.2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('检查连接'));
    await tester.pumpAndSettle();
    expect(find.textContaining('无法读取站点授权'), findsOneWidget);
  });

  testWidgets('局域网拒绝提供系统设置恢复路径，恢复后手动重试成功', (tester) async {
    var denied = true;
    final client = MockClient((request) async {
      if (denied) {
        throw const SocketException(
          'Permission denied',
          osError: OSError('permission', 13),
        );
      }
      return http.Response('{"status":"ok","version":"0.1.0"}', 200);
    });
    await tester.pumpWidget(
      MileafApp(
        sessionStore: MemorySessionStore(),
        client: client,
        trustStore: MemoryTrustStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'https://192.168.1.2');
    await tester.tap(find.text('检查连接'));
    await tester.pumpAndSettle();
    expect(find.textContaining('系统设置'), findsOneWidget);
    expect(find.textContaining('局域网'), findsOneWidget);
    denied = false;
    await tester.tap(find.text('检查连接'));
    await tester.pumpAndSettle();
    expect(find.text('服务正常，版本 0.1.0'), findsOneWidget);
  });

  testWidgets('重定向不继续请求，明确提示实际服务地址', (tester) async {
    final client = MockClient((request) async {
      expect(request.followRedirects, isFalse);
      expect(request.url.host, 'example.com');
      return http.Response(
        '',
        302,
        headers: {'location': 'http://other.example.com/stolen'},
      );
    });
    await tester.pumpWidget(
      MileafApp(
        sessionStore: MemorySessionStore(),
        client: client,
        trustStore: MemoryTrustStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'https://example.com');
    await tester.tap(find.text('检查连接'));
    await tester.pumpAndSettle();
    expect(find.textContaining('不会自动跟随跳转'), findsOneWidget);
    expect(find.textContaining('实际服务地址'), findsOneWidget);
  });

  testWidgets('HTTP 授权重启后恢复，撤销后再次阻止联网', (tester) async {
    final store = MemoryTrustStore();
    final client = MockClient(
      (request) async =>
          http.Response('{"status":"ok","version":"0.1.0"}', 200),
    );
    await tester.pumpWidget(
      MileafApp(
        sessionStore: MemorySessionStore(),
        key: const ValueKey(1),
        client: client,
        trustStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'http://192.168.1.2');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MileafApp(
        sessionStore: MemorySessionStore(),
        key: const ValueKey(2),
        client: client,
        trustStore: store,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'http://192.168.1.2/');
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    await tester.tap(find.text('检查连接'));
    await tester.pumpAndSettle();
    expect(find.text('服务正常，版本 0.1.0'), findsOneWidget);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('检查连接'));
    await tester.pumpAndSettle();
    expect(find.textContaining('请先确认此站点'), findsOneWidget);
  });

  testWidgets('车主输入反代服务地址并读取健康状态和服务版本', (tester) async {
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        'https://example.com:8443/mileaf/v1/health',
      );
      return http.Response('{"status":"ok","version":"0.1.0"}', 200);
    });
    await tester.pumpWidget(
      MileafApp(
        sessionStore: MemorySessionStore(),
        client: client,
        trustStore: MemoryTrustStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'https://example.com:8443/mileaf/',
    );
    await tester.tap(find.text('检查连接'));
    await tester.pumpAndSettle();
    expect(find.text('服务正常，版本 0.1.0'), findsOneWidget);
  });
  testWidgets('HTTP 未授权不联网，主动信任后仅对确切站点生效', (tester) async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      expect(request.followRedirects, isFalse);
      return http.Response('{"status":"ok","version":"0.1.0"}', 200);
    });
    await tester.pumpWidget(
      MileafApp(
        sessionStore: MemorySessionStore(),
        client: client,
        trustStore: MemoryTrustStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'http://192.168.1.2:8000/mileaf',
    );
    await tester.tap(find.text('检查连接'));
    await tester.pumpAndSettle();
    expect(requests, 0);
    expect(find.textContaining('明文'), findsWidgets);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('检查连接'));
    await tester.pumpAndSettle();
    expect(find.text('服务正常，版本 0.1.0'), findsOneWidget);
    expect(requests, 1);
    await tester.enterText(
      find.byType(TextFormField),
      'http://192.168.1.2:8000/other',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('检查连接'));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.text('服务正常，版本 0.1.0'), findsNothing);
  });
  for (final isJson in [true, false]) {
    testWidgets('数据库503后保留输入并可重试成功 JSON=$isJson', (tester) async {
      var unavailable = true;
      final client = MockClient(
        (request) async => unavailable
            ? http.Response(
                isJson
                    ? '{"error":{"code":"db_unavailable","message":"Database is unavailable"}}'
                    : '<html>private proxy error</html>',
                503,
              )
            : http.Response('{"status":"ok","version":"0.1.0"}', 200),
      );
      await tester.pumpWidget(
        MileafApp(
          sessionStore: MemorySessionStore(),
          client: client,
          trustStore: MemoryTrustStore(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'https://example.com/v1/',
      );
      await tester.tap(find.text('检查连接'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining(isJson ? '数据库暂不可用' : '数据库或上游暂不可用'),
        findsOneWidget,
      );
      unavailable = false;
      await tester.tap(find.text('检查连接'));
      await tester.pumpAndSettle();
      expect(find.text('服务正常，版本 0.1.0'), findsOneWidget);
    });
  }
  testWidgets('总时限涵盖等待响应头，超时后可以重试', (tester) async {
    final client = MockClient((request) => Completer<http.Response>().future);
    await tester.pumpWidget(
      MileafApp(
        sessionStore: MemorySessionStore(),
        client: client,
        trustStore: MemoryTrustStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'https://example.com');
    await tester.tap(find.text('检查连接'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 16));
    expect(find.text('请求超时，请检查网络后重试'), findsOneWidget);
    expect(
      tester
          .widget<MileafButton>(find.widgetWithText(MileafButton, '检查连接'))
          .onPressed,
      isNotNull,
    );
  });
  for (final address in [
    'ftp://example.com',
    'https://user:password@example.com',
    'https://example.com?token=invalid',
    'https://example.com#fragment',
    'https://',
  ]) {
    testWidgets('无效服务地址不访问网络：$address', (tester) async {
      final client = MockClient((request) async => throw StateError('不得发出请求'));
      await tester.pumpWidget(
        MileafApp(
          sessionStore: MemorySessionStore(),
          client: client,
          trustStore: MemoryTrustStore(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), address);
      await tester.tap(find.text('检查连接'));
      await tester.pumpAndSettle();
      expect(find.textContaining('请输入有效的 HTTPS'), findsOneWidget);
    });
  }
  for (final failure in [
    (const SocketException('offline'), '服务不可达'),
    (const HandshakeException('untrusted'), '证书校验失败'),
  ]) {
    testWidgets('网络错误保留输入并可恢复：${failure.$2}', (tester) async {
      final client = MockClient((request) async => throw failure.$1);
      await tester.pumpWidget(
        MileafApp(
          sessionStore: MemorySessionStore(),
          client: client,
          trustStore: MemoryTrustStore(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'https://example.com');
      await tester.tap(find.text('检查连接'));
      await tester.pumpAndSettle();
      expect(find.textContaining(failure.$2), findsOneWidget);
      expect(find.text('https://example.com'), findsOneWidget);
    });
  }
  testWidgets('360像素、200%字体下错误与操作在浅深色都可阅读', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });
    final client = MockClient(
      (request) async => http.Response('unavailable', 503),
    );
    for (final brightness in Brightness.values) {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      await tester.pumpWidget(
        MileafApp(
          sessionStore: MemorySessionStore(),
          key: ValueKey(brightness),
          client: client,
          trustStore: MemoryTrustStore(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'https://example.com');
      await tester.ensureVisible(find.text('检查连接'));
      await tester.tap(find.text('检查连接'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('数据库或上游暂不可用'));
      expect(tester.takeException(), isNull);
    }
  });
}

// MemoryTrustStore / UnavailableTrustStore 已迁至 test/support/test_trust_store.dart
// （AP13 归拢，AP14 落地）。本文件经 support 导入继续使用。
