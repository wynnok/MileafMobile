import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/map/amap_ios_platform.dart';
import 'package:mileaf/src/map/amap_scene_wire.dart';
import 'package:mileaf/src/map/geo.dart';
import 'package:mileaf/src/map/map_consent.dart';
import 'package:mileaf/src/map/map_panel.dart';
import 'package:mileaf/src/map/map_privacy_page.dart';
import 'package:mileaf/src/map/map_scene.dart';

import 'support/fake_map_platform.dart';

const _beijing = Wgs84Point(39.9087, 116.3975);

MapScene _scene({bool empty = false}) => driveScene(
  coordinates: empty
      ? const []
      : const [
          MapCoordinate(31.230, 121.470),
          MapCoordinate(31.231, 121.471),
          MapCoordinate(null, null),
          MapCoordinate(31.233, 121.473),
        ],
  start: empty ? null : const MapCoordinate(31.230, 121.470),
  end: empty ? null : const MapCoordinate(31.233, 121.473),
  selected: empty ? null : const MapCoordinate(31.231, 121.471),
  selectedLabel: '选中',
  brightness: Brightness.light,
  interactive: false,
);

// MapPanel 现在按 A token 绘制浮层，测试宿主必须提供 A 主题。
Widget _app(MapPanel panel, {double? hostHeight}) => MaterialApp(
  theme: mileafTheme(Brightness.dark),
  home: Scaffold(
    body: hostHeight == null
        ? SingleChildScrollView(child: panel)
        : SizedBox(height: hostHeight, child: panel),
  ),
);

