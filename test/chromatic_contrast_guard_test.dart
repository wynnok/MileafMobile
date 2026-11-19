import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/semantic.dart';

import 'support/color_math.dart';

/// MC02（ADR 0016 / 规格 CL02、CL03）六色相对比度自动化守卫。
///
/// 门槛口径与 MG03 的 `days_migration_color_guard_test.dart` 同源（WCAG 2.x
/// 相对亮度），但**互不覆盖**：MG03 管既有语义前景 × 声明背景，本文件管新增的
/// 六色相 × 三级强度。两者都不允许通过改色值救测。
///
/// 门槛取「类别底线 + 余量」：图形 3.0（CL02 声明 3.55 实锚）、正文 4.5
/// （CL02 声明 5.90 实锚）。余量就是本增量允许的后续微调空间。
void main() {
  const palettes = <String, MileafColors>{
    'light': MileafColors.light(),
    'dark': MileafColors.dark(),
  };

  const graphicsFloor = 3.0;
  const textFloor = 4.5;

  Color overCanvas(MileafColors colors, Color layer) =>
      compositeOver(layer, layer.a, colors.canvas);
  Color overSurface(MileafColors colors, Color layer) =>
      compositeOver(layer, layer.a, colors.surface);

  group('CL02 图形级（solid）', () {
    palettes.forEach((mode, colors) {
      for (final hue in MileafHue.values) {
        test('$mode · ${hue.name}.solid ≥ $graphicsFloor（surface）', () {
          final ratio = contrastRatio(hue.solid(colors), colors.surface);
          expect(
            ratio,
            greaterThanOrEqualTo(graphicsFloor),
            reason: '$mode ${hue.name} solid 实测 ${ratio.toStringAsFixed(2)}:1',
          );
        });
        test('$mode · ${hue.name}.solid ≥ $graphicsFloor（canvas）', () {
          final ratio = contrastRatio(hue.solid(colors), colors.canvas);
          expect(
            ratio,
            greaterThanOrEqualTo(graphicsFloor),
            reason: '$mode ${hue.name} solid 实测 ${ratio.toStringAsFixed(2)}:1',
          );
        });
      }
    });
  });

  group('CL02 文字级（strong）', () {
    palettes.forEach((mode, colors) {
      for (final hue in MileafHue.values) {
        for (final entry in <String, Color>{
          'canvas': colors.canvas,
          'surface': colors.surface,
        }.entries) {
          test('$mode · ${hue.name}.strong ≥ $textFloor（${entry.key}）', () {
            final ratio = contrastRatio(hue.strong(colors), entry.value);
            expect(
              ratio,
              greaterThanOrEqualTo(textFloor),
              reason:
                  '$mode ${hue.name} strong 在 ${entry.key} 上实测 '
                  '${ratio.toStringAsFixed(2)}:1',
            );
          });
        }

        test('$mode · ${hue.name}.strong 压 soft 合成底 ≥ $textFloor', () {
          for (final bg in <String, Color>{
            'soft over canvas': overCanvas(colors, hue.soft(colors)),
            'soft over surface': overSurface(colors, hue.soft(colors)),
          }.entries) {
            final ratio = contrastRatio(hue.strong(colors), bg.value);
            expect(
              ratio,
              greaterThanOrEqualTo(textFloor),
              reason:
                  '$mode ${hue.name} strong 在 ${bg.key} 上实测 '
                  '${ratio.toStringAsFixed(2)}:1',
            );
          }
        });

        test('$mode · ${hue.name}.onStrong 压 strong 实心底 ≥ $textFloor', () {
          final ratio = contrastRatio(hue.onStrong(colors), hue.strong(colors));
          expect(
            ratio,
            greaterThanOrEqualTo(textFloor),
            reason:
                '$mode ${hue.name} onStrong 实测 ${ratio.toStringAsFixed(2)}:1',
          );
        });
      }
    });
  });

  group('CL06 正文压 tint 背板（大面只允许 tint，正文要读得出来）', () {
    palettes.forEach((mode, colors) {
      for (final hue in MileafHue.values) {
        test('$mode · text 压 ${hue.name}.tint 合成底 ≥ $textFloor', () {
          for (final bg in <String, Color>{
            'tint over canvas': overCanvas(colors, hue.tint(colors)),
            'tint over surface': overSurface(colors, hue.tint(colors)),
          }.entries) {
            final ratio = contrastRatio(colors.text, bg.value);
            expect(
              ratio,
              greaterThanOrEqualTo(textFloor),
              reason:
                  '$mode text 在 ${bg.key} 上实测 '
                  '${ratio.toStringAsFixed(2)}:1',
            );
          }
        });
      }
    });
  });

  group('CL06 彩色读数压 tint 背板（焦点卡/账目卡的真实组合）', () {
    palettes.forEach((mode, colors) {
      for (final hue in MileafHue.values) {
        test('$mode · ${hue.name}.strong 压 tint 合成底 ≥ $textFloor', () {
          for (final bg in <String, Color>{
            'tint over canvas': overCanvas(colors, hue.tint(colors)),
            'tint over surface': overSurface(colors, hue.tint(colors)),
          }.entries) {
            final ratio = contrastRatio(hue.strong(colors), bg.value);
            expect(
              ratio,
              greaterThanOrEqualTo(textFloor),
              reason:
                  '$mode ${hue.name} strong 在 ${bg.key} 上实测 '
                  '${ratio.toStringAsFixed(2)}:1',
            );
          }
        });
      }
    });
  });

  test('CL04 中性家族不因新增色相而放宽：text / textSecondary 仍过 4.5:1', () {
    palettes.forEach((mode, colors) {
      expect(
        contrastRatio(colors.text, colors.canvas),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(colors.textSecondary, colors.canvas),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
