import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/charging_page.dart';

import 'package:mileaf/src/workspace.dart';

import 'charging_expansion_test.dart' show expansionResponse;
import 'charging_test.dart' show MemoryCurrency, jsonResponse, navTab;
import 'support/a_gallery_fixture.dart';
import 'support/c_fixture.dart';
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');
const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');

/// AP10 正式图册（P03 充电账本 / P05 充电详情）：
/// - P03 全部数据状态（完整/空/失败含重试/进行中/未知币种/旧契约/长文本）
///   × 浅深 × 100/200%，补 390、320、430、130/150%、safeArea=0、768 宽；
/// - 全部记录模式（二级导航 + 胶囊下拉 + 匹配数脚注）与页尾说明层；
/// - P05 详情（正常 / 空采样 / 系列失败含重试）浅深首屏与页尾机位。
/// 首屏预算沿交付手册 §6 基准（360×800、safeArea 上下各 24、100%）实测并
/// 写入 measurements.json；无进行中时第一条记录完整，有进行中时标题与首行
/// 至少 44 可见。

class _Appearance implements AppearancePreferenceStore {
  _Appearance(this.value);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? next) async => value = next;
}

Finder pageScrollOf(WidgetTester tester) => find
    .descendant(
      of: find.byType(ChargingPage),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  final scroll = pageScrollOf(tester);
  var steps = 0;
  while (finder.hitTestable().evaluate().isEmpty && steps++ < 24) {
    await tester.drag(scroll, const Offset(0, -220));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(() async {
    if (output.isEmpty) return;
    await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('AP10 P03 充电账本全状态矩阵与首屏实测', (tester) async {
    final scenes = [
      for (final scenario in [
        'normal',
        'empty',
        'missing',
        'active',
        'unknown',
        'legacy',
      ])
        for (final mode in Brightness.values) ...[
          (scenario, mode, const Size(360, 800), 1.0, false),
          (scenario, mode, const Size(360, 800), 2.0, false),
        ],
      ('normal', Brightness.light, const Size(390, 844), 1.0, false),
      ('normal', Brightness.dark, const Size(390, 844), 1.0, false),
      ('normal', Brightness.light, const Size(320, 568), 2.0, false),
      ('normal', Brightness.light, const Size(430, 932), 1.0, false),
      ('normal', Brightness.light, const Size(360, 800), 1.3, false),
      ('normal', Brightness.light, const Size(360, 800), 1.5, false),
      ('normal', Brightness.light, const Size(360, 800), 1.0, true),
      ('normal', Brightness.dark, const Size(360, 800), 1.0, true),
      ('long', Brightness.dark, const Size(768, 1024), 2.0, false),
    ];
    final measurements = <Map<String, Object>>[];
    final images = <String, Map<String, String>>{};
    for (final (scenario, mode, size, scale, safeZero) in scenes) {
      tester.view.physicalSize = size;
      tester.view.viewPadding = safeZero
          ? FakeViewPadding.zero
          : const FakeViewPadding(top: 24, bottom: 24);
      tester.view.padding = tester.view.viewPadding;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      tester.platformDispatcher.platformBrightnessTestValue = mode;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetViewPadding();
        tester.view.resetPadding();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
      });
      final gallery = aGalleryClient(
        scenario: scenario == 'long' ? 'normal' : scenario,
        irregular: true,
        longFields: scenario == 'long',
      );
      final client = MockClient((request) async {
        if (scenario == 'legacy' && request.url.path.endsWith('/meta')) {
          return jsonResponse({'version': '0.1.0'});
        }
        if (scenario == 'active') {
          if (request.url.path.endsWith('/summary')) {
            final body = cSummary();
            (body['state'] as Map)['value'] = 'charging';
            return jsonResponse(body);
          }
          if (request.url.path.endsWith('/charging-sessions') &&
              request.url.queryParameters['time_basis'] == 'started_at') {
            return expansionResponse(request);
          }
        }
        final forwarded = http.Request(request.method, request.url)
          ..headers.addAll(request.headers)
          ..bodyBytes = request.bodyBytes;
        final response = await http.Response.fromStream(
          await gallery.send(forwarded),
        );
        if (scenario == 'long' &&
            (request.url.path.endsWith('/charging-sessions') ||
                request.url.path.endsWith('/charging-locations'))) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          for (final item in body['items'] as List) {
            (item['location'] as Map)['display_name'] =
                '上海临港新片区湖畔地下停车场新能源专用充电站东侧入口';
          }
          return jsonResponse(body);
        }
        return response;
      });
      final store = MemorySessionStore()
        ..value = jsonEncode({
          'site': cSite,
          'token': 'test',
          'expires_at': '2099-01-01T00:00:00Z',
        });
      final appearance = AppearanceController(_Appearance(mode.name));
      await appearance.restore();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MileafApp(
            key: UniqueKey(),
            client: client,
            sessionStore: store,
            appearance: appearance,
            trustStore: MemoryTrustStore(),
            vehiclePreferences: MemoryVehiclePreferences(),
            currencyPreferences: scenario == 'unknown'
                ? MemoryCurrency()
                : (MemoryCurrency()..values[cSite] = 'CNY'),
            now: () => cNow,
            calendar: () async => CalendarContext('Asia/Shanghai'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(navTab('充电'));
      await tester.pumpAndSettle();

      final camera =
          '${size.width.round()}x${size.height.round()}-${(scale * 100).round()}';
      final prefix =
          'AP10-充电-${scenario == 'long' ? 'long' : scenario}-glass-${mode.name}-$camera${safeZero ? '-safe0' : ''}';

      // §6 首屏预算实测（360×800、safeArea 24/24、100%）。
      if ((scenario == 'normal' || scenario == 'active') &&
          size.width == 360 &&
          scale == 1 &&
          !safeZero) {
        final scroll = pageScrollOf(tester);
        final viewport = tester.getRect(scroll);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('charge-9')),
          100,
          scrollable: scroll,
        );
        await tester.pumpAndSettle();
        final offset = tester.state<ScrollableState>(scroll).position.pixels;
        final first = tester.getRect(find.byKey(const ValueKey('charge-9')));
        final requiredBottom = scenario == 'active'
            ? first.top + 44
            : first.bottom;
        measurements.add({
          'scene': '$scenario-${mode.name}',
          'viewportHeight': viewport.height,
          'requiredBottom': requiredBottom + offset,
          'viewportBottom': viewport.bottom,
          'budgetMet': requiredBottom + offset <= viewport.bottom,
        });
        expect(
          requiredBottom + offset,
          lessThanOrEqualTo(viewport.bottom),
          reason: '§6 充电首屏预算（$scenario-${mode.name}）',
        );
        tester.state<ScrollableState>(scroll).position.jumpTo(0);
        await tester.pumpAndSettle();
      }

      await saveRenderPng(
        tester,
        find.byKey(boundary),
        '$output/$prefix-top.png',
      );
      images['$prefix-top.png'] = {
        'page': '充电',
        'scene': scenario,
        'mode': mode.name,
        'camera': camera,
        'safeArea': safeZero ? '0' : '24/24',
      };
      if (scenario == 'missing') {
        final scroll = pageScrollOf(tester);
        await scrollTo(tester, find.byKey(const ValueKey('charge-9')));
        await saveRenderPng(
          tester,
          find.byKey(boundary),
          '$output/$prefix-record.png',
        );
        images['$prefix-record.png'] = {
          'page': '充电',
          'scene': scenario,
          'mode': mode.name,
          'camera': camera,
          'safeArea': safeZero ? '0' : '24/24',
        };
        tester.state<ScrollableState>(scroll).position.jumpTo(0);
        await tester.pumpAndSettle();
      }

      // 全部记录模式：二级导航 + 胶囊下拉 + 匹配数脚注。
      if (scenario != 'legacy') {
        final entry = find.text('查看全部').hitTestable();
        await scrollTo(tester, entry);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        await saveRenderPng(
          tester,
          find.byKey(boundary),
          '$output/$prefix-records.png',
        );
        images['$prefix-records.png'] = {
          'page': '充电',
          'scene': scenario,
          'mode': mode.name,
          'camera': camera,
          'safeArea': safeZero ? '0' : '24/24',
        };
        final back = find.byType(BackButton);
        await tester.scrollUntilVisible(
          back.hitTestable(),
          -300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(back.hitTestable());
        await tester.pumpAndSettle();
      }

      // 页尾：关于这些数据展开「口径与估算」后到底部。
      final caliber = find.text('口径与估算').hitTestable();
      await scrollTo(tester, caliber);
      await tester.tap(caliber);
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(pageScrollOf(tester))
          .position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      await saveRenderPng(
        tester,
        find.byKey(boundary),
        '$output/$prefix-end.png',
      );
      images['$prefix-end.png'] = {
        'page': '充电',
        'scene': scenario,
        'mode': mode.name,
        'camera': camera,
        'safeArea': safeZero ? '0' : '24/24',
      };
      position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: prefix);
      await tester.pumpWidget(const SizedBox.shrink());
      client.close();
      gallery.close();
    }
    await tester.runAsync(() async {
      final dir = Directory(output);
      await dir.create(recursive: true);
      await File(
        '$output/measurements.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(measurements));
    });
    expect(measurements.every((m) => m['budgetMet'] == true), isTrue);
  }, skip: output.isEmpty || fontPath.isEmpty);

  testWidgets('AP10 P05 充电详情：正常 / 空采样 / 系列失败 浅深机位', (tester) async {
    final scenes = [
      for (final scenario in ['normal', 'empty', 'missing'])
        for (final mode in Brightness.values) (scenario, mode),
    ];
    final images = <String, Map<String, String>>{};
    for (final (scenario, mode) in scenes) {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
      tester.view.padding = tester.view.viewPadding;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = mode;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetViewPadding();
        tester.view.resetPadding();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
      });
      final gallery = aGalleryClient(scenario: scenario);
      final store = MemorySessionStore()
        ..value = jsonEncode({
          'site': cSite,
          'token': 'test',
          'expires_at': '2099-01-01T00:00:00Z',
        });
      final appearance = AppearanceController(_Appearance(mode.name));
      await appearance.restore();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MileafApp(
            key: UniqueKey(),
            client: gallery,
            sessionStore: store,
            appearance: appearance,
            trustStore: MemoryTrustStore(),
            vehiclePreferences: MemoryVehiclePreferences(),
            currencyPreferences: MemoryCurrency()..values[cSite] = 'CNY',
            now: () => cNow,
            calendar: () async => CalendarContext('Asia/Shanghai'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('charge-9'));
      if (scenario == 'empty') {
        // 空账本没有记录行：经概览「最近充电」行打开历史充电（last_charge 9）。
        // ensureVisible 会把行停在视口上沿（顶栏覆盖命中），向下拖一行再点。
        final recentCharge = find.text('最近充电');
        await tester.ensureVisible(recentCharge);
        await tester.pumpAndSettle();
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 160));
        await tester.pumpAndSettle();
        await tester.tap(recentCharge.hitTestable());
      } else {
        await tester.tap(navTab('充电'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          row,
          200,
          scrollable: pageScrollOf(tester),
        );
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row.hitTestable());
      }
      await tester.pumpAndSettle();
      expect(find.text('充电详情'), findsOneWidget);
      final prefix = 'AP10-充电详情-$scenario-glass-${mode.name}-360x800-100';
      await saveRenderPng(
        tester,
        find.byKey(boundary),
        '$output/$prefix-top.png',
      );
      images['$prefix-top.png'] = {
        'page': '充电详情',
        'scene': scenario,
        'mode': mode.name,
        'camera': '360x800-100',
      };
      // 页尾机位：说明层「口径与估算」展开后滚到底部。
      final caliber = find.text('口径与估算').hitTestable();
      await tester.scrollUntilVisible(caliber, 200);
      await tester.tap(caliber);
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).last)
          .position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      await saveRenderPng(
        tester,
        find.byKey(boundary),
        '$output/$prefix-end.png',
      );
      images['$prefix-end.png'] = {
        'page': '充电详情',
        'scene': scenario,
        'mode': mode.name,
        'camera': '360x800-100',
      };
      expect(tester.takeException(), isNull, reason: prefix);
      await tester.pumpWidget(const SizedBox.shrink());
      gallery.close();
    }
    await tester.runAsync(() async {
      final dir = Directory(output);
      await dir.create(recursive: true);
      final manifest = File('$output/p05-images.json');
      await manifest.writeAsString(
        const JsonEncoder.withIndent('  ').convert(images),
      );
    });
  }, skip: output.isEmpty || fontPath.isEmpty);
}
