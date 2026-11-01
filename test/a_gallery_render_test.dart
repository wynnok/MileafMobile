import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/c_fixture.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;
import 'c_gallery_render_test.dart' show cGalleryClient;

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

class _Appearance implements AppearancePreferenceStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? next) async => value = next;
}

class _Cny implements CurrencyPreferenceStore {
  @override
  Future<String?> read(String site) async => 'CNY';
  @override
  Future<void> write(String site, String? code) async {}
}

/// A visual QA gallery: four tabs, two details, one topic, across the
/// light/dark and 100/200% axes plus empty and missing states.
void main() {
  setUpAll(() async {
    if (output.isEmpty) return;
    final bytes = ByteData.sublistView(File(fontPath).readAsBytesSync());
    for (final family in ['Inter', 'Roboto', 'Arial', 'sans-serif']) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('A 图册：主 Tab、详情与专题', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final boundary = GlobalKey();
    Future<void> save(String name) =>
        saveRenderPng(tester, find.byKey(boundary), '$output/$name.png');

    Future<void> pumpApp(
      String key,
      String scenario,
      Brightness brightness,
    ) async {
      final appearanceStore = _Appearance()
        ..value = brightness == Brightness.dark ? 'dark' : 'light';
      final appearance = AppearanceController(appearanceStore);
      await appearance.restore();
      final store = MemorySessionStore()
        ..value = jsonEncode({
          'site': cSite,
          'token': 'test',
          'expires_at': '2099-01-01T00:00:00Z',
        });
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MileafApp(
            key: ValueKey(key),
            client: cGalleryClient(scenario: scenario),
            sessionStore: store,
            trustStore: MemoryTrustStore(),
            vehiclePreferences: MemoryVehiclePreferences(),
            currencyPreferences: _Cny(),
            appearance: appearance,
            now: () => cNow,
            calendar: () async => CalendarContext('Asia/Shanghai'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final scenario in ['normal', 'empty', 'missing']) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 2.0]) {
          if (scenario != 'normal' &&
              (brightness != Brightness.dark || scale != 1.0)) {
            continue;
          }
          final suffix =
              '$scenario-${brightness.name}-${scale == 1 ? '100' : '200'}';
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          tester.platformDispatcher.textScaleFactorTestValue = scale;

          await pumpApp('overview-$suffix', scenario, brightness);
          await save('overview-$suffix');
          if (scenario == 'normal' && scale == 1.0) {
            expect(find.textContaining('每日里程'), findsWidgets);
            expect(find.textContaining('本月 · 驾驶里程'), findsWidgets);
          }

          await pumpApp('drives-$suffix', scenario, brightness);
          await tester.tap(find.text('行程').last);
          await tester.pumpAndSettle();
          await save('drives-$suffix');
          if (scenario == 'normal' && scale == 1.0) {
            expect(find.text('出行节奏'), findsOneWidget);
            expect(find.text('最近的路'), findsOneWidget);
          }

          await pumpApp('charging-$suffix', scenario, brightness);
          await tester.tap(find.text('充电').last);
          await tester.pumpAndSettle();
          await save('charging-$suffix');
          if (scenario == 'normal' && scale == 1.0) {
            expect(find.textContaining('已知充电费用'), findsWidgets);
            expect(find.text('每日补能'), findsOneWidget);
          }

          await pumpApp('statistics-$suffix', scenario, brightness);
          await tester.tap(find.text('统计').last);
          await tester.pumpAndSettle();
          await save('statistics-$suffix');
          if (scenario == 'normal' && scale == 1.0) {
            expect(find.text('里程走势'), findsOneWidget);
            expect(find.text('四个问题'), findsOneWidget);
          }

          if (scenario == 'normal') {
            await tester.scrollUntilVisible(
              find.text('节奏').hitTestable(),
              150,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('节奏').hitTestable());
            await tester.pumpAndSettle();
            await save('topic-rhythm-$suffix');

            await pumpApp('charge-detail-$suffix', scenario, brightness);
            await tester.scrollUntilVisible(
              find.text('最近充电').hitTestable(),
              200,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('最近充电').hitTestable());
            await tester.pumpAndSettle();
            await save('charge-detail-$suffix');

            await pumpApp('drive-detail-$suffix', scenario, brightness);
            await tester.scrollUntilVisible(
              find.text('最近行程').hitTestable(),
              200,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('最近行程').hitTestable());
            await tester.pumpAndSettle();
            await save('drive-detail-$suffix');
          }
        }
      }
    }
  }, skip: output.isEmpty);
}
