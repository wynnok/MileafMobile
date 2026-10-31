import 'dart:convert';
import 'dart:io';

/// Canonical C「数据拼贴」visual fixture.
///
/// One snapshot drives every C render/visual test: 2026-10-26 18:40 in
/// Asia/Shanghai. Values match the confirmed C prototype
/// (docs/prototypes/visual-refresh/renders/C-*.png). Do not fork these values
/// inside individual render tests.
///
/// 概览/统计: 1,198.6 km · 46 trips · 158 Wh/km · 234.7 kWh · 9 charges
///           · ¥186.4 known cost · today 60 km · 26 daily buckets
/// 行程:      1,280.6 km · 52 trips · 197.4 kWh · 154.2 Wh/km · 示例 32.9 km
/// 充电:      46.8 kWh · 18→82% · 34 min · ¥71.28
/// 节奏:      22 active days · 13h18 · 18.6 km median
const cZone = 'Asia/Shanghai';
const cSite = 'https://example.com/prefix';

/// 2026-10-26 18:40 Asia/Shanghai == 10:40Z.
final cNow = DateTime.utc(2026, 10, 26, 10, 40);

const cMonth = (distanceKm: 1198.6, drives: 46, netWhKm: 158);
const cToday = (distanceKm: 60.0, drives: 3, energyKwh: 11.25);
const cChargingTotals = (
  energyKwh: 234.7,
  sessions: 9,
  knownCost: 186.4,
  acKwh: 118.0,
  dcKwh: 96.0,
  unknownKwh: 20.7,
);
const cDrivesTotals = (
  distanceKm: 1280.6,
  drives: 52,
  energyKwh: 197.4,
  netWhKm: 154.2,
);
const cChargeDetail = (
  energyKwh: 46.8,
  startSoc: 18,
  endSoc: 82,
  durationMin: 34,
  cost: 71.28,
);
const cRhythm = (activeDays: 22, drivingMinutes: 798, medianKm: 18.6);

/// Number of daily buckets in the current calendar month (Oct 1–26 2026).
const cBucketCount = 26;

/// Sept reference distance so 1,198.6 − 1,107.3 = 91.3 km, matching C-stats.
const cReferenceDistanceKm = 1107.3;

Map<String, dynamic> _json(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync())
        as Map<String, dynamic>;

Map<String, dynamic> _copy(Object? source) =>
    jsonDecode(jsonEncode(source)) as Map<String, dynamic>;

Object cVehicles() =>
    jsonDecode(File('test/fixtures/vehicles.json').readAsStringSync());

/// Meta declaring the statistics-insights + charging-experience capabilities.
Map<String, dynamic> cMeta() {
  final meta = _json('meta');
  meta['version'] = '0.3.0';
  meta['statistics_insights'] = {
    'contract_version': 'statistics-insights-v1',
    'minimum_server_version': '0.3.0',
    'tested_schema_version': 20260808090000,
    'features': {
      'driving_coverage': true,
      'driving_analysis': true,
      'range_observations': true,
      'parking_observations': true,
    },
  };
  meta['charging_experience'] = {
    'contract_version': 'charging-experience-v1',
    'minimum_server_version': '0.2.0',
    'tested_schema_version': 20260808090000,
    'fields': <String, bool>{},
  };
  return meta;
}

/// Summary tuned to the C overview hero: 320 km rated, 68 %, charging, and a
/// month of 1,198.6 km / 46 trips with today 60 km / 3 trips.
Map<String, dynamic> cSummary() {
  final body = _json('summary');
  body['state'] = {'value': 'charging', 'since': '2026-10-26T10:38:00Z'};
  body['battery'] = {'level': 68, 'range_km': 320.0, 'range_kind': 'rated'};
  body['charging_power_kw'] = 11.0;
  body['period'] = {
    'today': {
      'drives': cToday.drives,
      'distance_km': cToday.distanceKm,
      'energy_kwh': cToday.energyKwh,
    },
    'month': {
      'drives': cMonth.drives,
      'distance_km': cMonth.distanceKm,
      'energy_kwh': cChargingTotals.energyKwh,
    },
  };
  body['last_drive'] = {
    'id': 17,
    'started_at': '2026-10-26T08:05:00Z',
    'distance_km': 32.9,
    'consumption_wh_km': 154,
  };
  body['last_charge'] = {
    'id': 9,
    'started_at': '2026-10-25T22:10:00Z',
    'energy_kwh': 46.8,
    'end_soc': 82,
  };
  body['freshness'] = {
    'last_position_at': '2026-10-26T10:40:00Z',
    'last_state_at': '2026-10-26T09:00:00Z',
  };
  return body;
}

