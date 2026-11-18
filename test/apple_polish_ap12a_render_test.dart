// AP12a 正式渲染入口（交付手册 §5/§6.1）。opt-in：未设置 MILEAF_RENDER_OUTPUT /
// MILEAF_RENDER_FONT 时跳过。三个专题（P07 节奏 / P08 能耗 / P09 补能）在
// 代表机位（360×800 浅深 ×100/200%、390 浅 100%、320×568 浅 200%）加
// 430 宽、130/150%、safeArea=0 与本页数据状态（normal/empty/missing/
// zero|single/error/unsupported/legacy），每场景 top / 全程滚动 / bottom。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/statistics_charging_page.dart';
import 'package:mileaf/src/statistics_conditions_page.dart';
import 'package:mileaf/src/statistics_usage_page.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'ui_ux_u09a_test.dart' show dailyClient;
import 'ui_ux_u09b_test.dart' show conditionsClient;
import 'ui_ux_u09c_test.dart' show chargingClient;
import 'support/test_trust_store.dart' show MemoryTrustStore;

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const font = String.fromEnvironment('MILEAF_RENDER_FONT');

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
  required http.Client client,
  required Brightness brightness,
  required Size size,
  required double scale,
  required bool safeArea,
  required DateTime Function() now,
  required String Function() zone,
  required GlobalKey boundary,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  if (safeArea) {
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  } else {
    tester.view.padding = FakeViewPadding.zero;
    tester.view.viewPadding = FakeViewPadding.zero;
  }
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
        client: client,
        sessionStore: session,
        trustStore: MemoryTrustStore(),
        vehiclePreferences: MemoryVehiclePreferences(),
        appearance: appearance,
        now: now,
        calendar: () async => CalendarContext(zone()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (font.isNotEmpty) await loadRenderFonts(cjkFontPath: font);
  });

  testWidgets('AP12a 正式Flutter三专题矩阵与完整滚动', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final files = <String>[];
    final measurements = <Map<String, Object?>>[];
    final manifestInfo = <String, Object?>{};

    Future<void> capture(GlobalKey boundary, String path) async {
      void repaint(RenderObject object) {
        object.markNeedsPaint();
        object.visitChildren(repaint);
      }

      repaint(tester.renderObject(find.byKey(boundary)));
      await tester.pump();
      await saveRenderPng(tester, find.byKey(boundary), path);
      files.add(path);
    }

    /// 专题页自身的纵向滚动视图（避开隐藏 Tab 的 Scrollable）。
    Finder pageScroll(String topic) {
      final pageType = switch (topic) {
        '节奏' => StatisticsUsagePage,
        '能耗' => StatisticsConditionsPage,
        _ => StatisticsChargingPage,
      };
      return find
          .descendant(
            of: find.byType(pageType),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          )
          .last;
    }

    /// 全程滚动并在 100% 普通场景保存逐屏与 bottom 机位。
    Future<void> scrollAndSave(
      WidgetTester tester,
      GlobalKey boundary,
      String path,
      bool full,
      String topic,
    ) async {
      final scroll = pageScroll(topic);
      var step = 0;
      while (tester.state<ScrollableState>(scroll).position.extentAfter > 0 &&
          step < 40) {
        await tester.drag(scroll, const Offset(0, -520));
        await tester.pumpAndSettle();
        step++;
        if (full) {
          await capture(boundary, path.replaceAll('.png', '-scroll$step.png'));
        }
      }
      if (full) {
        await capture(boundary, path.replaceAll('.png', '-bottom.png'));
      }
    }

    final cases = <(String, Size, double, String, Brightness, bool)>[
      // 三专题代表机位：360 浅深 ×100/200%。
      for (final topic in ['节奏', '能耗', '补能'])
        for (final dark in [false, true])
          for (final scale in [1.0, 2.0])
            (
              topic,
              const Size(360, 800),
              scale,
              'normal',
              dark ? Brightness.dark : Brightness.light,
              true,
            ),
      // 补充机位：430 宽、130/150%、320×568 200%、safeArea=0。
      ('节奏', const Size(430, 900), 1.0, 'normal', Brightness.light, true),
      ('节奏', const Size(360, 800), 1.3, 'normal', Brightness.light, true),
      ('节奏', const Size(360, 800), 1.5, 'normal', Brightness.light, true),
      ('节奏', const Size(320, 568), 2.0, 'normal', Brightness.light, true),
      ('节奏', const Size(360, 800), 1.0, 'normal', Brightness.light, false),
      ('能耗', const Size(430, 900), 1.0, 'normal', Brightness.light, true),
      ('能耗', const Size(360, 800), 1.3, 'normal', Brightness.light, true),
      ('能耗', const Size(320, 568), 2.0, 'normal', Brightness.light, true),
      ('能耗', const Size(360, 800), 1.0, 'normal', Brightness.light, false),
      ('补能', const Size(430, 900), 1.0, 'normal', Brightness.light, true),
      ('补能', const Size(360, 800), 1.3, 'normal', Brightness.light, true),
      ('补能', const Size(320, 568), 2.0, 'normal', Brightness.light, true),
      ('补能', const Size(360, 800), 1.0, 'normal', Brightness.light, false),
      // 数据状态：空 / 缺失 / 局部失败 / 能力不足 / 旧契约。
      ('节奏', const Size(360, 800), 1.0, 'empty', Brightness.light, true),
      ('节奏', const Size(360, 800), 1.0, 'missing', Brightness.light, true),
      ('节奏', const Size(360, 800), 2.0, 'missing', Brightness.light, true),
      ('节奏', const Size(360, 800), 1.0, 'zero', Brightness.light, true),
      ('节奏', const Size(360, 800), 1.0, 'stale', Brightness.light, true),
      ('节奏', const Size(360, 800), 1.0, 'unsupported', Brightness.light, true),
      ('能耗', const Size(360, 800), 1.0, 'empty', Brightness.light, true),
      ('能耗', const Size(360, 800), 1.0, 'missing', Brightness.light, true),
      ('能耗', const Size(360, 800), 2.0, 'missing', Brightness.light, true),
      ('能耗', const Size(360, 800), 1.0, 'single', Brightness.light, true),
      ('能耗', const Size(360, 800), 1.0, 'error', Brightness.light, true),
      ('能耗', const Size(360, 800), 1.0, 'unsupported', Brightness.light, true),
      ('补能', const Size(360, 800), 1.0, 'empty', Brightness.light, true),
      ('补能', const Size(360, 800), 1.0, 'missing', Brightness.light, true),
      ('补能', const Size(360, 800), 2.0, 'missing', Brightness.light, true),
      ('补能', const Size(360, 800), 1.0, 'error', Brightness.light, true),
      ('补能', const Size(360, 800), 1.0, 'legacy', Brightness.light, true),
    ];
    manifestInfo['cases'] = cases.length;

    for (final (topic, size, scale, scenario, brightness, safeArea) in cases) {
      final dark = brightness == Brightness.dark;
      final name =
          'AP12a-$topic-$scenario-${dark ? 'dark' : 'light'}-${size.width.toInt()}x${size.height.toInt()}-${(scale * 100).round()}${safeArea ? '' : '-noSafeArea'}';
      final boundary = GlobalKey();
      final client = switch (topic) {
        '节奏' => dailyClient([], scenario: scenario),
        '能耗' => conditionsClient([], scenario: scenario),
        _ => chargingClient([], scenario: scenario),
      };
      await _pump(
        tester,
        client: client,
        brightness: brightness,
        size: size,
        scale: scale,
        safeArea: safeArea,
        now: topic == '补能'
            ? () => DateTime.utc(2026, 3, 30, 12)
            : () => DateTime.utc(2026, 10, 28, 11),
        zone: topic == '补能' ? () => 'UTC' : () => 'Asia/Shanghai',
        boundary: boundary,
      );
      // 进统计 Tab，再打开对应专题（宿主导航 + 专题卡）。
      await tester.tap(find.text('统计').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(topic).hitTestable(),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text(topic).first);
      await tester.pumpAndSettle();
      final full =
          scenario == 'normal' && scale == 1.0 && size.width == 360 && safeArea;
      await capture(boundary, '$output/gallery/$name-top.png');
      // 首屏预算（§6 五专题）：主图绘图区首 120 可见（100% 普通场景测一次）。
      if (full) {
        final plotKey = switch (topic) {
          '节奏' => const ValueKey('usage-daily-plot'),
          '能耗' => const ValueKey('conditions-plot'),
          _ => const ValueKey('charging-topic-plot'),
        };
        // 主图在视口下也无妨：直接取几何（§6 量的是首屏可见高度）。
        final plotFinder = find.byKey(plotKey);
        final plot = tester.getRect(plotFinder);
        final navBottom = tester
            .getRect(find.byType(MileafNavigationRow).last)
            .bottom;
        final visible =
            plot.bottom - (plot.top < navBottom ? navBottom : plot.top);
        measurements.add({
          'name': name,
          'plotTop': plot.top,
          'navBottom': navBottom,
          'plotVisible': visible,
        });
        expect(visible, greaterThanOrEqualTo(120));
      }
      await scrollAndSave(
        tester,
        boundary,
        '$output/gallery/$name-top.png',
        full,
        topic,
      );
      if (full) {
        // 返回首页，收起键盘与滚动，保证下一场景干净。
        await tester.pumpAndSettle();
      }
    }

    await tester.runAsync(() async {
      await File('$output/gallery/ap12a-manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'ticket': 'AP12a',
          'input': 'FP3 (8ea7e29) + 本票分段提交',
          'fixture': 'dailyClient / conditionsClient / chargingClient',
          'timezone': 'Asia/Shanghai（补能 UTC）',
          'font': font,
          'dpr': 1,
          'keyboard': 'hidden',
          'images': files,
          'measurements': measurements,
          'info': manifestInfo,
        }),
      );
    });
  }, skip: output.isEmpty || font.isEmpty);
}
