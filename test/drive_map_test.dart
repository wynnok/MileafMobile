import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart' show FlutterMap;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/src/map_candidate.dart';

import 'drive_detail_test.dart' show openDetail, fixture;
import 'drives_test.dart' show jsonResponse;

const provider = CandidateMapProvider(
  urlTemplate: 'https://maps.example.com/{z}/{x}/{y}.png',
  attribution: '授权底图测试来源',
  coordinateSystem: 'EPSG:4326',
);
http.Response tile() => http.Response.bytes(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
  ),
  200,
);
Future<http.Response> business(http.Request r) async {
  expect(r.headers['authorization'], 'Bearer test');
  if (r.url.path.endsWith('/series')) {
    return jsonResponse(
      '{"drive_id":1,"resolution":"server_sampled","points":5,"series":[{"t":"2026-03-15T08:00:00Z","lat":31.23,"lon":121.47},{"t":"2026-03-15T08:01:00Z","lat":31.231,"lon":121.471},{"t":"2026-03-15T08:02:00Z","lat":null,"lon":null},{"t":"2026-03-15T08:03:00Z","lat":31.233,"lon":121.473},{"t":"2026-03-15T08:04:00Z","lat":31.234,"lon":121.474}]}',
    );
  }
  final body = fixture('drive-detail');
  body['end']['lat'] = 31.235;
  body['end']['lon'] = 121.475;
  return jsonResponse(jsonEncode(body));
}

Future<void> scrollPageTo(
  WidgetTester tester,
  Finder target,
  double delta,
) async {
  for (var i = 0; i < 30 && target.hitTestable().evaluate().isEmpty; i++) {
    final viewport = tester.getRect(find.byType(RefreshIndicator));
    // The C map spans the width; swipe below its first viewport.
    await tester.dragFrom(
      Offset(viewport.right - 4, viewport.bottom - 8),
      Offset(0, -delta),
    );
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsOneWidget);
}

