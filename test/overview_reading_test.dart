import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';

import 'overview_a_regression_test.dart' show openOverview;

// R29：图表读值由 TimeSeriesChart 的读数头承载，不再有页面自排的读值块。
// live region 节点包裹可见的日期行与数值行；第三行（参照与差值）2026-11-19
// 起独占整卡内宽、落在步进那一行之外，可见文字不进语义树（朗读仍由 live
// region 的 sentence 一次说全），所以第三行的可见断言按图表框取。
const reading = MileafChartGrammar.readoutLiveKey;
const plate = ValueKey('overview-reading-plate');

Finder inReading(String text) =>
    find.descendant(of: find.byKey(reading), matching: find.text(text));

Finder inChart(String text) => find.descendant(
  of: find.byType(TimeSeriesChart).first,
  matching: find.text(text),
);

/// live region 的朗读句（第三行的参照与差值也在这句里）。
String readingLabel(WidgetTester tester) =>
    tester.getSemantics(find.byKey(reading)).getSemanticsData().label;

void main() {
  testWidgets('概览图表下方读数按本期四项分组，口径成段落在其后', (tester) async {
    await openOverview(tester, currency: 'CNY');
    expect(find.byKey(plate), findsOneWidget);
    // P01：本期账目独立成「本期账目」分组卡，四格标签按 CP02 改名。
    expect(find.text('本期账目'), findsOneWidget);
    for (final label in ['电耗', '已记录费用', '充电', '行程']) {
      expect(
        find.descendant(of: find.byKey(plate), matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }
    expect(
      find.descendant(of: find.byKey(plate), matching: find.text('158 Wh/km')),
      findsOneWidget,
      reason: '值与单位同一行，不折成两行',
    );
    expect(
      find.descendant(of: find.byKey(plate), matching: find.text('¥186.4')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(plate), matching: find.text('234.70 kWh')),
      findsOneWidget,
      reason: '值与单位同一行，不折成两行',
    );
    expect(
      find.descendant(of: find.byKey(plate), matching: find.text('46 趟')),
      findsOneWidget,
    );
    expect(
      find.text('未记录的费用不等于免费；电耗和耗电为估算值。'),
      findsOneWidget,
      reason: 'CP08：口径合并为一段，不再与数字混排',
    );
    expect(
      find.descendant(
        of: find.byKey(plate),
        matching: find.text('9 次中 8 次有费用'),
      ),
      findsOneWidget,
      reason: 'CP02：费用覆盖落在费用格旁，而不是压在表尾',
    );
    // The former wall of label-value lines is gone: labels and values are
    // separate cells, not one joined string.
    expect(find.textContaining('电耗 158 Wh/km'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('概览图表读值区给出选中日、参照与差值', (tester) async {
    final semantics = tester.ensureSemantics();
    await openOverview(tester, currency: 'CNY');
    // R29/CP04：读数头三行——数值（值 + 单位）、参照与差值一句、日期（DF1）。
    expect(inReading('60 km'), findsOneWidget);
    const reference = '上月同期 9月1日–26日 55.4 km，多 4.6 km';
    expect(inChart(reference), findsOneWidget, reason: '第三行仍是可见读数的一行');
    expect(
      readingLabel(tester),
      allOf(contains('9月1日–26日 55.4 km'), contains('多 4.6 km')),
      reason: '朗读句含参照与差值',
    );
    expect(
      find.bySemanticsLabel(RegExp(r'多 4.6 km')),
      findsOneWidget,
      reason: '可见第三行不进语义树：差值只由 live region 说一次',
    );
    // 日期行按站点日历（Asia/Shanghai）的墙钟写：选中桶是 10月26日。
    expect(inReading('10月26日'), findsOneWidget, reason: '读数头日期用站点日历');
    // CP11：可见的「点按读值」提示删除，改由图表语义提示承载。
    expect(find.text('点按读值'), findsNothing);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('每日里程图表'))
          .getSemanticsData()
          .hint,
      MileafChartGrammar.hint,
    );
    semantics.dispose();
  });

  testWidgets('概览图表换指标后读值同步，参照仍在同一层级', (tester) async {
    final semantics = tester.ensureSemantics();
    await openOverview(tester, currency: 'CNY');
    // 「电耗」在本期账目里也是格子标签，分段胶囊用 StatusChip 限定。
    final chip = find.widgetWithText(StatusChip, '电耗');
    await tester.scrollUntilVisible(chip, 160);
    await Scrollable.ensureVisible(tester.element(chip), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(reading),
        matching: find.textContaining('158'),
      ),
      findsOneWidget,
    );
    expect(inReading('158 Wh/km'), findsOneWidget, reason: '读数带单位');
    const reference = '上月同期 9月1日–26日 166 Wh/km，少 8 Wh/km';
    expect(inChart(reference), findsOneWidget, reason: '第三行仍是可见读数的一行');
    expect(
      readingLabel(tester),
      allOf(contains('9月1日–26日 166 Wh/km'), contains('少 8 Wh/km')),
      reason: '朗读句含参照与差值',
    );
    expect(
      find.bySemanticsLabel(RegExp(r'少 8 Wh/km')),
      findsOneWidget,
      reason: '可见第三行不进语义树：差值只由 live region 说一次',
    );
    expect(inReading('10月26日'), findsOneWidget, reason: '读数头日期用站点日历');
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('200% 字号下读数表纵向堆叠且读值完整', (tester) async {
    await openOverview(tester, currency: 'CNY', textScale: 2);
    await tester.scrollUntilVisible(find.text('本期账目'), 220);
    await tester.pumpAndSettle();
    final net = tester.getRect(
      find.descendant(of: find.byKey(plate), matching: find.text('电耗')),
    );
    final cost = tester.getRect(
      find.descendant(of: find.byKey(plate), matching: find.text('已记录费用')),
    );
    final energy = tester.getRect(
      find.descendant(of: find.byKey(plate), matching: find.text('充电')),
    );
    expect(cost.top, greaterThan(net.bottom), reason: '大字下单列');
    expect(energy.top, greaterThan(cost.bottom), reason: '大字下单列');
    expect(
      find.descendant(of: find.byKey(plate), matching: find.text('234.70 kWh')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('概览图表头：单位随标题，区间只在期间卡出现一次', (tester) async {
    await openOverview(tester, currency: 'CNY');
    final chart = tester.widget<TimeSeriesChart>(
      find.byType(TimeSeriesChart).first,
    );
    expect(chart.unit, 'km');
    // P01/R21.4：区间只在期间卡标签出现一次，图表头不再有副标题区间。
    expect(chart.subtitle, isNull, reason: '区间不再重复出现在图表头');
    final frame = find.byType(TimeSeriesChart).first;
    final title = tester.getRect(
      find.descendant(of: frame, matching: find.text('每日里程')),
    );
    final unit = tester.getRect(
      find.descendant(of: frame, matching: find.text('km')),
    );
    // 名称 → 度量同一行，单位紧贴标题。
    expect(unit.center.dy, closeTo(title.center.dy, 2));
    expect(unit.left, greaterThan(title.right));
    expect(find.text('10月1日–26日'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
