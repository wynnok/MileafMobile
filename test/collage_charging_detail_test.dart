import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/map/map_consent.dart';
import 'package:mileaf/src/map/map_platform.dart';

import 'support/fake_map_platform.dart';

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
Widget app(
  http.Client client, {
  MemoryCurrency? currency,
  MapConsentController? mapConsent,
  MapPlatform? mapPlatform,
}) => MileafApp(
  client: client,
  mapConsent: mapConsent,
  mapPlatform: mapPlatform,
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
    await tester.scrollUntilVisible(find.text('最近充电').hitTestable(), 300);
    await tester.tap(find.text('最近充电').hitTestable());
    await tester.pumpAndSettle();
    expect(find.textContaining('服务端采样'), findsNothing);
    expect(find.textContaining('采样峰值不等同原始峰值'), findsNothing);
    expect(find.text('电量区间'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('电量区间')).dy,
      lessThan(tester.getTopLeft(find.text('充入电池 20 kWh')).dy),
    );
    final graph = tester.getRect(find.byKey(const Key('charging-time-chart')));
    expect(graph.bottom, lessThanOrEqualTo(800));
    expect(graph.top, greaterThan(0));
  });
  for (final state in ['normal', 'missing', 'tile-failure']) {
    testWidgets('充电地点地图 $state 保留SOC和功率结果且不泄漏站点凭据', (tester) async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/charging-sessions/1')) {
          final body = fixture('charging-detail');
          if (state == 'missing') {
            body['location']['lat'] = null;
            body['location']['lon'] = null;
          }
          return response(body);
        }
        if (request.url.path.endsWith('/charging-sessions/1/series')) {
          return response(fixture('charging-series'));
        }
        return initial(request);
      });
      final fake = FakeMapPlatform();
      final consent = MapConsentController();
      await consent.grant('高德地图');
      await tester.pumpWidget(
        app(client, mapConsent: consent, mapPlatform: fake),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('最近充电').hitTestable(), 300);
      await tester.tap(find.text('最近充电').hitTestable());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('电量区间'), 200);
      expect(find.text('40% → 70%'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('功率 kW'), 200);
      expect(find.text('功率 kW'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('充电地点').hitTestable(), 240);
      if (state == 'missing') {
        expect(find.text('没有有效轨迹坐标'), findsOneWidget);
        expect(fake.builds, 0);
      } else if (state == 'tile-failure') {
        fake.fail();
        await tester.pumpAndSettle();
        expect(find.textContaining('底图暂不可用'), findsOneWidget);
      } else {
        fake.completeLoad('GS(test)');
        await tester.pumpAndSettle();
        expect(fake.scene, isNotNull);
        expect(find.textContaining('GS(test)'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
