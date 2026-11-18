import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/display_preferences.dart';
import 'package:mileaf/src/design/icons.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/c_fixture.dart' show cNow, cSite;
import 'support/c_gallery_client.dart';
import 'support/render_fonts.dart';
import 'support/color_math.dart';
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

/// 只有底栏与空白 canvas：同一几何下比较玻璃与实色两套材质。
Future<void> _pumpBar(
  WidgetTester tester, {
  required Brightness brightness,
  required GlobalKey boundary,
  required bool highContrast,
}) async {
  final preferences = DisplayPreferencesController(
    platform: DisplayPreferencesPlatform.android,
  );
  addTearDown(preferences.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: DisplayPreferencesScope(
        controller: preferences,
        child: MaterialApp(
          theme: mileafTheme(brightness),
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              highContrast: highContrast,
              viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
              padding: const EdgeInsets.only(top: 24, bottom: 24),
            ),
            child: Scaffold(
              bottomNavigationBar: MileafNavBar(index: 0, onSelected: (_) {}),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _labels = ['概览', '行程', '充电', '统计'];

/// L04 的渲染口径：标签 ≥4.5:1（文字），图标 ≥3:1（图形）。
void expectReadable(Map<String, Map<String, double>> measured, String where) {
  measured.forEach((key, value) {
    final floor = key.startsWith('label:') ? 4.5 : 3.0;
    expect(
      value['contrast'],
      greaterThanOrEqualTo(floor),
      reason: '$where / $key',
    );
  });
}

/// 从实际渲染的像素里量标签与图标：墨水取框内最暗/最亮像素，背景取框内
/// 90/12 分位，两者按 WCAG 求比。这样 L04 的“高透仍可读”有可重跑的证据，
/// 而不只是一条 token 合成公式。
Future<Map<String, Map<String, double>>> _measureContrast(
  WidgetTester tester,
  GlobalKey boundary,
  Brightness brightness,
) async {
  final dark = brightness == Brightness.dark;
  final boxes = <String, Rect>{};
  for (final label in _labels) {
    boxes['label:$label'] = tester.getRect(_nav(label));
  }
  final icons = find.descendant(
    of: find.byType(MileafNavBar),
    matching: find.byType(MileafIcon),
  );
  for (var i = 0; i < _labels.length; i++) {
    boxes['icon:${_labels[i]}'] = tester.getRect(icons.at(i));
  }
  final render = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundary),
  );
  final measured = await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: 2);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = data!.buffer.asUint8List();
      final width = image.width;
      final result = <String, Map<String, double>>{};
      boxes.forEach((key, rect) {
        final left = (rect.left * 2).floor().clamp(0, width - 1);
        final right = (rect.right * 2).ceil().clamp(left + 1, width);
        final top = (rect.top * 2).floor().clamp(0, image.height - 1);
        final bottom = (rect.bottom * 2).ceil().clamp(top + 1, image.height);
        final values = <double>[];
        for (var y = top; y < bottom; y++) {
          for (var x = left; x < right; x++) {
            final i = (y * width + x) * 4;
            values.add(
              luminance(
                Color.fromARGB(255, bytes[i], bytes[i + 1], bytes[i + 2]),
              ),
            );
          }
        }
        values.sort();
        final ink = dark ? values.last : values.first;
        final backdrop = dark
            ? values[(values.length * .12).floor()]
            : values[(values.length * .90).floor()];
        result[key] = {
          'contrast': contrastRatioOf(ink, backdrop),
          'ink_luminance': ink,
          'backdrop_luminance': backdrop,
        };
      });
      return result;
    } finally {
      image.dispose();
    }
  });
  return measured!;
}

/// [contrastRatio] works on colours; the sampler already has luminances.
double contrastRatioOf(double a, double b) {
  final high = a > b ? a : b;
  final low = a > b ? b : a;
  return (high + .05) / (low + .05);
}

void main() {
  setUpAll(() async {
    if (fontPath.isNotEmpty) await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('Liquid glass navigation renders', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
      tester.view.resetPadding();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });

    final contrast = <String, Object?>{};
    final geometry = <String, Object?>{
      'logical_size': '390x844',
      'pixel_ratio': 2,
      'text_scale': 1,
      'safe_area': {'top': 24, 'bottom': 24},
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
        'bar': _rect(tester.getRect(find.byType(MileafNavBar))),
        'material': _rect(tester.getRect(find.byType(MileafGlassSurface))),
      };
      final overviewContrast = await _measureContrast(
        tester,
        boundary,
        brightness,
      );
      contrast['overview-$mode'] = overviewContrast;
      expectReadable(overviewContrast, 'overview-$mode');

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      await saveRenderPng(
        tester,
        find.byKey(boundary),
        '$output/overview-scrolled-$mode.png',
      );

      await tester.tap(_nav('行程'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -220));
      await tester.pumpAndSettle();
      await saveRenderPng(
        tester,
        find.byKey(boundary),
        '$output/drives-scrolled-$mode.png',
      );
      final overContent = await _measureContrast(tester, boundary, brightness);
      contrast['drives-scrolled-$mode'] = overContent;
      expectReadable(overContent, 'drives-scrolled-$mode');

      await tester.pumpWidget(const SizedBox.shrink());
      final solid = GlobalKey();
      await _pumpBar(
        tester,
        brightness: brightness,
        boundary: solid,
        highContrast: true,
      );
      await saveRenderPng(tester, find.byKey(solid), '$output/solid-$mode.png');
      await tester.pumpWidget(const SizedBox.shrink());
    }
    await tester.runAsync(() async {
      await File('$output/geometry.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(geometry));
      await File('$output/contrast.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(contrast));
    });
  }, skip: output.isEmpty || fontPath.isEmpty);
}

Map<String, num> _rect(Rect rect) => {
  'left': rect.left,
  'top': rect.top,
  'right': rect.right,
  'bottom': rect.bottom,
  'width': rect.width,
  'height': rect.height,
};
