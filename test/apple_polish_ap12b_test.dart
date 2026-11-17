import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/layout.dart';

import 'statistics_parking_test.dart' show openParking;
import 'statistics_range_test.dart' show openRange;
import 'support/copy_probe.dart';

/// AP12b 专题合同测试：长期续航（P10）与停放观察（P11）按 R25 专题骨架、
/// R29 图表语法、R30 信息披露与 CP02/CP08/CP10 文案落地。
///
/// 主界面渲染树断言用 copy_probe：折叠状态下不得出现 snake_case、「·」拼接
/// 或「pp」符号代替词；技术详情与逐行明细折叠后不在树内（R30.4）。
void main() {
  group('P10 长期续航', () {
    testWidgets('身份块、结论卡、主图卡读数头与图例按 R25/R29 组织', (tester) async {
      await openRange(tester, <int>[]);
      // 身份块：术语标题（满电额定续航（估算））+ 统计口径一句。
      expect(find.text('满电额定续航（估算）'), findsOneWidget);
      expect(find.text('独立本地月窗口，逐月估算额定续航'), findsOneWidget);
      // 结论卡：月中位数 metricLg + 必要限定。
      expect(find.text('月中位数'), findsWidgets);
      expect(find.text('根据行程记录估算，不是电池健康检测'), findsOneWidget);
      // 主图卡：6/12 分段、读数头（live region）、绘图区、X 轴下图例与脚注。
      expect(find.text('6个月'), findsOneWidget);
      expect(find.text('12个月'), findsOneWidget);
      expect(find.byKey(MileafChartGrammar.readoutLiveKey), findsOneWidget);
      expect(find.byKey(const Key('range-observation-chart')), findsOneWidget);
      expect(find.text('日常波动范围（P10–P90）'), findsOneWidget);
      expect(find.textContaining('纵轴从 410 km 起'), findsOneWidget);
      expect(find.textContaining('432.0'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('页尾「关于这些数据」五类分组，技术详情可复制', (tester) async {
      await openRange(tester, <int>[]);
      await tester.scrollUntilVisible(
        find.text('关于这些数据').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      // 固定五类：口径与估算 / 记录与缺失 / 时间与时区 / 来源与生成时间 / 技术详情。
      for (final label in ['口径与估算', '记录与缺失', '时间与时区', '来源与生成时间', '技术详情']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // 算法版本等技术原值默认折叠，不在主界面。
      expect(find.textContaining('session-day-rated-range-v1'), findsNothing);
      await tester.tap(find.text('技术详情'));
      await tester.pumpAndSettle();
      expect(find.textContaining('session-day-rated-range-v1'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('稀疏样本给出样本较少限定', (tester) async {
      await openRange(tester, <int>[], sparse: true);
      expect(find.text('样本较少，仅供参考'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('缺失月读数不补零，结论卡给出缺失口径', (tester) async {
      await openRange(tester, <int>[], missing: true);
      // 缺失月不补零：结论卡脚注给出缺失口径，读数头值为 —。
      expect(find.text('暂无有效月样本'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('P11 停放观察', () {
    testWidgets('结论卡给出主值、总量上下文与不预测限定', (tester) async {
      await openParking(tester, <Uri>[]);
      expect(find.text('停车电量变化'), findsWidgets);
      expect(find.text('统计有效停车窗口，按窗口开始时间归期'), findsOneWidget);
      // 主值 −2.0 个百分点（真负号，不用 pp）。
      expect(find.textContaining('−2.0 个百分点'), findsWidgets);
      expect(find.text('2 段停车，共 12 小时；折合每天 −4.0 个百分点'), findsOneWidget);
      expect(find.text('只反映已记录的变化，不预测未来。'), findsOneWidget);
      // 主图卡：每段停车 + 读数头 + 正负柱绘图区。
      expect(find.text('每段停车'), findsOneWidget);
      expect(find.byKey(MileafChartGrammar.readoutLiveKey), findsOneWidget);
      expect(find.byKey(const Key('parking-trend-chart')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('停车时状态为占比条加状态、时长、占比表格行', (tester) async {
      await openParking(tester, <Uri>[]);
      expect(find.text('停车时状态'), findsOneWidget);
      expect(find.text('按有效停车时长计算占比'), findsOneWidget);
      expect(find.byKey(const Key('parking-state-bar')), findsOneWidget);
      for (final row in [
        ('在线', '2 小时', '16.7%'),
        ('睡眠', '6 小时', '50.0%'),
        ('离线', '1 小时', '8.3%'),
        ('未知', '3 小时', '25.0%'),
      ]) {
        expect(find.text(row.$1), findsWidgets, reason: row.$1);
        expect(find.text(row.$2), findsOneWidget, reason: row.$2);
        expect(find.text(row.$3), findsOneWidget, reason: row.$3);
      }
      // 窗口统计人话标签：候选/排除/开放与未计入原因。
      expect(find.text('共 4 段，未计入 1 段，尚未结束 1 段'), findsOneWidget);
      expect(find.text('未计入原因：缺少电量数据 1 段'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('停车记录行用人话标签，逐行明细保留原位折叠', (tester) async {
      await openParking(tester, <Uri>[]);
      expect(find.text('停车记录'), findsOneWidget);
      expect(find.textContaining('已载入 3 条记录，匹配 4 段'), findsOneWidget);
      expect(find.text('完整'), findsOneWidget);
      expect(find.text('状态记录不完整（仍计入）'), findsOneWidget);
      expect(find.text('未计入'), findsOneWidget);
      // 明细默认折叠：window_id 等技术原值不在树内；展开后逐行明细在原位。
      expect(find.textContaining('open-tail'), findsNothing);
      await tester.tap(find.text('未计入'));
      await tester.pumpAndSettle();
      expect(find.textContaining('缺少电量数据'), findsWidgets);
      expect(find.text('加载更多停车记录'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('无有效窗口时不展示零变化，能力不支持走共享句', (tester) async {
      await openParking(tester, <Uri>[], empty: true);
      expect(find.textContaining('— 个百分点'), findsWidgets);
      expect(find.text('暂无有效停车窗口，无法判断电量变化'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('CP09 渲染树探针（折叠态主界面）', () {
    testWidgets('长期续航主界面无 snake_case、无「·」拼接、无 pp 符号', (tester) async {
      await openRange(tester, <int>[]);
      final texts = collectedTexts(
        tester.element(find.byType(MileafContent).first),
      );
      expect(texts, isNotEmpty);
      final problems = <String>[];
      for (final text in texts) {
        if (copyGuardViolationTechnicalToken(text)) {
          problems.add('CP09.3 snake_case: $text');
        }
        if (copyGuardViolationDotJoin(text)) {
          problems.add('CP09.1 点号拼接: $text');
        }
        if (copyGuardViolationSymbolSubstitute(text)) {
          problems.add('CP09.4 符号代替词: $text');
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    testWidgets('停放观察主界面无 snake_case、无「·」拼接、无 pp 符号', (tester) async {
      await openParking(tester, <Uri>[]);
      final texts = collectedTexts(
        tester.element(find.byType(MileafContent).first),
      );
      expect(texts, isNotEmpty);
      final problems = <String>[];
      for (final text in texts) {
        if (copyGuardViolationTechnicalToken(text)) {
          problems.add('CP09.3 snake_case: $text');
        }
        if (copyGuardViolationDotJoin(text)) {
          problems.add('CP09.1 点号拼接: $text');
        }
        if (copyGuardViolationSymbolSubstitute(text)) {
          problems.add('CP09.4 符号代替词: $text');
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });
}
