import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/drives_page.dart';
import 'package:mileaf/src/design/components/chip.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/a_gallery_fixture.dart';
import 'support/c_fixture.dart';
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'support/test_trust_store.dart' show MemoryTrustStore;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'drives_test.dart' show openDrives, jsonResponse;

const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');
const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');

class _Appearance implements AppearancePreferenceStore {
  _Appearance(this.value);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? next) async => value = next;
}

void main() {
  setUpAll(() async {
    if (fontPath.isNotEmpty) await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('U05 按站点日期分组，普通记录至少88且跨年明确', (tester) async {
    final body = jsonDecode(
      File('test/fixtures/drives.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final items = body['items'] as List;
    items[0]['started_at'] = '2025-12-31T15:50:00Z';
    items[0]['ended_at'] = '2025-12-31T16:20:00Z';
    items[1]['started_at'] = '2025-12-30T21:30:00Z';
    items[1]['ended_at'] = null;
    body['next_cursor'] = null;
    await openDrives(tester, (_) async => jsonResponse(jsonEncode(body)));
    // P02：记录按 copy.formatDayGroup 分天分组——跨年写「M月D日 周X」并带年。
    expect(find.text('2025年12月31日 周三'), findsOneWidget);
    expect(find.textContaining('2026-01-01 00:20'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('drive-17'))).height,
      greaterThanOrEqualTo(88),
    );
    await tester.scrollUntilVisible(find.text('进行中').hitTestable(), 160);
    expect(find.text('进行中'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('U05 正式字体首屏、全状态与完整滚动矩阵', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final scenes = [
      for (final scenario in ['normal', 'empty', 'missing'])
        for (final mode in Brightness.values)
          for (final scale in [1.0, 2.0])
            (scenario, mode, const Size(360, 800), scale, false),
      ('long', Brightness.dark, const Size(320, 568), 2.0, false),
      ('normal', Brightness.light, const Size(390, 844), 1.0, false),
      ('long', Brightness.dark, const Size(768, 1024), 2.0, false),
      ('long', Brightness.light, const Size(360, 800), 1.0, false),
      ('normal', Brightness.light, const Size(360, 800), 1.3, false),
      ('normal', Brightness.dark, const Size(360, 800), 1.5, false),
      ('normal', Brightness.light, const Size(360, 800), 1.0, true),
      ('normal', Brightness.dark, const Size(360, 800), 1.0, true),
    ];
    for (final (scenario, mode, size, scale, safeZero) in scenes) {
      tester.view.physicalSize = size;
      tester.view.viewPadding = safeZero
          ? FakeViewPadding.zero
          : const FakeViewPadding(top: 24, bottom: 24);
      tester.view.padding = tester.view.viewPadding;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      final client = aGalleryClient(
        scenario: scenario == 'long' ? 'normal' : scenario,
        irregular: true,
        longFields: scenario == 'long',
      );
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
            now: () => cNow,
            calendar: () async => CalendarContext('Asia/Shanghai'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('行程').last);
      await tester.pumpAndSettle();
      final prefix =
          '$output/drives-$scenario-${mode.name}-${size.width.round()}-${(scale * 100).round()}${safeZero ? '-safe0' : ''}';
      final scroll = find
          .descendant(
            of: find.byType(DrivesPage),
            matching: find.byType(Scrollable),
          )
          .first;
      if (scenario == 'normal' &&
          size.width == 360 &&
          scale == 1 &&
          !safeZero) {
        // P02：节奏图改紧凑读数行——日期与数值分两段（DF1 + 「值 单位」）。
        expect(find.text('10月26日'), findsWidgets);
        expect(find.text('64.1 km'), findsOneWidget);
        // 焦点卡三格：行程 52 趟。
        expect(find.text('52 趟'), findsOneWidget);
        final viewport = tester.getRect(scroll);
        final first = tester.getRect(find.byKey(const ValueKey('drive-17')));
        final second = tester.getRect(find.byKey(const ValueKey('drive-16')));
        debugPrint(
          'U05 ${mode.name} body=$viewport first=$first second=$second visible=${viewport.bottom - second.top}',
        );
        expect(first.bottom, lessThanOrEqualTo(viewport.bottom));
        expect(viewport.bottom - second.top, greaterThanOrEqualTo(24));
      }
      await saveRenderPng(tester, find.byKey(boundary), '$prefix-top.png');
      if (size.width == 320) {
        for (final label in ['近7天', '近30天']) {
          tester.state<ScrollableState>(scroll).position.jumpTo(0);
          await tester.pumpAndSettle();
          final control = find.widgetWithText(StatusChip, label);
          await tester.scrollUntilVisible(control, 120, scrollable: scroll);
          await tester.pumpAndSettle();
          tester.widget<StatusChip>(control).onTap!();
          await tester.pumpAndSettle();
        }
      }
      if (scenario == 'long' || scenario == 'missing') {
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('drive-17')).hitTestable(),
          160,
          scrollable: scroll,
        );
        await saveRenderPng(tester, find.byKey(boundary), '$prefix-record.png');
      }
      await tester.scrollUntilVisible(
        find.text('数据说明').hitTestable(),
        250,
        scrollable: scroll,
      );
      await tester.tap(find.text('数据说明').hitTestable());
      await tester.pumpAndSettle();
      final position = tester.state<ScrollableState>(scroll).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      await saveRenderPng(tester, find.byKey(boundary), '$prefix-end.png');
      if (scenario == 'normal' &&
          mode == Brightness.light &&
          scale == 1 &&
          !safeZero &&
          size.width == 360) {
        position.jumpTo(0);
        await tester.pumpAndSettle();
        for (var i = 0; i < 20; i++) {
          await saveRenderPng(
            tester,
            find.byKey(boundary),
            '$prefix-scroll$i.png',
          );
          if (position.extentAfter == 0) break;
          position.jumpTo(
            (position.pixels + 400).clamp(0, position.maxScrollExtent),
          );
          await tester.pumpAndSettle();
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      client.close();
    }
  }, skip: fontPath.isEmpty || output.isEmpty);
}
