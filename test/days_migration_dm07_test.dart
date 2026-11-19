import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mileaf/main.dart';
import 'package:mileaf/src/design/components/components.dart';

import 'statistics_test.dart' show fixture, openStats;
import 'support/session_store.dart';
import 'support/test_trust_store.dart' show MemoryTrustStore;

/// DM07 页面包（MG09 状态诚实三要素 + MG02 受限 tone）页级接线用例。
///
/// 统计专题空态分档断言在 statistics_usage_test / statistics_charging_test；
/// 连接管理分组标题 inset 断言在 connection_management_test；初始化反馈
/// 状态条断言在 setup_test；本文件覆盖连接页检查失败与统计首页能力读取
/// 失败两条整页失败路径。
void main() {
  testWidgets('MG09 连接页检查失败：现状句（含原因）+ 重试动作走状态条', (tester) async {
    var healthCalls = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/health')) {
        healthCalls++;
        return http.Response('', 503);
      }
      return http.Response('{}', 404);
    });
    await tester.pumpWidget(
      MileafApp(
        client: client,
        trustStore: MemoryTrustStore(),
        sessionStore: MemorySessionStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '服务根地址'),
      'https://example.com/mileaf',
    );
    await tester.tap(find.text('检查连接'));
    await tester.pumpAndSettle();
    expect(healthCalls, 1);
    // 失败句不再由页面直接指定 error 色，改走受限四档 tone 的状态条。
    expect(find.byType(InlineBanner), findsOneWidget);
    expect(find.textContaining('暂不可用'), findsOneWidget);
    final retry = find.bySemanticsLabel('重试检查连接');
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(healthCalls, 2);
  });

  testWidgets('MG09 连接页证书校验失败：走失败状态条而非成功句（双轴审查修复 2）', (tester) async {
    var healthCalls = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/health')) {
        healthCalls++;
        // api 层透传客户端异常（仅超时被包装），模拟 TLS 握手失败。
        throw const HandshakeException('Handshake failed');
      }
      return http.Response('{}', 404);
    });
    await tester.pumpWidget(
      MileafApp(
        client: client,
        trustStore: MemoryTrustStore(),
        sessionStore: MemorySessionStore(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '服务根地址'),
      'https://example.com/mileaf',
    );
    await tester.tap(find.text('检查连接'));
    await tester.pumpAndSettle();
    // 失败必须呈现为失败（error 状态条 + 重试），不得以成功样式渲染。
    expect(find.byType(InlineBanner), findsOneWidget);
    expect(find.textContaining('证书校验失败'), findsOneWidget);
    expect(find.bySemanticsLabel('重试检查连接'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('重试检查连接'));
    await tester.pumpAndSettle();
    expect(healthCalls, 2);
  });

  testWidgets('MG09 统计首页能力读取失败：错误句 + 重试能力走状态条', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      // meta 失败：能力为空集且 error 非空，首页走失败分支。
      return http.Response('', 503);
    });
    await openStats(
      tester,
      client,
      () => DateTime.parse('2026-10-28T11:00:00Z'),
      () => 'UTC',
      statisticsInsights: true,
    );
    await tester.pumpAndSettle();
    expect(find.byType(InlineBanner), findsOneWidget);
    expect(find.textContaining('统计读取失败'), findsOneWidget);
    expect(find.text('重试能力'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
