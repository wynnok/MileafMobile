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

/// 行程焦点卡卡头（期间名 + 区间）的 opt-in 渲染入口：
/// 未设置 MILEAF_RENDER_OUTPUT / MILEAF_RENDER_FONT 时整组跳过。
const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

/// 与用户截屏同一窗口：近 30 天 = 10月20日–11月18日（13 字）。
final _now = DateTime.utc(2026, 11, 18, 12);

http.Response _json(String body) => http.Response(
  body,
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

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
  required Size size,
  required double scale,
  required String name,
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
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.padding = tester.view.viewPadding;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
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
            return _json(
              File('test/fixtures/vehicles.json').readAsStringSync(),
            );
          }
          if (r.url.path.endsWith('/stats')) {
            return _json(
              File('test/fixtures/driving-stats.json').readAsStringSync(),
            );
          }
          if (r.url.path.endsWith('/summary')) {
            return _json(File('test/fixtures/summary.json').readAsStringSync());
          }
          return _json('{"items":[],"next_cursor":null}');
        }),
        sessionStore: store,
        mapKeys: keys,
        trustStore: MemoryTrustStore(),
        vehiclePreferences: MemoryVehiclePreferences(),
        appearance: appearance,
        now: () => _now,
        calendar: () async => CalendarContext('Asia/Shanghai'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('行程').last);
  await tester.pumpAndSettle();
  await saveRenderPng(tester, find.byKey(boundary), '$output/$name');
}

void main() {
  setUpAll(() async {
    if (fontPath.isNotEmpty) await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('卡头渲染矩阵：一行 / 落到下一行 / 连接号后断行', (tester) async {
    if (output.isEmpty) return;
    // 用户截屏机位：360 宽 100%，13 字区间仍与期间名同一行。
    await _shot(
      tester,
      boundary: GlobalKey(),
      brightness: Brightness.light,
      size: const Size(360, 800),
      scale: 1,
      name: 'header-360x800-100-light.png',
    );
    await _shot(
      tester,
      boundary: GlobalKey(),
      brightness: Brightness.dark,
      size: const Size(360, 800),
      scale: 1,
      name: 'header-360x800-100-dark.png',
    );
    // 150%：区间整段落到期间名下一行，左对齐。
    await _shot(
      tester,
      boundary: GlobalKey(),
      brightness: Brightness.light,
      size: const Size(390, 844),
      scale: 1.5,
      name: 'header-390x844-150-light.png',
    );
    // 200% / 320 宽：整段区间也放不下，只在 DF3 连接号后断行。
    await _shot(
      tester,
      boundary: GlobalKey(),
      brightness: Brightness.light,
      size: const Size(320, 568),
      scale: 2,
      name: 'header-320x568-200-light.png',
    );
  }, skip: output.isEmpty || fontPath.isEmpty);
}
