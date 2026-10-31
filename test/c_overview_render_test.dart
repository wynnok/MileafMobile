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

MockClient cClient() => MockClient((request) async {
  final url = request.url;
  if (url.path.endsWith('/vehicles')) return _ok(cVehicles());
  if (url.path.endsWith('/summary')) return _ok(cSummary());
  if (url.path.endsWith('/meta')) return _ok(cMeta());
  if (url.path.endsWith('/stats')) {
    return _ok(
      url.queryParameters['kind'] == 'charging'
          ? cCharging(url)
          : cDriving(url),
    );
  }
  return http.Response('{}', 404);
});

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

  testWidgets('概览 C 设计正式渲染', (tester) async {
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

    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        final suffix =
            '${brightness.name}-${scale == 1 ? '100' : '200'}';
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
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
              key: ValueKey(suffix),
              client: cClient(),
              sessionStore: store,
              trustStore: MemoryTrustStore(),
              vehiclePreferences: MemoryVehiclePreferences(),
              currencyPreferences: _Cny(),
              now: () => cNow,
              calendar: () async => CalendarContext('Asia/Shanghai'),
            ),
          ),
        );
        await save('overview-$suffix');
      }
    }
  }, skip: output.isEmpty);
}
