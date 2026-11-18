import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:http/testing.dart';

import 'charging_test.dart' show app;
import 'charging_expansion_test.dart' show expansionResponse;

void main() {
  testWidgets('充电账本优先显示费用覆盖，再给入电与时长及每日证据', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(MockClient((r) async => expansionResponse(r))));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(MileafNavBar), matching: find.text('充电')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('次有费用'), findsOneWidget);
    // 记录行增高后账目卡与趋势卡不再同时留在惰性视口里：覆盖句在页顶断言，
    // 往返滚动后只查每日证据（R10：布局变化的断言调整）。
    expect(find.textContaining('8 次中 2 次有费用'), findsOneWidget);
    final dailyTop = tester.getTopLeft(find.text('每日充电')).dy;
    expect(tester.getTopLeft(find.text('已记录费用')).dy, lessThan(dailyTop));
    await tester.scrollUntilVisible(find.text('充入电量'), 160);
    expect(find.text('充入电量'), findsOneWidget);
    // P03 三格：充电次数并入覆盖句，第三格是充入均价。
    expect(find.text('充入均价'), findsOneWidget);
    expect(find.text('充电时长'), findsOneWidget);
    // User-approved U06 order puts secondary totals after recent records.
    await tester.scrollUntilVisible(find.text('每日充电'), -160);
    final viewport = tester.getRect(find.byType(RefreshIndicator).first);
    final daily = tester.getRect(find.text('每日充电'));
    expect(daily.bottom, lessThanOrEqualTo(viewport.bottom));
    final chart = find.byKey(const Key('charging-briefing-chart'));
    expect(tester.getRect(chart).top, greaterThan(daily.bottom));
    expect(tester.takeException(), isNull);
  });
}
