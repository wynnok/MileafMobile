// AP05 图表语法（R29）：完整读数头与紧凑读数行、步进、右侧 Y 轴、DF9 轴刻度、
// 柱端圆角、条形参照刻度、选中标记、图例在轴下、无数据收起、M07 触觉、M09 淡入。
//
// 断言分三层：结构（顺序与角色）、行为（选点、步进、触觉、朗读）、像素（标记与
// 刻度真的画成了规格说的样子）。不做私有字段断言。
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/tokens.dart';

import 'support/pixel_probe.dart';

const _plotKey = ValueKey('ap05-plot');
const _fadeKey = MileafChartGrammar.identityFadeKey;

MileafColors _colors(Brightness brightness) => brightness == Brightness.dark
    ? const MileafColors.dark()
    : const MileafColors.light();

TimeSeriesChart chart(
  List<num?> values, {
  String title = '每日里程',
  String unit = 'km',
  String seriesLabel = '里程',
  List<num?>? reference,
  String referenceLabel = '上月同期',
  ChartSeriesStyle style = ChartSeriesStyle.line,
  int? selectedIndex,
  ValueChanged<int>? onSelected,
  ChartReadoutScale scale = ChartReadoutScale.root,
  bool compact = false,
  bool showSteps = true,
  bool showYAxis = true,
  String Function(int)? readout,
  Widget Function(int index)? readoutBuilder,
  String? note,
  Key plotKey = _plotKey,
  bool showXAxis = true,
}) => TimeSeriesChart(
  title: title,
  unit: unit,
  times: [for (var i = 0; i < values.length; i++) DateTime(2026, 10, 1 + i)],
  series: [
    ChartSeries(label: seriesLabel, values: values, style: style),
    if (reference != null)
      ChartSeries(
        label: referenceLabel,
        values: reference,
        style: ChartSeriesStyle.reference,
      ),
  ],
  semanticsLabel: '$title图表',
  selectedIndex: selectedIndex,
  onSelected: onSelected,
  readout: readout,
  readoutBuilder: readoutBuilder,
  readoutScale: scale,
  compactReadout: compact,
  showSteps: showSteps,
  showYAxis: showYAxis,
  showXAxis: showXAxis,
  note: note,
  plotKey: plotKey,
);

