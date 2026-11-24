// 读数头第三行（参照与差值一句）的回归：用户截图里「上月同期 10月1日–19日
// 0 km，多 92 km」在手机卡宽下折成两行（2026-11-19 第二次截图，红框 ①，
// 右侧红框 ② 是占掉行宽的 < > 步进）。
//
// 上一版只把字号从 15 降到 13，并按「439 − 24 页边距 − 40 卡内边距 − 88 步进
// = 287」预留行宽——那个算式只减了一侧页边距与一侧卡内边距，实际第三行可用宽
// 是「屏宽 − 页边距×2 − 卡内边×2 − 88」（375 屏焦点卡只剩 223），13pt 下这句
// PingFang 实宽 248，仍然折行。本用例按真实几何（375/393/430 屏、焦点卡 12
// 内边、专题卡 16 内边）断言：第三行必须独占整行（不再被步进挤掉 88）且一行放下。
//
// 宽度断言需要实字宽（Inter + Ahem CJK），单独成文件，避免字体重载影响依赖
// Ahem 方块的像素探针测试（AP05）。
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

  /// 真实屏宽 → 卡内可用宽：屏宽 − 页边距×2 − 卡内边距×2。
  ///
  /// - 页边距按 `MileafLayout.pageInset` 分档：< 390 取 20，≥ 390 取 24。
  /// - 卡内边距默认 16；概览焦点卡走 §6 退让阶梯第 2 步的 12（**比默认窄，
  ///   所以默认档是保守值**，两种都要能放下）。
  double cardWidth(double screen, {double cardPad = MileafSpace.cardPad}) {
    final inset = screen >= MileafBreakpoints.wide
        ? MileafSpace.s24
        : MileafSpace.s20;
    return screen - 2 * inset - 2 * cardPad;
  }

  Future<void> pumpChart(
    WidgetTester tester, {
    required double width,
    required String referenceLabel,
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
    await tester.pumpAndSettle();
  }

  testWidgets('375 屏（焦点卡 12 内边）：用户截图那句一行放下，且第三行独占整行', (tester) async {
    // 截图原句：参照名 + 参照值 + 差值。375 屏焦点卡内宽 311（旧布局第三行
    // 只剩 223，PingFang 实宽 248 一撞就折行）。
    const sentence = '上月同期 10月1日–19日 0 km，多 92 km';
    final width = cardWidth(375, cardPad: MileafSpace.s12);
    await pumpChart(tester, width: width, referenceLabel: '上月同期 10月1日–19日');
    final context = find.textContaining(sentence);
    expect(context, findsOneWidget);
    expect(
      tester.getSize(context).height,
      lessThanOrEqualTo(MileafType.footnoteHeight + 0.5),
      reason: '「$sentence」应一行显示，不折成两行',
    );
    // 步进不再从第三行里抠走 88：行盒就是整张卡的内宽（旧布局这里是
    // width − 88，真机 PingFang 实宽 248 一撞就折行）。
    expect(
      tester.getSize(find.byKey(MileafChartGrammar.contextRowKey)).width,
      width,
      reason: '第三行应独占整行，不再被 < > 步进挤窄',
    );
    expect(tester.getTopLeft(context).dx, 0, reason: '第三行与日期/数值同左缘（卡内文字起始线）');
  });

  testWidgets('375 屏（默认 16 内边的专题卡）同样一行放下', (tester) async {
    // 统计区间 / 停放两处用默认卡内边 16：375 屏只剩 303，是全文最窄的一档。
    const sentence = '上月同期 10月1日–19日 0 km，多 92 km';
    await pumpChart(
      tester,
      width: cardWidth(375),
      referenceLabel: '上月同期 10月1日–19日',
    );
    expect(
      tester.getSize(find.textContaining(sentence)).height,
      lessThanOrEqualTo(MileafType.footnoteHeight + 0.5),
      reason: '「$sentence」应一行显示（最窄的默认卡内边）',
    );
  });

  testWidgets('393 / 430 屏同样一行放下', (tester) async {
    const sentence = '上月同期 10月1日–19日 0 km，多 92 km';
    for (final screen in [393.0, 430.0]) {
      final width = cardWidth(screen, cardPad: MileafSpace.s12);
      await pumpChart(tester, width: width, referenceLabel: '上月同期 10月1日–19日');
      expect(
        tester.getSize(find.textContaining(sentence)).height,
        lessThanOrEqualTo(MileafType.footnoteHeight + 0.5),
        reason: '${screen.toInt()} 屏「$sentence」应一行显示',
      );
    }
  });

  testWidgets('更长的电耗对比句在 375 屏焦点卡一行放下', (tester) async {
    // 全库最长的一句：PingFang 实宽 302，375 屏焦点卡内宽 311，余量 9。
    const sentence = '上月同期 9月1日–26日 174 Wh/km，少 8 Wh/km';
    await pumpChart(
      tester,
      width: cardWidth(375, cardPad: MileafSpace.s12),
      referenceLabel: '上月同期 9月1日–26日',
      unit: 'Wh/km',
      values: const [166, 5],
      reference: const [174, 5],
    );
    expect(
      tester.getSize(find.textContaining(sentence)).height,
      lessThanOrEqualTo(MileafType.footnoteHeight + 0.5),
      reason: '「$sentence」应一行显示',
    );
  });
}
