// AP02 导航外壳（R26/PD01/PD05、M03、M10、L09 修订）的合同测试。
//
// 覆盖：可收起大标题外壳的几何与滚动插值、减少动效阈值切换、320/768 宽与
// 100/150/200% 字号、底栏与收起标题的 1.35× 封顶、大内容查看器的出现与选择、
// 语义标签不变、外壳与底栏的避让、二级导航 headline 与「更多」菜单接口、
// notice 横幅的 M11 时长。
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/glass_surface.dart';
import 'package:mileaf/src/design/components/large_content_viewer.dart';
import 'package:mileaf/src/design/components/nav_bar.dart';
import 'package:mileaf/src/design/components/navigation_material.dart';
import 'package:mileaf/src/design/components/page_bar.dart';
import 'package:mileaf/src/design/components/top_bar.dart';
import 'package:mileaf/src/design/display_preferences.dart';
import 'package:mileaf/src/design/icons.dart';
import 'package:mileaf/src/design/layout.dart';
import 'package:mileaf/src/design/motion.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/tokens.dart';

const _safeTop = 24.0;

void _noopSettings() {}

const _vehicle = '行笺测试车';

/// 390 宽 100% 字号下 R26 的展开与收起几何。
const _expanded = _safeTop + MileafSpace.s8 + 44 + MileafSpace.s8;
const _collapsed = _safeTop + 44;

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
  Brightness brightness = Brightness.light,
  bool reduceMotion = false,
  bool highContrast = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(top: 24);
  tester.view.padding = tester.view.viewPadding;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewPadding();
    tester.view.resetPadding();
  });
  final preferences = DisplayPreferencesController(
    platform: DisplayPreferencesPlatform.android,
  );
  addTearDown(preferences.dispose);
  await tester.pumpWidget(
    DisplayPreferencesScope(
      controller: preferences,
      child: MaterialApp(
        // R26 的 44 行高是 iOS 基准；Android 命中区 48，行高按
        // MileafLayout.touchTarget 同步长 4（R05 命中尺寸优先）。
        theme: mileafTheme(brightness).copyWith(platform: TargetPlatform.iOS),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: textScaler,
            devicePixelRatio: 1,
            highContrast: highContrast,
            disableAnimations: reduceMotion,
            viewPadding: const EdgeInsets.only(top: _safeTop),
            padding: const EdgeInsets.only(top: _safeTop),
          ),
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

Widget _shell({
  ValueListenable<double>? scroll,
  String vehicle = _vehicle,
  String title = '概览',
}) => Align(
  alignment: Alignment.topCenter,
  child: MileafTopBar(
    title: title,
    vehicleName: vehicle,
    onVehicle: () {},
    onSettings: () {},
    scrollListenable: scroll,
  ),
);

Widget _bar({int index = 0, ValueChanged<int>? onSelected}) => Scaffold(
  body: const SizedBox.expand(),
  bottomNavigationBar: MileafNavBar(
    index: index,
    onSelected: onSelected ?? (_) {},
  ),
);

Finder _navText(String label) =>
    find.descendant(of: find.byType(MileafNavBar), matching: find.text(label));

Finder get _expandedTitle =>
    find.byKey(const ValueKey('top-bar-expanded-title'));
Finder get _collapsedTitle =>
    find.byKey(const ValueKey('top-bar-collapsed-title'));
Finder get _expandedLayer =>
    find.byKey(const ValueKey('top-bar-expanded-layer'));
Finder get _collapsedLayer =>
    find.byKey(const ValueKey('top-bar-collapsed-layer'));

Finder get _barMaterial => find.descendant(
  of: find.byType(MileafTopBar),
  matching: find.byType(NavigationMaterial),
);

Finder get _barBackdrop => find.descendant(
  of: find.byType(MileafTopBar),
  matching: find.byType(BackdropFilter),
);

double _fontSize(WidgetTester tester, Finder finder) =>
    tester.widget<Text>(finder).style!.fontSize!;

void main() {
  group('R26/PD01 外壳几何', () {
    testWidgets('展开：安全区 + 8 + 44 + 8；收起：安全区 + 44', (tester) async {
      await _pump(tester, _shell());
      expect(tester.getSize(find.byType(MileafTopBar)).height, _expanded);
      final context = tester.element(find.byType(MileafTopBar));
      expect(MileafLayout.rootTopBarHeight(context), _expanded);
      expect(MileafLayout.rootTopBarCollapsedHeight(context), _collapsed);
      // 页面顶部保留展开态高度的留白（R26：页面不动，只有外壳变）。
      expect(
        MileafLayout.rootTopClearance(context),
        _expanded + MileafSpace.s8,
      );
    });

    testWidgets('展开态是大标题 + 车辆胶囊 + 设置圆钮', (tester) async {
      await _pump(tester, _shell());
      expect(_fontSize(tester, _expandedTitle), MileafType.largeTitleSize);
      expect(_collapsedTitle, findsNothing);
      expect(find.text(_vehicle), findsOneWidget);
      expect(find.byTooltip('设置'), findsOneWidget);
      final capsule = tester.getRect(
        find.byKey(const ValueKey('top-bar-vehicle')),
      );
      final title = tester.getRect(_expandedTitle);
      expect(capsule.center.dy, closeTo(title.center.dy, 6));
      expect(capsule.right, lessThanOrEqualTo(390 - MileafSpace.s20 + .01));
      expect(capsule.height, greaterThanOrEqualTo(MileafSpace.touch - .01));
    });

    // 2026-11-18：底栏镜片多了自己的受光带（L12）。顶栏的车辆胶囊与设置圆钮
    // 用的是同一层 MileafGlassLens，但顶栏按规格 §3 仍走 R14 取值——受光带
    // 只在底栏打开，这里钉住它不会外溢。
    testWidgets('顶栏镜片不带底栏的受光带', (tester) async {
      await _pump(tester, _shell());
      final lenses = find.descendant(
        of: find.byType(MileafTopBar),
        matching: find.byType(MileafGlassLens),
      );
      expect(lenses, findsWidgets, reason: '玻璃路径下车辆胶囊与设置圆钮都是镜片');
      final painter =
          tester
                  .widgetList<CustomPaint>(
                    find.descendant(
                      of: lenses.first,
                      matching: find.byWidgetPredicate(
                        (widget) =>
                            widget is CustomPaint &&
                            widget.painter is LiquidGlassPainter,
                      ),
                    ),
                  )
                  .first
                  .painter!
              as LiquidGlassPainter;
      expect(painter.sheen, isNull, reason: '顶栏镜片不叠受光带');
    });

    testWidgets('滚动 0/8/16/100：标题交叉淡出、材质与高度插值', (tester) async {
      final scroll = ValueNotifier<double>(0);
      addTearDown(scroll.dispose);
      await _pump(tester, _shell(scroll: scroll));

      expect(tester.getSize(find.byType(MileafTopBar)).height, _expanded);
      expect(_barMaterial, findsNothing);
      expect(_barBackdrop, findsNothing);

      scroll.value = 8;
      await tester.pump();
      expect(
        tester.getSize(find.byType(MileafTopBar)).height,
        closeTo((_expanded + _collapsed) / 2, .01),
      );
      expect(tester.widget<Opacity>(_expandedLayer).opacity, closeTo(.5, .01));
      expect(tester.widget<Opacity>(_collapsedLayer).opacity, closeTo(.5, .01));
      expect(_barBackdrop, findsOneWidget, reason: '半收起时磨砂已出现');

      for (final value in [16.0, 100.0]) {
        scroll.value = value;
        await tester.pump();
        expect(tester.getSize(find.byType(MileafTopBar)).height, _collapsed);
        expect(_expandedTitle, findsNothing);
        expect(tester.widget<Opacity>(_collapsedLayer).opacity, 1);
        expect(_fontSize(tester, _collapsedTitle), MileafType.headlineSize);
        expect(
          tester
              .widget<Opacity>(find.byKey(const ValueKey('top-bar-divider')))
              .opacity,
          1,
        );
      }
    });

    testWidgets('减少动效时在 8 处直接切换（M03）', (tester) async {
      final scroll = ValueNotifier<double>(7);
      addTearDown(scroll.dispose);
      await _pump(tester, _shell(scroll: scroll), reduceMotion: true);
      expect(tester.getSize(find.byType(MileafTopBar)).height, _expanded);
      expect(tester.widget<Opacity>(_expandedLayer).opacity, 1);

      scroll.value = 8;
      await tester.pump();
      expect(tester.getSize(find.byType(MileafTopBar)).height, _collapsed);
      expect(_expandedTitle, findsNothing);
      expect(tester.widget<Opacity>(_collapsedLayer).opacity, 1);
    });

    testWidgets('滚动只重建外壳自身，不重建页面', (tester) async {
      var pageBuilds = 0;
      final scroll = ValueNotifier<double>(0);
      addTearDown(scroll.dispose);
      await _pump(
        tester,
        Column(
          children: [
            Builder(
              builder: (context) {
                pageBuilds++;
                return _shell(scroll: scroll);
              },
            ),
            Builder(builder: (context) => const Text('页面内容')),
          ],
        ),
      );
      expect(pageBuilds, 1);
      scroll.value = 16;
      await tester.pump();
      expect(pageBuilds, 1, reason: '外壳自持监听，滚动不触发父级重建');
      expect(tester.getSize(find.byType(MileafTopBar)).height, _collapsed);
    });
  });

  group('R26 宽度与字号矩阵', () {
    for (final width in [320.0, 768.0]) {
      testWidgets('$width 宽：无溢出，胶囊不超过外壳宽度的 45%', (tester) async {
        await _pump(
          tester,
          _shell(vehicle: '北仑港滨海超级充电站有限公司车队二号车'),
          size: Size(width, 800),
        );
        expect(tester.takeException(), isNull);
        final content = width >= MileafBreakpoints.wide
            ? MileafBreakpoints.maxContent
            : width - 2 * MileafSpace.s20;
        final capsule = tester.getRect(
          find.byKey(const ValueKey('top-bar-vehicle')),
        );
        expect(capsule.width, lessThanOrEqualTo(content * .45 + .01));
      });
    }

    testWidgets('150/200% 字号：控件在标题上方一行，收起只留控件', (tester) async {
      for (final scale in [1.5, 2.0]) {
        final scroll = ValueNotifier<double>(0);
        addTearDown(scroll.dispose);
        await _pump(
          tester,
          _shell(scroll: scroll),
          size: const Size(360, 800),
          textScaler: TextScaler.linear(scale),
        );
        expect(tester.takeException(), isNull, reason: '$scale');
        final capsule = tester.getRect(
          find.byKey(const ValueKey('top-bar-vehicle')),
        );
        final title = tester.getRect(_expandedTitle);
        expect(
          capsule.bottom,
          lessThanOrEqualTo(title.top + .01),
          reason: '$scale：展开态控件在标题上方一行靠右（R26 大字）',
        );

        scroll.value = MileafMotion.collapseScroll;
        await tester.pump();
        expect(tester.getSize(find.byType(MileafTopBar)).height, _collapsed);
        expect(_expandedTitle, findsNothing, reason: '$scale：收起态不放大标题');
        // 大字展开态把控件放在标题上方一行；收起后行结构收回 44，只保留控件
        // （R26「放不下标题时只保留控件」的取舍，见 AP02 交接偏差账本）。
        expect(_collapsedTitle, findsNothing);
        expect(find.text('概览'), findsNothing);
        expect(find.byKey(const ValueKey('top-bar-vehicle')), findsOneWidget);
        expect(find.byTooltip('设置'), findsOneWidget);
      }
    });

    testWidgets('大字长标题不溢出，收起态只保留控件（R26）', (tester) async {
      final scroll = ValueNotifier<double>(16);
      addTearDown(scroll.dispose);
      await _pump(
        tester,
        _shell(scroll: scroll, title: '行笺测试车的超长页面名称在这里'),
        size: const Size(320, 800),
        textScaler: const TextScaler.linear(2),
      );
      expect(tester.takeException(), isNull);
      expect(_collapsedTitle, findsNothing);
      expect(find.byKey(const ValueKey('top-bar-vehicle')), findsOneWidget);
      expect(find.byTooltip('设置'), findsOneWidget);
    });
  });

  group('R26/PD05 放大封顶 1.35× 与大内容查看器（M10）', () {
    testWidgets('200% 下底栏标签放大停在 1.35×，栏高随之封顶', (tester) async {
      expect(MileafNavBar.labelMaxScale, 1.35);
      await _pump(
        tester,
        _bar(),
        size: const Size(320, 720),
        textScaler: const TextScaler.linear(2),
      );
      final context = tester.element(_navText('概览'));
      expect(
        MediaQuery.textScalerOf(context).scale(MileafType.navLabelSize),
        closeTo(MileafType.navLabelSize * 1.35, .01),
      );
      expect(
        tester
            .getSize(
              find.descendant(
                of: find.byType(MileafNavBar),
                matching: find.byType(NavigationMaterial),
              ),
            )
            .height,
        closeTo(
          MileafSpace.navHeight +
              (MileafType.navLabelHeight * 1.35 - MileafType.navLabelHeight),
          .01,
        ),
        reason: '栏高按封顶后的标签增高，不再随系统字号无限放大',
      );
      for (final label in ['概览', '行程', '充电', '统计']) {
        expect(tester.getSize(_navText(label)).width, greaterThan(0));
      }
    });

    // 封顶只在「还没进入大字布局」的字号区间可见：140% 仍是单行外壳，
    // 17 号标题按 1.4 放大到 23.8，被 1.35 封顶拉回 22.95。
    testWidgets('140% 下收起态标题放大停在 1.35×', (tester) async {
      final scroll = ValueNotifier<double>(16);
      addTearDown(scroll.dispose);
      await _pump(
        tester,
        _shell(scroll: scroll),
        size: const Size(360, 800),
        textScaler: const TextScaler.linear(1.4),
      );
      final text = _collapsedTitle;
      final context = tester.element(text);
      expect(
        MediaQuery.textScalerOf(context).scale(_fontSize(tester, text)),
        closeTo(MileafType.headlineSize * 1.35, .01),
      );
    });

    testWidgets('长按出现 160×160 浮层，抬手落在该项上即切换', (tester) async {
      var selected = 0;
      await _pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) => _bar(
            index: selected,
            onSelected: (value) => setState(() => selected = value),
          ),
        ),
      );
      expect(find.byType(MileafLargeContentViewer), findsNothing);

      final gesture = await tester.startGesture(
        tester.getCenter(_navText('行程')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
      final viewer = find.byType(MileafLargeContentViewer);
      expect(viewer, findsOneWidget);
      expect(tester.getSize(viewer), const Size(160, 160));
      expect(MileafLargeContentViewer.extent, 160);
      expect(MileafLargeContentViewer.radius, MileafRadius.lg);
      expect(MileafLargeContentViewer.iconSize, 40);
      final colors = MileafColors.of(tester.element(viewer));
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: viewer,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is DecoratedBox &&
                    widget.decoration is BoxDecoration &&
                    (widget.decoration as BoxDecoration).borderRadius != null,
              ),
            )
            .first,
      );
      expect((box.decoration as BoxDecoration).color, colors.surfaceRaised);
      expect(
        tester
            .widget<MileafIcon>(
              find.descendant(of: viewer, matching: find.byType(MileafIcon)),
            )
            .size,
        40,
      );
      expect(
        _fontSize(
          tester,
          find.descendant(of: viewer, matching: find.text('行程')),
        ),
        MileafType.title2Size,
      );

      await gesture.moveTo(tester.getCenter(_navText('统计')));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(selected, 3, reason: '抬手落在该项上即切换');
      expect(find.byType(MileafLargeContentViewer), findsNothing);

      final outside = await tester.startGesture(
        tester.getCenter(_navText('充电')),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
      expect(find.byType(MileafLargeContentViewer), findsOneWidget);
      await outside.moveTo(const Offset(180, 120));
      await tester.pump();
      await outside.up();
      await tester.pumpAndSettle();
      expect(selected, 3, reason: '移到栏外抬手不切换');
      expect(find.byType(MileafLargeContentViewer), findsNothing);
    });

    testWidgets('顶栏车辆胶囊长按显示同一查看器（封顶补偿）', (tester) async {
      final scroll = ValueNotifier<double>(0);
      addTearDown(scroll.dispose);
      await _pump(
        tester,
        _shell(scroll: scroll),
        textScaler: const TextScaler.linear(2),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('top-bar-vehicle'))),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
      expect(find.byType(MileafLargeContentViewer), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MileafLargeContentViewer),
          matching: find.text(_vehicle),
        ),
        findsOneWidget,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(MileafLargeContentViewer), findsNothing);
    });

    testWidgets('收起标题与车辆胶囊的大内容查看器抬手/移出即消失（M10）', (tester) async {
      final scroll = ValueNotifier<double>(16);
      addTearDown(scroll.dispose);
      await _pump(
        tester,
        _shell(scroll: scroll),
        size: const Size(390, 844),
        textScaler: const TextScaler.linear(1.4),
      );
      expect(_collapsedTitle, findsOneWidget);

      // 收起标题：长按出现，抬手消失。
      var gesture = await tester.startGesture(
        tester.getCenter(_collapsedTitle),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(MileafLargeContentViewer), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(MileafLargeContentViewer), findsNothing);

      // 车辆胶囊：移出胶囊即消失，抬手仍消失。
      gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('top-bar-vehicle'))),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(MileafLargeContentViewer), findsOneWidget);
      await gesture.moveTo(const Offset(20, 700));
      await tester.pumpAndSettle();
      expect(find.byType(MileafLargeContentViewer), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byType(MileafLargeContentViewer), findsNothing);
    });
  });

  group('R26 语义与避让', () {
    testWidgets('底栏与顶栏控件的语义标签不变', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _bar());
      for (final label in ['概览', '行程', '充电', '统计']) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      await _pump(tester, _shell());
      expect(find.bySemanticsLabel(RegExp('选择车辆，$_vehicle')), findsOneWidget);
      expect(find.bySemanticsLabel('设置'), findsWidgets);
      handle.dispose();
    });

    testWidgets('滚动到末项时外壳与底栏不遮挡内容（AQ06）', (tester) async {
      Widget page() => Builder(
        builder: (context) => Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              ListView(
                key: const ValueKey('page-scroll'),
                padding: EdgeInsets.only(
                  top: MileafLayout.rootTopClearance(context),
                  bottom: MileafLayout.rootNavigationClearance(context),
                ),
                children: [
                  const SizedBox(
                    key: ValueKey('first-item'),
                    height: 160,
                    child: Text('首项'),
                  ),
                  for (var i = 0; i < 8; i++)
                    const SizedBox(height: 160, child: Text('内容块')),
                  const SizedBox(
                    key: ValueKey('last-item'),
                    height: 160,
                    child: Text('末项'),
                  ),
                ],
              ),
              const Align(
                alignment: Alignment.topCenter,
                child: MileafTopBar(
                  vehicleName: _vehicle,
                  onVehicle: null,
                  onSettings: _noopSettings,
                ),
              ),
            ],
          ),
          bottomNavigationBar: MileafNavBar(index: 0, onSelected: (_) {}),
        ),
      );
      await _pump(tester, page());
      expect(
        tester.getRect(find.byKey(const ValueKey('first-item'))).top,
        greaterThanOrEqualTo(
          tester.getRect(find.byType(MileafTopBar)).bottom - .01,
        ),
        reason: '首项从外壳下沿开始',
      );

      await tester.drag(
        find.byKey(const ValueKey('page-scroll')),
        const Offset(0, -5000),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('last-item'))).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(MileafNavBar)).top),
        reason: '滚到末项时底栏不遮挡它（rootNavigationClearance 留白）',
      );
    });

    testWidgets('外壳与底栏为末项留出避让', (tester) async {
      await _pump(tester, _bar());
      final context = tester.element(find.byType(MileafNavBar));
      final nav = MileafLayout.rootNavigationHeight(context);
      expect(
        MileafLayout.rootNavigationClearance(context),
        greaterThanOrEqualTo(nav + MileafSpace.s16),
      );
      final bottom = tester.getRect(find.byType(MileafNavBar)).bottom;
      expect(bottom, lessThanOrEqualTo(844 + .01));
    });
  });

  group('R26 二级导航', () {
    /// 推入一级路线，让二级导航拿到可返回的栈。
    Future<void> pushPage(
      WidgetTester tester, {
      required VoidCallback onMore,
    }) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      appBar: mileafPageBar(
                        context,
                        title: const Text('行程详情'),
                        actions: [
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                        moreActions: [
                          MileafNavigationMenuEntry(
                            label: '数据说明',
                            onSelected: onMore,
                          ),
                        ],
                      ),
                      body: const SizedBox.expand(),
                    ),
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();
    }

    testWidgets('标题 headline、返回改自绘图标、尾部最多一个可见操作', (tester) async {
      await pushPage(tester, onMore: () {});
      expect(
        DefaultTextStyle.of(tester.element(find.text('行程详情'))).style.fontSize,
        MileafType.headlineSize,
      );
      expect(
        tester
            .widget<MileafIcon>(
              find.descendant(
                of: find.byType(BackButton),
                matching: find.byType(MileafIcon),
              ),
            )
            .name,
        MileafIconName.back,
      );
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byTooltip('更多'), findsOneWidget);
    });

    testWidgets('内容经过时二级导航切磨砂，静止时与 canvas 同底（R26）', (tester) async {
      await _pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            appBar: mileafPageBar(context, title: const Text('行程详情')),
            body: ListView(
              children: [
                for (var i = 0; i < 20; i++)
                  const SizedBox(height: 120, child: Text('内容块')),
              ],
            ),
          ),
        ),
      );
      Finder frosted() => find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(BackdropFilter),
      );
      expect(frosted(), findsNothing, reason: '静止时是 canvas 实色');

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(frosted(), findsOneWidget, reason: '内容经过时换磨砂材质');

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(frosted(), findsNothing, reason: '回到顶部后恢复实底');
    });

    testWidgets('第二个操作进「更多」菜单', (tester) async {
      var tapped = false;
      await pushPage(tester, onMore: () => tapped = true);
      await tester.tap(find.byTooltip('更多'));
      await tester.pumpAndSettle();
      expect(find.text('数据说明'), findsOneWidget);
      await tester.tap(find.text('数据说明'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
      expect(find.text('数据说明'), findsNothing);
    });
  });

  group('R26 notice 横幅', () {
    testWidgets('与页面边距对齐、liveRegion、M11 时长', (tester) async {
      const text = '所选车辆已不可用，已重新选择';
      await _pump(tester, const MileafNoticeBanner(text: text));
      final context = tester.element(find.text(text));
      final icon = tester.getRect(find.byType(MileafIcon));
      expect(icon.left, MileafLayout.pageInset(context));
      expect(tester.getTopLeft(find.text(text)).dx, greaterThan(icon.right));
      expect(tester.getTopLeft(find.byType(MileafNoticeBanner)).dx, 0);
      final region = tester.widget<Semantics>(
        find
            .ancestor(of: find.text(text), matching: find.byType(Semantics))
            .first,
      );
      expect(region.properties.liveRegion, isTrue);
      expect(
        tester.widget<AnimatedSize>(find.byType(AnimatedSize).first).duration,
        MileafDurations.statusHeight,
      );
      expect(
        tester
            .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
            .duration,
        MileafDurations.statusOpacity,
      );
      await _pump(tester, const MileafNoticeBanner(text: null));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(MileafNoticeBanner)).height, 0);
    });
  });
}
