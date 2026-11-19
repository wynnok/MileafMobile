import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/tokens.dart';

import 'support/color_math.dart';

/// CL58（ADR 0017 / 规格 §12）鲜明度 v2 的守卫。
///
/// 钉的是**新加的物理约束**，不是「取到哪个色值」：
/// 1. 亮面档只配墨字，且自己不能承界（对白底 <3:1）；
/// 2. 洗色面上只允许 strong，solid 只能压中性底；
/// 3. 洗色必须「看得出是彩色」，但不得变成高彩面；
/// 4. 深洗底只在浅色模式生效；
/// 5. 读数按字号分档取色（大文本 solid / 小字 strong）。
void main() {
  const light = MileafColors.light();
  const dark = MileafColors.dark();
  const ink = MileafPalette.slate900;

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

  bool inGamut(double L, double C, double H) {
    final h = H * math.pi / 180;
    final a = C * math.cos(h), b = C * math.sin(h);
    final l_ = L + 0.3963377774 * a + 0.2158037573 * b;
    final m_ = L - 0.1055613458 * a - 0.0638541728 * b;
    final s_ = L - 0.0894841775 * a - 1.2914855480 * b;
    final l = l_ * l_ * l_, m = m_ * m_ * m_, s = s_ * s_ * s_;
    final r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
    final g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
    final bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;
    const eps = 5e-4;
    return [r, g, bl].every((v) => v >= -eps && v <= 1 + eps);
  }

  double maxChroma(double L, double H) {
    var lo = 0.0, hi = 0.5;
    for (var i = 0; i < 40; i++) {
      final mid = (lo + hi) / 2;
      if (inGamut(L, mid, H)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  group('CL49 亮面档：只配墨字，且自己不能承界', () {
    test('六亮面对墨字 ≥ 7:1，且两模式同值', () {
      for (final hue in MileafHue.values) {
        final ratio = contrastRatio(hue.vivid(light), ink);
        expect(
          ratio,
          greaterThanOrEqualTo(7.0),
          reason: '亮面对墨字 ${ratio.toStringAsFixed(2)}',
        );
        expect(hue.vivid(light), hue.vivid(dark));
      }
    });

    test('亮面对白底 < 3:1（所以禁止 100% 亮面承界，CL49.1）', () {
      for (final hue in MileafHue.values) {
        final ratio = contrastRatio(hue.vivid(light), const Color(0xFFFFFFFF));
        expect(
          ratio,
          lessThan(3.0),
          reason: '亮面对白底 ${ratio.toStringAsFixed(2)}',
        );
      }
    });

    test('统一明度 L=0.74、彩度取色域边界的 95.5–96.5%', () {
      for (final hue in MileafHue.values) {
        final (L, C, H) = oklch(hue.vivid(light));
        expect(L, inInclusiveRange(0.735, 0.745));
        final ratio = C / maxChroma(L, H);
        expect(
          ratio,
          inInclusiveRange(0.955, 0.965),
          reason: '色域占比 ${ratio.toStringAsFixed(3)}',
        );
      }
    });
  });

  group('CL51 面子关系：洗色面上只允许 strong', () {
    test('strong 压 veil/soft/tint 合成底 ≥ 4.5:1（六色相 × 浅深）', () {
      for (final colors in <MileafColors>[light, dark]) {
        for (final hue in MileafHue.values) {
          // veil 只压图形（3:1），soft/tint 承载文字（4.5:1）。
          final layers = <(String, Color, double)>[
            ('veil', hue.veil(colors), 3.0),
            ('soft', hue.soft(colors), 4.5),
            ('tint', hue.tint(colors), 4.5),
          ];
          for (final layer in layers) {
            final bases = <(String, Color)>[
              ('canvas', colors.canvas),
              ('surface', colors.surface),
            ];
            for (final base in bases) {
              final ratio = contrastRatio(
                hue.strong(colors),
                over(layer.$2, base.$2),
              );
              expect(
                ratio,
                greaterThanOrEqualTo(layer.$3),
                reason: '${layer.$1}@${base.$1}',
              );
            }
          }
        }
      }
    });

    test('solid 压 canvas/surface ≥ 3:1', () {
      for (final colors in <MileafColors>[light, dark]) {
        for (final hue in MileafHue.values) {
          for (final base in <Color>[colors.canvas, colors.surface]) {
            expect(
              contrastRatio(hue.solid(colors), base),
              greaterThanOrEqualTo(3.0),
            );
          }
        }
      }
    });

    test('浅色下 solid 压 tint < 3:1（所以浅色洗色面上的前景只能 strong）', () {
      for (final hue in MileafHue.values) {
        final onTint = contrastRatio(
          hue.solid(light),
          over(hue.tint(light), light.surface),
        );
        expect(onTint, lessThan(3.0), reason: 'solid 压 tint 达标说明 tint 又被改浅了');
      }
    });
  });

  group('CL50 洗色必须「看得出是彩色」', () {
    test('tint 合成后 C 在 0.024–0.075', () {
      for (final colors in <MileafColors>[light, dark]) {
        for (final hue in MileafHue.values) {
          final (_, C, _) = oklch(over(hue.tint(colors), colors.surface));
          expect(
            C,
            inInclusiveRange(0.024, 0.075),
            reason: 'tint C=${C.toStringAsFixed(4)}',
          );
        }
      }
    });

    test('veil 合成后 C ≥ 0.04（图表填充必须成形）', () {
      for (final hue in MileafHue.values) {
        final (_, C, _) = oklch(over(hue.veil(light), light.surface));
        expect(
          C,
          greaterThanOrEqualTo(0.040),
          reason: 'veil C=${C.toStringAsFixed(4)}',
        );
      }
    });
  });

  group('CL56 深洗底只在浅色模式', () {
    Future<Color> cardColor(WidgetTester tester, Brightness brightness) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(brightness),
          home: Scaffold(
            body: MileafModuleCard(
              hue: MileafHue.azure,
              emphasis: MileafCardEmphasis.deep,
              child: const SizedBox(height: 20, width: 20),
            ),
          ),
        ),
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(MileafModuleCard),
              matching: find.byType(Material),
            )
            .first,
      );
      return material.color!;
    }

    testWidgets('浅色 55% 洗底，墨字 ≥ 11:1', (tester) async {
      final lightCard = await cardColor(tester, Brightness.light);
      final (_, lightC, _) = oklch(lightCard);
      expect(lightC, inInclusiveRange(0.07, 0.13));
      expect(contrastRatio(ink, lightCard), greaterThanOrEqualTo(11.0));
    });

    testWidgets('深色自动退回 tint（不加深）', (tester) async {
      final darkCard = await cardColor(tester, Brightness.dark);
      final expected = over(MileafHue.azure.tint(dark), dark.surface);
      // Flutter 的 alphaBlend 按 8 位量化，逐通道留 0.01 的容差。
      expect(darkCard.r, closeTo(expected.r, .01));
      expect(darkCard.g, closeTo(expected.g, .01));
      expect(darkCard.b, closeTo(expected.b, .01));
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
            body: MetricBlock(hue: MileafHue.mint, value: '12', scale: scale),
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
        expect(await numberColor(tester, scale), MileafHue.mint.solid(light));
      }
      expect(
        await numberColor(tester, MetricValueScale.metricSm),
        MileafHue.mint.strong(light),
      );
    });

    testWidgets('缺失值不着色（CL08 仍有效）', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(Brightness.light),
          home: const Scaffold(body: MetricBlock(hue: MileafHue.mint)),
        ),
      );
      final number = tester.widget<MileafNumber>(find.byType(MileafNumber));
      expect(number.color, isNull, reason: '缺失值不在组件里着色（CL08）');
    });
  });
}
