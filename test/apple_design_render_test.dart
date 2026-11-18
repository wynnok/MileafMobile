import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/workspace.dart';

import 'charging_cost_test.dart' show CostSite, openCostSheet, pumpCostApp;
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

Finder _firstCharge() => find.byWidgetPredicate(
  (widget) =>
      widget.key is ValueKey<String> &&
      (widget.key! as ValueKey<String>).value.startsWith('charge-'),
);

Map<String, num> _rect(Rect rect) => {
  'left': rect.left,
  'top': rect.top,
  'right': rect.right,
  'bottom': rect.bottom,
  'width': rect.width,
  'height': rect.height,
};

Future<void> _pumpGallery(
  WidgetTester tester, {
  required Brightness brightness,
  required GlobalKey boundary,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.padding = tester.view.viewPadding;
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

void main() {
  setUpAll(() async {
    if (fontPath.isNotEmpty) await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('Apple renewal representative Flutter gallery', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
      tester.view.resetPadding();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });

    final geometry = <String, Object?>{
      'logical_size': '390x844',
      'pixel_ratio': 2,
      'text_scale': 1,
      'safe_area': {'top': 24, 'bottom': 24},
      'timezone': 'Asia/Shanghai',
      'fixture': 'cGalleryClient / CostSite',
      'font': fontPath,
    };
    for (final brightness in Brightness.values) {
      final mode = brightness.name;
      final boundary = GlobalKey();
      await _pumpGallery(tester, brightness: brightness, boundary: boundary);
      await saveRenderPng(
        tester,
        find.byKey(boundary),
        '$output/overview-$mode.png',
      );
      geometry['overview-$mode'] = {
        'top_bar': _rect(tester.getRect(find.byType(MileafTopBar))),
        'status': _rect(
          tester.getRect(find.byKey(const ValueKey('overview-status'))),
        ),
        'bottom_bar': _rect(tester.getRect(find.byType(MileafNavBar))),
      };

      await tester.tap(_nav('行程'));
      await tester.pumpAndSettle();
      expect(find.byType(MileafTopBar).hitTestable(), findsOneWidget);
      await saveRenderPng(
        tester,
        find.byKey(boundary),
        '$output/drives-$mode.png',
      );
      geometry['drives-$mode'] = {
        'top_bar': _rect(tester.getRect(find.byType(MileafTopBar))),
        'first_record': _rect(
          tester.getRect(find.byKey(const ValueKey('drive-17'))),
        ),
        'bottom_bar': _rect(tester.getRect(find.byType(MileafNavBar))),
      };

      await tester.tap(_nav('统计'));
      await tester.pumpAndSettle();
      expect(find.byType(MileafTopBar).hitTestable(), findsOneWidget);
      await saveRenderPng(
        tester,
        find.byKey(boundary),
        '$output/statistics-$mode.png',
      );
      geometry['statistics-$mode'] = {
        'top_bar': _rect(tester.getRect(find.byType(MileafTopBar))),
        'chart': _rect(tester.getRect(find.byType(TimeSeriesChart).first)),
        'bottom_bar': _rect(tester.getRect(find.byType(MileafNavBar))),
      };

      await tester.tap(_nav('充电'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(_firstCharge(), 240);
      await tester.tap(_firstCharge().first);
      await tester.pumpAndSettle();
      await saveRenderPng(
        tester,
        find.byKey(boundary),
        '$output/charging-detail-$mode.png',
      );
      geometry['charging-detail-$mode'] = {
        'battery_arc': _rect(tester.getRect(find.byType(BatteryArc))),
        'chart': _rect(
          tester.getRect(find.byKey(const Key('charging-time-chart'))),
        ),
      };

      final costBoundary = GlobalKey();
      await pumpCostApp(
        tester,
        CostSite(),
        size: const Size(390, 844),
        boundary: costBoundary,
      );
      await tester.tap(_nav('充电'));
      await tester.pumpAndSettle();
      await openCostSheet(tester);
      await saveRenderPng(
        tester,
        find.byKey(costBoundary),
        '$output/charging-cost-$mode.png',
      );
      geometry['charging-cost-$mode'] = {
        'sheet': _rect(tester.getRect(find.byType(MileafSheetFrame))),
      };
      await tester.pumpWidget(const SizedBox.shrink());
    }
    await tester.runAsync(
      () => File('$output/geometry.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(geometry)),
    );
  }, skip: output.isEmpty || fontPath.isEmpty);
}
