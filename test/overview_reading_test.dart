import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';

import 'overview_a_regression_test.dart' show openOverview;

const reading = ValueKey('overview-chart-reading');
const plate = ValueKey('overview-reading-plate');

Finder inReading(String text) =>
    find.descendant(of: find.byKey(reading), matching: find.text(text));

void main() {
  testWidgets('概览图表下方读数按本期四项分组，口径成段落在其后', (tester) async {
    await openOverview(tester, currency: 'CNY');
    expect(find.byKey(plate), findsOneWidget);
    expect(find.byKey(reading), findsOneWidget);
    for (final label in ['净电耗', '已知费用', '补能', '驾驶']) {
      expect(
        find.descendant(of: find.byKey(plate), matching: find.text(label)),
        findsOneWidget,
        reason: label,
      );
    }
    expect(
      find.descendant(of: find.byKey(plate), matching: find.text('158')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(plate), matching: find.text('Wh/km')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(plate), matching: find.text('¥186.4')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(plate), matching: find.text('kWh')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(plate), matching: find.text('234.70')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byKey(plate), matching: find.text('46 趟')),
      findsOneWidget,
    );
    expect(
      find.text('缺失的费用不表示免费。净电耗与驾驶消耗为估算。'),
      findsOneWidget,
      reason: '口径合并为一段，不再与数字混排',
    );
    expect(
      find.descendant(of: find.byKey(plate), matching: find.text('8/9 次已记录')),
      findsOneWidget,
      reason: '费用覆盖落在费用格旁，而不是压在表尾',
    );
    // The former wall of label-value lines is gone: labels and values are
    // separate cells, not one joined string.
    expect(find.textContaining('净电耗 158 Wh/km'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('概览图表读值区给出选中日、参照与差值', (tester) async {
    await openOverview(tester, currency: 'CNY');
    expect(inReading('10/26'), findsOneWidget);
    expect(inReading('60.0 km'), findsOneWidget);
    expect(inReading('上月同期 09.01 — 09.26，55.4 km'), findsOneWidget);
    expect(inReading('差 +4.6 km'), findsOneWidget);
    expect(inReading('点按读值'), findsOneWidget);
  });

  testWidgets('概览图表换指标后读值同步，参照仍在同一层级', (tester) async {
    await openOverview(tester, currency: 'CNY');
    final chip = find.text('电耗');
    await tester.scrollUntilVisible(chip, 160);
    await Scrollable.ensureVisible(tester.element(chip), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(inReading('10/26'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(reading),
        matching: find.textContaining('158'),
      ),
      findsOneWidget,
    );
    expect(inReading('158 Wh/km'), findsOneWidget, reason: '读数带单位');
    expect(inReading('上月同期 09.01 — 09.26，166 Wh/km'), findsOneWidget);
    expect(inReading('差 -8 Wh/km'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('200% 字号下读数表纵向堆叠且读值完整', (tester) async {
    await openOverview(tester, currency: 'CNY', textScale: 2);
    await tester.scrollUntilVisible(find.text('驾驶'), 220);
    await tester.pumpAndSettle();
    final net = tester.getRect(
      find.descendant(of: find.byKey(plate), matching: find.text('净电耗')),
    );
    final cost = tester.getRect(
      find.descendant(of: find.byKey(plate), matching: find.text('已知费用')),
    );
    final energy = tester.getRect(
      find.descendant(of: find.byKey(plate), matching: find.text('补能')),
    );
    expect(cost.top, greaterThan(net.bottom), reason: '大字下单列');
    expect(energy.top, greaterThan(cost.bottom), reason: '大字下单列');
    expect(
      find.descendant(of: find.byKey(plate), matching: find.text('234.70')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('概览图表头：单位与区间各归其位，不再折成两行', (tester) async {
    await openOverview(tester, currency: 'CNY');
    final chart = tester.widget<TimeSeriesChart>(
      find.byType(TimeSeriesChart).first,
    );
    expect(chart.unit, 'km');
    expect(chart.subtitle, '10.01 — 10.26', reason: '区间不再把单位折进字符串');
    final frame = find.byType(TimeSeriesChart).first;
    final title = tester.getRect(
      find.descendant(of: frame, matching: find.text('每日里程')),
    );
    final unit = tester.getRect(
      find.descendant(of: frame, matching: find.text('km')),
    );
    final range = tester.getRect(
      find.descendant(of: frame, matching: find.text('10.01 — 10.26')),
    );
    // 名称 → 度量 → 窗口同一行：单位紧贴标题，窗口落在右端。
    expect(unit.center.dy, closeTo(title.center.dy, 2));
    expect(range.center.dy, closeTo(title.center.dy, 2));
    expect(range.left, greaterThan(unit.right));
    expect(tester.takeException(), isNull);
  });
}
