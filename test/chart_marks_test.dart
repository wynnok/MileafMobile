import 'dart:math' as math;

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

/// 一列一列地量某个颜色的竖条：单次扫描后按 x 归并。
///
/// 每列取「最长的连续竖段」而不是上下界差：文字列在竖直方向是断开的，
/// 只有真正贯通绘图区的竖线才会得到很高的值。
List<({int from, int to, int height})> colorColumnRuns(
  PixelProbe probe,
  Color color, {
  int tolerance = 2,
}) {
  final columns = <int, List<int>>{};
  for (final pixel in probe.find(color, tolerance: tolerance)) {
    (columns[pixel.dx.toInt()] ??= <int>[]).add(pixel.dy.toInt());
  }
  int longestRun(List<int> values) {
    values.sort();
    var best = 1;
    var current = 1;
    for (var i = 1; i < values.length; i++) {
      current = values[i] == values[i - 1] + 1 ? current + 1 : 1;
      if (current > best) best = current;
    }
    return best;
  }

  final xs = columns.keys.toList()..sort();
  final runs = <({int from, int to, int height})>[];
  for (final x in xs) {
    final height = longestRun(columns[x]!);
    if (runs.isNotEmpty && x == runs.last.to + 1) {
      final last = runs.removeLast();
      runs.add((from: last.from, to: x, height: math.max(last.height, height)));
    } else {
      runs.add((from: x, to: x, height: height));
    }
  }
  return runs;
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
    ChartSeries(label: '每日里程', values: values, style: ChartSeriesStyle.bars),
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
        testWidgets('${brightness.name} $surfaceName：每根柱都是强调色实色且合成对比度 ≥3:1', (
          tester,
        ) async {
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
            reason:
                '${brightness.name} $surfaceName: 实色柱应有成片的像素，'
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
            // 只量柱身内部：圆角与抗锯齿的边缘不算「淡化柱」。
            final body = probe.columnBounds(colors.accent, bar.from, bar.to)!;
            final inset = (bar.to - bar.from) / 2 - 4;
            expect(
              probe.count(
                faded,
                tolerance: 2,
                where: (x, y) =>
                    (x - center).abs() <= inset &&
                    y > body.top + 3 &&
                    y < body.bottom - 3,
              ),
              // 真正的 30% 淡化柱有上百像素；个位数来自圆角的抗锯齿。
              lessThan(20),
              reason:
                  '${brightness.name} $surfaceName: 仍有 30% 淡化柱'
                  '（合成色 $faded）',
            );
          }
        });
      }
    }
  });

  group('补能竖线的可读性', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name} 画布：每根竖线都是强调色实色且合成对比度 ≥3:1', (
        tester,
      ) async {
        final colors = _colors(brightness);
        // R06: five known slots include two real-zero baseline marks.
        const values = <num?>[10, 0, null, 4, 7, 0];
        final probe = await pumpChart(
          tester,
          brightness: brightness,
          chart: _stems(values, selectedIndex: 4),
        );

        final stems = probe.columns(colors.accent);
        expect(
          stems,
          hasLength(5),
          reason: '${brightness.name}: 三根竖线和两个真实零标记，缺失留空',
        );
        final heights = [
          for (final stem in stems)
            probe
                    .bounds(
                      colors.accent,
                      where: (x, _) => x >= stem.from && x <= stem.to,
                    )!
                    .height /
                probeScale,
        ];
        expect(heights.where((height) => height > 20), hasLength(3));
        expect(heights.where((height) => height <= 20), hasLength(2));
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
            greaterThan(heights[stems.indexOf(stem)] > 20 ? 120 : 0),
            reason: '${brightness.name}: 整根竖线都应是强调色实色，而不是 35% 淡化',
          );
          final topmost = probe
              .find(
                colors.accent,
                where: (x, _) => x >= stem.from && x <= stem.to,
              )
              .reduce((a, b) => a.dy < b.dy ? a : b);
          final beside = probe.at(
            stem.to + 6 * probeScale.toInt(),
            topmost.dy.round(),
          );
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
      testWidgets('${brightness.name}：零保留零值标记、缺失留空、选中的零仍为零', (tester) async {
        final colors = _colors(brightness);
        const values = <num?>[12, 0, null, 18];
        final probe = await pumpChart(
          tester,
          brightness: brightness,
          chart: _bars(values, selectedIndex: 1),
        );

        final bars = probe.columns(colors.accent);
        expect(
          bars,
          hasLength(3),
          reason: '${brightness.name}: 零与缺失各占一槽，只有零有标记',
        );

        final zero = bars[1];
        final zeroBounds = probe.bounds(
          colors.accent,
          where: (x, _) => x >= zero.from && x <= zero.to,
        )!;
        expect(
          zeroBounds.height / probeScale,
          lessThanOrEqualTo(10),
          reason:
              '${brightness.name}: 零值只能是一个点（含 R29 半径 4 的选中点），'
              '不能被画成非零柱',
        );
        final all = probe.bounds(colors.accent)!;
        expect(
          (zeroBounds.bottom - all.bottom).abs() <= 2 * probeScale,
          isTrue,
          reason: '${brightness.name}: 零值标记应贴在零基线上',
        );

        // R29：选中是 1px 竖线 + 半径 4 的 accent 点，光晕取消。
        // 旧的 8px 光晕有上百像素；个位数的抗锯齿像素不算光晕。
        expect(
          probe.count(
            compositeOver(colors.accent, .2, colors.canvas),
            tolerance: 2,
          ),
          lessThan(10),
          reason: '${brightness.name}: 选中标记不再有光晕',
        );
        expect(
          probe.columns(colors.textSecondary, tolerance: 2),
          isNotEmpty,
          reason: '${brightness.name}: 选中的零由竖线指认',
        );

        expect(find.text('0 km'), findsOneWidget);
        expect(find.text('— km'), findsNothing);
      });
    }
  });

  group('选中标记（R29）', () {
    /// 选中点是一条 1px textSecondary 竖线加一个半径 4 的 accent 点；
    /// 旧的 8px 光晕已取消。
    /// 选中竖线：贯通绘图区、且只有 1 逻辑像素宽的那一条 textSecondary。
    Rect ruleOf(PixelProbe probe, Color color) {
      final all = colorColumnRuns(probe, color, tolerance: 2);
      final runs = all
          .where(
            (run) =>
                // 选中的点把竖线切成两段，每段仍有 40+ 逻辑像素高；
                // 文字列只有十几个。
                run.height / probeScale > 40 &&
                (run.to - run.from + 1) / probeScale <= 4,
          )
          .toList();
      expect(runs, hasLength(1), reason: '只画一条 1px 选中竖线；全部 $all');
      return probe.columnBounds(color, runs.single.from, runs.single.to)!;
    }

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}：1px 竖线加半径 4 的点，不再有光晕', (tester) async {
        final colors = _colors(brightness);
        // 平直折线：竖线以外只有一条 2px 的线与一个 8px 的点。
        final probe = await pumpChart(
          tester,
          brightness: brightness,
          // 关掉两条轴：图里只剩数据线、选中竖线与选中点。
          chart: TimeSeriesChart(
            title: '每日里程',
            unit: 'km',
            times: [for (var i = 0; i < 5; i++) DateTime(2026, 10, 1 + i)],
            series: const [
              ChartSeries(label: '每日里程', values: [20, 20, 20, 20, 20]),
            ],
            semanticsLabel: '每日里程图表',
            selectedIndex: 2,
            height: 120,
            showYAxis: false,
            showXAxis: false,
            readout: (index) => '20 km',
          ),
        );
        final rule = ruleOf(probe, colors.textSecondary);
        expect(
          (rule.width + 1) / probeScale,
          lessThanOrEqualTo(2),
          reason: '${brightness.name}: 竖线 1 逻辑像素',
        );
        expect(
          rule.height / probeScale,
          greaterThan(80),
          reason: '${brightness.name}: 竖线贯穿绘图区',
        );
        final dot = probe.bounds(
          colors.accent,
          tolerance: 2,
          where: (x, _) => (x - rule.center.dx).abs() <= 10 * probeScale,
        )!;
        expect(
          (dot.height + 1) / probeScale,
          closeTo(8, 2),
          reason: '${brightness.name}: 半径 4 的 accent 点',
        );
        expect(
          probe.count(
            compositeOver(colors.accent, .2, colors.canvas),
            tolerance: 2,
          ),
          lessThan(10),
          reason: '${brightness.name}: 光晕取消',
        );
      });
    }

    testWidgets('light：极值、负值、单点与首尾选中都不被绘图区裁切', (tester) async {
      final colors = _colors(Brightness.light);

      Widget bare(List<num?> values, {required ChartSeriesStyle style}) =>
          TimeSeriesChart(
            title: '每日里程',
            unit: 'km',
            times: [
              for (var i = 0; i < values.length; i++) DateTime(2026, 10, 1 + i),
            ],
            series: [ChartSeries(label: '里程', values: values, style: style)],
            semanticsLabel: '每日里程图表',
            selectedIndex: 0,
            height: 120,
            showYAxis: false,
            showXAxis: false,
            readout: (index) => '读值 i$index',
          );

      // 100 km 顶到最高刻度：端点贴在绘图区上沿，不能被裁。
      final peak = await pumpChart(
        tester,
        brightness: Brightness.light,
        chart: bare(const [100, 40, 60], style: ChartSeriesStyle.stem),
      );
      expect(
        peak.bounds(colors.accent)!.top,
        greaterThan(0),
        reason: '最大值处的标记被裁切',
      );

      // 负值柱挂在零基线之下：标记仍完整。
      final negative = await pumpChart(
        tester,
        brightness: Brightness.light,
        chart: bare(const [-20, 30], style: ChartSeriesStyle.bars),
      );
      expect(
        negative.bounds(colors.accent)!.bottom,
        lessThan(negative.height - 1),
      );

      // 单点居中：竖线落在绘图区中线上。
      final single = await pumpChart(
        tester,
        brightness: Brightness.light,
        chart: bare(const [10], style: ChartSeriesStyle.bars),
      );
      final singleRule = ruleOf(single, colors.textSecondary);
      expect(singleRule.top, greaterThan(0), reason: '单点的竖线不被上沿裁切');
      expect(
        singleRule.bottom,
        lessThan(single.height - 1),
        reason: '单点的竖线不被下沿裁切',
      );
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
        // The hero has no glow (U02 removed it), but it may sit on either the
        // canvas or the card surface, so the background is sampled beside the
        // mark rather than assumed from a token.
        final beside = probe.at(
          first.to + 20 * probeScale.toInt(),
          mark.center.dy.round(),
        );
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
      testWidgets('${brightness.name}：竖线里被选中的真实零只用基线点，不冒充柱体积', (tester) async {
        final colors = _colors(brightness);
        // R06/R29: zero keeps a baseline mark, missing retains an empty slot.
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
          lessThanOrEqualTo(10),
          reason:
              '${brightness.name}: 选中的零只用半径 4 的点，'
              '不能用柱体积（会把零读成有体积）',
        );
        expect(
          short.single.height / probeScale,
          lessThanOrEqualTo(10),
          reason: '${brightness.name}: 零没有高度',
        );
        final baseline = tall.map((m) => m.bottom).reduce(math.max);
        expect(
          (short.single.center.dy - baseline).abs() <= 6 * probeScale,
          isTrue,
          reason: '${brightness.name}: 零的标记落在零基线上',
        );
        expect(
          probe.columns(colors.textSecondary, tolerance: 2),
          isNotEmpty,
          reason: '${brightness.name}: 零也由选中竖线指认',
        );
      });
    }
  });
}
