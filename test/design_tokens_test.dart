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

/// CIELAB lightness (0–100): the only scale the §3.3 lightness steps use.
double lightness(Color color) {
  final y = _luminance(color);
  final f = y > 216 / 24389
      ? math.pow(y, 1 / 3).toDouble()
      : (24389 / 27 * y + 16) / 116;
  return 116 * f - 16;
}

/// `minimum` is 4.5 for text and 3.0 for graphics (Spec §1 R3).
void _expectContrast(
  String name,
  Color foreground,
  Color background,
  double expected, {
  double minimum = 4.5,
}) {
  final value = contrast(foreground, background);
  expect(
    value,
    closeTo(expected, .06),
    reason: '$name 对比度应与 Spec §3 一致（实测 $value）',
  );
  expect(value, greaterThanOrEqualTo(minimum), reason: '$name 未达 WCAG 阈值');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Spec §3 对比度', () {
    test('深色语义色', () {
      const c = MileafColors.dark();
      _expectContrast('text/canvas', c.text, c.canvas, 17.87);
      _expectContrast('muted/canvas', c.textMuted, c.canvas, 7.87);
      _expectContrast('faint/canvas', c.textFaint, c.canvas, 5.59);
      // Dark merges graphic and text accents: #64A8FF is 8.05:1 on canvas.
      _expectContrast('accent/canvas', c.accent, c.canvas, 8.05, minimum: 3);
      _expectContrast('accentStrong/canvas', c.accentStrong, c.canvas, 8.05);
      _expectContrast('reference/canvas', c.reference, c.canvas, 6.80);
      _expectContrast('warning/canvas', c.warning, c.canvas, 10.77);
      _expectContrast('error/canvas', c.error, c.canvas, 7.75);
      _expectContrast('textOnAccent/accent', c.textOnAccent, c.accent, 8.05);
    });

    test('浅色语义色', () {
      const c = MileafColors.light();
      _expectContrast('text/canvas', c.text, c.canvas, 17.10);
      _expectContrast('muted/canvas', c.textMuted, c.canvas, 5.38);
      _expectContrast('faint/canvas', c.textFaint, c.canvas, 4.65);
      // The graphic accent is allowed below AA for text: it is a 3:1 mark.
      _expectContrast('accent/canvas', c.accent, c.canvas, 3.25, minimum: 3);
      _expectContrast('accentStrong/canvas', c.accentStrong, c.canvas, 5.41);
      _expectContrast('reference/canvas', c.reference, c.canvas, 4.99);
      _expectContrast('warning/canvas', c.warning, c.canvas, 4.60);
      _expectContrast('error/canvas', c.error, c.canvas, 4.90);
      _expectContrast(
        'textOnAccent/accentStrong',
        c.textOnAccent,
        c.accentStrong,
        5.90,
      );
    });

    test('浅色模式仍保留深色 hero', () {
      const c = MileafColors.light();
      expect(c.hero, isNot(c.canvas));
      _expectContrast('heroText/hero', c.heroText, c.hero, 17.90);
      _expectContrast('heroMuted/hero', c.heroMuted, c.hero, 9.34);
      _expectContrast('heroFaint/hero', c.heroFaint, c.hero, 6.55);
      _expectContrast(
        'accentHero/hero',
        c.accentHero,
        c.hero,
        8.06,
        minimum: 3,
      );
      const dark = MileafColors.dark();
      _expectContrast('heroText/darkHero', dark.heroText, dark.hero, 18.10);
      _expectContrast('heroMuted/darkHero', dark.heroMuted, dark.hero, 9.45);
      _expectContrast('heroFaint/darkHero', dark.heroFaint, dark.hero, 6.63);
    });

    test('明度阶：面读得出，浅色 hero 是锚点，深色 hero 是连续材质', () {
      const dark = MileafColors.dark();
      const light = MileafColors.light();
      expect(
        lightness(light.surface) - lightness(light.canvas),
        greaterThanOrEqualTo(3),
        reason: '浅色 canvas→surface 必须读得出「面」',
      );
      expect(
        lightness(light.canvas) - lightness(light.hero),
        greaterThanOrEqualTo(80),
        reason: '浅色 hero 必须仍是深色锚点',
      );
      expect(
        lightness(dark.surface) - lightness(dark.canvas),
        greaterThanOrEqualTo(3),
      );
      expect(
        (lightness(dark.canvas) - lightness(dark.hero)).abs(),
        lessThanOrEqualTo(2),
        reason: '深色 hero 与画布是同一块连续材质',
      );
    });

    test('hero 形态只由 hero 与画布的明度差推导（Spec §6.1）', () {
      const dark = MileafColors.dark();
      const light = MileafColors.light();
      // Current values: dark ΔL*0.61 → full bleed, light Δ93.58 → card.
      expect(dark.heroAsCard, isFalse, reason: '深色 hero 是同一块连续材质');
      expect(light.heroAsCard, isTrue, reason: '浅色 hero 与纸面差 93 L*，必须是卡片');
      expect(
        (lightness(light.hero) - lightness(light.canvas)).abs(),
        greaterThan(20),
      );
      expect(
        (lightness(dark.hero) - lightness(dark.canvas)).abs(),
        lessThanOrEqualTo(20),
      );
      // The threshold itself, not just today's two palettes: #2C2C2C is Δ15
      // from the light hero (full bleed), #474747 is Δ27 (card).
      const near = Color(0xFF2C2C2C), far = Color(0xFF474747);
      expect(light.copyWith(canvas: near).heroAsCard, isFalse);
      expect(light.copyWith(canvas: far).heroAsCard, isTrue);
    });

    test('图表系列、参照与当前点在两种底色上都可读（Spec §8 / AV06）', () {
      for (final colors in const [MileafColors.dark(), MileafColors.light()]) {
        final mode = colors.isDark ? '深色' : '浅色';
        for (final (name, background) in [
          ('canvas', colors.canvas),
          ('surface', colors.surface),
        ]) {
          expect(
            contrast(colors.seriesPrimary, background),
            greaterThanOrEqualTo(3),
            reason: '$mode 主系列在 $name 上未达图形 3:1',
          );
          expect(
            contrast(colors.seriesSecondary, background),
            greaterThanOrEqualTo(3),
            reason: '$mode 次系列在 $name 上未达图形 3:1（accent 50% 只有 1.8/2.8）',
          );
          expect(
            contrast(colors.reference, background),
            greaterThanOrEqualTo(3),
            reason: '$mode 参照线在 $name 上未达图形 3:1',
          );
          expect(
            contrast(colors.seriesNeutral, background),
            greaterThanOrEqualTo(3),
            reason: '$mode 中性序列在 $name 上未达图形 3:1',
          );
          expect(
            contrast(colors.textFaint, background),
            greaterThanOrEqualTo(4.5),
            reason: '$mode 轴标签在 $name 上未达文本 4.5:1',
          );
        }
        // 主/次系列不能合并成一个读法。
        expect(
          contrast(colors.seriesPrimary, colors.seriesSecondary),
          greaterThanOrEqualTo(1.4),
          reason: '$mode 主次系列明度几乎相同',
        );
        // hero 内图表：accentHero 系列 + heroFaint 轴标签。
        expect(
          contrast(colors.accentHero, colors.hero),
          greaterThanOrEqualTo(3),
          reason: '$mode hero 内系列在 hero 上未达图形 3:1',
        );
        expect(
          contrast(colors.heroFaint, colors.hero),
          greaterThanOrEqualTo(4.5),
          reason: '$mode hero 内轴标签未达文本 4.5:1',
        );
      }
    });

    test('热力格 9px 标签在两种模式的高亮格上仍达 4.5', () {
      // 使用页把「≥100 km」画成 accent 72% 的格子，格内是 9px 文字。
      for (final colors in const [MileafColors.dark(), MileafColors.light()]) {
        final mode = colors.isDark ? '深色' : '浅色';
        final cell = Color.alphaBlend(
          colors.accent.withValues(alpha: .72),
          colors.surface,
        );
        final ink = colors.isDark ? colors.textOnAccent : colors.text;
        expect(
          contrast(ink, cell),
          greaterThanOrEqualTo(4.5),
          reason: '$mode 最强热力格上的 9px 日期未达 4.5:1',
        );
      }
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
      expect(spacing, {
        4.0,
        8.0,
        12.0,
        16.0,
        20.0,
        24.0,
        28.0,
        32.0,
        40.0,
        56.0,
      });
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
      expect(MileafType.displaySize, 48);
      expect(MileafType.metricLgSize, 36);
      expect(MileafType.metricMdSize, 24);
      expect(MileafType.titleSize, 18);
      expect(MileafType.bodySize, 16);
      expect(MileafType.labelSize, 13);
      expect(MileafType.microSize, 12);
      expect(MileafType.displayTracking, -.02);
      expect(MileafType.labelTracking, 0);
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

    test('语义色取自 v2 primitive，两模式 hero 与 canvas 分离', () {
      const dark = MileafColors.dark();
      const light = MileafColors.light();
      expect(dark.hero, MileafPalette.slate1000);
      expect(dark.canvas, MileafPalette.slate950);
      expect(light.hero, MileafPalette.heroLight);
      expect(light.canvas, MileafPalette.paper50);
      expect(light.surface, MileafPalette.paper0);
      expect(light.accent, MileafPalette.azure500);
      expect(light.accentStrong, MileafPalette.azure600);
      expect(light.accentHero, MileafPalette.azure300);
      expect(dark.accent, MileafPalette.azure300);
      // Dark merges the two accent strengths by design (Spec §1 R3).
      expect(dark.accentStrong, dark.accent);
    });

    test('线条与叠加层的透明度与 Spec §3 一致', () {
      // Alpha is the only thing these tokens carry; a wrong percentage is a
      // whole-page layering error that contrast maths cannot catch.
      int pct(Color color) => (color.a * 100).round();
      const dark = MileafColors.dark();
      const light = MileafColors.light();
      expect([pct(dark.line), pct(dark.lineStrong)], [9, 14]);
      expect([pct(light.line), pct(light.lineStrong)], [10, 16]);
      expect([pct(dark.nav), pct(light.nav)], [88, 92]);
      expect([pct(dark.scrim), pct(light.scrim)], [50, 35]);
      expect([pct(dark.skeleton), pct(light.skeleton)], [7, 6]);
      expect([pct(dark.accentSoft)], [16]);
      expect(light.accentSoft, MileafPalette.accentSoftLight);
      expect([pct(dark.pressOverlay), pct(light.pressOverlay)], [4, 6]);
      expect(pct(dark.focusRing), 60);
    });

    test('accentStrong 参与 copyWith 与主题插值', () {
      const dark = MileafColors.dark();
      const light = MileafColors.light();
      expect(
        light.copyWith(accentStrong: dark.accentStrong).accentStrong,
        dark.accentStrong,
      );
      final mid = dark.lerp(light, .5);
      // Without `accentStrong` in `lerp` the 200ms theme switch would jump.
      expect(
        mid.accentStrong,
        Color.lerp(dark.accentStrong, light.accentStrong, .5),
      );
      expect(mid.accentStrong, isNot(dark.accentStrong));
      expect(mid.accentStrong, isNot(light.accentStrong));
    });

    test('hero 卡片几何与中性浅色阴影已就位', () {
      expect(MileafSpace.cardInset, 12);
      expect(MileafSpace.cardPad, 16);
      // Spec §5.2: light sheet shadow is neutral 10% graphite, not warm grey.
      expect(MileafElevation.sheetLight.single.color, const Color(0x1A0E1319));
      expect(MileafElevation.sheetLight.single.blurRadius, 40);
      expect(MileafElevation.sheetLight.single.offset, const Offset(0, 12));
    });

    test('主题挂载语义与字号扩展，两种亮度都挂 canvas 底', () {
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
            body: Text(
              '320 km 1,198.6 行笺',
              style: TextStyle(fontFamily: 'Inter'),
            ),
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

    testWidgets('16 个关键图标在 16/20/24 都可绘制', (tester) async {
      expect(MileafIconName.values.length, 16);
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
                      MileafIcon(name, size: size, semanticLabel: name.name),
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
