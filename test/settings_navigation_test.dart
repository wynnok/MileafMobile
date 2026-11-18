import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/design/icons.dart';
import 'package:mileaf/src/map/map_privacy_page.dart';
import 'package:mileaf/src/map/map_key.dart';

import 'support/shell_harness.dart' show pumpShell;
import 'support/map_key_fixture.dart';
import 'support/vehicle_preferences.dart';
import 'connection_management_test.dart' show saved;
import 'support/test_trust_store.dart' show MemoryTrustStore;

void main() {
  testWidgets('无车辆时仍可从统一设置首页进入地图', (tester) async {
    final keys = MapKeyController(TestKeyStore());
    await keys.restore();
    addTearDown(keys.dispose);
    await tester.pumpWidget(
      MileafApp(
        client: MockClient((_) async => http.Response('[]', 200)),
        sessionStore: saved(),
        trustStore: MemoryTrustStore(),
        mapKeys: keys,
        vehiclePreferences: MemoryVehiclePreferences(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('此站点暂无车辆'), findsOneWidget);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('当前站点'), findsOneWidget);
    await tester.tap(find.text('地图'));
    await tester.pumpAndSettle();
    expect(find.byType(MapPrivacyPage), findsOneWidget);
  });

  testWidgets('320宽双倍字号的菜单箭头仍与标题同行，所有设置可滚动访问', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await pumpShell(tester, textScale: 2);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    final arrow = find
        .byWidgetPredicate(
          (widget) =>
              widget is MileafIcon && widget.name == MileafIconName.chevron,
        )
        .first;
    expect(
      tester.getCenter(arrow).dx,
      greaterThan(tester.getRect(find.text('地图')).right),
    );
    // 行由 ListView 懒构建：要滚到可命中（真实可达）再点。
    await tester.scrollUntilVisible(find.text('服务信息').hitTestable(), 160);
    await tester.pumpAndSettle();
    await tester.tap(find.text('服务信息').hitTestable());
    await tester.pumpAndSettle();
    expect(find.textContaining('Mileaf Server'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('设置首页按偏好与站点分组，地图一步直达且返回保留首页', (tester) async {
    final keys = MapKeyController(TestKeyStore());
    await keys.restore();
    addTearDown(keys.dispose);
    await pumpShell(tester, mapKeys: keys);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('使用偏好'), findsOneWidget);
    expect(find.text('当前站点'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.text('地图'));
    await tester.pumpAndSettle();
    expect(find.byType(MapPrivacyPage), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'a' * 32);
    await tester.tap(find.text('保存 Key'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('使用偏好'), findsOneWidget);
    expect(find.text('已保存'), findsOneWidget);
    keys.keyForMap();
    await keys.save('b' * 32);
    await tester.pumpAndSettle();
    expect(find.text('已保存，重新启动后生效'), findsOneWidget);
    await tester.tap(find.text('服务信息'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mileaf Server'), findsOneWidget);
    expect(find.text('地图'), findsNothing);
  });

  testWidgets('站点连接先展示摘要，更换与重新登录可展开且取消清除草稿', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('站点连接'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.text('更换连接'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '服务根地址'),
      'https://candidate.example',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '站点访问口令'),
      'draft-password',
    );
    await tester.ensureVisible(find.text('取消编辑'));
    await tester.tap(find.text('取消编辑'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.text('重新登录当前站点'));
    await tester.pumpAndSettle();
    final fields = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();
    expect(fields.first.controller!.text, 'https://example.com/prefix');
    expect(fields.last.controller!.text, isEmpty);
    expect(find.text('draft-password'), findsNothing);
  });
}
