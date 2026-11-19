import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/icons.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/tokens.dart';
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

/// Records `Clipboard.setData` payloads; returns a reader for the last value.
String? Function() mockClipboard() {
  final copied = <String?>[null];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied[0] = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
  addTearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return () => copied[0];
}

/// Chevron rotation owned by the disclosure, located through its title so the
/// assertion survives an extra fold.
///
/// AP13：两处折叠改 `MileafDisclosure`（R30.3），箭头约定为收起 .25、
/// 展开反方向 -.25（M06 的 180° 旋转不变）。
double chevronTurns(WidgetTester tester, String title) => tester
    .widget<AnimatedRotation>(
      find.descendant(
        of: find.ancestor(
          of: find.text(title),
          matching: find.byType(MileafDisclosure),
        ),
        matching: find.byType(AnimatedRotation),
      ),
    )
    .turns;

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
    // 已保存态换成一条 Key 摘要行，不再有整宽「更换 Key」按钮。
    expect(find.text('更换 Key'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Android 地图 Key'), findsOneWidget);
    expect(find.text('•••• aaaa'), findsOneWidget);
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
    final copied = mockClipboard();
    var reads = 0;
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
    // 两个折叠区默认收起：绑定值、控制台与政策链接都不可见。
    expect(find.text('app.mileaf.example'), findsNothing);
    expect(find.byTooltip('复制包名'), findsNothing);
    expect(chevronTurns(tester, '如何申请 Key'), .25);
    expect(chevronTurns(tester, '数据使用说明'), .25);
    expect(
      tester.getSize(
        find.descendant(
          of: find.byType(AnimatedRotation).first,
          matching: find.byType(MileafIcon),
        ),
      ),
      Size.square(MileafIconMetrics.inline),
    );
    await tester.ensureVisible(find.text('如何申请 Key'));
    await tester.tap(find.text('如何申请 Key'));
    await tester.pumpAndSettle();
    expect(reads, 1);
    // 展开后 chevron 翻 180°，绑定信息成为标签 + 值 + 复制按钮的行。
    expect(chevronTurns(tester, '如何申请 Key'), -.25);
    expect(chevronTurns(tester, '数据使用说明'), .25);
    expect(find.text('登录高德开放平台，创建应用并添加 Key。'), findsOneWidget);
    expect(find.text('app.mileaf.example'), findsOneWidget);
    expect(find.text('00:11:22'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('复制包名'));
    await tester.tap(find.byTooltip('复制包名'));
    await tester.pumpAndSettle();
    expect(copied(), 'app.mileaf.example');
    expect(find.text('包名已复制'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('复制签名 SHA-1'));
    await tester.tap(find.byTooltip('复制签名 SHA-1'));
    await tester.pumpAndSettle();
    expect(copied(), '00:11:22');
    // 控制台行显示短域名，复制仍是完整 URL。
    expect(find.text('console.amap.com/dev/key/app'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('复制高德控制台链接'));
    await tester.tap(find.byTooltip('复制高德控制台链接'));
    await tester.pumpAndSettle();
    expect(copied(), 'https://console.amap.com/dev/key/app');
  });

  testWidgets('已保存态：Key 行进入编辑，破坏行为 error 细线行', (tester) async {
    final keys = await configuredMapKeys();
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
    await tester.pumpAndSettle();
    const colors = MileafColors.light();
    expect(find.text('Android 地图 Key'), findsOneWidget);
    expect(find.text('•••• aaaa'), findsOneWidget);
    expect(find.text('更换 Key'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    // R2：已保存折叠态只剩状态图标一个强调色对象。
    expect(find.byType(MileafButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    // 破坏操作是独立 error 细线行，文案仍在。
    expect(
      tester.widget<Text>(find.text('清除已保存的 Key')).style?.color,
      colors.error,
    );
    await tester.tap(find.text('Android 地图 Key'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    // AP13：主按钮与取消更换都改胶囊组件家族（primary + ghost）。
    expect(find.byType(MileafButton), findsNWidgets(2));
    expect(find.widgetWithText(MileafButton, '保存 Key'), findsOneWidget);
    await tester.tap(find.text('取消更换'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Android 地图 Key'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('待重启态：状态与副说明都用 warning，副说明不再重复重启句', (tester) async {
    final keys = await configuredMapKeys();
    keys.keyForMap();
    await keys.save('b' * 32);
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
    await tester.pumpAndSettle();
    const colors = MileafColors.light();
    expect(find.text('已保存，重新启动后生效'), findsOneWidget);
    expect(find.text('本次运行仍用原 Key'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('已保存，重新启动后生效')).style?.color,
      colors.warning,
    );
    final subtitle = tester.widget<Text>(find.text('本次运行仍用原 Key')).style;
    expect(subtitle?.color, colors.warning);
    // AP13（R22）：micro 过渡别名去向 footnote（13/18），仍不升到 body。
    expect(subtitle?.fontSize, MileafType.footnoteSize);
    // 重启指令只由 status 承载，首屏不再出现两次「重新启动后生效」。
    expect(find.textContaining('重新启动后生效'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('隐私详情默认收起，展开后可复制完整政策链接', (tester) async {
    final keys = await configuredMapKeys();
    final copied = mockClipboard();
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
    await tester.pumpAndSettle();
    expect(find.text('数据使用说明'), findsOneWidget);
    expect(find.text('重新启用地图'), findsOneWidget);
    expect(find.text('当前未允许加载底图'), findsOneWidget);
    expect(find.byTooltip('复制隐私政策链接'), findsNothing);
    await tester.ensureVisible(find.text('数据使用说明'));
    await tester.tap(find.text('数据使用说明'));
    await tester.pumpAndSettle();
    expect(chevronTurns(tester, '数据使用说明'), -.25);
    // 供应商说明随详情展开，冻结的隐私语义不丢失。
    expect(find.textContaining('底图由高德地图提供'), findsOneWidget);
    expect(find.text('https://lbs.amap.com/pages/privacy/'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('复制隐私政策链接'));
    await tester.tap(find.byTooltip('复制隐私政策链接'));
    await tester.pumpAndSettle();
    expect(copied(), 'https://lbs.amap.com/pages/privacy/');
    expect(find.text('隐私政策链接已复制'), findsOneWidget);
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

  testWidgets('窄屏大字号的已保存态不溢出，Key 行与破坏行都可读', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final keys = await configuredMapKeys();
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
    await tester.pumpAndSettle();
    expect(find.text('Android 地图 Key'), findsOneWidget);
    expect(find.text('•••• aaaa'), findsOneWidget);
    await tester.ensureVisible(find.text('清除已保存的 Key'));
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

  testWidgets('秩序断言：分组标题、行文字与脚注共用起始线（R24）', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final keys = await configuredMapKeys();
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
    await tester.pumpAndSettle();

    double left(String text) => tester.getTopLeft(find.text(text)).dx;
    final header = left('本机配置');
    // 分组标题与组内行文字同一条起始线（页面边距 + 16）。
    expect(left('Android 地图 Key'), header);
    expect(left('清除已保存的 Key'), header);
    expect(left('底图授权'), header);
    // 状态块：图标落在卡内内边距处，文字按「图标 + 间距」内收。
    final icon = find.byWidgetPredicate(
      (widget) => widget is MileafIcon && widget.name == MileafIconName.mapPin,
    );
    expect(tester.getTopLeft(icon.first).dx, header);
    final statusText = left('已保存');
    // 细线缩进公式与状态文字起点一致：卡内边距 + 图标 20 + 间距 12。
    expect(statusText, header + MileafIconMetrics.nav + MileafSpace.s12);
    expect(left('保存在本机 · 所有车辆与站点共用'), statusText);

    // 保存后的结果句是画布层脚注：与分组标题同一条起始线。
    await tester.tap(find.text('Android 地图 Key'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'a' * 32);
    await tester.tap(find.text('保存 Key'));
    await tester.pumpAndSettle();
    expect(left('打开详情地图后可查看加载结果。'), header);
    expect(tester.takeException(), isNull);
  });
}
