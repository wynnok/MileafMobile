import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mileaf/src/map_candidate.dart';

const provider = CandidateMapProvider(
  urlTemplate: 'https://maps.example.com/{z}/{x}/{y}.png',
  attribution: '测试供应商 · 未验证',
  coordinateSystem: 'EPSG:4326',
);

void main() {
  testWidgets('未配置底图时保留记录说明且不联网', (tester) async {
    final client = MockClient((request) async => throw StateError('不得联网'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Text('行程指标仍可阅读'),
              CandidateMap(
                coordinates: const [MapCoordinate(31.23, 121.47)],
                sourceCrs: 'EPSG:4326',
                tileClient: client,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('地图暂不可用：此版本尚未配置底图服务，其他记录仍可阅读'), findsOneWidget);
    expect(find.text('行程指标仍可阅读'), findsOneWidget);
    expect(find.text('允许加载底图'), findsNothing);
  });
  testWidgets('坐标参考系未确认时不联网，确认后先展示第三方告知', (tester) async {
    final client = MockClient((request) async => throw StateError('不得联网'));
    for (final crs in [null, 'EPSG:4326']) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CandidateMap(
              key: ValueKey(crs),
              coordinates: const [MapCoordinate(31.23, 121.47)],
              sourceCrs: crs,
              provider: provider,
              tileClient: client,
            ),
          ),
        ),
      );
      if (crs == null) {
        expect(find.text('地图暂不可用：坐标参考系尚未核准，其他记录仍可阅读'), findsOneWidget);
        expect(find.text('允许加载底图'), findsNothing);
      } else {
        expect(find.textContaining('第三方将收到 IP 和可见区域'), findsOneWidget);
        expect(find.text('允许加载底图'), findsOneWidget);
      }
    }
  });
  testWidgets('同意后独立请求底图并展示单点、署名和缩放操作', (tester) async {
    var requested = false;
    final client = MockClient((request) async {
      requested = true;
      expect(request.url.host, 'maps.example.com');
      expect(
        request.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('authorization')),
      );
      expect(request.followRedirects, isFalse);
      return http.Response.bytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
        ),
        200,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CandidateMap(
            coordinates: const [MapCoordinate(31.23, 121.47)],
            sourceCrs: 'EPSG:4326',
            provider: provider,
            tileClient: client,
          ),
        ),
      ),
    );
    expect(requested, isFalse);
    await tester.tap(find.text('允许加载底图'));
    await tester.pumpAndSettle();
    expect(requested, isTrue);
    expect(find.text('测试供应商 · 未验证'), findsOneWidget);
    expect(find.text('单个采样点'), findsOneWidget);
    await tester.tap(find.byTooltip('放大地图'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('底图失败保留其他内容并允许局部重试', (tester) async {
    var failing = true;
    final client = MockClient(
      (request) async => failing
          ? http.Response('unavailable', 503)
          : http.Response.bytes(
              base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
              ),
              200,
            ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Text('里程 12.3 km'),
              CandidateMap(
                coordinates: const [MapCoordinate(31.23, 121.47)],
                sourceCrs: 'EPSG:4326',
                provider: provider,
                tileClient: client,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('允许加载底图'));
    await tester.pumpAndSettle();
    expect(find.text('底图加载失败，其他记录仍可阅读'), findsOneWidget);
    expect(find.text('里程 12.3 km'), findsOneWidget);
    failing = false;
    await tester.tap(find.text('重试底图'));
    await tester.pumpAndSettle();
    expect(find.text('底图加载失败，其他记录仍可阅读'), findsNothing);
    expect(find.text('测试供应商 · 未验证'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('无有效坐标时不联网，有缺失的多点轨迹分段展示起终点', (tester) async {
    final semantics = tester.ensureSemantics();
    var requested = false;
    final client = MockClient((request) async {
      requested = true;
      return http.Response.bytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
        ),
        200,
      );
    });
    final points = <MapCoordinate?>[
      null,
      const MapCoordinate(91, 121),
      const MapCoordinate(double.nan, 0),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CandidateMap(
            key: const ValueKey('empty'),
            coordinates: points,
            sourceCrs: 'EPSG:4326',
            provider: provider,
            tileClient: client,
          ),
        ),
      ),
    );
    expect(find.text('没有有效轨迹坐标'), findsOneWidget);
    expect(requested, isFalse);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CandidateMap(
            key: const ValueKey('segments'),
            coordinates: const [
              MapCoordinate(31.230, 121.470),
              MapCoordinate(31.231, 121.471),
              null,
              MapCoordinate(31.233, 121.473),
              MapCoordinate(31.234, 121.474),
            ],
            sourceCrs: 'EPSG:4326',
            provider: provider,
            tileClient: client,
          ),
        ),
      ),
    );
    await tester.tap(find.text('允许加载底图'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('地图数据说明'));
    await tester.pumpAndSettle();
    expect(find.text('4 个有效采样点 · 2 段轨迹'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('首个采样点')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('末个采样点')), findsOneWidget);
    expect(find.text('采样连线仅为示意；缺失坐标处已断开。'), findsOneWidget);
    await tester.tap(find.byTooltip('适配轨迹'));
    await tester.pumpAndSettle();
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('不安全或不完整发布配置不会联网', (tester) async {
    final client = MockClient((request) async => throw StateError('不得联网'));
    for (final url in [
      'http://maps.example.com/{z}/{x}/{y}',
      'https://user:password@maps.example.com/{z}/{x}/{y}',
      'https://maps.example.com/tile',
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CandidateMap(
              key: ValueKey(url),
              coordinates: const [MapCoordinate(31.23, 121.47)],
              sourceCrs: 'EPSG:4326',
              provider: CandidateMapProvider(
                urlTemplate: url,
                attribution: '测试来源',
                coordinateSystem: 'EPSG:4326',
              ),
              tileClient: client,
            ),
          ),
        ),
      );
      expect(find.text('地图暂不可用：底图服务配置无效，其他记录仍可阅读'), findsOneWidget);
      expect(find.text('允许加载底图'), findsNothing);
    }
  });

  testWidgets('更换底图供应商后重新征得同意，不沿用旧供应商授权', (tester) async {
    final hosts = <String>[];
    final client = MockClient((request) async {
      hosts.add(request.url.host);
      return http.Response.bytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
        ),
        200,
      );
    });
    Widget app(CandidateMapProvider config) => MaterialApp(
      home: Scaffold(
        body: CandidateMap(
          coordinates: const [MapCoordinate(31.23, 121.47)],
          sourceCrs: 'EPSG:4326',
          provider: config,
          tileClient: client,
        ),
      ),
    );
    await tester.pumpWidget(app(provider));
    await tester.tap(find.text('允许加载底图'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      app(
        const CandidateMapProvider(
          urlTemplate: 'https://second.example.com/{z}/{x}/{y}.png',
          attribution: '另一供应商',
          coordinateSystem: 'EPSG:4326',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('允许加载底图'), findsOneWidget);
    expect(hosts, isNot(contains('second.example.com')));
  });
}
