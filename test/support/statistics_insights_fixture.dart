import 'dart:convert';
import 'dart:io';

// Synthetic HTTP response using the published statistics-insights-v1 contract.
Map<String, dynamic> statisticsInsightsFixture(
  Uri uri, {
  num consumption = 187.5,
  num energy = 3.75,
  String sampleStatus = 'adequate',
  String rangeKind = 'rated',
  int version = 1,
}) {
  final query = uri.queryParameters;
  final coverage = <String, dynamic>{
    'candidate_count': 5,
    'valid_count': 5,
    'excluded_count': 0,
    'candidate_distance_km': 20,
    'valid_distance_km': 20,
    'candidate_duration_min': 60,
    'valid_duration_min': 60,
    'unknown_distance_count': 0,
    'unknown_duration_count': 0,
    'excluded_by_reason': <String, int>{},
  };
  final metrics = <String, dynamic>{
    'drives': 5,
    'distance_km': 20,
    'energy_kwh': energy,
    'consumption_wh_km_net': consumption,
    'consumption_wh_km_gross': null,
    'speed_max_kmh': 80,
    'driving_coverage': {
      'status': 'available',
      'completed_drives': 5,
      'ongoing_drives': 0,
      'distance_known_drives': 5,
      'distance_known_km': 20,
      'net_energy_known_drives': 5,
      'net_energy_known_distance_km': 20,
      'duration_known_drives': 5,
      'duration_known_min': 60,
      'distance': coverage,
      'net_energy': coverage,
      'duration': coverage,
      'excluded_by_reason': <String, Map<String, int>>{},
    },
    'net_consumption_paired': {
      'status': 'available',
      'value_wh_km': consumption,
      'numerator_energy_kwh': energy,
      'denominator_distance_km': 20,
      'eligible_drives': 5,
      'excluded_drives': 0,
      'coverage': coverage,
      'method': 'paired-net-consumption-v1',
      'version': version,
    },
    'comparison_quality': {
      'status': 'available',
      'sample_status': sampleStatus,
      'distance_coverage': 1,
      'eligible_drives': 5,
      'unknown_distance_drives': 0,
      'invalid_distance_drives': 0,
      'method': 'paired-comparison-quality-v1',
      'version': version,
    },
  };
  return {
    'totals': metrics,
    'buckets': [
      {'bucket_start': query['from'], ...metrics},
    ],
    'range_kind': rangeKind,
    'as_of': '2026-10-28T11:00:00Z',
    'query': {
      'vehicle_id': 1,
      'from': query['from'],
      'to': query['to'],
      'tz': query['tz'],
      'bucket': query['bucket'],
      'filters': <String, String>{},
      'time_basis': 'started_at',
    },
  };
}

/// Preserve the published base metadata while enabling only this scenario's features.
Map<String, dynamic> statisticsInsightsMeta({
  Map<String, bool> features = const {'driving_coverage': true},
}) {
  final body = jsonDecode(
    File('test/fixtures/meta.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  body['version'] = '0.3.0';
  body['statistics_insights'] = {
    'contract_version': 'statistics-insights-v1',
    'minimum_server_version': '0.3.0',
    'tested_schema_version': 20260808090000,
    'features': {
      'driving_coverage': false,
      'driving_analysis': false,
      'range_observations': false,
      'parking_observations': false,
      ...features,
    },
  };
  return body;
}
