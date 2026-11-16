import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/glass_surface.dart';
import 'package:mileaf/src/design/components/nav_bar.dart';
import 'package:mileaf/src/design/components/navigation_material.dart';
import 'package:mileaf/src/design/display_preferences.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/tokens.dart';

import 'support/color_math.dart';

/// 液态玻璃底栏（ADR 0013）的合同 L01–L09。像素级对比由
/// `liquid_glass_nav_render_test.dart` 在真机位渲染上断言。
Widget _shell({
  required DisplayPreferencesController preferences,
  Brightness brightness = Brightness.light,
  bool highContrast = false,
  bool reduceMotion = false,
  bool forceSolid = false,
  int index = 0,
  ValueChanged<int>? onSelected,
  Size size = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
}) => DisplayPreferencesScope(
  controller: preferences,
  child: MaterialApp(
    theme: mileafTheme(brightness),
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: textScaler,
        devicePixelRatio: 2,
        highContrast: highContrast,
        disableAnimations: reduceMotion,
        viewPadding: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.only(bottom: 24),
      ),
      child: Scaffold(
        body: const SizedBox.expand(),
        bottomNavigationBar: MileafNavBar(
          index: index,
          forceSolid: forceSolid,
          onSelected: onSelected ?? (_) {},
        ),
      ),
    ),
  ),
);

void _setView(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(bottom: 24);
  tester.view.padding = tester.view.viewPadding;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewPadding();
    tester.view.resetPadding();
  });
}

DisplayPreferencesController _transparent() =>
    DisplayPreferencesController(platform: DisplayPreferencesPlatform.android);

/// 真实切换一次目的地：底栏自己不改 index，动画由外层状态驱动。
class _Harness extends StatefulWidget {
  const _Harness({required this.preferences, this.reduceMotion = false});

  final DisplayPreferencesController preferences;
  final bool reduceMotion;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  var index = 0;
  int? selected;

  @override
  Widget build(BuildContext context) => _shell(
    preferences: widget.preferences,
    reduceMotion: widget.reduceMotion,
    index: index,
    onSelected: (value) => setState(() {
      selected = value;
      index = value;
    }),
  );
}

