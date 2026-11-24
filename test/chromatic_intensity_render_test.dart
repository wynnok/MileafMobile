import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/workspace.dart';

import 'overview_statistics_reading_test.dart'
    show chargingDays, dayStats, readingClient;
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/test_trust_store.dart';
import 'support/vehicle_preferences.dart';

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

class _Appearance implements AppearancePreferenceStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? next) async => value = next;
}

/// 四个主页面的浅深首屏、滚动色面和悬浮选择器。
void main() {
  setUpAll(() async {
    if (output.isEmpty) return;
    await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('四页首屏对照样张', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final boundary = GlobalKey();
    for (final brightness in Brightness.values) {
      for (final page in ['概览', '行程', '充电', '统计']) {
        final store = MemorySessionStore()
          ..value = jsonEncode({
            'site': 'https://example.com/prefix',
            'token': 'test',
            'expires_at': '2099-01-01T00:00:00Z',
          });
        final appearance = AppearanceController(
          _Appearance()
            ..value = brightness == Brightness.dark ? 'dark' : 'light',
        );
        await appearance.restore();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MileafApp(
              key: ValueKey('${brightness.name}-$page'),
              client: readingClient(
                [],
                driving: (url) => dayStats(url, days: 7),
                charging: chargingDays,
              ),
              sessionStore: store,
              trustStore: MemoryTrustStore(),
              vehiclePreferences: MemoryVehiclePreferences(),
              appearance: appearance,
              now: () => DateTime.utc(2026, 3, 30, 12),
              calendar: () async => CalendarContext('UTC'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (page != '概览') {
          await tester.tap(
            find.descendant(
              of: find.byType(MileafNavBar),
              matching: find.text(page),
            ),
          );
          await tester.pumpAndSettle();
        }
        await saveRenderPng(
          tester,
          find.byKey(boundary),
          '$output/$page-${brightness.name}.png',
        );
        if (page == '概览') {
          final scroll = tester.state<ScrollableState>(
            find.byType(Scrollable).last,
          );
          scroll.position.jumpTo(132);
          await tester.pumpAndSettle();
          await saveRenderPng(
            tester,
            find.byKey(boundary),
            '$output/概览-滚动玻璃-${brightness.name}.png',
          );
          await tester.tap(find.byKey(const ValueKey('top-bar-vehicle')));
          await tester.pumpAndSettle();
          expect(find.text('选择车辆'), findsOneWidget);
          await saveRenderPng(
            tester,
            find.byKey(boundary),
            '$output/选择车辆-${brightness.name}.png',
          );
          await tester.tap(find.byTooltip('关闭'));
          await tester.pumpAndSettle();
        }
        if (page == '行程' || page == '统计') {
          final scroll = tester.state<ScrollableState>(
            find.byType(Scrollable).last,
          );
          scroll.position.jumpTo(
            scroll.position.maxScrollExtent.clamp(0.0, 330.0),
          );
          await tester.pumpAndSettle();
          await saveRenderPng(
            tester,
            find.byKey(boundary),
            '$output/$page-滚动-${brightness.name}.png',
          );
        }
        expect(tester.takeException(), isNull);
      }
    }
  }, skip: output.isEmpty);
}
