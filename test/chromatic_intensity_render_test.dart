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

/// 鲜明度 v2 的对照样张：四个主页面 × 浅深两模式，只截首屏。
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
        expect(tester.takeException(), isNull);
      }
    }
  }, skip: output.isEmpty);
}
