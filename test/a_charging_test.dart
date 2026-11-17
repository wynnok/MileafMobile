import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mileaf/src/design/components/charts.dart';
import 'package:mileaf/src/design/components/nav_bar.dart';

import 'charging_test.dart' show app, jsonResponse;
import 'charging_expansion_test.dart' show chargingStatsV2, expansionResponse;

/// AP07：概览等页面也出现「充电」字样，底栏点击按导航栏定位。
Finder navTab(String label) =>
    find.descendant(of: find.byType(MileafNavBar), matching: find.text(label));

void main() {
  testWidgets('U06 账本同底摘要、三读数与每日充电', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(MockClient((r) async => expansionResponse(r))));
    await tester.pumpAndSettle();
    await tester.tap(navTab('充电'));
    await tester.pumpAndSettle();
    expect(find.text('已记录费用'), findsOneWidget);
    expect(find.textContaining('次有费用'), findsOneWidget);
    expect(find.textContaining('8 次中 2 次有费用'), findsOneWidget);
    final dailyTop = tester.getTopLeft(find.text('每日充电')).dy;
    expect(tester.getTopLeft(find.text('已记录费用')).dy, lessThan(dailyTop));
    await tester.scrollUntilVisible(find.text('充入电量'), 160);
    expect(find.text('充入电量'), findsOneWidget);
    // P03 三格：充入电量 / 充入均价 / 充电时长（充电次数并入覆盖句）。
    expect(find.text('充入均价'), findsOneWidget);
    expect(find.text('充电时长'), findsOneWidget);
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
    await tester.tap(navTab('充电'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('每日充电'), 160);
    expect(find.text('每日充电'), findsOneWidget);
    // CP07 首次空：还没有充电记录（共享构造函数）。
    // 每日充电卡空态句（充电方式卡的首次空结论在下方，惰性构建）。
    expect(find.text('这段时间没有充电'), findsOneWidget);
    expect(find.byType(StemChart), findsNothing);
    expect(find.textContaining('0 次中 0 次有费用'), findsOneWidget);
  });

  testWidgets('A 费用缺少币种时不默认人民币', (tester) async {
    await tester.pumpWidget(app(MockClient((r) async => expansionResponse(r))));
    await tester.pumpAndSettle();
    await tester.tap(navTab('充电'));
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
    await tester.tap(navTab('充电'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('充入电量'), 300);
    expect(find.text('充入电量'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('充电时长'), 300);
    expect(find.text('充电时长'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
