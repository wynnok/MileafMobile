import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/workspace.dart';
import 'package:mileaf/src/overview_page.dart' show OverviewPage;
import 'package:mileaf/src/drives_page.dart' show DrivesPage;

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
  Future<String?> write(String? value) async => this.value = value;
}

class _CurrencyStore implements CurrencyPreferenceStore {
  @override
  Future<String?> read(String site) async => 'CNY';

  @override
  Future<void> write(String site, String? code) async {}
}

/// DM05 页面包（概览 + 行程）样张：MG01 彩色面积登记的目验机位。
/// opt-in 入口（与 AP07 同一 skip 机制）：
/// ./tool/flutterw test --no-pub test/days_migration_dm05_render_test.dart \
///   --dart-define=MILEAF_RENDER_OUTPUT=build/dm05-renders \
///   '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
void main() {
  setUpAll(() async {
    if (fontPath.isNotEmpty) await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('概览与行程浅深样张', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
      tester.view.resetPadding();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });
    for (final brightness in Brightness.values) {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
      tester.view.padding = tester.view.viewPadding;
      tester.platformDispatcher.textScaleFactorTestValue = 1.0;
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
      final boundary = GlobalKey();
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
      final mode = brightness.name;
      // 概览整页两段：hero + 焦点卡；账目与页尾区。
      await saveRenderPng(
        tester,
        find.byKey(boundary),
        '$output/dm05-overview-top-$mode-390x844-100.png',
      );
      Finder pageScrollOf(Type page) => find
          .descendant(
            of: find.byType(page),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          )
          .first;
      Future<void> scrollTo(Type page, Finder target) async {
        var steps = 0;
        while (target.evaluate().isEmpty && steps++ < 24) {
          await tester.drag(pageScrollOf(page), const Offset(0, -250));
          await tester.pumpAndSettle();
        }
        await Scrollable.ensureVisible(
          tester.element(target),
          alignment: .2,
        );
        await tester.pumpAndSettle();
      }

      await scrollTo(OverviewPage, find.text('本期账目'));
      await saveRenderPng(
        tester,
        find.byKey(boundary),
        '$output/dm05-overview-lower-$mode-390x844-100.png',
      );
      // 行程整页两段：焦点卡 + 记录分组；页尾。
      await tester.tap(
        find.descendant(
          of: find.byType(MileafNavBar),
          matching: find.text('行程'),
        ),
      );
      await tester.pumpAndSettle();
      await saveRenderPng(
        tester,
        find.byKey(boundary),
        '$output/dm05-drives-top-$mode-390x844-100.png',
      );
      await scrollTo(DrivesPage, find.text('今天'));
      await saveRenderPng(
        tester,
        find.byKey(boundary),
        '$output/dm05-drives-records-$mode-390x844-100.png',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  }, skip: output.isEmpty || fontPath.isEmpty);
}
