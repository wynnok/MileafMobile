import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/semantic.dart';

import 'support/color_math.dart';

/// MG03（days-matter-migration.md §4）对比度自动化守卫。
///
/// 遍历「语义前景 × 声明背景」组合，浅深两模式各跑一遍：
/// - 正文类（text / textSecondary / textFaint / accentStrong 作文字 /
///   textOnAccent）≥4.5:1；
/// - 图形与边框类（accent / controlBorder / reference / warning / error，
///   accentStrong 作图形）≥3.0:1。
///
/// 未来调色板改动触碰下限即测试失败。**本测试不允许通过改色值来救**；
/// 确实低于门槛的组合降级为记录性测试（见豁免登记），不得改值。
void main() {
  const palettes = <String, MileafColors>{
    'light': MileafColors.light(),
    'dark': MileafColors.dark(),
  };

  group('MG03 对比度守卫（自动断言）', () {
    palettes.forEach((mode, colors) {
      group(mode, () {
        for (final entry in _registry(colors).where((e) => !e.exempt)) {
          test(
            '${entry.foreground} × ${entry.background} ≥ '
            '${entry.floor.toStringAsFixed(1)}（${entry.purpose}）',
            () {
              final ratio = contrastRatio(
                entry.foregroundOf(colors),
                entry.backgroundOf(colors),
              );
              expect(
                ratio,
                greaterThanOrEqualTo(entry.floor),
                reason: '$mode：${entry.foreground} 在 ${entry.background} 上 '
                    '实测 ${ratio.toStringAsFixed(2)}:1，'
                    '低于 ${entry.floor}:1 门槛（${entry.purpose}）。'
                    '禁止改色值救测；按 MG03 走豁免登记流程。',
              );
            },
          );
        }
      });
    });
  });

  test('MG03 记录性组合（豁免自动断言，实测值登记）', () {
    // 以下组合实测低于其类别门槛，按 MG03「不改色值」裁决降级为记录性
    // 测试：只打印实测值，不自动断言。豁免理由与完整登记见
    // docs/implementation/days-matter-migration-color.md §1.2，
    // 列为「待用户裁定」发现：
    //
    // - textFaint × segmentTrack（浅）：4.17 —— textFaint 声明用途是
    //   占位符 / 禁用态 / 非文字装饰（semantic.dart），segmentTrack 是
    //   分段控件的中性轨道底；若未来出现 faint 文字压轨道的用法，需在
    //   页面层换 textSecondary（浅色该组合实测 4.82 ≥4.5）。
    // - textFaint × accentSoft（浅）：4.19 —— 同上；textMuted 在同底
    //   4.85 ≥4.5。
    // - textFaint × accentSoft 合成底 over canvas（深）：4.45 —— 深色
    //   accentSoft 是 16% azure 半透明（0x2964A8FF），实测口径为先按
    //   compositeOver 合成再算对比度；仅差 0.05，仍属 <4.5。
    // - textFaint × accentSoft 合成底 over surface（深）：3.96 —— 同上。
    //
    // textFaint 现值 #63707C / #7E8A96 保留不变（MG03 裁决：以
    // overview-chart-header.md:79 的 WCAG 复测口径为准）。
    for (final entry in palettes.entries) {
      for (final e
          in _registry(entry.value).where((element) => element.exempt)) {
        final ratio = contrastRatio(
          e.foregroundOf(entry.value),
          e.backgroundOf(entry.value),
        );
        // ignore: avoid_print
        print('MG03 豁免登记 [${entry.key}] ${e.foreground} × ${e.background}'
            '（${e.purpose}）：实测 ${ratio.toStringAsFixed(2)}:1'
            '（门槛 ${e.floor.toStringAsFixed(1)}:1，豁免待用户裁定）');
        expect(ratio, greaterThan(0));
      }
    }
  });

  group('MG02 状态取色映射', () {
    test('映射表逐项（MG02 全站唯一映射）', () {
      palettes.forEach((mode, colors) {
        expect(
          MileafStatusTone.neutral.resolveColor(colors),
          colors.textSecondary,
          reason: '$mode：缺失/未知/未记录 → 中性 textSecondary',
        );
        expect(
          MileafStatusTone.accent.resolveColor(colors),
          colors.accentStrong,
          reason: '$mode：进行中/加载 → accentStrong（文字级强度）',
        );
        expect(
          MileafStatusTone.warning.resolveColor(colors),
          colors.warning,
          reason: '$mode：警示 → warning',
        );
        expect(
          MileafStatusTone.error.resolveColor(colors),
          colors.error,
          reason: '$mode：失败/破坏 → error',
        );
      });
    });

    test('neutral 解析结果不含 accent / warning / error（缺失数据永不彩色）', () {
      palettes.forEach((mode, colors) {
        final neutral = MileafStatusTone.neutral.resolveColor(colors);
        expect(
          neutral,
          isNot(colors.accent),
          reason: '$mode：neutral 不得落到图形 accent',
        );
        expect(
          neutral,
          isNot(colors.warning),
          reason: '$mode：neutral 不得落到 warning',
        );
        expect(
          neutral,
          isNot(colors.error),
          reason: '$mode：neutral 不得落到 error',
        );
      });
    });
  });
}

