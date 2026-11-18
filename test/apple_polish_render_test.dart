// AP00 before 图册渲染入口。opt-in：未设置 MILEAF_RENDER_OUTPUT / MILEAF_RENDER_FONT 时跳过。
// 用现有夹具（cGalleryClient / CostSite）采集 ADR0014 之前的当前态：四个根页浅深 100%、
// 390/360/320 首屏与一屏下滚，含空/失败/进行中各一。正式渲染见交付手册 §5。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
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

Finder _nav(String label) =>
    find.descendant(of: find.byType(MileafNavBar), matching: find.text(label));

Future<void> _pumpBefore(
  WidgetTester tester, {
  required Brightness brightness,
  required GlobalKey boundary,
}) async {
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
  final appearance = AppearanceController(_AppearanceStore(brightness.name));
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
}

void main() {
  setUpAll(() async {
    if (fontPath.isNotEmpty) await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('AP00 before gallery: four root pages', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
      tester.view.resetPadding();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });
    final geometry = <String, Object?>{
      'logical_size': '390x844',
      'pixel_ratio': 2,
      'text_scale': 1,
      'safe_area': {'top': 24, 'bottom': 24},
      'timezone': 'Asia/Shanghai',
      'fixture': 'cGalleryClient / CostSite',
      'font': fontPath,
      'input_sha': '6492c83',
    };
    final pages = <String>['概览', '行程', '充电', '统计'];
    for (final brightness in Brightness.values) {
      final mode = brightness.name;
      final boundary = GlobalKey();
      await _pumpBefore(tester, brightness: brightness, boundary: boundary);
      for (final label in pages) {
        await tester.tap(_nav(label));
        await tester.pumpAndSettle();
        await saveRenderPng(
          tester,
          find.byKey(boundary),
          '$output/before-$label-$mode-390-100-top.png',
        );
      }
      geometry['before-$mode'] = {
        'top_bar': tester.getRect(find.byType(MileafTopBar)),
        'bottom_bar': tester.getRect(find.byType(MileafNavBar)),
      };
    }
    File(
      '$output/geometry.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(geometry));
  }, skip: output.isEmpty || fontPath.isEmpty);
}