/// Per-bucket distances/drives: 26 daily buckets, 22 active days, today 60 km
/// and 3 drives, summing exactly to the C month totals.
final List<({double distance, int drives})> _daily = () {
  const zeroDays = {3, 9, 16, 22};
  final list = List<({double distance, int drives})>.filled(cBucketCount, (
    distance: 0,
    drives: 0,
  ));
  list[25] = (distance: cToday.distanceKm, drives: cToday.drives);
  final activeOthers = [
    for (var i = 0; i < 25; i++)
      if (!zeroDays.contains(i)) i,
  ]; // 21 days
  var remaining = cMonth.distanceKm - cToday.distanceKm; // 1138.6
  for (var k = 0; k < activeOthers.length; k++) {
    final last = k == activeOthers.length - 1;
    final distance = last ? double.parse(remaining.toStringAsFixed(1)) : 54.0;
    final drives = last ? 3 : 2;
    list[activeOthers[k]] = (distance: distance, drives: drives);
    remaining = double.parse((remaining - distance).toStringAsFixed(1));
  }
  return list;
}();

Map<String, dynamic> _metrics(double distance, int drives, {num? netWhKm}) {
  final unit = netWhKm ?? cMonth.netWhKm;
  final net = distance > 0 ? unit.toDouble() : null;
  final energy = distance > 0
      ? double.parse((distance * unit / 1000).toStringAsFixed(2))
      : 0.0;
  Map<String, dynamic> coverage(int count, double km) => {
    'candidate_count': count,
    'valid_count': count,
    'excluded_count': 0,
    'candidate_distance_km': km,
    'valid_distance_km': km,
    'candidate_duration_min': count * 20,
    'valid_duration_min': count * 20,
    'unknown_distance_count': 0,
    'unknown_duration_count': 0,
    'excluded_by_reason': <String, int>{},
  };
  return {
    'drives': drives,
    'distance_km': distance,
    'energy_kwh': energy,
    'consumption_wh_km_net': net,
    'consumption_wh_km_gross': null,
    'speed_max_kmh': 96,
    'driving_coverage': {
      'status': 'available',
      'completed_drives': drives,
      'ongoing_drives': 0,
      'distance_known_drives': drives,
      'distance_known_km': distance,
      'net_energy_known_drives': drives,
      'net_energy_known_distance_km': distance,
      'duration_known_drives': drives,
      'duration_known_min': drives * 20,
      'distance': coverage(drives, distance),
      'net_energy': coverage(drives, distance),
      'duration': coverage(drives, distance),
      'excluded_by_reason': <String, Map<String, int>>{},
    },
    'net_consumption_paired': {
      'status': 'available',
      'value_wh_km': net,
      'numerator_energy_kwh': energy,
      'denominator_distance_km': distance,
      'eligible_drives': drives,
      'excluded_drives': 0,
      'coverage': coverage(drives, distance),
      'method': 'paired-net-consumption-v1',
      'version': 1,
    },
    'comparison_quality': {
      'status': 'available',
      'sample_status': 'adequate',
      'distance_coverage': 1.0,
      'eligible_drives': drives,
      'unknown_distance_drives': 0,
      'invalid_distance_drives': 0,
      'method': 'paired-comparison-quality-v1',
      'version': 1,
    },
  };
}

/// 26 daily driving buckets for the current month, or the Sept reference
/// totals when the requested window ends in September.
Map<String, dynamic> cDriving(Uri uri) {
  final to = DateTime.tryParse(uri.queryParameters['to'] ?? '') ?? cNow;
  final reference = to.month == 9;
  final from = uri.queryParameters['from'] ?? '2026-10-01T00:00:00Z';
  // Same 26 bucket starts for both periods so canCompare() accepts the
  // reference; the reference scale reproduces the C ↓/↑ 较参照 gap.
  final scale = cReferenceDistanceKm / cMonth.distanceKm;
  final buckets = <Map<String, dynamic>>[
    for (var i = 0; i < cBucketCount; i++)
      {
        'bucket_start': DateTime.utc(
          2026,
          10,
          1 + i,
          16,
        ).subtract(const Duration(days: 1)).toIso8601String(),
        ..._metrics(
          reference
              ? double.parse((_daily[i].distance * scale).toStringAsFixed(1))
              : _daily[i].distance,
          _daily[i].drives,
        ),
      },
  ];
  final totals = reference
      ? _metrics(cReferenceDistanceKm, 45)
      : _metrics(cMonth.distanceKm, cMonth.drives);
  return {
    'totals': totals,
    'buckets': buckets,
    'range_kind': 'rated',
    'as_of': '2026-10-26T10:40:00Z',
    'query': {
      'vehicle_id': 1,
      'from': from,
      'to': to.toIso8601String(),
      'tz': uri.queryParameters['tz'] ?? cZone,
      'bucket': uri.queryParameters['bucket'] ?? 'day',
      'filters': <String, String>{},
      'time_basis': 'started_at',
    },
  };
}

