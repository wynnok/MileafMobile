import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/a_gallery_fixture.dart';
import 'support/c_fixture.dart';
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

/// A long vehicle name is the point of the overview scene, not decoration.
const longName = '白露 · 长续航双电机全轮驱动版 2026 款';

/// What each scene must show once it is on screen: the state has to be real
/// data (a zero, a gap, a long name), never normal data relabelled.
const markers = <String, ({List<String> must, List<String> mustNot})>{
  'overview-long': (
    must: [longName, '本月 · 驾驶里程', '1,198.6'],
    mustNot: ['这段时间还没有行程'],
  ),
  'drives-sparse': (
    must: ['出行节奏', '看当天'],
    mustNot: ['这段时间还没有行程'],
  ),
  'charging-sparse': (
    must: ['每日补能', '看当天'],
    mustNot: ['这段时间还没有充电记录'],
  ),
};

class _Appearance implements AppearancePreferenceStore {
  _Appearance(this.value);
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

/// Sparse and long-text renders for #26: the states the 132-image gallery does
/// not cover (real zeros and nulls inside a daily series, and a long vehicle
/// name at 200% text).
void main() {
  setUpAll(() async {
    if (output.isEmpty) return;
    await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('稀疏与长文本 × 浅深 × 100/200%', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final boundary = GlobalKey();
    final problems = <String>[];
    var saved = 0;

    for (final scene in markers.keys) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 2.0]) {
          final label =
              '$scene-${brightness.name}-${scale == 1 ? '100' : '200'}';
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          try {
            final appearance = AppearanceController(
              _Appearance(brightness == Brightness.dark ? 'dark' : 'light'),
            );
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
                  key: ValueKey(label),
                  client: aGalleryClient(
                    vehicleName: scene == 'overview-long' ? longName : null,
                    sparseCharts: scene != 'overview-long',
                  ),
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

            switch (scene) {
              case 'drives-sparse':
                await tester.tap(find.text('行程').last);
                await tester.pumpAndSettle();
                await tester.scrollUntilVisible(
                  find.byType(TimeSeriesChart),
                  220,
                  scrollable: find.byType(Scrollable).last,
                );
              case 'charging-sparse':
                await tester.tap(find.text('充电').last);
                await tester.pumpAndSettle();
                await tester.scrollUntilVisible(
                  find.byType(StemChart),
                  220,
                  scrollable: find.byType(Scrollable).last,
                );
              default:
                break;
            }
            await tester.pumpAndSettle();

            final texts = [
              for (final text in tester.widgetList<Text>(find.byType(Text)))
                text.data ?? text.textSpan?.toPlainText() ?? '',
            ].where((line) => line.trim().isNotEmpty).toList();
            final wanted = markers[scene]!;
            bool seen(String needle) => texts.any((t) => t.contains(needle));
            final absent = wanted.must.where((n) => !seen(n)).toList();
            final leaked = wanted.mustNot.where(seen).toList();
            if (absent.isNotEmpty || leaked.isNotEmpty) {
              problems.add(
                '$label 断言不符：缺少 $absent'
                '${leaked.isEmpty ? '' : '，不应出现 $leaked'}',
              );
            }
            await saveRenderPng(
              tester,
              find.byKey(boundary),
              '$output/$label.png',
            );
            saved++;
          } catch (failure) {
            problems.add('$label 渲染失败：$failure');
            tester.takeException();
          }
        }
      }
    }

    expect(problems, isEmpty, reason: problems.join('\n'));
    expect(saved, markers.length * 4, reason: '应生成 12 张');
  }, skip: output.isEmpty);
}
