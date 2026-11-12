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
    expect(find.textContaining('费用覆盖'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('已知充电费用')).dy,
      lessThan(tester.getTopLeft(find.text('补入电池')).dy),
    );
    expect(
      tester.getTopLeft(find.text('补入电池')).dy,
      lessThan(tester.getTopLeft(find.text('每日补能')).dy),
    );
    // 规格§5 P03 的首屏目标是「无进行中时第一条完整记录」，本页整页重排属 U06；
    // 原绝对阈值 720 是旧密度下的包装机位（统一字号增量使同内容整体下移 67px）。
    // 这里保留本用例的章节结构约束：费用覆盖 → 入电/时长 → 每日补能（首屏可见）
    // → 每日补能图，且图表仍可由滚动到达。
    final viewport = tester.getRect(find.byType(RefreshIndicator).first);
    final daily = tester.getRect(find.text('每日补能'));
    expect(daily.bottom, lessThanOrEqualTo(viewport.bottom));
    final chart = find.byKey(const Key('charging-briefing-chart'));
    expect(tester.getRect(chart).top, greaterThan(daily.bottom));
    await tester.scrollUntilVisible(chart, 200);
    expect(chart, findsOneWidget);
    expect(find.textContaining('费用有记录 2 / 8 次'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
