import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';

void main() {
  testWidgets('车主输入反代服务地址并读取健康状态和服务版本', (tester) async {
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        'https://example.com:8443/mileaf/v1/health',
      );
      return http.Response('{"status":"ok","version":"0.1.0"}', 200);
    });
    await tester.pumpWidget(MileafApp(client: client));
    await tester.enterText(
      find.byType(TextFormField),
      'https://example.com:8443/mileaf/',
    );
    await tester.tap(find.text('检查连接'));
    await tester.pumpAndSettle();
    expect(find.text('服务正常 · 版本 0.1.0'), findsOneWidget);
  });
  testWidgets('HTTP 明确拒绝且无请求，输入保留可修改', (tester) async {
    final client = MockClient((request) async => throw StateError('不得发出请求'));
    await tester.pumpWidget(MileafApp(client: client));
    await tester.enterText(find.byType(TextFormField), 'http://example.com');
    await tester.tap(find.text('检查连接'));
    await tester.pumpAndSettle();
    expect(find.textContaining('请输入有效的 HTTPS'), findsOneWidget);
    expect(find.text('http://example.com'), findsOneWidget);
  });
  testWidgets('数据库503后保留输入并可重试成功', (tester) async {
    var unavailable = true;
    final client = MockClient(
      (request) async => unavailable
          ? http.Response(
              '{"error":{"code":"db_unavailable","message":"Database is unavailable"}}',
              503,
            )
          : http.Response('{"status":"ok","version":"0.1.0"}', 200),
    );
    await tester.pumpWidget(MileafApp(client: client));
    await tester.enterText(
      find.byType(TextFormField),
      'https://example.com/v1/',
    );
    await tester.tap(find.text('检查连接'));
    await tester.pumpAndSettle();
    expect(find.textContaining('数据库或上游暂不可用'), findsOneWidget);
    unavailable = false;
    await tester.tap(find.text('检查连接'));
    await tester.pumpAndSettle();
    expect(find.text('服务正常 · 版本 0.1.0'), findsOneWidget);
  });
  testWidgets('总时限涵盖等待响应头，超时后可以重试', (tester) async {
    final client = MockClient((request) => Completer<http.Response>().future);
    await tester.pumpWidget(MileafApp(client: client));
    await tester.enterText(find.byType(TextFormField), 'https://example.com');
    await tester.tap(find.text('检查连接'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 16));
    expect(find.text('请求超时，请检查网络后重试'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
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
      await tester.pumpWidget(MileafApp(client: client));
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
      await tester.pumpWidget(MileafApp(client: client));
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
        MileafApp(key: ValueKey(brightness), client: client),
      );
      await tester.enterText(find.byType(TextFormField), 'https://example.com');
      await tester.ensureVisible(find.text('检查连接'));
      await tester.tap(find.text('检查连接'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('数据库或上游暂不可用'));
      expect(tester.takeException(), isNull);
    }
  });
}