/// 深色 accentSoft 是 16% azure 半透明底，实际落底随下层内容变化；
/// 按 canvas 与 surface 两条常见合成口径各记一条。浅色 accentSoft 为
/// 不透明 #DCEBFD，原样使用。
Color _accentSoftOverCanvas(MileafColors colors) => colors.isDark
    ? compositeOver(colors.accentSoft, colors.accentSoft.a, colors.canvas)
    : colors.accentSoft;

Color _accentSoftOverSurface(MileafColors colors) => colors.isDark
    ? compositeOver(colors.accentSoft, colors.accentSoft.a, colors.surface)
    : colors.accentSoft;

class _GuardEntry {
  const _GuardEntry({
    required this.foreground,
    required this.foregroundOf,
    required this.background,
    required this.backgroundOf,
    required this.floor,
    required this.purpose,
    this.exempt = false,
  });

  final String foreground;
  final Color Function(MileafColors colors) foregroundOf;
  final String background;
  final Color Function(MileafColors colors) backgroundOf;

  /// WCAG 门槛：正文 4.5，图形与边框 3.0。
  final double floor;

  /// 声明用途（登记表口径）。
  final String purpose;

  /// true = 实测低于门槛，按 MG03 降级为记录性组合（不得改色值救测）。
  final bool exempt;
}

