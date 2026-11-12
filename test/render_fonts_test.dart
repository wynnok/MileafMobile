import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/charts.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/tokens.dart';
import 'package:mileaf/src/design/typography.dart';

import 'support/pixel_probe.dart';
import 'support/render_fonts.dart';

const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

/// The family and fallbacks a `Text` really paints with.
TextStyle paintedStyle(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text)).text.style!;

Future<Uint8List> _ink(WidgetTester tester, String text, TextStyle style) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFFFFFFFF),
            child: Text(text, style: style),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (await capturePixels(tester, find.byKey(key))).bytes;
}

void main() {
  group('字体族契约', () {
    test('渲染入口只把中文回退注册为回退族，不冒充 Inter', () {
      // The shipped Inter weights and the theme's family contract are owned by
      // design_tokens_test; what matters here is which families a render
      // harness may register a substitute CJK face under.
      expect(renderFallbackFamilies, MileafType.fallback);
      expect(renderFallbackFamilies, isNot(contains('Inter')));
      expect(renderFallbackFamilies, isNot(contains('Roboto')));
      expect(renderFallbackFamilies, isNot(contains('Arial')));
    });

    test('产品代码不写死字体族名字（设计层 token 除外）', () {
      final literal = RegExp(r'''fontFamily(?:Fallback)?:\s*(?:const\s*)?['"]''');
      final offenders = <String>[];
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        if (file.path.contains('/design/')) continue;
        if (literal.hasMatch(source) ||
            source.contains("'Roboto'") ||
            source.contains("'Arial'")) {
          offenders.add(file.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '字体族只能引用 design 层 token，不得写死族名或别名',
      );
    });
  });

  group('实际落点', () {
    testWidgets('默认 Material 文字落在 Inter + 独立中文回退', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(Brightness.light),
          home: Scaffold(
            body: ListTile(
              title: const Text('行笺'),
              subtitle: const Text('320 km'),
            ),
          ),
        ),
      );
      final theme = Theme.of(tester.element(find.byType(ListTile)));
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
      expect(theme.textTheme.bodyMedium?.fontFamilyFallback, MileafType.fallback);

      for (final text in ['行笺', '320 km']) {
        final style = paintedStyle(tester, text);
        expect(style.fontFamily, 'Inter', reason: '$text 应使用随包 Inter');
        expect(
          style.fontFamilyFallback,
          MileafType.fallback,
          reason: '$text 的中文回退应是声明的回退族',
        );
      }
    });

    testWidgets('图表自绘文字使用同一字体族与回退', (tester) async {
      final style = chartAxisLabelStyle(
        color: const Color(0xFF000000),
        scaler: TextScaler.noScaling,
      );
      expect(style.fontFamily, 'Inter');
      expect(style.fontFamilyFallback, MileafType.fallback);
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));

      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(Brightness.dark),
          home: const Scaffold(
            body: SizedBox(
              width: 320,
              child: TimeSeriesChart(
                title: '每日里程',
                unit: 'km',
                times: [],
                series: [],
                semanticsLabel: '每日里程图表',
              ),
            ),
          ),
        ),
      );
      expect(find.text('每日里程'), findsOneWidget);
      final title = paintedStyle(tester, '每日里程');
      expect(title.fontFamily, 'Inter');
      expect(title.fontFamilyFallback, MileafType.fallback);
    });

    testWidgets(
      '中文经声明的回退族渲染，而不是被当成 Inter 或测试字体',
      (tester) async {
        await loadRenderFonts(cjkFontPath: fontPath);
        const colors = MileafColors.light();
        final body = MileafTextStyles.resolve(colors).body;

        // What the theme asks for: Inter first, then the declared CJK family.
        final throughTheme = await _ink(tester, '行笺', body);
        // The same text asked for the fallback family alone.
        final throughFallback = await _ink(
          tester,
          '行笺',
          body.copyWith(
            fontFamily: 'PingFang SC',
            fontFamilyFallback: const [],
          ),
        );
        // Inter alone has no CJK glyphs: this must not match.
        final throughInterOnly = await _ink(
          tester,
          '行笺',
          body.copyWith(fontFamilyFallback: const []),
        );

        expect(
          throughTheme,
          equals(throughFallback),
          reason: '主题的中文应落在声明的回退族上',
        );
        expect(
          throughTheme,
          isNot(equals(throughInterOnly)),
          reason: '中文不能被当作 Inter 字形渲染',
        );
      },
      skip: fontPath.isEmpty,
    );
  });
}
