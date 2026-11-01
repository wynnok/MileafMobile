import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/brand_mark.dart';
import 'package:mileaf/src/design/icons.dart';
import 'package:mileaf/src/design/layout.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/tokens.dart';
import 'package:mileaf/src/design/typography.dart';

double _linear(double channel) => channel <= 0.04045
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color color) =>
    0.2126 * _linear(color.r) +
    0.7152 * _linear(color.g) +
    0.0722 * _linear(color.b);

double contrast(Color foreground, Color background) {
  final a = _luminance(foreground), b = _luminance(background);
  final high = a > b ? a : b, low = a > b ? b : a;
  return (high + .05) / (low + .05);
}

void _expectContrast(
  String name,
  Color foreground,
  Color background,
  double expected,
) {
  final value = contrast(foreground, background);
  expect(
    value,
    closeTo(expected, .06),
    reason: '$name 对比度应与 Spec §2.4 一致（实测 $value）',
  );
  expect(value, greaterThanOrEqualTo(4.5), reason: '$name 未达 WCAG AA');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Spec §2.4 对比度', () {
    test('深色语义色', () {
      const c = MileafColors.dark();
      _expectContrast('text/canvas', c.text, c.canvas, 18.16);
      _expectContrast('muted/canvas', c.textMuted, c.canvas, 6.59);
      _expectContrast('faint/canvas', c.textFaint, c.canvas, 5.07);
      _expectContrast('accent/canvas', c.accent, c.canvas, 12.03);
      _expectContrast('reference/canvas', c.reference, c.canvas, 10.06);
      _expectContrast('warning/canvas', c.warning, c.canvas, 9.17);
      _expectContrast('error/canvas', c.error, c.canvas, 7.59);
      _expectContrast('textOnAccent/accent', c.textOnAccent, c.accent, 11.64);
    });

    test('浅色语义色', () {
      const c = MileafColors.light();
      _expectContrast('text/canvas', c.text, c.canvas, 16.00);
      _expectContrast('muted/canvas', c.textMuted, c.canvas, 4.94);
      _expectContrast('faint/canvas', c.textFaint, c.canvas, 4.59);
      _expectContrast('accent/canvas', c.accent, c.canvas, 5.64);
      _expectContrast('reference/canvas', c.reference, c.canvas, 5.17);
      _expectContrast('warning/canvas', c.warning, c.canvas, 6.54);
      _expectContrast('error/canvas', c.error, c.canvas, 5.10);
      _expectContrast('textOnAccent/accent', c.textOnAccent, c.accent, 6.10);
    });

    test('浅色模式仍保留深色 hero', () {
      const c = MileafColors.light();
      expect(c.hero, isNot(c.canvas));
      _expectContrast('heroText/hero', c.heroText, c.hero, 16.22);
      expect(
        contrast(c.heroMuted, c.hero),
        inInclusiveRange(8.4, 9.7),
      );
      expect(contrast(c.heroFaint, c.hero), greaterThanOrEqualTo(4.5));
      _expectContrast('heroText/darkHero', c.heroText, MileafPalette.jade900, 18.29);
      _expectContrast('heroFaint/darkHero', c.heroFaint, MileafPalette.jade900, 5.36);
    });

    test('比较与状态不靠红绿，线只用于非文本装饰', () {
      const dark = MileafColors.dark();
      final reference = contrast(dark.reference, dark.canvas);
      final warning = contrast(dark.warning, dark.canvas);
      final error = contrast(dark.error, dark.canvas);
      expect({reference > 4.5, warning > 4.5, error > 4.5}, {true});
      // Lines are decorative 1px strokes and never carry information alone.
      expect(dark.line.a, lessThan(.2));
      expect(dark.lineStrong.a, lessThan(.2));
    });
  });

  group('token 完整性', () {
    test('间距为 4px 基准的有名档位', () {
      final spacing = {
        MileafSpace.s4,
        MileafSpace.s8,
        MileafSpace.s12,
        MileafSpace.s16,
        MileafSpace.s20,
        MileafSpace.s24,
        MileafSpace.section,
        MileafSpace.s32,
        MileafSpace.s40,
        MileafSpace.s56,
      };
      expect(spacing, {4.0, 8.0, 12.0, 16.0, 20.0, 24.0, 28.0, 32.0, 40.0, 56.0});
      expect(MileafSpace.section % 4, 0);
      expect(MileafSpace.touch, 44);
      expect(MileafSpace.navHeight, 64);
      expect(MileafSpace.contentBottom, 84);
      expect(MileafSpace.rowMin, 56);
    });

    test('圆角与动效时长锁定', () {
      expect(
        {
          MileafRadius.none.x,
          MileafRadius.xs,
          MileafRadius.sm,
          MileafRadius.md,
          MileafRadius.lg,
          MileafRadius.full,
        },
        {0.0, 4.0, 10.0, 12.0, 20.0, 999.0},
      );
      expect(
        {
          MileafDurations.press.inMilliseconds,
          MileafDurations.tab.inMilliseconds,
          MileafDurations.enter.inMilliseconds,
          MileafDurations.value.inMilliseconds,
          MileafDurations.sheet.inMilliseconds,
          MileafDurations.chart.inMilliseconds,
        },
        {120, 160, 180, 220, 240, 500},
      );
    });

    test('五级字号与尺寸变体', () {
      expect(MileafType.displaySize, 60);
      expect(MileafType.metricLgSize, 44);
      expect(MileafType.metricMdSize, 24);
      expect(MileafType.titleSize, 18);
      expect(MileafType.bodySize, 13);
      expect(MileafType.labelSize, 10);
      expect(MileafType.microSize, 9);
      expect(MileafType.displayTracking, -.04);
      expect(MileafType.labelTracking, .08);
    });

    test('每个字号 level 都带 tabular figures', () {
      final type = MileafTextStyles.resolve(const MileafColors.dark());
      for (final style in [
        type.display,
        type.metricLg,
        type.metricMd,
        type.title,
        type.body,
        type.label,
        type.micro,
      ]) {
        expect(style.fontFamily, 'Inter');
        expect(style.fontFamilyFallback, contains('PingFang SC'));
        expect(
          style.fontFeatures?.any((f) => f.feature == 'tnum'),
          isTrue,
          reason: '所有数字必须 tabular',
        );
      }
    });

    test('浅色 hero 与页面底色不同，深色默认使用 hero 锚点', () {
      const dark = MileafColors.dark();
      const light = MileafColors.light();
      expect(dark.hero, MileafPalette.jade900);
      expect(light.hero, MileafPalette.jade800);
      expect(dark.canvas, MileafPalette.canvasDark);
      expect(light.canvas, MileafPalette.stone50);
      expect(light.accent, MileafPalette.jade500);
      expect(light.accentHero, MileafPalette.jade300);
      expect(dark.accent, MileafPalette.jade300);
    });

    test('主题挂载语义与字号扩展，且默认深色底', () {
      final dark = mileafTheme(Brightness.dark);
      expect(dark.scaffoldBackgroundColor, const MileafColors.dark().canvas);
      expect(dark.extension<MileafColors>(), isA<MileafColors>());
      expect(dark.extension<MileafTextStyles>()?.title.fontSize, 18);
      final light = mileafTheme(Brightness.light);
      expect(light.scaffoldBackgroundColor, const MileafColors.light().canvas);
      expect(
        light.textTheme.bodyMedium?.fontFamily,
        'Inter',
        reason: 'Material 文本也使用锁定字体',
      );
    });

    test('页面不再引用旧 lakeTheme', () {
      final offenders = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => file.readAsStringSync().contains('lakeTheme'))
          .map((file) => file.path)
          .toList();
      expect(offenders, isEmpty);
    });
  });

  group('Inter 字体资产', () {
    testWidgets('三字重与 OFL 随包并可加载', (tester) async {
      for (final file in [
        'Inter-Regular.ttf',
        'Inter-Medium.ttf',
        'Inter-SemiBold.ttf',
      ]) {
        final data = await rootBundle.load('assets/fonts/$file');
        expect(data.lengthInBytes, greaterThan(100000), reason: file);
      }
      final license = await rootBundle.loadString('assets/fonts/OFL.txt');
      expect(license, contains('SIL Open Font License'));

      for (final file in [
        'Inter-Regular.ttf',
        'Inter-Medium.ttf',
        'Inter-SemiBold.ttf',
      ]) {
        final bytes = await rootBundle.load('assets/fonts/$file');
        await (FontLoader('Inter')..addFont(Future.value(bytes))).load();
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(Brightness.dark),
          home: const Scaffold(
            body: Text('320 km 1,198.6 行笺', style: TextStyle(fontFamily: 'Inter')),
          ),
        ),
      );
      expect(find.textContaining('1,198.6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('品牌与图标', () {
    testWidgets('M 径在 18/24/32/58 深浅底都可绘制', (tester) async {
      for (final brightness in Brightness.values) {
        for (final size in [18.0, 24.0, 32.0, 58.0]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: mileafTheme(brightness),
              home: Scaffold(
                body: Center(
                  child: BrandMark(size: size, semanticLabel: '行笺 $size'),
                ),
              ),
            ),
          );
          expect(tester.getSize(find.byType(BrandMark)), Size.square(size));
          expect(tester.takeException(), isNull);
          expect(find.byType(CustomPaint), findsWidgets);
        }
      }
    });

    testWidgets('字标包含中文名与拉丁描述', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(Brightness.dark),
          home: const Scaffold(body: MileafWordmark()),
        ),
      );
      expect(find.text('行笺'), findsOneWidget);
      expect(find.text('MILEAF'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('15 个关键图标在 16/20/24 都可绘制', (tester) async {
      expect(MileafIconName.values.length, 15);
      for (final brightness in Brightness.values) {
        for (final size in [
          MileafIconMetrics.inline,
          MileafIconMetrics.nav,
          MileafIconMetrics.header,
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: mileafTheme(brightness),
              home: Scaffold(
                body: Wrap(
                  children: [
                    for (final name in MileafIconName.values)
                      MileafIcon(
                        name,
                        size: size,
                        semanticLabel: name.name,
                      ),
                  ],
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byType(MileafIcon).first),
            Size.square(size),
          );
        }
      }
    });
  });

  group('响应式与动效', () {
    testWidgets('页面左右留白按宽度切换 20/24', (tester) async {
      Future<double> inset(double width) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        late double value;
        await tester.pumpWidget(
          MaterialApp(
            theme: mileafTheme(Brightness.dark),
            home: Builder(
              builder: (context) {
                value = MileafLayout.pageInset(context);
                return const SizedBox();
              },
            ),
          ),
        );
        return value;
      }

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      expect(await inset(360), 20);
      expect(await inset(390), 24);
    });

    testWidgets('150% 起进入大字号断点', (tester) async {
      Future<bool> large(double scale) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        late bool value;
        await tester.pumpWidget(
          MaterialApp(
            theme: mileafTheme(Brightness.dark),
            home: Builder(
              builder: (context) {
                value = MileafLayout.largeText(context);
                return const SizedBox();
              },
            ),
          ),
        );
        return value;
      }

      addTearDown(
        () => tester.platformDispatcher.clearTextScaleFactorTestValue(),
      );
      expect(await large(1.0), isFalse);
      expect(await large(1.49), isFalse);
      expect(await large(1.5), isTrue);
      expect(await large(2.0), isTrue);
    });
  });
}
