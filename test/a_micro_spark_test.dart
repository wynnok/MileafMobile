import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/theme.dart';

Future<void> pumpSpark(WidgetTester tester, List<double?> values) =>
    tester.pumpWidget(
      MaterialApp(
        theme: mileafTheme(Brightness.dark),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 150,
              child: MicroSpark(values: values, semanticsLabel: '迷你趋势'),
            ),
          ),
        ),
      ),
    );

/// A 版微趋势取代 C 的 `Sparkline`：缺失断线、单点/空列表只占位。
void main() {
  testWidgets('A 微折线在缺失值处断线也不抛异常', (tester) async {
    await pumpSpark(tester, [12, null, 30, 18, null, 24]);
    expect(find.byType(MicroSpark), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.bySemanticsLabel('迷你趋势'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('全缺失与单点都不画线但保留占位高度', (tester) async {
    await pumpSpark(tester, [null, null]);
    expect(tester.getSize(find.byType(MicroSpark)).height, 28);
    await pumpSpark(tester, [42]);
    expect(tester.getSize(find.byType(MicroSpark)).height, 28);
    expect(tester.takeException(), isNull);
  });
  testWidgets('空列表只占位不渲染趋势', (tester) async {
    await pumpSpark(tester, const []);
    expect(tester.getSize(find.byType(MicroSpark)).height, 28);
    expect(tester.takeException(), isNull);
  });
}
