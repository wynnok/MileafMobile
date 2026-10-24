import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
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
    await tester.scrollUntilVisible(find.text('重试底图'), 200);
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
    await tester.scrollUntilVisible(find.text('重试底图'), 180);
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