/// 「前景 token × 声明背景」登记表。
///
/// 口径：声明底取各 token 的文档声明用途——内容底（canvas / surface /
/// hero）、分段轨道（segmentTrack；深色即 surfaceRaised）、弱强调底
///（accentSoft；深色半透明按合成口径记两条）。surfaceRaised 浅色等于
/// surface、深色等于 segmentTrack，不再单列。豁免条目只登记不断言
///（见「记录性组合」测试）。
List<_GuardEntry> _registry(MileafColors colors) {
  final isDark = colors.isDark;
  const softName = 'accentSoft';

  final textEntries = [
    for (final f in <(String, Color Function(MileafColors))>[
      ('text', (c) => c.text),
      ('textSecondary', (c) => c.textSecondary),
      ('textFaint', (c) => c.textFaint),
    ])
      ...[
        _GuardEntry(
          foreground: f.$1,
          foregroundOf: f.$2,
          background: 'canvas',
          backgroundOf: (c) => c.canvas,
          floor: 4.5,
          purpose: '正文类：页面底色上的正文',
        ),
        _GuardEntry(
          foreground: f.$1,
          foregroundOf: f.$2,
          background: 'surface',
          backgroundOf: (c) => c.surface,
          floor: 4.5,
          purpose: '正文类：卡面 / 表面底上的正文',
        ),
        _GuardEntry(
          foreground: f.$1,
          foregroundOf: f.$2,
          background: 'segmentTrack',
          backgroundOf: (c) => c.segmentTrack,
          floor: 4.5,
          purpose: '正文类：分段轨道中性底上的文字',
          exempt: f.$1 == 'textFaint' && !isDark,
        ),
        _GuardEntry(
          foreground: f.$1,
          foregroundOf: f.$2,
          background: softName,
          backgroundOf: _accentSoftOverCanvas,
          floor: 4.5,
          purpose: '正文类：弱强调底上的文字',
          exempt: f.$1 == 'textFaint',
        ),
      ],
    // 深色 accentSoft 再记一条 over surface 合成底（半透明的实际落底
    // 随下层内容变化，取 canvas / surface 两条常见口径）。
    if (isDark)
      _GuardEntry(
        foreground: 'textFaint',
        foregroundOf: (c) => c.textFaint,
        background: 'accentSoft（合成底 over surface）',
        backgroundOf: _accentSoftOverSurface,
        floor: 4.5,
        purpose: '正文类：弱强调底上的文字',
        exempt: true,
      ),
  ];

  // hero 区有自己的一组前景（heroText / heroMuted / heroFaint，值与
  // 正文三档一致），按其声明底 hero 单列。
  final heroEntries = [
    for (final f in <(String, Color Function(MileafColors))>[
      ('heroText', (c) => c.heroText),
      ('heroMuted', (c) => c.heroMuted),
      ('heroFaint', (c) => c.heroFaint),
    ])
      _GuardEntry(
        foreground: f.$1,
        foregroundOf: f.$2,
        background: 'hero',
        backgroundOf: (c) => c.hero,
        floor: 4.5,
        purpose: '正文类：hero 区文字',
      ),
  ];

  final graphicsEntries = [
    for (final f in <(String, Color Function(MileafColors))>[
      ('accent', (c) => c.accent),
      ('accentStrong', (c) => c.accentStrong),
      ('controlBorder', (c) => c.controlBorder),
      ('reference', (c) => c.reference),
      ('warning', (c) => c.warning),
      ('error', (c) => c.error),
    ])
      ...[
        _GuardEntry(
          foreground: f.$1,
          foregroundOf: f.$2,
          background: 'canvas',
          backgroundOf: (c) => c.canvas,
          floor: 3.0,
          purpose: '图形与边框类：页面底色上的图形 / 描边',
        ),
        _GuardEntry(
          foreground: f.$1,
          foregroundOf: f.$2,
          background: 'surface',
          backgroundOf: (c) => c.surface,
          floor: 3.0,
          purpose: '图形与边框类：卡面 / 表面底上的图形 / 描边',
        ),
      ],
  ];

  final strongTextEntries = [
    // accentStrong 作为文字（链接、选中标签、主要文字强调）按 4.5 断言。
    _GuardEntry(
      foreground: 'accentStrong（作文字）',
      foregroundOf: (c) => c.accentStrong,
      background: 'canvas',
      backgroundOf: (c) => c.canvas,
      floor: 4.5,
      purpose: 'accentStrong 作为文字（链接、选中标签、主按钮文字）',
    ),
    _GuardEntry(
      foreground: 'accentStrong（作文字）',
      foregroundOf: (c) => c.accentStrong,
      background: 'surface',
      backgroundOf: (c) => c.surface,
      floor: 4.5,
      purpose: 'accentStrong 作为文字（链接、选中标签、主按钮文字）',
    ),
    // accentStrong 实色填充上的文字。
    _GuardEntry(
      foreground: 'textOnAccent',
      foregroundOf: (c) => c.textOnAccent,
      background: 'accentStrong（实色填充）',
      backgroundOf: (c) => c.accentStrong,
      floor: 4.5,
      purpose: '正文类：主按钮 / 实色强调底上的文字',
    ),
  ];

  return [
    ...textEntries,
    ...heroEntries,
    ...graphicsEntries,
    ...strongTextEntries,
  ];
}