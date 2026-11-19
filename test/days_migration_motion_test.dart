import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/tokens.dart';

import 'design_components_test.dart' show pumpComponent;

/// DM03：MG08 焦点值统一交叉淡化（PD13 / M08 扩展）。
///
/// 交叉淡化口径（MG08）：任何焦点值内容变更 120ms 交叉淡化；transitionBuilder
/// 只动 opacity；layoutBuilder 叠放不跳高度；交叉淡化期间旧值移出语义树，
/// 同一时刻只有一个数值可被朗读；减少动效时长归零直接切换。
/// MG06/PD12 的页级间距断言在 days_migration_spacing_test.dart（与 overview/
/// drives 页面接线一同提交，见 days-matter-migration.md「工作区状态」）。
void main() {
  /// 承载值变化的宿主：同类型根节点在 pumpWidget 间保状态，
  /// MileafNumber 走 didUpdateWidget 触发 AnimatedSwitcher。
  Widget host(String value, {Widget? child}) =>
      child ??
      MileafNumber(value: value, unit: 'km', scale: MetricValueScale.metricMd);

  List<String> numberTexts(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(MileafNumber),
          matching: find.byType(Text),
        ),
      )
      .map((t) => (t.textSpan! as TextSpan).toPlainText())
      .toList();

  void enableReduceMotion(WidgetTester tester) {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      () => tester.binding.platformDispatcher
          .clearAccessibilityFeaturesTestValue(),
    );
  }

  group('MG08/PD13：MileafNumber 值变更交叉淡化', () {
    testWidgets('值变更：中间帧旧值淡出、新值淡入，高度稳定', (tester) async {
      await pumpComponent(tester, host('12'));
      expect(numberTexts(tester), ['12 km']);

      final heightBefore = tester.getSize(find.byType(MileafNumber)).height;
      await pumpComponent(tester, host('34'));
      await tester.pump(); // 启动过渡。
      await tester.pump(const Duration(milliseconds: 60)); // 中间帧。

      final fades = tester
          .widgetList<FadeTransition>(
            find.descendant(
              of: find.byType(MileafNumber),
              matching: find.byType(FadeTransition),
            ),
          )
          .toList();
      expect(fades, hasLength(2), reason: '交叉淡化期间新旧两层各一个透明度');
      final opacities = fades.map((f) => f.opacity.value).toList()..sort();
      expect(
        opacities.first,
        inInclusiveRange(0.01, 0.99),
        reason: '旧值已离开全显、仍在淡出',
      );
      expect(opacities.last, inInclusiveRange(0.01, 0.99), reason: '新值已淡入但未完成');
      expect(numberTexts(tester), containsAll(['12 km', '34 km']));

      expect(tester.getSize(find.byType(MileafNumber)).height, heightBefore);
    });

    testWidgets('完成帧只有新值', (tester) async {
      await pumpComponent(tester, host('12'));
      await pumpComponent(tester, host('34'));
      await tester.pumpAndSettle();
      expect(numberTexts(tester), ['34 km']);
      expect(find.textContaining('12'), findsNothing);
    });

    testWidgets('减少动效：时长归零，直接切新值无过渡', (tester) async {
      enableReduceMotion(tester);
      await pumpComponent(tester, host('12'));
      await pumpComponent(tester, host('34'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(numberTexts(tester), ['34 km'], reason: '减动效下不出现过渡帧');
      expect(
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
        Duration.zero,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('12'), findsNothing);
    });

    testWidgets('非减动效时长为 120ms（MileafDurations.value）', (tester) async {
      await pumpComponent(tester, host('12'));
      expect(
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
        MileafDurations.value,
      );
    });
  });

  group('MG08：语义单一（同一时刻只有一个数值可被朗读）', () {
    testWidgets('裸 MileafNumber：交叉淡化期间旧值移出语义树', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpComponent(tester, host('12'));
      await pumpComponent(tester, host('34'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.bySemanticsLabel(RegExp('34')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('12')),
        findsNothing,
        reason: '旧值经 ExcludeSemantics 移出语义树，读屏单一来源',
      );
      semantics.dispose();
    });

    testWidgets('MetricBlock：live 标签随值更新，全程只有一份', (tester) async {
      final semantics = tester.ensureSemantics();
      Widget blockHost(String value) => MetricBlock(
        label: '驾驶里程',
        value: value,
        unit: 'km',
        scale: MetricValueScale.metricLg,
      );
      await pumpComponent(tester, blockHost('12'));
      await pumpComponent(tester, blockHost('34'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.bySemanticsLabel(RegExp('34 km')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('12 km')), findsNothing);
      await tester.pumpAndSettle();
      semantics.dispose();
    });
  });
}
