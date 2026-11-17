import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'statistics_test.dart' show openStats;
import 'statistics_insights_test.dart' show comparisonClient;

void main() {
  testWidgets('A 长期专题不硬编码 316，未加载时显示破折号与查看专题', (tester) async {
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
    // P06 专题卡：2×2 卡片，长期无值时只写「续航与停放」状态与「查看专题」。
    expect(find.byKey(const ValueKey('statistics-topic-长期')), findsOneWidget);
    expect(find.text('续航与停放'), findsOneWidget);
    expect(find.text('— km'), findsNothing);
    expect(find.text('查看专题'), findsOneWidget);
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
    // P06 结论卡标签：期间名 + DF3 区间。
    final label = find.text('本月 10月1日\u201328日');
    expect(tester.widget<Text>(label).maxLines, isNull);
    expect(tester.widget<Text>(label).overflow, isNull);
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
