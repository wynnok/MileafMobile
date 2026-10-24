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

http.Response jsonResponse(
  String body, {
  Map<String, String> headers = const {},
}) => http.Response(
  body,
  200,
  headers: {'content-type': 'application/json; charset=utf-8', ...headers},
);
Future<void> openDrives(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler, {
  DateTime Function()? now,
  Future<CalendarContext> Function()? calendar,
}) async {
  final store = MemorySessionStore()
    ..value = jsonEncode({
      'site': 'https://example.com/prefix',
      'token': 'test',
      'expires_at': '2099-01-01T00:00:00Z',
    });
  await tester.pumpWidget(
    MileafApp(
      client: MockClient((r) async {
        if (r.url.path.endsWith('/vehicles'))
          return jsonResponse(
            File('test/fixtures/vehicles.json').readAsStringSync(),
          );
        if (r.url.path.endsWith('/summary'))
          return jsonResponse(
            File('test/fixtures/summary.json').readAsStringSync(),
          );
        return handler(r);
      }),
      sessionStore: store,
      trustStore: MemoryTrustStore(),
      vehiclePreferences: MemoryVehiclePreferences(),
      now: now ?? () => DateTime.utc(2026, 3, 30, 12),
      calendar: calendar ?? () async => CalendarContext('Asia/Shanghai'),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('行程').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('行程从固定后端多页样本读取，展示未知地点与净电耗并产生详情目标', (tester) async {
    await openDrives(tester, (request) async {
      expect(request.url.path, '/prefix/v1/vehicles/1/drives');
      expect(request.url.queryParameters['from'], '2026-02-28T16:00:00.000Z');
      expect(request.url.queryParameters['to'], '2026-03-30T12:00:00.000Z');
      expect(request.url.queryParameters['limit'], '20');
      return jsonResponse(File('test/fixtures/drives.json').readAsStringSync());
    });
    expect(find.textContaining('净电耗 188 Wh/km'), findsWidgets);
    expect(find.textContaining('未知地点'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('drive-17')));
    await tester.pumpAndSettle();
    expect(find.textContaining('行程 #17'), findsOneWidget);
  });
}
