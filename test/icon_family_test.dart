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
