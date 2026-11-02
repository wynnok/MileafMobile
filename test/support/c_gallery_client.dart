import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../charging_expansion_test.dart' show expansionResponse;
import 'c_fixture.dart';

/// Fixture client for the recorded C「数据拼贴」snapshot.
///
/// Kept as a shared fixture after the C render harness was archived
/// (2026-11-02): `a_overview_test.dart` and `overview_a_regression_test.dart`
/// still drive the overview page from these responses.
http.Response _ok(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'max-age=30',
  },
);

MockClient cGalleryClient({String scenario = 'normal'}) =>
    MockClient((request) async {
      final url = request.url;
      if (url.path.endsWith('/vehicles')) return _ok(cVehicles());
      if (url.path.endsWith('/summary')) {
        return _ok(scenario == 'empty' ? cEmptySummary() : cSummary());
      }
      if (url.path.endsWith('/meta')) return _ok(cMeta());
      if (url.path.endsWith('/drives')) return _ok(cDrives());
      if (url.path.endsWith('/drives/17/series')) return _ok(cDriveSeries());
      if (url.path.endsWith('/drives/17')) return _ok(cDriveDetail());
      if (url.path.endsWith('/charging-sessions/9/series')) {
        return _ok(cChargeSeries());
      }
      if (url.path.endsWith('/charging-sessions/9')) {
        return _ok(cChargeDetailBody());
      }
      if (url.path.contains('/charging-sessions') ||
          url.path.contains('/charging-locations') ||
          (url.path.endsWith('/stats') &&
              url.queryParameters['kind'] == 'charging')) {
        if (url.path.endsWith('/stats')) {
          return _ok(switch (scenario) {
            'empty' => cEmptyChargingV2(),
            'missing' => cMissingChargingV2(),
            _ => cChargingStatsV2(),
          });
        }
        final expanded = expansionResponse(request);
        if (url.path.endsWith('/charging-sessions')) {
          final body = jsonDecode(expanded.body) as Map<String, dynamic>;
          final items = [
            for (final item in (body['items'] as List).cast<Map>())
              if (item['is_active'] != true) Map<String, dynamic>.from(item),
          ];
          if (items.isNotEmpty) {
            items.first.addAll({
              'energy_added_kwh': cChargeDetail.energyKwh,
              'start_soc': cChargeDetail.startSoc,
              'end_soc': cChargeDetail.endSoc,
              'cost': cChargeDetail.cost,
              'duration_min': cChargeDetail.durationMin,
              'is_dc': true,
            });
          }
          body['items'] = items;
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return expanded;
      }
      if (url.path.endsWith('/driving-analysis')) {
        return _ok(
          url.queryParameters['view'] == 'calendar'
              ? cCalendar(url)
              : (scenario == 'empty' ? cEmptyUsage() : cUsage()),
        );
      }
      if (url.path.endsWith('/stats')) {
        final charging = url.queryParameters['kind'] == 'charging';
        if (scenario == 'empty') {
          return _ok(charging ? cEmptyCharging(url) : cEmptyDriving(url));
        }
        if (scenario == 'missing' && !charging) {
          return _ok(cMissingDriving(url));
        }
        if (charging) return _ok(cChargingStatsV2());
        final from = url.queryParameters['from'] ?? '';
        return _ok(
          from.startsWith('2026-09-2') ? cDrivesStats(url) : cDriving(url),
        );
      }
      return http.Response('{}', 404);
    });
