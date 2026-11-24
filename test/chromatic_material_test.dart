// MC05 票内测试：按钮图标纪律（CL14）与浮层玻璃（CL30/CL31 + CL30.1）。
//
// 只测公开 Widget、公开常量与可从 widget 树读出的材质参数；不读私有字段。
// 逐像素光泽与合成帧成本留在外部 gate（#11/#16/#17）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/button.dart';
import 'package:mileaf/src/design/components/glass_surface.dart';
import 'package:mileaf/src/design/components/icon_button.dart';
import 'package:mileaf/src/design/components/pull_down.dart';
import 'package:mileaf/src/design/components/sheet.dart';
import 'package:mileaf/src/design/display_preferences.dart';
import 'package:mileaf/src/design/icons.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/tokens.dart';
import 'package:mileaf/src/map/map_consent.dart';
import 'package:mileaf/src/map/map_panel.dart';
import 'package:mileaf/src/map/map_scene.dart';

import 'support/fake_map_platform.dart';

Widget _board(
  Widget child, {
  TargetPlatform platform = TargetPlatform.iOS,
  bool reduceTransparency = false,
}) {
  final preferences = DisplayPreferencesController(
    platform: DisplayPreferencesPlatform.other,
  )..updateFromPlatform(reduceTransparency);
  addTearDown(preferences.dispose);
  return DisplayPreferencesScope(
    controller: preferences,
    child: MaterialApp(
      theme: mileafTheme(Brightness.light).copyWith(platform: platform),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

/// 液态玻璃在 widget 树里的两类 paint：玻璃体（叠色 + 受光边）与挖孔阴影。
Finder _glassPainters(Finder scope) => find.descendant(
  of: scope,
  matching: find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is LiquidGlassPainter,
  ),
);

LiquidGlassPainter _bodyPainter(WidgetTester tester, Finder surface) =>
    tester.widget<CustomPaint>(_glassPainters(surface).first).painter!
        as LiquidGlassPainter;

LiquidGlassShadowPainter _shadowPainter(WidgetTester tester, Finder surface) =>
    tester
            .widget<CustomPaint>(
              find
                  .descendant(
                    of: surface,
                    matching: find.byWidgetPredicate(
                      (widget) =>
                          widget is CustomPaint &&
                          widget.painter is LiquidGlassShadowPainter,
                    ),
                  )
                  .first,
            )
            .painter!
        as LiquidGlassShadowPainter;

MileafPullDown<String> _pullDown({ValueChanged<String>? onChanged}) =>
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

MapScene _scene() => driveScene(
  coordinates: const [
    MapCoordinate(31.230, 121.470),
    MapCoordinate(31.231, 121.471),
    MapCoordinate(31.233, 121.473),
  ],
  start: const MapCoordinate(31.230, 121.470),
  end: const MapCoordinate(31.233, 121.473),
  selected: const MapCoordinate(31.231, 121.471),
  selectedLabel: '选中',
  brightness: Brightness.light,
  interactive: false,
);

void main() {
  group('CL14 按钮图标纪律', () {
    testWidgets('图标在左、与文字间距 s8（主/次/文字按钮同一条规则）', (tester) async {
      for (final kind in MileafButtonKind.values) {
        await tester.pumpWidget(
          _board(
            MileafButton(
              label: '刷新',
              kind: kind,
              icon: MileafActionIcon.refresh,
              onPressed: () {},
            ),
          ),
        );
        final icon = tester.getRect(find.byType(MileafIcon));
        final text = tester.getRect(find.text('刷新'));
        expect(
          icon.right,
          lessThanOrEqualTo(text.left),
          reason: '$kind：图标槽在文字左侧',
        );
        expect(
          text.left - icon.right,
          MileafSpace.s8,
          reason: '$kind：图标与文字之间只有 s8（CL13.1）',
        );
        expect(
          icon.width,
          MileafIconMetrics.inline,
          reason: '按钮内图标是 inline 16',
        );
        expect(
          (icon.center.dy - text.center.dy).abs(),
          lessThan(1),
          reason: '$kind：Row 交叉轴居中，图标与文字视觉居中',
        );
      }
      expect(MileafControlMetrics.buttonIconGap, MileafSpace.s8);
    });

    testWidgets('图标槽恰好占 inline 16 + s8，无图标时不占位', (tester) async {
      double widthOf(MileafIconName? icon) =>
          tester.getSize(find.byType(MileafButton)).width;
      await tester.pumpWidget(
        _board(MileafButton(label: '刷新', onPressed: () {})),
      );
      final bare = widthOf(null);
      await tester.pumpWidget(
        _board(
          MileafButton(
            label: '刷新',
            icon: MileafActionIcon.refresh,
            onPressed: () {},
          ),
        ),
      );
      expect(
        widthOf(MileafActionIcon.refresh) - bare,
        MileafIconMetrics.inline + MileafSpace.s8,
        reason: '图标槽多出来的只有图标本身与 s8，没有第二处间距',
      );
      expect(
        MileafControlMetrics.iconLeading(null, const Color(0xFF000000)),
        isEmpty,
      );
    });

    test('动作 → 字形映射表：同一动作同一字形，不引入第二套图标库', () {
      expect(MileafActionIcon.refresh, MileafIconName.refresh);
      expect(MileafActionIcon.share, MileafIconName.share);
      expect(MileafActionIcon.compare, MileafIconName.chart);
      expect(MileafActionIcon.addCost, MileafIconName.wallet);
      expect(MileafActionIcon.expand, MileafIconName.expand);
      expect(MileafActionIcon.map, MileafIconName.mapPin);
      expect(MileafActionIcon.filter, MileafIconName.chevronDown);
      expect(MileafActionIcon.copy, MileafIconName.copy);
      expect(MileafActionIcon.clear, MileafIconName.close);
      expect(MileafActionIcon.save, MileafIconName.check);
      expect(MileafActionIcon.dateRange, MileafIconName.calendar);
      // 「重试」与「刷新」是同一个动作的两种措辞：不得换字形（CL14 第三条）。
      expect(MileafActionIcon.retry, MileafActionIcon.refresh);
    });
  });

  group('CL30/CL31 浮层玻璃', () {
    testWidgets('下拉菜单背板是共享玻璃，σ 与过饱和取自 MileafMaterialMetrics', (tester) async {
      await tester.pumpWidget(_board(_pullDown()));
      await tester.tap(find.byType(MileafPullDown<String>));
      await tester.pumpAndSettle();

      final surface = find.byKey(kPullDownMenuSurfaceKey);
      expect(surface, findsOneWidget);
      expect(tester.widget(surface), isA<MileafGlassSurface>());
      expect(
        tester.widget<MileafGlassSurface>(surface).borderRadius,
        BorderRadius.circular(MileafControlMetrics.menuRadius),
        reason: 'CL21：浮层菜单半径 14，与 R28 相同',
      );

      final filters = tester
          .widgetList<BackdropFilter>(
            find.descendant(of: surface, matching: find.byType(BackdropFilter)),
          )
          .toList();
      expect(filters, hasLength(1), reason: '一块浮层只有一层有界模糊');
      final filter = filters.single.filter.toString();
      final sigma = MileafMaterialMetrics.glassBlur;
      expect(
        filter,
        contains('blur($sigma, $sigma'),
        reason: 'σ 必须等于 MileafMaterialMetrics.glassBlur（CL31：全站同一来源）',
      );
      // 过饱和：矩阵首项 = 0.2126 * (1 - s) + s，与 glassSaturation 一一对应。
      final saturationEntry = saturationMatrix(
        MileafMaterialMetrics.glassSaturation,
      ).first;
      expect(
        filter,
        contains(saturationEntry.toStringAsFixed(4)),
        reason: '过饱和必须等于 MileafMaterialMetrics.glassSaturation',
      );
    });

    testWidgets('菜单背板使用控件玻璃的中性叠色、边缘和阴影', (tester) async {
      await tester.pumpWidget(_board(_pullDown()));
      await tester.tap(find.byType(MileafPullDown<String>));
      await tester.pumpAndSettle();
      final surface = find.byKey(kPullDownMenuSurfaceKey);
      const colors = MileafColors.light();
      final body = _bodyPainter(tester, surface);
      final tint = colors.surface.withValues(
        alpha: MileafMaterialMetrics.controlGlassOpacity,
      );
      expect(body.fillTop, tint);
      expect(
        body.fillBottom,
        colors.surface.withValues(
          alpha: MileafMaterialMetrics.controlGlassBottomOpacity,
        ),
      );
      expect(body.meniscus, isNotNull);
      expect(body.edge, colors.glassEdge, reason: '受光边缘含 1px 描边兜底');
      final dpr = tester.view.devicePixelRatio;
      expect(
        body.rimStroke * dpr,
        greaterThanOrEqualTo(1),
        reason: 'CL31：玻璃必带 1px 描边兜底（浅色压亮内容时的边界）',
      );
      expect(body.innerStroke, greaterThan(0));
      expect(
        _shadowPainter(tester, surface).shadows,
        MileafElevation.controlGlassLight,
        reason: 'CL31：浮层阴影只有一处来源',
      );
    });

    testWidgets('减少透明度时菜单保留尺寸与选择能力，移除模糊', (tester) async {
      String? picked;
      await tester.pumpWidget(
        _board(
          _pullDown(onChanged: (value) => picked = value),
          reduceTransparency: true,
        ),
      );
      await tester.tap(find.byType(MileafPullDown<String>));
      await tester.pumpAndSettle();
      final surface = find.byKey(kPullDownMenuSurfaceKey);
      expect(surface, findsOneWidget);
      expect(
        find.descendant(of: surface, matching: find.byType(BackdropFilter)),
        findsNothing,
      );
      final options = find.descendant(
        of: surface,
        matching: find.byType(GestureDetector),
      );
      await tester.tap(options.last);
      await tester.pumpAndSettle();
      expect(picked, isNotNull);
    });

    testWidgets('点外部只关菜单、不改值', (tester) async {
      String? picked;
      await tester.pumpWidget(
        _board(_pullDown(onChanged: (value) => picked = value)),
      );
      await tester.tap(find.byType(MileafPullDown<String>));
      await tester.pumpAndSettle();
      expect(find.byKey(kPullDownMenuSurfaceKey), findsOneWidget);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();
      expect(find.byKey(kPullDownMenuSurfaceKey), findsNothing);
      expect(picked, isNull);
    });

    testWidgets('选择弹层用一层有界玻璃，贴边表单与减少透明度使用实色', (tester) async {
      const colors = MileafColors.light();
      for (final (style, reduced, blurCount) in [
        (MileafSheetStyle.floating, false, 1),
        (MileafSheetStyle.floating, true, 0),
        (MileafSheetStyle.edge, false, 0),
      ]) {
        await tester.pumpWidget(
          _board(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showMileafSheet<void>(
                  context: context,
                  title: '选择',
                  style: style,
                  builder: (_) => const SizedBox(height: 80),
                ),
                child: const Text('打开'),
              ),
            ),
            reduceTransparency: reduced,
          ),
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        expect(find.byType(MileafSheetFrame), findsOneWidget);
        final surface = find.byKey(const ValueKey('sheet-surface'));
        expect(
          find.descendant(of: surface, matching: find.byType(BackdropFilter)),
          findsNWidgets(blurCount),
        );
        if (style == MileafSheetStyle.edge) {
          final decoration =
              tester.widget<DecoratedBox>(surface).decoration as BoxDecoration;
          expect(decoration.color, colors.surfaceRaised);
        } else if (reduced) {
          expect(_glassPainters(surface), findsNothing);
        } else {
          expect(_glassPainters(surface), findsOneWidget);
        }
        // 关掉弹层，避免下一次 pumpWidget 里残留路由。
        await tester.tap(find.byTooltip('关闭'));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('地图浮控背板改玻璃，36 圆钮几何不变', (tester) async {
      final fake = FakeMapPlatform();
      final consent = MapConsentController();
      addTearDown(consent.dispose);
      await consent.grant(fake.providerName);
      await tester.pumpWidget(
        _board(
          SizedBox(
            height: 320,
            child: MapPanel(
              scene: _scene(),
              consent: consent,
              platform: fake,
              height: 320,
              showControls: true,
              onExpand: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      fake.completeLoad('GS(test)');
      await tester.pumpAndSettle();

      final panel = find.byType(MapPanel);
      // 适配轨迹 / 放大 / 缩小 / 查看完整地图：四枚浮控各垫一块玻璃。
      final glass = find.descendant(
        of: panel,
        matching: find.byType(MileafGlassSurface),
      );
      expect(glass, findsNWidgets(4));
      for (var i = 0; i < 4; i++) {
        expect(
          tester.widget<MileafGlassSurface>(glass.at(i)).borderRadius,
          MileafRadius.fullAll,
          reason: '地图浮控是圆形（R24/MileafShape.circle）',
        );
        expect(
          tester.getSize(glass.at(i)),
          const Size.square(MileafControlMetrics.iconVisual),
        );
        expect(
          find.descendant(
            of: find
                .ancestor(of: glass.at(i), matching: find.byType(Stack))
                .first,
            matching: find.byType(BackdropFilter),
          ),
          findsWidgets,
        );
      }
      final buttons = tester.widgetList<MileafIconButton>(
        find.descendant(of: panel, matching: find.byType(MileafIconButton)),
      );
      expect(buttons, isNotEmpty);
      for (final button in buttons) {
        // 背板已交给玻璃；圆钮自己不再画 segmentTrack 实色。
        expect(button.fill, MileafIconButtonFill.none);
      }
    });

    test('浮层菜单与地图浮控的源码不重写玻璃数值（CL31.1）', () {
      const paths = [
        'lib/src/design/components/pull_down.dart',
        'lib/src/map/map_panel.dart',
      ];
      for (final path in paths) {
        final source = File(path).readAsStringSync();
        expect(
          source.contains('ImageFilter'),
          isFalse,
          reason: '$path 不得自建模糊（σ 只有 MileafMaterialMetrics 一个来源）',
        );
        expect(source.contains('sigmaX'), isFalse, reason: path);
        expect(source.contains('sigmaY'), isFalse, reason: path);
        expect(
          RegExp(r'glassBlur\s*[:=]').hasMatch(source),
          isFalse,
          reason: '$path 不得覆盖 glassBlur',
        );
        expect(
          RegExp(r'glassSaturation\s*[:=]').hasMatch(source),
          isFalse,
          reason: '$path 不得覆盖 glassSaturation',
        );
      }
    });
  });

  group('CL31 玻璃参数单一来源', () {
    test('22σ / 1.5 过饱和，且模糊不得低于 18', () {
      expect(MileafMaterialMetrics.glassBlur, 22.0);
      expect(MileafMaterialMetrics.glassSaturation, 1.5);
      expect(
        MileafMaterialMetrics.glassBlur,
        greaterThanOrEqualTo(18.0),
        reason: 'CL31.1：σ < 18 视为违反（背后内容仍可辨识是玻璃的前提）',
      );
    });
  });
}
