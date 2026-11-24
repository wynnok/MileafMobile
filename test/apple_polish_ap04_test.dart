import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/icons.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/tokens.dart';
import 'package:mileaf/src/design/typography.dart';

import 'design_components_test.dart' show pumpComponent;
import 'support/hierarchy_probe.dart';

/// AP04 内容语法（R21、R24、R25、R30、R31；§4 M06、M11）的组件合同。
///
/// StateView 的整页图形尺寸未公开，测试用规格值 48（R31）。
const double stateViewPageIconSize = 48;

void main() {
  group('模块卡与分组卡（R24/PD02）', () {
    testWidgets('模块卡：半径 20、内边 16、背板与墨水层分离', (tester) async {
      await pumpComponent(tester, const MileafModuleCard(child: Text('图表')));
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(MileafModuleCard),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.type, MaterialType.transparency);
      expect(material.borderRadius, BorderRadius.circular(MileafRadius.lg));
      expect(material.elevation, 0, reason: '静态卡无阴影');
      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(MileafModuleCard),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(padding.padding, const EdgeInsets.all(MileafSpace.cardPad));
    });

    testWidgets('分组卡：半径 20、无阴影、默认无内边', (tester) async {
      await pumpComponent(tester, const MileafGroupCard(child: Text('设置组')));
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(MileafGroupCard),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.type, MaterialType.transparency);
      expect(material.borderRadius, BorderRadius.circular(MileafRadius.lg));
      expect(material.elevation, 0);
    });
  });

  group('标题（R22/R24）', () {
    testWidgets('区块标题用 title2、区间用 subheadline', (tester) async {
      await pumpComponent(
        tester,
        const SectionHeader(title: '最近记录', range: '10.01 — 10.26'),
      );
      final title = tester.widget<Text>(find.text('最近记录'));
      expect(title.style?.fontSize, MileafType.title2Size);
      expect(title.style?.fontWeight, MileafType.weightSemiBold);
      final range = tester.widget<Text>(find.text('10.01 — 10.26'));
      expect(range.style?.fontSize, MileafType.subheadlineSize);
      expect(range.style?.color, const MileafColors.dark().textSecondary);
    });

    testWidgets('分组标题用 subheadline 500、脚注用 footnote', (tester) async {
      await pumpComponent(
        tester,
        const MileafGroupHeader(title: '关于这些数据', footnote: '两项分别计量，不能相加'),
      );
      final title = tester.widget<Text>(find.text('关于这些数据'));
      expect(title.style?.fontSize, MileafType.subheadlineSize);
      expect(title.style?.fontWeight, MileafType.weightMedium);
      final footnote = tester.widget<Text>(find.text('两项分别计量，不能相加'));
      expect(footnote.style?.fontSize, MileafType.footnoteSize);
    });
  });

  group('分组行（R24）', () {
    testWidgets('单行最小高 52、双行最小高 64', (tester) async {
      await pumpComponent(tester, const MileafGroupRow(title: '地图'));
      final single = tester.getSize(find.byType(MileafGroupRow)).height;
      // R24 规格值独立断言：单行 52、双行 64。
      expect(single, 52.0);
      await pumpComponent(
        tester,
        const MileafGroupRow(title: '主题', meta: '深色'),
      );
      final twoLine = tester.getSize(find.byType(MileafGroupRow)).height;
      expect(twoLine, 64.0);
    });

    testWidgets('分隔线从文字起始处开始、到卡片右缘结束', (tester) async {
      await pumpComponent(
        tester,
        const MileafGroupCard(
          child: Column(
            children: [
              MileafGroupRow(
                title: '地图',
                leading: MileafIconName.mapPin,
                bottomLine: true,
              ),
              MileafGroupRow(title: '外观', bottomLine: true),
            ],
          ),
        ),
      );
      final hairlines = find.descendant(
        of: find.byType(MileafGroupRow),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).border != null,
        ),
      );
      expect(hairlines, findsNWidgets(2));
      final cardRect = tester.getRect(find.byType(MileafGroupCard));
      final leadingRect = tester.getRect(
        find.descendant(
          of: find.byType(MileafGroupRow),
          matching: find.byType(MileafIcon),
        ),
      );
      final first = tester.getRect(hairlines.first);
      final second = tester.getRect(hairlines.last);
      // 有图标：起点 = 卡左缘 + 图标宽 + 12；终点 = 卡片右缘。
      expect(first.left, closeTo(leadingRect.right + MileafSpace.s12, .5));
      expect(first.right, cardRect.right);
      // 无图标：起点回到卡内文字左缘（页面 + 16），仍到右缘。
      expect(second.left, cardRect.left + MileafSpace.cardPad);
      expect(second.right, cardRect.right);
    });

    testWidgets('行标题 body 400、尾部值 body textSecondary（R22/P12）', (tester) async {
      await pumpComponent(
        tester,
        const MileafGroupRow(title: '导航', value: '158', unit: 'km'),
      );
      final title = tester.widget<Text>(find.text('导航'));
      expect(title.style?.fontSize, MileafType.bodySize);
      expect(title.style?.fontWeight, MileafType.weightRegular);
      final value = tester.widget<Text>(
        find.descendant(
          of: find.byType(MileafGroupRow),
          matching: find.byWidgetPredicate(
            (widget) => widget is Text && widget.textSpan != null,
          ),
        ),
      );
      final span = value.textSpan! as TextSpan;
      expect(span.text, '158');
      expect(span.style?.fontSize, MileafType.bodySize);
      expect(span.style?.fontWeight, MileafType.weightRegular);
      expect(span.style?.color, const MileafColors.dark().textSecondary);
      expect(
        (span.children!.first as TextSpan).style?.fontSize,
        MileafType.subheadlineSize,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('数值与网格（R21.5）', () {
    testWidgets('数值与单位永不拆行：单个富文本、单位不在第二行', (tester) async {
      await pumpComponent(
        tester,
        const SizedBox(
          width: 56,
          child: MileafNumber(
            value: '1,198.6',
            unit: 'km',
            scale: MetricValueScale.metricLg,
          ),
        ),
      );
      final text = tester.widget<Text>(
        find
            .descendant(
              of: find.byType(MileafNumber),
              matching: find.byType(Text),
            )
            .first,
      );
      final span = text.textSpan! as TextSpan;
      expect(span.text, '1,198.6');
      expect(span.children, hasLength(1));
      expect((span.children!.first as TextSpan).text, ' km');
      expect(text.maxLines, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '单位随 R22：metric 用 subheadline、display 用 body，均为 textSecondary',
      (tester) async {
        await pumpComponent(
          tester,
          const MileafNumber(
            value: '68',
            unit: '%',
            scale: MetricValueScale.metricMd,
          ),
        );
        var text = tester.widget<Text>(
          find
              .descendant(
                of: find.byType(MileafNumber),
                matching: find.byType(Text),
              )
              .first,
        );
        var unitSpan = (text.textSpan! as TextSpan).children!.first as TextSpan;
        expect(unitSpan.style?.fontSize, MileafType.subheadlineSize);
        expect(unitSpan.style?.fontWeight, MileafType.weightRegular);
        expect(unitSpan.style?.color, const MileafColors.dark().textSecondary);

        await pumpComponent(
          tester,
          const MileafNumber(
            value: '320',
            unit: 'km',
            scale: MetricValueScale.display,
          ),
        );
        text = tester.widget<Text>(
          find
              .descendant(
                of: find.byType(MileafNumber),
                matching: find.byType(Text),
              )
              .first,
        );
        unitSpan = (text.textSpan! as TextSpan).children!.first as TextSpan;
        expect(unitSpan.style?.fontSize, MileafType.bodySize);
        expect(unitSpan.style?.color, const MileafColors.dark().textSecondary);
      },
    );

    testWidgets('三列网格：一行三格', (tester) async {
      await pumpComponent(
        tester,
        const MetricGrid(
          columns: 3,
          children: [Text('一'), Text('二'), Text('三')],
        ),
        width: 390,
      );
      final one = tester.getRect(find.text('一'));
      final two = tester.getRect(find.text('二'));
      final three = tester.getRect(find.text('三'));
      expect(one.top, two.top);
      expect(two.top, three.top);
      expect(one.left, lessThan(two.left));
      expect(two.left, lessThan(three.left));
    });

    testWidgets('200% 时网格单列堆叠', (tester) async {
      await pumpComponent(
        tester,
        const MetricGrid(
          columns: 3,
          children: [Text('一'), Text('二'), Text('三')],
        ),
        scale: 2,
      );
      final one = tester.getRect(find.text('一'));
      final two = tester.getRect(find.text('二'));
      expect(two.top, greaterThan(one.top));
      expect(two.left, one.left);
    });
  });

  group('折叠（M06）', () {
    testWidgets('M06：内容高度 200ms、透明度 120ms、箭头 160ms；阅读锚点不跳', (tester) async {
      await pumpComponent(
        tester,
        const MileafDisclosure(
          label: '对照电量',
          child: SizedBox(height: 80, child: Text('第二张图')),
        ),
      );
      final anchorTop = tester.getRect(find.text('对照电量')).top;
      final size = tester.widget<AnimatedSize>(
        find.descendant(
          of: find.byType(MileafDisclosure),
          matching: find.byType(AnimatedSize),
        ),
      );
      expect(size.duration, MileafDurations.foldHeight);
      final opacity = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: find.byType(MileafDisclosure),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(opacity.duration, MileafDurations.foldOpacity);
      final rotation = tester.widget<AnimatedRotation>(
        find.descendant(
          of: find.byType(MileafDisclosure),
          matching: find.byType(AnimatedRotation),
        ),
      );
      expect(rotation.duration, MileafDurations.chevron);
      await tester.tap(find.text('对照电量'));
      await tester.pumpAndSettle();
      expect(find.text('第二张图'), findsOneWidget);
      // 阅读锚点：触发行位置不变，内容向下长出。
      expect(tester.getRect(find.text('对照电量')).top, anchorTop);
    });

    testWidgets('减少动效：M06 时长归零', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpComponent(
        tester,
        const MileafDisclosure(label: '更多', child: Text('明细')),
      );
      final size = tester.widget<AnimatedSize>(
        find.descendant(
          of: find.byType(MileafDisclosure),
          matching: find.byType(AnimatedSize),
        ),
      );
      expect(size.duration, Duration.zero);
      final opacity = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: find.byType(MileafDisclosure),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(opacity.duration, Duration.zero);
    });
  });

  group('状态与反馈（R31/M11）', () {
    testWidgets('整页状态用 title2 与 48 图形；错误标题用 text 不用 error', (tester) async {
      await pumpComponent(
        tester,
        const StateView(
          kind: StateViewKind.error,
          title: '数据读取失败',
          message: '保留上次快照',
        ),
      );
      final title = tester.widget<Text>(find.text('数据读取失败'));
      expect(title.style?.fontSize, MileafType.title2Size);
      expect(title.style?.color, const MileafColors.dark().text);
      final icon = tester.widget<MileafIcon>(find.byType(MileafIcon));
      expect(icon.size, stateViewPageIconSize);
      expect(icon.color, const MileafColors.dark().error);
    });

    testWidgets('模块内状态用 headline 与 24 图形', (tester) async {
      await pumpComponent(
        tester,
        const StateView(
          kind: StateViewKind.empty,
          title: '这段时间没有数据',
          compact: true,
        ),
      );
      final title = tester.widget<Text>(find.text('这段时间没有数据'));
      expect(title.style?.fontSize, MileafType.headlineSize);
      final icon = tester.widget<MileafIcon>(find.byType(MileafIcon));
      expect(icon.size, MileafIconMetrics.header);
    });

    testWidgets('M11：行内状态条高度 200ms、透明度 160ms', (tester) async {
      await pumpComponent(
        tester,
        const InlineBanner(message: '没能更新，显示的是 10:02 的数据'),
      );
      final size = tester.widget<AnimatedSize>(
        find.descendant(
          of: find.byType(InlineBanner),
          matching: find.byType(AnimatedSize),
        ),
      );
      expect(size.duration, MileafDurations.statusHeight);
      final opacity = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: find.byType(InlineBanner),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(opacity.duration, MileafDurations.statusOpacity);
      expect(opacity.opacity, 1);
    });

    testWidgets('进行中胶囊：高 24、segmentTrack 底', (tester) async {
      await pumpComponent(tester, const MileafRunningPill());
      expect(tester.getSize(find.byType(MileafRunningPill)).height, 24.0);
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(MileafRunningPill),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, const MileafColors.dark().segmentTrack);
      expect(find.text('进行中'), findsOneWidget);
    });
  });

  group('车况卡（PD06）', () {
    testWidgets('车况卡半径由 24 改 20', (tester) async {
      await pumpComponent(
        tester,
        const MileafHero(child: SizedBox(height: 100, child: Text('320 km'))),
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(MileafHero),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.borderRadius, BorderRadius.circular(MileafRadius.lg));
    });
  });

  group('关于这些数据（R30）', () {
    testWidgets('五类按序、缺类不出现、默认折叠', (tester) async {
      await pumpComponent(
        tester,
        const MileafDataNotes(
          groups: [
            MileafDataNoteGroup(
              category: DataNoteCategory.technical,
              note: '版本 v1',
            ),
            MileafDataNoteGroup(category: DataNoteCategory.caliber, note: '估算'),
          ],
        ),
      );
      expect(find.text('关于这些数据'), findsOneWidget);
      expect(find.text('口径与估算'), findsOneWidget);
      expect(find.text('技术详情'), findsOneWidget);
      expect(find.text('记录与缺失'), findsNothing);
      expect(find.text('时间与时区'), findsNothing);
      expect(find.text('来源与生成时间'), findsNothing);
      // 默认折叠：说明文字不构建。
      expect(find.text('估算'), findsNothing);
      expect(find.text('版本 v1'), findsNothing);
      final caliber = tester.getRect(find.text('口径与估算'));
      final technical = tester.getRect(find.text('技术详情'));
      expect(caliber.top, lessThan(technical.top));
    });

    testWidgets('展开显示说明，技术详情可复制', (tester) async {
      await pumpComponent(
        tester,
        const MileafDataNotes(
          groups: [
            MileafDataNoteGroup(
              category: DataNoteCategory.technical,
              note: '采样 200 点',
              copyable: true,
            ),
          ],
        ),
      );
      await tester.tap(find.text('技术详情'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.text('采样 200 点'), findsOneWidget);
    });
  });

  group('层级探针（R21.7）', () {
    testWidgets('统计视口内 display 与 metricLg 文字数量', (tester) async {
      await pumpComponent(
        tester,
        Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('甲', style: context.type.display),
              Text('乙', style: context.type.metricLg),
              Text('丙', style: context.type.body),
              Text('丁', style: context.type.metricMd),
            ],
          ),
        ),
      );
      final report = measureHierarchy(
        tester,
        viewport: const Rect.fromLTWH(0, 0, 360, 800),
      );
      expect(report.displayCount, 1);
      expect(report.metricLgCount, 1);
      expect(report.total, 2);
    });

    testWidgets('排除有效视口之外的文字', (tester) async {
      await pumpComponent(
        tester,
        Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('视口内', style: context.type.display),
              const SizedBox(height: 900),
              Text('视口外', style: context.type.display),
            ],
          ),
        ),
      );
      final report = measureHierarchy(
        tester,
        viewport: const Rect.fromLTWH(0, 0, 360, 800),
      );
      expect(report.displayCount, 1);
      expect(report.display.single.text, '视口内');
    });
  });

  group('评审增量（M1/M3/M06/M11/R31）', () {
    testWidgets('320 宽三列网格先收成两列，数值不裁切', (tester) async {
      await pumpComponent(
        tester,
        const MetricGrid(
          columns: 3,
          children: [
            MileafNumber(
              value: '1,198.6',
              unit: 'km',
              scale: MetricValueScale.metricSm,
            ),
            MileafNumber(
              value: '60.0',
              unit: 'km',
              scale: MetricValueScale.metricSm,
            ),
            MileafNumber(
              value: '11.25',
              unit: 'kWh',
              scale: MetricValueScale.metricSm,
            ),
          ],
        ),
        width: 320,
      );
      final one = tester.getRect(find.text('1,198.6 km'));
      final two = tester.getRect(find.text('60.0 km'));
      final three = tester.getRect(find.text('11.25 kWh'));
      expect(one.top, two.top, reason: '320 宽先收成两列');
      expect(three.top, greaterThan(one.top));
      expect(tester.takeException(), isNull);
    });

    testWidgets('M06：折叠中途高度与透明度都在过渡（时间采样）', (tester) async {
      await pumpComponent(
        tester,
        const MileafDisclosure(
          label: '对照电量',
          child: SizedBox(height: 80, child: Text('第二张图')),
        ),
      );
      final collapsed = tester.getRect(find.byType(MileafDisclosure)).height;
      await tester.tap(find.text('对照电量'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = tester.getRect(find.byType(MileafDisclosure)).height;
      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(MileafDisclosure),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(mid, greaterThan(collapsed));
      expect(mid, lessThan(collapsed + 88));
      expect(fade.opacity.value, greaterThan(0));
      expect(fade.opacity.value, lessThan(1));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(MileafDisclosure)).height,
        greaterThan(mid),
      );
    });

    testWidgets('M11：状态条消失中途高度收缩（时间采样）', (tester) async {
      Widget banner(bool visible) =>
          InlineBanner(message: '没能更新，显示的是 10:02 的数据', visible: visible);
      await pumpComponent(tester, banner(true));
      await tester.pumpAndSettle();
      final shown = tester.getRect(find.byType(InlineBanner)).height;
      await pumpComponent(tester, banner(false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = tester.getRect(find.byType(InlineBanner)).height;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(shown));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(InlineBanner)).height, 0);
    });

    testWidgets('200% 分组行自然增高、文字不溢出', (tester) async {
      await pumpComponent(
        tester,
        const MileafGroupRow(title: '地图', meta: '未配置'),
        scale: 2,
      );
      expect(
        tester.getSize(find.byType(MileafGroupRow)).height,
        greaterThanOrEqualTo(72.0),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('状态组件各态：模块内加载、整页空、模块内错误', (tester) async {
      await pumpComponent(
        tester,
        const StateView(kind: StateViewKind.loading, compact: true),
      );
      expect(find.byType(SkeletonBlock), findsWidgets);
      await pumpComponent(
        tester,
        StateView(
          kind: StateViewKind.empty,
          title: '这段时间还没有行程',
          actionLabel: '重试',
          onAction: () {},
        ),
      );
      expect(find.text('这段时间还没有行程'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      await pumpComponent(
        tester,
        const StateView(
          kind: StateViewKind.error,
          title: '没能更新',
          compact: true,
        ),
      );
      final title = tester.widget<Text>(find.text('没能更新'));
      expect(title.style?.color, const MileafColors.dark().text);
    });

    test('车况状态图形映射闪电/月亮/离线（R31/P01）', () {
      expect(
        vehicleStatusIcon(VehicleStatusKind.charging),
        MileafIconName.bolt,
      );
      expect(
        vehicleStatusIcon(VehicleStatusKind.sleeping),
        MileafIconName.moon,
      );
      expect(
        vehicleStatusIcon(VehicleStatusKind.offline),
        MileafIconName.offline,
      );
    });
  });
}
