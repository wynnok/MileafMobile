// 充电记录行与充电地点行重排的 opt-in 渲染入口。未设置
// MILEAF_RENDER_OUTPUT / MILEAF_RENDER_FONT 时跳过；机位覆盖「最近充电」
// 记录卡与「充电地点」分组卡，浅深 390×844 100%、浅色 360×800 与 200%。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/charging_page.dart';
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

  testWidgets('充电行重排图册：最近充电记录卡与充电地点卡', (tester) async {
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

    Future<void> scrollTo(
      WidgetTester tester,
      Type page,
      Finder target,
      double align,
    ) async {
      var steps = 0;
      while (target.evaluate().isEmpty && steps++ < 24) {
        await tester.drag(pageScroll(page), const Offset(0, -250));
        await tester.pumpAndSettle();
      }
      await Scrollable.ensureVisible(tester.element(target), alignment: align);
      await tester.pumpAndSettle();
    }

    Future<void> scene(
      WidgetTester tester,
      GlobalKey boundary,
      String dir, {
      required Brightness brightness,
      required Size size,
      required double scale,
      required String camera,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
      tester.view.padding = tester.view.viewPadding;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
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
      await scrollTo(tester, ChargingPage, find.text('查看全部'), 0.22);
      await saveRenderPng(
        tester,
        find.byKey(boundary),
        '$dir/充电-最近充电-${brightness.name}-$camera.png',
      );
      await scrollTo(tester, ChargingPage, find.text('充电地点'), 0.35);
      await saveRenderPng(
        tester,
        find.byKey(boundary),
        '$dir/充电-充电地点-${brightness.name}-$camera.png',
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewPadding();
        tester.view.resetPadding();
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
    }

    final cameras = [
      (
        brightness: Brightness.light,
        size: const Size(390, 844),
        scale: 1.0,
        camera: '390x844-100',
      ),
      (
        brightness: Brightness.dark,
        size: const Size(390, 844),
        scale: 1.0,
        camera: '390x844-100',
      ),
      (
        brightness: Brightness.light,
        size: const Size(390, 844),
        scale: 2.0,
        camera: '390x844-200',
      ),
      (
        brightness: Brightness.dark,
        size: const Size(390, 844),
        scale: 2.0,
        camera: '390x844-200',
      ),
      (
        brightness: Brightness.light,
        size: const Size(360, 800),
        scale: 1.0,
        camera: '360x800-100',
      ),
    ];
    for (final config in cameras) {
      final boundary = GlobalKey();
      await scene(
        tester,
        boundary,
        output,
        brightness: config.brightness,
        size: config.size,
        scale: config.scale,
        camera: config.camera,
      );
    }
  }, skip: output.isEmpty || fontPath.isEmpty);
}
