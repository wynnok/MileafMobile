import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/design/components/battery_arc.dart';
import 'package:mileaf/src/workspace.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/c_fixture.dart';
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'support/test_trust_store.dart' show MemoryTrustStore;

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

http.Response _ok(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _clone(Object value) =>
    jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

/// A sample client with a visibly distinct same-progress reference so the
/// dashed series is readable in the hand-off renders.
MockClient sampleClient(String scenario) => MockClient((request) async {
  final path = request.url.path;
  if (path.endsWith('/vehicles')) return _ok(cVehicles());
  if (path.endsWith('/meta')) return _ok(cMeta());
  if (path.endsWith('/summary')) {
    final body = scenario == 'empty' ? cEmptySummary() : cSummary();
    if (scenario == 'empty') {
      body['freshness'] = {
        'last_position_at': '2026-10-26T10:38:00Z',
        'last_state_at': '2026-10-26T09:00:00Z',
      };
      body['state']['since'] = '2026-10-26T10:38:00Z';
    }
    if (scenario == 'missing') {
      body['battery'] = {
        ...(body['battery'] as Map),
        'range_km': null,
        'level': null,
      };
      final period = body['period'] as Map;
      body['period'] = {
        ...period,
        'today': {...(period['today'] as Map), 'energy_kwh': null},
      };
      body['last_drive'] = null;
    }
    return _ok(body);
  }
  if (path.endsWith('/stats')) {
    final charging = request.url.queryParameters['kind'] == 'charging';
    if (charging) {
      return _ok(switch (scenario) {
        'empty' => cEmptyChargingV2(),
        'missing' => cMissingChargingV2(),
        _ => cChargingStatsV2(),
      });
    }
    if (scenario == 'empty') return _ok(cEmptyDriving(request.url));
    if (scenario == 'missing') return _ok(cMissingDriving(request.url));
    final body = _clone(cDriving(request.url));
    final to = DateTime.parse(request.url.queryParameters['to']!);
    if (to.month == 9) {
      for (final bucket in (body['buckets'] as List).cast<Map>()) {
        bucket['distance_km'] = (bucket['distance_km'] as num).toDouble() * .92;
      }
      final totals = body['totals'] as Map;
      totals['distance_km'] = (totals['distance_km'] as num).toDouble() * .92;
      totals['consumption_wh_km_net'] = 166;
    }
    return _ok(body);
  }
  return http.Response('{}', 404);
});

class _Appearance implements AppearancePreferenceStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? next) async => value = next;
}

/// VA04 hand-off sample: overview × 360×800 × light/dark × 100/200% ×
/// normal/empty/missing. Opt-in through MILEAF_RENDER_OUTPUT.
void main() {
  setUpAll(() async {
    if (output.isEmpty) return;
    await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('A 概览 12 张样张', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final boundary = GlobalKey();
    for (final scenario in ['normal', 'empty', 'missing']) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 2.0]) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          final store = MemorySessionStore()
            ..value = jsonEncode({
              'site': cSite,
              'token': 'test',
              'expires_at': '2099-01-01T00:00:00Z',
            });
          final appearanceStore = _Appearance()
            ..value = brightness == Brightness.dark ? 'dark' : 'light';
          final appearance = AppearanceController(appearanceStore);
          await appearance.restore();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MileafApp(
                key: ValueKey('$scenario-${brightness.name}-$scale'),
                client: sampleClient(scenario),
                sessionStore: store,
                trustStore: MemoryTrustStore(),
                vehiclePreferences: MemoryVehiclePreferences(),
                appearance: appearance,
                now: () => cNow,
                calendar: () async => CalendarContext('Asia/Shanghai'),
              ),
            ),
          );
          await saveRenderPng(
            tester,
            find.byKey(boundary),
            '$output/overview-$scenario-${brightness.name}-'
            '${scale == 1 ? '100' : '200'}.png',
          );
          expect(
            find.byType(BatteryArc),
            findsOneWidget,
            reason: '$scenario-${brightness.name}-$scale',
          );
          if (scenario == 'normal') {
            expect(find.textContaining('320'), findsWidgets);
            expect(find.textContaining('1,198.6'), findsWidgets);
            expect(find.text('每日里程'), findsOneWidget);
          } else if (scenario == 'empty') {
            expect(find.text('这段时间没有行程'), findsOneWidget);
          } else {
            expect(find.textContaining('—'), findsWidgets);
          }
          expect(tester.takeException(), isNull);
        }
      }
    }
  }, skip: output.isEmpty);
}
