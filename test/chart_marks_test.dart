import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';

import 'support/color_math.dart';
import 'support/pixel_probe.dart';

/// Renders one shared chart on a real theme surface and returns its pixels.
///
/// The chart is the official component (`TimeSeriesChart` / `StemChart`), the
/// colours come from `mileafTheme`, and the boundary paints the same background
/// the pages use, so a pixel here is the mark a user sees.
Future<PixelProbe> pumpChart(
  WidgetTester tester, {
  required Brightness brightness,
  required Widget chart,
  Color? background,
  bool hero = false,
  double width = 320,
}) async {
  tester.view.physicalSize = const Size(400, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final colors = _colors(brightness);
  final key = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      theme: mileafTheme(brightness),
      home: RepaintBoundary(
        key: key,
        child: Scaffold(
          backgroundColor: background ?? colors.canvas,
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: hero ? MileafHero(child: chart) : chart,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return capturePixels(tester, find.byKey(key), pixelRatio: probeScale);
}

/// Physical pixels per logical pixel: the same 2x the render pipeline and a
/// real 3x/2x screen use, so a 1.5px hairline is judged on whole physical
/// pixels instead of an artificially coarse 1x rasterisation.
const probeScale = 2.0;

MileafColors _colors(Brightness brightness) => brightness == Brightness.dark
    ? const MileafColors.dark()
    : const MileafColors.light();

TimeSeriesChart _bars(
  List<num?> values, {
  int selectedIndex = 0,
  bool onHero = false,
}) => TimeSeriesChart(
  title: '每日里程',
  unit: 'km',
  times: [for (var i = 0; i < values.length; i++) DateTime(2026, 10, 1 + i)],
  series: [
    ChartSeries(
      label: '每日里程',
      values: values,
      style: ChartSeriesStyle.bars,
    ),
  ],
  semanticsLabel: '每日里程图表',
  selectedIndex: selectedIndex,
  onHero: onHero,
  height: 120,
  readout: (index) => '${values[index] ?? '—'} km',
);

StemChart _stems(List<num?> values, {int selectedIndex = 0}) => StemChart(
  title: '每日补能',
  unit: 'kWh',
  times: [for (var i = 0; i < values.length; i++) DateTime(2026, 10, 1 + i)],
  values: values,
  semanticsLabel: '每日补能图表',
  selectedIndex: selectedIndex,
  height: 120,
  readout: (index) => '${values[index] ?? '—'} kWh',
);

void main() {
  group('普通柱的可读性', () {
    for (final brightness in Brightness.values) {
      for (final onSurface in [false, true]) {
        final surfaceName = onSurface ? '表面' : '画布';
        testWidgets(
          '${brightness.name} $surfaceName：每根柱都是强调色实色且合成对比度 ≥3:1',
          (tester) async {
            final colors = _colors(brightness);
            final background = onSurface ? colors.surface : colors.canvas;
            const values = <num?>[12, 24, 8, 30, 18, 22];
            final probe = await pumpChart(
              tester,
              brightness: brightness,
              background: background,
              chart: _bars(values, selectedIndex: 2),
            );

            // The background under the marks is the surface the chart sits on.
            expect(probe.at(probe.width - 2, probe.height - 2), background);

            // One solid column per known value: no bar is drawn faded.
            final bars = probe.columns(colors.accent);
            expect(
              bars,
              hasLength(values.length),
              reason:
                  '${brightness.name} $surfaceName: 每根普通柱都应是 ${colors.accent} 实色',
            );
            expect(
              probe.count(colors.accent),
              greaterThan(800),
              reason: '${brightness.name} $surfaceName: 实色柱应有成片的像素，'
                  '而不是一条描边',
            );

            // The colour actually painted against the background actually
            // painted: sample the middle of the first bar and the gap beside it.
            final first = bars.first;
            final markRect = probe.bounds(
              colors.accent,
              where: (x, _) => x >= first.from && x <= first.to,
            )!;
            final markX = (first.from + first.to) ~/ 2;
            final markY = markRect.center.dy.round();
            final painted = probe.at(markX, markY);
            final beside = probe.at(first.to + 15 * probeScale.toInt(), markY);
            expect(painted, colors.accent);
            expect(beside, background);
            expect(
              contrastRatio(painted, beside),
              greaterThanOrEqualTo(3),
              reason: '${brightness.name} $surfaceName: 普通柱与背景合成后仍须 ≥3:1',
            );

            // The 30% idle rule must be gone: the interior of every bar is
            // solid, so no faded composite survives away from antialiased edges.
            final faded = compositeOver(colors.accent, .3, background);
            for (final bar in bars) {
              final center = (bar.from + bar.to) ~/ 2;
              expect(
                probe.count(
                  faded,
                  tolerance: 2,
                  where: (x, _) => (x - center).abs() <= 2,
                ),
                0,
                reason: '${brightness.name} $surfaceName: 仍有 30% 淡化柱'
                    '（合成色 $faded）',
              );
            }
          },
        );
      }
    }
  });

  group('补能竖线的可读性', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name} 画布：每根竖线都是强调色实色且合成对比度 ≥3:1', (
        tester,
      ) async {
        final colors = _colors(brightness);
        // Two empty slots (a real zero and a null) between five slots with data.
        const values = <num?>[10, 0, null, 4, 7, 0];
        final probe = await pumpChart(
          tester,
          brightness: brightness,
          chart: _stems(values, selectedIndex: 4),
        );

        final stems = probe.columns(colors.accent);
        expect(
          stems,
          hasLength(3),
          reason: '${brightness.name}: 零与缺失都不画竖线，只应有 3 根实色竖线',
        );
        for (final stem in stems) {
          expect(
            stem.to - stem.from + 1,
            lessThanOrEqualTo(9 * probeScale),
            reason: '${brightness.name}: 补能竖线是细线加端点，不是柱',
          );
          // The hairline is antialiased, so count the pixels that are exactly
          // the accent: a 35% hairline could not produce any of them.
          final solid = probe.count(
            colors.accent,
            where: (x, _) => x >= stem.from && x <= stem.to,
          );
          expect(
            solid,
            greaterThan(120),
            reason: '${brightness.name}: 整根竖线都应是强调色实色，而不是 35% 淡化',
          );
          final topmost = probe
              .find(
                colors.accent,
                where: (x, _) => x >= stem.from && x <= stem.to,
              )
              .reduce((a, b) => a.dy < b.dy ? a : b);
          final beside = probe.at(stem.to + 6 * probeScale.toInt(), topmost.dy.round());
          expect(beside, colors.canvas);
          expect(
            contrastRatio(colors.accent, beside),
            greaterThanOrEqualTo(3),
            reason: '${brightness.name}: 补能竖线与背景合成后仍须 ≥3:1',
          );
        }
      });
    }
  });

  group('真实零与缺失', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}：零保留零值标记、缺失留空、选中的零仍为零', (
        tester,
      ) async {
        final colors = _colors(brightness);
        const values = <num?>[12, 0, null, 18];
        final probe = await pumpChart(
          tester,
          brightness: brightness,
          chart: _bars(values, selectedIndex: 1),
        );

        final bars = probe.columns(colors.accent);
        expect(bars, hasLength(3), reason: '${brightness.name}: 零与缺失各占一槽，只有零有标记');

        final zero = bars[1];
        final zeroBounds = probe.bounds(
          colors.accent,
          where: (x, _) => x >= zero.from && x <= zero.to,
        )!;
        expect(
          zeroBounds.height / probeScale,
          lessThanOrEqualTo(4),
          reason: '${brightness.name}: 零值只能是一个点，不能被画成非零柱',
        );
        final all = probe.bounds(colors.accent)!;
        expect(
          (zeroBounds.bottom - all.bottom).abs() <= 2 * probeScale,
          isTrue,
          reason: '${brightness.name}: 零值标记应贴在零基线上',
        );

        // The zero is selected: the halo marks it without inventing volume.
        final halo = compositeOver(colors.accent, .2, colors.canvas);
        expect(
          probe.bounds(halo, tolerance: 2),
          isNotNull,
          reason: '${brightness.name}: 选中的零仍需可见的选中光晕',
        );

        expect(find.text('0 km'), findsOneWidget);
        expect(find.text('— km'), findsNothing);
      });
    }
  });

  group('选中标记', () {
    /// Bounds of the selection halo near one mark; the accent antialiases to
    /// the same composite, so the window keeps neighbouring marks out.
    Rect? haloNear(PixelProbe probe, Color halo, int centerX) => probe.bounds(
      halo,
      tolerance: 2,
      where: (x, _) => (x - centerX).abs() <= 12 * probeScale,
    );

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}：选中柱有端点与光晕，不只靠颜色', (tester) async {
        final colors = _colors(brightness);
        final halo = compositeOver(colors.accent, .2, colors.canvas);
        final probe = await pumpChart(
          tester,
          brightness: brightness,
          chart: _bars(const [20, 20, 20, 20, 20], selectedIndex: 2),
        );

        final bars = probe.columns(colors.accent);
        expect(bars, hasLength(5));
        Rect? markIn(({int from, int to}) bar) => probe.bounds(
          colors.accent,
          where: (x, _) => x >= bar.from && x <= bar.to,
        );
        final selectedMark = markIn(bars[2])!;
        final plainMark = markIn(bars[1])!;
        expect(
          (plainMark.top - selectedMark.top) / probeScale,
          greaterThanOrEqualTo(3),
          reason: '${brightness.name}: 等高的柱里，选中那根应有端点这类几何标记',
        );

        final haloBounds = haloNear(
          probe,
          halo,
          (bars[2].from + bars[2].to) ~/ 2,
        );
        expect(haloBounds, isNotNull, reason: '${brightness.name}: 选中光晕应被绘制');
        expect(
          haloBounds!.width / probeScale,
          greaterThanOrEqualTo(14),
          reason: '${brightness.name}: 光晕是既有 8px 尺寸，横向应完整可见',
        );
        expect(
          (selectedMark.top - haloBounds.top) / probeScale,
          greaterThanOrEqualTo(3),
          reason: '${brightness.name}: 光晕上方不能被裁掉',
        );
      });
    }

    testWidgets('light：极值、负值、单点与首尾选中都不被绘图区裁切', (tester) async {
      final colors = _colors(Brightness.light);
      final halo = compositeOver(colors.accent, .2, colors.canvas);

      // 100 km rounds exactly onto the top tick, so the stem endpoint sits on
      // the plot edge; the halo may not be trimmed there.
      final peak = await pumpChart(
        tester,
        brightness: Brightness.light,
        chart: _stems(const [100, 40, 60], selectedIndex: 0),
      );
      final peakMark = peak.bounds(colors.accent)!;
      final peakHalo = peak.bounds(
        halo,
        tolerance: 2,
        where: (x, y) => x <= 12 * probeScale && y < peakMark.top,
      )!;
      expect(peakHalo.top, greaterThan(0));
      expect(
        (peakMark.top - peakHalo.top) / probeScale,
        greaterThanOrEqualTo(3),
        reason: '最大值处的选中光晕被裁切',
      );

      // A negative bar hangs below the zero baseline: its halo must survive too.
      final negative = await pumpChart(
        tester,
        brightness: Brightness.light,
        chart: _bars(const [-20, 30], selectedIndex: 0),
      );
      final negativeMark = negative.bounds(colors.accent)!;
      final negativeHalo = negative.bounds(halo, tolerance: 2)!;
      expect(negativeHalo.bottom, lessThan(negative.height - 1));
      expect(
        (negativeHalo.bottom - negativeMark.bottom) / probeScale,
        greaterThanOrEqualTo(3),
        reason: '负值处的选中光晕被裁切',
      );

      // A single point is centred; the halo must be whole in both axes.
      final single = await pumpChart(
        tester,
        brightness: Brightness.light,
        chart: _bars(const [10], selectedIndex: 0),
      );
      final singleMark = single.bounds(colors.accent)!;
      final singleHalo = single.bounds(halo, tolerance: 2)!;
      expect(singleHalo.width / probeScale, greaterThanOrEqualTo(14));
      expect(
        (singleMark.top - singleHalo.top) / probeScale,
        greaterThanOrEqualTo(3),
      );
      expect(singleHalo.bottom, lessThan(single.height - 1));
    });
  });

  group('微趋势柱', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}：微趋势柱也用实色，不再 55% 淡化', (tester) async {
        final colors = _colors(brightness);
        final probe = await pumpChart(
          tester,
          brightness: brightness,
          chart: const SizedBox(
            height: 40,
            child: MicroSpark(
              values: [3, 5, 2, 6, 4],
              style: SparkStyle.bars,
              semanticsLabel: '每周里程',
            ),
          ),
        );
        expect(
          probe.count(colors.accent),
          greaterThan(40),
          reason: '${brightness.name}: 微趋势柱应是实色',
        );
        expect(
          probe.count(compositeOver(colors.accent, .55, colors.canvas)),
          0,
          reason: '${brightness.name}: 仍有 55% 淡化的微趋势柱',
        );
      });
    }
  });

  group('hero 内的图形', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}：hero 内普通柱与竖线用 accentHero 实色且 ≥3:1', (
        tester,
      ) async {
        final colors = _colors(brightness);
        final probe = await pumpChart(
          tester,
          brightness: brightness,
          hero: true,
          chart: _bars(const [12, 24, 8, 30], selectedIndex: 1, onHero: true),
        );

        final bars = probe.columns(colors.accentHero);
        expect(
          bars,
          hasLength(4),
          reason: '${brightness.name}: hero 内每根柱都应是 ${colors.accentHero} 实色',
        );
        final first = bars.first;
        final mark = probe.bounds(
          colors.accentHero,
          where: (x, _) => x >= first.from && x <= first.to,
        )!;
        final painted = probe.at(
          (first.from + first.to) ~/ 2,
          mark.center.dy.round(),
        );
        expect(painted, colors.accentHero);
        // The hero carries a decorative glow, so the background is sampled
        // next to the mark rather than assumed from the token.
        final beside = probe.at(first.to + 20 * probeScale.toInt(), mark.center.dy.round());
        expect(
          contrastRatio(painted, beside),
          greaterThanOrEqualTo(3),
          reason: '${brightness.name}: hero 内的普通柱与所在背景仍须 ≥3:1',
        );
      });
    }
  });

  group('选中零值', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}：竖线里被选中的真实零用零值点，不用当前端点', (
        tester,
      ) async {
        final colors = _colors(brightness);
        final halo = compositeOver(colors.accent, .2, colors.canvas);
        // Index 1 is a real zero, index 2 is missing: neither draws a stem, so
        // the selection marker is the only thing on screen for them.
        final probe = await pumpChart(
          tester,
          brightness: brightness,
          chart: _stems(const [10, 0, null, 7], selectedIndex: 1),
        );

        final marks = [
          for (final column in probe.columns(colors.accent))
            probe.bounds(
              colors.accent,
              where: (x, _) => x >= column.from && x <= column.to,
            )!,
        ];
        // Two hairs for 10 and 7; a real zero draws no hair. The selected zero
        // is therefore the one short mark, and a missing point draws none.
        final tall = marks.where((m) => m.height / probeScale > 20).toList();
        final short = marks.where((m) => m.height / probeScale <= 20).toList();
        expect(tall, hasLength(2), reason: '${brightness.name}: 两根竖线应有实际高度');
        expect(
          short,
          hasLength(1),
          reason: '${brightness.name}: 只有被选中的零有一个短标记，缺失点没有',
        );
        expect(
          short.single.width / probeScale,
          lessThanOrEqualTo(4),
          reason: '${brightness.name}: 选中的零只能用零值点那样的小标记，'
              '不能用当前端点（会把零读成有体积）',
        );
        expect(
          probe.bounds(halo, tolerance: 2),
          isNotNull,
          reason: '${brightness.name}: 选中的零仍要有光晕',
        );
      });
    }
  });
}
