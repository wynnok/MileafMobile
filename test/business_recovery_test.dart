import 'dart:async';
import 'dart:convert';
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
import 'overview_test.dart'
    show background, foreground, overviewTrendResponse, overviewMetaResponse;

void main() {
  for (final retryHeader in ['60', 'Sun, 15 Mar 2026 12:01:00 GMT']) {
    testWidgets('业务限流保留快照并遵守Retry-After $retryHeader，等待结束只能手动恢复', (
      tester,
    ) async {
      var now = DateTime.utc(2026, 3, 15, 12);
      var calls = 0;
      final store = MemorySessionStore()
        ..value = jsonEncode({
          'site': 'https://example.com',
          'token': 'test',
          'expires_at': '2099-01-01T00:00:00Z',
        });
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/meta')) return overviewMetaResponse();
        if (request.url.path.endsWith('/stats')) return overviewTrendResponse();
        if (request.url.path.endsWith('/vehicles')) {
          return http.Response(
            File('test/fixtures/vehicles.json').readAsStringSync(),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        calls++;
        if (calls == 2) {
          return http.Response(
            '{"error":{"code":"rate_limited"}}',
            429,
            headers: {'retry-after': retryHeader},
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
          now: () => now,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('68 %'), findsOneWidget);
      await tester.tap(find.byTooltip('刷新概览'));
      await tester.pumpAndSettle();
      expect(find.textContaining('请求过于频繁'), findsWidgets);
      expect(find.textContaining('68 %'), findsOneWidget);
      await tester.tap(find.byTooltip('刷新概览'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      now = now.add(const Duration(seconds: 60));
      await tester.pump(const Duration(minutes: 1));
      expect(calls, 2);
      await tester.tap(find.byTooltip('刷新概览'));
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(find.textContaining('请求过于频繁'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('同键迟到旧响应不能污染返回概览时的更新快照', (tester) async {
    final old = Completer<http.Response>();
    var reads = 0;
    final store = MemorySessionStore()
      ..value = jsonEncode({
        'site': 'https://example.com',
        'token': 'test',
        'expires_at': '2099-01-01T00:00:00Z',
      });
    final fixture = File('test/fixtures/summary.json').readAsStringSync();
    final current = jsonDecode(fixture) as Map<String, dynamic>;
    current['battery']['level'] = 21;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/meta')) return overviewMetaResponse();
      if (request.url.path.endsWith('/stats')) return overviewTrendResponse();
      if (request.url.path.endsWith('/vehicles')) {
        return http.Response(
          File('test/fixtures/vehicles.json').readAsStringSync(),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path.endsWith('/drives')) {
        return http.Response('{"items":[],"next_cursor":null}', 200);
      }
      reads++;
      if (reads == 1) return old.future;
      return http.Response(
        jsonEncode(current),
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
        calendar: () async => CalendarContext('UTC'),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump();
    }
    expect(reads, 1);
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('21 %'), findsOneWidget);
    old.complete(
      http.Response(
        fixture,
        200,
        headers: {
          'content-type': 'application/json; charset=utf-8',
          'cache-control': 'max-age=3600',
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('21 %'), findsOneWidget);
    await tester.tap(find.text('行程').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('概览').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('21 %'), findsOneWidget);
    expect(reads, 2);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('业务HTTPS证书错误可辨识且保留快照，不泄露异常细节', (tester) async {
    var fail = false;
    final store = MemorySessionStore()
      ..value = jsonEncode({
        'site': 'https://example.com',
        'token': 'test',
        'expires_at': '2099-01-01T00:00:00Z',
      });
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/meta')) return overviewMetaResponse();
      if (request.url.path.endsWith('/stats')) return overviewTrendResponse();
      if (request.url.path.endsWith('/vehicles')) {
        return http.Response(
          File('test/fixtures/vehicles.json').readAsStringSync(),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (fail) throw const HandshakeException('sensitive connection detail');
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
    fail = true;
    await tester.tap(find.byTooltip('刷新概览'));
    await tester.pumpAndSettle();
    expect(find.textContaining('证书校验失败'), findsOneWidget);
    expect(find.textContaining('保留上次快照'), findsOneWidget);
    expect(find.textContaining('68 %'), findsOneWidget);
    expect(find.textContaining('sensitive connection detail'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('前台跨日丢弃旧查询快照时仍遵守当前会话限流', (tester) async {
    var now = DateTime.utc(2026, 3, 15, 23, 59, 30);
    var calls = 0;
    final store = MemorySessionStore()
      ..value = jsonEncode({
        'site': 'https://example.com',
        'token': 'test',
        'expires_at': '2099-01-01T00:00:00Z',
      });
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/meta')) return overviewMetaResponse();
      if (request.url.path.endsWith('/stats')) return overviewTrendResponse();
      if (request.url.path.endsWith('/vehicles')) {
        return http.Response(
          File('test/fixtures/vehicles.json').readAsStringSync(),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      calls++;
      if (calls == 2) {
        return http.Response('', 429, headers: {'retry-after': '120'});
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
        now: () => now,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('刷新概览'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    background(tester);
    now = now.add(const Duration(seconds: 30));
    foreground(tester);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.textContaining('请求过于频繁'), findsWidgets);
    now = now.add(const Duration(seconds: 90));
    await tester.tap(find.byTooltip('刷新概览'));
    await tester.pumpAndSettle();
    expect(calls, 3);
    await tester.pumpWidget(const SizedBox());
  });
}
