// 回归：能耗专题（P08「不同温度下的电耗」）在高精度读数与窄屏下的版式。
//
// 用户反馈（2026-11-19）整页显示错乱：结论卡与主图卡贴在一起、读数溢出把行内
// 文字压成一字一行、点图读数互相叠压、分段轨道折行成一个团块、「查看这些行程」
// 比同页卡片多缩进一次且没有行尾箭头。
//
// 根因都在同一处：本页曾是唯一把服务端浮点**原样上屏**的专题页
// （`conditionsValue` = num.toString()），其余页面走 number_format 的业务精度。
// 夹具因此带 15 位有效数字（见 test/support/raw_conditions_fixture.dart）——
// 四舍五入过的夹具会让这些问题在测试里同时消失。
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/components/icons.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/tokens.dart';
import 'package:mileaf/src/statistics_conditions_page.dart';
import 'package:mileaf/src/statistics_usage_page.dart'
    show StatisticsTopicFacts;

import 'statistics_conditions_test.dart' show openConditions;
import 'statistics_test.dart' show openStats;
import 'support/raw_conditions_fixture.dart';

/// 页面上所有 Text 的纯文本（含 Text.rich 的 span 文本）。
List<String> pageTexts(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(find.byType(Text)))
    text.data ?? text.textSpan?.toPlainText() ?? '',
];

/// 三位以上小数视为「原始浮点上屏」。两位小数（`48.63`）是合法的业务精度，
/// 所以这里只守 ≥3 位；更细的守卫由具体字段的断言给出。
final _rawValue = RegExp(r'\d\.\d{3,}');

Future<void> openConditionsPage(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  Map<String, dynamic>? body,
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await openStats(
    tester,
    conditionsBodyClient(body ?? rawConditions()),
    () => DateTime.utc(2026, 10, 28, 11),
    () => 'Asia/Shanghai',
    statisticsInsights: true,
  );
  await openConditions(tester);
}

Finder _scrollView() => find
    .descendant(
      of: find.byType(StatisticsConditionsPage),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    )
    .last;

