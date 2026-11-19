// MG04/R32 图标家族守卫 + opt-in 渲染入口。
// 常规断言常绿：家族参数、逐图标渲染与语义标签、像素探针。
// opt-in 渲染：未设置 MILEAF_RENDER_OUTPUT / MILEAF_RENDER_FONT 时整组跳过。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/icons.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/tokens.dart';
import 'package:mileaf/src/design/typography.dart';

import 'support/pixel_probe.dart';
import 'support/render_fonts.dart';
import 'support/render_png.dart';

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

/// 家族清单（CL11）：25 个既有字形 + MC03 扩的 4 个 = 29。
///
/// 写成显式清单而不是只读 `MileafIconName.values`，是为了让「多一个/少一个
/// 字形」必须显式改这里——扩字形是有意决定，不是顺手加一个枚举值。
const familyManifest = <MileafIconName>[
  MileafIconName.home,
  MileafIconName.car,
  MileafIconName.bolt,
  MileafIconName.chart,
  MileafIconName.route,
  MileafIconName.mapPin,
  MileafIconName.battery,
  MileafIconName.clock,
  MileafIconName.settings,
  MileafIconName.chevron,
  MileafIconName.refresh,
  MileafIconName.wallet,
  MileafIconName.info,
  MileafIconName.close,
  MileafIconName.check,
  MileafIconName.copy,
  MileafIconName.calendar,
  MileafIconName.more,
  MileafIconName.expand,
  MileafIconName.chevronDown,
  MileafIconName.back,
  MileafIconName.plus,
  MileafIconName.minus,
  MileafIconName.moon,
  MileafIconName.offline,
  MileafIconName.leaf,
  MileafIconName.thermometer,
  MileafIconName.speed,
  MileafIconName.share,
];

/// MC03/CL11 新增的四个字形（效率 / 环境 / 速度 / 分享）。
const newGlyphs = <MileafIconName>[
  MileafIconName.leaf,
  MileafIconName.thermometer,
  MileafIconName.speed,
  MileafIconName.share,
];

/// 四个新字形的登记语义（CL11.1）与规格 §5 的域绑定一致。
const newGlyphLabels = <MileafIconName, String>{
  MileafIconName.leaf: '续航与效率',
  MileafIconName.thermometer: '温度',
  MileafIconName.speed: '速度',
  MileafIconName.share: '分享',
};

/// 白底上的黑笔画，与家族守卫同一条「深于中灰」口径。
const _stroke = Color(0xFF000000);
const _strokeTolerance = 127;

bool _isStroke(Color pixel) =>
    pixel.r * 255 <= _strokeTolerance &&
    pixel.g * 255 <= _strokeTolerance &&
    pixel.b * 255 <= _strokeTolerance;

/// 按 [size] 渲染单个图标，取回它的像素（含白底，见下方白底说明）。
Future<PixelProbe> _inkProbe(
  WidgetTester tester,
  MileafIconName name,
  double size,
) async {
  final boundary = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: RepaintBoundary(
            key: boundary,
            // 白底必须在边界子树内：探针按 RGB 匹配，透明像素会被误判为黑。
            child: Container(
              width: size,
              height: size,
              color: Colors.white,
              child: MileafIcon(name, size: size, color: _stroke),
            ),
          ),
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull, reason: '${name.name}@$size');
  return capturePixels(tester, find.byKey(boundary));
}

/// 笔画外接框（图标局部像素坐标）。
Future<Rect> _inkBounds(
  WidgetTester tester,
  MileafIconName name,
  double size,
) async {
  final probe = await _inkProbe(tester, name, size);
  final box = probe.bounds(_stroke, tolerance: _strokeTolerance);
  expect(box, isNotNull, reason: '${name.name}@$size 必须画出可见笔画');
  return box!;
}

