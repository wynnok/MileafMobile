import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'statistics_test.dart' show openStats;
import 'statistics_insights_test.dart' show comparisonClient;

void main() {
  testWidgets('A 长期章节不硬编码 316，未加载时显示破折号与进专题', (tester) async {
    await openStats(
      tester,
      comparisonClient(),
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await tester.scrollUntilVisible(
      find.text('长期'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('316'), findsNothing);
    expect(find.text('进专题查看'), findsOneWidget);
    expect(find.text('节奏'), findsOneWidget);
  });

  testWidgets('A 200% 章节单列且主图保留读数', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await openStats(
      tester,
      comparisonClient(),
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    expect(tester.widget<Text>(find.text('本月 · 2026年10月')).maxLines, isNull);
    expect(tester.widget<Text>(find.text('本月 · 2026年10月')).overflow, isNull);
    await tester.scrollUntilVisible(
      find.text('节奏'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.scrollUntilVisible(
      find.text('能耗'),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    final rhythm = tester.getTopLeft(find.text('节奏'));
    final energy = tester.getTopLeft(find.text('能耗'));
    expect(energy.dx, rhythm.dx);
    expect(energy.dy, greaterThan(rhythm.dy));
    expect(tester.takeException(), isNull);
  });
}
