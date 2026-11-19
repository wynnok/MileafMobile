import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/tokens.dart';

/// MC04b：五个图形组件的可选 `MileafHue? hue`。
///
/// 两组断言：缺省（hue 为 null）时取色与改造前逐值一致；给了色相时数据图形
/// 取该色相的档位（CL01/CL02），而轨道 / 刻度 / 文字这些次级元素不动。
const light = MileafColors.light();
const dark = MileafColors.dark();

Future<void> pumpComponent(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: mileafTheme(brightness),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    ),
  );
  await tester.pump();
}

dynamic _painterOf(WidgetTester tester, Type type) {
  final paint = tester.widget<CustomPaint>(
    find
        .descendant(of: find.byType(type), matching: find.byType(CustomPaint))
        .first,
  );
  return paint.painter;
}

/// BatteryArc 的弧前景与轨道（画笔的两个取色字段）。
(Color, Color) _arcColors(WidgetTester tester) {
  final painter = _painterOf(tester, BatteryArc);
  return (painter.arc as Color, painter.track as Color);
}

/// ShareRing 的分段色，按段序。
List<Color> _ringColors(WidgetTester tester) {
  final painter = _painterOf(tester, MileafShareRing);
  return List<Color>.from(painter.colors as List<Color>);
}

/// 所有装饰盒的底色，按树的先后顺序（轨道在前、填充在后）。
List<Color> _decorationColors(WidgetTester tester, Type type) => [
  for (final box in tester.widgetList<DecoratedBox>(
    find.descendant(of: find.byType(type), matching: find.byType(DecoratedBox)),
  ))
    (box.decoration as BoxDecoration).color!,
];

