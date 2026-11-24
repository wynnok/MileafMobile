import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/tokens.dart';

import 'support/color_math.dart';

/// VH26：验证实际色面、玻璃受光、操作与数据图形的对比度。
void main() {
  const palettes = <String, MileafColors>{
    'light': MileafColors.light(),
    'dark': MileafColors.dark(),
  };

  const graphicsFloor = 3.0;
  const textFloor = 4.5;

  test('品牌原色主按钮在静态和按下时保留 ≥4.5:1 的图文对比', () {
    for (final colors in palettes.values) {
      for (final background in [
        colors.primaryAction,
        Color.alphaBlend(colors.pressOverlay, colors.primaryAction),
      ]) {
        expect(
          contrastRatio(colors.onPrimaryAction, background),
          greaterThanOrEqualTo(textFloor),
        );
      }
    }
  });

  test('充电弧段在补能底上可辨，双主题有两个不同明度的段', () {
    for (final colors in palettes.values) {
      const hue = MileafHue.mint;
      final primary = hue.solid(colors);
      final secondary = hue.secondarySeries(colors);
      final surface = colors.cardSurface(hue);
      expect(
        contrastRatio(primary, surface),
        greaterThanOrEqualTo(graphicsFloor),
      );
      expect(
        contrastRatio(secondary, surface),
        greaterThanOrEqualTo(graphicsFloor),
      );
      expect(contrastRatio(primary, secondary), greaterThanOrEqualTo(1.4));
    }
  });

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
      }
    });
  });

  test('域色边界与文字在实际普通面、焦点面及受光层保持可读', () {
    for (final colors in palettes.values) {
      final sheen = colors.isDark
          ? MileafMaterialMetrics.cardGlassSheenDark
          : MileafMaterialMetrics.cardGlassSheenLight;
      for (final hue in MileafHue.values) {
        final focus = colors.focused(hue);
        for (final (fill, local) in [
          (colors.cardSurface(hue), colors),
          (focus.surface, focus),
        ]) {
          for (final background in [
            fill,
            compositeOver(Colors.white, sheen, fill),
          ]) {
            for (final foreground in [
              local.text,
              local.textSecondary,
              local.textFaint,
              hue.strong(local),
            ]) {
              expect(
                contrastRatio(foreground, background),
                greaterThanOrEqualTo(textFloor),
                reason:
                    '${hue.name} ${colors.isDark} $foreground on $background',
              );
            }
            expect(
              contrastRatio(hue.solid(local), background),
              greaterThanOrEqualTo(graphicsFloor),
              reason: '${hue.name} ${colors.isDark} 图形',
            );
          }
        }
      }
    }
  });

  test('分段选中镜片的文字及轮廓在实际控件底色上可辨', () {
    for (final colors in palettes.values) {
      final selected = colors.segmentSelected;
      final sheen = colors.isDark
          ? MileafMaterialMetrics.cardGlassSheenDark
          : MileafMaterialMetrics.cardGlassSheenLight;
      for (final background in [
        selected,
        compositeOver(Colors.white, sheen, selected),
      ]) {
        expect(
          contrastRatio(colors.text, background),
          greaterThanOrEqualTo(textFloor),
        );
        expect(
          contrastRatio(colors.segmentBorder, background),
          greaterThanOrEqualTo(graphicsFloor),
        );
      }
      expect(
        contrastRatio(colors.segmentBorder, colors.segmentTrack),
        greaterThanOrEqualTo(graphicsFloor),
      );
    }
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
