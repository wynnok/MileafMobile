import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/a_gallery_fixture.dart';
import 'support/c_fixture.dart';
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const u01 = bool.fromEnvironment('MILEAF_U01');
const safeZero = bool.fromEnvironment('MILEAF_U01_SAFE_ZERO');
const longFields = bool.fromEnvironment('MILEAF_U01_LONG');
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
const markers =
    <String, Map<String, ({List<String> must, List<String> mustNot})>>{
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
        'empty': (must: ['还没有充电记录'], mustNot: ['¥186.4', '0 / 0 次']),
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
    await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('A 图册：11 页 × normal/empty/missing × 浅深 × 100/200%', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final boundary = GlobalKey();
    final images = <String>[];
    Future<void> save(String name) async {
      await saveRenderPng(tester, find.byKey(boundary), '$output/$name.png');
      images.add('$name.png');
    }

    Future<void> pumpApp(
      String key,
      String scenario,
      Brightness brightness,
    ) async {
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
            client: aGalleryClient(
              scenario: scenario,
              irregular: u01,
              longFields: longFields,
              vehicleName: longFields ? '行笺长名称车辆 · 上海至杭州通勤与周末旅行' : null,
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

    final measurements = <Map<String, Object?>>[];
    final problems = <String>[];
    var saved = 0;
    for (final camera
        in u01
            ? [const Size(360, 800), const Size(320, 568), const Size(390, 844)]
            : [const Size(360, 800)]) {
      tester.view.physicalSize = camera;
      if (u01) {
        tester.view.viewPadding = FakeViewPadding(
          top: safeZero ? 0 : 24,
          bottom: safeZero ? 0 : 24,
        );
        tester.view.padding = FakeViewPadding(
          top: safeZero ? 0 : 24,
          bottom: safeZero ? 0 : 24,
        );
      }
      for (final page
          in u01 ? ['drives', 'statistics', 'charge-detail'] : pages) {
        if (camera.width != 360 && page == 'charge-detail') continue;
        for (final scenario in scenarios) {
          for (final brightness in Brightness.values) {
            for (final scale
                in u01 && camera.width == 360
                    ? [1.0, 1.3, 1.5, 2.0]
                    : [1.0, if (!u01 || camera.width == 320) 2.0]) {
              if (u01 && scale != 1 && scale != 2 && scenario != 'normal') {
                continue;
              }
              if ((safeZero || longFields) &&
                  (camera.width != 360 ||
                      scenario != 'normal' ||
                      scale == 1.3 ||
                      scale == 1.5 ||
                      safeZero && scale != 1)) {
                continue;
              }
              if (u01 && camera.width != 360 && scenario != 'normal') continue;
              final suffix =
                  '$scenario-${brightness.name}-${scale == 1 ? '100' : '200'}';
              final label = u01
                  ? '$page-${longFields ? 'long' : scenario}-${brightness.name}-${camera.width.toInt()}-${(scale * 100).round()}${safeZero ? '-safe0' : ''}-top'
                  : '$page-$suffix';
              tester.platformDispatcher.platformBrightnessTestValue =
                  brightness;
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              try {
                await pumpApp(label, scenario, brightness);
                await navigate(page);
                final texts = [
                  for (final text in tester.widgetList<Text>(find.byType(Text)))
                    text.data ?? text.textSpan?.toPlainText() ?? '',
                ].where((line) => line.trim().isNotEmpty).toList();
                final wanted = markers[page]![scenario]!;
                bool seen(String needle) =>
                    texts.any((t) => t.contains(needle));
                final absent = wanted.must.where((n) => !seen(n)).toList();
                final leaked = wanted.mustNot.where(seen).toList();
                if ((absent.isNotEmpty && !u01) || leaked.isNotEmpty) {
                  problems.add(
                    '$label 断言不符：缺少 $absent${leaked.isEmpty ? '' : '，不应出现 $leaked'}'
                    '；实际：${texts.take(60).join(' | ')}',
                  );
                }
                if (longFields && page == 'drives' && scale == 1) {
                  final row = find.byKey(const ValueKey('drive-17'));
                  final title = tester.widget<Text>(
                    find.descendant(of: row, matching: find.byType(Text)).first,
                  );
                  expect(title.maxLines, 2, reason: 'R03 普通字号长地点最多两行');
                }
                await save(label);
                saved++;
                if (u01) {
                  final list = find.byType(ListView).last;
                  final viewport = tester.getRect(list);
                  final bars = find.byType(MileafTopBar);
                  final bodyTop = bars.evaluate().isEmpty
                      ? viewport.top
                      : tester.getRect(bars.first).bottom;
                  final entry = <String, Object?>{
                    'image': '$label.png',
                    'bodyTop': bodyTop,
                    'bodyBottom': viewport.bottom,
                    'bodyHeight': viewport.bottom - bodyTop,
                  };
                  if (scenario == 'normal' && scale == 1) {
                    final target = page == 'drives'
                        ? find.byKey(const ValueKey('drive-17'))
                        : page == 'statistics'
                        ? find.byKey(const ValueKey('statistics-topic-能耗'))
                        : find.byKey(const Key('charging-time-chart'));
                    if (target.evaluate().isNotEmpty) {
                      final rect = tester.getRect(target.first);
                      entry['targetTop'] = rect.top - bodyTop;
                      entry['targetBottom'] = rect.bottom - bodyTop;
                      entry['visibleHeight'] = (viewport.bottom - rect.top)
                          .clamp(0, rect.height);
                      if (camera.width == 360 && !longFields && !safeZero) {
                        if (page == 'statistics') {
                          expect(
                            rect.bottom,
                            lessThanOrEqualTo(viewport.bottom),
                            reason: 'P06 专题首行完整',
                          );
                        }
                        if (page == 'drives') {
                          final secondTitle = find
                              .descendant(
                                of: find.byKey(const ValueKey('drive-16')),
                                matching: find.byType(Text),
                              )
                              .first;
                          final second = tester.getRect(secondTitle);
                          final visible = (viewport.bottom - second.top).clamp(
                            0.0,
                            second.height,
                          );
                          entry['secondTitleTop'] = second.top - bodyTop;
                          entry['secondTitleBottom'] = second.bottom - bodyTop;
                          entry['secondTitleVisibleHeight'] = visible;
                          entry['secondTitleAvailableHeight'] =
                              viewport.bottom - second.top;
                          expect(
                            visible,
                            greaterThanOrEqualTo(24),
                            reason: 'P02 第二条实际正文至少24',
                          );
                        }
                        if (page == 'charge-detail') {
                          expect(
                            viewport.bottom - rect.top,
                            greaterThanOrEqualTo(128),
                            reason: 'P05 图面至少120及8标记留白',
                          );
                        }
                      }
                    }
                  }
                  measurements.add(entry);
                  {
                    final scroll = find
                        .descendant(of: list, matching: find.byType(Scrollable))
                        .first;
                    var cameraIndex = 0;
                    while (tester
                                .state<ScrollableState>(scroll)
                                .position
                                .extentAfter >
                            0 &&
                        cameraIndex < 30) {
                      await tester.drag(list, Offset(0, -viewport.height * .7));
                      await tester.pumpAndSettle();
                      texts.addAll(
                        tester
                            .widgetList<Text>(find.byType(Text))
                            .map(
                              (text) =>
                                  text.data ??
                                  text.textSpan?.toPlainText() ??
                                  '',
                            ),
                      );
                      cameraIndex++;
                      await save(
                        label.replaceAll('-top', '-scroll$cameraIndex'),
                      );
                    }
                    expect(
                      tester
                          .state<ScrollableState>(scroll)
                          .position
                          .extentAfter,
                      0,
                    );
                    expect(
                      wanted.must
                          .where(
                            (needle) => !texts.any((t) => t.contains(needle)),
                          )
                          .toList(),
                      isEmpty,
                      reason: '$label 完整滚动标记',
                    );
                  }
                }
              } catch (failure) {
                problems.add('$label 渲染失败：$failure');
                tester.takeException();
              }
            }
          }
        }
      }
    }
    if (u01) {
      await tester.runAsync(() async {
        await File(
          '$output/u01${longFields
              ? '-long'
              : safeZero
              ? '-safe0'
              : ''}-measurements.json',
        ).writeAsString(
          const JsonEncoder.withIndent('  ')
              .convert({'images': images, 'measurements': measurements}),
        );
      });
    } else {
      expect(saved, pages.length * scenarios.length * 4, reason: '应生成 132 张');
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  }, skip: output.isEmpty);
}
