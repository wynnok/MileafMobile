// 回归：统计「全部指标」索引页（P15）的页首/页尾节奏与页尾说明形式。
//
// 用户 2026-11-20 以整页红框截图指出该页版式问题（无文字）。基线提交 `b1d86ba`。
// 实测（360×800、safeArea 上下 24、100% 字号）三处偏差：
// ① 首张卡片顶在导航栏底缘（间距 0）——R24 的间距表没有 0 这一档，其余二级页
//    一律从导航栏下方 8 起排；
// ② 页尾说明行贴着卡片底缘（间距 0）——R24「区块与区块 32」；
// ③ 页尾是裸折叠行，不是 R30.2/PD08 的「分组标题 + 一张分组卡」，读屏名目也还是
//    旧词「数据说明」（CP05 已并入「关于这些数据」）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/tokens.dart';

import 'apple_polish_ap11_test.dart' show insightsClient;
import 'statistics_test.dart' show openStats;

/// 打开「统计 → 全部指标」并稳定在首屏。
///
/// 数据用 AP11 票内测试的 `insightsClient`（统计洞察的整数化夹具），不是正式
/// 图册的 `aGalleryClient`——本文件只关心版式，不关心数据状态档。
Future<void> openAllMetrics(
  WidgetTester tester, {
  Size size = const Size(360, 800),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
    tester.view.resetViewPadding();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await openStats(
    tester,
    insightsClient([]),
    () => DateTime.utc(2026, 10, 28, 11),
    () => 'Asia/Shanghai',
    statisticsInsights: true,
  );
  await tester.scrollUntilVisible(
    find.widgetWithText(TextButton, '全部指标').hitTestable(),
    300,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.widgetWithText(TextButton, '全部指标'));
  await tester.pumpAndSettle();
}

/// 指标清单卡：含「节奏」那一行的分组卡（按内容定位，不依赖卡片顺序）。
Finder get indexCard =>
    find.ancestor(of: find.text('节奏'), matching: find.byType(MileafGroupCard));

/// 页尾说明分组（R30.2 的容器），按组件定位。
Finder get notesSection => find.byType(MileafDataNotes);

/// 页尾说明分组卡本身。
Finder get notesCard =>
    find.descendant(of: notesSection, matching: find.byType(MileafGroupCard));

/// 页尾说明行（默认折叠的折叠行），按 R30.2 固定顺序。
Finder get noteRows =>
    find.descendant(of: notesSection, matching: find.byType(MileafDisclosure));

void main() {
  testWidgets('页首：指标卡从导航栏下方 8 起排，不贴导航栏', (tester) async {
    await openAllMetrics(tester);
    final bar = tester.getRect(find.byType(AppBar));
    final card = tester.getRect(indexCard);
    expect(
      card.top - bar.bottom,
      MileafSpace.s8,
      reason: 'R24 间距表没有 0；二级页首张卡与导航栏之间是 8',
    );
  });

  testWidgets('页尾：说明分组与上方卡片之间是区块间距 32', (tester) async {
    await openAllMetrics(tester);
    final card = tester.getRect(indexCard);
    final notes = tester.getRect(notesSection);
    expect(
      notes.top - card.bottom,
      MileafSpace.section,
      reason: 'R24「区块与区块 32」；MileafDataNotes 不自带上边距',
    );
  });

  testWidgets('页尾为 R30.2 形式：分组标题 + 一张分组卡，旧名目「数据说明」退出', (tester) async {
    await openAllMetrics(tester);
    expect(find.text('关于这些数据'), findsOneWidget);
    expect(find.text('数据说明'), findsNothing);
    // 五类里本页只有「口径与估算」「时间与时区」两类。
    expect(find.text('口径与估算'), findsOneWidget);
    expect(find.text('时间与时区'), findsOneWidget);
    // 说明行在分组卡内（不是画布层裸行），且卡片与指标清单卡同宽同线。
    expect(notesCard, findsOneWidget);
    expect(noteRows, findsNWidgets(2));
    final card = tester.getRect(indexCard);
    final grouped = tester.getRect(notesCard);
    expect(grouped.left, card.left);
    expect(grouped.right, card.right);
  });

  testWidgets('页尾说明行落在卡片内边距上，行尾箭头与指标行同一条竖线', (tester) async {
    await openAllMetrics(tester);
    final index = tester.getRect(indexCard);
    final grouped = tester.getRect(notesCard);
    final row = tester.getRect(find.byType(MileafGroupRow).first);
    final noteRow = tester.getRect(noteRows.first);

    // 两张卡同宽同线。
    expect(index.left, grouped.left);
    expect(index.right, grouped.right);
    // R24「两条起始线」：卡内文字对齐卡片内边距（页面边距 + 16）。说明行没有
    // 行首图标，落在这条线上；指标行多一列 20 + 12 的图标，文字因此再右移一档
    // （同一张卡的 hairline 起点也按这一列换算）。
    expect(
      tester.getRect(find.text('口径与估算')).left - grouped.left,
      MileafSpace.cardPad,
    );
    expect(
      tester.getRect(find.text('节奏')).left - index.left,
      MileafSpace.cardPad + MileafIconMetrics.nav + MileafSpace.s12,
      reason: '指标行的行首图标各占一列',
    );
    // 行尾：说明行的命中区右缘与指标行一样收在卡片内边距上——两个行尾箭头
    // 因此共用同一条竖线（箭头本身在 AnimatedRotation 里，取行盒而非字形）。
    expect(noteRow.left, grouped.left + MileafSpace.cardPad);
    expect(noteRow.right, grouped.right - MileafSpace.cardPad);
    expect(noteRow.right, row.right - MileafSpace.cardPad);
  });

  testWidgets('说明行按 R30.2 的固定顺序排列，不按页面自选顺序', (tester) async {
    await openAllMetrics(tester);
    // R30.2「说明行固定分为五类」：caliber 在 time 之前。顺序由
    // MileafDataNotes 按 category 排序给出，页面只交分类与文字。
    expect(
      tester.getRect(find.text('口径与估算')).top,
      lessThan(tester.getRect(find.text('时间与时区')).top),
    );
    // 行距不在这里守：R24「卡片内部的分组用分隔线或 16 的间距」由
    // MileafDisclosure 自带的上下 s8 决定（相邻 8 + 8 = 16），属组件内部，
    // 页面侧断言只会把测试耦合到它的实现上。
  });

  testWidgets('页尾说明默认折叠，展开后读到统计时区', (tester) async {
    await openAllMetrics(tester);
    expect(find.textContaining('Asia/Shanghai'), findsNothing);
    await tester.tap(find.text('时间与时区'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Asia/Shanghai'), findsOneWidget);
  });

  testWidgets('「原始统计指标」的说明在 360 宽单行，五行行高一致', (tester) async {
    await openAllMetrics(tester);
    // 修复前 16 字说明差 9 就换行，末行只剩「细」，该行被撑到 85。14 字落在
    // 360 宽的单行预算内（卡宽 320 − 行内边距 32 − 行首图标列 32 − 行尾箭头
    // 列 28 = 228）。几何断言照 test/drives_test.dart 的「不折出孤字」先例：
    // 比同页单行说明的高度，不在测试里用 TextPainter 预估换行
    // （docs/specs/charging-method-share-ring.md:208）。
    expect(find.text('驾驶与充电的区间指标与时间桶'), findsOneWidget);
    expect(
      tester.getRect(find.text('驾驶与充电的区间指标与时间桶')).height,
      tester.getRect(find.text('驾驶时间、单程与星期分布')).height,
      reason: '与同页单行说明同高，说明不再折行',
    );
    // R24 的 64 是双行行的**最小高**，不是固定高（大字下组件再 +8）。这里守的是
    // 五行彼此等高：修复前末行因说明折行被撑到 85，与另外四行不齐。
    final rows = find.byType(MileafGroupRow);
    final heights = [
      for (var i = 0; i < rows.evaluate().length; i++)
        tester.getRect(rows.at(i)).height,
    ];
    expect(heights, hasLength(5));
    for (final height in heights) {
      expect(height, heights.first, reason: '五行等高');
    }
    expect(
      heights.first,
      greaterThanOrEqualTo(MileafGroupRow.rowHeightTwoLine),
      reason: 'R24 双行最小高 64',
    );
  });

  testWidgets('窄屏 320 宽最多折成两行，不再继续膨胀', (tester) async {
    await openAllMetrics(tester, size: const Size(320, 568));
    // 320 宽装不下 14 字，必然折行（实测 12 + 2，末行不再是孤字，但「时间桶」
    // 会被拆开，见记录 §4）。这里只守「不继续膨胀」：高度不超过单行说明的两倍。
    final single = tester.getRect(find.text('温度与距离条件')).height;
    expect(
      tester.getRect(find.text('驾驶与充电的区间指标与时间桶')).height,
      lessThanOrEqualTo(single * 2),
      reason: '窄屏最多两行',
    );
  });

  testWidgets('窄屏大字滚动全页无溢出', (tester) async {
    await openAllMetrics(tester, size: const Size(320, 568), scale: 2);
    final scroll = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .last;
    for (var step = 0; step < 10; step++) {
      expect(tester.takeException(), isNull, reason: '第 $step 屏出现溢出');
      if (tester.state<ScrollableState>(scroll).position.extentAfter <= 0) {
        break;
      }
      await tester.drag(scroll, const Offset(0, -320));
      await tester.pumpAndSettle();
    }
  });
}
