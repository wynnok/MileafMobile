import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/map_candidate.dart';
import 'package:flutter_map/flutter_map.dart' show FlutterMap;

import 'drive_map_test.dart' show provider, tile;

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
  MapConfiguration? mapConfiguration,
}) => MileafApp(
  client: client,
  mapConfiguration: mapConfiguration,
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
    expect(find.textContaining('地图暂不可用'), findsOneWidget);
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
      await tester.pumpWidget(
        app(
          client,
          mapConfiguration: MapConfiguration(
            provider: provider,
            sourceCrs: 'EPSG:4326',
            tileClient: MockClient((request) async {
              expect(request.headers.containsKey('authorization'), isFalse);
              return state == 'tile-failure' ? http.Response('', 500) : tile();
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('最近充电'), 300);
      await tester.tap(find.text('最近充电'));
      await tester.pumpAndSettle();
      if (state == 'missing') {
        expect(find.text('没有有效轨迹坐标'), findsOneWidget);
        expect(find.text('允许加载底图'), findsNothing);
      } else {
        await tester.tap(find.text('允许加载底图'));
        await tester.pumpAndSettle();
        expect(find.byType(FlutterMap), findsOneWidget);
      }
      await tester.scrollUntilVisible(find.text('电量区间'), 200);
      expect(find.text('40% → 70%'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('功率 kW'), 200);
      expect(find.text('功率 kW'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
