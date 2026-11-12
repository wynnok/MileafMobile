import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/layout.dart';
import 'package:mileaf/src/design/motion.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/tokens.dart';

import 'support/color_math.dart';
import 'support/pixel_probe.dart';
import 'support/render_fonts.dart';
import 'support/render_png.dart';

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

/// U03 图表、状态和动效基础回归：每条用例捕获一个具体回退（#31 必做项）。
///
/// 覆盖 R06.4/R06.5（轴留白按实测、参照 1.5）、R06.7（横拖/纵滚/键盘/语义
/// 增减/普通刷新不重置选点）、R07（禁动效即时完整图形、静态骨架、弹层
/// 240ms、整页入场直出）与 A13/A14 的共享面。
void main() {
  TimeSeriesChart chart(
    List<num?> values, {
    String semanticsLabel = '每日里程图表',
    bool showYAxis = false,
    int? selectedIndex,
    String Function(int index)? readout,
    List<ChartSeries>? extraSeries,
    ValueChanged<int>? onSelected,
    ChartSeriesStyle style = ChartSeriesStyle.line,
    Key? plotKey,
    String title = '每日里程',
  }) => TimeSeriesChart(
    title: title,
    unit: 'km',
    times: [for (var i = 0; i < values.length; i++) DateTime(2026, 10, 1 + i)],
    series: [
      ChartSeries(label: title, values: values, style: style),
      ...?extraSeries,
    ],
    semanticsLabel: semanticsLabel,
    selectedIndex: selectedIndex,
    onSelected: onSelected,
    showYAxis: showYAxis,
    readout: readout,
    height: 120,
    plotKey: plotKey,
  );

  Future<void> pumpBare(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
  }) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: mileafTheme(brightness),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 320, child: child),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('R06.7 图表操作', () {
    testWidgets('横拖改变选点：读值与回调一致，不新增默认选点策略', (tester) async {
      var selected = -1;
      await pumpBare(
        tester,
        chart(
          const [10, 20, 30, 40, 50],
          readout: (i) => '读值 i$i',
          onSelected: (i) => selected = i,
          plotKey: const ValueKey('u03-plot'),
        ),
      );
      await tester.drag(
        find.byKey(const ValueKey('u03-plot')),
        const Offset(240, 0),
      );
      await tester.pump();
      expect(find.text('读值 i4'), findsOneWidget, reason: '拖到最右读末点');
      expect(selected, 4);
    });

    testWidgets('纵向拖动不选点：手势交给页面滚动', (tester) async {
      var selected = 0;
      tester.view.physicalSize = const Size(360, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 600),
                  chart(
                    const [10, 20, 30],
                    readout: (i) => '读值 i$i',
                    onSelected: (i) => selected = i,
                    plotKey: const ValueKey('u03-plot'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // 先把图表滚入视口，再在图表上纵向拖动。
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -350));
      await tester.pumpAndSettle();
      final before = tester.getRect(find.byType(TimeSeriesChart));
      expect(before.top, lessThan(400), reason: '前置条件：图表已进入视口');
      await tester.drag(
        find.byKey(const ValueKey('u03-plot')),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      final after = tester.getRect(find.byType(TimeSeriesChart));
      expect(after.top, lessThan(before.top), reason: '纵向拖动应滚动页面');
      expect(selected, 0, reason: '纵向拖动不改变选点');
      expect(find.text('读值 i0'), findsOneWidget);
    });

    testWidgets('键盘左右移动选点，语义保留增减动作', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpBare(
          tester,
          chart(
            const [10, 20, 30],
            readout: (i) => '读值 i$i',
            plotKey: const ValueKey('u03-plot'),
          ),
        );
        final node = tester.getSemantics(find.bySemanticsLabel('每日里程图表'));
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.increase),
          isTrue,
          reason: '语义增减保留',
        );
        expect(
          node.getSemanticsData().hasAction(SemanticsAction.decrease),
          isFalse,
          reason: '首点没有减少动作',
        );
        // 点按绘图区中心会把选点定到中点（i1），随后用键盘前后移动。
        await tester.tap(find.byKey(const ValueKey('u03-plot')));
        await tester.pump();
        expect(find.text('读值 i1'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(find.text('读值 i2'), findsOneWidget);
        // 末点再按右停在末点；左移回退。
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(find.text('读值 i2'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(find.text('读值 i1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('普通刷新不重置选点；显式 selectedIndex 仍被遵循', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      // 主题只建一次：MaterialApp 用 AnimatedTheme，每次新 ThemeData
      // 实例都会重启主题动画，让 hasScheduledFrame 断言失去意义。
      final theme = mileafTheme(Brightness.light);
      Widget build(List<num> values, {int? selectedIndex}) => MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 320,
              child: chart(
                values,
                selectedIndex: selectedIndex,
                readout: (i) => '读值 i$i=${values[i]}',
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(build(const [10, 20, 30, 40], selectedIndex: 2));
      await tester.pump();
      expect(find.text('读值 i2=30'), findsOneWidget);
      // 同身份刷新：数据更新、显式 selectedIndex 未变——选点保留（R06.7）。
      await tester.pumpWidget(build(const [12, 22, 32, 42], selectedIndex: 2));
      await tester.pump();
      expect(find.text('读值 i2=32'), findsOneWidget);
      // 父级显式改选点时才跟随。
      await tester.pumpWidget(build(const [12, 22, 32, 42], selectedIndex: 0));
      await tester.pump();
      expect(find.text('读值 i0=12'), findsOneWidget);
    });
  });

  group('R06.4 轴留白与大字', () {
    testWidgets('100% 与 200%：绘图盒高度 = 顶留白 + 绘图区 + 底轴行高', (tester) async {
      Future<void> check(double scale) async {
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        // 在与图表完全相同的字号环境里实测轴标尺寸，按 R06.4 复算盒子高度。
        var expected = 0.0;
        await tester.pumpWidget(
          MaterialApp(
            theme: mileafTheme(Brightness.light),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 320,
                  child: Builder(
                    builder: (context) {
                      final scaler = MediaQuery.textScalerOf(context);
                      final style = chartAxisLabelStyle(
                        color: const Color(0xFF000000),
                        scaler: scaler,
                      );
                      final painter = TextPainter(
                        text: TextSpan(text: '10/1', style: style),
                        textDirection: TextDirection.ltr,
                      )..layout();
                      final tickHeight = painter.height;
                      painter.dispose();
                      expected =
                          math.max(8, tickHeight / 2) + 120 + tickHeight + 8;
                      return chart(
                        const [10, 20, 30],
                        showYAxis: true,
                        plotKey: const ValueKey('u03-plot'),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        final height = tester
            .getSize(find.byKey(const ValueKey('u03-plot')))
            .height;
        expect(
          height,
          closeTo(expected, 1.0),
          reason:
              'scale $scale：盒子必须恰好容纳顶留白+绘图区+底轴行高；'
              '实测 $height，按实测轴标复算 $expected；'
              '旧公式（绘图区+底轴+2×8）会在大字下裁掉轴标顶部',
        );
      }

      await check(1);
      await check(2);
    });

    testWidgets('200% 且 showYAxis：整表不抛异常、轴标随完整 TextScaler', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              child: chart(
                const [10, 20, 30, 40, 60],
                showYAxis: true,
                readout: (i) => '读值 i$i',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('R07 图表即时完整与骨架', () {
    testWidgets('禁动效首帧即完整真实几何：无绘制生长、无循环帧', (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });
      final key = GlobalKey();
      // 主题只建一次，避免 AnimatedTheme 重启造成无限动画帧。
      final theme = mileafTheme(Brightness.light);
      Widget wrap(List<num> values) => MaterialApp(
        theme: theme,
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 320,
                child: chart(
                  values,
                  style: ChartSeriesStyle.bars,
                  readout: (i) => '读值 i$i',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(wrap(const [10, 10, 10, 10, 10]));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse, reason: '无循环动画帧');
      final colors = const MileafColors.light();
      var probe = await capturePixels(tester, find.byKey(key), pixelRatio: 2);
      final columns = probe.columns(colors.accent);
      expect(columns, hasLength(5), reason: '首帧 5 根柱全部完整');
      // 同身份刷新：单帧后新几何直接呈现，无生长过程。
      await tester.pumpWidget(wrap(const [30, 30, 30, 30, 30]));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      probe = await capturePixels(tester, find.byKey(key), pixelRatio: 2);
      final bounds = probe.bounds(colors.accent)!;
      // probe 为 2 倍物理像素：柱从 y(30) 到基线占满 120 逻辑高 ≈ 240 物理高。
      expect(bounds.height, greaterThan(200), reason: '刷新后柱直接到新高度（无 500ms 生长）');
    });

    testWidgets('静态骨架：无限脉冲移除，任意时刻像素恒定', (tester) async {
      await pumpBare(tester, const SkeletonBlock(width: 160, height: 14));
      expect(tester.binding.hasScheduledFrame, isFalse, reason: '无动画帧');
      final key = GlobalKey();
      final colors = const MileafColors.light();
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(Brightness.light),
          home: Scaffold(
            backgroundColor: colors.canvas,
            body: RepaintBoundary(
              key: key,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SkeletonBlock(width: 160, height: 14),
                    SizedBox(height: 8),
                    SkeletonBlock(width: 220, height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      var probe = await capturePixels(tester, find.byKey(key), pixelRatio: 2);
      final before = probe.bytes;
      expect(
        probe.width * probe.height - probe.count(colors.canvas),
        greaterThan(0),
        reason: '骨架有可见墨迹',
      );
      await tester.pump(const Duration(seconds: 3));
      probe = await capturePixels(tester, find.byKey(key), pixelRatio: 2);
      expect(probe.bytes, before, reason: '静态骨架：推进 3 秒后像素逐字节不变（无无限脉冲）');
      expect(tester.binding.hasScheduledFrame, isFalse, reason: '推进 3 秒后仍无动画帧');
    });
  });

  group('R07 页面级减动效接缝', () {
    testWidgets('MileafPageEnter 即时直出：单帧完整内容、无入场帧', (tester) async {
      await pumpBare(tester, const MileafPageEnter(child: Text('即时内容')));
      expect(find.text('即时内容'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('MileafProgressLine：默认走指示动画，禁动效为静态条', (tester) async {
      final colors = const MileafColors.light();
      // 主题只建一次，避免 AnimatedTheme 重启造成无限动画帧。
      final theme = mileafTheme(Brightness.light);
      Future<void> check(bool reduce, GlobalKey key) async {
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        if (reduce) {
          tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
        }
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.binding.platformDispatcher
              .clearAccessibilityFeaturesTestValue();
        });
        await tester.pumpWidget(
          // 不同 key 强制整树重建，避免上一个用例的树就地复用。
          KeyedSubtree(
            key: ValueKey('progress-$reduce'),
            child: MaterialApp(
              theme: theme,
              home: Scaffold(
                backgroundColor: colors.canvas,
                body: RepaintBoundary(
                  key: key,
                  child: const Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(width: 300, child: MileafProgressLine()),
                  ),
                ),
              ),
            ),
          ),
        );
        // 主题已提升，单帧后即可断言；默认分支是不定动画，不能 pumpAndSettle。
        await tester.pump();
        if (reduce) {
          expect(
            tester.binding.hasScheduledFrame,
            isFalse,
            reason: '禁动效下无无限转动帧（R07）',
          );
        } else {
          expect(
            tester.binding.hasScheduledFrame,
            isTrue,
            reason: '默认模式保留进行中指示',
          );
        }
        // 默认模式推进半秒，让不定指示器画出可见段。
        await tester.pump(const Duration(milliseconds: 500));
        final probe = await capturePixels(
          tester,
          find.byKey(key),
          pixelRatio: 2,
        );
        // 两种模式的墨迹都以预乘通道写入边界图（capturePixels 返回原始
        // RGBA）：accent 55% alpha 的像素通道 = accent.rgb × .55。
        Color premul(Color c, double alpha) => Color.fromARGB(
          (alpha * 255).round(),
          (c.r * alpha * 255).round(),
          (c.g * alpha * 255).round(),
          (c.b * alpha * 255).round(),
        );
        final ink = reduce ? premul(colors.accent, .55) : colors.accent;
        expect(probe.count(ink), greaterThan(0), reason: '两种模式都有进度条墨迹（更新中不消失）');
      }

      await check(false, GlobalKey());
      await check(true, GlobalKey());
    });

    testWidgets('弹层转场 240ms easeOutCubic，禁动效归零（U02 交接项）', (tester) async {
      final theme = mileafTheme(Brightness.light);
      Future<Duration> openSheet(bool reduce) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        if (reduce) {
          tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
        }
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.binding.platformDispatcher
              .clearAccessibilityFeaturesTestValue();
        });
        // 不同 key 强制整树重建：pumpWidget 对同根树就地更新，上一轮打开
        // 的弹层路由会留在 Navigator 里挡住下一次点按。
        await tester.pumpWidget(
          KeyedSubtree(
            key: ValueKey('sheet-$reduce'),
            child: MaterialApp(
              theme: theme,
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showMileafSheet(
                      context: context,
                      title: '弹层',
                      builder: (_) => const SizedBox(height: 100),
                    ),
                    child: const Text('打开'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开'), warnIfMissed: false);
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(MileafSheetFrame));
        return ModalRoute.of(context)!.transitionDuration;
      }

      expect(
        await openSheet(false),
        MileafDurations.sheet,
        reason: 'R07 弹层 240ms',
      );
      expect(MileafCurves.sheet, Curves.easeOutCubic);
      expect(await openSheet(true), Duration.zero, reason: '禁动效归零');
    });
  });

  group('R06.6 读值与比较区间', () {
    testWidgets('有可比参照时默认读值带参照值与差值；缺失即省略，不伪造比较', (tester) async {
      Future<void> check(
        int selected, {
        required List<num?> values,
        required List<num?> reference,
        required String text,
        required String reason,
      }) async {
        await pumpBare(
          tester,
          chart(
            values,
            selectedIndex: selected,
            extraSeries: [
              ChartSeries(
                label: '上期同区间',
                values: reference,
                style: ChartSeriesStyle.reference,
              ),
            ],
          ),
        );
        expect(find.text(text), findsOneWidget, reason: reason);
      }

      await check(
        0,
        values: const [10, null, 30],
        reference: const [8, 5, null],
        text: '10/1 · 10 km · 上期同区间 8 km（差 +2 km）',
        reason: '双侧已知：参照区间名+参照值+差值（R06.6）',
      );
      await check(
        1,
        values: const [10, null, 30],
        reference: const [8, 5, null],
        text: '10/2 · —',
        reason: '当前值缺失不拼参照（缺失主值不带单位，沿 U01 口径）',
      );
      await check(
        2,
        values: const [10, null, 30],
        reference: const [8, 5, null],
        text: '10/3 · 30 km',
        reason: '参照缺失省略参照段',
      );
    });

    testWidgets('参照高于当前时差值带负号', (tester) async {
      await pumpBare(
        tester,
        chart(
          const [10],
          selectedIndex: 0,
          extraSeries: const [
            ChartSeries(
              label: '上期同区间',
              values: [12],
              style: ChartSeriesStyle.reference,
            ),
          ],
        ),
      );
      expect(find.text('10/1 · 10 km · 上期同区间 12 km（差 -2 km）'), findsOneWidget);
    });

    testWidgets('末点选中的光晕不被绘图区右缘裁切', (tester) async {
      final key = GlobalKey();
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final colors = const MileafColors.light();
      // 边界包住 Scaffold：capturePixels 才带上画布底色，合成色可比。
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: mileafTheme(Brightness.light),
            home: Scaffold(
              backgroundColor: colors.canvas,
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 320,
                  child: chart(
                    const [10, 20, 30, 40, 50],
                    style: ChartSeriesStyle.bars,
                    selectedIndex: 4,
                    plotKey: const ValueKey('u03-plot'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final probe = await capturePixels(tester, find.byKey(key), pixelRatio: 2);
      final halo = compositeOver(colors.accent, .2, colors.canvas);
      final mark = probe.bounds(colors.accent)!;
      final haloBounds = probe.bounds(halo, tolerance: 2);
      expect(haloBounds, isNotNull, reason: '末点光晕被绘制');
      expect(
        haloBounds!.width,
        greaterThanOrEqualTo(14),
        reason: '8px halo 直径 16 物理像素，截断会小于 14',
      );
      expect(
        haloBounds.right,
        greaterThan(mark.right),
        reason: '光晕右缘必须越过标记（末点不被裁）',
      );
    });
  });

  group('图册：图表状态板（正/负/0/null/单点/全空/稀疏/长轴标）', () {
    setUpAll(() async {
      if (output.isEmpty) return;
      await loadRenderFonts(cjkFontPath: fontPath);
    });

    testWidgets('浅深 × 100/200% 渲染状态板', (tester) async {
      final boundary = GlobalKey();
      for (final brightness in Brightness.values) {
        final colors = brightness == Brightness.dark
            ? const MileafColors.dark()
            : const MileafColors.light();
        // 主题每模式只建一次，避免 AnimatedTheme 重启。
        final theme = mileafTheme(brightness);
        for (final scale in [1.0, 2.0]) {
          final label =
              'chart-states-${brightness.name}-${scale == 1 ? '100' : '200'}';
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher
            ..platformBrightnessTestValue = brightness
            ..textScaleFactorTestValue = scale;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            tester.platformDispatcher
              ..clearPlatformBrightnessTestValue()
              ..clearTextScaleFactorTestValue();
          });
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                theme: theme,
                debugShowCheckedModeBanner: false,
                home: Scaffold(
                  backgroundColor: colors.canvas,
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 正值/null/参照虚线 + Y 轴实测留白。
                        TimeSeriesChart(
                          title: '折线与参照',
                          unit: 'km',
                          times: [
                            DateTime(2026, 10, 1),
                            DateTime(2026, 10, 2),
                            DateTime(2026, 10, 3),
                            DateTime(2026, 10, 4),
                            DateTime(2026, 10, 5),
                          ],
                          series: [
                            const ChartSeries(
                              label: '本期',
                              values: [12, 30, null, 65, 8],
                            ),
                            ChartSeries(
                              label: '上期同区间',
                              values: [14, 22, 28, 40, 50],
                              style: ChartSeriesStyle.reference,
                            ),
                          ],
                          semanticsLabel: '折线与参照图表',
                          showYAxis: true,
                          selectedIndex: 3,
                          height: 160,
                        ),
                        const SizedBox(height: 24),
                        // 正/负/0/null/极值柱。
                        TimeSeriesChart(
                          title: '正负与零缺失',
                          unit: 'km',
                          times: [
                            DateTime(2026, 10, 1),
                            DateTime(2026, 10, 2),
                            DateTime(2026, 10, 3),
                            DateTime(2026, 10, 4),
                            DateTime(2026, 10, 5),
                          ],
                          series: [
                            const ChartSeries(
                              label: '停放变化',
                              values: [120, -45, 0, null, 260],
                              style: ChartSeriesStyle.bars,
                            ),
                          ],
                          semanticsLabel: '正负与零缺失图表',
                          showYAxis: true,
                          selectedIndex: 1,
                          height: 160,
                        ),
                        const SizedBox(height: 24),
                        // 稀疏竖线：真实 0 与 null 都不画线。
                        StemChart(
                          title: '稀疏补能',
                          unit: 'kWh',
                          times: [
                            DateTime(2026, 10, 1),
                            DateTime(2026, 10, 2),
                            DateTime(2026, 10, 3),
                            DateTime(2026, 10, 4),
                            DateTime(2026, 10, 5),
                          ],
                          values: const [10, 0, null, null, 7],
                          semanticsLabel: '稀疏补能图表',
                          selectedIndex: 4,
                          height: 120,
                        ),
                        const SizedBox(height: 24),
                        // 单点 + 长轴标（千位缩写）。
                        TimeSeriesChart(
                          title: '单点与大数轴',
                          unit: 'Wh/km',
                          times: [DateTime(2026, 10, 28)],
                          series: const [
                            ChartSeries(label: '净电耗', values: [9800]),
                          ],
                          semanticsLabel: '单点与大数轴图表',
                          height: 120,
                        ),
                        const SizedBox(height: 24),
                        TimeSeriesChart(
                          title: '长轴标',
                          unit: 'Wh/km',
                          times: [
                            DateTime(2026, 10, 1),
                            DateTime(2026, 10, 15),
                            DateTime(2026, 10, 28),
                          ],
                          series: const [
                            ChartSeries(
                              label: '净电耗',
                              values: [9800, 12300, 10400],
                            ),
                          ],
                          semanticsLabel: '长轴标图表',
                          showYAxis: true,
                          height: 120,
                        ),
                        const SizedBox(height: 24),
                        // 全空：收缩为说明，不画假曲线。
                        TimeSeriesChart(
                          title: '没有采样点',
                          unit: 'km',
                          times: const [],
                          series: const [
                            ChartSeries(label: '每日里程', values: []),
                          ],
                          semanticsLabel: '没有采样点图表',
                          emptyMessage: '这段时间没有采样点',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$label（theme $theme）渲染无异常',
          );
          await saveRenderPng(
            tester,
            find.byKey(boundary),
            '$output/$label.png',
          );
        }
      }
    }, skip: output.isEmpty);
  });
}
