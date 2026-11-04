import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'charging_cost_test.dart' show CostSite, openCostSheet;
import 'charging_detail_test.dart' show response;
import 'statistics_charging_test.dart' show statisticsChargingResponse;
import 'statistics_test.dart' show openStats;

void main() {
  testWidgets('专题地点刷新延迟失败时，补录提示部分汇总暂未更新', (tester) async {
    final delayedLocation = Completer<http.Response>();
    var wrote = false, queried = false;
    final site = CostSite();
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/cost')) {
        wrote = true;
        return site.handle(request);
      }
      if (path.endsWith('/charging-sessions/1') ||
          path.endsWith('/charging-sessions/1/series')) {
        return site.handle(request);
      }
      if (path.endsWith('/meta')) {
        final body = jsonDecode(
          statisticsChargingResponse(request).body,
        ) as Map<String, dynamic>;
        body['version'] = '0.4.0';
        return response(body);
      }
      if (path.endsWith('/charging-sessions')) {
        final body = jsonDecode(
          statisticsChargingResponse(request).body,
        ) as Map<String, dynamic>;
        body['items'] = [
          {
            ...Map<String, dynamic>.from((body['items'] as List).first as Map),
            'id': 1,
            'cost': site.cost,
            'is_active': false,
            'ended_at': '2026-03-28T09:00:00Z',
            'energy_added_kwh': 20,
            'energy_used_kwh': 22,
          },
        ];
        body['next_cursor'] = null;
        return response(body);
      }
      if (wrote &&
          path.endsWith('/charging-locations') &&
          !request.url.queryParameters.containsKey('location_id')) {
        queried = true;
        return delayedLocation.future;
      }
      return statisticsChargingResponse(request);
    });
    try {
      await openStats(
        tester,
        client,
        () => DateTime.utc(2026, 3, 30, 12),
        () => 'UTC',
        statisticsInsights: true,
      );
      await tester.scrollUntilVisible(
        find.text('补能').hitTestable(),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('补能'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('家 · 地库').hitTestable(),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('家 · 地库').hitTestable());
      await tester.pumpAndSettle();
      await openCostSheet(tester);
      await tester.enterText(find.byType(TextField).last, '1.25');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('确认补录'));
      await tester.tap(find.text('确认补录'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(queried, true);
      delayedLocation.complete(http.Response('', 503));
      await tester.pumpAndSettle();
      expect(find.textContaining('费用已补录'), findsOneWidget);
      expect(find.textContaining('部分汇总暂未更新'), findsOneWidget);
    } finally {
      if (!delayedLocation.isCompleted) {
        delayedLocation.complete(http.Response('', 503));
      }
    }
  });
}