void main() {
  test('WGS84 -> GCJ-02 固定点偏移且境外不偏移', () {
    final gcj = gcj02FromWgs84(_beijing);
    expect(gcj.lat, isNot(_beijing.lat));
    expect(gcj.lon, isNot(_beijing.lon));
    expect((gcj.lat - _beijing.lat).abs(), lessThan(0.01));
    expect((gcj.lon - _beijing.lon).abs(), lessThan(0.01));

    const tokyo = Wgs84Point(35.6762, 139.6503);
    final unchanged = gcj02FromWgs84(tokyo);
    expect(unchanged.lat, tokyo.lat);
    expect(unchanged.lon, tokyo.lon);

    for (final point in [
      const Wgs84Point(1.3521, 103.8198), // Singapore
      const Wgs84Point(25.0330, 121.5654), // Taipei
    ]) {
      final kept = gcj02FromWgs84(point);
      expect(kept.lat, point.lat);
      expect(kept.lon, point.lon);
    }
  });

  test('缺失坐标断开轨迹段，源 scene 仍为 WGS84', () {
    final scene = _scene();
    expect(scene.segments.length, 2);
    expect(scene.segments.first.length, 2);
    expect(scene.segments.last.length, 1);
    expect(scene.start!.lat, 31.230);
    final gcj = scene.gcj02Segments;
    expect(gcj.first.first.lat, isNot(31.230));
  });

  test('同意按供应商隔离，不会把路线示意授权沿用给高德', () async {
    final consent = MapConsentController();
    await consent.grant('路线示意');
    expect(consent.isGrantedFor('路线示意'), isTrue);
    expect(consent.isGrantedFor('高德地图'), isFalse);
    await consent.grant('高德地图');
    expect(consent.isGrantedFor('高德地图'), isTrue);
    expect(consent.isGrantedFor('路线示意'), isFalse);
  });

  test('iOS AMap 适配器使用同一高德供应商名', () {
    expect(const AmapIosPlatform().providerName, '高德地图');
  });

  test('AMap 创建参数只含 GCJ-02 场景且不带站点凭据', () {
    final scene = _scene();
    final params = AmapSceneWire.creationParams(
      scene,
      ColorScheme.fromSeed(seedColor: Colors.green),
    );
    expect(params['consent'], isTrue);
    expect(params['interactive'], isFalse);
    final wire = params['scene'] as Map<String, dynamic>;
    final segments = wire['segments'] as List;
    final firstPoint = (segments.first as List).first as List;
    expect(firstPoint[0], isNot(scene.segments.first.first.lat));
    expect(wire['padding'], AmapSceneWire.padding);
    expect(wire.containsKey('token'), isFalse);
    expect(wire.toString(), isNot(contains('Bearer')));
  });

  testWidgets('未同意时不创建地图，同意后创建并显示加载状态', (tester) async {
    final fake = FakeMapPlatform();
    final consent = MapConsentController();
    await tester.pumpWidget(
      _app(
        MapPanel(
          scene: _scene(),
          consent: consent,
          platform: fake,
          height: 300,
        ),
      ),
    );
    expect(find.text('启用地图'), findsOneWidget);
    expect(fake.builds, 0);

    await tester.tap(find.text('启用地图'));
    await tester.pumpAndSettle();
    expect(find.text('允许加载'), findsOneWidget);
    await tester.tap(find.text('允许加载'));
    await tester.pumpAndSettle();

    expect(consent.granted, isTrue);
    expect(fake.builds, 1);
    expect(find.text('正在加载底图'), findsOneWidget);

    fake.completeLoad('GS(test)');
    await tester.pumpAndSettle();
    expect(find.text('正在加载底图'), findsNothing);
    expect(find.textContaining('GS(test)'), findsOneWidget);
    expect(fake.scene!.segments.length, 2);
  });

  testWidgets('200% 字号同意面板不溢出', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final fake = FakeMapPlatform();
    final consent = MapConsentController();
    await tester.pumpWidget(
      _app(
        MapPanel(
          scene: _scene(),
          consent: consent,
          platform: fake,
          height: 300,
        ),
        hostHeight: 300,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('启用地图'), findsOneWidget);
    final surface = tester.getRect(
      find
          .descendant(
            of: find.byType(MapPanel),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    expect(surface.height, 120, reason: 'P04 降级图面120，状态行自然增高');
    await tester.ensureVisible(find.text('启用地图'));
    await tester.pumpAndSettle();
    final panel = tester.getRect(find.byType(MapPanel));
    expect(panel.height, 300, reason: '有限高宿主通过滚动承载自然状态区');
    expect(fake.builds, 0);
    expect(
      tester.getRect(find.text('启用地图')).bottom,
      lessThanOrEqualTo(panel.bottom),
      reason: '200% 下同意条仍完整落在地图内',
    );
  });

  testWidgets('200% 全屏地图同意条留在面板内', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final fake = FakeMapPlatform();
    final consent = MapConsentController();
    await tester.pumpWidget(
      MaterialApp(
        theme: mileafTheme(Brightness.dark),
        home: Scaffold(
          body: MapPanel(
            scene: _scene(),
            consent: consent,
            platform: fake,
            height: double.infinity,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('启用地图'), findsOneWidget);
    await tester.ensureVisible(find.text('启用地图'));
    await tester.pumpAndSettle();
    expect(find.text('启用地图').hitTestable(), findsOneWidget);
    expect(fake.builds, 0);
    await tester.tap(find.text('启用地图'));
    await tester.pumpAndSettle();
    expect(find.textContaining('不会读取手机定位'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('选中采样变化传给地图场景', (tester) async {
    final fake = FakeMapPlatform();
    final consent = MapConsentController();
    await consent.grant('高德地图');
    MapScene selected(double lat) => driveScene(
      coordinates: const [MapCoordinate(31.230, 121.470)],
      start: const MapCoordinate(31.230, 121.470),
      end: null,
      selected: MapCoordinate(lat, 121.470),
      selectedLabel: '选中',
      brightness: Brightness.light,
      interactive: false,
    );
    await tester.pumpWidget(
      _app(
        MapPanel(
          scene: selected(31.231),
          consent: consent,
          platform: fake,
          height: 300,
        ),
      ),
    );
    expect(fake.scene!.selected!.lat, 31.231);
    await tester.pumpWidget(
      _app(
        MapPanel(
          scene: selected(31.232),
          consent: consent,
          platform: fake,
          height: 300,
        ),
      ),
    );
    expect(fake.scene!.selected!.lat, 31.232);
  });

  testWidgets('地图失败保留路线速写并可重试', (tester) async {
    final fake = FakeMapPlatform();
    final consent = MapConsentController();
    await consent.grant('高德地图');
    await tester.pumpWidget(
      _app(
        MapPanel(
          scene: _scene(),
          consent: consent,
          platform: fake,
          height: 300,
        ),
      ),
    );
    fake.fail();
    await tester.pumpAndSettle();
    expect(find.textContaining('地图暂不可用'), findsOneWidget);
    expect(find.text('重试底图'), findsOneWidget);
    await tester.tap(find.text('重试底图'));
    await tester.pumpAndSettle();
    expect(fake.builds, 2);
  });

  testWidgets('15 秒无加载回调走失败兜底', (tester) async {
    final fake = FakeMapPlatform();
    final consent = MapConsentController();
    await consent.grant('高德地图');
    await tester.pumpWidget(
      _app(
        MapPanel(
          scene: _scene(),
          consent: consent,
          platform: fake,
          height: 300,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.textContaining('地图暂不可用'), findsOneWidget);
  });

  testWidgets('地图与隐私页可撤销同意', (tester) async {
    final consent = MapConsentController();
    await consent.grant('高德地图');
    await tester.pumpWidget(
      MaterialApp(
        theme: mileafTheme(Brightness.dark),
        home: MapPrivacyPage(consent: consent, providerName: '高德地图'),
      ),
    );
    expect(find.text('当前已允许加载底图'), findsOneWidget);
    await tester.tap(find.text('关闭底图'));
    await tester.pumpAndSettle();
    expect(consent.granted, isFalse);
    expect(find.text('当前未允许加载底图'), findsOneWidget);
    expect(find.text('重新启用地图'), findsOneWidget);
  });

  testWidgets('路线示意不冒充 Apple 地图隐私', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: mileafTheme(Brightness.dark),
        home: MapPrivacyPage(
          consent: MapConsentController(),
          providerName: '路线示意',
        ),
      ),
    );
    expect(find.textContaining('Apple'), findsNothing);
    expect(find.text('高德隐私政策'), findsNothing);
  });

  testWidgets('空场景不创建地图', (tester) async {
    final fake = FakeMapPlatform();
    final consent = MapConsentController();
    await consent.grant('高德地图');
    await tester.pumpWidget(
      _app(
        MapPanel(
          scene: _scene(empty: true),
          consent: consent,
          platform: fake,
          height: 300,
        ),
      ),
    );
    expect(find.text('没有有效轨迹坐标'), findsOneWidget);
    expect(fake.builds, 0);
  });
}
