import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/map/map_key.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/shell_harness.dart' show MemoryAppearanceStore, shellClient;
import 'charging_test.dart' show MemoryCurrency;
import 'support/map_key_fixture.dart';
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'support/test_trust_store.dart' show MemoryTrustStore;

const _output = String.fromEnvironment('MILEAF_SETTINGS_RENDER_OUTPUT');
const _font = String.fromEnvironment('MILEAF_RENDER_FONT');

void main() {
  setUpAll(() async {
    if (_output.isEmpty) return;
    await loadRenderFonts(cjkFontPath: _font);
  });

  testWidgets('设置与连接正式组件浅深、大字号、键盘渲染', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    for (final brightness in Brightness.values) {
      for (final scene in [
        'home',
        'home-large',
        'connection',
        'edit',
        'edit-large',
        'keyboard',
        'service',
      ]) {
        final large = scene.endsWith('large');
        tester.view.physicalSize = Size(large ? 320 : 390, 844);
        tester.view.viewInsets = const FakeViewPadding();
        tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
        final appearance = AppearanceController(
          MemoryAppearanceStore()..value = brightness.name,
        );
        await appearance.restore();
        final keys = MapKeyController(TestKeyStore());
        await keys.restore();
        final store = MemorySessionStore()
          ..value = jsonEncode({
            'site': 'https://mileaf.example.com',
            'token': 'synthetic-render-token',
            'expires_at': '2099-01-01T00:00:00Z',
          });
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MileafApp(
              key: UniqueKey(),
              client: shellClient(),
              mapKeys: keys,
              appearance: appearance,
              currencyPreferences: MemoryCurrency(),
              sessionStore: store,
              trustStore: MemoryTrustStore(),
              vehiclePreferences: MemoryVehiclePreferences(),
              now: () => DateTime.utc(2026, 10, 26, 10, 40),
              calendar: () async => CalendarContext('Asia/Shanghai'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('设置'));
        await tester.pumpAndSettle();
        if (scene == 'service') {
          await tester.tap(find.text('服务信息'));
          await tester.pumpAndSettle();
        } else if (!scene.startsWith('home')) {
          await tester.ensureVisible(find.text('站点连接'));
          await tester.tap(find.text('站点连接'));
          await tester.pumpAndSettle();
          if (scene != 'connection') {
            await tester.tap(find.text('更换连接'));
            await tester.pumpAndSettle();
          }
          if (scene == 'keyboard') {
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            await tester.tap(find.widgetWithText(TextFormField, '站点访问口令'));
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.text('验证并替换连接'));
            await tester.pumpAndSettle();
          }
        }
        expect(tester.takeException(), isNull);
        await saveRenderPng(
          tester,
          find.byKey(boundary),
          '$_output/settings-${brightness.name}-$scene.png',
        );
        // Check the bottom of long pages too, beyond the captured viewport.
        if (large) {
          final last = scene == 'home-large' ? '服务信息' : '退出此设备';
          await tester.ensureVisible(find.text(last));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        keys.dispose();
        appearance.dispose();
      }
    }
  }, skip: _output.isEmpty);
}
