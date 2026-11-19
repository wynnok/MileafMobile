import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/map_key_fixture.dart';
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/test_trust_store.dart' show MemoryTrustStore;
import 'support/vehicle_preferences.dart';

/// DM03 / MG06（PD12）首屏预算实测入口：360×800 机位的概览与行程首屏。
/// opt-in：未设置 MILEAF_RENDER_OUTPUT / MILEAF_RENDER_FONT 时整组跳过。
/// 产出目录建议 build/dm03-spacing-renders/（build/ 不入库）。
const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

http.Response _json(String body) => http.Response(
  body,
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

String _fixture(String name) =>
    File('test/fixtures/$name').readAsStringSync();

class _AppearanceStore implements AppearancePreferenceStore {
  _AppearanceStore(this.value);
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? value) async => this.value = value;
}

Future<void> _shot(
  WidgetTester tester, {
  required GlobalKey boundary,
  required Brightness brightness,
  required String name,
  required bool drives,
}) async {
  final keys = await configuredMapKeys();
  addTearDown(keys.dispose);
  final store = MemorySessionStore()
    ..value = jsonEncode({
      'site': 'https://example.com/prefix',
      'token': 'test',
      'expires_at': '2099-01-01T00:00:00Z',
    });
  final appearance = AppearanceController(_AppearanceStore(brightness.name));
  await appearance.restore();
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.padding = tester.view.viewPadding;
  tester.platformDispatcher.textScaleFactorTestValue = 1;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewPadding();
    tester.view.resetPadding();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MileafApp(
        client: MockClient((r) async {
          if (r.url.path.endsWith('/vehicles')) {
            return _json(_fixture('vehicles.json'));
          }
          if (r.url.path.endsWith('/meta')) return _json(_fixture('meta.json'));
          if (r.url.path.endsWith('/stats')) {
            return _json(_fixture('driving-stats.json'));
          }
          if (r.url.path.endsWith('/summary')) {
            return _json(_fixture('summary.json'));
          }
          return _json('{"items":[],"next_cursor":null}');
        }),
        sessionStore: store,
        mapKeys: keys,
        trustStore: MemoryTrustStore(),
        vehiclePreferences: MemoryVehiclePreferences(),
        appearance: appearance,
        now: () => DateTime.utc(2026, 3, 30, 12),
        calendar: () async => CalendarContext('Asia/Shanghai'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (drives) {
    await tester.tap(find.text('行程').last);
    await tester.pumpAndSettle();
  }
  await saveRenderPng(tester, find.byKey(boundary), '$output/$name');
}

void main() {
  setUpAll(() async {
    if (fontPath.isNotEmpty) await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('PD12 首屏预算实测：概览 / 行程 360×800 浅深各一', (tester) async {
    if (output.isEmpty) return;
    await _shot(
      tester,
      boundary: GlobalKey(),
      brightness: Brightness.light,
      name: 'pd12-overview-360x800-100-light.png',
      drives: false,
    );
    await _shot(
      tester,
      boundary: GlobalKey(),
      brightness: Brightness.dark,
      name: 'pd12-overview-360x800-100-dark.png',
      drives: false,
    );
    await _shot(
      tester,
      boundary: GlobalKey(),
      brightness: Brightness.light,
      name: 'pd12-drives-360x800-100-light.png',
      drives: true,
    );
    await _shot(
      tester,
      boundary: GlobalKey(),
      brightness: Brightness.dark,
      name: 'pd12-drives-360x800-100-dark.png',
      drives: true,
    );
  }, skip: output.isEmpty || fontPath.isEmpty);
}