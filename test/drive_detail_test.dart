import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mileaf/src/collage.dart';
import 'package:mileaf/src/map/map_consent.dart';
import 'package:mileaf/src/map/map_panel.dart';
import 'package:mileaf/src/map/map_platform.dart';
import 'package:mileaf/src/workspace.dart';

import 'drives_test.dart' show openDrives, jsonResponse;

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
        as Map<String, dynamic>;
Future<void> openDetail(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler, {
  MapConsentController? mapConsent,
  MapPlatform? mapPlatform,
  Future<http.Response> Function(http.Request)? statsHandler,
  Future<CalendarContext> Function()? calendar,
}) async {
  await openDrives(
    tester,
    (r) async {
      if (r.url.path.endsWith('/1/drives')) {
        return jsonResponse(
          jsonEncode({
            'items': [fixture('drive-detail')],
            'next_cursor': null,
          }),
        );
      }
      return handler(r);
    },
    mapConsent: mapConsent,
    mapPlatform: mapPlatform,
    statsHandler: statsHandler,
    calendar: calendar,
  );
  await tester.scrollUntilVisible(find.byKey(const ValueKey('drive-1')), 180);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('drive-1')).hitTestable(),
    140,
  );
  await tester.tap(find.byKey(const ValueKey('drive-1')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('详情地图与页面内容同边距并先于路线与结果', (tester) async {
    await openDetail(
      tester,
      (r) async => jsonResponse(
        jsonEncode(
          fixture(
            r.url.path.endsWith('/series') ? 'drive-series' : 'drive-detail',
          ),
        ),
      ),
    );
    final map = tester.getRect(find.byType(MapPanel));
    final route = tester.getRect(find.textContaining(' → ').first);
    final tile = tester.getRect(
      find.ancestor(of: find.text('距离'), matching: find.byType(CollageTile)),
    );
    final viewWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(map.top, lessThan(route.top));
    expect(map.left, tile.left);
    expect(viewWidth - map.right, map.left);
    expect(map.width, viewWidth - 24);
  });

  testWidgets('电耗口径行保留负值本次值与真实零参照并提供口径说明', (tester) async {
    await openDetail(
      tester,
      (r) async {
        final body = fixture(
          r.url.path.endsWith('/series') ? 'drive-series' : 'drive-detail',
        );
        if (!r.url.path.endsWith('/series')) {
          body['consumption_wh_km'] = -12;
          body['energy_kwh'] = -0.24;
        }
        return jsonResponse(jsonEncode(body));
      },
      statsHandler: (_) async {
        final body = fixture('driving-stats');
        body['totals']['consumption_wh_km_net'] = 0;
        body['totals']['energy_kwh'] = 0;
        return jsonResponse(jsonEncode(body));
      },
    );
    await tester.scrollUntilVisible(
      find.textContaining('参考净电耗').hitTestable(),
      140,
    );
    expect(find.textContaining('本次 -12 Wh/km'), findsOneWidget);
    expect(find.textContaining('参考净电耗 0 Wh/km'), findsOneWidget);
    expect(find.bySemanticsLabel('参考净电耗 0 Wh/km'), findsOneWidget);
    await tester.tap(find.byTooltip('电耗参照说明'));
    await tester.pumpAndSettle();
    expect(find.text('电耗参照说明'), findsWidgets);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
  });
  testWidgets('进行中即使已有端点电量也不显示最终百分点差', (tester) async {
    await openDetail(tester, (r) async {
      final body = fixture(
        r.url.path.endsWith('/series') ? 'drive-series' : 'drive-detail',
      );
      if (!r.url.path.endsWith('/series')) {
        body['ended_at'] = null;
        body['start']['battery_level'] = 70;
        body['end']['battery_level'] = 65;
      }
      return jsonResponse(jsonEncode(body));
    });
    await tester.scrollUntilVisible(find.text('行程电量区间').hitTestable(), 140);
    expect(find.text('电量下降 5 个百分点'), findsNothing);
    expect(find.textContaining('参考净电耗'), findsNothing);
  });
  testWidgets('零里程行程不查询或展示个人电耗参照', (tester) async {
    var references = 0;
    await openDetail(
      tester,
      (r) async {
        final body = fixture(
          r.url.path.endsWith('/series') ? 'drive-series' : 'drive-detail',
        );
        if (!r.url.path.endsWith('/series')) body['distance_km'] = 0;
        return jsonResponse(jsonEncode(body));
      },
      statsHandler: (r) async {
        if (r.url.queryParameters['to'] == '2026-03-14T16:00:00.000Z') {
          references++;
        }
        return jsonResponse(jsonEncode(fixture('driving-stats')));
      },
    );
    expect(references, 0);
    expect(find.textContaining('参考净电耗'), findsNothing);
  });
  for (final sample in [
    ('Asia/Shanghai', '2026-02-12T16:00:00.000Z', '2026-03-14T16:00:00.000Z'),
    (
      'America/New_York',
      '2026-02-13T05:00:00.000Z',
      '2026-03-15T04:00:00.000Z',
    ),
  ]) {
    testWidgets('个人参照按行程日前30个完整本地日查询 ${sample.$1}', (tester) async {
      final requests = <Map<String, String>>[];
      await openDetail(
        tester,
        (r) async => jsonResponse(
          jsonEncode(
            fixture(
              r.url.path.endsWith('/series') ? 'drive-series' : 'drive-detail',
            ),
          ),
        ),
        calendar: () async => CalendarContext(sample.$1),
        statsHandler: (r) async {
          requests.add(r.url.queryParameters);
          return jsonResponse(jsonEncode(fixture('driving-stats')));
        },
      );
      expect(requests.last, {
        'kind': 'driving',
        'bucket': 'day',
        'tz': sample.$1,
        'from': sample.$2,
        'to': sample.$3,
      });
    });
  }
  testWidgets('个人参照失败时口径行给出错误与独立重试，不影响明细与采样', (tester) async {
    var fail = true;
    await openDetail(
      tester,
      (r) async => jsonResponse(
        jsonEncode(
          fixture(
            r.url.path.endsWith('/series') ? 'drive-series' : 'drive-detail',
          ),
        ),
      ),
      statsHandler: (_) async => fail
          ? http.Response('', 500)
          : jsonResponse(jsonEncode(fixture('driving-stats'))),
    );
    await tester.scrollUntilVisible(
      find.textContaining('个人历史参照：').hitTestable(),
      160,
    );
    expect(find.textContaining('个人历史参照：'), findsOneWidget);
    expect(find.textContaining('参考净电耗'), findsNothing);
    fail = false;
    await tester.tap(find.text('重试历史参照'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('参考净电耗').hitTestable(),
      160,
    );
    expect(find.textContaining('参考净电耗 188 Wh/km'), findsOneWidget);
  });
  testWidgets('完成行程显示此前30个完整本地日的全部路线参照', (tester) async {
    await openDetail(
      tester,
      (r) async => jsonResponse(
        jsonEncode(
          fixture(
            r.url.path.endsWith('/series') ? 'drive-series' : 'drive-detail',
          ),
        ),
      ),
    );
    final reference = find.bySemanticsLabel('参考净电耗 188 Wh/km');
    await tester.scrollUntilVisible(reference, 180);
    expect(reference, findsOneWidget);
    expect(find.textContaining('此前30个完整本地日 · 全部路线'), findsOneWidget);
  });
  testWidgets('行程电量区间保留起终点减少和未知值，不伪造成补能或零', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      var missing = false;
      await openDetail(tester, (request) async {
        if (request.url.path.endsWith('/series')) {
          return jsonResponse(jsonEncode(fixture('drive-series')));
        }
        final body = fixture('drive-detail');
        body['start']['battery_level'] = 82;
        body['end']['battery_level'] = missing ? null : 72;
        return jsonResponse(jsonEncode(body));
      });
      final known = find.bySemanticsLabel(RegExp('电量区间.*82.*72.*尺度0至100%'));
      await tester.scrollUntilVisible(known, 180);
      await tester.pumpAndSettle();
      expect(known, findsOneWidget);
      expect(find.text('起始 82 %'), findsOneWidget);
      expect(find.text('结束 72 %'), findsOneWidget);
      missing = true;
      await tester.tap(find.byTooltip('刷新行程明细'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('电量区间.*82.*结束未知')), findsOneWidget);
      expect(find.text('结束 —'), findsOneWidget);
      expect(find.text('结束 0 %'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('360宽200%字完整行程指标曲线和地点地图均可纵向阅读', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await openDetail(
      tester,
      (r) async => jsonResponse(
        jsonEncode(
          fixture(
            r.url.path.endsWith('/series') ? 'drive-series' : 'drive-detail',
          ),
        ),
      ),
    );
    for (final text in [
      '底图未启用',
      '距离 20.0 km',
      '时长 120 分钟',
      '净电耗 188 Wh/km',
      '速度读数',
    ]) {
      final target =
          (text.startsWith('距离') ||
                      text.startsWith('时长') ||
                      text.startsWith('净电耗')
                  ? find.bySemanticsLabel(text)
                  : find.textContaining(text))
              .hitTestable();
      await tester.scrollUntilVisible(target, 120);
      expect(target, findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    for (final text in [
      '平均速度 10 km/h',
      '最高速度 90 km/h',
      '最大功率 120 kW',
      '车外均温 15.0 °C',
      '车内均温 21.0 °C',
    ]) {
      final target = find.textContaining(text).hitTestable();
      await tester.scrollUntilVisible(target, 120);
      expect(target, findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.scrollUntilVisible(find.text('更多行程指标').hitTestable(), 160);
    await tester.tap(find.text('更多行程指标'));
    await tester.pumpAndSettle();
    for (final text in ['净能量 3.75 kWh', '起点电量 70 %', '终点电量 70 %', '续航口径']) {
      final target = find.textContaining(text).hitTestable();
      await tester.scrollUntilVisible(target, 120);
      expect(target, findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('行程列表与详情保留地址围栏，地点缺失回退且不重复主名称', (tester) async {
    final detail = fixture('drive-detail');
    detail['start']['geofence'] = '住宅围栏';
    detail['start']['address'] = '样例路1号';
    detail['end']['display_name'] = '办公地点';
    detail['end']['geofence'] = '办公地点';
    detail['end']['address'] = '办公地点';
    await openDrives(tester, (r) async {
      if (r.url.path.endsWith('/1/drives')) {
        return jsonResponse(
          jsonEncode({
            'items': [detail],
            'next_cursor': null,
          }),
        );
      }
      return jsonResponse(
        jsonEncode(
          r.url.path.endsWith('/series') ? fixture('drive-series') : detail,
        ),
      );
    });
    await tester.scrollUntilVisible(
      find.text('未知地点 → 办公地点').hitTestable(),
      120,
    );
    expect(find.text('未知地点 → 办公地点'), findsOneWidget);
    // C 列表卡只放路线与主要指标，围栏/地址留在详情的「更多行程指标」。
    expect(find.text('起点围栏：住宅围栏'), findsNothing);
    expect(find.text('起点地址：样例路1号'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('drive-1')).hitTestable(),
      140,
    );
    await tester.tap(find.byKey(const ValueKey('drive-1')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('未知地点 → 办公地点'), 120);
    expect(find.text('未知地点 → 办公地点'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('更多行程指标'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('更多行程指标'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('起点地址：样例路1号'), 200);
    expect(find.text('起点围栏：住宅围栏'), findsOneWidget);
    expect(find.text('起点地址：样例路1号'), findsOneWidget);
    expect(find.text('终点地址：办公地点'), findsNothing);
  });

  testWidgets('360x800详情先读路线结果与过程图，向下可读电量区间', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await openDetail(
      tester,
      (r) async => jsonResponse(
        jsonEncode(
          fixture(
            r.url.path.endsWith('/series') ? 'drive-series' : 'drive-detail',
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('距离 20.0 km').hitTestable(), findsOneWidget);
    expect(
      find.bySemanticsLabel('净电耗 188 Wh/km').hitTestable(),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('sample-chart')).hitTestable(),
      140,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('sample-chart')));
    await tester.pumpAndSettle();
    final viewport = tester.getRect(find.byType(RefreshIndicator));
    final graph = tester.getRect(find.byKey(const ValueKey('sample-chart')));
    expect(graph.top, greaterThanOrEqualTo(viewport.top));
    expect(graph.bottom, lessThanOrEqualTo(viewport.bottom));
    await tester.scrollUntilVisible(find.text('行程电量区间').hitTestable(), 140);
    expect(find.text('行程电量区间').hitTestable(), findsOneWidget);
  });

  testWidgets('列表进入真实详情，固定明细与独立series解码，切换电量并读数', (tester) async {
    await openDetail(tester, (r) async {
      if (r.url.path.endsWith('/series')) {
        expect(r.url.queryParameters, {
          'fields': 'speed,battery,elevation',
          'points': '200',
        });
        return jsonResponse(jsonEncode(fixture('drive-series')));
      }
      expect(r.url.path, '/prefix/v1/drives/1');
      return jsonResponse(jsonEncode(fixture('drive-detail')));
    });
    expect(find.text('行程 #1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('净电耗 188 Wh/km').hitTestable(),
      160,
    );
    expect(find.bySemanticsLabel('净电耗 188 Wh/km'), findsWidgets);
    await tester.scrollUntilVisible(find.textContaining('最高速度 90'), 200);
    expect(find.textContaining('最高速度 90 km/h'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('电量').hitTestable(), -200);
    await tester.tap(find.text('电量'));
    await tester.pumpAndSettle();
    expect(find.textContaining('电量读数 70 %'), findsOneWidget);
    expect(find.textContaining('不代表连续观测'), findsNothing);
    await tester.scrollUntilVisible(find.text('电量数据说明').hitTestable(), 160);
    await tester.tap(find.text('电量数据说明').hitTestable());
    await tester.pumpAndSettle();
    expect(find.textContaining('不代表连续观测'), findsOneWidget);
  });
  testWidgets('series失败不遮明细，局部重试支持null省略与单点，大字体读数可达', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    var failing = true;
    await openDetail(tester, (r) async {
      if (r.url.path.endsWith('/series')) {
        if (failing) return http.Response('', 503);
        return jsonResponse(
          '{"drive_id":1,"resolution":"server_sampled","points":1,"series":[{"t":"2026-03-15T08:00:00Z","lat":null,"lon":null,"speed_kmh":0,"battery_level":null}]}',
        );
      }
      final d = fixture('drive-detail');
      d['ended_at'] = null;
      d['distance_km'] = null;
      d['speed_max_kmh'] = 0;
      return jsonResponse(jsonEncode(d));
    });
    expect(find.textContaining('进行中'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('重试行程采样').hitTestable(), 300);
    failing = false;
    await tester.tap(find.text('重试行程采样'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('速度读数 0'), 250);
    expect(find.textContaining('速度读数 0 km/h'), findsOneWidget);
    expect(find.textContaining('仅1个采样点'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('电量').hitTestable(), -200);
    await tester.tap(find.text('电量'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('电量读数'), 200);
    expect(find.textContaining('电量读数 —（缺失）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('概览最近记录进入同一详情，明细404可返回，独立空series仍可阅读', (tester) async {
    await openDrives(tester, (r) async {
      if (r.url.path.endsWith('/1/drives')) {
        return jsonResponse('{"items":[],"next_cursor":null}');
      }
      if (r.url.path.endsWith('/17/series')) {
        final body = fixture('drive-empty-series');
        body['drive_id'] = 17;
        return jsonResponse(jsonEncode(body));
      }
      expect(r.url.path, '/prefix/v1/drives/17');
      return http.Response('', 404);
    });
    await tester.tap(find.text('概览').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('最近行程').hitTestable(), 300);
    await tester.tap(find.text('最近行程').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('行程 #17'), findsOneWidget);
    expect(find.textContaining('记录已不可用'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('没有采样点'), 250);
    expect(find.text('没有采样点'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('返回行程列表'), -250);
    await tester.tap(find.text('返回行程列表'));
    await tester.pumpAndSettle();
    expect(find.text('行程 #17'), findsNothing);
  });
  testWidgets('详情条件304保留，series刷新失败只保留该区域快照，点选按真实时间', (tester) async {
    var refresh = false;
    await openDetail(tester, (r) async {
      if (r.url.path.endsWith('/series')) {
        if (refresh) return http.Response('', 503);
        return jsonResponse(
          '{"drive_id":1,"resolution":"server_sampled","points":3,"series":[{"t":"2026-03-15T08:00:00Z","lat":null,"lon":null,"speed_kmh":10},{"t":"2026-03-15T08:01:00Z","lat":null,"lon":null,"speed_kmh":null},{"t":"2026-03-15T10:00:00Z","lat":null,"lon":null,"speed_kmh":80}]}',
        );
      }
      if (refresh) {
        expect(r.headers['if-none-match'], '"detail"');
        return http.Response('', 304);
      }
      return jsonResponse(
        jsonEncode(fixture('drive-detail')),
        headers: {'etag': '"detail"'},
      );
    });
    await tester.scrollUntilVisible(find.text('前一个采样'), 200);
    await tester.ensureVisible(find.byKey(const ValueKey('sample-chart')));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byKey(const ValueKey('sample-chart')));
    await tester.tapAt(Offset(rect.left + rect.width * 0.49, rect.center.dy));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('速度读数'), 150);
    expect(
      find.textContaining('速度读数 —（缺失）'),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.textContaining('速度读数'))
          .map((t) => t.data)
          .join(),
    );
    await tester.tap(find.text('后一个采样'));
    await tester.pumpAndSettle();
    expect(find.textContaining('速度读数 80 km/h'), findsOneWidget);
    refresh = true;
    await tester.scrollUntilVisible(find.byTooltip('刷新行程采样'), -200);
    await tester.tap(find.byTooltip('刷新行程采样'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('保留上次快照'), -200);
    expect(find.textContaining('保留上次快照'), findsOneWidget);
    await tester.scrollUntilVisible(find.byTooltip('刷新行程明细'), -300);
    await tester.tap(find.byTooltip('刷新行程明细'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('行程地图').hitTestable(), -160);
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('净电耗 188 Wh/km').hitTestable(),
      160,
    );
    expect(find.bySemanticsLabel('净电耗 188 Wh/km'), findsOneWidget);
  });
  testWidgets('当前401退出详情回登录并清除明细与采样', (tester) async {
    var expiry = false;
    await openDetail(tester, (r) async {
      if (r.url.path.endsWith('/series')) {
        return jsonResponse(jsonEncode(fixture('drive-series')));
      }
      if (expiry) return http.Response('', 401);
      return jsonResponse(jsonEncode(fixture('drive-detail')));
    });
    expiry = true;
    await tester.tap(find.byTooltip('刷新行程明细'));
    await tester.pumpAndSettle();
    expect(find.text('站点访问口令'), findsOneWidget);
    expect(find.text('行程 #1'), findsNothing);
  });
  testWidgets('车辆归属不符拒绝明细，返回后切车旧详情迟到不能污染新车', (tester) async {
    var refresh = false;
    final slow = Completer<http.Response>();
    await openDetail(tester, (r) async {
      if (r.url.path.endsWith('/series')) {
        return jsonResponse(jsonEncode(fixture('drive-series')));
      }
      if (refresh) return slow.future;
      final d = fixture('drive-detail');
      d['vehicle_id'] = 2;
      return jsonResponse(jsonEncode(d));
    });
    expect(find.textContaining('格式不兼容'), findsOneWidget);
    expect(find.bySemanticsLabel('净电耗 188 Wh/km'), findsNothing);
    refresh = true;
    await tester.tap(find.text('重试行程明细'));
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('行笺测试车'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Y · 尾号 0002'));
    await tester.pumpAndSettle();
    slow.complete(jsonResponse(jsonEncode(fixture('drive-detail'))));
    await tester.pumpAndSettle();
    expect(find.text('行程 #1'), findsNothing);
    expect(find.text('Y · 尾号 0002'), findsOneWidget);
  });
  testWidgets('默认未启用底图时详情和采样可读，显示路线示意且没有研发占位文案', (tester) async {
    await openDetail(
      tester,
      (r) async => jsonResponse(
        jsonEncode(
          fixture(
            r.url.path.endsWith('/series') ? 'drive-series' : 'drive-detail',
          ),
        ),
      ),
    );
    expect(find.textContaining('底图未启用'), findsOneWidget);
    expect(find.text('启用地图'), findsOneWidget);
    expect(find.textContaining('后续地图切片'), findsNothing);
    expect(find.text('允许加载底图'), findsNothing);
  });
}
