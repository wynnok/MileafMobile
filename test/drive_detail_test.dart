import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/map/map_consent.dart';
import 'package:mileaf/src/map/map_panel.dart';
import 'package:mileaf/src/map/map_platform.dart';
import 'package:mileaf/src/workspace.dart';

import 'drives_test.dart' show openDrives, jsonResponse;
import 'support/fake_map_platform.dart';

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
  // 记录之后还有节奏卡与页尾：把记录行移到视口中部，避免被收起顶栏遮住。
  await Scrollable.ensureVisible(
    tester.element(find.byKey(const ValueKey('drive-1'))),
    alignment: .5,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('drive-1')));
  await tester.pumpAndSettle();
}

/// 页面自身的纵向列表：技术详情等可复制文本自带滚动区，滚动必须以页面为准。
Finder get pageScrollable => find
    .descendant(
      of: find.byType(RefreshIndicator),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  testWidgets('U07 路线摘要先于紧凑降级地图与结果', (tester) async {
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
    await tester.scrollUntilVisible(find.bySemanticsLabel('距离 20.0 km'), 100);
    final map = tester.getRect(
      find
          .descendant(
            of: find.byType(MapPanel),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    final route = tester.getRect(find.textContaining(' → ').first);
    final result = tester.getRect(find.bySemanticsLabel('距离 20.0 km'));
    final viewWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(route.top, lessThan(map.top));
    expect(route.top, lessThan(result.top));
    // P04 地图卡在内容网格内（页面边距 20/24、最大宽 560），降级时图面 120。
    final contentWidth = viewWidth.clamp(0.0, 560.0);
    final inset = viewWidth >= 390 ? 24.0 : 20.0;
    expect(map.left, (viewWidth - contentWidth) / 2 + inset);
    expect(map.width, contentWidth - 2 * inset);
    expect(map.height, 120);
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
    await tester.scrollUntilVisible(find.text('与近 30 天相比'), 140);
    // CP03：负值用真负号；参照为真实 0 时照实显示 0。
    expect(find.bySemanticsLabel('本次 −12 Wh/km'), findsOneWidget);
    expect(find.bySemanticsLabel('近 30 天 0 Wh/km'), findsOneWidget);
    // 口径说明移入页尾「关于这些数据」，不再用弹窗（R30.2）。
    await tester.scrollUntilVisible(find.text('口径与估算').hitTestable(), 260);
    await tester.tap(find.text('口径与估算'));
    await tester.pumpAndSettle();
    expect(find.textContaining('均为服务器估算'), findsWidgets);
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
    await tester.scrollUntilVisible(find.text('电量变化'), 140);
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
      find.text('与近 30 天相比'),
      200,
      scrollable: pageScrollable,
    );
    bool hasReference() => tester
        .widgetList<MetricBlock>(find.byType(MetricBlock))
        .any((block) => block.semanticLabel == '近 30 天 188 Wh/km');
    expect(hasReference(), isFalse);
    fail = false;
    final retry = find.widgetWithText(TextButton, '重试');
    await tester.scrollUntilVisible(retry, 160, scrollable: pageScrollable);
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('与近 30 天相比'),
      200,
      scrollable: pageScrollable,
    );
    expect(hasReference(), isTrue);
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
    final reference = find.bySemanticsLabel('近 30 天 188 Wh/km');
    await tester.scrollUntilVisible(reference, 180);
    expect(reference, findsOneWidget);
    await tester.scrollUntilVisible(find.text('口径与估算'), 260);
    await tester.tap(find.text('口径与估算'));
    await tester.pumpAndSettle();
    expect(find.textContaining('近 30 天为行程开始日前 30 个完整本地日'), findsOneWidget);
  });
  testWidgets('行程电量区间保留出发到达和未知值，不伪造成补能或零', (tester) async {
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
      final known = find.bySemanticsLabel(RegExp('电量区间.*82.*72.*尺度 0 至 100%'));
      await tester.scrollUntilVisible(known, 180);
      await tester.pumpAndSettle();
      expect(known, findsOneWidget);
      expect(find.text('到达 72%'), findsOneWidget);
      expect(find.text('出发 82%'), findsOneWidget);
      // 2026-11-01 用户裁定：标签按行程顺序「出发」在前。
      expect(
        tester.getTopLeft(find.text('出发 82%')).dx,
        lessThan(tester.getTopLeft(find.text('到达 72%')).dx),
        reason: '出发在左，到达在右',
      );
      missing = true;
      await tester.tap(find.byTooltip('刷新行程详情'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('电量区间.*82.*到达 未知')), findsOneWidget);
      expect(find.text('到达 —'), findsOneWidget);
      expect(find.text('到达 0%'), findsNothing);
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
      '电耗 188 Wh/km',
      // R21.4/R29：卡片标题「行驶过程」是该区的定位锚点。
      '行驶过程',
    ]) {
      final target =
          (text.startsWith('距离') ||
                      text.startsWith('时长') ||
                      text.startsWith('电耗')
                  ? find.bySemanticsLabel(text)
                  : find.textContaining(text))
              .hitTestable();
      await tester.scrollUntilVisible(target, 120);
      expect(target, findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    // 事实表把字段名与值拆成两个排版角色，读屏与断言都按整行的语义读值。
    for (final text in [
      '平均速度 10 km/h',
      '最高速度 90 km/h',
      '最大功率 120 kW',
      '车外均温 15.0 °C',
      '车内均温 21.0 °C',
    ]) {
      final target = find.bySemanticsLabel(text).hitTestable();
      await tester.scrollUntilVisible(target, 120);
      expect(target, findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.scrollUntilVisible(
      find.text('关于这些数据'),
      260,
      scrollable: pageScrollable,
    );
    await tester.ensureVisible(find.text('技术详情'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('技术详情'));
    await tester.pumpAndSettle();
    for (final text in ['净能量 3.75 kWh', '起点电量 70%', '终点电量 70%', '续航口径 额定']) {
      final target = find.textContaining(text);
      await tester.scrollUntilVisible(target, 120, scrollable: pageScrollable);
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
    await tester.scrollUntilVisible(find.text('关于这些数据'), 260);
    await tester.pumpAndSettle();
    await tester.tap(find.text('技术详情'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('起点地址 样例路1号'),
      200,
      scrollable: pageScrollable,
    );
    expect(find.textContaining('起点围栏 住宅围栏'), findsOneWidget);
    expect(find.textContaining('起点地址 样例路1号'), findsOneWidget);
    expect(find.textContaining('终点地址'), findsNothing);
  });

  testWidgets('360x800详情先读路线结果与过程图，向下可读电量区间', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.padding = tester.view.viewPadding;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
      tester.view.resetPadding();
    });
    // §6 预算按「正常地图」测量：注入已同意且有 Key 的底图并让它加载完成。
    final consent = MapConsentController();
    await consent.grant();
    final platform = FakeMapPlatform();
    await openDetail(
      tester,
      (r) async => jsonResponse(
        jsonEncode(
          fixture(
            r.url.path.endsWith('/series') ? 'drive-series' : 'drive-detail',
          ),
        ),
      ),
      mapConsent: consent,
      mapPlatform: platform,
    );
    platform.completeLoad('GS(test)');
    await tester.pumpAndSettle();
    // §6 行程详情首屏：正常地图、三项关键值与过程图读数头、绘图区首 64 可见。
    expect(find.bySemanticsLabel('距离 20.0 km'), findsOneWidget);
    expect(find.bySemanticsLabel('电耗 188 Wh/km'), findsOneWidget);
    expect(find.byType(MileafChartReadout), findsOneWidget);
    final viewport = tester.getRect(find.byType(RefreshIndicator));
    final plot = tester.getRect(find.byKey(const ValueKey('sample-chart')));
    // 有效视口扣除底部安全区（§6 基准：safeArea 上下各 24）。
    final visible = viewport.bottom - 24 - plot.top;
    expect(
      visible,
      greaterThanOrEqualTo(64),
      reason: '绘图区首 64 可见（预算），实际 $visible',
    );
    await tester.scrollUntilVisible(find.text('电量变化'), 140);
    expect(find.text('电量变化'), findsOneWidget);
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
    expect(find.text('行程详情'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('电耗 188 Wh/km').hitTestable(),
      160,
    );
    expect(find.bySemanticsLabel('电耗 188 Wh/km'), findsWidgets);
    await tester.scrollUntilVisible(find.bySemanticsLabel('最高速度 90 km/h'), 200);
    expect(find.bySemanticsLabel('最高速度 90 km/h'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('电量').hitTestable(), -200);
    await tester.tap(find.text('电量'));
    await tester.pumpAndSettle();
    // R29：可见读值改为读数头（时间行 + 数值行）。
    expect(find.text('70%'), findsOneWidget);
    expect(find.textContaining('不代表连续观测'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('口径与估算'),
      260,
      scrollable: pageScrollable,
    );
    await tester.ensureVisible(find.text('口径与估算'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('口径与估算'));
    await tester.pumpAndSettle();
    expect(find.textContaining('连线只表示采样顺序'), findsOneWidget);
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
    expect(find.textContaining('进行中'), findsWidgets);
    final retry = find.widgetWithText(TextButton, '重试');
    await tester.scrollUntilVisible(retry, 300, scrollable: pageScrollable);
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    failing = false;
    await tester.tap(retry);
    await tester.pumpAndSettle();
    // R29：读数头数值行保留单位，单位与数值紧贴。
    await tester.scrollUntilVisible(find.text('0 km/h'), 250);
    expect(find.text('0 km/h'), findsOneWidget);
    expect(find.textContaining('只有 1 个数据点'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('电量').hitTestable(), -200);
    await tester.tap(find.text('电量'));
    await tester.pumpAndSettle();
    // R29：缺失值读数头直接给「—」，并在读数头下说明「这一项没有记录」。
    expect(find.text('—'), findsOneWidget);
    expect(find.text('这一项没有记录'), findsOneWidget);
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
    expect(find.text('行程详情'), findsOneWidget);
    expect(find.textContaining('记录已不可用'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('没有采样点'), 250);
    expect(find.text('没有采样点'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('返回行程列表'), -250);
    await tester.tap(find.text('返回行程列表'));
    await tester.pumpAndSettle();
    expect(find.text('行程详情'), findsNothing);
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
    await tester.scrollUntilVisible(find.text('行驶过程'), 200);
    await tester.ensureVisible(find.byKey(const ValueKey('sample-chart')));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byKey(const ValueKey('sample-chart')));
    await tester.tapAt(Offset(rect.left + rect.width * 0.49, rect.center.dy));
    await tester.pumpAndSettle();
    // R29：读数头把日期与数值分行，缺失点数值行为「—」。
    await tester.scrollUntilVisible(find.text('行驶过程'), 150);
    expect(find.text('—'), findsWidgets);
    final sampleRect = tester.getRect(
      find.byKey(const ValueKey('sample-chart')),
    );
    await tester.tapAt(
      Offset(sampleRect.left + sampleRect.width * 0.9, sampleRect.center.dy),
    );
    await tester.pumpAndSettle();
    expect(find.text('80 km/h'), findsOneWidget);
    refresh = true;
    await tester.scrollUntilVisible(find.byTooltip('刷新行程详情'), -300);
    await tester.tap(find.byTooltip('刷新行程详情'));
    await tester.pumpAndSettle();
    // CP07：刷新失败有旧数据时说清显示的是哪一刻的数据。
    await tester.scrollUntilVisible(find.textContaining('没能更新，显示的是'), -200);
    expect(find.textContaining('没能更新，显示的是'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('路线示意，非导航路线').hitTestable(),
      -200,
    );
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('电耗 188 Wh/km').hitTestable(),
      160,
    );
    expect(find.bySemanticsLabel('电耗 188 Wh/km'), findsOneWidget);
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
    await tester.tap(find.byTooltip('刷新行程详情'));
    await tester.pumpAndSettle();
    expect(find.text('站点访问口令'), findsOneWidget);
    expect(find.text('行程详情'), findsNothing);
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
    expect(find.textContaining('数据格式不受支持'), findsOneWidget);
    expect(find.bySemanticsLabel('电耗 188 Wh/km'), findsNothing);
    refresh = true;
    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('行笺测试车'));
    await tester.pumpAndSettle();
    // 弹层行按 P16 写「Y，尾号 0002」（CP09.1 逗号）。
    await tester.tap(find.text('Y，尾号 0002'));
    await tester.pumpAndSettle();
    slow.complete(jsonResponse(jsonEncode(fixture('drive-detail'))));
    await tester.pumpAndSettle();
    expect(find.text('行程详情'), findsNothing);
    // 弹层关闭后由顶栏车辆胶囊确认已换车；胶囊仍按 vehicleName 的「·」拼接。
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
    // P04：地图卡下的脚注说明路线示意（CP09 用逗号，不用「·」）。
    expect(find.text('路线示意，非导航路线'), findsOneWidget);
    expect(find.textContaining('后续地图切片'), findsNothing);
    expect(find.text('允许加载底图'), findsNothing);
  });
}