/// 逐屏滚动到底，每屏检查没有溢出/异常。
Future<void> scrollThrough(WidgetTester tester, {int steps = 14}) async {
  final scroll = _scrollView();
  for (var step = 0; step < steps; step++) {
    expect(tester.takeException(), isNull, reason: '第 $step 屏出现溢出');
    if (tester.state<ScrollableState>(scroll).position.extentAfter <= 0) {
      break;
    }
    await tester.drag(scroll, const Offset(0, -420));
    await tester.pumpAndSettle();
  }
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('服务端浮点按业务精度上屏，不出现原始长小数', (tester) async {
    await openConditionsPage(tester);
    expect(find.text('不同温度下的电耗'), findsOneWidget);
    // 结论卡：电耗（Wh/km）整数（Spec mobile-v1 §11 展示舍入）。
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('conditions-conclusion')),
        matching: find.text('164 Wh/km'),
      ),
      findsOneWidget,
      reason: '结论卡读数应为整数 Wh/km',
    );
    // 样本明细：距离 1 位小数、单程中位数 1 位、平均速度整数。
    await tester.scrollUntilVisible(find.text('样本明细'), 200);
    await tester.pumpAndSettle();
    expect(find.text('342.7 km'), findsOneWidget);
    expect(find.text('62.9 km'), findsOneWidget);
    expect(find.text('47 km/h'), findsOneWidget);
    // 距离分组行：读数与元信息同精度。
    await tester.scrollUntilVisible(find.text('0–10 km'), 200);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.widgetWithText(MileafGroupCard, '0–10 km'),
        matching: find.text('164 Wh/km'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('配对 48.63 kWh / 87.2 km'), findsOneWidget);
    final raw = pageTexts(tester).where(_rawValue.hasMatch).toList();
    expect(raw, isEmpty, reason: '仍在上屏原始浮点：$raw');
    expect(tester.takeException(), isNull);
  });

  testWidgets('组边界保留小数：分档步长变成 2.5 时仍读得出真实区间', (tester) async {
    // 服务端当前按 5°C 分档，端点恒为整数；一旦步长改成 2.5，把端点压成整数
    // 会把 [7.5, 10) 显示成「8至10°C」，与页尾「只显示真实分组值」自相矛盾。
    final body = rawConditions();
    final bin = ((body['temperature_bins'] as List).first as Map)
        .cast<String, dynamic>();
    body['temperature_bins'] = [
      {
        ...bin,
        'lower_c': 7.5,
        'upper_c': 10,
        'consumption_wh_km': 164.38290651723641,
      },
    ];
    await openConditionsPage(tester, body: body);
    expect(find.text('7.5 至 10°C'), findsOneWidget);
    expect(find.text('7.5至10°C'), findsWidgets);
  });

  testWidgets('同级相邻卡之间保持 cardInset 间距（不出现贴合成沙漏）', (tester) async {
    await openConditionsPage(tester);
    final conclusion = tester.getRect(
      find.byKey(const ValueKey('conditions-conclusion')),
    );
    final plot = tester.getRect(
      find.byKey(const ValueKey('conditions-plot-card')),
    );
    // R24/CL20：同一区块内相邻卡片之间 12，与 P10 续航、P11 停放同构。
    expect(plot.top - conclusion.bottom, MileafSpace.cardInset);
    // 页尾「关于这些数据」是新区块：与上方的距离分组卡之间取 section。
    final groups = find.byType(MileafGroupCard).evaluate().toList();
    final distance = tester.getRect(
      find.byType(MileafGroupCard).at(groups.length - 2),
    );
    final notesHeader = tester.getRect(
      find.widgetWithText(MileafGroupHeader, '关于这些数据'),
    );
    expect(notesHeader.top - distance.bottom, MileafSpace.section);
  });

  testWidgets('「查看这些行程」与同页卡片同宽对齐，行尾有箭头', (tester) async {
    await openConditionsPage(tester);
    final facts = tester.getRect(find.byType(StatisticsTopicFacts));
    final drill = find.widgetWithText(MileafGroupCard, '查看这些行程');
    expect(drill, findsOneWidget);
    final row = tester.getRect(drill);
    expect(row.left, facts.left, reason: '下钻行比同页卡片多缩进了一次');
    expect(row.right, facts.right);
    // R24：它没有自己的区块标题，是样本明细的下一步动作，卡间取 cardInset。
    expect(row.top - facts.bottom, MileafSpace.cardInset);
    expect(
      find.descendant(
        of: drill,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is MileafIcon && widget.name == MileafIconName.chevron,
        ),
      ),
      findsOneWidget,
      reason: '下钻行缺行尾箭头',
    );
  });

  testWidgets('温度组分段轨道折行时不再是拉长的胶囊团块', (tester) async {
    await openConditionsPage(tester, size: const Size(360, 800));
    final track = tester.widget<Container>(find.byKey(MileafChipKeys.track));
    final shape = (track.decoration as BoxDecoration?)?.borderRadius;
    // 折行后轨道是内容容器（半径 lg），只有单行才用胶囊（MileafShape/R24）。
    expect(
      shape,
      BorderRadius.circular(MileafRadius.lg),
      reason: '两行轨道仍画成胶囊，成为一个团块',
    );
  });

  testWidgets('点图读数标签互不重叠、不越出绘图区（选中组优先）', (tester) async {
    // 三个都比槽位宽的读数：只保留锚点（选中组），且落位收敛在绘图区内。
    expect(
      conditionsValueLabelOffsets(
        widths: const [120, 120, 120],
        centers: const [40, 120, 200],
        plotLeft: 0,
        plotRight: 240,
        anchorIndex: 1,
      ),
      [null, 60.0, null],
    );
    // 窄读数：全部放得下，且保持左到右的顺序（不是一律丢弃）。
    expect(
      conditionsValueLabelOffsets(
        widths: const [30, 30, 30],
        centers: const [40, 120, 200],
        plotLeft: 0,
        plotRight: 240,
        anchorIndex: 1,
      ),
      [25.0, 105.0, 185.0],
    );
    // 比绘图区还宽的读数：贴左也读不全，一律不画。
    expect(
      conditionsValueLabelOffsets(
        widths: const [300],
        centers: const [120],
        plotLeft: 0,
        plotRight: 240,
        anchorIndex: 0,
      ),
      [null],
    );
    // 真实绘制层：13 组 × 200% 时仍不抛异常，且选中组的读数被保留。
    await openConditionsPage(
      tester,
      size: const Size(390, 844),
      body: denseConditions(),
      scale: 2,
    );
    expect(find.byKey(const ValueKey('conditions-plot-card')), findsOneWidget);
    await scrollThrough(tester);
  });

  testWidgets('13 组真实形态：下拉替代分段，卡片间距不变且不溢出', (tester) async {
    await openConditionsPage(
      tester,
      size: const Size(360, 800),
      body: denseConditions(),
    );
    expect(tester.takeException(), isNull);
    await scrollThrough(tester);
    final conclusion = tester.getRect(
      find.byKey(const ValueKey('conditions-conclusion')),
    );
    final plot = tester.getRect(
      find.byKey(const ValueKey('conditions-plot-card')),
    );
    expect(plot.top - conclusion.bottom, MileafSpace.cardInset);
  });

  testWidgets('结论卡用效率域焦点表面，下钻仍使用行程图标', (tester) async {
    await openConditionsPage(tester);
    final card = tester.widget<MileafModuleCard>(
      find.byKey(const ValueKey('conditions-conclusion')),
    );
    expect(card.hue, MileafDataDomain.efficiency.hue);
    expect(card.emphasis, MileafCardEmphasis.focus);
    final number = find.descendant(
      of: find.byKey(const ValueKey('conditions-conclusion')),
      matching: find.byType(MileafNumber),
    );
    expect(tester.element(number).colors.text, const MileafColors.light().text);
    // CL14/CL12：下钻行行首图标取 route（行程＝路线），颜色取 journey 域。
    final drill = find.widgetWithText(MileafGroupCard, '查看这些行程');
    expect(
      find.descendant(
        of: drill,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is MileafIcon && widget.name == MileafIconName.route,
        ),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<MileafGroupRow>(find.byType(MileafGroupRow)).hue,
      MileafDataDomain.journey.hue,
    );
  });

  testWidgets('组数超过 6 时分段改下拉（R03 纵向选项），选择仍能切组', (tester) async {
    final semantics = tester.ensureSemantics();
    await openConditionsPage(
      tester,
      size: const Size(320, 800),
      body: denseConditions(),
      scale: 2,
    );
    // 13 组不再画多行轨道；下拉胶囊显示当前组。
    expect(find.byKey(MileafChipKeys.track), findsNothing);
    final selector = find.byType(MileafPullDown<int>);
    expect(selector, findsOneWidget);
    expect(tester.getSize(selector).height, greaterThanOrEqualTo(44));
    final button = find.bySemanticsLabel('−10至−5°C');
    expect(
      tester
          .getSemantics(button)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    // 真负号 U+2212（CP03）。
    expect(find.text('−10至−5°C'), findsWidgets);
    // 打开浮层，选第 3 组（-10 + 2*5 = 0 至 5°C，读数 150.25 + 7 = 157.25 → 157）。
    await tester.ensureVisible(selector);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    final option = find.bySemanticsLabel('0至5°C');
    expect(
      tester
          .getSemantics(option)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    await tester.tap(find.text('0至5°C').last);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('conditions-conclusion')),
        matching: find.text('157 Wh/km'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('窄屏大字时 5 至 6 个温度组使用下拉，普通字号保留分段', (tester) async {
    for (final count in [5, 6]) {
      await openConditionsPage(
        tester,
        size: const Size(320, 800),
        body: denseConditions(bins: count),
        scale: 2,
      );
      final selector = find.descendant(
        of: find.byKey(const ValueKey('conditions-plot-card')),
        matching: find.byType(MileafPullDown<int>),
      );
      expect(selector, findsOneWidget, reason: '$count 个温度组无法在两行内排下');
      expect(find.byKey(MileafChipKeys.track), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    await openConditionsPage(
      tester,
      size: const Size(560, 800),
      body: denseConditions(bins: 5),
    );
    expect(find.byKey(MileafChipKeys.track), findsOneWidget);
    expect(find.byType(MileafPullDown<int>), findsNothing);
  });

  testWidgets('13 组 × 320 宽 200%：最窄最大字的组合也不溢出', (tester) async {
    await openConditionsPage(
      tester,
      size: const Size(320, 640),
      body: denseConditions(),
      scale: 2,
    );
    await scrollThrough(tester);
  });

  testWidgets('320 宽 200% 大字逐屏滚动不溢出', (tester) async {
    await openConditionsPage(tester, size: const Size(320, 640), scale: 2);
    await scrollThrough(tester);
    // 距离行标题在 200% 下仍单行起排（修复前会被压成一字一行）。
    await tester.scrollUntilVisible(find.text('0–10 km'), 200);
    await tester.pumpAndSettle();
    final title = tester.getRect(find.text('0–10 km'));
    final row = tester.getRect(find.byType(MileafGroupCard).last);
    expect(title.height, lessThan(row.height / 2), reason: '标题被压成多行');
    expect(tester.takeException(), isNull);
  });
}
