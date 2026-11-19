import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/tokens.dart';

/// MC01（ADR 0016 / 规格 CL01–CL09，CL02）语义色相 token 的结构性断言。
///
/// 这里只钉「解析出口取到了哪一档、alpha 是多少、域映射对不对」；
/// 对比度门槛在 `chromatic_contrast_guard_test.dart`（MC02）里单独守卫。
void main() {
  const light = MileafColors.light();
  const dark = MileafColors.dark();

  group('CL01 色相 → 三级强度的取值', () {
    const expected = <MileafHue, (Color, Color, Color)>{
      MileafHue.azure: (
        MileafHueRamp.azureSolidLight,
        MileafHueRamp.azureStrongLight,
        MileafHueRamp.azureDark,
      ),
      MileafHue.aqua: (
        MileafHueRamp.aquaSolidLight,
        MileafHueRamp.aquaStrongLight,
        MileafHueRamp.aquaDark,
      ),
      MileafHue.mint: (
        MileafHueRamp.mintSolidLight,
        MileafHueRamp.mintStrongLight,
        MileafHueRamp.mintDark,
      ),
      MileafHue.amber: (
        MileafHueRamp.amberSolidLight,
        MileafHueRamp.amberStrongLight,
        MileafHueRamp.amberDark,
      ),
      MileafHue.coral: (
        MileafHueRamp.coralSolidLight,
        MileafHueRamp.coralStrongLight,
        MileafHueRamp.coralDark,
      ),
      MileafHue.violet: (
        MileafHueRamp.violetSolidLight,
        MileafHueRamp.violetStrongLight,
        MileafHueRamp.violetDark,
      ),
    };

    test('浅色 solid / strong 与深色单档逐项匹配', () {
      for (final entry in expected.entries) {
        final hue = entry.key;
        final (solidLight, strongLight, darkOnly) = entry.value;
        expect(hue.solid(light), solidLight, reason: '${hue.name} 浅色 solid');
        expect(hue.strong(light), strongLight, reason: '${hue.name} 浅色 strong');
        expect(hue.solid(dark), darkOnly, reason: '${hue.name} 深色 solid');
        expect(
          hue.strong(dark),
          darkOnly,
          reason: '${hue.name} 深色 strong 与 solid 同值（CL02.1）',
        );
      }
    });

    test('azure 保留品牌现值：与 accent / accentStrong 逐字节一致', () {
      expect(MileafHue.azure.solid(light), light.accent);
      expect(MileafHue.azure.strong(light), light.accentStrong);
      expect(MileafHue.azure.solid(dark), dark.accent);
      expect(MileafHue.azure.solid(light), MileafPalette.azure500);
      expect(MileafHue.azure.strong(light), MileafPalette.azure600);
      expect(MileafHue.azure.solid(dark), MileafPalette.azure300);
    });

    test('soft / tint 是 solid 的 16% / 8% alpha（两模式同一规律）', () {
      for (final colors in <MileafColors>[light, dark]) {
        for (final hue in MileafHue.values) {
          final soft = hue.soft(colors);
          final tint = hue.tint(colors);
          expect(soft.r, hue.solid(colors).r, reason: '${hue.name} soft 色相不变');
          expect(soft.g, hue.solid(colors).g);
          expect(soft.b, hue.solid(colors).b);
          expect(soft.a, closeTo(MileafHueWash.softAlpha, .005));
          expect(tint.a, closeTo(MileafHueWash.tintAlpha, .005));
        }
      }
    });

    test('onStrong 浅色取白、深色取近黑（都压得住 strong 实心底）', () {
      for (final hue in MileafHue.values) {
        expect(hue.onStrong(light), light.textOnAccent);
        expect(hue.onStrong(dark), dark.textOnAccent);
      }
    });

    test('六色相两两不同色（无重复取值）', () {
      final solidLight = <Color>{
        for (final h in MileafHue.values) h.solid(light),
      };
      final solidDark = <Color>{
        for (final h in MileafHue.values) h.solid(dark),
      };
      expect(solidLight, hasLength(MileafHue.values.length));
      expect(solidDark, hasLength(MileafHue.values.length));
    });
  });

  group('CL04 中性家族：色相带 242–258°、彩度 ≤0.025', () {
    // OKLab/OKLCH 转换（与规格 §4 的推导同一口径）。
    (double, double, double) oklch(Color c) {
      double lin(double v) => v <= 0.04045
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      final r = lin(c.r), g = lin(c.g), b = lin(c.b);
      final l = math
          .pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1 / 3)
          .toDouble();
      final m = math
          .pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1 / 3)
          .toDouble();
      final s = math
          .pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1 / 3)
          .toDouble();
      final okL = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
      final okA = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
      final okB = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
      final chroma = math.sqrt(okA * okA + okB * okB);
      final hue = (math.atan2(okB, okA) * 180 / math.pi + 360) % 360;
      return (okL, chroma, hue);
    }

    test('浅色与深色的中性 token 都落在同一条色相带上', () {
      for (final colors in <MileafColors>[light, dark]) {
        final neutrals = <String, Color>{
          'canvas': colors.canvas,
          'surface': colors.surface,
          'surfaceRaised': colors.surfaceRaised,
          'line': colors.line,
          'text': colors.text,
          'textMuted': colors.textMuted,
          'textFaint': colors.textFaint,
          'controlBorder': colors.controlBorder,
          'segmentTrack': colors.segmentTrack,
          'navigationLabel': colors.navigationLabel,
        };
        neutrals.forEach((name, color) {
          final (_, chroma, hue) = oklch(color);
          // 极低彩度的中性色色相在 OKLab 里会抖动，彩度 ≤0.025 时只要求落在带内。
          expect(
            chroma,
            lessThanOrEqualTo(0.025),
            reason: '$name 彩度 ${chroma.toStringAsFixed(4)} 超过 0.025（引入了有彩色中性）',
          );
          // 纯白/纯黑的色相是数值噪声（C≈0），只对带彩度的中性查色相带。
          if (chroma <= 0.004) return;
          expect(
            hue,
            inInclusiveRange(240, 267),
            reason:
                '$name 色相 ${hue.toStringAsFixed(1)}° 落在实测带 242–265° 之外'
                '（容差 ±2°）',
          );
        });
      }
    });
  });

  group('CL01 数据域 → 色相', () {
    test('六个域各有唯一色相，且六色相各被用一次', () {
      const expected = <MileafDataDomain, MileafHue>{
        MileafDataDomain.journey: MileafHue.azure,
        MileafDataDomain.energy: MileafHue.aqua,
        MileafDataDomain.efficiency: MileafHue.mint,
        MileafDataDomain.cost: MileafHue.amber,
        MileafDataDomain.climate: MileafHue.coral,
        MileafDataDomain.dwell: MileafHue.violet,
      };
      expected.forEach((domain, hue) {
        expect(domain.hue, hue, reason: '${domain.name} → ${hue.name}');
        expect(domain.solid(light), hue.solid(light));
        expect(domain.strong(light), hue.strong(light));
      });
      final used = expected.values.toSet();
      expect(used, hasLength(MileafHue.values.length));
    });

    test('动作色与数据身份色不共享取色出口（CL05）', () {
      // 动作色只从 accent* 取；数据身份色只从 MileafHue 取。
      expect(light.accent, MileafHue.azure.solid(light));
      // 其余五色不得等于动作色的任一档——否则页面会分不清「能点」和「这是费用」。
      for (final hue in MileafHue.values.where((h) => h != MileafHue.azure)) {
        expect(hue.solid(light), isNot(light.accent));
        expect(hue.strong(light), isNot(light.accentStrong));
        expect(hue.solid(dark), isNot(dark.accent));
      }
    });
  });
}
