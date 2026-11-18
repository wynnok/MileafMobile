import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/icons.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/tokens.dart';

import 'design_components_test.dart' show pumpComponent;

/// U02 共享系统回归：实际命中、合成对比度、大字布局、微动效与旧条款回退。
///
/// 每条用例捕获一个具体回退（#30 必做项），对应规则写在 reason 里。
void main() {
  double contrast(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    final (hi, lo) = l1 >= l2 ? (l1, l2) : (l2, l1);
    return (hi + .05) / (lo + .05);
  }

  group('R04 输入与边界合成对比度', () {
    for (final brightness in Brightness.values) {
      test('${brightness.name}：controlBorder 对最终背景 ≥3:1，正文 ≥4.5:1', () {
        final colors = brightness == Brightness.dark
            ? const MileafColors.dark()
            : const MileafColors.light();
        // 输入边界按其实际所在背景（surface 与 canvas）合成计算。
        for (final background in [colors.surface, colors.canvas]) {
          expect(
            contrast(colors.controlBorder, background),
            greaterThanOrEqualTo(3),
            reason: '${brightness.name} 输入边界在 surface/canvas 上 ≥3:1',
          );
        }
        expect(
          contrast(colors.textMuted, colors.surface),
          greaterThanOrEqualTo(4.5),
          reason: '${brightness.name} 辅助文字 ≥4.5:1',
        );
        expect(
          contrast(colors.text, colors.canvas),
          greaterThanOrEqualTo(4.5),
          reason: '${brightness.name} 正文 ≥4.5:1',
        );
      });
    }
  });

  group('R05 实际命中区 44×44（坐标级）', () {
    testWidgets('MileafIconButton 边缘坐标可命中', (tester) async {
      var taps = 0;
      await pumpComponent(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: MileafIconButton(
            icon: MileafIconName.refresh,
            tooltip: '刷新',
            onPressed: () => taps++,
          ),
        ),
      );
      final origin = tester.getTopLeft(find.byType(MileafIconButton));
      for (final offset in const [
        Offset(2, 2),
        Offset(MileafSpace.touch - 3, 2),
        Offset(2, MileafSpace.touch - 3),
        Offset(MileafSpace.touch - 3, MileafSpace.touch - 3),
      ]) {
        await tester.tapAt(origin + offset);
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(taps, 4, reason: '图标按钮 44×44 命中区四角全部可点');
    });

    testWidgets('StatusChip 44 命中带的上下边缘可点', (tester) async {
      var taps = 0;
      await pumpComponent(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: StatusChip(label: '近30天', onTap: () => taps++),
        ),
      );
      final chip = tester.getRect(find.byType(StatusChip));
      expect(chip.height, greaterThanOrEqualTo(MileafSpace.touch));
      await tester.tapAt(chip.topLeft + const Offset(6, 2));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tapAt(chip.bottomLeft + const Offset(6, -2));
      await tester.pump(const Duration(milliseconds: 10));
      expect(taps, 2, reason: 'chip 命中区边缘实际可点（A08）');
    });
  });

  group('R05 输入最小 52 与列表行 72', () {
    testWidgets('TextField 装饰器 ≥52', (tester) async {
      await pumpComponent(
        tester,
        const TextField(decoration: InputDecoration(labelText: '站点地址')),
        brightness: Brightness.light,
      );
      final decorator = tester.getSize(find.byType(InputDecorator));
      expect(
        decorator.height,
        greaterThanOrEqualTo(MileafSpace.inputMinHeight),
      );
    });

    testWidgets('单行 MileafDataRow ≥72（原 rowMin 56，R05/P12）', (tester) async {
      await pumpComponent(
        tester,
        MileafDataRow(title: '服务信息', onTap: () {}),
        brightness: Brightness.light,
      );
      expect(
        tester.getSize(find.byType(MileafDataRow)).height,
        greaterThanOrEqualTo(MileafSpace.rowMin),
      );
    });
  });

  group('R14/R15 浮动底栏材质并随大字增高', () {
    Widget shell() => MaterialApp(
      theme: mileafTheme(Brightness.light)
          .copyWith(platform: TargetPlatform.iOS),
      home: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: MileafNavBar(index: 0, onSelected: (_) {}),
      ),
    );

    double navHeight(WidgetTester tester) =>
        tester.getSize(find.byType(NavigationMaterial)).height;

    testWidgets('100% 内容高64，未知透明度偏好使用同几何实色', (tester) async {
      await tester.pumpWidget(shell());
      expect(navHeight(tester), greaterThanOrEqualTo(MileafSpace.navHeight));
      expect(
        find.descendant(
          of: find.byType(MileafNavBar),
          matching: find.byType(NavigationMaterial),
        ),
        findsOneWidget,
      );
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('200% 按实际文字增高', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(shell());
      expect(
        navHeight(tester),
        greaterThan(MileafSpace.navHeight),
        reason: '大字下底栏不得截断标签（R05）',
      );
    });
  });

  group('R05 顶栏大字两行', () {
    Future<void> pumpBar(WidgetTester tester, {bool nonlinear = false}) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(Brightness.light),
          home: MediaQuery(
            // 非线性缩放只作用于本子树（R03：跟随平台非线性，不读线性倍数）。
            data: MediaQueryData(
              textScaler: nonlinear
                  ? const _SteepScaler()
                  : TextScaler.noScaling,
            ),
            child: Scaffold(
              body: MileafTopBar(
                vehicleName: '行笺测试车',
                onVehicle: () {},
                onSettings: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('200%（非线性）车辆独立成行且 ≥44 命中，无横向溢出', (tester) async {
      await pumpBar(tester, nonlinear: true);
      expect(tester.takeException(), isNull);
      final vehicle = tester.getRect(find.text('行笺测试车'));
      final brand = tester.getRect(find.text('概览'));
      // AP02（R26/PD01）：大字展开态的控件在标题上方一行靠右，车辆不再位于
      // 标题下方；两行结构仍成立，只是顺序按 ADR0014 调换。
      expect(
        vehicle.bottom,
        lessThanOrEqualTo(brand.top),
        reason: 'R26 顶栏 200% 两行：控件在上、大标题独占下一行',
      );
      final hit = tester.getRect(
        find
            .ancestor(of: find.text('行笺测试车'), matching: find.byType(InkWell))
            .first,
      );
      expect(hit.height, greaterThanOrEqualTo(MileafSpace.touch));
      expect(find.byTooltip('设置'), findsOneWidget, reason: '设置入口仍可达');
    });

    testWidgets('100% 仍为单行（页名、车辆、设置同一行）', (tester) async {
      await pumpBar(tester);
      final vehicle = tester.getRect(find.text('行笺测试车'));
      final brand = tester.getRect(find.text('概览'));
      expect(
        (vehicle.center.dy - brand.center.dy).abs(),
        lessThan(4),
        reason: '普通字号保持单行顶栏',
      );
    });
  });

  group('R07 控件微动效', () {
    testWidgets('chip 选中过渡180ms；disableAnimations 时归零', (tester) async {
      await pumpComponent(
        tester,
        StatusChip(label: '里程', selected: false, onTap: () {}),
      );
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      expect(
        container.duration,
        MileafDurations.selection,
        reason: 'R16 互斥选中 180ms',
      );

      // disableAnimations：时长归零，最多再排一帧即到终态，不再有 160ms 过渡。
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpComponent(
        tester,
        StatusChip(label: '里程', selected: true, onTap: () {}),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(
        tester
                .widget<AnimatedContainer>(find.byType(AnimatedContainer).first)
                .decoration
            is BoxDecoration,
        isTrue,
      );
      final decoration =
          tester
                  .widget<AnimatedContainer>(
                    find.byType(AnimatedContainer).first,
                  )
                  .decoration!
              as BoxDecoration;
      expect(
        decoration.color,
        const MileafColors.dark().segmentSelected,
        reason: '禁动效下选中底色 1ms 内到达终态（160ms 过渡下此处仍是起始色）',
      );
    });
  });

  group('R04 图标圆币移除', () {
    testWidgets('MileafDataRow 行内图标 20px、无圆圈包装', (tester) async {
      await pumpComponent(
        tester,
        MileafDataRow(title: '地图设置', icon: MileafIconName.mapPin, onTap: () {}),
        brightness: Brightness.light,
      );
      final icon = tester.widget<MileafIcon>(find.byType(MileafIcon).first);
      expect(icon.size, MileafIconMetrics.nav, reason: 'R04/A12 行内图标 20');
      expect(
        tester.widgetList<Container>(
          find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
          ),
        ),
        isEmpty,
        reason: 'R04 禁止图标圆币',
      );
    });
  });

  group('R05/R04 焦点即时可见', () {
    testWidgets('Tab 聚焦按钮出现 2px focusRing，不淡入', (tester) async {
      await pumpComponent(
        tester,
        MileafButton(label: '验证并连接', onPressed: () {}),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final border =
          (tester
                          .widget<Container>(
                            find
                                .descendant(
                                  of: find.byType(MileafButton),
                                  matching: find.byType(Container),
                                )
                                .first,
                          )
                          .decoration!
                      as BoxDecoration)
                  .border!
              as Border;
      expect(border.top.width, 2, reason: 'R05 焦点即时 2px 外环');
      expect(
        border.top.color,
        // R04: primary uses an inverse boundary against its accent fill.
        const MileafColors.dark().textOnAccent,
      );
    });

    testWidgets('Tab 聚焦 chip 出现 2px focusRing', (tester) async {
      await pumpComponent(tester, StatusChip(label: '里程', onTap: () {}));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final chip = tester.firstWidget<Container>(
        find.descendant(
          of: find.byType(StatusChip),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container && widget.foregroundDecoration != null,
          ),
        ),
      );
      final ring = chip.foregroundDecoration! as BoxDecoration;
      expect(ring.border!.top.width, 2);
      expect(ring.border!.top.color, const MileafColors.dark().focusRing);
    });
  });

  group('R02 自绘与功能文字基值 ≥12', () {
    test('图形文字 token 均不低于 12', () {
      expect(MileafChartMetrics.axisLabelSize, greaterThanOrEqualTo(12));
      expect(MileafBatteryMetrics.valueSize, greaterThanOrEqualTo(12));
      expect(MileafType.footnoteSize, greaterThanOrEqualTo(12));
      expect(MileafType.captionSize, greaterThanOrEqualTo(12));
      expect(MileafType.navLabelSize, greaterThanOrEqualTo(12));
      expect(MileafType.detailSize, greaterThanOrEqualTo(12));
    });
  });
}

/// 非线性大字：14 → 23.8（≥21 触发大字分支），18 以上增速放缓，
/// 模拟平台真实非线性缩放（R03）。
class _SteepScaler extends TextScaler {
  const _SteepScaler();

  @override
  double scale(double fontSize) {
    const knee = 18.0;
    const factor = 1.7;
    final base = fontSize <= knee
        ? fontSize * factor
        : knee * factor + (fontSize - knee) * 1.5;
    return fontSize <= 0 ? fontSize : base;
  }

  @override
  double get textScaleFactor => 1.5;
}
