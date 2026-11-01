import 'support/render_png.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:mileaf/main.dart';
import 'package:mileaf/src/workspace.dart';

import 'overview_visualization_test.dart';
import 'statistics_test.dart' show fixture;
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
  testWidgets('C概览正常空态缺失正式Flutter渲染', (tester) async {
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
              if (scenario == 'capability-failure') {
                return http.Response('', 503);
              }
              final meta = statisticsInsightsMeta(
                features: {'driving_coverage': true, 'driving_analysis': true},
              );
              meta['charging_experience'] = {
                'contract_version': 'charging-experience-v1',
                'fields': <String, bool>{},
              };
              return overviewResponse(meta);
            }
            if (r.url.queryParameters['kind'] == 'charging') {
              if (scenario == 'charging-failure') return http.Response('', 503);
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
            return overviewResponse(stateDriving(r.url, scenario));
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
          await save('overview-$suffix');
          // 净值口径的入口是本月块「净电耗 · 估算」tile（旧文案为「驾驶净电耗 …」）。
          const metricLabel = '净电耗 · 估算';
          await tester.scrollUntilVisible(
            find.text(metricLabel).hitTestable(),
            120,
          );
          await tester.tap(find.text(metricLabel).hitTestable());
          await tester.pumpAndSettle();
          final chartTitle = scenario == 'capability-failure'
              ? '净电耗趋势 · 估算'
              : '配对净电耗趋势 · 估算';
          await tester.scrollUntilVisible(
            find.text(chartTitle).hitTestable(),
            120,
          );
          await save('paired-$suffix');
        }
      }
    }
  }, skip: output.isEmpty);
}

Map<String, dynamic> stateDriving(Uri uri, String scenario) {
  final reference = DateTime.parse(uri.queryParameters['to']!).month == 9;
  final body = jsonDecode(
    jsonEncode(
      statisticsInsightsFixture(
        uri,
        sampleStatus: scenario == 'sparse-reference' && reference
            ? 'insufficient_data'
            : 'adequate',
      ),
    ),
  ) as Map<String, dynamic>;
  if (scenario == 'empty' || scenario == 'missing') {
    final empty = scenario == 'empty';
    for (final metrics in [body['totals'], ...body['buckets'] as List]) {
      metrics['drives'] = empty ? 0 : 5;
      metrics['distance_km'] = empty ? 0 : 20;
      metrics['energy_kwh'] = null;
      metrics['consumption_wh_km_net'] = null;
      metrics['net_consumption_paired']['value_wh_km'] = null;
      metrics['net_consumption_paired']['numerator_energy_kwh'] = null;
      metrics['net_consumption_paired']['denominator_distance_km'] = 0;
      metrics['net_consumption_paired']['eligible_drives'] = 0;
      metrics['net_consumption_paired']['excluded_drives'] = empty ? 0 : 5;
      metrics['net_consumption_paired']['status'] = empty
          ? 'no_records'
          : 'insufficient_data';
      metrics['comparison_quality']['sample_status'] = 'insufficient_data';
      metrics['comparison_quality']['eligible_drives'] = 0;
      metrics['comparison_quality']['distance_coverage'] = empty ? null : 0;
      final coverage = metrics['driving_coverage'];
      coverage['completed_drives'] = empty ? 0 : 5;
      coverage['distance_known_drives'] = empty ? 0 : 5;
      coverage['distance_known_km'] = empty ? 0 : 20;
      coverage['net_energy_known_drives'] = 0;
      coverage['net_energy_known_distance_km'] = 0;
      coverage['duration_known_drives'] = empty ? 0 : 5;
      coverage['duration_known_min'] = empty ? null : 60;
      coverage['status'] = empty ? 'no_records' : 'available';
      final pairedCoverage = metrics['net_consumption_paired']['coverage'];
      pairedCoverage['candidate_count'] = empty ? 0 : 5;
      pairedCoverage['valid_count'] = 0;
      pairedCoverage['excluded_count'] = empty ? 0 : 5;
      pairedCoverage['candidate_distance_km'] = empty ? 0 : 20;
      pairedCoverage['valid_distance_km'] = 0;
      pairedCoverage['candidate_duration_min'] = empty ? 0 : 60;
      pairedCoverage['valid_duration_min'] = 0;
      for (final key in ['distance', 'net_energy', 'duration']) {
        final item = coverage[key];
        item['candidate_count'] = empty ? 0 : 5;
        item['valid_count'] = empty || key == 'net_energy' ? 0 : 5;
        item['excluded_count'] = !empty && key == 'net_energy' ? 5 : 0;
        item['candidate_distance_km'] = empty ? 0 : 20;
        item['valid_distance_km'] = empty || key == 'net_energy' ? 0 : 20;
        item['candidate_duration_min'] = empty ? 0 : 60;
        item['valid_duration_min'] = empty || key == 'net_energy' ? 0 : 60;
      }
    }
    if (empty) body['buckets'] = <Object>[];
  }
  return body;
}
