import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../charging_expansion_test.dart' show expansionResponse;
import '../statistics_conditions_test.dart' show conditionsFixture;
import '../statistics_parking_test.dart' show parkingResponse;
import '../statistics_range_test.dart' show rangeResponse;
import 'c_fixture.dart';

/// Fixture client for the A「夜航」gallery.
///
/// Three scenarios drive the 11 pages × 3 states × 2 appearances × 2 text
/// scales matrix:
///
/// * `normal`  — the recorded 2026-10-26 snapshot (see `c_fixture.dart`).
/// * `empty`   — real "no records" data: empty buckets, zero totals, empty
///               series. Never normal data relabelled as empty.
/// * `missing` — unknown fields stay `null` so the UI prints `—`; the two
///               detail pages instead receive a 503 (明细 503 / 系列 503) to
///               cover the failure-with-retry path.
///
/// Every response is contract-valid: the pages decode the published DTOs
/// before rendering, so a fixture that drifts is caught by the render run.
MockClient aGalleryClient({String scenario = 'normal'}) =>
    MockClient((request) async {
      final url = request.url;
      final path = url.path;
      final query = url.queryParameters;

      if (path.endsWith('/vehicles')) return _ok(cVehicles());
      if (path.endsWith('/meta')) return _ok(cMeta());
      if (path.endsWith('/summary')) {
        return _ok(switch (scenario) {
          'empty' => cEmptySummaryWithHistory(),
          'missing' => cMissingSummary(),
          _ => cSummary(),
        });
      }

      // 行程详情：missing 时走明细 503，整页失败态 + 重试。
      if (path.endsWith('/drives/17/series')) {
        return _ok(scenario == 'empty' ? cEmptyDriveSeries() : cDriveSeries());
      }
      if (path.endsWith('/drives/17')) {
        return switch (scenario) {
          'missing' => _fail(),
          'empty' => _ok(cHistoryDriveDetail()),
          _ => _ok(cDriveDetail()),
        };
      }

      // 充电详情：missing 时走系列 503，结果保留、曲线重试。
      if (path.endsWith('/charging-sessions/9/series')) {
        if (scenario == 'missing') return _fail();
        return _ok(scenario == 'empty' ? cEmptyChargeSeries() : cChargeSeries());
      }
      if (path.endsWith('/charging-sessions/9')) {
        return _ok(
          scenario == 'empty' ? cHistoryChargeDetail() : cChargeDetailBody(),
        );
      }

      if (path.endsWith('/charging-locations')) {
        return _ok(_locations(request, scenario));
      }

      if (path.contains('/charging-sessions')) {
        final body = jsonDecode(expansionResponse(request).body)
            as Map<String, dynamic>;
        if (scenario == 'empty') {
          body['items'] = <Object>[];
          body['next_cursor'] = null;
          return _ok(body);
        }
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
        return _ok(body);
      }

      if (path.endsWith('/driving-analysis')) {
        final view = query['view'];
        if (view == 'conditions') {
          return _ok(switch (scenario) {
            'empty' => cEmptyConditions(),
            'missing' => cMissingConditions(),
            _ => conditionsFixture(),
          });
        }
        if (view == 'calendar') return _ok(cCalendar(url));
        return _ok(switch (scenario) {
          'empty' => cEmptyUsage(),
          'missing' => cMissingUsage(),
          _ => cUsage(),
        });
      }

      if (path.endsWith('/range-observations')) {
        return _ok(
          rangeResponse(
            months: int.tryParse(query['months'] ?? '') ?? 6,
            empty: scenario == 'empty',
            missing: scenario == 'missing',
          ),
        );
      }

      if (path.endsWith('/parking-observations')) {
        return _ok(
          parkingResponse(
            url,
            empty: scenario == 'empty',
            missing: scenario == 'missing',
          ),
        );
      }

      if (path.endsWith('/stats')) {
        if (query['kind'] == 'charging') {
          return _ok(switch (scenario) {
            'empty' => cEmptyChargingV2(),
            'missing' => cMissingChargingV2(),
            _ => cChargingStatsV2(),
          });
        }
        // Any window that starts in late September is the 30-day drives period.
        final drivesWindow = (query['from'] ?? '').startsWith('2026-09-2');
        return _ok(switch (scenario) {
          'empty' => cEmptyDriving(url),
          'missing' => drivesWindow
              ? cMissingDrivesStats(url)
              : cMissingDriving(url),
          _ => drivesWindow ? cDrivesStats(url) : cDriving(url),
        });
      }

      if (path.endsWith('/drives')) {
        return _ok(switch (scenario) {
          'empty' => cEmptyDrives(),
          'missing' => cMissingDrives(),
          _ => cDrives(),
        });
      }

      return http.Response('{}', 404);
    });

