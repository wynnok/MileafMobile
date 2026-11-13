import 'dart:convert';
import 'dart:io';

import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/design/components/nav_bar.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/a_gallery_fixture.dart';
import 'support/c_fixture.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'widget_test.dart' show MemoryTrustStore;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'statistics_insights_test.dart' show comparisonClient;
import 'statistics_test.dart' show openStats, fixture;
import 'support/statistics_insights_fixture.dart';

void main() {
  testWidgets('长期索引仅导航，不预取续航与停放数据', (tester) async {
    final reads = <String>[];
    final client = MockClient((r) async {
      reads.add(r.url.toString());
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      if (r.url.path.endsWith('/meta')) {
        return http.Response(
          jsonEncode(
            statisticsInsightsMeta(
              features: {
                'driving_coverage': true,
                'range_observations': true,
                'parking_observations': true,
              },
            ),
          ),
          200,
        );
      }
      if (r.url.queryParameters['kind'] == 'charging') {
        return fixture('charging-stats');
      }
      if (r.url.path.endsWith('/stats')) {
        return http.Response(jsonEncode(statisticsInsightsFixture(r.url)), 200);
      }
      return http.Response('{}', 503);
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await tester.scrollUntilVisible(
      find.text('长期'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    final before = reads.length;
    await tester.tap(find.text('长期'));
    await tester.pumpAndSettle();
    expect(find.text('展开长期续航'), findsOneWidget);
    expect(find.text('展开停放观察'), findsOneWidget);
    expect(reads.length, before, reason: '索引不为摘要预取两个专题');
    for (final label in ['展开长期续航', '展开停放观察']) {
      expect(
        tester.getSize(find.widgetWithText(ListTile, label)).height,
        greaterThanOrEqualTo(44),
      );
    }
  });

  testWidgets('主图读值带真实参照区间和差值，摘要各行独立', (tester) async {
    await openStats(
      tester,
      comparisonClient(),
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    expect(
      find.textContaining('参照 9/1–9/28 20.0 km（差 0.0 km）'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('净电耗 187.5 Wh/km'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('净电耗 187.5 Wh/km'), findsOneWidget);
    expect(find.textContaining('已知支出'), findsWidgets);
  });
  testWidgets('全部指标保留驾驶与充电原始指标入口', (tester) async {
    await openStats(
      tester,
      comparisonClient(),
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await tester.tap(find.widgetWithText(TextButton, '全部指标'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('原始统计指标'));
    await tester.pumpAndSettle();
    expect(find.text('驾驶统计'), findsOneWidget);
    expect(find.text('充电统计'), findsOneWidget);
  });

  const output = String.fromEnvironment('MILEAF_U08_RENDER_OUTPUT');
  const font = String.fromEnvironment('MILEAF_RENDER_FONT');
  testWidgets('U08 正式 Flutter 页面矩阵与完整滚动', (tester) async {
    await loadRenderFonts(cjkFontPath: font);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final files = <String>[];
    final measurements = <Map<String, Object?>>[];
    for (final size in [
      const Size(360, 800),
      const Size(320, 568),
      const Size(390, 844),
      const Size(768, 1024),
    ]) {
      tester.view.physicalSize = size;
      for (final scenario in ['normal', 'empty', 'missing', 'legacy', 'long']) {
        if (size.width != 360 && scenario != 'normal') continue;
        for (final dark in [false, true]) {
          for (final scale
              in size.width == 360
                  ? [
                      1.0,
                      if (scenario == 'normal') ...[1.3, 1.5],
                      2.0,
                    ]
                  : [size.width == 390 ? 1.0 : 2.0]) {
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            final appearance = AppearanceController(
              _Appearance(dark ? 'dark' : 'light'),
            );
            await appearance.restore();
            final session = MemorySessionStore()
              ..value = jsonEncode({
                'site': cSite,
                'token': 'test',
                'expires_at': '2099-01-01T00:00:00Z',
              });
            final client = aGalleryClient(
              scenario: ['legacy', 'long'].contains(scenario)
                  ? 'normal'
                  : scenario,
              longFields: scenario == 'long',
              vehicleName: scenario == 'long' ? '上海至杭州通勤与周末旅行的行笺长名称车辆' : null,
            );
            final boundary = GlobalKey();
            final name =
                'u08-statistics-$scenario-${dark ? 'dark' : 'light'}-${size.width.toInt()}-${(scale * 100).round()}';
            await tester.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: MileafApp(
                  key: ValueKey(name),
                  client: MockClient((r) async {
                    if (scenario == 'legacy' && r.url.path.endsWith('/meta')) {
                      return fixture('meta');
                    }
                    final forwarded = http.Request(r.method, r.url)
                      ..headers.addAll(r.headers)
                      ..bodyBytes = r.bodyBytes;
                    return http.Response.fromStream(
                      await client.send(forwarded),
                    );
                  }),
                  sessionStore: session,
                  trustStore: MemoryTrustStore(),
                  vehiclePreferences: MemoryVehiclePreferences(),
                  appearance: appearance,
                  now: () => cNow,
                  calendar: () async => CalendarContext('Asia/Shanghai'),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('统计').last);
            await tester.pumpAndSettle();
            Future<void> save(String camera) async {
              final path = '$output/$name-$camera.png';
              await saveRenderPng(tester, find.byKey(boundary), path);
              files.add(path);
            }

            await save('top');
            if (scenario == 'normal' && size.width == 360 && scale == 1) {
              final first = tester.getRect(
                find.byKey(const ValueKey('statistics-topic-节奏')),
              );
              final second = tester.getRect(
                find.byKey(const ValueKey('statistics-topic-能耗')),
              );
              final bottom = tester.getTopLeft(find.byType(MileafNavBar)).dy;
              expect(first.bottom, lessThanOrEqualTo(bottom));
              expect(second.bottom, lessThanOrEqualTo(bottom));
              measurements.add({
                'name': name,
                'firstRowBottom': first.bottom,
                'secondCellBottom': second.bottom,
                'bodyBottom': bottom,
              });
            }
            final list = find.byType(Scrollable).last;
            var step = 0;
            while (tester.state<ScrollableState>(list).position.extentAfter >
                    0 &&
                step < 40) {
              await tester.drag(list, Offset(0, -size.height * .7));
              await tester.pumpAndSettle();
              await save('scroll${++step}');
            }
            expect(tester.state<ScrollableState>(list).position.extentAfter, 0);
            if (scenario == 'normal' && scale == 2 && size.width == 768) {
              await tester.tap(find.widgetWithText(TextButton, '全部指标'));
              await tester.pumpAndSettle();
              expect(
                tester.getSize(find.byType(ListView).last).width,
                lessThanOrEqualTo(560),
              );
              await save('all-metrics');
              await tester.tap(find.text('原始统计指标'));
              await tester.pumpAndSettle();
              expect(
                tester.getSize(find.byType(ListView).last).width,
                lessThanOrEqualTo(560),
              );
              await save('raw-metrics');
              await tester.tap(find.byType(BackButton));
              await tester.pumpAndSettle();
            }
            if (scenario == 'normal' &&
                scale == 2 &&
                (size.width == 320 || size.width == 768)) {
              for (
                var attempt = 0;
                find.text('长期').hitTestable().evaluate().isEmpty &&
                    attempt < 40;
                attempt++
              ) {
                await tester.drag(list, const Offset(0, 60));
                await tester.pumpAndSettle();
              }
              await tester.tap(find.text('长期').hitTestable());
              await tester.pumpAndSettle();
              await save('long-index');
              expect(find.text('展开长期续航'), findsOneWidget);
              expect(find.text('展开停放观察'), findsOneWidget);
              expect(
                tester.getSize(find.byType(ListView).last).width,
                lessThanOrEqualTo(560),
              );
            }
          }
        }
      }
    }
    await tester.runAsync(() async {
      await File('$output/u08-manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ')
            .convert({'files': files, 'measurements': measurements}),
      );
    });
  }, skip: output.isEmpty);
}

class _Appearance implements AppearancePreferenceStore {
  _Appearance(this.value);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? next) async => value = next;
}
