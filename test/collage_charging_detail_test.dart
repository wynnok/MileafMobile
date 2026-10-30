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
import 'charging_test.dart' show MemoryCurrency;

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
        as Map<String, dynamic>;
http.Response response(Object body, {Map<String, String> headers = const {}}) =>
    http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json; charset=utf-8', ...headers},
    );
Widget app(http.Client client, {MemoryCurrency? currency}) => MileafApp(
  client: client,
  trustStore: MemoryTrustStore(),
  sessionStore: MemorySessionStore()
    ..value = jsonEncode({
      'site': 'https://example.com/prefix',
      'token': 'test',
      'expires_at': '2099-01-01T00:00:00Z',
    }),
  vehiclePreferences: MemoryVehiclePreferences(),
  currencyPreferences: currency,
  calendar: () async => CalendarContext('UTC'),
  now: () => DateTime.utc(2026, 3, 30, 12),
);
http.Response initial(http.Request request) {
  if (request.url.path.endsWith('/stats')) {
    return response(fixture('driving-stats'));
  }
  if (request.url.path.endsWith('/vehicles')) {
    return http.Response(
      File('test/fixtures/vehicles.json').readAsStringSync(),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }
  if (request.url.path.endsWith('/charging-sessions')) {
    return response(fixture('charging-sessions'));
  }
  final summary = fixture('summary');
  summary['last_charge']['id'] = 1;
  return response(summary);
}

void main() {
  testWidgets('360x800充电详情先展示主要结果和完整默认功率图', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/charging-sessions/1')) {
        return response(fixture('charging-detail'));
      }
      if (request.url.path.endsWith('/charging-sessions/1/series')) {
        return response(fixture('charging-series'));
      }
      return initial(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('最近充电'), 300);
    await tester.tap(find.text('最近充电'));
    await tester.pumpAndSettle();
    expect(find.textContaining('服务端采样'), findsNothing);
    expect(find.textContaining('采样峰值不等同原始峰值'), findsNothing);
    expect(find.text('电量变化'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('电量变化')).dy,
      lessThan(tester.getTopLeft(find.text('充入电池 20 kWh')).dy),
    );
    final graph = tester.getRect(find.byKey(const Key('charging-time-chart')));
    expect(graph.bottom, lessThanOrEqualTo(800));
    expect(graph.top, greaterThan(0));
  });
}
