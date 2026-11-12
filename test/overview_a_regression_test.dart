import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/c_gallery_client.dart';
import 'support/c_fixture.dart' show cNow, cSite;
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

class _Appearance implements AppearancePreferenceStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? next) async => value = next;
}

class _Currency implements CurrencyPreferenceStore {
  _Currency(this.code);
  final String? code;
  @override
  Future<String?> read(String site) async => code;
  @override
  Future<void> write(String site, String? next) async {}
}

Future<void> openOverview(
  WidgetTester tester, {
  String scenario = 'normal',
  String? currency,
  Brightness brightness = Brightness.dark,
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  final store = MemorySessionStore()
    ..value = jsonEncode({
      'site': cSite,
      'token': 'test',
      'expires_at': '2099-01-01T00:00:00Z',
    });
  final appearanceStore = _Appearance()
    ..value = (brightness == Brightness.dark ? 'dark' : 'light');
  final appearance = AppearanceController(appearanceStore);
  await appearance.restore();
  await tester.pumpWidget(
    MileafApp(
      client: cGalleryClient(scenario: scenario),
      sessionStore: store,
      trustStore: MemoryTrustStore(),
      vehiclePreferences: MemoryVehiclePreferences(),
      currencyPreferences: _Currency(currency),
      appearance: appearance,
      now: () => cNow,
      calendar: () async => CalendarContext('Asia/Shanghai'),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('A 概览时间人性化，费用未知不默认币种', (tester) async {
    await openOverview(tester);
    // State started 18:38, fixture now 18:40.
    expect(find.text('2 分钟前'), findsOneWidget);
    expect(find.textContaining('（币种未知）'), findsNothing);
    expect(find.textContaining('（缺失）'), findsNothing);
    expect(find.textContaining('已知费用 186.4'), findsOneWidget);
    expect(find.textContaining('币种未记录'), findsOneWidget);
    expect(find.textContaining('326880'), findsNothing);
  });

  testWidgets('A 概览已知币种时显示符号且不出现币种未记录', (tester) async {
    await openOverview(tester, currency: 'CNY');
    expect(find.textContaining('已知费用 ¥186.4'), findsOneWidget);
    expect(find.textContaining('币种未记录'), findsNothing);
  });

  testWidgets('A 概览空态不画全零图，最近记录给空态', (tester) async {
    await openOverview(tester, scenario: 'empty');
    expect(find.text('还没有采样点'), findsOneWidget);
    expect(find.textContaining('这段时间还没有行程'), findsOneWidget);
    expect(find.textContaining('还没有充电记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A 概览部分缺失显示破折号，不补零', (tester) async {
    await openOverview(tester, scenario: 'missing');
    expect(find.textContaining('净电耗 —'), findsOneWidget);
    expect(find.textContaining('—'), findsWidgets);
    expect(find.textContaining('0 Wh/km'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A 概览 200% 浅色无横向溢出且主数单位可见', (tester) async {
    await openOverview(tester, brightness: Brightness.light, textScale: 2);
    expect(find.textContaining('320'), findsWidgets);
    expect(find.textContaining('今日 km'), findsOneWidget);
    // 200% 下主图眉标位于首屏之外，仅按需构建；沿页面滚动确认仍可达且文案不变。
    await tester.scrollUntilVisible(find.textContaining('本月 · 驾驶里程'), 240);
    expect(find.textContaining('本月 · 驾驶里程'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
