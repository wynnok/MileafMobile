import 'support/render_png.dart';

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'statistics_range_test.dart' as ranges;
import 'statistics_parking_test.dart' as parking;
import 'statistics_conditions_test.dart' as conditions;

import 'package:flutter/material.dart';
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
  testWidgets('能耗专题正常空缺失的正式Flutter渲染', (tester) async {
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

    for (final scenario in ['normal', 'empty', 'missing']) {
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
                final data = conditions.conditionsFixture();
                if (scenario == 'empty') {
                  data['status'] = 'no_records';
                  data['temperature_bins'] = [];
                } else if (scenario == 'missing') {
                  for (final bin in data['temperature_bins'] as List) {
                    bin['consumption_wh_km'] = null;
                    bin['paired_energy_kwh'] = null;
                    bin['sample_status'] = 'insufficient_data';
                  }
                }
                return overviewResponse(data);
              }
              return overviewResponse(
                scenario == 'empty'
                    ? {
                        ...usageFixture(),
                        'status': 'no_records',
                        'active_days': 0,
                      }
                    : scenario == 'missing'
                    ? {
                        ...usageFixture(),
                        'active_days': null,
                        'driving_duration_min': null,
                        'distance_per_active_day_km': null,
                        'distance_p50_km': null,
                        'distance_p90_km': null,
                        'duration_p50_min': null,
                        'duration_p90_min': null,
                        'mean_speed_kmh': null,
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
            final data = jsonDecode(
              jsonEncode(statisticsInsightsFixture(r.url)),
            ) as Map<String, dynamic>;
            if (scenario == 'empty') {
              data['buckets'] = [];
              final totals = data['totals'] as Map;
              totals['drives'] = 0;
              totals['distance_km'] = 0;
              totals['energy_kwh'] = null;
              totals['consumption_wh_km_net'] = null;
              (totals['net_consumption_paired'] as Map)['value_wh_km'] = null;
              (totals['comparison_quality'] as Map)['sample_status'] =
                  'insufficient';
            } else if (scenario == 'missing') {
              for (final totals in [
                data['totals'],
                ...(data['buckets'] as List),
              ]) {
                totals['energy_kwh'] = null;
                totals['consumption_wh_km_net'] = null;
                totals['net_consumption_paired']['value_wh_km'] = null;
                totals['comparison_quality']['sample_status'] = 'insufficient';
              }
            }
            return overviewResponse(data);
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
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.widgetWithText(TextButton, '能耗').hitTestable(),
            160,
          );
          await tester.tap(find.widgetWithText(TextButton, '能耗'));
          await save('conditions-$suffix');
          if (scenario == 'normal') {
            await tester.scrollUntilVisible(
              find.bySemanticsLabel('温度分类点图，横向拖动选择温度组'),
              150,
            );
            await save('conditions-distribution-$suffix');
            await tester.scrollUntilVisible(
              find.text('查看该温度组行程').hitTestable(),
              150,
            );
            await save('conditions-evidence-$suffix');
            await tester.scrollUntilVisible(
              find.text('短途、中途与长途').hitTestable(),
              150,
            );
            await save('conditions-distance-$suffix');
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
  }, skip: output.isEmpty);
}
