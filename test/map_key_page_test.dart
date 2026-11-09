import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/map/map_consent.dart';
import 'package:mileaf/src/map/map_key.dart';
import 'package:mileaf/src/map/map_panel.dart';
import 'package:mileaf/src/map/map_privacy_page.dart';
import 'package:mileaf/src/map/map_scene.dart';

import 'support/map_key_fixture.dart';
import 'support/fake_map_platform.dart';

class IosTestBinding extends MapBinding {
  @override
  String get platformLabel => 'iOS';
}

void main() {
  testWidgets('未配置不创建 SDK，速写入口可进入同一设置页，保存后可用', (tester) async {
    final keys = MapKeyController(TestKeyStore());
    await keys.restore();
    final consent = MapConsentController();
    await consent.grant('高德地图');
    final platform = FakeMapPlatform();
    final scene = driveScene(
      coordinates: const [
        MapCoordinate(31.23, 121.47),
        MapCoordinate(31.24, 121.48),
      ],
      start: const MapCoordinate(31.23, 121.47),
      end: const MapCoordinate(31.24, 121.48),
      selected: null,
      selectedLabel: null,
      brightness: Brightness.light,
      interactive: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: mileafTheme(Brightness.light),
        builder: (context, child) =>
            MapKeyScope(controller: keys, child: child!),
        home: Scaffold(
          body: MapPanel(scene: scene, consent: consent, platform: platform),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(platform.builds, 0);
    await tester.tap(find.text('配置地图'));
    await tester.pumpAndSettle();
    expect(find.byType(MapPrivacyPage), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'a' * 32);
    await tester.tap(find.text('保存 Key'));
    await tester.pumpAndSettle();
    expect(find.text('已保存'), findsOneWidget);
    expect(find.text('更换 Key'), findsOneWidget);
    expect(find.text('a' * 32), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(platform.builds, greaterThan(0));
    platform.completeLoad();
    await tester.pumpAndSettle();
    await keys.clear();
    await tester.pumpAndSettle();
    platform.fail();
    await tester.pumpAndSettle();
    expect(find.text('配置地图'), findsOneWidget);
    expect(find.text('正在加载底图'), findsNothing);
  });

  testWidgets('安装包信息延迟读取，显示平台绑定信息并可复制', (tester) async {
    final keys = MapKeyController(TestKeyStore());
    await keys.restore();
    var reads = 0;
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(MapBinding.channel, (call) async {
          expect(call.method, 'getBinding');
          reads++;
          return {'包名': 'app.mileaf.example', '签名 SHA-1': '00:11:22'};
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MapBinding.channel, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: mileafTheme(Brightness.light),
        home: MapPrivacyPage(
          consent: MapConsentController(),
          providerName: '高德地图',
          keys: keys,
        ),
      ),
    );
    expect(reads, 0);
    await tester.ensureVisible(find.text('如何申请 Key'));
    await tester.tap(find.text('如何申请 Key'));
    await tester.pumpAndSettle();
    expect(reads, 1);
    expect(find.text('app.mileaf.example'), findsOneWidget);
    expect(find.text('00:11:22'), findsOneWidget);
    await tester.ensureVisible(find.text('复制包名'));
    await tester.tap(find.text('复制包名'));
    await tester.pumpAndSettle();
    expect(copied, 'app.mileaf.example');
  });

  testWidgets('窄屏大字号下表单、申请帮助及隐私均可滚动访问', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final keys = MapKeyController(TestKeyStore());
    await keys.restore();
    await tester.pumpWidget(
      MaterialApp(
        theme: mileafTheme(Brightness.dark),
        home: MapPrivacyPage(
          consent: MapConsentController(),
          providerName: '高德地图',
          keys: keys,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'bad');
    await tester.ensureVisible(find.text('保存 Key'));
    await tester.tap(find.text('保存 Key'));
    await tester.pumpAndSettle();
    expect(find.textContaining('请输入 32 位'), findsOneWidget);
    await tester.ensureVisible(find.text('重新启用地图'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('iOS 保存失败保留输入，可原地重试并清除', (tester) async {
    final store = TestKeyStore()..fail = true;
    final keys = MapKeyController(store);
    await keys.restore();
    await tester.pumpWidget(
      MaterialApp(
        theme: mileafTheme(Brightness.light),
        home: MapPrivacyPage(
          consent: MapConsentController(),
          providerName: '高德地图',
          keys: keys,
          binding: IosTestBinding(),
        ),
      ),
    );
    expect(find.text('iOS 地图 Key'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'c' * 32);
    await tester.tap(find.text('保存 Key'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Key 保存失败'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'c' * 32,
    );
    store.fail = false;
    await tester.tap(find.text('保存 Key'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清除已保存的 Key'));
    await tester.pumpAndSettle();
    expect(keys.available, isTrue);
    await tester.tap(find.text('清除 Key'));
    await tester.pumpAndSettle();
    expect(keys.available, isFalse);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('配置读取失败可重试恢复表单', (tester) async {
    final store = TestKeyStore()..failRead = true;
    final keys = MapKeyController(store);
    await keys.restore();
    await tester.pumpWidget(
      MaterialApp(
        theme: mileafTheme(Brightness.light),
        home: MapPrivacyPage(
          consent: MapConsentController(),
          providerName: '高德地图',
          keys: keys,
        ),
      ),
    );
    expect(find.text('地图配置读取失败'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    store.failRead = false;
    await tester.tap(find.text('重试读取配置'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });
}
