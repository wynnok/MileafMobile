import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mileaf/src/map_candidate.dart';

import 'drives_test.dart' show openDrives, jsonResponse;

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
        as Map<String, dynamic>;
Future<void> openDetail(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler, {
  MapConfiguration? mapConfiguration,
}) async {
  await openDrives(tester, (r) async {
    if (r.url.path.endsWith('/1/drives')) {
      return jsonResponse(
        jsonEncode({
          'items': [fixture('drive-detail')],
          'next_cursor': null,
        }),
      );
    }
    return handler(r);
  }, mapConfiguration: mapConfiguration);
  await tester.tap(find.byKey(const ValueKey('drive-1')));
  await tester.pumpAndSettle();
}

void main() {
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
    expect(find.textContaining('净电耗 188 Wh/km'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('最高速度 90'), 200);
    expect(find.textContaining('最高速度 90 km/h'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('电量'), 200);
    await tester.tap(find.text('电量'));
    await tester.pumpAndSettle();
    expect(find.textContaining('电量读数 70 %'), findsOneWidget);
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
    await tester.scrollUntilVisible(find.text('重试行程采样'), 300);
    failing = false;
    await tester.tap(find.text('重试行程采样'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('速度读数 0'), 250);
    expect(find.textContaining('速度读数 0 km/h'), findsOneWidget);
    expect(find.textContaining('仅1个采样点'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('电量'), -200);
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
    await tester.scrollUntilVisible(find.text('最近行程'), 300);
    await tester.tap(find.text('最近行程'));
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
    expect(find.textContaining('保留上次快照'), findsOneWidget);
    await tester.scrollUntilVisible(find.byTooltip('刷新行程明细'), -300);
    await tester.tap(find.byTooltip('刷新行程明细'));
    await tester.pumpAndSettle();
    expect(find.textContaining('净电耗 188 Wh/km'), findsOneWidget);
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
    expect(find.textContaining('净电耗 188 Wh/km'), findsNothing);
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
  testWidgets('未配置地图时详情和采样可读，不向第三方联网且没有研发占位文案', (tester) async {
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
    await tester.scrollUntilVisible(find.textContaining('地图暂不可用'), 250);
    expect(find.textContaining('地图暂不可用'), findsOneWidget);
    expect(find.textContaining('后续地图切片'), findsNothing);
    expect(find.text('允许加载底图'), findsNothing);
  });
}
