import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/a_gallery_fixture.dart';
import 'support/c_fixture.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

const scenarios = <String>['normal', 'empty', 'missing'];

/// What each state must show once the block is scrolled into view.
const markers = <String, ({List<String> must, List<String> mustNot})>{
  'normal': (
    must: ['我的补能方式', 'AC 与 DC 接近', '55.14%', '118 kWh'],
    mustNot: ['还没有充电记录', '分类能量未记录'],
  ),
  'empty': (must: ['我的补能方式', '还没有充电记录'], mustNot: ['AC 与 DC 接近', '55.14%']),
  'missing': (must: ['我的补能方式', '分类能量未记录'], mustNot: ['AC 与 DC 接近', '118 kWh']),
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

/// 补能方式区块：3 状态 × 浅/深 × 100/200% = 12 张，滚动到区块后整屏渲染。
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

  testWidgets('补能方式 × normal/empty/missing × 浅深 × 100/200%', (tester) async {
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

    for (final scenario in scenarios) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 2.0]) {
          final suffix =
              '$scenario-${brightness.name}-${scale == 1 ? '100' : '200'}';
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          final appearance = AppearanceController(
            _Appearance(brightness == Brightness.dark ? 'dark' : 'light'),
          );
          await appearance.restore();
          try {
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: MileafApp(
                  key: ValueKey(suffix),
                  client: aGalleryClient(scenario: scenario),
                  sessionStore: MemorySessionStore()
                    ..value = jsonEncode({
                      'site': cSite,
                      'token': 'test',
                      'expires_at': '2099-01-01T00:00:00Z',
                    }),
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
            await tester.tap(find.text('充电').last);
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              find.text('我的补能方式'),
              180,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.pumpAndSettle();

            final texts = [
              for (final text in tester.widgetList<Text>(find.byType(Text)))
                text.data ?? text.textSpan?.toPlainText() ?? '',
            ].where((line) => line.trim().isNotEmpty).toList();
            bool seen(String needle) => texts.any((t) => t.contains(needle));
            final wanted = markers[scenario]!;
            final absent = wanted.must.where((n) => !seen(n)).toList();
            final leaked = wanted.mustNot.where(seen).toList();
            if (absent.isNotEmpty || leaked.isNotEmpty) {
              problems.add(
                'charging-method-$suffix 断言不符：缺少 $absent'
                '${leaked.isEmpty ? '' : '，不应出现 $leaked'}',
              );
            }
            expect(find.byType(MileafShareRing), findsOneWidget);
            await saveRenderPng(
              tester,
              find.byKey(boundary),
              '$output/charging-method-$suffix.png',
            );
            saved++;
          } catch (failure) {
            problems.add('charging-method-$suffix 渲染失败：$failure');
            tester.takeException();
          }
        }
      }
    }

    expect(saved, scenarios.length * 4, reason: '应生成 12 张');
    expect(problems, isEmpty, reason: problems.join('\n'));
  }, skip: output.isEmpty);
}
