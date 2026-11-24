import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/semantic.dart';

/// Exact VH23–VH25 values published in the approved design.
void main() {
  const light = MileafColors.light();
  const dark = MileafColors.dark();

  const expected = <(MileafHue, List<int>)>[
    (
      MileafHue.sky,
      [
        0xFF95CAEA,
        0xFF346C90,
        0xFF205678,
        0xFFA9DAF7,
        0xFFECF6FC,
        0xFFCDE8F8,
        0xFF1C2B38,
        0xFF263C4D,
      ],
    ),
    (
      MileafHue.mint,
      [
        0xFF9AF1CD,
        0xFF23715D,
        0xFF215F50,
        0xFFA0EDD0,
        0xFFE8F9F1,
        0xFFC6F4E0,
        0xFF192D29,
        0xFF203B34,
      ],
    ),
    (
      MileafHue.teal,
      [
        0xFF0E7C7B,
        0xFF0E7C7B,
        0xFF145B5C,
        0xFF8DDBD4,
        0xFFE9F4F3,
        0xFFD4EEEB,
        0xFF1B292C,
        0xFF223639,
      ],
    ),
    (
      MileafHue.coral,
      [
        0xFFF65A49,
        0xFFAD3B31,
        0xFF9D3428,
        0xFFFFA89D,
        0xFFFFF0EC,
        0xFFFFE6E0,
        0xFF35262A,
        0xFF453038,
      ],
    ),
    (
      MileafHue.plum,
      [
        0xFF4B1D3F,
        0xFF7D486C,
        0xFF4B1D3F,
        0xFFE4BCD8,
        0xFFF3EAF1,
        0xFFEDE0EB,
        0xFF2C2330,
        0xFF382B3C,
      ],
    ),
    (
      MileafHue.mutedPlum,
      [
        0xFF4B1D3F,
        0xFF7D486C,
        0xFF4B1D3F,
        0xFFE4BCD8,
        0xFFF2EDF2,
        0xFFEDE0EB,
        0xFF27232B,
        0xFF342A35,
      ],
    ),
  ];

  test('六域的标记、前景、两档背板与批准色表逐值一致', () {
    for (final (hue, values) in expected) {
      expect(
        [
          hue.marker,
          hue.solid(light),
          hue.strong(light),
          hue.strong(dark),
          light.cardSurface(hue),
          light.focused(hue).surface,
          dark.cardSurface(hue),
          dark.focused(hue).surface,
        ],
        values.map(Color.new),
        reason: hue.name,
      );
      expect(hue.solid(dark), hue.strong(dark));
    }
  });

  test('VH23–VH26 里程、主操作与原底栏各取对应色板', () {
    final journey = MileafDataDomain.journey.hue;
    expect(light.cardSurface(journey), const Color(0xFFECF6FC));
    expect(light.focused(journey).surface, const Color(0xFFCDE8F8));
    expect(dark.cardSurface(journey), const Color(0xFF1C2B38));
    expect(dark.focused(journey).surface, const Color(0xFF263C4D));
    expect(light.primaryAction, const Color(0xFF0E7C7B));
    expect(dark.primaryAction, const Color(0xFF0E7C7B));
    expect(light.onPrimaryAction, Colors.white);
    expect(dark.onPrimaryAction, Colors.white);
    expect(light.navigationActive, const Color(0xFF0B62C4));
    expect(dark.navigationActive, const Color(0xFF64A8FF));
    expect(dark.navigationSolid, const Color(0xFF191E25));
    expect(light.navigationSelection, const Color(0xFFE6E9ED));
    expect(
      light.lerp(dark, .49).navigationSolid,
      Color.lerp(Colors.white, const Color(0xFF12161C), .49),
    );
    expect(
      light.lerp(dark, .51).navigationSolid,
      Color.lerp(Colors.white, const Color(0xFF191E25), .51),
    );
  });

  group('VH24 中性家族保留低彩度', () {
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

    test('浅色与深色的中性 token 维持低彩度', () {
      for (final colors in <MileafColors>[light, dark]) {
        final neutrals = <String, Color>{
          'canvas': colors.canvas,
          'cardSurface': colors.cardSurface(),
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
          final (_, chroma, _) = oklch(color);
          final limit = name == 'textMuted' ? .03 : .025;
          expect(
            chroma,
            lessThanOrEqualTo(limit),
            reason: '$name 彩度 ${chroma.toStringAsFixed(4)} 超过 $limit',
          );
        });
      }
    });
  });

  group('VH25 数据域 → 色相', () {
    test('六个域采用现行色阶，环境和停放共用梅紫家族', () {
      const expected = <MileafDataDomain, MileafHue>{
        MileafDataDomain.journey: MileafHue.sky,
        MileafDataDomain.energy: MileafHue.mint,
        MileafDataDomain.efficiency: MileafHue.teal,
        MileafDataDomain.cost: MileafHue.coral,
        MileafDataDomain.climate: MileafHue.mutedPlum,
        MileafDataDomain.dwell: MileafHue.plum,
      };
      expected.forEach((domain, hue) {
        expect(domain.hue, hue, reason: '${domain.name} → ${hue.name}');
        expect(domain.solid(light), hue.solid(light));
        expect(domain.strong(light), hue.strong(light));
      });
      final used = expected.values.toSet();
      expect(used, hasLength(MileafHue.values.length));
    });

    test('交互与数据各自取色，深青锚点在能耗中复用', () {
      expect(light.accentStrong, const Color(0xFF145B5C));
      expect(dark.accentStrong, const Color(0xFF8DDBD4));
      expect(MileafDataDomain.journey.solid(light), isNot(light.accent));
      expect(MileafDataDomain.efficiency.solid(light), light.accent);
      expect(
        MileafDataDomain.climate.hue.marker,
        MileafDataDomain.dwell.hue.marker,
      );
      expect(
        light.cardSurface(MileafDataDomain.climate.hue),
        isNot(light.cardSurface(MileafDataDomain.dwell.hue)),
      );
    });
  });
}