void main() {
  testWidgets('L01 玻璃路径只有一层有界模糊，其余路径完全实色', (tester) async {
    final preferences = _transparent();
    addTearDown(preferences.dispose);

    await tester.pumpWidget(_shell(preferences: preferences));
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(MileafGlassSurface), findsOneWidget);

    await tester.pumpWidget(
      _shell(preferences: preferences, highContrast: true),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(MileafGlassSurface), findsNothing);

    await tester.pumpWidget(_shell(preferences: preferences, forceSolid: true));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(MileafGlassSurface), findsNothing);

    // 未知透明度偏好（iOS 启动期）同样走实色，几何不变。
    final unknown = DisplayPreferencesController(
      platform: DisplayPreferencesPlatform.iOS,
      readReduceTransparency: () async => false,
    );
    addTearDown(unknown.dispose);
    await tester.pumpWidget(_shell(preferences: unknown));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(
      tester.getSize(find.byType(NavigationMaterial)).height,
      greaterThanOrEqualTo(MileafSpace.navHeight),
    );
  });

  testWidgets('L02 玻璃是胶囊：外距 16、下距 8、最小高 64、最大宽 528', (tester) async {
    _setView(tester);
    final preferences = _transparent();
    addTearDown(preferences.dispose);
    await tester.pumpWidget(_shell(preferences: preferences));

    final surface = tester.getRect(find.byType(MileafGlassSurface));
    expect(surface.left, 16);
    expect(surface.right, 390 - 16);
    expect(surface.height, 64);

    final clip = tester.widget<ClipRRect>(
      find
          .descendant(
            of: find.byType(MileafGlassSurface),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    expect(clip.borderRadius, MileafRadius.fullAll);

    final bodies = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is LiquidGlassPainter,
    );
    expect(bodies, findsNWidgets(2), reason: '底栏与选中镜片各一层玻璃');
    final painter =
        tester.widget<CustomPaint>(bodies.first).painter! as LiquidGlassPainter;
    expect(painter.sheen, isNotNull);
    expect(painter.meniscus, isNotNull);
    expect(painter.edge.top, isNot(painter.edge.bottom));

    // 宽屏不拉伸：胶囊封顶 528 并居中。
    _setView(tester, size: const Size(768, 1024));
    await tester.pumpWidget(
      _shell(preferences: preferences, size: const Size(768, 1024)),
    );
    final wide = tester.getRect(find.byType(MileafGlassSurface));
    expect(wide.width, 528);
    expect(wide.left, (768 - 528) / 2);
  });

  testWidgets('L03 选中镜片是同一胶囊里的第二层玻璃', (tester) async {
    _setView(tester);
    final preferences = _transparent();
    addTearDown(preferences.dispose);
    await tester.pumpWidget(_shell(preferences: preferences, index: 0));

    final lens = find.byKey(const ValueKey('nav-selection-surface'));
    expect(lens, findsOneWidget);
    expect(find.byType(MileafGlassLens), findsOneWidget);
    final rect = tester.getRect(lens);
    expect(rect.height, 64 - MileafSpace.s12);
    final surface = tester.getRect(find.byType(MileafGlassSurface));
    expect(surface.contains(rect.topLeft), isTrue);
    expect(surface.contains(rect.bottomRight), isTrue);

    final colors = MileafColors.of(tester.element(lens));
    final inactive = tester.widget<Text>(
      find.descendant(of: find.byType(MileafNavBar), matching: find.text('行程')),
    );
    expect(inactive.style?.color, colors.textMuted);
    final active = tester.widget<Text>(
      find.descendant(of: find.byType(MileafNavBar), matching: find.text('概览')),
    );
    expect(active.style?.color, colors.accentStrong);
  });

  testWidgets('L04 高透仍可读：标签 ≥4.5、图标 ≥3（token 合成）', (tester) async {
    for (final brightness in Brightness.values) {
      final colors = brightness == Brightness.dark
          ? const MileafColors.dark()
          : const MileafColors.light();
      for (final backdrop in [colors.canvas, colors.surface]) {
        for (final fill in [colors.glassFillTop, colors.glassFillBottom]) {
          final glass = compositeOver(fill, fill.a, backdrop);
          final lens = compositeOver(
            colors.glassLensTop,
            colors.glassLensTop.a,
            glass,
          );
          final where = '$brightness / $backdrop / $fill';
          expect(
            contrastRatio(colors.textMuted, glass),
            greaterThanOrEqualTo(4.5),
            reason: '未选标签 $where',
          );
          expect(
            contrastRatio(colors.accentStrong, lens),
            greaterThanOrEqualTo(4.5),
            reason: '选中标签 $where',
          );
          expect(
            contrastRatio(colors.accent, lens),
            greaterThanOrEqualTo(3),
            reason: '选中图标 $where',
          );
        }
      }
    }
  });

  testWidgets('L05 镜片位移 180ms、起步 1.06 回落，减动效时不过冲', (tester) async {
    final preferences = _transparent();
    addTearDown(preferences.dispose);

    double lensScaleX() => tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byKey(const ValueKey('nav-selection')),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .storage[0];

    await tester.pumpWidget(_Harness(preferences: preferences));
    final align = tester.widget<AnimatedAlign>(
      find.byKey(const ValueKey('nav-selection')),
    );
    expect(align.duration, MileafDurations.selection);
    expect(MileafDurations.selection, const Duration(milliseconds: 180));
    expect(MileafMaterialMetrics.glassLensStretch, greaterThan(1));

    expect(lensScaleX(), 1, reason: '首帧不做过冲');
    await tester.tap(find.text('统计'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(lensScaleX(), greaterThan(1));
    expect(tester.state<_HarnessState>(find.byType(_Harness)).selected, 3);
    await tester.pumpAndSettle();
    expect(lensScaleX(), moreOrLessEquals(1, epsilon: .01));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      _Harness(preferences: preferences, reduceMotion: true),
    );
    expect(
      tester
          .widget<AnimatedAlign>(find.byKey(const ValueKey('nav-selection')))
          .duration,
      Duration.zero,
    );
    await tester.tap(find.text('充电'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(lensScaleX(), 1);
  });

  testWidgets('L06 玻璃只叠本模式中性色：下浓上淡、顶边亮于底边', (tester) async {
    final light = const MileafColors.light();
    final dark = const MileafColors.dark();
    expect(light.glassFillTop, isNot(dark.glassFillTop));
    for (final colors in [light, dark]) {
      expect(colors.glassFillBottom.a, greaterThan(colors.glassFillTop.a));
      expect(colors.glassEdge.top.a, greaterThan(colors.glassEdge.bottom.a));
      expect(colors.glassLensTop.a, greaterThan(colors.glassLensBottom.a));
    }
    // 浅色内缘收暗，深色内缘提亮——同一 token 表达两种极性。
    expect(luminance(light.glassEdge.inner), lessThan(luminance(light.canvas)));
    expect(
      luminance(dark.glassEdge.inner),
      greaterThan(luminance(dark.canvas)),
    );

    _setView(tester);
    final preferences = _transparent();
    addTearDown(preferences.dispose);
    await tester.pumpWidget(
      _shell(preferences: preferences, brightness: Brightness.dark),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(tester.getSize(find.byType(MileafGlassSurface)).height, 64);
  });

  testWidgets('L07 阴影由挖孔 painter 承担，玻璃身下没有 BoxShadow', (tester) async {
    _setView(tester);
    final preferences = _transparent();
    addTearDown(preferences.dispose);
    await tester.pumpWidget(_shell(preferences: preferences));

    final shadowPainters = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is LiquidGlassShadowPainter,
    );
    expect(shadowPainters, findsNWidgets(2), reason: '底栏与镜片各一次');
    final colors = MileafColors.of(
      tester.element(find.byType(MileafGlassSurface)),
    );
    final painter =
        tester.widget<CustomPaint>(shadowPainters.first).painter!
            as LiquidGlassShadowPainter;
    expect(painter.shadows, colors.glassShadow);

    // 玻璃身下不能有 decoration 阴影：那会被薄玻璃透成栏内灰带。
    final decorated = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).boxShadow != null,
    );
    expect(
      find.descendant(of: find.byType(MileafNavBar), matching: decorated),
      findsNothing,
    );
  });

  testWidgets('L08 实色路径的镜片用 navigationSelection 并保持同几何', (tester) async {
    _setView(tester);
    final preferences = _transparent();
    addTearDown(preferences.dispose);

    await tester.pumpWidget(_shell(preferences: preferences, index: 2));
    final glass = tester.getRect(
      find.byKey(const ValueKey('nav-selection-surface')),
    );

    await tester.pumpWidget(
      _shell(preferences: preferences, index: 2, forceSolid: true),
    );
    final solidLens = tester.getRect(
      find.byKey(const ValueKey('nav-selection-surface')),
    );
    expect(solidLens.size, glass.size);

    final colors = MileafColors.of(
      tester.element(find.byKey(const ValueKey('nav-selection-surface'))),
    );
    final decoration =
        tester
                .widget<DecoratedBox>(
                  find.byKey(const ValueKey('nav-selection-surface')),
                )
                .decoration
            as BoxDecoration;
    expect(decoration.color, colors.navigationSelection);
    expect(decoration.color, isNot(colors.surface), reason: '不回到白底浮白块');
    expect(decoration.borderRadius, MileafRadius.fullAll);
  });

  testWidgets('L09 320 宽 + 200% 字号仍是完整胶囊，四个标签可见', (tester) async {
    _setView(tester, size: const Size(320, 720));
    final preferences = _transparent();
    addTearDown(preferences.dispose);
    await tester.pumpWidget(
      _shell(
        preferences: preferences,
        size: const Size(320, 720),
        textScaler: const TextScaler.linear(2),
      ),
    );
    expect(tester.takeException(), isNull);

    final surface = tester.getRect(find.byType(MileafGlassSurface));
    expect(surface.left, 16);
    expect(surface.right, 320 - 16);
    expect(surface.height, greaterThan(MileafSpace.navHeight));

    final lens = tester.getRect(
      find.byKey(const ValueKey('nav-selection-surface')),
    );
    expect(lens.width, greaterThan(0));
    expect(surface.contains(lens.topLeft), isTrue);
    expect(surface.contains(lens.bottomRight), isTrue);
    for (final label in ['概览', '行程', '充电', '统计']) {
      expect(
        tester.getSize(find.text(label)).width,
        greaterThan(0),
        reason: label,
      );
    }
  });
}
