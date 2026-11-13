import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    expect(find.textContaining('费用有记录'), findsOneWidget);
    final dailyTop = tester.getTopLeft(find.text('每日补能')).dy;
    expect(tester.getTopLeft(find.text('已知充电费用')).dy, lessThan(dailyTop));
    await tester.scrollUntilVisible(find.text('补入电池'), 160);
    expect(find.text('补入电池'), findsOneWidget);
    expect(find.text('充电次数'), findsOneWidget);
    expect(find.text('记录时长'), findsOneWidget);
    // User-approved U06 order puts secondary totals after recent records.
    await tester.scrollUntilVisible(find.text('每日补能'), -160);
    final viewport = tester.getRect(find.byType(RefreshIndicator).first);
    final daily = tester.getRect(find.text('每日补能'));
    expect(daily.bottom, lessThanOrEqualTo(viewport.bottom));
    final chart = find.byKey(const Key('charging-briefing-chart'));
    expect(tester.getRect(chart).top, greaterThan(daily.bottom));
    expect(find.textContaining('费用有记录 2 / 8 次'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
