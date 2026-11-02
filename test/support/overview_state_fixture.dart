import 'dart:convert';

import 'statistics_insights_fixture.dart';

/// Overview driving-insight fixture with real empty/missing shapes.
///
/// Moved here from the archived `overview_state_render_test.dart`
/// (2026-11-02); `overview_verification_test.dart` still drives the overview
/// page from it. `empty` means no records at all, `missing` means the records
/// exist while every net metric is unknown — never normal data relabelled.
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