Future<void> pumpChart(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  double width = 360,
  double textScale = 1,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(420, 1200);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: mileafTheme(brightness),
      home: Scaffold(
        backgroundColor: _colors(brightness).canvas,
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

double _fontSize(WidgetTester tester, String text) =>
    (tester.widget<Text>(find.text(text)).style?.fontSize ?? 0).toDouble();

void main() {
  group('R29 完整读数头', () {
    testWidgets('读数头在绘图区之上，三行的顺序是日期→数值→参照与差值', (tester) async {
      await pumpChart(
        tester,
        chart(const [10, null, 30], reference: const [8, 5, null]),
      );
      final readout = tester.getRect(find.byType(MileafChartReadout));
      final plot = tester.getRect(find.byKey(_plotKey));
      expect(
        readout.bottom,
        lessThanOrEqualTo(plot.top),
        reason: 'R29：读数头在绘图区之上，拖动时不会被手指挡住',
      );
      final date = tester.getRect(find.text('10月1日'));
      final value = tester.getRect(find.text('10 km'));
      final context = tester.getRect(find.text('上月同期 8 km，多 2 km'));
      expect(date.top, lessThan(value.top));
      expect(value.top, lessThan(context.top));
      expect(date.bottom, lessThanOrEqualTo(plot.top));
    });

    testWidgets('根页数值用 metricMd、日期与上下文用 subheadline', (tester) async {
      final colors = _colors(Brightness.light);
      await pumpChart(tester, chart(const [10, 20], reference: const [8, 9]));
      expect(_fontSize(tester, '10 km'), MileafType.metricMdSize);
      expect(_fontSize(tester, '10月1日'), MileafType.subheadlineSize);
      expect(_fontSize(tester, '上月同期 8 km，多 2 km'), MileafType.subheadlineSize);
      final dateText = tester.widget<Text>(find.text('10月1日'));
      expect(dateText.style?.color, colors.textSecondary, reason: 'R23 两级文字');
    });

    testWidgets('详情与专题的读数头数值用 metricSm', (tester) async {
      await pumpChart(
        tester,
        chart(const [10, 20], scale: ChartReadoutScale.detail),
      );
      expect(_fontSize(tester, '10 km'), MileafType.metricSmSize);
    });

    testWidgets('缺值显示 —，真实 0 保留 0', (tester) async {
      await pumpChart(tester, chart(const [null, 0], selectedIndex: 0));
      expect(find.text('—'), findsOneWidget);
      await pumpChart(tester, chart(const [null, 0], selectedIndex: 1));
      expect(find.text('0 km'), findsOneWidget);
    });

    testWidgets('参照为 0 时写「多」，低于参照写「少」，句子里不用箭头', (tester) async {
      await pumpChart(tester, chart(const [6, 2], reference: const [0, 5]));
      expect(find.text('上月同期 0 km，多 6 km'), findsOneWidget);
      await pumpChart(
        tester,
        chart(const [6, 2], reference: const [0, 5], selectedIndex: 1),
      );
      expect(find.text('上月同期 5 km，少 3 km'), findsOneWidget);
      expect(find.textContaining('↑'), findsNothing);
      expect(find.textContaining('↓'), findsNothing);
    });

    testWidgets('负值用真负号（U+2212），不用 ASCII 连字符', (tester) async {
      await pumpChart(tester, chart(const [-12, 4], unit: 'kWh'));
      expect(find.text('\u221212 kWh'), findsOneWidget);
      expect(find.text('-12 kWh'), findsNothing);
    });

    testWidgets('切换选中点时读数头高度不变（有参照/无参照/缺值）', (tester) async {
      Future<double> heightAt(int index) async {
        await pumpChart(
          tester,
          chart(
            const [10, null, 30],
            reference: const [8, null, null],
            selectedIndex: index,
          ),
          width: 320,
          textScale: 2,
        );
        return tester.getSize(find.byType(MileafChartReadout)).height;
      }

      final withReference = await heightAt(0);
      final missing = await heightAt(1);
      final noReference = await heightAt(2);
      expect(missing, closeTo(withReference, .5), reason: '缺值不得让读数头变矮');
      expect(noReference, closeTo(withReference, .5), reason: '无参照不得跳高度');
    });
  });

  group('R29 步进', () {
    testWidgets('步进圆钮在读数头尾部，两端禁用、命中 ≥44', (tester) async {
      final semantics = tester.ensureSemantics();
      var selected = 0;
      await pumpChart(
        tester,
        chart(const [10, 20, 30], onSelected: (index) => selected = index),
      );
      final previous = find.bySemanticsLabel(MileafChartGrammar.previousStep);
      final next = find.bySemanticsLabel(MileafChartGrammar.nextStep);
      expect(previous, findsOneWidget);
      expect(next, findsOneWidget);
      expect(MileafChartGrammar.previousStep, '上一个数据点');
      expect(MileafChartGrammar.nextStep, '下一个数据点');
      expect(
        tester.getSize(next).width,
        greaterThanOrEqualTo(44),
        reason: 'R24/R27：圆钮命中 iOS 44',
      );
      final readout = tester.getRect(find.byType(MileafChartReadout));
      final nextRect = tester.getRect(next);
      expect(
        nextRect.center.dx,
        greaterThan(readout.center.dx),
        reason: 'R29：步进在读数头尾部',
      );
      expect(
        tester
            .getSemantics(next)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(find.text('10月2日'), findsOneWidget);
      expect(find.text('20 km'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('首点只有前进可用，末点只有后退可用', (tester) async {
      final semantics = tester.ensureSemantics();
      var selected = 0;
      await pumpChart(
        tester,
        chart(const [10, 20], onSelected: (index) => selected = index),
      );
      await tester.tap(
        find.bySemanticsLabel(MileafChartGrammar.previousStep),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(selected, 0, reason: '首点的上一个禁用');
      await tester.tap(find.bySemanticsLabel(MileafChartGrammar.nextStep));
      await tester.pumpAndSettle();
      expect(selected, 1);
      await tester.tap(
        find.bySemanticsLabel(MileafChartGrammar.nextStep),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(selected, 1, reason: '末点的下一个禁用');
      semantics.dispose();
    });

    testWidgets('默认选点不变：不传 selectedIndex 时取首点', (tester) async {
      await pumpChart(tester, chart(const [10, 20, 30]));
      expect(find.text('10月1日'), findsOneWidget);
      expect(find.text('10 km'), findsOneWidget);
    });

    testWidgets('程序恢复选点不触发触觉；索引变化时才触发一次', (tester) async {
      final events = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            events.add('${call.arguments}');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pumpChart(tester, chart(const [10, 20, 30, 40]));
      expect(events, isEmpty, reason: '首帧不触觉');
      await tester.tapAt(
        tester.getRect(find.byKey(_plotKey)).centerRight - const Offset(8, 0),
      );
      await tester.pumpAndSettle();
      expect(events, hasLength(1));
      expect(events.single, contains('selectionClick'));
      await tester.dragFrom(
        tester.getRect(find.byKey(_plotKey)).centerRight - const Offset(12, 0),
        const Offset(-2, 0),
      );
      await tester.pumpAndSettle();
      expect(events, hasLength(1), reason: '同一索引不重复播报');
      await pumpChart(tester, chart(const [10, 20, 30, 40], selectedIndex: 2));
      expect(events, hasLength(1), reason: '程序恢复选点不触发触觉');
    });
  });

  group('R29 朗读来源', () {
    testWidgets('readout 句子仍是唯一朗读源，可见读数由数据行组成', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpChart(
        tester,
        chart(const [10, 20], readout: (index) => '自定义读数 i$index'),
      );
      final node = tester.getSemantics(
        find.byKey(MileafChartGrammar.readoutLiveKey),
      );
      expect(node.getSemanticsData().label, '自定义读数 i0');
      expect(
        find.text('自定义读数 i0'),
        findsNothing,
        reason: 'R29：readout 只作朗读来源，可见读数来自数据行',
      );
      expect(find.text('10月1日'), findsOneWidget);
      expect(find.text('10 km'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('readoutBuilder 兼容：显示在读数头位置，朗读句仍来自 readout', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpChart(
        tester,
        chart(
          const [10, 20],
          readout: (index) => '朗读 i$index',
          readoutBuilder: (index) =>
              Text('自定义版式 $index', key: const ValueKey('ap05-builder')),
        ),
      );
      expect(find.text('自定义版式 0'), findsOneWidget);
      final builder = tester.getRect(
        find.byKey(const ValueKey('ap05-builder')),
      );
      final plot = tester.getRect(find.byKey(_plotKey));
      expect(
        builder.bottom,
        lessThanOrEqualTo(plot.top),
        reason: 'R29：读数头在绘图区之上',
      );
      final node = tester.getSemantics(
        find.byKey(MileafChartGrammar.readoutLiveKey),
      );
      expect(
        node.getSemanticsData().label,
        contains('朗读 i0'),
        reason: '朗读句仍由 readout 单一提供',
      );
      semantics.dispose();
    });
  });

  group('R29 紧凑读数行', () {
    testWidgets('一行内依次为日期、数值（body 600）与行尾步进', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpChart(tester, chart(const [10, 20], compact: true));
      final date = tester.getRect(find.text('10月1日'));
      final value = tester.getRect(find.text('10 km'));
      expect(date.left, lessThan(value.left));
      expect(date.center.dy, closeTo(value.center.dy, 1), reason: '同一行');
      final valueText = tester.widget<Text>(find.text('10 km'));
      expect(valueText.style?.fontSize, MileafType.bodySize);
      expect(valueText.style?.fontWeight, MileafType.weightSemiBold);
      final next = find.bySemanticsLabel(MileafChartGrammar.nextStep);
      expect(tester.getRect(next).center.dx, greaterThan(value.right - 1));
      expect(
        tester.getSize(find.byType(MileafChartReadout)).height,
        lessThan(64),
        reason: '88 高图只留一行读数',
      );
      semantics.dispose();
    });

    testWidgets('大字下紧凑行自然折行，不溢出', (tester) async {
      await pumpChart(
        tester,
        chart(const [10, 20], compact: true),
        width: 320,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('R29 坐标', () {
    testWidgets('Y 轴刻度画在绘图区右侧，左缘不再留刻度槽', (tester) async {
      final colors = _colors(Brightness.light);
      final boundary = GlobalKey();
      await pumpChart(
        tester,
        RepaintBoundary(
          key: boundary,
          child: chart(const [10, 20, 30], showYAxis: true),
        ),
        width: 320,
      );
      final origin = tester.getTopLeft(find.byType(TimeSeriesChart));
      final plot = tester.getRect(find.byKey(_plotKey)).shift(-origin);
      final probe = await capturePixels(tester, find.byKey(boundary));
      // 只看绘图区上部那一段：X 轴文字在盒子底部，不属于 Y 轴刻度。
      final columns = {
        for (final pixel in probe.find(
          colors.textSecondary,
          tolerance: 2,
          where: (x, y) => y >= plot.top + 2 && y < plot.top + 100,
        ))
          pixel.dx,
      };
      expect(columns, isNotEmpty, reason: 'Y 轴刻度确实绘制');
      expect(
        columns.reduce(math.max),
        greaterThan(plot.width * .9),
        reason: 'R29：刻度文字贴绘图区右缘',
      );
      expect(
        columns.length,
        greaterThan(8),
        reason: 'R29：右侧是一排刻度文字，而不是一条 1px 竖线',
      );
      expect(plot.left, lessThan(2), reason: 'R29：绘图区左缘与卡内文字起始线对齐，不在左侧留刻度槽');
    });

    testWidgets('X 轴刻度按 CP04 DF9：首刻度写月日，其余写日', (tester) async {
      final times = [
        DateTime(2026, 10, 1),
        DateTime(2026, 10, 2),
        DateTime(2026, 10, 3),
        DateTime(2026, 10, 4),
        DateTime(2026, 10, 5),
      ];
      expect(
        chartAxisTickLabels(
          times: times,
          indices: const [0, 2, 4],
          today: times.last,
        ),
        ['10月1日', '3日', '5日'],
      );
      final crossing = [
        DateTime(2026, 9, 29),
        DateTime(2026, 10, 3),
        DateTime(2026, 10, 8),
      ];
      expect(
        chartAxisTickLabels(
          times: crossing,
          indices: const [0, 1, 2],
          today: crossing.last,
        ),
        ['9月29日', '10月3日', '8日'],
        reason: '跨月时每月第一个刻度写月日',
      );
      expect(
        chartAxisTickLabels(
          times: [DateTime(2026, 1, 5)],
          indices: const [0],
          today: DateTime(2027, 1, 1),
        ),
        ['2026年1月5日'],
        reason: '非今年带年（DF1）',
      );
    });

    testWidgets('时间级与月级轴刻度按 DF9', (tester) async {
      final intraday = [
        DateTime(2026, 10, 1, 6, 10),
        DateTime(2026, 10, 1, 7, 40),
        DateTime(2026, 10, 1, 9, 10),
      ];
      expect(
        chartAxisTickLabels(
          times: intraday,
          indices: const [0, 1, 2],
          today: intraday.first,
        ),
        ['06:10', '07:40', '09:10'],
      );
      final monthly = [
        DateTime(2026, 5, 1),
        DateTime(2026, 6, 1),
        DateTime(2026, 7, 1),
      ];
      expect(
        chartAxisTickLabels(
          times: monthly,
          indices: const [0, 1, 2],
          today: monthly.last,
        ),
        ['5月', '6月', '7月'],
      );
    });
  });

  group('R29 标记与形状', () {
    testWidgets('柱只在数值端做圆角，基线端保持方角', (tester) async {
      final colors = _colors(Brightness.light);
      final boundary = GlobalKey();
      await pumpChart(
        tester,
        RepaintBoundary(
          key: boundary,
          child: chart(
            const [10, 12, 14],
            style: ChartSeriesStyle.bars,
            selectedIndex: 0,
          ),
        ),
        width: 320,
      );
      final probe = await capturePixels(tester, find.byKey(boundary));
      final bars = probe.columns(colors.accent);
      expect(bars, hasLength(3));
      final middle = bars[1];
      final bounds = probe.columnBounds(colors.accent, middle.from, middle.to)!;
      final topRow = probe.count(
        colors.accent,
        tolerance: 2,
        where: (x, y) => y == bounds.top.round(),
      );
      final middleRow = probe.count(
        colors.accent,
        tolerance: 2,
        where: (x, y) => y == bounds.center.dy.round(),
      );
      final bottomRow = probe.count(
        colors.accent,
        tolerance: 2,
        where: (x, y) => y == bounds.bottom.round() - 1,
      );
      expect(topRow, lessThan(middleRow), reason: 'R29：数值端有圆角，末行比中间窄');
      expect(
        bottomRow,
        greaterThanOrEqualTo(middleRow - 1),
        reason: 'R29：基线端不圆角',
      );
    });

    testWidgets('条形图的参照是每个时间槽一段短横刻度，不是连线', (tester) async {
      final colors = _colors(Brightness.light);
      final boundary = GlobalKey();
      await pumpChart(
        tester,
        RepaintBoundary(
          key: boundary,
          child: chart(
            const [10, 12, 14, 16],
            reference: const [8, 8, 8, 8],
            style: ChartSeriesStyle.bars,
            selectedIndex: 0,
            showYAxis: false,
            showXAxis: false,
          ),
        ),
        width: 320,
      );
      // 关掉两条轴后，图里只有柱（accent）、刻度（reference）与选中标记。
      const scale = 2.0;
      final probe = await capturePixels(
        tester,
        find.byKey(boundary),
        pixelRatio: scale,
      );
      final bars = probe.columns(colors.accent, tolerance: 3);
      expect(bars, hasLength(4), reason: '四个时间槽各一根柱');
      final half =
          (MileafChartMetrics.barMaxWidth +
              MileafChartGrammar.referenceTickBleed) /
          2;
      int referencePixelsNear(double center, double radius) => probe.count(
        colors.reference,
        tolerance: 5,
        where: (x, _) => (x - center).abs() <= radius * scale,
      );
      for (final bar in bars) {
        final center = (bar.from + bar.to) / 2;
        expect(
          referencePixelsNear(center, half),
          greaterThan(0),
          reason: 'R29：每个时间槽在参照值处有一段短横刻度',
        );
      }
      for (var i = 1; i < bars.length; i++) {
        final midpoint = ((bars[i - 1].to + bars[i].from) / 2);
        expect(
          referencePixelsNear(midpoint, 3),
          0,
          reason: 'R29：相邻日之间不连线，只在槽内画刻度',
        );
      }
    });

    testWidgets('折线图的参照仍是虚线', (tester) async {
      final colors = _colors(Brightness.light);
      final boundary = GlobalKey();
      await pumpChart(
        tester,
        RepaintBoundary(
          key: boundary,
          child: chart(
            const [10, 12, 14, 16],
            reference: const [8, 9, 10, 11],
            selectedIndex: 0,
          ),
        ),
        width: 320,
      );
      final probe = await capturePixels(tester, find.byKey(boundary));
      expect(
        probe.count(colors.reference, tolerance: 2),
        greaterThan(40),
        reason: '参照虚线仍在',
      );
      expect(
        probe.columns(colors.reference).length,
        greaterThan(4),
        reason: '折线参照是虚线段，不是每个槽一段刻度',
      );
    });

    testWidgets('选中标记是 1px 竖线 + 半径 4 的 accent 点，光晕取消', (tester) async {
      final colors = _colors(Brightness.light);
      final boundary = GlobalKey();
      await pumpChart(
        tester,
        RepaintBoundary(
          key: boundary,
          child: chart(
            const [12, 12, 12, 12],
            selectedIndex: 2,
            showYAxis: false,
            showXAxis: false,
          ),
        ),
        width: 320,
      );
      // 两条轴都关掉：图里只有数据线、选中竖线与选中点，没有别的文字。
      const scale = 2.0;
      final probe = await capturePixels(
        tester,
        find.byKey(boundary),
        pixelRatio: scale,
      );
      final origin = tester.getTopLeft(find.byType(TimeSeriesChart));
      final plot = tester.getRect(find.byKey(_plotKey)).shift(-origin);
      // 只看绘图区内部：读数头在绘图区之上，不属于标记。
      bool inside(int x, int y) =>
          y >= (plot.top + 6) * scale && y < (plot.top + 90) * scale;
      final line = [
        for (final column in probe.columns(colors.textSecondary, tolerance: 4))
          if (probe.count(
                colors.textSecondary,
                tolerance: 4,
                where: (x, y) =>
                    x >= column.from && x <= column.to && inside(x, y),
              ) >=
              20)
            column,
      ];
      expect(line, hasLength(1), reason: 'R29：只画一条选中竖线');
      final lineWidth = (line.single.to - line.single.from + 1) / scale;
      expect(
        lineWidth,
        lessThanOrEqualTo(MileafChartGrammar.selectionLine + 1),
        reason: 'R29：1 逻辑像素竖线',
      );
      final lineBounds = probe.columnBounds(
        colors.textSecondary,
        line.single.from,
        line.single.to,
      )!;
      expect(lineBounds.height / scale, greaterThan(80), reason: 'R29：竖线贯穿绘图区');
      final dot = probe.bounds(
        colors.accent,
        tolerance: 4,
        where: (x, _) => (x - lineBounds.center.dx).abs() <= 10 * scale,
      );
      expect(dot, isNotNull);
      final dotHeight = (dot!.height + 1) / scale;
      expect(
        dotHeight,
        closeTo(MileafChartGrammar.selectionDot * 2, 2),
        reason: 'R29：半径 4 的 accent 点（直径 8）',
      );
      expect(dotHeight, lessThan(12), reason: 'R29：取消光晕（旧光晕直径 16）');
    });

    testWidgets('图例在 X 轴之下，指标控件点名后只列参照', (tester) async {
      await pumpChart(
        tester,
        TimeSeriesChart(
          title: '趋势',
          unit: 'km',
          times: [
            DateTime(2026, 10, 1),
            DateTime(2026, 10, 2),
            DateTime(2026, 10, 3),
          ],
          series: const [
            ChartSeries(label: '本期', values: [10, 12, 14]),
            ChartSeries(
              label: '上月同期',
              values: [8, 9, 10],
              style: ChartSeriesStyle.reference,
            ),
          ],
          semanticsLabel: '趋势图表',
          controls: const Text('指标'),
          showYAxis: false,
          plotKey: _plotKey,
        ),
      );
      final legend = tester.getRect(find.text('上月同期'));
      final plot = tester.getRect(find.byKey(_plotKey));
      expect(
        legend.top,
        greaterThanOrEqualTo(plot.bottom),
        reason: 'R29：图例位于 X 轴之下',
      );
      expect(find.text('本期'), findsNothing, reason: 'R29：图例只列参照');
    });
  });

  group('R29 无数据与提示', () {
    testWidgets('无数据时卡内一句说明，绘图区收起', (tester) async {
      await pumpChart(
        tester,
        const TimeSeriesChart(
          title: '每日里程',
          unit: 'km',
          times: [],
          series: [ChartSeries(label: '里程', values: [])],
          semanticsLabel: '每日里程图表',
          emptyMessage: '这段时间没有行程',
        ),
      );
      expect(find.text('这段时间没有行程'), findsOneWidget);
      expect(find.byType(MileafChartReadout), findsNothing);
      expect(find.byKey(_plotKey), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('图表给出 CP11 语义提示，不再出现「点按读值」类提示', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpChart(tester, chart(const [10, 20]));
      final node = tester.getSemantics(find.bySemanticsLabel('每日里程图表'));
      expect(
        node.getSemanticsData().hint,
        MileafChartGrammar.hint,
        reason: 'CP11：图表语义提示',
      );
      expect(MileafChartGrammar.hint, '拖动或轻点查看每天的值；可用调整手势切换日期');
      semantics.dispose();
    });
  });

  group('M07/M09 动效', () {
    testWidgets('切换指标或期间时读数头与图 120ms 淡入', (tester) async {
      await pumpChart(tester, chart(const [10, 20], title: '每日里程'));
      final fade = find.byKey(_fadeKey);
      expect(fade, findsOneWidget);
      expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
      await pumpChart(
        tester,
        chart(const [10, 20], title: '每日补能', unit: 'kWh'),
        settle: false,
      );
      expect(
        tester.widget<FadeTransition>(fade).opacity.value,
        lessThan(1),
        reason: '身份变化从 0 淡入',
      );
      await tester.pump(MileafDurations.metricFade);
      expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    });

    testWidgets('拖动选点不淡入（读数直接跟随）', (tester) async {
      await pumpChart(tester, chart(const [10, 20, 30, 40]));
      await tester.drag(find.byKey(_plotKey), const Offset(-60, 0));
      await tester.pump();
      expect(
        tester.widget<FadeTransition>(find.byKey(_fadeKey)).opacity.value,
        1,
        reason: 'M09：拖动选点时不淡入',
      );
    });

    testWidgets('减少动效下不淡入、首帧即完整', (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        () => tester.binding.platformDispatcher
            .clearAccessibilityFeaturesTestValue(),
      );
      await pumpChart(tester, chart(const [10, 20], title: '每日里程'));
      expect(
        tester.widget<FadeTransition>(find.byKey(_fadeKey)).opacity.value,
        1,
      );
      await pumpChart(
        tester,
        chart(const [10, 20], title: '每日补能', unit: 'kWh'),
        settle: false,
      );
      expect(
        tester.widget<FadeTransition>(find.byKey(_fadeKey)).opacity.value,
        1,
        reason: 'M09 减少动效时长 0：首帧即完整读数',
      );
    });
  });

  group('BatteryArc 环内只放数值', () {
    testWidgets('圆心只有数值（含单位），标签移到环外', (tester) async {
      await pumpChart(tester, const BatteryArc(level: 82));
      final value = tester.widget<Text>(find.text('82'));
      expect(
        (value.style?.fontSize ?? 0),
        MileafBatteryMetrics.valueSize,
        reason: '环内是数值本身（CP03：% 紧贴）',
      );
      expect(find.text('%'), findsOneWidget, reason: '单位仍与数值同处圆心');
      final label = tester.getRect(find.text('电量'));
      final arc = tester.getRect(
        find
            .descendant(
              of: find.byType(BatteryArc),
              matching: find.byType(CustomPaint),
            )
            .first,
      );
      expect(
        label.top,
        greaterThanOrEqualTo(arc.bottom - 1),
        reason: 'R29：标签不再挤在环内',
      );
      expect(arc.width, MileafBatteryMetrics.size);
    });

    testWidgets('大字下标签不再占环内一行，数值仍可见且圆心不溢出', (tester) async {
      await pumpChart(tester, const BatteryArc(level: 68), textScale: 2);
      expect(tester.takeException(), isNull, reason: 'D8：200% 下圆心不得溢出');
      expect(find.text('电量'), findsNothing, reason: '大字下标签不出');
      expect(find.text('68'), findsOneWidget, reason: '数值仍在');
      // 单位只有「与数值同行」或「落到下一行」两种去处，且至多一个。
      expect(
        find.text('%').evaluate().length,
        lessThanOrEqualTo(1),
        reason: '单位至多一处（同行或下一行）',
      );
    });
  });

  group('R32 工程约束', () {
    test('本票源文件不再使用 Material Icons', () {
      const files = [
        'lib/src/design/components/charts.dart',
        'lib/src/design/components/category_bars.dart',
        'lib/src/design/components/composition_bar.dart',
        'lib/src/design/components/battery_arc.dart',
        'lib/src/design/components/share_ring.dart',
        'lib/src/sample_chart.dart',
      ];
      for (final file in files) {
        final source = File(file).readAsStringSync();
        expect(
          source.contains('Icons.'),
          isFalse,
          reason: '$file 仍有 Material Icons',
        );
      }
    });

    test('图表源文件不再出现「点按读值」类提示', () {
      for (final file in [
        'lib/src/design/components/charts.dart',
        'lib/src/sample_chart.dart',
      ]) {
        final source = File(file).readAsStringSync();
        expect(source.contains('点按读值'), isFalse);
        expect(source.contains('点按图形读值'), isFalse);
      }
    });
  });
}
