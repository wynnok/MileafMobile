// A15「根页共用上下文与统计嵌入顶栏互斥」回归（R15：顶部始终只有一组有效导航）：
// 概览页尾「驾驶统计 / 充电统计」与「用车专题」下钻把统计 Tab 以嵌入专题打开，
// 页面自带导航行顶栏，共用根顶栏（大标题 + 车辆镜片 + 设置圆钮）必须互斥隐藏；
// 返回统计总览后根顶栏恢复且不与内容堆叠（此前两者同屏堆叠，红框处元素重叠）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/icons.dart';

import 'statistics_test.dart' show openStats;
import 'support/a_gallery_fixture.dart' show aGalleryClient;

/// 共用根顶栏的外壳键（MileafTopBar 根 SizedBox）。
final topBarSurface = find.byKey(const ValueKey('root-top-bar-surface'));
final vehicleCapsule = find.byKey(const ValueKey('top-bar-vehicle'));

/// 嵌入专题导航行的自绘返回图标（R32），语义化返回入口。
final backGlyph = find.byWidgetPredicate(
  (widget) => widget is MileafIcon && widget.name == MileafIconName.back,
);

/// 回到概览 Tab，向下滚动让页尾「充电统计」下钻进入树并点按。
Future<void> openChargingDrill(WidgetTester tester) async {
  await tester.tap(
    find.descendant(of: find.byType(MileafNavBar), matching: find.text('概览')),
  );
  await tester.pumpAndSettle();
  final drill = find.text('充电统计').hitTestable();
  for (var i = 0; i < 20 && drill.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
  expect(drill, findsOneWidget, reason: '概览页尾未出现充电统计下钻');
  await tester.tap(drill);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('统计总览显示共用根顶栏，嵌入补能专题后互斥隐藏', (tester) async {
    await openStats(
      tester,
      aGalleryClient(),
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    // 统计 Tab 总览：根顶栏在位。
    expect(topBarSurface, findsOneWidget);
    expect(vehicleCapsule, findsOneWidget);

    // 概览页尾「充电统计」：统计 Tab 以嵌入补能专题打开。
    await openChargingDrill(tester);

    // 嵌入专题：根顶栏（含车辆镜片与设置）互斥隐藏，导航行顶栏在位。
    expect(topBarSurface, findsNothing);
    expect(vehicleCapsule, findsNothing);
    expect(find.byTooltip('设置'), findsNothing);
    final row = find.byType(MileafNavigationRow).last;
    expect(find.descendant(of: row, matching: find.text('补能')), findsOneWidget);
    expect(
      find.descendant(of: row, matching: find.text('全部指标')),
      findsOneWidget,
    );

    // 导航行返回统计总览：根顶栏恢复，且外壳与期间行控件不相交（无堆叠）。
    await tester.tap(find.descendant(of: row, matching: backGlyph));
    await tester.pumpAndSettle();
    expect(topBarSurface, findsOneWidget);
    expect(vehicleCapsule, findsOneWidget);
    final topBarRect = tester.getRect(topBarSurface);
    final periodRect = tester.getRect(
      find.widgetWithText(StatusChip, '自定义').hitTestable(),
    );
    expect(topBarRect.inflate(2).overlaps(periodRect), isFalse);

    // 再次从概览下钻进入嵌入专题，确认互斥状态可重复进入。
    await openChargingDrill(tester);
    expect(topBarSurface, findsNothing);
    expect(vehicleCapsule, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('概览「用车专题」嵌入节奏专题同样互斥隐藏根顶栏', (tester) async {
    await openStats(
      tester,
      aGalleryClient(),
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await tester.tap(
      find.descendant(of: find.byType(MileafNavBar), matching: find.text('概览')),
    );
    await tester.pumpAndSettle();
    final topic = find.text('节奏').hitTestable();
    for (var i = 0; i < 20 && topic.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    expect(topic, findsOneWidget, reason: '概览用车专题未出现节奏入口');
    await tester.tap(topic);
    await tester.pumpAndSettle();
    expect(topBarSurface, findsNothing);
    expect(
      find.descendant(
        of: find.byType(MileafNavigationRow).last,
        matching: find.text('用车节奏'),
      ),
      findsOneWidget,
    );
    // 返回总览：根顶栏恢复。
    await tester.tap(
      find.descendant(
        of: find.byType(MileafNavigationRow).last,
        matching: backGlyph,
      ),
    );
    await tester.pumpAndSettle();
    expect(topBarSurface, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
