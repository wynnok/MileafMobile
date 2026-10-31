import 'collage_charging_detail_test.dart' as map_fixture;

import 'package:mileaf/src/map/map_consent.dart';
import 'package:mileaf/src/map/sketch_platform.dart';

import 'support/render_png.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'charging_expansion_test.dart'
    show detailV2, expansionResponse, seriesV2;
import 'charging_test.dart' show app, initial, jsonResponse;

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

void main() {
  setUpAll(() async {
    if (output.isEmpty) return;
    final data = ByteData.sublistView(File(fontPath).readAsBytesSync());
    for (final family in ['Roboto', 'Arial', 'sans-serif']) {
      await (FontLoader(family)..addFont(Future.value(data))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('补能账本在360宽浅深色和200%字号下实际渲染', (tester) async {
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

    for (final state in ['normal', 'empty', 'missing']) {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        for (final scale in [1.0, 2.0]) {
          final suffix =
              '$state-${brightness.name}-${scale == 1 ? '100' : '200'}';
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          final consent = MapConsentController();
          await consent.grant('路线示意');
          final client = MockClient((request) async {
            if (request.url.path.endsWith('/summary')) {
              final body =
                  jsonDecode(initial(request).body) as Map<String, dynamic>;
              (body['last_charge'] as Map<String, dynamic>)['id'] = 1;
              return jsonResponse(body);
            }
            if (request.url.path.endsWith('/charging-sessions/1')) {
              final body = detailV2();
              if (state == 'missing') {
                for (final key in [
                  'start_soc',
                  'end_soc',
                  'energy_added_kwh',
                  'energy_used_kwh',
                  'cost',
                  'duration_min',
                ]) {
                  body[key] = null;
                }
              }
              return jsonResponse(body);
            }
            if (request.url.path.endsWith('/charging-sessions/1/series')) {
              final body = seriesV2();
              if (state == 'empty') {
                body['series'] = <Object>[];
                body['points'] = 0;
              }
              return jsonResponse(body);
            }
            if (request.url.path.endsWith('/charging-sessions') &&
                request.url.queryParameters['time_basis'] == 'started_at') {
              final body = jsonDecode(
                expansionResponse(request).body,
              ) as Map<String, dynamic>;
              body['items'] = <Object>[];
              return jsonResponse(body);
            }
            final response = expansionResponse(request);
            if (state == 'empty' &&
                request.url.path.endsWith('/charging-sessions')) {
              final body = jsonDecode(response.body) as Map<String, dynamic>;
              body['items'] = <Object>[];
              body['next_cursor'] = null;
              body['matched_sessions'] = 0;
              return jsonResponse(body);
            }

            if (request.url.path.endsWith('/stats') && state != 'normal') {
              final body = jsonDecode(response.body) as Map<String, dynamic>;
              final total = body['totals'] as Map<String, dynamic>;
              if (state == 'missing') {
                total['cost'] = null;
                total['cost_known_sessions'] = 0;
                total['energy_known_sessions'] = 0;
                total['duration_known_sessions'] = 0;
                total['unit_cost_added']['value'] = null;
              } else {
                for (final key in total.keys.toList()) {
                  if (total[key] is num) total[key] = 0;
                }
                total['cost'] = null;
                total['unit_cost_added']['value'] = null;
                total['unit_cost_added']['excluded_cost_sessions'] = 0;
                body['buckets'] = [];
              }
              return jsonResponse(body);
            }
            return response;
          });
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: app(client, key: ValueKey(suffix)),
            ),
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.text('最近充电').hitTestable(), 180);
          await tester.tap(find.text('最近充电').hitTestable());
          await save('detail-$suffix');
          await tester.scrollUntilVisible(
            find.text('功率 kW').hitTestable(),
            140,
          );
          await save('curve-$suffix');
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
  }, skip: output.isEmpty);
  testWidgets('充电地点地图实际渲染与降级', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final boundary = GlobalKey();
    for (final state in ['normal', 'missing', 'tile-failure']) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 2.0]) {
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          final consent = MapConsentController();
          await consent.grant('路线示意');
          final client = MockClient((request) async {
            if (request.url.path.endsWith('/charging-sessions/1')) {
              final body = map_fixture.fixture('charging-detail');
              if (state == 'missing') {
                body['location']['lat'] = null;
                body['location']['lon'] = null;
              }
              return map_fixture.response(body);
            }
            if (request.url.path.endsWith('/charging-sessions/1/series')) {
              return map_fixture.response(
                map_fixture.fixture('charging-series'),
              );
            }
            return map_fixture.initial(request);
          });
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: map_fixture.app(
                client,
                mapConsent: consent,
                mapPlatform: const SketchPlatform(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.text('最近充电').hitTestable(), 180);
          await tester.tap(find.text('最近充电').hitTestable());
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(find.text('充电地点').hitTestable(), 240);
          await saveRenderPng(
            tester,
            find.byKey(boundary),
            '$output/map-$state-${brightness.name}-${scale == 1 ? 100 : 200}.png',
          );
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
  }, skip: output.isEmpty);
}
