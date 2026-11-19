// AP03 控件与弹层（R27、R28、§4 M01/M02/M05）的票内测试。
//
// 只测公开 Widget、公开构造参数与可观察的几何、语义与回调；不读私有字段。
// 组件图板与正式渲染见 test/apple_polish_ap03_render_test.dart（交付手册 §5）。
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/icons.dart';
import 'package:mileaf/src/design/motion.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/tokens.dart';

Future<void> pumpBoard(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.dark,
  double width = 390,
  double height = 844,
  double scale = 1,
  TargetPlatform platform = TargetPlatform.iOS,
  EdgeInsets padding = const EdgeInsets.all(20),
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: mileafTheme(brightness).copyWith(platform: platform),
      home: Scaffold(
        body: SingleChildScrollView(padding: padding, child: child),
      ),
    ),
  );
  await tester.pump();
}

/// 选中底（唯一胶囊）。
Finder get lens => find.byKey(MileafChipKeys.selected);

/// 带真实状态的互斥分段，用于 M02、重定向与减少动效。
class SegmentedHarness extends StatefulWidget {
  const SegmentedHarness({
    super.key,
    required this.labels,
    this.onSelected,
    this.equalWidth = true,
  });

  final List<String> labels;
  final ValueChanged<int>? onSelected;
  final bool equalWidth;

  @override
  State<SegmentedHarness> createState() => _SegmentedHarnessState();
}

class _SegmentedHarnessState extends State<SegmentedHarness> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) => ChipRow(
    equalWidth: widget.equalWidth,
    children: [
      for (final (index, label) in widget.labels.indexed)
        StatusChip(
          label: label,
          selected: _selected == index,
          onTap: () {
            setState(() => _selected = index);
            widget.onSelected?.call(index);
          },
        ),
    ],
  );
}

Widget statefulRow(
  List<String> labels, {
  ValueChanged<int>? onSelected,
  bool equalWidth = true,
}) => SegmentedHarness(
  labels: labels,
  onSelected: onSelected,
  equalWidth: equalWidth,
);

