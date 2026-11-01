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

/// Per page and state: strings that must all be on screen, and strings that
/// must not.
///
/// `must` proves the state actually rendered (a main number, a chart heading or
/// the no-records copy); `mustNot` proves the state is real — an empty or
/// missing render may never show the normal snapshot's numbers, and a normal
/// render may never show the empty copy.
const markers = <String, Map<String, ({List<String> must, List<String> mustNot})>>{
  'overview': {
    'normal': (must: ['本月 · 驾驶里程', '1,198.6'], mustNot: []),
    'empty': (must: ['本月 · 驾驶里程', '0.0'], mustNot: ['1,198.6']),
    'missing': (must: ['—'], mustNot: ['320']),
  },
  'drives': {
    'normal': (must: ['出行节奏', '32.9'], mustNot: ['这段时间还没有行程']),
    'empty': (must: ['这段时间还没有行程', '0.0'], mustNot: ['32.9']),
    'missing': (must: ['—'], mustNot: ['32.9']),
  },
  'charging': {
    'normal': (must: ['已知充电费用', '¥186.4'], mustNot: ['这段时间还没有充电记录']),
    'empty': (must: ['—', '费用有记录 0 / 0 次'], mustNot: ['¥186.4']),
    'missing': (must: ['—'], mustNot: ['¥186.4']),
  },
  'statistics': {
    'normal': (must: ['里程走势', '1,198.6'], mustNot: []),
    'empty': (must: ['—'], mustNot: ['1,198.6']),
    'missing': (must: ['—'], mustNot: ['158']),
  },
  'drive-detail': {
    'normal': (must: ['净电耗', '32.9'], mustNot: ['无采样数据']),
    'empty': (must: ['32.9'], mustNot: ['速度读数']),
    'missing': (must: ['重试行程明细'], mustNot: ['32.9']),
  },
  'charge-detail': {
    'normal': (must: ['充电曲线', '46.8'], mustNot: ['此充电没有序列采样']),
    'empty': (must: ['此充电没有序列采样'], mustNot: ['服务端采样 1']),
    'missing': (must: ['重试充电曲线', '46.8'], mustNot: []),
  },
  'topic-rhythm': {
    'normal': (must: ['这段时间的用车节奏', '活跃'], mustNot: ['区间内无已完成行程']),
    'empty': (must: ['区间内无已完成行程'], mustNot: ['活跃 22']),
    'missing': (must: ['—'], mustNot: []),
  },
  'topic-energy': {
    'normal': (must: ['温度下的用车能耗', '210'], mustNot: ['区间内无已完成行程']),
    'empty': (must: ['区间内无已完成行程'], mustNot: ['210']),
    'missing': (must: ['—'], mustNot: ['210']),
  },
  'topic-charging': {
    'normal': (must: ['补能账目', '¥186.4'], mustNot: ['还没有充电记录']),
    'empty': (must: ['—'], mustNot: ['¥186.4']),
    'missing': (must: ['—'], mustNot: ['¥186.4']),
  },
  'topic-range': {
    'normal': (must: ['满电等效额定续航', '432.0'], mustNot: ['观察窗口内无充电记录']),
    'empty': (must: ['观察窗口内无充电记录'], mustNot: ['432.0']),
    'missing': (must: ['—'], mustNot: ['432.0']),
  },
  'topic-parking': {
    'normal': (must: ['停放SOC变化', '-2.0'], mustNot: ['分桶SOC变化缺失，不补零']),
    'empty': (must: ['暂无有效窗口'], mustNot: ['分桶SOC变化缺失，不补零']),
    // 汇总仍保留（-2.0 pp 是真实聚合），只有分桶读数未知。
    'missing': (must: ['分桶SOC变化缺失，不补零'], mustNot: []),
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
              bool seen(String needle) => texts.any((t) => t.contains(needle));
              final absent = wanted.must.where((n) => !seen(n)).toList();
              final leaked = wanted.mustNot.where(seen).toList();
              if (absent.isNotEmpty || leaked.isNotEmpty) {
                problems.add(
                  '$label 断言不符：缺少 $absent${leaked.isEmpty ? '' : '，不应出现 $leaked'}'
                  '；实际：${texts.take(60).join(' | ')}',
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
