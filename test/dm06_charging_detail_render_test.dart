// DM06（MG01 彩色面积登记）充电详情 opt-in 渲染入口。未设置
// MILEAF_RENDER_OUTPUT / MILEAF_RENDER_FONT 时跳过；机位为详情页浅/深
// 390×844 100% 各两张（顶部电量卡 + 下半计量/费用卡）。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/charging_detail.dart';
import 'package:mileaf/src/charging_page.dart' show ChargingPage;
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/c_fixture.dart' show cNow, cSite;
import 'support/c_gallery_client.dart';
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'support/test_trust_store.dart' show MemoryTrustStore;

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

class _AppearanceStore implements AppearancePreferenceStore {
  _AppearanceStore(this.value);
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? value) async => this.value = value;
}

class _CurrencyStore implements CurrencyPreferenceStore {
  @override
  Future<String?> read(String site) async => 'CNY';

  @override
  Future<void> write(String site, String? code) async {}
}

void main() {
  setUpAll(() async {
    if (fontPath.isNotEmpty) await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('充电详情图册：浅/深 390×844 100%', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
      tester.view.resetPadding();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    Finder pageScroll(Type page) => find
        .descendant(
          of: find.byType(page),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        )
        .first;

    Future<void> scene(
      WidgetTester tester,
      GlobalKey boundary,
      Brightness brightness,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
      tester.view.padding = tester.view.viewPadding;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      final session = MemorySessionStore()
        ..value = jsonEncode({
          'site': cSite,
          'token': 'test',
          'expires_at': '2099-01-01T00:00:00Z',
        });
      final appearance = AppearanceController(
        _AppearanceStore(brightness.name),
      );
      await appearance.restore();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MileafApp(
            client: cGalleryClient(),
            sessionStore: session,
            trustStore: MemoryTrustStore(),
            vehiclePreferences: MemoryVehiclePreferences(),
            currencyPreferences: _CurrencyStore(),
            appearance: appearance,
            now: () => cNow,
            calendar: () async => CalendarContext('Asia/Shanghai'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(MileafNavBar),
          matching: find.text('充电'),
        ),
      );
      await tester.pumpAndSettle();
      // 先进「全部充电记录」（入口在最近充电区块标题尾部），记录行在
      // 记录模式页顶，点 charge-9 打开详情。
      final viewAll = find.text('查看全部');
      var steps = 0;
      while (viewAll.evaluate().isEmpty && steps++ < 24) {
        await tester.drag(pageScroll(ChargingPage), const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      await Scrollable.ensureVisible(tester.element(viewAll), alignment: 0.1);
      await tester.pumpAndSettle();
      await tester.tap(viewAll.hitTestable());
      await tester.pumpAndSettle();
      final recordRow = find.byKey(const ValueKey('charge-9')).hitTestable();
      await tester.tap(recordRow.first);
      await tester.pumpAndSettle();
      await saveRenderPng(
        tester,
        find.byKey(boundary),
        '$output/充电详情-顶部-${brightness.name}-390x844-100.png',
      );
      final detailScroll = pageScroll(ChargingDetailPage);
      steps = 0;
      while (find.text('费用明细').evaluate().isEmpty && steps++ < 24) {
        await tester.drag(detailScroll, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
      await saveRenderPng(
        tester,
        find.byKey(boundary),
        '$output/充电详情-计量费用-${brightness.name}-390x844-100.png',
      );
    }

    for (final brightness in [Brightness.light, Brightness.dark]) {
      final boundary = GlobalKey();
      await scene(tester, boundary, brightness);
    }
  }, skip: output.isEmpty || fontPath.isEmpty);
}
