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
    expect(find.text('费用覆盖'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('已知充电费用')).dy,
      lessThan(tester.getTopLeft(find.text('补入电池')).dy),
    );
    expect(
      tester.getTopLeft(find.text('补入电池')).dy,
      lessThan(tester.getTopLeft(find.text('每日补能')).dy),
    );
    expect(
      tester.getRect(find.byKey(const Key('charging-briefing-chart'))).top,
      lessThan(720),
    );
    expect(find.textContaining('费用有记录 2 / 8 次'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
