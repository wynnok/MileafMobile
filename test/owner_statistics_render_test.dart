import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'statistics_range_test.dart' as ranges;
import 'statistics_parking_test.dart' as parking;
import 'statistics_conditions_test.dart' as conditions;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/workspace.dart';

import 'overview_visualization_test.dart';
import 'statistics_test.dart' show fixture;
import 'statistics_usage_test.dart' show usageFixture;
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'support/statistics_insights_fixture.dart';
import 'charging_expansion_test.dart' show chargingStatsV2;
import 'widget_test.dart' show MemoryTrustStore;

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

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
  testWidgets('统计各专题正常稀疏失败的正式Flutter渲染', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final boundary = GlobalKey();
    Future<void> save(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: name);
      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundary),
      );
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$output/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final scenario in ['normal', 'edge', 'failure']) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 2.0]) {
          final suffix =
              '$scenario-${brightness.name}-${scale == 1 ? '100' : '200'}';
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          final client = MockClient((r) async {
            if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
            if (r.url.path.endsWith('/summary')) return fixture('summary');
            if (r.url.path.endsWith('/meta')) {
              final meta = statisticsInsightsMeta(
                features: {
                  'driving_coverage': true,
                  'driving_analysis': true,
                  'range_observations': true,
                  'parking_observations': true,
                },
              );
              meta['charging_experience'] = {
                'contract_version': 'charging-experience-v1',
                'fields': <String, bool>{},
              };
              return overviewResponse(meta);
            }
            if (r.url.path.endsWith('/range-observations')) {
              return overviewResponse(
                ranges.rangeResponse(
                  months: int.parse(r.url.queryParameters['months']!),
                  sparse: scenario == 'edge',
                  missing: scenario == 'edge',
                ),
              );
            }
            if (r.url.path.endsWith('/parking-observations')) {
              return overviewResponse(
                parking.parkingResponse(r.url, empty: scenario == 'edge'),
              );
            }
            if (r.url.path.endsWith('/driving-analysis')) {
              if (scenario == 'failure' &&
                  r.url.queryParameters['view'] == 'conditions') {
                return http.Response('{}', 503);
              }
              if (r.url.queryParameters['view'] == 'conditions') {
                return overviewResponse(conditions.conditionsFixture());
              }
              return overviewResponse(
                scenario == 'edge'
                    ? {
                        ...usageFixture(),
                        'status': 'no_records',
                        'active_days': 0,
                      }
                    : usageFixture(),
              );
            }
            if (r.url.queryParameters['kind'] == 'charging') {
              final stats = chargingStatsV2();
              stats['query'] = {
                ...(stats['query'] as Map),
                ...r.url.queryParameters,
              };
              stats['as_of'] = '2026-10-28T11:00:00Z';
              for (final (index, bucket)
                  in (stats['buckets'] as List).indexed) {
                bucket['bucket_start'] = DateTime.utc(
                  2026,
                  10,
                  25 + index,
                ).toIso8601String();
              }
              return overviewResponse(stats);
            }
            return overviewResponse(statisticsInsightsFixture(r.url));
          });
          final store = MemorySessionStore()
            ..value = jsonEncode({
              'site': 'https://example.com/prefix',
              'token': 'test',
              'expires_at': '2099-01-01T00:00:00Z',
            });
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MileafApp(
                key: ValueKey(suffix),
                client: client,
                sessionStore: store,
                trustStore: MemoryTrustStore(),
                vehiclePreferences: MemoryVehiclePreferences(),
                now: () => DateTime.utc(2026, 10, 28, 11),
                calendar: () async => CalendarContext('Asia/Shanghai'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('统计').last);
          await save('overview-$suffix');
          for (final topic in ['节奏', '能耗', '补能', '长期']) {
            await tester.tap(find.widgetWithText(ChoiceChip, topic));
            await save('$topic-$suffix');
          }
          await tester.scrollUntilVisible(
            find.text('展开长期续航').hitTestable(),
            100,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.tap(find.text('展开长期续航'));
          await save('range-$suffix');
          await tester.scrollUntilVisible(
            find.text('月中位数 · P10–P90有效日波动带（km）'),
            100,
            scrollable: find.byType(Scrollable).last,
          );
          await save('range-chart-$suffix');
          await tester.tap(find.widgetWithText(ChoiceChip, '长期'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('展开停放观察').hitTestable(),
            100,
            scrollable: find.byType(Scrollable).last,
          );
          await tester.tap(find.text('展开停放观察'));
          await save('parking-$suffix');
          await tester.scrollUntilVisible(
            find.byKey(const Key('parking-trend-chart')),
            100,
            scrollable: find.byType(Scrollable).last,
          );
          await save('parking-chart-$suffix');
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
  }, skip: output.isEmpty);
}
