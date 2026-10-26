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

import 'charging_test.dart' show MemoryCurrency;
import 'full_flow_test.dart' show sample, response;
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

// Opt-in actual Flutter rendering at the same App/HTTP boundary as behavior
// tests. Output and font are explicit local paths; no device or API is used.
const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

Map<String, dynamic> fixture(String name) =>
    sample(name) as Map<String, dynamic>;

Map<String, dynamic> stats(bool charging) {
  final body = fixture(charging ? 'charging-stats' : 'driving-stats');
  final template = (body['buckets'] as List).first as Map<String, dynamic>;
  const distance = [42, 0, 68, 91, 54, 23, 0, 71, 46, 82, 38, 0, 61, 75, 44];
  body['buckets'] = [
    for (var day = 1; day <= 15; day++)
      {
        ...template,
        'bucket_start': DateTime.utc(2026, 3, day - 1, 16).toIso8601String(),
        if (!charging) ...{
          'distance_km': distance[day - 1],
          'drives': distance[day - 1] == 0 ? 0 : 2,
          'energy_kwh': day == 8 ? null : distance[day - 1] * .148,
          'consumption_wh_km_net': day == 7
              ? null
              : day == 11
              ? -12
              : 140 + day,
          'consumption_wh_km_gross': day == 7 ? null : 174 + day,
          'speed_max_kmh': distance[day - 1] == 0 ? null : 80 + day,
        } else ...{
          'sessions': day % 3 == 0 ? 1 : 0,
          'energy_added_kwh': day % 3 == 0 ? 12 + day : 0,
          'cost': day == 6
              ? null
              : day % 3 == 0
              ? 7.2 + day
              : 0,
          'cost_per_kwh': day % 3 != 0 || day == 6 ? null : .6 + day / 100,
          'ac_energy_kwh': day % 6 == 0 ? 12 + day : 0,
          'dc_energy_kwh': day % 6 == 3 ? 12 + day : 0,
          'dc_energy_share': day % 3 == 0 ? (day % 6 == 0 ? 0.0 : 1.0) : null,
        },
      },
  ];
  return body;
}

Map<String, dynamic> detail(bool charging) {
  final body = fixture(charging ? 'charging-detail' : 'drive-detail');
  if (charging) {
    body['location']['display_name'] = '云栖中心充电站';
  } else {
    body['start']['display_name'] = '松岚小区';
    body['end']['display_name'] = '云栖中心';
  }
  return body;
}

Map<String, dynamic> series(bool charging) {
  final body = fixture(charging ? 'charging-series' : 'drive-series');
  final template = (body['series'] as List).first as Map<String, dynamic>;
  const speed = [
    0,
    17,
    31,
    48,
    44,
    63,
    79,
    82,
    65,
    59,
    75,
    91,
    82,
    64,
    46,
    39,
    54,
    48,
    30,
    21,
    0,
  ];
  const power = [
    0,
    36,
    62,
    83,
    91,
    94,
    92,
    89,
    82,
    75,
    68,
    60,
    51,
    44,
    36,
    29,
    24,
    20,
    16,
    12,
    8,
  ];
  body['series'] = [
    for (var i = 0; i < speed.length; i++)
      {
        ...template,
        't': DateTime.utc(2026, 3, 15, 8, i * 2).toIso8601String(),
        if (charging) ...{'power': power[i], 'soc': 24 + i * 2},
        if (!charging) ...{
          'speed_kmh': speed[i],
          'battery_level': i == 8 ? null : 82 - i ~/ 2,
          'elevation_m': i == 12 ? null : 8 + i % 5 * 3,
        },
      },
  ];
  body['points'] = speed.length;
  return body;
}

void main() {
  setUpAll(() async {
    if (output.isEmpty) return;
    if (fontPath.isEmpty) {
      throw StateError(
        'Provide an existing local CJK font via MILEAF_RENDER_FONT',
      );
    }
    final data = ByteData.sublistView(File(fontPath).readAsBytesSync());
    for (final family in ['Roboto', 'Arial', 'sans-serif']) {
      await (FontLoader(family)..addFont(Future.value(data))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('A方案完整App七类页面的实际浅深色和大字体渲染', (tester) async {
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
      expect(render.size, const Size(360, 800));
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$output/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final scale in [1.0, 2.0]) {
        final suffix = '${brightness.name}-${scale == 1 ? '100' : '200'}';
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        final store = MemorySessionStore()
          ..value = jsonEncode({
            'site': 'https://example.com/prefix',
            'token': 'synthetic-test-token',
            'expires_at': '2099-01-01T00:00:00Z',
          });
        final client = MockClient((r) async {
          final path = r.url.path.replaceFirst('/prefix/v1/', '');
          if (path == 'vehicles') return response(sample('vehicles'));
          if (path == 'meta') return response(sample('meta'));
          if (path.endsWith('/summary')) {
            final body = fixture('summary');
            body['last_drive']['id'] = 1;
            body['last_charge']['id'] = 1;
            return response(body);
          }
          if (path.endsWith('/stats')) {
            return response(stats(r.url.queryParameters['kind'] == 'charging'));
          }
          if (path == 'vehicles/1/drives') {
            return response({
              'items': [detail(false)],
              'next_cursor': null,
            });
          }
          if (path == 'vehicles/1/charging-sessions') {
            return response({
              'items': [detail(true)],
              'next_cursor': null,
            });
          }
          if (path == 'drives/1') return response(detail(false));
          if (path == 'drives/1/series') return response(series(false));
          if (path == 'charging-sessions/1') return response(detail(true));
          if (path == 'charging-sessions/1/series') {
            return response(series(true));
          }
          throw StateError('Unexpected synthetic render route');
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
              currencyPreferences: MemoryCurrency(),
              now: () => DateTime.utc(2026, 3, 15, 12),
              calendar: () async => CalendarContext('Asia/Shanghai'),
            ),
          ),
        );
        await save('overview-$suffix');
        await tester.tap(find.text('行程').last);
        await save('drives-$suffix');
        await tester.ensureVisible(find.byKey(const ValueKey('drive-1')));
        await tester.tap(find.byKey(const ValueKey('drive-1')));
        await save('drive-$suffix');
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('充电').last);
        await save('charges-$suffix');
        await tester.scrollUntilVisible(find.text('充电 #1 · 查看详情'), 180);
        await tester.tap(find.text('充电 #1 · 查看详情'));
        await save('charge-$suffix');
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('统计').last);
        await save('driving-$suffix');
        await tester.tap(find.text('充电统计'));
        await save('charging-$suffix');
        await tester.pumpWidget(const SizedBox());
      }
    }
  }, skip: output.isEmpty);
}
