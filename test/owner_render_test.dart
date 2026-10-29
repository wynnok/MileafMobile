import 'dart:convert';
import 'dart:io';
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
  testWidgets('车主概览与0.3统计的正式Flutter渲染', (tester) async {
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

    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        final suffix = '${brightness.name}-${scale == 1 ? '100' : '200'}';
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        final client = MockClient((r) async {
          if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
          if (r.url.path.endsWith('/summary')) return fixture('summary');
          if (r.url.path.endsWith('/meta')) {
            final meta = statisticsInsightsMeta(
              features: {'driving_coverage': true, 'driving_analysis': true},
            );
            meta['charging_experience'] = {
              'contract_version': 'charging-experience-v1',
              'fields': <String, bool>{},
            };
            return overviewResponse(meta);
          }
          if (r.url.path.endsWith('/driving-analysis')) {
            return overviewResponse(usageFixture());
          }
          if (r.url.queryParameters['kind'] == 'charging') {
            final stats = chargingStatsV2();
            stats['query'] = {
              ...(stats['query'] as Map),
              ...r.url.queryParameters,
            };
            stats['as_of'] = '2026-10-28T11:00:00Z';
            for (final (index, bucket) in (stats['buckets'] as List).indexed) {
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
        await save('overview-$suffix');
        await tester.scrollUntilVisible(find.text('已知费用的覆盖'), 120);
        await save('coverage-$suffix');
        await tester.scrollUntilVisible(find.text('我的用车节奏').hitTestable(), 120);
        await save('questions-$suffix');
        await tester.tap(find.text('统计').last);
        await save('statistics-$suffix');
        if (scale == 1) {
          expect(
            tester
                .getRect(
                  find.byKey(const ValueKey('statistics-insights-chart')),
                )
                .bottom,
            lessThanOrEqualTo(734),
          );
        }
        await tester.scrollUntilVisible(
          find.text('记录驾驶时长'),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await save('metrics-$suffix');
        await tester.tap(find.widgetWithText(ChoiceChip, '节奏'));
        await save('usage-$suffix');
        await tester.pumpWidget(const SizedBox());
      }
    }
  }, skip: output.isEmpty);
}
