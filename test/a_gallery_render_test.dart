import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/a_gallery_fixture.dart';
import 'support/c_fixture.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

/// The 11 pages of the VA12 gallery.
const pages = <String>[
  'overview',
  'drives',
  'charging',
  'statistics',
  'drive-detail',
  'charge-detail',
  'topic-rhythm',
  'topic-energy',
  'topic-charging',
  'topic-range',
  'topic-parking',
];

const scenarios = <String>['normal', 'empty', 'missing'];

/// One required on-screen marker per page and state.
///
/// `normal` asserts a main number or chart heading, `empty` asserts the
/// no-records/sample copy (or the real zero), `missing` asserts that unknown
/// values print `—` instead of a fabricated number.
const markers = <String, Map<String, List<String>>>{
  'overview': {
    'normal': ['本月 · 驾驶里程'],
    'empty': ['本月 · 驾驶里程', '这段时间还没有行程'],
    'missing': ['—'],
  },
  'drives': {
    'normal': ['出行节奏'],
    'empty': ['还没有行程', '暂无行程', '出行节奏'],
    'missing': ['—'],
  },
  'charging': {
    'normal': ['已知充电费用'],
    'empty': ['费用有记录 0 / 0 次', '还没有充电记录'],
    'missing': ['—'],
  },
  'statistics': {
    'normal': ['里程走势'],
    'empty': ['里程走势', '—'],
    'missing': ['—'],
  },
  'drive-detail': {
    'normal': ['净电耗'],
    'empty': ['32.9', '行程电量区间'],
    'missing': ['失败', '重试'],
  },
  'charge-detail': {
    'normal': ['充电曲线', '这一次的账'],
    'empty': ['此充电没有序列采样', '充电曲线'],
    'missing': ['失败', '重试'],
  },
  'topic-rhythm': {
    'normal': ['这段时间的用车节奏'],
    'empty': ['区间内无已完成行程'],
    'missing': ['—'],
  },
  'topic-energy': {
    'normal': ['温度下的用车能耗'],
    'empty': ['区间内无已完成行程'],
    'missing': ['—'],
  },
  'topic-charging': {
    'normal': ['补能账目'],
    'empty': ['补能账目', '还没有充电记录'],
    'missing': ['—'],
  },
  'topic-range': {
    'normal': ['满电等效额定续航'],
    'empty': ['观察窗口内无充电记录'],
    'missing': ['—'],
  },
  'topic-parking': {
    'normal': ['停放SOC变化'],
    'empty': ['停放SOC变化'],
    'missing': ['分桶SOC变化缺失，不补零'],
  },
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

/// VA12 five-topic gallery: 4 tabs + 2 details + 5 topics, each rendered at
/// light/dark × 100/200% and at normal/empty/missing = 132 images.
///
/// The appearance is forced through `AppearanceController` (an in-memory
/// preference store), never through `platformBrightnessTestValue` alone, so a
/// light and a dark render can never silently share the same colours.
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

  testWidgets('A 图册：11 页 × normal/empty/missing × 浅深 × 100/200%', (
    tester,
  ) async {
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

    Future<void> pumpApp(String key, String scenario, Brightness brightness) async {
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
            key: ValueKey(key),
            client: aGalleryClient(scenario: scenario),
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

    Future<void> tab(String label) async {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    Future<void> scrollAndTap(String label, {double delta = 180}) async {
      final target = find.text(label);
      await tester.scrollUntilVisible(
        target,
        delta,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(target.first);
      await tester.pumpAndSettle();
    }

    Future<void> navigate(String page) async {
      switch (page) {
        case 'drives':
          await tab('行程');
        case 'charging':
          await tab('充电');
        case 'statistics':
          await tab('统计');
        case 'drive-detail':
          await scrollAndTap('最近行程', delta: 200);
        case 'charge-detail':
          await scrollAndTap('最近充电', delta: 200);
        case 'topic-rhythm':
          await tab('统计');
          await scrollAndTap('节奏');
        case 'topic-energy':
          await tab('统计');
          await scrollAndTap('能耗');
        case 'topic-charging':
          await tab('统计');
          await scrollAndTap('补能');
        case 'topic-range':
          await tab('统计');
          await scrollAndTap('长期');
          await scrollAndTap('展开长期续航');
        case 'topic-parking':
          await tab('统计');
          await scrollAndTap('长期');
          await scrollAndTap('展开停放观察');
      }
    }

    final problems = <String>[];
    var saved = 0;
    for (final page in pages) {
      for (final scenario in scenarios) {
        for (final brightness in Brightness.values) {
          for (final scale in [1.0, 2.0]) {
            final suffix =
                '$scenario-${brightness.name}-${scale == 1 ? '100' : '200'}';
            final label = '$page-$suffix';
            tester.platformDispatcher.platformBrightnessTestValue = brightness;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            try {
              await pumpApp(label, scenario, brightness);
              await navigate(page);
              final texts = [
                for (final text in tester.widgetList<Text>(find.byType(Text)))
                  text.data ?? text.textSpan?.toPlainText() ?? '',
              ].where((line) => line.trim().isNotEmpty).toList();
              final wanted = markers[page]![scenario]!;
              if (!wanted.any((needle) => texts.any((t) => t.contains(needle)))) {
                problems.add(
                  '$label 缺少期望文案 $wanted；实际：'
                  '${texts.take(60).join(' | ')}',
                );
              }
              await save(label);
              saved++;
            } catch (failure) {
              problems.add('$label 渲染失败：$failure');
              tester.takeException();
            }
          }
        }
      }
    }

    expect(saved, pages.length * scenarios.length * 4, reason: '应生成 132 张');
    expect(problems, isEmpty, reason: problems.join('\n'));
  }, skip: output.isEmpty);
}
