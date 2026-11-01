import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mileaf/src/design/components/charts.dart';

import 'charging_test.dart' show app, jsonResponse;
import 'charging_expansion_test.dart' show chargingStatsV2, expansionResponse;

void main() {
  testWidgets('A 账本首屏为费用 hero、三读数与每日补能', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(MockClient((r) async => expansionResponse(r))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    expect(find.text('已知充电费用'), findsOneWidget);
    expect(find.text('费用覆盖'), findsOneWidget);
    expect(find.textContaining('费用有记录 2 / 8 次'), findsOneWidget);
    expect(find.text('补入电池'), findsOneWidget);
    expect(find.text('充电次数'), findsOneWidget);
    expect(find.text('记录时长'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('已知充电费用')).dy,
      lessThan(tester.getTopLeft(find.text('补入电池')).dy),
    );
    expect(
      tester.getTopLeft(find.text('补入电池')).dy,
      lessThan(tester.getTopLeft(find.text('每日补能')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('A 空期间不画全零补能图', (tester) async {
    await tester.pumpWidget(
      app(
        MockClient((request) async {
          if (request.url.path.endsWith('/stats') &&
              request.url.queryParameters['kind'] == 'charging') {
            final body = chargingStatsV2();
            body['buckets'] = [];
            final totals = body['totals'] as Map<String, dynamic>;
            totals.addAll({
              'sessions': 0,
              'energy_added_kwh': 0,
              'cost': null,
              'cost_known_sessions': 0,
              'cost_known_energy_kwh': 0,
              'energy_known_sessions': 0,
              'duration_min_total': 0,
              'duration_known_sessions': 0,
              'unit_cost_added': {
                'value': null,
                'numerator_cost': 0,
                'denominator_kwh': 0,
                'eligible_sessions': 0,
                'excluded_cost_sessions': 0,
              },
            });
            return jsonResponse(body);
          }
          return expansionResponse(request);
        }),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    expect(find.text('每日补能'), findsOneWidget);
    expect(find.text('这段时间还没有充电记录'), findsOneWidget);
    expect(find.byType(StemChart), findsNothing);
    expect(find.textContaining('费用有记录 0 / 0'), findsOneWidget);
  });

  testWidgets('A 费用缺少币种时不默认人民币', (tester) async {
    await tester.pumpWidget(app(MockClient((r) async => expansionResponse(r))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    expect(find.textContaining('¥'), findsNothing);
    expect(find.textContaining('币种未记录'), findsWidgets);
  });

  testWidgets('A 200% 三读数与构成不溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(app(MockClient((r) async => expansionResponse(r))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('补入电池'), 300);
    expect(find.text('补入电池'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('记录时长'), 300);
    expect(find.text('记录时长'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