void main() {
  group('R27 分段控件（胶囊轨道、唯一选中底、无下划线）', () {
    testWidgets('轨道视觉高 40、选中底 36，两者都是胶囊', (tester) async {
      await pumpBoard(
        tester,
        ChipRow(
          children: [
            StatusChip(label: '里程', onTap: () {}),
            StatusChip(label: '电耗', selected: true, onTap: () {}),
            StatusChip(label: '补能', onTap: () {}),
          ],
        ),
      );
      final track = find.byKey(MileafChipKeys.track);
      expect(tester.getSize(track).height, 40);
      final trackDecoration =
          (tester.widget<Container>(track).decoration! as BoxDecoration);
      expect(trackDecoration.color, const MileafColors.dark().segmentTrack);
      expect(
        trackDecoration.borderRadius,
        BorderRadius.all(Radius.circular(MileafRadius.full)),
      );

      expect(tester.getSize(lens).height, 36);
      final lensDecoration =
          (tester.widget<Container>(lens).decoration! as BoxDecoration);
      expect(lensDecoration.color, const MileafColors.dark().segmentSelected);
      expect(
        lensDecoration.borderRadius,
        BorderRadius.all(Radius.circular(MileafRadius.full)),
      );
      // R27：下划线标记删除——组件内不再有 12×2 的强调色标记。
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).color ==
                  const MileafColors.dark().accentStrong,
        ),
        findsNothing,
      );
    });

    testWidgets('选中底只在浅色加阴影（y1/blur3/黑 12%），深色无阴影', (tester) async {
      Widget row() => ChipRow(
        children: [
          StatusChip(label: '本月', onTap: () {}),
          StatusChip(label: '近7天', selected: true, onTap: () {}),
        ],
      );
      await pumpBoard(tester, row(), brightness: Brightness.light);
      var decoration =
          tester.widget<Container>(lens).decoration! as BoxDecoration;
      expect(decoration.boxShadow, isNotNull);
      final shadow = decoration.boxShadow!.single;
      expect(shadow.offset, const Offset(0, 1));
      expect(shadow.blurRadius, 3);
      expect((shadow.color.a * 100).round(), 12, reason: '黑色 12%');

      await pumpBoard(tester, row(), brightness: Brightness.dark);
      await tester.pumpAndSettle();
      decoration = tester.widget<Container>(lens).decoration! as BoxDecoration;
      expect(decoration.boxShadow ?? const <BoxShadow>[], isEmpty);
    });

    testWidgets('M02：选中底 180ms 平移，起步横向拉伸 1.04 后回落', (tester) async {
      await pumpBoard(tester, statefulRow(const ['里程', '电耗']));
      final resting = tester.getSize(lens).width;
      final startCenter = tester.getRect(lens).center.dx;
      await tester.tap(find.text('电耗'));
      await tester.pump();
      expect(
        tester.getRect(lens).width,
        closeTo(resting * MileafMotion.segmentStretch, .5),
        reason: 'M02 起步横向拉伸 1.04',
      );
      final firstCenter = tester.getRect(lens).center.dx;
      expect(firstCenter, closeTo(startCenter, 1), reason: '拉伸先于位移');
      await tester.pump(const Duration(milliseconds: 90));
      final middleCenter = tester.getRect(lens).center.dx;
      expect(middleCenter, greaterThan(startCenter));
      expect(
        middleCenter,
        lessThan(
          tester.getRect(find.widgetWithText(StatusChip, '电耗')).center.dx,
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.getRect(lens).width,
        closeTo(resting, .5),
        reason: '拉伸回落到 1.0',
      );
      final target = tester.getRect(find.widgetWithText(StatusChip, '电耗'));
      expect(tester.getRect(lens).center.dx, closeTo(target.center.dx, .5));
      expect(
        tester
            .widget<AnimatedPositioned>(
              find.ancestor(
                of: lens,
                matching: find.byType(AnimatedPositioned),
              ),
            )
            .duration,
        MileafDurations.selection,
        reason: 'M02 平移 180ms',
      );
    });

    testWidgets('连续点击从当前位置重定向，不回跳起点', (tester) async {
      await pumpBoard(tester, statefulRow(const ['里程', '电耗', '补能']));
      await tester.tap(find.text('补能'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final midCenter = tester.getRect(lens).center.dx;
      await tester.tap(find.text('里程'));
      await tester.pump();
      final redirected = tester.getRect(lens).center.dx;
      expect(
        (redirected - midCenter).abs(),
        lessThan(24),
        reason: '重定向从当前位置起步，不回到起点',
      );
      await tester.pump(const Duration(milliseconds: 220));
      expect(
        tester.getRect(lens).center.dx,
        closeTo(
          tester.getRect(find.widgetWithText(StatusChip, '里程')).center.dx,
          .5,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('四项在 320 宽或大字时 2×2，每行至多 3 项（5 项 3+2）', (tester) async {
      await pumpBoard(
        tester,
        ChipRow(
          children: [
            for (final label in ['里程', '电耗', '补能', '费用'])
              StatusChip(label: label, onTap: () {}),
          ],
        ),
        width: 320,
      );
      final first = tester.getRect(find.widgetWithText(StatusChip, '里程'));
      final second = tester.getRect(find.widgetWithText(StatusChip, '电耗'));
      final third = tester.getRect(find.widgetWithText(StatusChip, '补能'));
      expect(second.center.dy, closeTo(first.center.dy, .5), reason: '第一行两项');
      expect(third.top, greaterThanOrEqualTo(first.bottom), reason: '第二行');

      await pumpBoard(
        tester,
        ChipRow(
          children: [
            for (final label in ['近30天', '近7天', '自定义', '本月', '本年'])
              StatusChip(label: label, onTap: () {}),
          ],
        ),
      );
      final rects = [
        for (final label in ['近30天', '近7天', '自定义', '本月', '本年'])
          tester.getRect(find.widgetWithText(StatusChip, label)),
      ];
      expect(
        rects[2].center.dy,
        closeTo(rects[0].center.dy, .5),
        reason: '每行至多 3 项',
      );
      expect(rects[3].top, greaterThanOrEqualTo(rects[0].bottom));
      expect(
        rects[3].center.dy,
        closeTo(rects[4].center.dy, .5),
        reason: '5 项 3+2',
      );
    });

    testWidgets('大字仍放不下时单列，不横向溢出', (tester) async {
      await pumpBoard(
        tester,
        ChipRow(
          children: [
            for (final label in ['查看期间补能记录', '里程'])
              StatusChip(label: label, onTap: () {}),
          ],
        ),
        width: 320,
        scale: 2,
      );
      final first = tester.getRect(find.widgetWithText(StatusChip, '查看期间补能记录'));
      final second = tester.getRect(find.widgetWithText(StatusChip, '里程'));
      expect(second.top, greaterThanOrEqualTo(first.bottom), reason: '单列');
      expect(tester.takeException(), isNull);
    });

    testWidgets('透明扩展满足命中：视觉 36 之外、命中 44 之内可点', (tester) async {
      var taps = 0;
      await pumpBoard(tester, StatusChip(label: '近30天', onTap: () => taps++));
      final chip = tester.getRect(find.byType(StatusChip));
      expect(chip.height, MileafSpace.touch);
      expect(
        tester.getSize(find.byKey(MileafChipKeys.capsule('近30天'))).height,
        36,
      );
      await tester.tapAt(chip.topLeft + const Offset(6, 1));
      await tester.tapAt(chip.bottomLeft + const Offset(6, -1));
      expect(taps, 2, reason: 'R27 透明扩展满足平台命中');
    });

    testWidgets('减少动效：选中底即时到位且不拉伸', (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await pumpBoard(tester, statefulRow(const ['里程', '电耗']));
      final resting = tester.getRect(lens).width;
      await tester.tap(find.text('电耗'));
      await tester.pump();
      expect(
        tester.getRect(lens).width,
        closeTo(resting, .5),
        reason: 'M02 拉伸在减少动效时归零',
      );
      expect(
        tester.getRect(lens).center.dx,
        closeTo(
          tester.getRect(find.widgetWithText(StatusChip, '电耗')).center.dx,
          .5,
        ),
        reason: 'M02 平移在减少动效时归零',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('未选 control 500 textSecondary、选中 600 text', (tester) async {
      await pumpBoard(
        tester,
        ChipRow(
          children: [
            StatusChip(label: '里程', onTap: () {}),
            StatusChip(label: '电耗', selected: true, onTap: () {}),
          ],
        ),
      );
      const colors = MileafColors.dark();
      final unselected = tester.widget<Text>(find.text('里程')).style!;
      final selected = tester.widget<Text>(find.text('电耗')).style!;
      expect(unselected.fontSize, MileafType.controlSize);
      expect(unselected.fontWeight, FontWeight.w500);
      expect(unselected.color, colors.textSecondary);
      expect(selected.fontSize, MileafType.controlSize);
      expect(selected.fontWeight, FontWeight.w600);
      expect(selected.color, colors.text);
    });

    testWidgets('选中语义即时更新，禁用项不可点', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pumpBoard(
        tester,
        Wrap(
          children: [
            StatusChip(label: '本月', selected: true, onTap: () {}),
            StatusChip(label: '禁用', enabled: false, onTap: () => taps++),
          ],
        ),
      );
      expect(
        tester.getSemantics(find.widgetWithText(StatusChip, '本月')),
        matchesSemantics(
          label: '本月',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: true,
        ),
      );
      await tester.tap(find.text('禁用'));
      expect(taps, 0);
      semantics.dispose();
    });
  });

  group('R27 期间行（分段占剩余宽度 + 行尾刷新圆钮）', () {
    testWidgets('刷新圆钮贴行右上并与第一行垂直居中', (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      await pumpBoard(
        tester,
        MileafPeriodRow(
          trailing: MileafIconButton(
            icon: MileafIconName.refresh,
            tooltip: '刷新概览',
            onPressed: () {},
          ),
          children: [
            StatusChip(label: '本月', selected: true, onTap: () {}),
            StatusChip(label: '近7天', onTap: () {}),
            StatusChip(label: '自定义', onTap: () {}),
          ],
        ),
        width: 390,
      );
      final row = tester.getRect(find.byType(MileafPeriodRow));
      final button = tester.getRect(find.byType(MileafIconButton));
      final firstChip = tester.getRect(find.widgetWithText(StatusChip, '本月'));
      expect(button.right, closeTo(row.right, .5), reason: '圆钮贴行右缘');
      expect(button.top, closeTo(row.top, .5), reason: '圆钮贴行上沿');
      expect(
        button.center.dy,
        closeTo(firstChip.center.dy, .5),
        reason: '与第一行垂直居中',
      );
      final track = tester.getRect(find.byKey(MileafChipKeys.track));
      expect(button.left, greaterThan(track.right), reason: '期间分段占剩余宽度，不与圆钮重叠');
      expect(
        track.width,
        closeTo(row.width - button.width - MileafSpace.s8, 40),
        reason: '分段拿到行内剩余宽度',
      );
    });

    testWidgets('容器可点：命中区在分段与圆钮之间不互相吞掉', (tester) async {
      var refreshes = 0;
      var selected = 0;
      await pumpBoard(
        tester,
        MileafPeriodRow(
          trailing: MileafIconButton(
            icon: MileafIconName.refresh,
            tooltip: '刷新充电',
            onPressed: () => refreshes++,
          ),
          children: [
            StatusChip(label: '本月', selected: true, onTap: () => selected = 0),
            StatusChip(label: '近7天', onTap: () => selected = 1),
          ],
        ),
      );
      await tester.tap(find.text('近7天'));
      expect(selected, 1);
      await tester.tap(find.byTooltip('刷新充电'));
      expect(refreshes, 1);
    });
  });

  group('R27 按钮（胶囊 50、文字按钮、危险操作、处理中）', () {
    testWidgets('主按钮 50 高胶囊、headline 文字、accentStrong 填充', (tester) async {
      await pumpBoard(tester, MileafButton(label: '确认补录', onPressed: () {}));
      const colors = MileafColors.dark();
      expect(tester.getSize(find.byType(MileafButton)).height, 50);
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(MileafButton),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, colors.accentStrong);
      expect(material.borderRadius, BorderRadius.circular(MileafRadius.full));
      final text = tester.widget<Text>(find.text('确认补录')).style!;
      expect(text.fontSize, MileafType.headlineSize);
      expect(text.fontWeight, FontWeight.w600);
      expect(text.color, colors.textOnAccent);
    });

    testWidgets('次按钮 50 高、accentSoft 填充 + accentStrong control 文字', (
      tester,
    ) async {
      await pumpBoard(
        tester,
        MileafButton(
          label: '取消',
          kind: MileafButtonKind.secondary,
          onPressed: () {},
        ),
      );
      const colors = MileafColors.dark();
      expect(tester.getSize(find.byType(MileafButton)).height, 50);
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(MileafButton),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, colors.accentSoft);
      final text = tester.widget<Text>(find.text('取消')).style!;
      expect(text.fontSize, MileafType.controlSize);
      expect(text.color, colors.accentStrong);
    });

    testWidgets('文字按钮 accentStrong body 400、命中不低于 44', (tester) async {
      var taps = 0;
      await pumpBoard(
        tester,
        MileafButton(
          label: '查看全部',
          kind: MileafButtonKind.ghost,
          onPressed: () => taps++,
        ),
      );
      const colors = MileafColors.dark();
      final text = tester.widget<Text>(find.text('查看全部')).style!;
      expect(text.fontSize, MileafType.bodySize);
      expect(text.fontWeight, FontWeight.w400);
      expect(text.color, colors.accentStrong);
      expect(
        tester.getSize(find.byType(MileafButton)).height,
        greaterThanOrEqualTo(MileafSpace.touch),
      );
      await tester.tap(find.text('查看全部'));
      expect(taps, 1);
    });

    testWidgets('危险操作用 error 文字，确认流程不变（仍由页面负责）', (tester) async {
      await pumpBoard(
        tester,
        MileafButton(
          label: '清除已保存的 Key',
          kind: MileafButtonKind.ghost,
          destructive: true,
          onPressed: () {},
        ),
      );
      expect(
        tester.widget<Text>(find.text('清除已保存的 Key')).style!.color,
        const MileafColors.dark().error,
      );
    });

    testWidgets('处理中保留文字、尾部活动指示器、宽度不跳，且阻断重复点击', (tester) async {
      var taps = 0;
      var loading = false;
      await pumpBoard(
        tester,
        StatefulBuilder(
          builder: (context, update) => Column(
            children: [
              MileafButton(
                label: '验证并连接',
                loading: loading,
                onPressed: () {
                  taps++;
                  update(() => loading = true);
                },
              ),
            ],
          ),
        ),
      );
      final width = tester.getSize(find.byType(MileafButton)).width;
      await tester.tap(find.text('验证并连接'));
      await tester.pump();
      expect(taps, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.getSize(find.byType(MileafButton)).width,
        closeTo(width, .5),
        reason: 'R27 处理中宽度不跳',
      );
      expect(find.text('验证并连接'), findsOneWidget, reason: '处理中保留文字');
      await tester.tap(find.text('验证并连接'), warnIfMissed: false);
      expect(taps, 1, reason: '处理中阻断重复点击');
    });

    testWidgets('M01 按压：缩放 0.97、覆盖层即时出现、松手 120ms 消退', (tester) async {
      await pumpBoard(tester, MileafButton(label: '保存', onPressed: () {}));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('保存')),
      );
      await tester.pump();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        MileafMotion.pressScale,
        reason: 'M01 胶囊按钮缩放到 0.97',
      );
      final overlay = tester.widget<MileafPressOverlay>(
        find.byType(MileafPressOverlay),
      );
      expect(overlay.visible, isTrue, reason: '覆盖层即时出现');
      final fade = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: find.byType(MileafPressOverlay),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(fade.duration, Duration.zero, reason: '按下不再等淡入');
      await gesture.up();
      await tester.pump();
      expect(
        tester
            .widget<MileafPressOverlay>(find.byType(MileafPressOverlay))
            .visible,
        isFalse,
      );
      final out = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: find.byType(MileafPressOverlay),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(
        out.duration,
        const Duration(milliseconds: 120),
        reason: 'M01 松手 120ms',
      );
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    });

    testWidgets('减少动效：按压不缩放，只留覆盖层', (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await pumpBoard(tester, MileafButton(label: '保存', onPressed: () {}));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('保存')),
      );
      await tester.pump();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        1,
        reason: '减少动效时 M01 缩放归零',
      );
      await gesture.up();
    });

    testWidgets('焦点环 2px 随胶囊形状立即出现', (tester) async {
      await pumpBoard(tester, MileafButton(label: '保存', onPressed: () {}));
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
      expect(border.top.width, 2);
      expect(
        border.top.color,
        const MileafColors.dark().textOnAccent,
        reason: 'primary 用反相边界',
      );
      expect(
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
            .borderRadius,
        BorderRadius.circular(MileafRadius.full),
        reason: '焦点环随胶囊形状',
      );
    });
  });

  group('R27 图标圆钮（视觉 36、命中 44/48、图标 20）', () {
    testWidgets('视觉 36 圆、命中 44、图标 20', (tester) async {
      await pumpBoard(
        tester,
        MileafIconButton(
          icon: MileafIconName.refresh,
          tooltip: '刷新概览',
          onPressed: () {},
        ),
      );
      expect(tester.getSize(find.byType(MileafIconButton)), const Size(44, 44));
      final visual = find
          .descendant(
            of: find.byType(MileafIconButton),
            matching: find.byType(DecoratedBox),
          )
          .first;
      expect(tester.getSize(visual), const Size(36, 36));
      expect(
        (tester.widget<DecoratedBox>(visual).decoration as BoxDecoration).shape,
        BoxShape.circle,
      );
      expect(
        tester.widget<MileafIcon>(find.byType(MileafIcon)).size,
        MileafIconMetrics.nav,
      );
      expect(tester.widget<MileafIcon>(find.byType(MileafIcon)).size, 20);
    });

    testWidgets('Android 命中 48', (tester) async {
      await pumpBoard(
        tester,
        MileafIconButton(
          icon: MileafIconName.refresh,
          tooltip: '刷新概览',
          onPressed: () {},
        ),
        platform: TargetPlatform.android,
      );
      expect(tester.getSize(find.byType(MileafIconButton)), const Size(48, 48));
    });

    testWidgets('画布填充用 segmentTrack，默认无填充；选中 accentSoft + accent 图标', (
      tester,
    ) async {
      const colors = MileafColors.dark();
      Color? fill() {
        final box = tester.widget<DecoratedBox>(
          find
              .descendant(
                of: find.byType(MileafIconButton),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        return (box.decoration as BoxDecoration).color;
      }

      await pumpBoard(
        tester,
        MileafIconButton(
          icon: MileafIconName.refresh,
          tooltip: '刷新行程',
          fill: MileafIconButtonFill.track,
          onPressed: () {},
        ),
      );
      expect(fill(), colors.segmentTrack);

      await pumpBoard(
        tester,
        MileafIconButton(
          icon: MileafIconName.refresh,
          tooltip: '刷新行程',
          onPressed: () {},
        ),
      );
      expect(fill(), isNull, reason: '默认不填充，其他持有票外观不变');

      await pumpBoard(
        tester,
        MileafIconButton(
          icon: MileafIconName.settings,
          tooltip: '设置',
          selected: true,
          onPressed: () {},
        ),
      );
      expect(fill(), colors.accentSoft);
      expect(
        tester.widget<MileafIcon>(find.byType(MileafIcon)).color,
        colors.accent,
      );
    });

    testWidgets('禁用 38% textFaint 且不可点，焦点环 2px', (tester) async {
      var taps = 0;
      await pumpBoard(
        tester,
        Column(
          children: [
            MileafIconButton(icon: MileafIconName.refresh, tooltip: '刷新'),
            MileafIconButton(
              icon: MileafIconName.refresh,
              tooltip: '刷新概览',
              onPressed: () => taps++,
            ),
          ],
        ),
      );
      const colors = MileafColors.dark();
      expect(
        tester.widgetList<MileafIcon>(find.byType(MileafIcon)).first.color,
        colors.textFaint.withValues(alpha: .38),
      );
      await tester.tap(find.byTooltip('刷新'), warnIfMissed: false);
      expect(taps, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final ring =
          (tester
                          .widget<DecoratedBox>(
                            find
                                .descendant(
                                  of: find.byType(MileafIconButton),
                                  matching: find.byType(DecoratedBox),
                                )
                                .first,
                          )
                          .decoration
                      as BoxDecoration)
                  .border
              as Border;
      expect(ring.top.width, 2);
      expect(ring.top.color, colors.focusRing);
    });

    testWidgets('按压覆盖层为 accentSoft，无涟漪', (tester) async {
      await pumpBoard(
        tester,
        MileafIconButton(
          icon: MileafIconName.refresh,
          tooltip: '刷新概览',
          onPressed: () {},
        ),
      );
      expect(
        tester
            .widget<MileafPressOverlay>(find.byType(MileafPressOverlay))
            .color,
        const MileafColors.dark().accentSoft,
      );
      expect(
        tester
            .widget<InkWell>(
              find
                  .descendant(
                    of: find.byType(MileafIconButton),
                    matching: find.byType(InkWell),
                  )
                  .first,
            )
            .highlightColor,
        Colors.transparent,
        reason: '§4 M01 无涟漪，覆盖层由 MileafPressOverlay 计时',
      );
    });
  });

  group('R27 下拉（小胶囊 32 + R28 菜单）', () {
    Widget pullDown({ValueChanged<String>? onChanged}) =>
        MileafPullDown<String>(
          label: '类型',
          value: 'all',
          onChanged: onChanged ?? (_) {},
          options: const [
            MileafPullDownOption(value: 'all', label: '全部类型'),
            MileafPullDownOption(value: 'ac', label: 'AC'),
            MileafPullDownOption(value: 'dc', label: 'DC'),
          ],
        );

    testWidgets('小胶囊高 32、segmentTrack 底、control 文字与向下箭头', (tester) async {
      await pumpBoard(tester, pullDown());
      const colors = MileafColors.dark();
      expect(tester.getSize(find.byType(MileafPullDown<String>)).height, 32);
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(MileafPullDown<String>),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, colors.segmentTrack);
      expect(decoration.borderRadius, BorderRadius.circular(MileafRadius.full));
      final text = tester.widget<Text>(find.text('全部类型')).style!;
      expect(text.fontSize, MileafType.controlSize);
      expect(
        tester.widget<MileafIcon>(find.byType(MileafIcon)).name,
        MileafIconName.chevronDown,
      );
    });

    testWidgets('菜单玻璃背板、半径 14、行高 44、选中项尾部勾选', (tester) async {
      await pumpBoard(tester, pullDown());
      await tester.tap(find.byType(MileafPullDown<String>));
      await tester.pumpAndSettle();
      // CL30/CL31：浮层菜单的背板由 surfaceRaised 实色改为玻璃（与底栏同参数）。
      final surface = find.byKey(kPullDownMenuSurfaceKey);
      expect(surface, findsOneWidget);
      expect(
        tester.widget(surface),
        isA<MileafGlassSurface>(),
        reason: '菜单背板是共享玻璃，不是自绘的第三种材质',
      );
      expect(
        tester.widget<MileafGlassSurface>(surface).borderRadius,
        BorderRadius.circular(MileafControlMetrics.menuRadius),
      );
      expect(
        find.descendant(of: surface, matching: find.byType(BackdropFilter)),
        findsOneWidget,
      );
      // 行高 44、菜单上下各留 s8（R28 几何不变）。
      final rect = tester.getRect(surface);
      expect(
        rect.height,
        MileafControlMetrics.menuRowHeight * 3 + MileafSpace.s16,
      );
      expect(
        tester.getCenter(find.text('AC')).dy -
            tester
                .getCenter(
                  find.descendant(of: surface, matching: find.text('全部类型')),
                )
                .dy,
        MileafControlMetrics.menuRowHeight,
      );
      // 选中项尾部勾选，只出现一次。
      expect(find.byType(MileafIcon), findsWidgets);
      final check = tester
          .widgetList<MileafIcon>(find.byType(MileafIcon))
          .where((icon) => icon.name == MileafIconName.check)
          .length;
      expect(check, 1);
    });

    testWidgets('选择后回调新值并关闭菜单', (tester) async {
      String? picked;
      await pumpBoard(tester, pullDown(onChanged: (value) => picked = value));
      await tester.tap(find.byType(MileafPullDown<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DC'));
      await tester.pumpAndSettle();
      expect(picked, 'dc');
      expect(
        find.byKey(kPullDownMenuSurfaceKey),
        findsNothing,
        reason: '选择后菜单关闭（浮层玻璃整块撤掉）',
      );
    });

    testWidgets('读屏标签带对象名与当前值', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpBoard(tester, pullDown());
      expect(find.bySemanticsLabel('类型 全部类型'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('R27 选择列表（只勾选、不填充）', () {
    Widget list({String value = 'complete', ValueChanged<String>? onChanged}) =>
        MileafSelectionList<String>(
          semanticLabel: '停车记录状态',
          value: value,
          onChanged: onChanged ?? (_) {},
          options: const [
            MileafSelectionOption(value: 'complete', label: '完整'),
            MileafSelectionOption(
              value: 'partial',
              label: '状态记录不完整',
              subtitle: '仍计入',
            ),
          ],
        );

    testWidgets('选中只显示尾部勾选，不填充底色', (tester) async {
      const colors = MileafColors.dark();
      await pumpBoard(tester, list());
      expect(find.byIcon(Icons.check), findsNothing);
      final checks = tester
          .widgetList<MileafIcon>(find.byType(MileafIcon))
          .where((icon) => icon.name == MileafIconName.check)
          .toList();
      expect(checks.length, 1);
      expect(checks.single.color, colors.accent);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).color == colors.accentSoft,
        ),
        findsNothing,
        reason: 'R23.4 选中行不填充 accentSoft',
      );
    });

    testWidgets('单行 52、双行 64、标题 body 400', (tester) async {
      await pumpBoard(tester, list());
      final single = tester.getRect(
        find
            .ancestor(of: find.text('完整'), matching: find.byType(InkWell))
            .first,
      );
      final doubleLine = tester.getRect(
        find
            .ancestor(of: find.text('状态记录不完整'), matching: find.byType(InkWell))
            .first,
      );
      expect(single.height, 52);
      expect(doubleLine.height, 64);
      expect(
        tester.widget<Text>(find.text('完整')).style!.fontWeight,
        FontWeight.w400,
      );
      expect(
        tester.widget<Text>(find.text('完整')).style!.fontSize,
        MileafType.bodySize,
      );
    });

    testWidgets('语义带 selected，点按回调新值', (tester) async {
      final semantics = tester.ensureSemantics();
      String? picked;
      await pumpBoard(tester, list(onChanged: (value) => picked = value));
      expect(
        tester.getSemantics(find.text('完整')),
        matchesSemantics(
          label: '完整',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: true,
        ),
      );
      await tester.tap(find.text('状态记录不完整'));
      expect(picked, 'partial');
      semantics.dispose();
    });

    testWidgets('禁用行不可点，文字退到 38% textFaint', (tester) async {
      var picked = 0;
      await pumpBoard(
        tester,
        MileafSelectionList<String>(
          value: 'a',
          onChanged: (_) => picked++,
          options: const [
            MileafSelectionOption(value: 'a', label: '自动', enabled: false),
          ],
        ),
      );
      await tester.tap(find.text('自动'), warnIfMissed: false);
      expect(picked, 0);
      expect(
        tester.widget<Text>(find.text('自动')).style!.color,
        const MileafColors.dark().textFaint.withValues(alpha: .38),
      );
    });
  });

  group('R28 弹层（浮动 / 贴边、headline 标题、焦点返回）', () {
    Future<void> open(
      WidgetTester tester, {
      MileafSheetStyle? style,
      double width = 390,
    }) async {
      await pumpBoard(
        tester,
        Builder(
          builder: (context) => MileafButton(
            label: '打开',
            onPressed: () => showMileafSheet<void>(
              context: context,
              title: '选择车辆',
              style: style,
              builder: (_) =>
                  const Column(children: [Text('白露'), SizedBox(height: 240)]),
            ),
          ),
        ),
        width: width,
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
    }

    testWidgets('浮动样式：左右下各留 8、四角 28、正文 surfaceRaised', (tester) async {
      const colors = MileafColors.dark();
      await open(tester, style: MileafSheetStyle.floating);
      final surface = find.byKey(const ValueKey('sheet-surface'));
      final rect = tester.getRect(surface);
      expect(rect.left, 8);
      expect(rect.right, 390 - 8);
      expect(rect.bottom, closeTo(844 - 8, .5));
      final decoration =
          tester.widget<DecoratedBox>(surface).decoration as BoxDecoration;
      expect(decoration.color, colors.surfaceRaised);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(MileafRadius.sheet),
      );
      expect(decoration.boxShadow, isNotNull, reason: '浮层才有阴影');
      expect(find.text('选择车辆'), findsOneWidget);
    });

    testWidgets('贴边样式：顶部半径 28、正文 surfaceRaised、无浮层阴影', (tester) async {
      const colors = MileafColors.dark();
      await open(tester, style: MileafSheetStyle.edge);
      final surface = find.byKey(const ValueKey('sheet-surface'));
      final decoration =
          tester.widget<DecoratedBox>(surface).decoration as BoxDecoration;
      expect(decoration.color, colors.surfaceRaised);
      expect(
        decoration.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(MileafRadius.sheet)),
      );
      expect(decoration.boxShadow ?? const <BoxShadow>[], isEmpty);
      expect(tester.getRect(surface).left, 0, reason: '贴边');
      expect(tester.getRect(surface).width, 390);
    });

    testWidgets('不给样式时维持现有几何（合入不变）', (tester) async {
      await open(tester);
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('sheet-surface')),
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color, isNull, reason: '沿用主题表面色，行为合同不变');
      expect(decoration.boxShadow ?? const <BoxShadow>[], isEmpty);
    });

    testWidgets('标题 headline 左对齐 + 关闭圆钮，内容单一滚动', (tester) async {
      await open(tester, style: MileafSheetStyle.edge);
      final title = tester.widget<Text>(find.text('选择车辆')).style!;
      expect(title.fontSize, MileafType.headlineSize);
      expect(title.fontWeight, FontWeight.w600);
      expect(find.byTooltip('关闭'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MileafSheetFrame),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
        reason: 'R28 内容单一滚动',
      );
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(find.text('选择车辆'), findsNothing);
    });

    testWidgets('关闭后焦点回到触发控件', (tester) async {
      final trigger = FocusNode();
      addTearDown(trigger.dispose);
      await pumpBoard(
        tester,
        Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Focus(
                focusNode: trigger,
                child: const SizedBox(width: 44, height: 44),
              ),
              MileafButton(
                label: '打开',
                onPressed: () => showMileafSheet<void>(
                  context: context,
                  title: '选择车辆',
                  style: MileafSheetStyle.floating,
                  builder: (_) => const Text('白露'),
                ),
              ),
            ],
          ),
        ),
      );
      trigger.requestFocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, trigger);
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus,
        trigger,
        reason: 'R28 关闭后焦点回到触发控件',
      );
    });

    testWidgets('M05 时长 280/220，减少动效时一帧内到位', (tester) async {
      expect(MileafDurations.sheetIn, const Duration(milliseconds: 280));
      expect(MileafDurations.sheetOut, const Duration(milliseconds: 220));
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await open(tester, style: MileafSheetStyle.floating);
      expect(find.text('选择车辆'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const ValueKey('sheet-surface'))).bottom,
        closeTo(844 - 8, .5),
        reason: '减少动效下弹层一帧内到终态',
      );
    });

    testWidgets('键盘 viewInsets 让内容避让：滚动区仍在且末项可滚到键盘之上', (tester) async {
      await pumpBoard(
        tester,
        Builder(
          builder: (context) => MileafButton(
            label: '打开',
            onPressed: () => showMileafSheet<void>(
              context: context,
              title: '补录费用',
              style: MileafSheetStyle.edge,
              builder: (_) => const Column(
                children: [Text('白露'), SizedBox(height: 240), Text('尾部')],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final scroll = find
          .descendant(
            of: find.byType(MileafSheetFrame),
            matching: find.byType(SingleChildScrollView),
          )
          .last;
      expect(
        tester.getRect(scroll).height,
        greaterThan(0),
        reason: '键盘弹出后单一滚动区仍可用',
      );
      await tester.drag(scroll, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('尾部')).bottom,
        lessThan(844 - 300),
        reason: 'R28 键盘按 viewInsets 避让，末项可滚到键盘之上',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('R27 日期区间弹层（共享、平台选择器、键盘路径、校验注入）', () {
    final firstDate = DateTime(2024, 1, 1);
    final lastDate = DateTime(2026, 11, 17);
    final today = DateTime(2026, 11, 17);

    /// 打开弹层的入口；返回读取结果的闭包。
    Future<DateTimeRange? Function()> launch(
      WidgetTester tester, {
      required DateTimeRange initialRange,
      MileafDateRangeValidator? validator,
      DateTime? todayOverride,
      TargetPlatform platform = TargetPlatform.iOS,
    }) async {
      DateTimeRange? result;
      await pumpBoard(
        platform: platform,
        tester,
        Builder(
          builder: (context) => MileafButton(
            label: '打开',
            onPressed: () async {
              result = await showMileafDateRangeSheet(
                context: context,
                initialRange: initialRange,
                firstDate: firstDate,
                lastDate: lastDate,
                today: todayOverride ?? today,
                validator: validator,
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
      return () => result;
    }

    final october = DateTimeRange(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 26),
    );

    testWidgets('两行开始/结束、脚注包含结束当天、主按钮应用', (tester) async {
      await launch(tester, initialRange: october);
      expect(find.text('选择日期'), findsOneWidget);
      expect(find.text('开始'), findsOneWidget);
      expect(find.text('结束'), findsOneWidget);
      expect(find.text('10月1日'), findsOneWidget);
      expect(find.text('10月26日'), findsOneWidget);
      expect(find.text('应用'), findsOneWidget);
      expect(find.text('包含结束当天'), findsOneWidget);
      expect(find.text('改为输入'), findsOneWidget);
      // 组件不写业务口径，脚注只写一次包含结束当天（CP04）。
      expect(find.textContaining('含首尾'), findsNothing);
    });

    testWidgets('点按行展开 iOS 平台日期选择器', (tester) async {
      await launch(tester, initialRange: october);
      expect(find.byType(CupertinoDatePicker), findsNothing);
      await tester.tap(find.text('开始'));
      await tester.pumpAndSettle();
      final picker = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(picker.mode, CupertinoDatePickerMode.date);
      expect(picker.minimumDate, firstDate);
      expect(picker.maximumDate, lastDate);
      await tester.tap(find.text('结束'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Android 用 CalendarDatePicker', (tester) async {
      await launch(
        tester,
        initialRange: october,
        platform: TargetPlatform.android,
      );
      await tester.tap(find.text('开始'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarDatePicker), findsOneWidget);
      expect(find.byType(CupertinoDatePicker), findsNothing);
    });

    testWidgets('改为输入：非法日期就地报错，合法日期回传区间', (tester) async {
      final result = await launch(tester, initialRange: october);
      await tester.tap(find.text('改为输入'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('date-range-start-input')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('date-range-start-input')),
        '2026-02-31',
      );
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      expect(find.text('请输入有效日期'), findsOneWidget);
      expect(find.text('选择日期'), findsOneWidget, reason: '校验失败不关闭');

      await tester.enterText(
        find.byKey(const ValueKey('date-range-start-input')),
        '2026-03-01',
      );
      await tester.enterText(
        find.byKey(const ValueKey('date-range-end-input')),
        '2026-03-30',
      );
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      final range = result();
      expect(range, isNotNull);
      expect(range!.start, DateTime(2026, 3, 1));
      expect(range.end, DateTime(2026, 3, 30));
      expect(find.text('选择日期'), findsNothing, reason: '应用后关闭');
    });

    testWidgets('校验回调由调用方注入：返回错误时不关闭', (tester) async {
      await launch(
        tester,
        initialRange: october,
        validator: (start, end) => end.isBefore(start) ? '开始日期不能晚于结束日期' : null,
      );
      await tester.tap(find.text('改为输入'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('date-range-start-input')),
        '2026-03-30',
      );
      await tester.enterText(
        find.byKey(const ValueKey('date-range-end-input')),
        '2026-03-01',
      );
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      expect(find.text('开始日期不能晚于结束日期'), findsOneWidget);
      expect(find.text('选择日期'), findsOneWidget, reason: '业务校验失败不关闭');
    });

    testWidgets('组件不内置业务规则：730 天以上仍可应用', (tester) async {
      final wide = DateTimeRange(
        start: DateTime(2024, 1, 1),
        end: DateTime(2026, 11, 1),
      );
      final result = await launch(tester, initialRange: wide);
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      final range = result();
      expect(range, isNotNull, reason: 'R27：业务校验由调用方注入，组件不内置');
      expect(range!.start, DateTime(2024, 1, 1));
      expect(range.end, DateTime(2026, 11, 1));
    });

    testWidgets('跨年区间按 DF1 两端带年', (tester) async {
      await launch(
        tester,
        initialRange: DateTimeRange(
          start: DateTime(2025, 12, 28),
          end: DateTime(2026, 1, 3),
        ),
        todayOverride: DateTime(2026, 1, 5),
      );
      // DF1：非今年加年，今年只写 M月D日。
      expect(find.text('2025年12月28日'), findsOneWidget);
      expect(find.text('1月3日'), findsOneWidget);
    });
  });

  group('文案（CP09、CP12）', () {
    testWidgets('组件文案无点号拼接、无占位符与箭头代替词', (tester) async {
      await pumpBoard(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ChipRow(
              children: [
                StatusChip(label: '本月', selected: true, onTap: () {}),
                StatusChip(label: '自定义', onTap: () {}),
              ],
            ),
            MileafButton(label: '应用', onPressed: () {}),
            MileafButton(
              label: '取消',
              kind: MileafButtonKind.secondary,
              onPressed: () {},
            ),
            MileafPullDown<String>(
              label: '类型',
              value: 'all',
              onChanged: (_) {},
              options: const [
                MileafPullDownOption(value: 'all', label: '全部类型'),
              ],
            ),
            MileafSelectionList<String>(
              value: 'a',
              onChanged: (_) {},
              options: const [MileafSelectionOption(value: 'a', label: '完整')],
            ),
          ],
        ),
      );
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data ?? '')
          .toList();
      for (final text in texts) {
        expect(text.contains('·'), isFalse, reason: 'CP09.1 点号拼接：$text');
        expect(
          text.contains('YYYY-MM-DD'),
          isFalse,
          reason: 'CP09.3 占位符：$text',
        );
        expect(
          text.contains('↑') || text.contains('↓'),
          isFalse,
          reason: 'CP09.4 符号：$text',
        );
        expect(text.contains('›'), isFalse, reason: 'CP09.6 行尾箭头字符：$text');
      }
    });
  });
}
