import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/workspace.dart';
import 'package:mileaf/src/map/map_key.dart';

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
Finder resultLabel(String value) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == value,
);

Widget app(
  http.Client client, {
  MemoryCurrency? currency,
  MapKeyController? mapKeys,
}) => MileafApp(
  client: client,
  mapKeys: mapKeys,
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
    final graph = tester.getRect(find.byKey(const Key('charging-time-chart')));
    expect(graph.bottom, lessThanOrEqualTo(800));
    expect(graph.top, greaterThan(0));
  });
  testWidgets('概览最近充电读取固定详情与序列，两类能量和真实采样读数可见', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/charging-sessions/1')) {
        return response(fixture('charging-detail'));
      }
      if (request.url.path.endsWith('/charging-sessions/1/series')) {
        expect(request.url.queryParameters, {
          'fields': 'power,soc',
          'points': '200',
        });
        return response(fixture('charging-series'));
      }
      return initial(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('最近充电').hitTestable(), 300);
    await tester.tap(find.text('最近充电').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('充电详情'), findsOneWidget);
    expect(resultLabel('充入电池 20 kWh'), findsOneWidget);
    expect(resultLabel('费用 12'), findsOneWidget);
    expect(find.text('币种未记录'), findsWidgets);
    await tester.scrollUntilVisible(find.text('功率 kW'), 300);
    expect(find.text('功率 kW'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('后一个采样').hitTestable(), 200);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('后一个采样').hitTestable());
      await tester.pumpAndSettle();
    }
    expect(find.text('2026-01-05 08:04:00'), findsOneWidget);
    expect(find.text('功率读数 11.00 kW'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('两类能量'), 200);
    expect(find.textContaining('电网侧'), findsOneWidget);
    expect(find.textContaining('22.00 kWh'), findsOneWidget);
  });
  testWidgets('列表进入进行中详情，币种标签复用，明细与曲线局部失败互不遮蔽', (tester) async {
    var failSeries = true, failDetail = false;
    final currency = MemoryCurrency()
      ..values['https://example.com/prefix'] = 'USD';
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/charging-sessions/8')) {
        if (failDetail) return http.Response('', 503);
        final body = fixture('charging-active');
        body['cost'] = 0;
        body['is_dc'] = null;
        return response(body);
      }
      if (request.url.path.endsWith('/charging-sessions/8/series')) {
        if (failSeries) return http.Response('', 503);
        return response({
          'session_id': 8,
          'resolution': 'empty',
          'points': 0,
          'series': [],
        });
      }
      return initial(request);
    });
    await tester.pumpWidget(app(client, currency: currency));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('充电 #8 · 查看详情').hitTestable(),
      200,
    );
    await tester.tap(find.text('充电 #8 · 查看详情').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('充电详情'), findsOneWidget);
    expect(find.text('充电进行中，当前指标不代表最终结果'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('更多充电信息'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('更多充电信息'));
    await tester.pumpAndSettle();
    expect(find.text('结束 —'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('充电类型未知'), -200);
    expect(find.text('充电类型未知'), findsOneWidget);
    expect(resultLabel('费用 0 USD'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('重试充电曲线').hitTestable(), 200);
    failSeries = false;
    await tester.tap(find.text('重试充电曲线').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('此充电没有序列采样'), findsOneWidget);
    failDetail = true;
    await tester.scrollUntilVisible(
      find.byTooltip('刷新充电明细').hitTestable(),
      -300,
    );
    await tester.tap(find.byTooltip('刷新充电明细').hitTestable());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('保留上次快照'), -200);
    expect(find.textContaining('保留上次快照'), findsOneWidget);
    expect(resultLabel('费用 0 USD'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('此充电没有序列采样').hitTestable(), 200);
    expect(find.text('此充电没有序列采样'), findsOneWidget);
  });
  testWidgets('不等间隔真实时间轴可点选缺失点，切电量读数及单点均不补零', (tester) async {
    var single = false;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/charging-sessions/1')) {
        return response(fixture('charging-detail'));
      }
      if (request.url.path.endsWith('/charging-sessions/1/series')) {
        return response({
          'session_id': 1,
          'resolution': 'server_sampled',
          'points': single ? 1 : 3,
          'series': single
              ? [
                  {'t': '2026-01-05T08:00:00Z', 'soc': 0},
                ]
              : [
                  {'t': '2026-01-05T08:00:00Z', 'power': 0, 'soc': 40},
                  {'t': '2026-01-05T08:01:00Z', 'power': null, 'soc': 45},
                  {'t': '2026-01-05T09:00:00Z', 'power': 20, 'soc': 70},
                ],
        });
      }
      return initial(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('最近充电').hitTestable(), 300);
    await tester.tap(find.text('最近充电').hitTestable());
    await tester.pumpAndSettle();
    final chart = find.byKey(const Key('charging-time-chart'));
    await tester.scrollUntilVisible(chart.hitTestable(), 200);
    final rect = tester.getRect(chart);
    await tester.tapAt(rect.center);
    await tester.pumpAndSettle();
    expect(find.text('功率读数 —'), findsOneWidget);
    expect(find.text('2026-01-05 08:01:00'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('电量 %').hitTestable(), -200);
    await tester.tap(find.text('电量 %').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('电量读数 45 %'), findsOneWidget);
    expect(find.text('2026-01-05 08:01:00'), findsOneWidget);
    single = true;
    await tester.scrollUntilVisible(
      find.byTooltip('刷新充电曲线').hitTestable(),
      -200,
    );
    await tester.tap(find.byTooltip('刷新充电曲线').hitTestable());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('有效采样不足两点'), 200);
    expect(find.textContaining('有效采样不足两点'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('电量 %').hitTestable(), -200);
    await tester.tap(find.text('电量 %').hitTestable());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('电量读数 0 %').hitTestable(), 200);
    expect(find.text('电量读数 0 %'), findsOneWidget);
  });
  testWidgets('明细404可返回概览，曲线成功不被遮蔽；错车详情不得展示', (tester) async {
    var mismatch = false;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/charging-sessions/1')) {
        if (!mismatch) return http.Response('', 404);
        final body = fixture('charging-detail');
        body['vehicle_id'] = 2;
        body['cost'] = 9876;
        return response(body);
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
    expect(find.text('该充电记录已不可用，可返回上一页'), findsOneWidget);
    expect(resultLabel('充入电池 20 kWh'), findsNothing);
    await tester.scrollUntilVisible(find.text('功率 kW'), 200);
    expect(find.text('功率 kW'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('返回上一页').hitTestable(), -300);
    await tester.tap(find.text('返回上一页'));
    await tester.pumpAndSettle();
    mismatch = true;
    await tester.tap(find.text('最近充电').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('服务返回格式不兼容，请核对版本'), findsOneWidget);
    expect(find.textContaining('9876'), findsNothing);
    expect(find.text('功率 kW'), findsNothing);
  });
  testWidgets('当前401清除详情路由，旧序列最后完成不泄露快照', (tester) async {
    final delayed = Completer<http.Response>();
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/charging-sessions/1')) {
        return http.Response('', 401);
      }
      if (request.url.path.endsWith('/charging-sessions/1/series')) {
        return delayed.future;
      }
      return initial(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('最近充电').hitTestable(), 300);
    await tester.tap(find.text('最近充电').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('站点访问口令'), findsOneWidget);
    expect(find.text('充电详情'), findsNothing);
    delayed.complete(response(fixture('charging-series')));
    await tester.pumpAndSettle();
    expect(find.text('站点访问口令'), findsOneWidget);
    expect(find.text('功率 kW'), findsNothing);
  });
  testWidgets('360宽200%字深色下明细与序列条件304保留读数，缺失费用不变零', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });
    final validated = <String>[];
    final client = MockClient((request) async {
      if (request.url.path.contains('/charging-sessions/1')) {
        final series = request.url.path.endsWith('/series');
        if (request.headers['if-none-match'] ==
            (series ? '"series"' : '"detail"')) {
          validated.add(series ? 'series' : 'detail');
          return http.Response('', 304);
        }
        final body = fixture(series ? 'charging-series' : 'charging-detail');
        if (!series) body['cost'] = null;
        return response(
          body,
          headers: {
            'etag': series ? '"series"' : '"detail"',
            'cache-control': 'max-age=60',
          },
        );
      }
      return initial(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('最近充电').hitTestable(), 250);
    await tester.tap(find.text('最近充电').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('刷新充电明细'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(resultLabel('费用 —').hitTestable(), 200);
    expect(resultLabel('费用 —'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byTooltip('刷新充电曲线').hitTestable(),
      200,
    );
    await tester.tap(find.byTooltip('刷新充电曲线').hitTestable());
    await tester.pumpAndSettle();
    expect(validated, ['detail', 'series']);
    await tester.scrollUntilVisible(find.text('曲线数据说明').hitTestable(), 200);
    await tester.tap(find.text('曲线数据说明').hitTestable());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('服务端采样 24 点'), 200);
    expect(find.textContaining('服务端采样 24 点'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
