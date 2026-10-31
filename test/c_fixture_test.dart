import 'package:flutter_test/flutter_test.dart';

import 'support/c_fixture.dart';

Uri _statsUri({String to = '2026-10-26T23:59:59Z'}) => Uri.parse(
  'https://example.com/prefix/v1/vehicles/1/stats'
  '?from=2026-10-01T00:00:00Z&to=$to&tz=Asia%2FShanghai&bucket=day',
);

void main() {
  group('shared C fixture matches the confirmed C prototype numbers', () {
    test('overview/statistics driving totals and 26 daily buckets', () {
      final body = cDriving(_statsUri());
      final totals = body['totals'] as Map<String, dynamic>;
      expect(totals['distance_km'], 1198.6);
      expect(totals['drives'], 46);
      expect((totals['net_consumption_paired'] as Map)['value_wh_km'], 158);
      final buckets = (body['buckets'] as List).cast<Map<String, dynamic>>();
      expect(buckets, hasLength(26));
      final today = buckets.last;
      expect(today['distance_km'], 60.0);
      expect(today['drives'], 3);
      // Buckets sum exactly to the month total.
      final sum = buckets.fold<double>(
        0,
        (a, b) => a + (b['distance_km'] as num).toDouble(),
      );
      expect(double.parse(sum.toStringAsFixed(1)), 1198.6);
      // 22 active days (drives > 0).
      expect(buckets.where((b) => (b['drives'] as int) > 0).length, 22);
    });

    test('September reference distance yields 91.3 km gap', () {
      final body = cDriving(_statsUri(to: '2026-09-30T23:59:59Z'));
      final totals = body['totals'] as Map<String, dynamic>;
      expect(totals['distance_km'], cReferenceDistanceKm);
      expect(
        double.parse((1198.6 - cReferenceDistanceKm).toStringAsFixed(1)),
        91.3,
      );
    });

    test('charging totals 234.7 kWh / 9 / ¥186.4 with AC-DC split', () {
      final body = cCharging(_statsUri());
      final totals = body['totals'] as Map<String, dynamic>;
      expect(totals['energy_added_kwh'], 234.7);
      expect(totals['sessions'], 9);
      expect(totals['cost'], 186.4);
      expect(totals['ac_energy_kwh'], 118.0);
      expect(totals['dc_energy_kwh'], 96.0);
      expect((body['buckets'] as List), hasLength(26));
    });

    test('summary month/today and last records', () {
      final body = cSummary();
      final month = (body['period'] as Map)['month'] as Map;
      expect(month['distance_km'], 1198.6);
      expect(month['drives'], 46);
      final today = (body['period'] as Map)['today'] as Map;
      expect(today['distance_km'], 60.0);
      expect((body['last_drive'] as Map)['distance_km'], 32.9);
      expect((body['last_charge'] as Map)['energy_kwh'], 46.8);
    });

    test(
      'capability meta enables statistics-insights + charging-experience',
      () {
        final meta = cMeta();
        expect(
          (meta['statistics_insights'] as Map)['contract_version'],
          'statistics-insights-v1',
        );
        expect(
          ((meta['statistics_insights'] as Map)['features']
              as Map)['driving_coverage'],
          true,
        );
        expect(
          (meta['charging_experience'] as Map)['contract_version'],
          'charging-experience-v1',
        );
      },
    );

    test('drives list has the 32.9 km representative trip', () {
      final body = cDrives();
      final first = (body['items'] as List).first as Map;
      expect(first['distance_km'], 32.9);
      expect(first['duration_min'], 46);
    });
  });
}
