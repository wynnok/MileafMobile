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
      expect(find.textContaining('请求过于频繁'), findsOneWidget);
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
}
