import 'support/render_png.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:mileaf/main.dart';
import 'package:mileaf/src/workspace.dart';
import 'package:mileaf/src/currency.dart';

import 'support/c_fixture.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

http.Response _ok(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'max-age=30',
  },
);

class _Cny implements CurrencyPreferenceStore {
  @override
  Future<String?> read(String site) async => 'CNY';
  @override
  Future<void> write(String site, String? code) async {}
}

MockClient cGalleryClient({String scenario = 'normal'}) => MockClient((
  request,
) async {
  final url = request.url;
  if (url.path.endsWith('/vehicles')) return _ok(cVehicles());
  if (url.path.endsWith('/summary')) {
    return _ok(scenario == 'empty' ? cEmptySummary() : cSummary());
  }
  if (url.path.endsWith('/meta')) return _ok(cMeta());
  if (url.path.endsWith('/drives')) return _ok(cDrives());
  if (url.path.endsWith('/driving-analysis')) {
    return _ok(
      url.queryParameters['view'] == 'calendar'
          ? cCalendar(url)
          : (scenario == 'empty' ? cEmptyUsage() : cUsage()),
    );
  }
  if (url.path.endsWith('/stats')) {
    final charging = url.queryParameters['kind'] == 'charging';
    if (scenario == 'empty') {
      return _ok(charging ? cEmptyCharging(url) : cEmptyDriving(url));
    }
    if (scenario == 'missing' && !charging) return _ok(cMissingDriving(url));
    return _ok(charging ? cCharging(url) : cDrivesStats(url));
  }
  return http.Response('{}', 404);
});

/// Every C page in one gallery, driven exclusively by test/support/c_fixture.dart.
void main() {
  setUpAll(() async {
    if (output.isEmpty) return;
    final bytes = ByteData.sublistView(File(fontPath).readAsBytesSync());
    for (final family in ['Roboto', 'Arial', 'sans-serif']) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('C 图册：概览/统计/行程/节奏共用同一 fixture', (tester) async {
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

    Future<void> pumpApp(String key, {String scenario = 'normal'}) async {
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
          final suffix =
              '$scenario-${brightness.name}-${scale == 1 ? '100' : '200'}';
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          tester.platformDispatcher.textScaleFactorTestValue = scale;

          await pumpApp('overview-$suffix', scenario: scenario);
          await save('overview-$suffix');

          await tester.tap(find.text('统计').last);
          await tester.pumpAndSettle();
          await save('statistics-$suffix');

          await tester.scrollUntilVisible(find.text('节奏').hitTestable(), 150);
          await tester.tap(find.text('节奏').hitTestable());
          await tester.pumpAndSettle();
          await save('rhythm-$suffix');

          await pumpApp('drives-$suffix', scenario: scenario);
          await tester.tap(find.text('行程').last);
          await tester.pumpAndSettle();
          await save('drives-$suffix');
        }
      }
    }
  }, skip: output.isEmpty);
}