http.Response _ok(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// A real failure: the page must show the error and a retry, no fake numbers.
http.Response _fail() => http.Response(
  jsonEncode({'error': 'service_unavailable'}),
  503,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _locations(http.Request request, String scenario) {
  final body =
      jsonDecode(expansionResponse(request).body) as Map<String, dynamic>;
  if (scenario == 'empty') {
    body['items'] = <Object>[];
    body['total_locations'] = 0;
    body['next_cursor'] = null;
  }
  return body;
}

// --- missing-state summaries -------------------------------------------------

/// Unknown state/battery/energy: the overview prints `—`, real period totals
/// stay whatever the server still knows.
Map<String, dynamic> cMissingSummary() {
  final body = cSummary();
  body['state'] = null;
  body['battery'] = null;
  body['charging_power_kw'] = null;
  body['odometer_km'] = null;
  body['period'] = {
    'today': {'drives': 3, 'distance_km': 60.0, 'energy_kwh': null},
    'month': {'drives': 46, 'distance_km': 1198.6, 'energy_kwh': null},
  };
  body['last_drive'] = {
    'id': 17,
    'started_at': '2026-10-26T08:05:00Z',
    'distance_km': null,
    'consumption_wh_km': null,
  };
  body['last_charge'] = {
    'id': 9,
    'started_at': '2026-10-25T22:10:00Z',
    'energy_kwh': null,
    'end_soc': null,
  };
  body['freshness'] = {'last_position_at': null, 'last_state_at': null};
  return body;
}

/// 30-day drives totals with unknown energy/consumption (not zero).
Map<String, dynamic> cMissingDrivesStats(Uri uri) {
  final body = cDrivesStats(uri);
  void degrade(Map<String, dynamic> metrics) {
    metrics['energy_kwh'] = null;
    metrics['consumption_wh_km_net'] = null;
    final paired = metrics['net_consumption_paired'];
    if (paired is Map) {
      paired['value_wh_km'] = null;
      paired['status'] = 'no_records';
    }
  }

  degrade(body['totals'] as Map<String, dynamic>);
  for (final bucket in (body['buckets'] as List).cast<Map<String, dynamic>>()) {
    degrade(bucket);
  }
  return body;
}

/// Unknown rhythm numbers: durations and percentiles stay null so the topic
/// prints `—` instead of inventing values.
Map<String, dynamic> cMissingUsage() {
  final body = cUsage();
  body['driving_duration_min'] = null;
  body['duration_p50_min'] = null;
  body['duration_p90_min'] = null;
  body['distance_p50_km'] = null;
  body['distance_p90_km'] = null;
  body['distance_per_active_day_km'] = null;
  body['mean_speed_kmh'] = null;
  body['weekday_bins'] = [
    for (final bin in (body['weekday_bins'] as List).cast<Map>())
      {...Map<String, dynamic>.from(bin), 'duration_min': null},
  ];
  return body;
}

/// No completed trips in the window: no paired samples, nothing to chart.
Map<String, dynamic> cEmptyConditions() => {
  ...conditionsFixture(),
  'status': 'no_records',
  'temperature_bins': <Object>[],
  'distance_bins': <Object>[],
};

/// Unknown paired energy for the first temperature group.
Map<String, dynamic> cMissingConditions() {
  final body = conditionsFixture();
  final bins = (body['temperature_bins'] as List).cast<Map>();
  body['temperature_bins'] = [
    for (final bin in bins)
      {
        ...Map<String, dynamic>.from(bin),
        'consumption_wh_km': null,
        'paired_energy_kwh': null,
        'paired_distance_km': null,
        'sample_status': 'insufficient_data',
      },
  ];
  return body;
}

// --- empty-state -------------------------------------------------------------

/// An empty current month whose last records predate it.
///
/// The recent rows must stay tappable, because an "empty" detail page means
/// 「无采样」rather than 「无记录」: the trip exists, its samples do not.
Map<String, dynamic> cEmptySummaryWithHistory() {
  final body = cEmptySummary();
  body['last_drive'] = {
    'id': 17,
    'started_at': '2026-09-30T08:05:00Z',
    'distance_km': 32.9,
    'consumption_wh_km': 154,
  };
  body['last_charge'] = {
    'id': 9,
    'started_at': '2026-09-29T22:10:00Z',
    'energy_kwh': 46.8,
    'end_soc': 82,
  };
  return body;
}

Map<String, dynamic> cHistoryDriveDetail() {
  final body = cDriveDetail();
  body['started_at'] = '2026-09-30T08:05:00Z';
  body['ended_at'] = '2026-09-30T08:51:00Z';
  return body;
}

Map<String, dynamic> cHistoryChargeDetail() {
  final body = cChargeDetailBody();
  body['started_at'] = '2026-09-29T22:10:00Z';
  body['ended_at'] = '2026-09-29T22:44:00Z';
  return body;
}

Map<String, dynamic> cEmptyDrives() => {
  ...cDrives(),
  'items': <Object>[],
  'next_cursor': null,
};

/// Recorded trips whose distance/energy/consumption are unknown.
Map<String, dynamic> cMissingDrives() {
  final body = cDrives();
  body['items'] = [
    for (final item in (body['items'] as List).cast<Map>())
      {
        ...Map<String, dynamic>.from(item),
        'distance_km': null,
        'duration_min': null,
        'energy_kwh': null,
        'consumption_wh_km': null,
      },
  ];
  return body;
}

/// A detail record that exists but has no sampling points.
Map<String, dynamic> cEmptyDriveSeries() => {
  'drive_id': 17,
  'resolution': 'empty',
  'points': 0,
  'series': <Object>[],
};

Map<String, dynamic> cEmptyChargeSeries() => {
  'session_id': 9,
  'resolution': 'empty',
  'points': 0,
  'series': <Object>[],
};
