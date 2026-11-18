// 读数头第三行（参照与差值一句）的回归：用户截图里「上月同期 10月1日–18日
// 0 km，多 92 km」在手机卡宽下折成两行。按用户裁定改为 footnote 小一号，
// 并要求单行读感。宽度断言需要实字宽（Inter + Ahem CJK），单独成文件，
// 避免字体重载影响依赖 Ahem 方块的像素探针测试（AP05）。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/tokens.dart';
import 'package:mileaf/src/design/theme.dart';

TimeSeriesChart chart({
  required List<num?> values,
  required List<num?> reference,
  required String referenceLabel,
  String unit = 'km',
}) => TimeSeriesChart(
  title: '每日里程',
  unit: unit,
  times: [for (var i = 0; i < values.length; i++) DateTime(2026, 11, 1 + i)],
  series: [
    ChartSeries(label: '里程', values: values, style: ChartSeriesStyle.bars),
    ChartSeries(
      label: referenceLabel,
      values: reference,
      style: ChartSeriesStyle.reference,
    ),
  ],
  semanticsLabel: '每日里程图表',
);

void main() {
  setUpAll(() async {
    // 与 AP14 同法：Inter 实字宽测宽度，CJK 走 Ahem 方块（≈字号方宽）。
    final loader = FontLoader('Inter');
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      loader.addFont(rootBundle.load('assets/fonts/Inter-$weight.ttf'));
    }
    await loader.load();
  });

  Future<double> contextHeight(
    WidgetTester tester, {
    required double width,
    required String referenceLabel,
    required String contextText,
    String unit = 'km',
    List<num?> values = const [92, 5],
    List<num?> reference = const [0, 5],
  }) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: mileafTheme(Brightness.light),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: chart(
                values: values,
                reference: reference,
                referenceLabel: referenceLabel,
                unit: unit,
              ),
            ),
          ),
        ),
      ),
    );
    return tester.getSize(find.textContaining(contextText)).height;
  }

  testWidgets('用户截图的一句在手机卡宽内一行放下（footnote 小一号）', (tester) async {
    // 截图设备 ≈439pt 屏：可用行宽 = 439 − 24 页边距 − 40 卡内边距 − 88 步进命中；
    // harness 无页边与卡内边距，等价宽度 = 287 + 88。
    final height = await contextHeight(
      tester,
      width: 375,
      referenceLabel: '上月同期 10月1日–18日',
      // 用户截图的原句：参照名 + 参照值 + 差值。
      contextText: '上月同期 10月1日–18日 0 km，多 92 km',
    );
    expect(
      height,
      lessThanOrEqualTo(MileafType.footnoteHeight + 0.5),
      reason: '「上月同期 10月1日–18日 0 km，多 92 km」应一行显示，不折成两行',
    );
  });

  testWidgets('更长的电耗对比句同样一行放下', (tester) async {
    final height = await contextHeight(
      tester,
      width: 375,
      referenceLabel: '上月同期 9月1日–26日',
      contextText: '上月同期 9月1日–26日 174 Wh/km，少 8 Wh/km',
      unit: 'Wh/km',
      values: const [166, 5],
      reference: const [174, 5],
    );
    expect(
      height,
      lessThanOrEqualTo(MileafType.footnoteHeight + 0.5),
      reason: '「上月同期 9月1日–26日 174 Wh/km，少 8 Wh/km」应一行显示',
    );
  });
}
