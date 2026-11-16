import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/c_fixture.dart' show cNow, cSite;
import 'support/c_gallery_client.dart';
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

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

Future<void> _pump(
  WidgetTester tester, {
  required Brightness brightness,
  required double scale,
  required double width,
  required GlobalKey boundary,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
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
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MileafApp(
        client: cGalleryClient(),
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

/// 概览图表下方读数区的对照样张：390×844、DPR 2、浅深色、100/200% 字号。
void main() {
  setUpAll(() async {
    if (fontPath.isNotEmpty) await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('概览读数区样张', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
      tester.view.resetPadding();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });
    for (final brightness in Brightness.values) {
      for (final (width, scale) in const [
        (390.0, 1.0),
        (390.0, 2.0),
        (320.0, 1.0),
      ]) {
        final boundary = GlobalKey();
        await _pump(
          tester,
          brightness: brightness,
          scale: scale,
          width: width,
          boundary: boundary,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('每日里程')),
          alignment: scale == 1 ? .15 : .25,
        );
        await tester.pumpAndSettle();
        await saveRenderPng(
          tester,
          find.byKey(boundary),
          '$output/overview-reading-${brightness.name}-'
          '${width.toInt()}-${scale == 1 ? '100' : '200'}.png',
        );
        if (scale == 2) {
          await Scrollable.ensureVisible(
            tester.element(find.text('本期')),
            alignment: .32,
          );
          await tester.pumpAndSettle();
          await saveRenderPng(
            tester,
            find.byKey(boundary),
            '$output/overview-reading-plate-${brightness.name}-'
            '${width.toInt()}-200.png',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  }, skip: output.isEmpty || fontPath.isEmpty);
}
