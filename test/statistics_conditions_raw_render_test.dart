// 能耗专题（P08）高精度读数的渲染入口。opt-in：未设置 MILEAF_RENDER_OUTPUT /
// MILEAF_RENDER_FONT 时跳过。
//
// 与 AP12a 的正式图册不同，这里的夹具带高精度合成浮点（15 位有效数字）：
// 它专门用来复现与复核「原始浮点上屏」引发的一整串版式问题（读数溢出、行内文字
// 被压成一字一行、点图读数叠压、下钻行缩进不一致）。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/statistics_conditions_page.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/raw_conditions_fixture.dart';
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/test_trust_store.dart' show MemoryTrustStore;
import 'support/vehicle_preferences.dart';

const String output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const String font = String.fromEnvironment('MILEAF_RENDER_FONT');

class _Appearance implements AppearancePreferenceStore {
  _Appearance(this.value);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? value) async => this.value = value;
}

Future<void> _pump(
  WidgetTester tester, {
  required Brightness brightness,
  required Size size,
  required double scale,
  required GlobalKey boundary,
  required Map<String, dynamic> fixture,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  final session = MemorySessionStore()
    ..value = jsonEncode({
      'site': 'https://example.com/prefix',
      'token': 'test',
      'expires_at': '2099-01-01T00:00:00Z',
    });
  final appearance = AppearanceController(_Appearance(brightness.name));
  await appearance.restore();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MileafApp(
        client: conditionsBodyClient(fixture),
        sessionStore: session,
        trustStore: MemoryTrustStore(),
        vehiclePreferences: MemoryVehiclePreferences(),
        appearance: appearance,
        now: () => DateTime.utc(2026, 10, 28, 11),
        calendar: () async => CalendarContext('Asia/Shanghai'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (font.isNotEmpty) await loadRenderFonts(cjkFontPath: font);
  });

  testWidgets('P08 高精度读数整页渲染', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final files = <String>[];
    for (final (size, scale, dark, fixture, tag) in [
      (const Size(430, 932), 1.0, false, rawConditions(), ''),
      (const Size(390, 844), 1.0, false, rawConditions(), ''),
      (const Size(360, 800), 1.0, false, rawConditions(), ''),
      (const Size(390, 844), 1.0, true, rawConditions(), ''),
      (const Size(390, 844), 2.0, false, rawConditions(), ''),
      // 密集样本：13 个温度组，验证分段下拉和点图读数避让。
      (const Size(390, 844), 1.0, false, denseConditions(), '-dense13'),
      (const Size(390, 844), 2.0, false, denseConditions(), '-dense13'),
    ]) {
      final boundary = GlobalKey();
      await _pump(
        tester,
        brightness: dark ? Brightness.dark : Brightness.light,
        size: size,
        scale: scale,
        boundary: boundary,
        fixture: fixture,
      );
      await tester.tap(find.text('统计').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('能耗').hitTestable(),
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('能耗').first);
      await tester.pumpAndSettle();
      final name =
          '${size.width.toInt()}x${size.height.toInt()}-'
          '${(scale * 100).round()}$tag${dark ? '-dark' : ''}';
      Future<void> capture(String suffix) async {
        final path = '$output/$name-$suffix.png';
        await saveRenderPng(tester, find.byKey(boundary), path);
        files.add(path);
      }

      await capture('top');
      final scroll = find
          .descendant(
            of: find.byType(StatisticsConditionsPage),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          )
          .last;
      var step = 0;
      while (tester.state<ScrollableState>(scroll).position.extentAfter > 0 &&
          step < 12) {
        await tester.drag(scroll, const Offset(0, -420));
        await tester.pumpAndSettle();
        step++;
        await capture('scroll$step');
      }
    }
    await tester.runAsync(() async {
      await File('$output/manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'ticket': 'P08 高精度读数版式',
          'fixture': 'rawConditions（高精度合成浮点）',
          'font': font,
          'images': files,
        }),
      );
    });
  }, skip: output.isEmpty || font.isEmpty);
}