void main() {
  group('BatteryArc.hue', () {
    testWidgets('hue 缺省：弧取 accent、轨道仍 accent × trackOpacity', (tester) async {
      await pumpComponent(tester, const BatteryArc(level: 68));
      final (arc, track) = _arcColors(tester);
      expect(arc, light.accent);
      expect(
        track,
        light.accent.withValues(alpha: MileafBatteryMetrics.trackOpacity),
      );
    });

    testWidgets('hue 缺省且 onHero：弧取 accentHero', (tester) async {
      await pumpComponent(tester, const BatteryArc(level: 68, onHero: true));
      expect(_arcColors(tester).$1, light.accentHero);
    });

    testWidgets('hue = energy：弧取 hue.solid，轨道不变', (tester) async {
      await pumpComponent(
        tester,
        const BatteryArc(level: 68, hue: MileafHue.aqua),
      );
      final (arc, track) = _arcColors(tester);
      expect(arc, MileafHue.aqua.solid(light));
      expect(arc, MileafHueRamp.aquaSolidLight);
      expect(
        track,
        light.accent.withValues(alpha: MileafBatteryMetrics.trackOpacity),
        reason: '轨道是次级元素，不跟随色相',
      );
    });

    testWidgets('hue 在深色取深色档', (tester) async {
      await pumpComponent(
        tester,
        const BatteryArc(level: 68, hue: MileafHue.aqua),
        brightness: Brightness.dark,
      );
      expect(_arcColors(tester).$1, MileafHueRamp.aquaDark);
    });
  });

  group('MileafShareRing.hue', () {
    const segments = [
      ShareRingSegment(label: 'AC', value: 70, color: Color(0xFF74DDA8)),
      ShareRingSegment(label: 'DC', value: 20, color: Color(0xFF3A7F63)),
      ShareRingSegment(label: '未知', value: 10, color: Color(0xFF9AA5B1)),
    ];

    testWidgets('hue 缺省：逐段沿用调用方的颜色', (tester) async {
      await pumpComponent(
        tester,
        const MileafShareRing(
          segments: segments,
          centerValue: '70',
          centerLabel: 'AC',
        ),
      );
      expect(_ringColors(tester), [
        for (final segment in segments) segment.color,
      ]);
    });

    testWidgets('hue = energy：主段 solid、次段 strong、未知段中性', (tester) async {
      await pumpComponent(
        tester,
        const MileafShareRing(
          segments: segments,
          centerValue: '70',
          centerLabel: 'AC',
          hue: MileafHue.aqua,
        ),
      );
      expect(_ringColors(tester), [
        MileafHue.aqua.solid(light),
        MileafHue.aqua.strong(light),
        segments[2].color,
      ]);
      expect(MileafHue.aqua.strong(light), MileafHueRamp.aquaStrongLight);
    });

    testWidgets('hue 在深色只有一档（solid = strong）', (tester) async {
      await pumpComponent(
        tester,
        const MileafShareRing(
          segments: segments,
          centerValue: '70',
          hue: MileafHue.aqua,
        ),
        brightness: Brightness.dark,
      );
      expect(_ringColors(tester), [
        MileafHueRamp.aquaDark,
        MileafHueRamp.aquaDark,
        segments[2].color,
      ]);
    });
  });

  group('MileafCategoryBars.hue', () {
    const values = [('AC', 12.0), ('DC', 8.0), ('未知', 1.0)];

    testWidgets('hue 缺省：三档沿用 series token', (tester) async {
      await pumpComponent(tester, const MileafCategoryBars(values: values));
      expect(_decorationColors(tester, MileafCategoryBars), [
        light.line,
        light.seriesPrimary,
        light.line,
        light.seriesSecondary,
        light.line,
        light.seriesNeutral,
      ]);
    });

    testWidgets('hue = energy：柱取 hue.solid 与 hue.strong，未知仍中性', (tester) async {
      await pumpComponent(
        tester,
        const MileafCategoryBars(values: values, hue: MileafHue.aqua),
      );
      expect(_decorationColors(tester, MileafCategoryBars), [
        light.line,
        MileafHue.aqua.solid(light),
        light.line,
        MileafHue.aqua.strong(light),
        light.line,
        light.seriesNeutral,
      ]);
    });

    testWidgets('hue = journey（azure）与缺省取色一致', (tester) async {
      await pumpComponent(
        tester,
        const MileafCategoryBars(values: values, hue: MileafHue.azure),
      );
      expect(_decorationColors(tester, MileafCategoryBars), [
        light.line,
        light.seriesPrimary,
        light.line,
        light.seriesSecondary,
        light.line,
        light.seriesNeutral,
      ]);
    });
  });

  group('MileafCompositionBar.hue', () {
    const segments = [('AC', 70.0), ('DC', 20.0), ('未知', 10.0)];

    List<Color> colors(WidgetTester tester) => [
      for (final box in tester.widgetList<ColoredBox>(
        find.descendant(
          of: find.byType(MileafCompositionBar),
          matching: find.byType(ColoredBox),
        ),
      ))
        box.color,
    ];

    testWidgets('hue 缺省：主段 seriesPrimary、次段 seriesSecondary', (tester) async {
      await pumpComponent(
        tester,
        const MileafCompositionBar(segments: segments),
      );
      expect(colors(tester), [
        light.seriesPrimary,
        light.seriesSecondary,
        light.seriesNeutral,
      ]);
    });

    testWidgets('hue = energy：主段 solid、次段 strong', (tester) async {
      await pumpComponent(
        tester,
        const MileafCompositionBar(segments: segments, hue: MileafHue.aqua),
      );
      expect(colors(tester), [
        MileafHue.aqua.solid(light),
        MileafHue.aqua.strong(light),
        light.seriesNeutral,
      ]);
    });

    testWidgets('hue 在深色取深色档', (tester) async {
      await pumpComponent(
        tester,
        const MileafCompositionBar(segments: segments, hue: MileafHue.aqua),
        brightness: Brightness.dark,
      );
      expect(colors(tester), [
        MileafHueRamp.aquaDark,
        MileafHueRamp.aquaDark,
        dark.seriesNeutral,
      ]);
    });
  });

  group('SocIntervalBar.hue', () {
    testWidgets('hue 缺省：区间带取 accent、轨道仍 lineStrong', (tester) async {
      await pumpComponent(tester, const SocIntervalBar(start: 18, end: 82));
      final colors = _decorationColors(tester, SocIntervalBar);
      expect(colors, [light.lineStrong, light.accent]);
    });

    testWidgets('hue = energy：区间带取 hue.solid，轨道与透明度不变', (tester) async {
      await pumpComponent(
        tester,
        const SocIntervalBar(start: 18, end: 82, hue: MileafHue.aqua),
      );
      final colors = _decorationColors(tester, SocIntervalBar);
      expect(colors, [light.lineStrong, MileafHue.aqua.solid(light)]);
      expect(colors.last.a, 1.0, reason: '区间带填充不透明度保持现状');
    });

    testWidgets('hue 在深色取深色档', (tester) async {
      await pumpComponent(
        tester,
        const SocIntervalBar(start: 18, end: 82, hue: MileafHue.aqua),
        brightness: Brightness.dark,
      );
      expect(_decorationColors(tester, SocIntervalBar), [
        dark.lineStrong,
        MileafHueRamp.aquaDark,
      ]);
    });
  });
}
