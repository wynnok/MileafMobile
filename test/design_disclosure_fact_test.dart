import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/tokens.dart';

import 'design_components_test.dart' show pumpComponent;

/// `MileafDisclosure` 与 `MileafFactList` 的组件合同。
///
/// 独立成文件：两者为行程详情读数区新增，其他调用方行为不变，
/// 因此不并在 `design_components_test.dart` 的既有分组里。
void main() {
  group('MileafDisclosure', () {
    testWidgets('命中区为平台命中高度，收起时不构建内容，展开就地长出', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpComponent(
        tester,
        const MileafDisclosure(
          label: '采样数据说明',
          meta: '服务端采样 200 点',
          child: Text('缺失值断线，不补点或补零。'),
        ),
      );
      expect(
        tester.getRect(find.byType(MileafDisclosure)).height,
        greaterThanOrEqualTo(MileafSpace.touch),
      );
      // 收起：只留说明，不建内容；读成一个可展开的按钮。
      expect(find.text('缺失值断线，不补点或补零。'), findsNothing);
      expect(find.text('服务端采样 200 点'), findsOneWidget);
      expect(find.bySemanticsLabel('采样数据说明'), findsOneWidget);
      await tester.tap(find.text('采样数据说明'));
      await tester.pumpAndSettle();
      expect(find.text('缺失值断线，不补点或补零。'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('动作行更实一档，并有 1px 顶部分隔线', (tester) async {
      await pumpComponent(
        tester,
        const MileafDisclosure(
          label: '对照电量',
          emphasis: true,
          topLine: true,
          child: Text('第二张图'),
        ),
      );
      final colors = MileafColors.of(
        tester.element(find.byType(MileafDisclosure)),
      );
      final label = tester.widget<Text>(find.text('对照电量'));
      expect(label.style?.color, colors.text);
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(MileafDisclosure),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.border, Border(top: BorderSide(color: colors.line)));
    });

    testWidgets('键盘：Tab 停在折叠行、焦点环用 focusRing、回车展开', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpComponent(
        tester,
        const MileafDisclosure(
          label: '对照电量',
          emphasis: true,
          topLine: true,
          child: Text('第二张图'),
        ),
      );
      // 外层 Focus 只是焦点环锚点，不新增 Tab 停靠点。
      final anchor = tester.widget<Focus>(
        find
            .descendant(
              of: find.byType(MileafDisclosure),
              matching: find.byType(Focus),
            )
            .first,
      );
      expect(anchor.canRequestFocus, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final ring = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(MileafFocusRing),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final border = (ring.decoration as BoxDecoration).border! as Border;
      expect(
        border.top.color,
        MileafColors.of(tester.element(find.byType(MileafFocusRing))).focusRing,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('第二张图'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('减少动效时箭头不旋转', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpComponent(
        tester,
        const MileafDisclosure(label: '更多行程指标', child: Text('明细')),
      );
      final rotation = tester.widget<AnimatedRotation>(
        find.byType(AnimatedRotation),
      );
      expect(rotation.duration, Duration.zero);
      expect(rotation.turns, .25);
    });
  });

  group('MileafFactList', () {
    testWidgets('单位定宽列：数字与单位各成一条竖线，缺失值不带单位', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpComponent(
        tester,
        const MileafFactList(
          facts: [
            MileafFact(label: '平均速度', value: '79', unit: 'km/h'),
            MileafFact(label: '最大功率', value: '103', unit: 'kW'),
            MileafFact(label: '车内均温'),
          ],
        ),
      );
      expect(
        tester.getRect(find.text('79')).right,
        tester.getRect(find.text('103')).right,
      );
      expect(
        tester.getRect(find.text('km/h')).right,
        tester.getRect(find.text('kW')).right,
      );
      // 缺失只出破折号，不写“— °C”。
      expect(find.text('°C'), findsNothing);
      expect(find.bySemanticsLabel('车内均温 —'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('200% 时字段名在上、值在下，左边缘同一线', (tester) async {
      await pumpComponent(
        tester,
        const MileafFactList(
          facts: [MileafFact(label: '平均速度', value: '79', unit: 'km/h')],
        ),
        scale: 2,
      );
      final label = tester.getRect(find.text('平均速度'));
      final value = tester.getRect(find.text('79 km/h'));
      expect(value.top, greaterThanOrEqualTo(label.bottom));
      expect(value.left, label.left);
      expect(tester.takeException(), isNull);
    });
  });
}
