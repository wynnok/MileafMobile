// AP07 代表页 after 渲染入口（评审包）。opt-in：未设置 MILEAF_RENDER_OUTPUT /
// MILEAF_RENDER_FONT 时跳过。机位按交付手册 §6.1 的代表页要求取 390×844 浅深
// 100%、360×800 浅 100%、390×844 浅 200%，页面为 P01 概览、P02 行程、
// P06 统计首页、P05 充电详情、P12 设置与 P16 车辆弹层。//
// 用户 2026-11-17 视觉裁定后另加四页红框区域定向图（-scrolled）：概览下半、
// 行程记录、充电顶部与「最近充电」入口、统计结论卡与专题网格，以及统计的
// 「不可比（无参照序列）」状态。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/charging_page.dart';
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/drives_page.dart';
import 'package:mileaf/src/overview_page.dart';
import 'package:mileaf/src/statistics_insights_page.dart';
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

/// 「不可比（无参照序列）」：让参照区间那一次读取失败，本期结果保留，
/// 图表只有本期序列、比较句不造句。其他请求仍走 C 快照夹具。
MockClient _noReferenceClient() {
  final inner = cGalleryClient();
  var drivingReads = 0;
  return MockClient((request) async {
    final isDrivingStats =
        request.url.path.endsWith('/stats') &&
        request.url.queryParameters['kind'] != 'charging';
    if (isDrivingStats && ++drivingReads > 1) {
      return http.Response(
        jsonEncode({
          'error': {'code': 'not_found'},
        }),
        404,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    final forwarded = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return http.Response.fromStream(await inner.send(forwarded));
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Brightness brightness,
  required GlobalKey boundary,
  required Size size,
  required double scale,
  http.Client? client,
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
        client: client ?? cGalleryClient(),
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

    // P05 充电详情（用户裁定 P05 在本票补齐）：390 浅深 100%、360 浅 100%、
    // 390 浅 200% 三组机位，与本票其他代表页同规格。
    Future<void> openChargingDetail(WidgetTester tester) async {
      await tester.tap(_nav('充电'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('charge-9')).hitTestable(),
        300,
      );
      await tester.tap(find.byKey(const ValueKey('charge-9')).hitTestable());
      await tester.pumpAndSettle();
    }

    for (final brightness in Brightness.values) {
      final boundary = GlobalKey();
      await _pump(
        tester,
        brightness: brightness,
        boundary: boundary,
        size: const Size(390, 844),
        scale: 1,
      );
      await openChargingDetail(tester);
      await capture(boundary, '充电详情', 'normal', brightness.name, '390x844-100');
    }
    final detailSmall = GlobalKey();
    await _pump(
      tester,
      brightness: Brightness.light,
      boundary: detailSmall,
      size: const Size(360, 800),
      scale: 1,
    );
    await openChargingDetail(tester);
    await capture(detailSmall, '充电详情', 'normal', 'light', '360x800-100');
    final detailLarge = GlobalKey();
    await _pump(
      tester,
      brightness: Brightness.light,
      boundary: detailLarge,
      size: const Size(390, 844),
      scale: 2,
    );
    await openChargingDetail(tester);
    await capture(detailLarge, '充电详情', 'normal', 'light', '390x844-200');

    // —— 定向机位：四页红框区域（用户 2026-11-17 视觉裁定）——
    Future<void> captureScrolled(
      GlobalKey boundary,
      String page,
      String scene,
      String mode,
      String camera,
    ) async {
      final name = 'AP07-$page-$scene-glass-$mode-$camera-scrolled.png';
      await saveRenderPng(tester, find.byKey(boundary), '$output/$name');
      images[name] = {
        'page': page,
        'scene': scene,
        'mode': mode,
        'camera': camera,
        'size': tester.getSize(find.byKey(boundary)).toString(),
        'directed': true,
      };
    }

    /// 列表是惰性的：先滚到目标被构建出来，再把它对到指定的视口位置。
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

    Future<void> tab(WidgetTester tester, String label) async {
      await tester.tap(_nav(label));
      await tester.pumpAndSettle();
    }

    /// 四页各一处定向机位：概览下半、行程记录（昨天分组）、充电顶部、
    /// 充电「最近充电」入口、统计结论卡与专题网格。
    Future<void> directedScenes(
      GlobalKey boundary, {
      required Brightness brightness,
      required Size size,
      required double scale,
      required String mode,
      required String camera,
    }) async {
      await _pump(
        tester,
        brightness: brightness,
        boundary: boundary,
        size: size,
        scale: scale,
      );
      await scrollTo(tester, OverviewPage, find.text('电耗对比'), 0.45);
      await captureScrolled(boundary, '概览', '下半', mode, camera);

      await tab(tester, '行程');
      // 今天的分组有两条记录：既看分组标题与卡片内容同一网格，也看行间唯一的
      // 分隔线与末行之下没有线（单行分组的 昨天 由几何断言覆盖）。
      await scrollTo(tester, DrivesPage, find.text('今天'), 0.10);
      await captureScrolled(boundary, '行程', '记录', mode, camera);

      await tab(tester, '充电');
      await captureScrolled(boundary, '充电', '顶部', mode, camera);
      await scrollTo(tester, ChargingPage, find.text('查看全部'), 0.30);
      await captureScrolled(boundary, '充电', '最近充电', mode, camera);

      await tab(tester, '统计');
      await scrollTo(
        tester,
        StatisticsInsightsPage,
        find.byKey(const ValueKey('statistics-topic-节奏')),
        0.45,
      );
      await captureScrolled(boundary, '统计', '结论与专题', mode, camera);
    }

    for (final config in const [
      (
        brightness: Brightness.light,
        size: Size(390, 844),
        scale: 1.0,
        camera: '390x844-100',
      ),
      (
        brightness: Brightness.dark,
        size: Size(390, 844),
        scale: 1.0,
        camera: '390x844-100',
      ),
      (
        brightness: Brightness.light,
        size: Size(390, 844),
        scale: 2.0,
        camera: '390x844-200',
      ),
      (
        brightness: Brightness.light,
        size: Size(360, 800),
        scale: 1.0,
        camera: '360x800-100',
      ),
    ]) {
      final boundary = GlobalKey();
      await directedScenes(
        boundary,
        brightness: config.brightness,
        size: config.size,
        scale: config.scale,
        mode: config.brightness.name,
        camera: config.camera,
      );
    }

    // 用户截图里的「不可比（无参照序列）」状态。
    final noReference = GlobalKey();
    await _pump(
      tester,
      brightness: Brightness.light,
      boundary: noReference,
      size: const Size(390, 844),
      scale: 1,
      client: _noReferenceClient(),
    );
    await tab(tester, '统计');
    await scrollTo(
      tester,
      StatisticsInsightsPage,
      find.byKey(const ValueKey('statistics-topic-节奏')),
      0.45,
    );
    await captureScrolled(noReference, '统计', '无参照', 'light', '390x844-100');

    File('$output/manifest.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'ticket': 'AP07',
        'input_sha': '1f3c721',
        'freeze_point': 'FP2 (a2707f7)',
        'round': 'user-visual-review-2026-11-17',
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
