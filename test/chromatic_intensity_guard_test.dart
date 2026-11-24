import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/display_preferences.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/tokens.dart';

import 'support/color_math.dart';

/// VH24–VH26 色面与读数的渲染和对比度回归。
void main() {
  const light = MileafColors.light();
  const dark = MileafColors.dark();

  Color over(Color layer, Color base) => compositeOver(layer, layer.a, base);

  (double, double, double) oklch(Color c) {
    double lin(double v) => v <= 0.04045
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    double cbrt(double v) =>
        v < 0 ? -math.pow(-v, 1 / 3).toDouble() : math.pow(v, 1 / 3).toDouble();
    final r = lin(c.r), g = lin(c.g), b = lin(c.b);
    final l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    final m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    final s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    final okL = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
    final okA = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
    final okB = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
    return (
      okL,
      math.sqrt(okA * okA + okB * okB),
      (math.atan2(okB, okA) * 180 / math.pi + 360) % 360,
    );
  }

  group('VH24 卡片色面', () {
    test('普通卡保持低彩度，与底面有可辨的明度及色度差', () {
      for (final colors in [light, dark]) {
        final (baseLightness, baseChroma, baseHue) = oklch(colors.surface);
        for (final hue in MileafHue.values) {
          final (lightness, chroma, angle) = oklch(colors.cardSurface(hue));
          final difference = math.sqrt(
            (lightness - baseLightness) * (lightness - baseLightness) +
                chroma * chroma +
                baseChroma * baseChroma -
                2 *
                    chroma *
                    baseChroma *
                    math.cos((angle - baseHue) * math.pi / 180),
          );
          expect(chroma, lessThanOrEqualTo(.075));
          expect(difference, greaterThanOrEqualTo(.03), reason: hue.name);
        }
      }
    });
  });

  group('专题入口与主读数层级', () {
    Future<Color> cardColor(WidgetTester tester, Brightness brightness) async {
      final preferences = DisplayPreferencesController(
        platform: DisplayPreferencesPlatform.other,
      );
      addTearDown(preferences.dispose);
      await tester.pumpWidget(
        DisplayPreferencesScope(
          controller: preferences,
          child: MaterialApp(
            theme: mileafTheme(brightness),
            home: Scaffold(
              body: const MileafModuleCard(
                hue: MileafHue.sky,
                child: SizedBox(height: 20, width: 20),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final paint = tester.widget<CustomPaint>(
        find
            .descendant(
              of: find.byType(MileafModuleCard),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is CustomPaint &&
                    widget.painter is LiquidGlassPainter,
              ),
            )
            .first,
      );
      return (paint.painter! as LiquidGlassPainter).fillBottom;
    }

    testWidgets('专题入口双主题有可辨身份色并保留文字对比', (tester) async {
      for (final (brightness, colors) in [
        (Brightness.light, light),
        (Brightness.dark, dark),
      ]) {
        final fill = await cardColor(tester, brightness);
        expect(fill, colors.cardSurface(MileafHue.sky));
        expect(
          contrastRatio(colors.textSecondary, fill),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('六域普通色面与中性色面的正文、彩色读数均至少 4.5:1', () {
      for (final colors in [light, dark]) {
        for (final hue in [null, ...MileafHue.values]) {
          final fill = colors.cardSurface(hue);
          final gloss = over(
            Colors.white.withValues(
              alpha: colors.isDark
                  ? MileafMaterialMetrics.cardGlassSheenDark
                  : MileafMaterialMetrics.cardGlassSheenLight,
            ),
            fill,
          );
          for (final background in [fill, gloss]) {
            for (final foreground in [
              colors.text,
              colors.textSecondary,
              for (final domainHue in MileafHue.values)
                domainHue.strong(colors),
            ]) {
              expect(
                contrastRatio(foreground, background),
                greaterThanOrEqualTo(4.5),
                reason: '$hue ${colors.isDark} $foreground on $background',
              );
            }
          }
        }
      }
    });

    test('六域焦点正文和操作 ≥ 4.5:1，背板彩度受限', () {
      for (final colors in [
        light,
        light.lerp(dark, .49),
        light.lerp(dark, .51),
        dark,
      ]) {
        for (final hue in MileafHue.values) {
          final focus = colors.focused(hue);
          for (final foreground in [
            focus.text,
            focus.textSecondary,
            focus.accentStrong,
          ]) {
            expect(
              contrastRatio(foreground, focus.surface),
              greaterThanOrEqualTo(4.5),
              reason: '$hue on ${focus.surface}',
            );
          }
          expect(
            contrastRatio(
              focus.accentStrong,
              over(focus.pressOverlay, focus.surface),
            ),
            greaterThanOrEqualTo(4.5),
          );
          expect(oklch(focus.surface).$2, lessThan(0.12));
        }
      }
    });
  });

  group('CL55 读数按字号分档取色', () {
    Future<Color?> numberColor(
      WidgetTester tester,
      MetricValueScale scale,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(Brightness.light),
          home: Scaffold(
            body: MetricBlock(hue: MileafHue.teal, value: '12', scale: scale),
          ),
        ),
      );
      return tester.widget<MileafNumber>(find.byType(MileafNumber)).color;
    }

    testWidgets('display/metricLg/metricMd 取 solid，metricSm 取 strong', (
      tester,
    ) async {
      for (final scale in <MetricValueScale>[
        MetricValueScale.display,
        MetricValueScale.metricLg,
        MetricValueScale.metricMd,
      ]) {
        expect(await numberColor(tester, scale), MileafHue.teal.solid(light));
      }
      expect(
        await numberColor(tester, MetricValueScale.metricSm),
        MileafHue.teal.strong(light),
      );
    });

    testWidgets('缺失值不着色（CL08 仍有效）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(Brightness.light),
          home: const Scaffold(body: MetricBlock(hue: MileafHue.teal)),
        ),
      );
      final number = tester.widget<MileafNumber>(find.byType(MileafNumber));
      expect(number.color, isNull, reason: '缺失值不在组件里着色（CL08）');
    });
  });
}
