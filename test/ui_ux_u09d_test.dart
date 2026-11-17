import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/workspace.dart';

import 'statistics_range_test.dart' show rangeResponse;
import 'statistics_test.dart' show openStats, fixture;
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/statistics_insights_fixture.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

/// U09d 专属回归：旧测试未覆盖的图例与轴范围注记、单月/中间缺月/全缺失、
/// 长数值轴留白、200%与前后按钮实际触控、键盘左右与语义增减、宽屏限宽。
/// 渲染矩阵沿交付手册 §4，输出独占 gallery/u09d-*。

http.Client rangeClient(List<Uri> seen, {String scenario = 'normal'}) {
  return MockClient((request) async {
    if (request.url.path.endsWith('/vehicles')) return fixture('vehicles');
    if (request.url.path.endsWith('/summary')) return fixture('summary');
    if (request.url.path.endsWith('/meta')) {
      return http.Response(
        jsonEncode(
          statisticsInsightsMeta(
            features: {'driving_coverage': true, 'range_observations': true},
          ),
        ),
        200,
      );
    }
    if (request.url.path.endsWith('/range-observations')) {
      seen.add(request.url);
      if (scenario == 'error') {
        return http.Response('{}', 503);
      }
      final months = int.parse(request.url.queryParameters['months']!);
      return http.Response(
        jsonEncode(rangeScenario(scenario, months)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response(
      jsonEncode(statisticsInsightsFixture(request.url)),
      200,
    );
  });
}

Map<String, dynamic> rangeScenario(String scenario, int months) {
  final body = rangeResponse(months: months);
  switch (scenario) {
    case 'empty':
      // 观察窗口内无充电记录。
      return rangeResponse(months: months, empty: true);
    case 'single':
      // 单月窗口：仅一个可用月，前一个月不可用。
      (body['buckets'] as List).removeRange(1, 6);
    case 'midmissing':
      // 中间缺月：破线留槽，不补线不补值。
      final buckets = body['buckets'] as List;
      final missing = buckets[2] as Map;
      missing['status'] = 'no_records';
      missing['sample_status'] = 'insufficient_data';
      missing['median_range_km'] = null;
      missing['p10_range_km'] = null;
      missing['p90_range_km'] = null;
      missing['coverage'] = {
        ...(missing['coverage'] as Map),
        'valid_days': 0,
        'valid_sessions': 0,
        'valid_points': 0,
      };
    case 'allmissing':
      // 全缺失：服务端声明样本不足，不推算额定续航。
      body['totals'] = {
        ...(body['totals'] as Map<String, dynamic>),
        'status': 'insufficient_data',
      };
      for (final bucket in body['buckets'] as List) {
        (bucket as Map)
          ..['median_range_km'] = null
          ..['p10_range_km'] = null
          ..['p90_range_km'] = null
          ..['sample_status'] = 'insufficient_data';
      }
    case 'long':
      // 长数值：轴刻度与留白按实际文字度量，注记完整。
      final buckets = body['buckets'] as List;
      for (var i = 0; i < buckets.length; i++) {
        (buckets[i] as Map)
          ..['median_range_km'] = 12345.6 + i
          ..['p10_range_km'] = 12300.0
          ..['p90_range_km'] = 12400.0;
      }
  }
  return body;
}

Future<void> openU09d(WidgetTester tester, http.Client client) async {
  await openStats(
    tester,
    client,
    () => DateTime.utc(2026, 10, 28, 11),
    () => 'Asia/Shanghai',
    statisticsInsights: true,
  );
  await tester.scrollUntilVisible(
    find.text('长期').hitTestable(),
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('长期').hitTestable());
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('展开长期续航').hitTestable(),
    100,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('展开长期续航').hitTestable());
  await tester.pumpAndSettle();
}

Semantics? plotSemantics(WidgetTester tester, Finder finder) =>
    tester.widgetList<Semantics>(finder).whereType<Semantics>().firstOrNull;

/// R27/CP06：读数头步进圆钮（语义「上一个数据点」「下一个数据点」）。
Finder stepButton(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.button == true &&
      widget.properties.label == label,
);

Finder trendPlot() => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      (widget.properties.label?.startsWith('月续航走势图表') ?? false),
);

void main() {
  testWidgets('趋势带与中位数折线有明确图例，非零起点标注轴范围', (tester) async {
    await openU09d(tester, rangeClient([]));
    expect(find.text('月中位数'), findsWidgets);
    expect(find.text('日常波动范围（P10–P90）'), findsOneWidget);
    expect(find.textContaining('纵轴从 410 km 起'), findsOneWidget);
    expect(find.text('独立本地月窗口，逐月估算额定续航'), findsOneWidget);
    expect(find.byKey(const Key('range-observation-chart')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('中间缺月破线留槽，选中缺失月读值为缺失并说明', (tester) async {
    await openU09d(tester, rangeClient([], scenario: 'midmissing'));
    for (var i = 0; i < 3; i++) {
      final prev = stepButton(MileafChartGrammar.previousStep);
      await tester.scrollUntilVisible(prev.hitTestable(), 100);
      await tester.tap(prev);
      await tester.pumpAndSettle();
    }
    // 缺失月不补零：结论卡给缺失口径，记录与缺失说明逐月给「有效天数 0 天」。
    expect(find.text('暂无有效月样本'), findsOneWidget);
    final notes = find.widgetWithText(MileafDisclosure, '记录与缺失');
    await tester.ensureVisible(notes.last);
    await tester.pumpAndSettle();
    await tester.tap(notes.last);
    await tester.pumpAndSettle();
    expect(find.textContaining('有效天数 0 天'), findsOneWidget);
    expect(find.text('日常波动范围（P10–P90）'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('单月窗口正常呈现且前一个月不可用', (tester) async {
    await openU09d(tester, rangeClient([], scenario: 'single'));
    expect(find.textContaining('440.0 km'), findsWidgets);
    // 只有一个月时读数头不渲染步进圆钮。
    expect(
      stepButton(MileafChartGrammar.previousStep),
      findsNothing,
      reason: '只有一个月时无上一步进',
    );
    expect(
      stepButton(MileafChartGrammar.nextStep),
      findsNothing,
      reason: '只有一个月时无下一步进',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('全缺失不推算额定续航并保留能力说明', (tester) async {
    await openU09d(tester, rangeClient([], scenario: 'allmissing'));
    expect(find.text('尚无有效续航样本'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('长数值轴注记完整且无溢出', (tester) async {
    await openU09d(tester, rangeClient([], scenario: 'long'));
    expect(find.textContaining('纵轴从 12290 km 起'), findsOneWidget);
    expect(find.textContaining('12350.6 km'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('200%下月份前后按钮实际触控至少44', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openU09d(tester, rangeClient([]));
    for (final label in [
      MileafChartGrammar.previousStep,
      MileafChartGrammar.nextStep,
    ]) {
      final rect = tester.getRect(stepButton(label));
      expect(rect.width, greaterThanOrEqualTo(44), reason: label);
      expect(rect.height, greaterThanOrEqualTo(44), reason: label);
    }
    // 提示词四：200%下步进圆钮除尺寸外还需真实点按可达，读值随之变化。
    final prev = stepButton(MileafChartGrammar.previousStep);
    await tester.scrollUntilVisible(prev.hitTestable(), 100);
    await tester.tap(prev);
    await tester.pumpAndSettle();
    expect(find.textContaining('440.0 km'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('趋势图支持键盘左右与语义增减', (tester) async {
    await openU09d(tester, rangeClient([]));
    final plot = trendPlot();
    final semanticsHandle = tester.ensureSemantics();
    final semantics = plotSemantics(tester, plot)!;
    // 默认选中最后一月（10月）：只能减，不能加。
    expect(semantics.properties.onDecrease, isNotNull);
    final focusNode = Focus.of(
      tester.element(
        find.descendant(of: plot, matching: find.byType(CustomPaint)),
      ),
    );
    for (var i = 0; !focusNode.hasFocus && i < 24; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focusNode.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    // 6个月窗口默认选最后一月（10月，未结束）；左移到9月完整月。
    expect(find.text('9月'), findsOneWidget);
    expect(
      plotSemantics(tester, trendPlot())!.properties.onIncrease,
      isNotNull,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('10月（本月未结束）'), findsOneWidget);
    semanticsHandle.dispose();
  });

  testWidgets('宽屏专题主体限宽并与标题共享左线', (tester) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openU09d(tester, rangeClient([]));
    final chart = find.byKey(const Key('range-observation-chart'));
    expect(tester.getSize(chart).width, lessThanOrEqualTo(560));
    final header = find.text('满电额定续航（估算）');
    final card = find
        .ancestor(of: chart, matching: find.byType(MileafModuleCard))
        .first;
    // R24：卡片外缘与身份块标题共享左线；卡内内容由卡内边对齐。
    expect(tester.getRect(card).left, closeTo(tester.getRect(header).left, 1));
    expect(tester.takeException(), isNull);
  });

  const output = String.fromEnvironment('MILEAF_U09D_RENDER_OUTPUT');
  const font = String.fromEnvironment('MILEAF_RENDER_FONT');
  testWidgets('U09d 正式Flutter长期续航矩阵及完整滚动', (tester) async {
    await loadRenderFonts(cjkFontPath: font);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final files = <String>[];
    final measurements = <Map<String, Object?>>[];
    final cases = <(Size, double, String, bool)>[
      for (final dark in [false, true]) ...[
        for (final scenario in ['normal', 'midmissing', 'empty'])
          for (final scale in [1.0, 2.0])
            (const Size(360, 800), scale, scenario, dark),
        for (final scale in [1.3, 1.5])
          (const Size(360, 800), scale, 'normal', dark),
        (const Size(320, 568), 2, 'normal', dark),
        (const Size(390, 844), 1, 'normal', dark),
        (const Size(768, 1024), 2, 'normal', dark),
        for (final scenario in ['error', 'allmissing', 'long', 'single'])
          (const Size(360, 800), 1, scenario, dark),
      ],
    ];
    for (final (size, scale, scenario, dark) in cases) {
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      final boundary = GlobalKey();
      final name =
          'u09d-range-$scenario-${dark ? 'dark' : 'light'}-${size.width.toInt()}-${(scale * 100).round()}';
      final appearance = AppearanceController(
        _Appearance(dark ? 'dark' : 'light'),
      );
      await appearance.restore();
      final store = MemorySessionStore()
        ..value = jsonEncode({
          'site': 'https://example.com/prefix',
          'token': 'test',
          'expires_at': '2099-01-01T00:00:00Z',
        });
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MileafApp(
            key: ValueKey(name),
            client: rangeClient([], scenario: scenario),
            sessionStore: store,
            trustStore: MemoryTrustStore(),
            vehiclePreferences: MemoryVehiclePreferences(),
            appearance: appearance,
            now: () => DateTime.utc(2026, 10, 28, 11),
            calendar: () async => CalendarContext('Asia/Shanghai'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('统计').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('长期').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('长期').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('展开长期续航').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('展开长期续航').first);
      await tester.pumpAndSettle();
      Future<void> save(String camera) async {
        final path = '$output/gallery/$name-$camera.png';
        void repaint(RenderObject object) {
          object.markNeedsPaint();
          object.visitChildren(repaint);
        }

        repaint(tester.renderObject(find.byKey(boundary)));
        await tester.pump();
        await saveRenderPng(tester, find.byKey(boundary), path);
        files.add(path);
      }

      await save('top');
      final scroll = find.byType(Scrollable).last;
      if (scenario == 'normal' && size.width == 360 && scale == 1) {
        final plot = tester.getRect(
          find.byKey(const Key('range-observation-chart')),
        );
        final bodyTop = tester
            .getRect(find.byType(MileafNavigationRow).last)
            .bottom;
        final visible =
            math.min(plot.bottom, size.height - 24) -
            math.max(plot.top, bodyTop);
        // 规格§5 五专题首屏目标：主结果与必要限定之后，主图可见至少120高。
        expect(visible, greaterThanOrEqualTo(120));
        measurements.add({
          'name': name,
          'bodyTop': bodyTop,
          'plotTopInBody': plot.top - bodyTop,
          'plotVisible': visible,
        });
        expect(plot.width, lessThanOrEqualTo(560));
        var step = 0;
        while (tester.state<ScrollableState>(scroll).position.extentAfter > 0 &&
            step < 60) {
          await tester.drag(scroll, Offset(0, -size.height * .65));
          await tester.pumpAndSettle();
          step++;
          await save('scroll$step');
        }
        await save('bottom');
        // 步进动作可达：滚到读值区点击后返回末月。
        final prev = stepButton(MileafChartGrammar.previousStep);
        await tester.scrollUntilVisible(prev.hitTestable(), -150);
        await tester.tap(prev);
        await tester.pumpAndSettle();
        expect(find.textContaining('440.0 km'), findsOneWidget);
      }
      if (scenario == 'normal' ||
          scenario == 'midmissing' ||
          scenario == 'long') {
        final notes = find.widgetWithText(MileafDisclosure, '技术详情');
        await tester.ensureVisible(notes.last);
        await tester.tap(notes.last);
        await tester.pumpAndSettle();
        final state = tester.state<ScrollableState>(
          find.byType(Scrollable).last,
        );
        state.position.jumpTo(state.position.maxScrollExtent);
        await tester.pumpAndSettle();
        await save('notes');
      }
    }
    await tester.runAsync(() async {
      await File('$output/gallery/u09d-manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ')
            .convert({'files': files, 'measurements': measurements}),
      );
    });
  }, skip: output.isEmpty || font.isEmpty);
}

class _Appearance implements AppearancePreferenceStore {
  _Appearance(this.value);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? value) async => this.value = value;
}
