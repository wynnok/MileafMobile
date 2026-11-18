import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/glass_surface.dart';
import 'package:mileaf/src/design/components/nav_bar.dart';
import 'package:mileaf/src/design/components/navigation_material.dart';
import 'package:mileaf/src/design/display_preferences.dart';
import 'package:mileaf/src/design/icons.dart';
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
    // 2026-11-18 修订：玻璃变薄后未选目的地改用底栏专属的 navigationLabel
    // （浅 #3A444E / 深 #C9D3DD），页面次级灰 textMuted 在透出的内容上不足
    // 4.5:1；选中图标也随文字改用 accentStrong（accent 在亮镜片上只剩 3.0）。
    expect(inactive.style?.color, colors.navigationLabel);
    expect(colors.navigationLabel, isNot(colors.textMuted));
    final active = tester.widget<Text>(
      find.descendant(of: find.byType(MileafNavBar), matching: find.text('概览')),
    );
    expect(active.style?.color, colors.accentStrong);
  });

  testWidgets('L04 高透仍可读：标签 ≥4.5、图标 ≥3（token 合成）', (tester) async {
    // token 口径只叠「填充 + 弯月」在标签带（0.72）上的合成；受光带在该高度
    // 已经散尽，端头增厚只压两端。渲染像素口径由 opt-in 的
    // liquid_glass_nav_render_test 断言，两者都不通过即红。
    for (final brightness in Brightness.values) {
      final colors = brightness == Brightness.dark
          ? const MileafColors.dark()
          : const MileafColors.light();
      for (final backdrop in [colors.canvas, colors.surface]) {
        final glass = _glassAt(colors, backdrop, _kLabelBand);
        final lens = compositeOver(
          colors.glassLensTop,
          colors.glassLensTop.a,
          glass,
        );
        final where = '$brightness / $backdrop';
        expect(
          contrastRatio(colors.navigationLabel, glass),
          greaterThanOrEqualTo(4.5),
          reason: '未选标签 $where',
        );
        expect(
          contrastRatio(colors.accentStrong, lens),
          greaterThanOrEqualTo(4.5),
          reason: '选中标签 $where',
        );
        // 选中图形与选中文字同色（L03/L12），文字下限更严，图形下限随之满足。
        expect(
          contrastRatio(colors.accentStrong, lens),
          greaterThanOrEqualTo(3),
          reason: '选中图标 $where',
        );
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

  // ADR0014 PD05 修订 L09：标签放大封顶 1.35×，封顶的补偿是长按大内容查看器
  // （M10，见 test/apple_polish_ap02_test.dart）；胶囊几何本身不变。
  testWidgets('L09（ADR0014 修订）320 宽 + 200% 字号仍是完整胶囊，标签封顶 1.35×', (
    tester,
  ) async {
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
    final cappedLabel = MileafType.navLabelHeight * MileafNavBar.labelMaxScale;
    expect(
      surface.height,
      closeTo(
        MileafSpace.navHeight + (cappedLabel - MileafType.navLabelHeight),
        .01,
      ),
      reason: '栏高只按封顶后的标签增高（ADR0014 PD05）',
    );
    expect(
      MediaQuery.textScalerOf(tester.element(find.text('概览')))
          .scale(MileafType.navLabelSize),
      closeTo(MileafType.navLabelSize * MileafNavBar.labelMaxScale, .01),
    );

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

  // 2026-11-18「液态玻璃再透一层」：L10–L12 固定新的材质口径。
  testWidgets('L10 透光率有上限：标签带叠色不超过阈值，顶边仍有受光带', (tester) async {
    for (final brightness in Brightness.values) {
      final colors = brightness == Brightness.dark
          ? const MileafColors.dark()
          : const MileafColors.light();
      final ceiling = brightness == Brightness.dark ? .52 : .32;
      final labelBand = _veilAlpha(colors, _kLabelBand);
      expect(
        labelBand,
        lessThanOrEqualTo(ceiling),
        reason: '$brightness 标签带总叠色 $labelBand 超过 $ceiling：背后内容会被洗掉',
      );
      expect(
        _veilAlpha(colors, 0),
        greaterThanOrEqualTo(.2),
        reason: '$brightness 顶边必须仍有受光带（不是一层空气）',
      );
    }
  });

  testWidgets('L11 受光带、弯月、端头增厚真的接到画布参数上', (tester) async {
    _setView(tester);
    final preferences = _transparent();
    addTearDown(preferences.dispose);
    await tester.pumpWidget(_shell(preferences: preferences));

    final painter = _surfacePainter(tester);
    expect(painter.sheen, isNotNull);
    expect(painter.meniscus, isNotNull);
    expect(painter.lip, isNotNull);
    // 三项曾经被留成默认值（reach 0 / start 1 / reach 0），等于画了看不见的带。
    expect(painter.sheenReach, MileafMaterialMetrics.glassSheenReach);
    expect(painter.sheenCore, MileafMaterialMetrics.glassSheenCore);
    expect(painter.meniscusStart, MileafMaterialMetrics.glassMeniscusStart);
    expect(painter.lipReach, MileafMaterialMetrics.glassLipReach);
    expect(painter.sheenReach, greaterThan(painter.sheenCore));
    expect(painter.sheenCore, greaterThan(0));
    expect(painter.meniscusStart, lessThan(1));
    expect(painter.lipReach, greaterThan(0));
    expect(painter.lipReach, lessThan(.5));
  });

  testWidgets('L12 镜片是第二层玻璃：自带受光带与更亮的边，选中图形不弱于文字', (tester) async {
    _setView(tester);
    final preferences = _transparent();
    addTearDown(preferences.dispose);
    await tester.pumpWidget(_shell(preferences: preferences, index: 1));

    final lens = _lensPainter(tester);
    final surface = _surfacePainter(tester);
    expect(lens.sheen, isNotNull, reason: '镜片自己也要有一条受光带');
    expect(lens.sheenReach, MileafMaterialMetrics.glassLensSheenReach);
    expect(lens.fillTop, isNot(surface.fillTop), reason: '两层玻璃不能同色');
    expect(lens.edge.top.a, greaterThan(lens.edge.bottom.a));

    final colors = MileafColors.of(
      tester.element(find.byKey(const ValueKey('nav-selection-surface'))),
    );
    // 顺序以底栏自己声明的 items/index 为准（图标按 items 顺序绘制），
    // 不写死「第 2 个」——加项或换序时失败原因才指向颜色本身。
    final bar = tester.widget<MileafNavBar>(find.byType(MileafNavBar));
    final iconColors = tester
        .widgetList<MileafIcon>(
          find.descendant(
            of: find.byType(MileafNavBar),
            matching: find.byType(MileafIcon),
          ),
        )
        .toList();
    expect(iconColors, hasLength(bar.items.length));
    expect(
      iconColors[bar.index].color,
      colors.accentStrong,
      reason: '亮镜片上的选中图形要与文字同强度（accent 只剩 3.0:1）',
    );
    for (var i = 0; i < iconColors.length; i++) {
      if (i == bar.index) continue;
      expect(
        iconColors[i].color,
        colors.navigationLabel,
        reason: bar.items[i].label,
      );
    }
  });
}

/// 标签所在的相对高度：图标在 0.25–0.45，文字落在 0.6–0.85。
const _kLabelBand = .72;

/// 玻璃体在相对高度 [h] 处的叠色上限：底栏填充 + 顶部受光带 + 下沿弯月。
///
/// 只用来卡「有多透」这条口径（各层 alpha 相加是上界，真实合成只会更薄）。
double _veilAlpha(MileafColors colors, double h) {
  final fill =
      colors.glassFillTop.a +
      (colors.glassFillBottom.a - colors.glassFillTop.a) * h;
  final sheen = colors.glassSheen.a;
  final core = MileafMaterialMetrics.glassSheenCore;
  final reach = MileafMaterialMetrics.glassSheenReach;
  final double sheenAlpha;
  if (h <= core) {
    sheenAlpha = sheen;
  } else if (h <= reach) {
    final t = (h - core) / (reach - core);
    sheenAlpha = sheen * (MileafMaterialMetrics.glassSheenCoreAlpha * (1 - t));
  } else {
    sheenAlpha = 0;
  }
  final start = MileafMaterialMetrics.glassMeniscusStart;
  final meniscusAlpha = h <= start
      ? 0.0
      : colors.glassMeniscus.a * ((h - start) / (1 - start));
  return fill + sheenAlpha + meniscusAlpha;
}

/// 玻璃体在相对高度 [h] 处的合成色：填充 + 下沿弯月。
///
/// 受光带在标签带（0.72）已经散尽，端头增厚只压两端，故两者不计入；[h] 越低
/// 受光带越强，这一处只服务「标签带有多不透明」这条口径。
Color _glassAt(MileafColors colors, Color backdrop, double h) {
  final fill = Color.lerp(colors.glassFillTop, colors.glassFillBottom, h)!;
  var out = compositeOver(fill, fill.a, backdrop);
  final start = MileafMaterialMetrics.glassMeniscusStart;
  if (h > start) {
    final alpha = colors.glassMeniscus.a * ((h - start) / (1 - start));
    out = compositeOver(colors.glassMeniscus, alpha, out);
  }
  return out;
}

/// 某个玻璃容器里最外层的玻璃体：镜片是底栏的子树，所以取先序第一个。
Finder _glassBodyOf(Finder scope) => find
    .descendant(
      of: scope,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is LiquidGlassPainter,
      ),
    )
    .first;

LiquidGlassPainter _surfacePainter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(_glassBodyOf(find.byType(MileafGlassSurface)))
            .painter!
        as LiquidGlassPainter;

/// 只认底栏里的镜片：顶栏的车辆胶囊与设置圆钮用的是同一层玻璃。
LiquidGlassPainter _lensPainter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              _glassBodyOf(
                find.descendant(
                  of: find.byType(MileafNavBar),
                  matching: find.byType(MileafGlassLens),
                ),
              ),
            )
            .painter!
        as LiquidGlassPainter;
