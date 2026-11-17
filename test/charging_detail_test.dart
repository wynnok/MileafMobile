import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/design/components/components.dart';
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
  testWidgets('360x800充电详情首屏：主要结果与功率绘图区首 120 可见', (tester) async {
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
    expect(find.text('充电详情'), findsOneWidget);
    expect(find.text('40% → 70%'), findsOneWidget);
    expect(find.text('已结束'), findsOneWidget);
    expect(find.text('充入电量'), findsOneWidget);
    expect(find.text('AC'), findsOneWidget);
    final plot = tester.getRect(find.byKey(const Key('charging-time-chart')));
    // §6 充电详情：功率绘图区至少 120 可见。
    expect(
      800 - plot.top,
      greaterThanOrEqualTo(120),
      reason: 'P05 首屏功率绘图区首 120',
    );
  });

  testWidgets('概览最近充电读取固定详情与序列，电量计量与真实采样读数可见', (tester) async {
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
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('最近充电').hitTestable(), 300);
    await tester.tap(find.text('最近充电').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('充电详情'), findsOneWidget);
    expect(find.text('充入电量'), findsOneWidget);
    expect(find.textContaining('20'), findsWidgets);
    expect(find.text('费用'), findsOneWidget);
    expect(find.textContaining('12'), findsWidgets);
    expect(find.text('1 小时'), findsOneWidget);
    // R29 读数头：日期行 HH:mm，数值行带单位。
    expect(find.text('08:00'), findsWidgets);
    expect(find.text('11 kW'), findsOneWidget);
    final next = find.bySemanticsLabel('下一个数据点');
    await tester.scrollUntilVisible(next, 200);
    for (var i = 0; i < 2; i++) {
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(find.text('08:04'), findsWidgets);
    await tester.scrollUntilVisible(find.text('电量计量'), 200);
    expect(find.text('电网用电'), findsOneWidget);
    expect(find.textContaining('22.00 kWh'), findsOneWidget);
    semantics.dispose();
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
    await tester.tap(
      find.descendant(of: find.byType(MileafNavBar), matching: find.text('充电')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('charge-8')).hitTestable(),
      200,
    );
    await tester.tap(find.byKey(const ValueKey('charge-8')).hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('充电详情'), findsOneWidget);
    // CP02：进行中写成人话，不再是旧提示句。
    expect(find.textContaining('充电中，已充入'), findsOneWidget);
    expect(find.textContaining('结束后计入统计'), findsOneWidget);
    expect(find.text('DC'), findsNothing);
    expect(find.text('AC'), findsNothing);
    // 0 元不出现补录胶囊（S06）。
    expect(find.text('补录'), findsNothing);
    expect(find.text('0 USD'), findsWidgets);
    // CP06：重试统一「重试」；曲线错误由相邻错误文字区分。
    await tester.scrollUntilVisible(find.text('重试').hitTestable(), 200);
    failSeries = false;
    await tester.tap(find.text('重试').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('这次充电没有采样点'), findsOneWidget);
    failDetail = true;
    await tester.scrollUntilVisible(
      find.byTooltip('刷新充电明细').hitTestable(),
      -300,
    );
    await tester.tap(find.byTooltip('刷新充电明细').hitTestable());
    await tester.pumpAndSettle();
    // CP07：失败有旧数据走共享构造函数。
    await tester.scrollUntilVisible(find.textContaining('没能更新，显示的是'), -200);
    expect(find.textContaining('没能更新，显示的是'), findsOneWidget);
    expect(find.text('0 USD'), findsWidgets);
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
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('最近充电').hitTestable(), 300);
    await tester.tap(find.text('最近充电').hitTestable());
    await tester.pumpAndSettle();
    final chart = find.byKey(const Key('charging-time-chart'));
    await tester.scrollUntilVisible(chart.hitTestable(), 200);
    await tester.tapAt(tester.getRect(chart).center);
    await tester.pumpAndSettle();
    expect(find.text('—'), findsWidgets, reason: '缺失点写「—」，不补零');
    expect(find.text('08:01'), findsWidgets);
    await tester.scrollUntilVisible(find.text('电量').hitTestable(), -200);
    await tester.tap(find.text('电量').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('45%'), findsWidgets, reason: 'CP03 数值与百分号紧贴');
    expect(find.text('08:01'), findsWidgets);
    single = true;
    await tester.scrollUntilVisible(
      find.byTooltip('刷新充电明细').hitTestable(),
      -200,
    );
    await tester.tap(find.byTooltip('刷新充电明细').hitTestable());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('0%').hitTestable(), 200);
    expect(find.text('0%'), findsWidgets);
    semantics.dispose();
  });

  testWidgets('明细404时可返回上一页，曲线成功不被遮蔽', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/charging-sessions/1')) {
        return http.Response('', 404);
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
    expect(find.text('充入电量'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('charging-time-chart')),
      200,
    );
    expect(find.byKey(const Key('charging-time-chart')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('返回上一页').hitTestable(), -300);
    await tester.tap(find.text('返回上一页'));
    await tester.pumpAndSettle();
    expect(find.text('充电详情'), findsNothing);
  });

  testWidgets('错车详情不得展示费用，也不画曲线', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/charging-sessions/1')) {
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
    expect(find.text('服务器返回的数据格式不受支持，请确认 Mileaf Server 版本'), findsOneWidget);
    expect(find.textContaining('9876'), findsNothing);
    expect(find.byKey(const Key('charging-time-chart')), findsNothing);
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
    expect(find.text('充入电量'), findsNothing);
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
    // P05 只留一个刷新入口（AU13）：明细与曲线一起更新。
    await tester.tap(find.byTooltip('刷新充电明细'));
    await tester.pumpAndSettle();
    expect(validated, ['detail', 'series']);
    // 费用缺失写「—」，不写 0；补录胶囊只在站点支持补录时出现（此处 mock
    // 没有 meta 版本，按只读处理）。
    expect(find.text('—'), findsWidgets);
    expect(find.text('0'), findsNothing);
    expect(find.text('补录'), findsNothing);
    await tester.scrollUntilVisible(find.text('关于这些数据').hitTestable(), 200);
    await tester.tap(find.text('口径与估算').hitTestable());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('原始充电过程指标暂不可用'), 200);
    expect(find.textContaining('原始充电过程指标暂不可用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
