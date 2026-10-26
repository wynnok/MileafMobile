import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'drive_detail_test.dart' show openDetail, fixture;
import 'drives_test.dart' show jsonResponse;

void main() {
  testWidgets('行程图表提供时间与单位，并可连续前后读取真实采样和缺失值', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final series = fixture('drive-series');
      series['series'] = [
        {
          't': '2026-03-15T08:00:00Z',
          'lat': null,
          'lon': null,
          'speed_kmh': 10,
        },
        {
          't': '2026-03-15T08:01:00Z',
          'lat': null,
          'lon': null,
          'speed_kmh': null,
        },
        {
          't': '2026-03-15T09:00:00Z',
          'lat': null,
          'lon': null,
          'speed_kmh': 90,
        },
      ];
      series['points'] = 3;
      await openDetail(
        tester,
        (request) async => jsonResponse(
          jsonEncode(
            request.url.path.endsWith('/series')
                ? series
                : fixture('drive-detail'),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('sample-chart')),
        150,
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('速度图表'), findsOneWidget);
      expect(find.text('km/h'), findsWidgets);
      expect(find.textContaining('速度读数 10 km/h'), findsOneWidget);
      await tester.ensureVisible(find.text('后一个采样'));
      await tester.tap(find.text('后一个采样'));
      await tester.pump();
      expect(find.textContaining('速度读数 —（缺失）'), findsOneWidget);
      await tester.tap(find.text('后一个采样'));
      await tester.pump();
      expect(find.textContaining('速度读数 90 km/h'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