void main() {
  testWidgets('平移地图后选择新的曲线采样会使选中位置重新可见', (tester) async {
    final semantics = tester.ensureSemantics();
    await openDetail(
      tester,
      business,
      mapConfiguration: MapConfiguration(
        provider: provider,
        sourceCrs: 'EPSG:4326',
        tileClient: MockClient((_) async => tile()),
      ),
    );
    await tester.scrollUntilVisible(find.text('允许加载底图').hitTestable(), 160);
    await tester.tap(find.text('允许加载底图'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FlutterMap));
    await tester.pumpAndSettle();
    final bounds = tester.getRect(find.byType(FlutterMap));
    await tester.dragFrom(bounds.center, const Offset(-700, -700));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('selected-drive-sample')).hitTestable(),
      findsNothing,
    );
    await scrollPageTo(tester, find.text('后一个采样'), 180);
    await tester.tap(find.text('后一个采样'));
    await tester.pumpAndSettle();
    await scrollPageTo(tester, find.text('行程地图'), -180);
    await tester.ensureVisible(find.byType(FlutterMap));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('selected-drive-sample')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('选中采样位置.*16:01:00', dotAll: true)),
      findsOneWidget,
    );
    semantics.dispose();
  });
  testWidgets('图表选点与地图位置同步，缺失坐标不显示选中位置', (tester) async {
    final semantics = tester.ensureSemantics();
    await openDetail(
      tester,
      business,
      mapConfiguration: MapConfiguration(
        provider: provider,
        sourceCrs: 'EPSG:4326',
        tileClient: MockClient((_) async => tile()),
      ),
    );
    await tester.scrollUntilVisible(find.text('允许加载底图'), 200);
    await tester.tap(find.text('允许加载底图'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(
        RegExp('选中采样位置.*2026-03-15 16:00:00', dotAll: true),
      ),
      findsOneWidget,
    );
    await scrollPageTo(tester, find.text('后一个采样'), 180);
    await tester.tap(find.text('后一个采样'));
    await tester.pumpAndSettle();
    await scrollPageTo(tester, find.text('行程地图'), -180);
    await tester.ensureVisible(find.byType(FlutterMap));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(
        RegExp('选中采样位置.*2026-03-15 16:01:00', dotAll: true),
      ),
      findsOneWidget,
    );
    await scrollPageTo(tester, find.text('后一个采样'), 180);
    await tester.tap(find.text('后一个采样'));
    await tester.pumpAndSettle();
    await scrollPageTo(tester, find.text('行程地图'), -180);
    await tester.ensureVisible(find.byType(FlutterMap));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('选中采样位置')), findsNothing);
    semantics.dispose();
  });
  testWidgets('真实详情同意前0瓦片，独立底图无Bearer不跳转，缺点断线并标明起终点，可局部重试', (tester) async {
    final semantics = tester.ensureSemantics();
    var calls = 0;
    var failing = true;
    final tiles = MockClient((r) async {
      calls++;
      expect(r.url.host, 'maps.example.com');
      expect(
        r.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
      expect(r.headers['User-Agent'], 'Mileaf/0.1 (map)');
      expect(r.followRedirects, isFalse);
      return failing ? http.Response('', 503) : tile();
    });
    await openDetail(
      tester,
      business,
      mapConfiguration: MapConfiguration(
        provider: provider,
        sourceCrs: 'EPSG:4326',
        tileClient: tiles,
      ),
    );
    await tester.scrollUntilVisible(find.text('允许加载底图'), 250);
    expect(calls, 0);
    expect(find.textContaining('第三方将收到 IP'), findsOneWidget);
    await tester.tap(find.text('允许加载底图'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('重试底图'));
    await tester.pumpAndSettle();
    expect(calls, greaterThan(0));
    expect(find.text('4 个有效采样点 · 2 段轨迹'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('行程地图'), -180);
    expect(
      find.bySemanticsLabel(RegExp('行程起点')),
      findsOneWidget,
      reason: tester
          .widgetList<Icon>(find.byType(Icon))
          .map((i) => i.semanticLabel)
          .join(' | '),
    );
    expect(find.bySemanticsLabel(RegExp('行程终点')), findsOneWidget);
    await tester.ensureVisible(find.text('重试底图'));
    await tester.pumpAndSettle();
    failing = false;
    await tester.tap(find.text('重试底图'));
    await tester.pumpAndSettle();
    expect(find.text('底图加载失败，其他记录仍可阅读'), findsNothing);
    await tester.scrollUntilVisible(find.byTooltip('放大地图'), 100);
    await tester.tap(find.byTooltip('放大地图'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
  testWidgets('发行方未核准源CRS时拒绝地图，配置不能代替源坐标校准', (tester) async {
    var tiles = 0;
    await openDetail(
      tester,
      business,
      mapConfiguration: MapConfiguration(
        provider: provider,
        tileClient: MockClient((r) async {
          tiles++;
          return tile();
        }),
      ),
    );
    await tester.scrollUntilVisible(find.textContaining('坐标参考系尚未核准'), 250);
    expect(tiles, 0);
    expect(find.text('允许加载底图'), findsNothing);
  });
  testWidgets('退出重开记录重新告知，旧地图授权不跨详情沿用', (tester) async {
    var calls = 0;
    await openDetail(
      tester,
      business,
      mapConfiguration: MapConfiguration(
        provider: provider,
        sourceCrs: 'EPSG:4326',
        tileClient: MockClient((r) async {
          calls++;
          return tile();
        }),
      ),
    );
    await tester.scrollUntilVisible(find.text('允许加载底图'), 250);
    await tester.tap(find.text('允许加载底图'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    final previous = calls;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('drive-1')).hitTestable(),
      140,
    );
    await tester.tap(find.byKey(const ValueKey('drive-1')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('允许加载底图'), 250);
    expect(calls, previous);
    expect(find.text('允许加载底图'), findsOneWidget);
  });
  for (final count in [0, 1]) {
    testWidgets('真实详情$count个轨迹点保留空态或单点，不虚构连线', (tester) async {
      var calls = 0;
      await openDetail(
        tester,
        (r) async {
          if (r.url.path.endsWith('/series')) {
            return jsonResponse(
              jsonEncode({
                'drive_id': 1,
                'resolution': count == 0 ? 'empty' : 'server_sampled',
                'points': count,
                'series': count == 0
                    ? []
                    : [
                        {
                          't': '2026-03-15T08:00:00Z',
                          'lat': 31.23,
                          'lon': 121.47,
                        },
                      ],
              }),
            );
          }
          final d = fixture('drive-detail');
          d['start']['lat'] = null;
          d['start']['lon'] = null;
          d['end']['lat'] = null;
          d['end']['lon'] = null;
          return jsonResponse(jsonEncode(d));
        },
        mapConfiguration: MapConfiguration(
          provider: provider,
          sourceCrs: 'EPSG:4326',
          tileClient: MockClient((r) async {
            calls++;
            return tile();
          }),
        ),
      );
      if (count == 0) {
        await tester.scrollUntilVisible(find.text('没有有效轨迹坐标'), 200);
        expect(calls, 0);
      } else {
        await tester.scrollUntilVisible(find.text('允许加载底图'), 250);
        await tester.tap(find.text('允许加载底图'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('单个采样点'), 200);
        expect(find.text('单个采样点'), findsOneWidget);
        expect(calls, greaterThan(0));
      }
      expect(find.text('采样连线仅为示意；缺失坐标处已断开。'), findsNothing);
    });
  }
}