/// 30-day drives window totals from the C drives prototype
/// (1,280.6 km · 52 trips · 197.4 kWh · 154.2 Wh/km) with the same shape.
Map<String, dynamic> cDrivesStats(Uri uri) {
  final body = cDriving(uri);
  final scale = cDrivesTotals.distanceKm / cMonth.distanceKm;
  body['totals'] = _metrics(
    cDrivesTotals.distanceKm,
    cDrivesTotals.drives,
    netWhKm: cDrivesTotals.netWhKm,
  );
  body['buckets'] = [
    for (final bucket in (body['buckets'] as List).cast<Map<String, dynamic>>())
      {
        'bucket_start': bucket['bucket_start'],
        ..._metrics(
          double.parse(
            ((bucket['distance_km'] as num) * scale).toStringAsFixed(1),
          ),
          bucket['drives'] as int,
          netWhKm: cDrivesTotals.netWhKm,
        ),
      },
  ];
  return body;
}

/// 26 daily charging buckets summing to the C month charging totals.
Map<String, dynamic> cCharging(Uri uri) {
  final from = uri.queryParameters['from'] ?? '2026-10-01T00:00:00Z';
  final to = DateTime.tryParse(uri.queryParameters['to'] ?? '') ?? cNow;
  const dailyEnergy = 234.7 / 26;
  final buckets = <Map<String, dynamic>>[
    for (var i = 0; i < cBucketCount; i++)
      {
        'bucket_start': DateTime.utc(2026, 10, 1 + i).toIso8601String(),
        'sessions': i == 25 ? 1 : (i % 9 == 0 ? 1 : 0),
        'energy_added_kwh': double.parse(dailyEnergy.toStringAsFixed(2)),
        'cost': double.parse((dailyEnergy * 0.79).toStringAsFixed(2)),
        'cost_per_kwh': 0.79,
        'ac_energy_kwh': double.parse((dailyEnergy * 0.5).toStringAsFixed(2)),
        'dc_energy_kwh': double.parse((dailyEnergy * 0.41).toStringAsFixed(2)),
        'dc_energy_share': 0.41,
      },
  ];
  return {
    'totals': {
      'sessions': cChargingTotals.sessions,
      'energy_added_kwh': cChargingTotals.energyKwh,
      'cost': cChargingTotals.knownCost,
      'cost_per_kwh': double.parse(
        (cChargingTotals.knownCost / cChargingTotals.energyKwh).toStringAsFixed(
          3,
        ),
      ),
      'ac_energy_kwh': cChargingTotals.acKwh,
      'dc_energy_kwh': cChargingTotals.dcKwh,
      'dc_energy_share': double.parse(
        (cChargingTotals.dcKwh / cChargingTotals.energyKwh).toStringAsFixed(3),
      ),
    },
    'buckets': buckets,
    'as_of': '2026-10-26T10:40:00Z',
    'query': {
      'vehicle_id': 1,
      'from': from,
      'to': to.toIso8601String(),
      'tz': uri.queryParameters['tz'] ?? cZone,
      'bucket': uri.queryParameters['bucket'] ?? 'day',
      'filters': <String, String>{},
      'time_basis': 'started_at',
    },
  };
}

/// 52-trip drive list tuned to the C drives totals (1,280.6 km), with one
/// representative 32.9 km / 46 min drive.
Map<String, dynamic> cDrives() {
  final body = _copy(_json('drives'));
  final items = (body['items'] as List).cast<Map<String, dynamic>>();
  final first = items.first;
  first
    ..['distance_km'] = 32.9
    ..['duration_min'] = 46
    ..['started_at'] = '2026-10-26T08:05:00Z'
    ..['ended_at'] = '2026-10-26T08:51:00Z'
    ..['consumption_wh_km'] = 154
    ..['start'] = {
      'display_name': '松岚小区',
      'geofence': '家',
      'address': '松岚小区',
      'lat': 31.2304,
      'lon': 121.4737,
    }
    ..['end'] = {
      'display_name': '云栖中心',
      'geofence': '公司',
      'address': '云栖中心',
      'lat': 31.2450,
      'lon': 121.5010,
    };
  return body;
}