void main() {
  group('MileafIconFamily 家族参数', () {
    test('全部导出图标登记 24 网格、1.5 描边、圆头圆角（R32）', () {
      expect(MileafIconFamily.grid, 24);
      expect(MileafIconFamily.strokeWidth, 1.5);
      expect(MileafIconFamily.strokeCap, StrokeCap.round);
      expect(MileafIconFamily.strokeJoin, StrokeJoin.round);
      // 参数单一来源：家族常量必须与 MileafIconMetrics 同源，不得另抄数值。
      expect(MileafIconFamily.grid, MileafIconMetrics.grid);
      expect(MileafIconFamily.strokeWidth, MileafIconMetrics.stroke);
      expect(MileafIconFamily.boxInline, MileafIconMetrics.inline);
      expect(MileafIconFamily.boxNav, MileafIconMetrics.nav);
      expect(MileafIconFamily.boxHeader, MileafIconMetrics.header);
    });

    test('语义标签覆盖每个导出图标且非空不重复', () {
      final names = MileafIconName.values;
      expect(MileafIconFamily.semanticLabels.keys.toSet(), names.toSet());
      final labels = [
        for (final name in names) MileafIconFamily.semanticLabels[name]!,
      ];
      for (final label in labels) {
        expect(label, isNotEmpty, reason: '语义标签不得为空（CP11）');
      }
      expect(labels.toSet().length, labels.length, reason: '语义标签不得重名');
    });
  });

  group('MC03 新增四字形（CL11）', () {
    test('家族清单 29 个：25 个既有 + leaf/thermometer/speed/share', () {
      expect(familyManifest, hasLength(29));
      expect(familyManifest.length, MileafIconName.values.length);
      expect(familyManifest.toSet(), MileafIconName.values.toSet());
      expect(
        familyManifest.toSet().length,
        familyManifest.length,
        reason: '清单内不得重复',
      );
      for (final name in newGlyphs) {
        expect(familyManifest, contains(name), reason: name.name);
      }
    });

    test('四个新字形都登记了语义标签（CL11.1）', () {
      for (final entry in newGlyphLabels.entries) {
        expect(
          MileafIconFamily.semanticLabels[entry.key],
          entry.value,
          reason: '${entry.key.name} 的语义标签必须是「${entry.value}」',
        );
      }
      // 只补新值：「覆盖全集且不重名」由既有家族组继续守住，这里不放宽。
      expect(newGlyphLabels.values.toSet(), hasLength(newGlyphLabels.length));
      for (final label in newGlyphLabels.values) {
        expect(label, isNotEmpty);
      }
    });

    testWidgets('四个新字形沿用同一组家族参数：24 网格内等比缩放', (tester) async {
      // 家族参数单一来源：与既有家族组同源，针对新字形再钉一次。
      expect(MileafIconFamily.grid, 24);
      expect(MileafIconFamily.strokeWidth, 1.5);
      expect(MileafIconFamily.strokeCap, StrokeCap.round);
      expect(MileafIconFamily.strokeJoin, StrokeJoin.round);
      const ratio = MileafIconFamily.boxInline / MileafIconFamily.grid;
      for (final name in newGlyphs) {
        final atGrid = await _inkBounds(tester, name, MileafIconFamily.grid);
        final boxReason = '${name.name} 笔画越出 24 视觉盒：$atGrid';
        expect(atGrid.left, greaterThanOrEqualTo(0.5), reason: boxReason);
        expect(atGrid.top, greaterThanOrEqualTo(0.5), reason: boxReason);
        expect(atGrid.right, lessThanOrEqualTo(23.5), reason: boxReason);
        expect(atGrid.bottom, lessThanOrEqualTo(23.5), reason: boxReason);
        // 16 视觉盒下同一字形按 2/3 等比缩小（±1 px 端点量化容差），
        // 证明绘制走的是 `size / grid` 缩放与同一条 1.5 线宽。
        final atInline = await _inkBounds(
          tester,
          name,
          MileafIconFamily.boxInline,
        );
        final scaleReason = '${name.name} 未按 24 网格等比缩到 16 视觉盒';
        expect(
          atInline.left,
          closeTo(atGrid.left * ratio, 1),
          reason: scaleReason,
        );
        expect(
          atInline.top,
          closeTo(atGrid.top * ratio, 1),
          reason: scaleReason,
        );
        expect(
          atInline.right,
          closeTo(atGrid.right * ratio, 1),
          reason: scaleReason,
        );
        expect(
          atInline.bottom,
          closeTo(atGrid.bottom * ratio, 1),
          reason: scaleReason,
        );
      }
    });

    testWidgets('leaf 在 16 视觉盒下仍是两瓣 + 中脉', (tester) async {
      final probe = await _inkProbe(
        tester,
        MileafIconName.leaf,
        MileafIconFamily.boxInline,
      );
      // 最宽处（网格 y≈12.2 → 16 盒 y≈8）应读成「左瓣 · 中脉 · 右瓣」三段，
      // 缩到 16 不糊成一坨，也没有加密集叶脉（CL11）。
      var widest = 0;
      for (var row = 0; row < probe.height; row++) {
        var runs = 0;
        var inInk = false;
        for (var col = 0; col < probe.width; col++) {
          final ink = _isStroke(probe.at(col, row));
          if (ink && !inInk) runs++;
          inInk = ink;
        }
        if (runs > widest) widest = runs;
      }
      expect(
        widest,
        greaterThanOrEqualTo(3),
        reason: '16 视觉盒下叶片应是左瓣+中脉+右瓣三段笔画，实测 $widest 段',
      );
    });
  });

  group('逐导出图标渲染', () {
    testWidgets('每个图标 pump 不抛错且语义标签存在', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        for (final name in MileafIconName.values) {
          final label = MileafIconFamily.semanticLabels[name]!;
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MileafIcon(
                  name,
                  semanticLabel: label,
                  color: Colors.black,
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: name.name);
          expect(
            find.bySemanticsLabel(label),
            findsOneWidget,
            reason: '${name.name} 必须携带语义标签「$label」',
          );
        }
      } finally {
        // 语义句柄必须在测试体内释放（end-of-test 校验先于 tearDown）。
        semantics.dispose();
      }
    });

    testWidgets('每个图标实际画出笔画且不越出 24 视觉盒', (tester) async {
      final boundary = GlobalKey();
      for (final name in MileafIconName.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: RepaintBoundary(
                  key: boundary,
                  // 白底必须在边界子树内：探针按 RGB 匹配，透明像素会被
                  // 误判为黑（PixelProbe 不比较 alpha）。
                  child: Container(
                    color: Colors.white,
                    child: MileafIcon(
                      name,
                      size: MileafIconFamily.grid,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: name.name);
        final probe = await capturePixels(tester, find.byKey(boundary));
        // 1.5 斜向笔画可能没有全覆盖像素（全黑），按「深于中灰」计笔画。
        // PixelProbe 只比 RGB 不比 alpha，所以白底必须画在边界子树内。
        const stroke = Color(0xFF000000);
        const strokeTolerance = 127;
        expect(
          probe.count(stroke, tolerance: strokeTolerance),
          greaterThan(0),
          reason: '${name.name} 必须画出可见笔画',
        );
        final box = probe.bounds(stroke, tolerance: strokeTolerance)!;
        final reason = '${name.name} 笔画越出视觉盒：$box';
        expect(box.left, greaterThanOrEqualTo(0.5), reason: reason);
        expect(box.top, greaterThanOrEqualTo(0.5), reason: reason);
        expect(box.right, lessThanOrEqualTo(23.5), reason: reason);
        expect(box.bottom, lessThanOrEqualTo(23.5), reason: reason);
      }
    });
  });

  group('DM02 opt-in 渲染入口', () {
    setUpAll(() async {
      if (fontPath.isNotEmpty) await loadRenderFonts(cjkFontPath: fontPath);
    });

    Widget iconBoard(Brightness brightness) {
      final colors = brightness == Brightness.dark
          ? const MileafColors.dark()
          : const MileafColors.light();
      final t = MileafTextStyles.resolve(colors);
      return MaterialApp(
        theme: mileafTheme(brightness),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              Text('行笺 · 图标家族出口', style: t.title2),
              const SizedBox(height: 4),
              Text(
                'MG04 统一出口 · ${MileafIconName.values.length} 图标 · '
                '${MileafIconFamily.grid} 网格 ${MileafIconFamily.strokeWidth} '
                '描边（DM02）',
                style: t.subheadline,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final name in MileafIconName.values)
                    SizedBox(
                      width: 104,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MileafIcon(
                            name,
                            size: MileafIconFamily.boxHeader,
                            color: colors.text,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            MileafIconFamily.semanticLabels[name]!,
                            style: t.caption,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('浅深双模式图标图板', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      final boundary = GlobalKey();
      final files = <String>[];
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          RepaintBoundary(key: boundary, child: iconBoard(brightness)),
        );
        await tester.pumpAndSettle();
        final file = 'DM02-icons-normal-${brightness.name}-390x844-100.png';
        await saveRenderPng(tester, find.byKey(boundary), '$output/$file');
        files.add(file);
      }
      expect(tester.takeException(), isNull);
      expect(files, hasLength(Brightness.values.length));
    }, skip: output.isEmpty || fontPath.isEmpty);
  });
}
