import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/collage.dart';

Future<void> pumpSparkline(WidgetTester tester, List<double?> values) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 150, child: Sparkline(values: values)),
          ),
        ),
      ),
    );

void main() {
  testWidgets('C 迷你折线在缺失值处断线也不抛异常', (tester) async {
    await pumpSparkline(tester, [12, null, 30, 18, null, 24]);
    expect(find.byType(Sparkline), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('全缺失与单点都不画线但保留占位高度', (tester) async {
    await pumpSparkline(tester, [null, null]);
    expect(tester.getSize(find.byType(Sparkline)).height, 34);
    await pumpSparkline(tester, [42]);
    expect(tester.getSize(find.byType(Sparkline)).height, 34);
    expect(tester.takeException(), isNull);
  });
  testWidgets('空列表只占位不渲染画布', (tester) async {
    await pumpSparkline(tester, const []);
    expect(tester.getSize(find.byType(Sparkline)).height, 34);
    expect(tester.takeException(), isNull);
  });
}
