// AP11 正式渲染入口（交付手册 §5）。opt-in：未设置 MILEAF_AP11_RENDER_OUTPUT
// 与 MILEAF_RENDER_FONT 时跳过。
// 机位：P06 统计首页（390 浅深 100%、360/430 浅 100%、390 浅 200%、360 浅
// 130/150%、360 浅 100% safeArea=0，首屏 + 一屏下滚）、数据状态（empty /
// missing / legacy 回退 / long）、长期索引、全部指标页、共享日期区间弹层。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/workspace.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'statistics_test.dart' show fixture;
import 'support/a_gallery_fixture.dart' show aGalleryClient;
import 'support/c_fixture.dart' show cNow, cSite;
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'support/test_trust_store.dart' show MemoryTrustStore;

const output = String.fromEnvironment('MILEAF_AP11_RENDER_OUTPUT');
const font = String.fromEnvironment('MILEAF_RENDER_FONT');

class _AppearanceStore implements AppearancePreferenceStore {
  _AppearanceStore(this.value);
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? value) async => this.value = value;
}

Future<void> _pumpStatistics(
  WidgetTester tester, {
  required Brightness brightness,
  required Size size,
  required double scale,
  required bool safeArea,
  required String scenario,
  required GlobalKey boundary,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = FakeViewPadding(
    top: safeArea ? 24 : 0,
    bottom: safeArea ? 24 : 0,
  );
  tester.view.padding = tester.view.viewPadding;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  final session = MemorySessionStore()
    ..value = jsonEncode({
      'site': cSite,
      'token': 'test',
      'expires_at': '2099-01-01T00:00:00Z',
    });
  final appearance = AppearanceController(_AppearanceStore(brightness.name));
  await appearance.restore();
  final gallery = aGalleryClient(
    scenario: scenario == 'legacy' ? 'normal' : scenario,
    longFields: scenario == 'long',
  );
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MileafApp(
        client: MockClient((r) async {
          // legacy：meta 不带 statistics_insights，走 0.1/0.2 回退页。
          if (scenario == 'legacy' && r.url.path.endsWith('/meta')) {
            return fixture('meta');
          }
          final forwarded = http.Request(r.method, r.url)
            ..headers.addAll(r.headers)
            ..bodyBytes = r.bodyBytes;
          return http.Response.fromStream(await gallery.send(forwarded));
        }),
        sessionStore: session,
        trustStore: MemoryTrustStore(),
        vehiclePreferences: MemoryVehiclePreferences(),
        appearance: appearance,
        now: () => cNow,
        calendar: () async => CalendarContext('Asia/Shanghai'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('统计').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('AP11 正式渲染：统计首页全部状态、全部指标与日期弹层', (tester) async {
    await loadRenderFonts(cjkFontPath: font);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
      tester.view.resetPadding();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });
    final files = <String>[];
    Future<void> save(
      WidgetTester tester,
      GlobalKey boundary,
      String name,
    ) async {
      final path = '$output/$name.png';
      await saveRenderPng(tester, find.byKey(boundary), path);
      files.add(name);
    }

    Future<void> machine({
      required Brightness brightness,
      required Size size,
      required double scale,
      bool safeArea = true,
      required String scenario,
      required String tag,
      bool scrollOnce = false,
    }) async {
      final boundary = GlobalKey();
      await _pumpStatistics(
        tester,
        brightness: brightness,
        size: size,
        scale: scale,
        safeArea: safeArea,
        scenario: scenario,
        boundary: boundary,
      );
      final mode = brightness.name;
      final spec =
          'statistics-$tag-glass-$mode-${size.width.toInt()}x${size.height.toInt()}-${(scale * 100).round()}';
      await save(tester, boundary, '$spec-top');
      if (scrollOnce) {
        await tester.drag(
          find.byType(Scrollable).last,
          Offset(0, -size.height * .8),
        );
        await tester.pumpAndSettle();
        await save(tester, boundary, '$spec-scrolled');
      }
    }

    // 代表机位（§6.1）：390 浅深 100%、360 浅 100%，首屏与一屏下滚。
    await machine(
      brightness: Brightness.light,
      size: const Size(390, 844),
      scale: 1,
      scenario: 'normal',
      tag: 'normal',
      scrollOnce: true,
    );
    await machine(
      brightness: Brightness.dark,
      size: const Size(390, 844),
      scale: 1,
      scenario: 'normal',
      tag: 'normal',
      scrollOnce: true,
    );
    await machine(
      brightness: Brightness.light,
      size: const Size(360, 800),
      scale: 1,
      scenario: 'normal',
      tag: 'normal',
      scrollOnce: true,
    );
    // 430 宽、200%、130/150% 与 safeArea=0。
    await machine(
      brightness: Brightness.light,
      size: const Size(430, 900),
      scale: 1,
      scenario: 'normal',
      tag: 'normal',
    );
    await machine(
      brightness: Brightness.light,
      size: const Size(390, 844),
      scale: 2,
      scenario: 'normal',
      tag: 'normal',
    );
    await machine(
      brightness: Brightness.light,
      size: const Size(360, 800),
      scale: 1.3,
      scenario: 'normal',
      tag: 'normal',
    );
    await machine(
      brightness: Brightness.light,
      size: const Size(360, 800),
      scale: 1.5,
      scenario: 'normal',
      tag: 'normal',
    );
    await machine(
      brightness: Brightness.light,
      size: const Size(360, 800),
      scale: 1,
      safeArea: false,
      scenario: 'normal',
      tag: 'normal',
    );
    // 数据状态：空、能力缺失、legacy 回退、长期。
    for (final scenario in ['empty', 'missing', 'legacy', 'long']) {
      await machine(
        brightness: Brightness.light,
        size: const Size(360, 800),
        scale: 1,
        scenario: scenario,
        tag: scenario,
      );
    }

    // 长期索引两入口（分组卡行）。
    {
      final boundary = GlobalKey();
      await _pumpStatistics(
        tester,
        brightness: Brightness.light,
        size: const Size(360, 800),
        scale: 1,
        safeArea: true,
        scenario: 'long',
        boundary: boundary,
      );
      await tester.scrollUntilVisible(
        find.text('长期').hitTestable(),
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('长期').hitTestable());
      await tester.pumpAndSettle();
      await save(tester, boundary, 'long-index-glass-light-360x800-100-top');
    }

    // 全部指标页（P15 分组卡列表）。
    {
      final boundary = GlobalKey();
      await _pumpStatistics(
        tester,
        brightness: Brightness.light,
        size: const Size(360, 800),
        scale: 1,
        safeArea: true,
        scenario: 'normal',
        boundary: boundary,
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(TextButton, '全部指标').hitTestable(),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.widgetWithText(TextButton, '全部指标'));
      await tester.pumpAndSettle();
      await save(tester, boundary, 'all-metrics-glass-light-360x800-100-top');
    }

    // 共享日期区间弹层（R27：选择路径 + 预设）。
    {
      final boundary = GlobalKey();
      await _pumpStatistics(
        tester,
        brightness: Brightness.light,
        size: const Size(360, 800),
        scale: 1,
        safeArea: true,
        scenario: 'normal',
        boundary: boundary,
      );
      await tester.tap(find.widgetWithText(StatusChip, '自定义'));
      await tester.pumpAndSettle();
      await save(tester, boundary, 'date-sheet-glass-light-360x800-100-sheet');
    }

    await tester.runAsync(() async {
      await File('$output/AP11-manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'input': 'FP3 8ea7e29 + AP11 票内提交',
          'fixture': 'aGalleryClient 场景 normal/empty/missing/legacy/long',
          'timezone': 'Asia/Shanghai',
          'now': cNow.toIso8601String(),
          'font': font,
          'pixel_ratio': 2,
          'safe_area': '上下各 24（safeArea=0 机位除外）',
          'material': 'glass',
          'files': files,
        }),
      );
    });
  }, skip: output.isEmpty);
}
