// AP07 代表页 after 渲染入口（评审包）。opt-in：未设置 MILEAF_RENDER_OUTPUT /
// MILEAF_RENDER_FONT 时跳过。机位按交付手册 §6.1 的代表页要求取 390×844 浅深
// 100%、360×800 浅 100%、390×844 浅 200%，页面为 P01 概览、P02 行程、
// P06 统计首页、P12 设置与 P16 车辆弹层。
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
import 'widget_test.dart' show MemoryTrustStore;

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

Future<void> _pump(
  WidgetTester tester, {
  required Brightness brightness,
  required GlobalKey boundary,
  required Size size,
  required double scale,
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

  testWidgets('AP07 review gallery: representative pages', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
      tester.view.resetPadding();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final images = <String, Map<String, Object?>>{};
    Future<void> capture(
      GlobalKey boundary,
      String page,
      String scene,
      String mode,
      String camera,
    ) async {
      final name = 'AP07-$page-$scene-glass-$mode-$camera-top.png';
      await saveRenderPng(tester, find.byKey(boundary), '$output/$name');
      images[name] = {
        'page': page,
        'scene': scene,
        'mode': mode,
        'camera': camera,
        'size': tester.getSize(find.byKey(boundary)).toString(),
      };
    }

    for (final brightness in Brightness.values) {
      final mode = brightness.name;
      final boundary = GlobalKey();
      await _pump(
        tester,
        brightness: brightness,
        boundary: boundary,
        size: const Size(390, 844),
        scale: 1,
      );
      for (final label in const ['概览', '行程', '统计']) {
        await tester.tap(_nav(label));
        await tester.pumpAndSettle();
        await capture(boundary, label, 'normal', mode, '390x844-100');
      }
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await capture(boundary, '设置', 'normal', mode, '390x844-100');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('行笺测试车').first);
      await tester.pumpAndSettle();
      await capture(boundary, '车辆', 'sheet', mode, '390x844-100');
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
    }

    final small = GlobalKey();
    await _pump(
      tester,
      brightness: Brightness.light,
      boundary: small,
      size: const Size(360, 800),
      scale: 1,
    );
    for (final label in const ['概览', '行程', '统计']) {
      await tester.tap(_nav(label));
      await tester.pumpAndSettle();
      await capture(small, label, 'normal', 'light', '360x800-100');
    }

    final large = GlobalKey();
    await _pump(
      tester,
      brightness: Brightness.light,
      boundary: large,
      size: const Size(390, 844),
      scale: 2,
    );
    for (final label in const ['概览', '行程', '统计']) {
      await tester.tap(_nav(label));
      await tester.pumpAndSettle();
      await capture(large, label, 'normal', 'light', '390x844-200');
    }

    File('$output/manifest.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'ticket': 'AP07',
        'input_sha': 'a2707f7',
        'fixture': 'cGalleryClient / CostSite',
        'timezone': 'Asia/Shanghai',
        'sampled_at': cNow.toIso8601String(),
        'font': fontPath,
        'dpr': 1,
        'keyboard': 'hidden',
        'material_preferences': 'default',
        'images': images,
      }),
    );
  }, skip: output.isEmpty || fontPath.isEmpty);
}
