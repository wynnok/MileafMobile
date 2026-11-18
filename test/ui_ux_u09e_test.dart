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
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/workspace.dart';

import 'statistics_parking_test.dart' show openParking, parkingResponse;
import 'statistics_test.dart' show fixture;
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/statistics_insights_fixture.dart';
import 'support/vehicle_preferences.dart';
import 'support/test_trust_store.dart' show MemoryTrustStore;

/// U09e 专属回归：旧测试未覆盖的正/负/0分桶、中间缺失不补零、离线/未知
/// 状态编码、窄片段真实比例、200%读值实际触控、键盘左右与语义增减、宽屏
/// 限宽。渲染矩阵沿交付手册 §4，输出独占 gallery/u09e-*。

/// 窄片段与局部缺失状态占比：分母严格为有效窗口观测小时（100h），
/// 离线 0.1h 为窄片段，未知 share 缺失时不伪造全日状态。
Map<String, dynamic> fragmentTotals({bool unknownMissing = false}) => {
  'candidate_windows': 6,
  'valid_windows': 4,
  'excluded_windows': 1,
  'open_windows': 1,
  'observed_hours': 100,
  'soc_change_pp': 3,
  'soc_change_pp_per_24h': 6,
  'online_hours': 50,
  'asleep_hours': 30,
  'offline_hours': .1,
  // 契约里 hours 非空、share 可空：缺失只发生在 share。
  'unknown_hours': 19.9,
  'online_share': .5,
  'asleep_share': .3,
  'offline_share': .001,
  'unknown_share': unknownMissing ? null : .199,
  'excluded_by_reason': {'missing_soc': 1},
};

Map<String, dynamic> parkingScenario(String scenario, Uri uri) {
  final body = parkingResponse(uri);
  switch (scenario) {
    case 'empty':
      return parkingResponse(uri, empty: true);
    case 'missing':
      // 中间分桶缺失：留槽不补零，读值给缺失口径。
      (body['buckets'] as List)[1]['soc_change_pp'] = null;
      (body['buckets'] as List)[1]['soc_change_pp_per_24h'] = null;
    case 'allnull':
      // 全部分桶缺失：说明行可见，图区不画零。
      for (final bucket in body['buckets'] as List) {
        (bucket as Map)
          ..['soc_change_pp'] = null
          ..['soc_change_pp_per_24h'] = null;
      }
    case 'fragments':
      // 窄片段真实比例 + 未知 share 缺失。
      body['totals'] = fragmentTotals(unknownMissing: true);
      for (final bucket in body['buckets'] as List) {
        (bucket as Map).addAll(fragmentTotals(unknownMissing: true));
      }
    case 'zeros':
      // 全零分桶：真实停放零变化，量程下限保护，零柱画在基线。
      body['totals'] = {
        ...(body['totals'] as Map<String, dynamic>),
        'soc_change_pp': 0,
        'soc_change_pp_per_24h': 0,
      };
      for (final bucket in body['buckets'] as List) {
        (bucket as Map)
          ..['soc_change_pp'] = 0
          ..['soc_change_pp_per_24h'] = 0;
      }
    case 'error':
      return body;
  }
  return body;
}

http.Client parkingClient(List<Uri> seen, {String scenario = 'normal'}) {
  return MockClient((request) async {
    if (request.url.path.endsWith('/vehicles')) return fixture('vehicles');
    if (request.url.path.endsWith('/summary')) return fixture('summary');
    if (request.url.path.endsWith('/meta')) {
      return http.Response(
        jsonEncode(
          statisticsInsightsMeta(
            features: {'driving_coverage': true, 'parking_observations': true},
          ),
        ),
        200,
      );
    }
    if (request.url.path.endsWith('/parking-observations')) {
      seen.add(request.url);
      if (scenario == 'error') return http.Response('{}', 503);
      return http.Response(
        jsonEncode(parkingScenario(scenario, request.url)),
        200,
      );
    }
    return http.Response(
      jsonEncode(statisticsInsightsFixture(request.url)),
      200,
    );
  });
}

Finder trendPlot() => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      (widget.properties.label?.startsWith('每段停车电量变化正负柱图') ?? false),
);

/// R27/CP06：读数头步进圆钮（语义「上一个数据点」「下一个数据点」）。
Finder stepButton(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.button == true &&
      widget.properties.label == label,
);

/// WCAG 对比度；睡眠/离线的中性实色按最终画布合成验证。
double contrastRatio(Color a, Color b) {
  final l1 = math.max(a.computeLuminance(), b.computeLuminance());
  final l2 = math.min(a.computeLuminance(), b.computeLuminance());
  return (l1 + .05) / (l2 + .05);
}

void main() {
  test('状态分布中性实色对浅深画布合成对比≥3:1（R06.10）', () {
    for (final colors in [
      const MileafColors.light(),
      const MileafColors.dark(),
    ]) {
      final ratio = contrastRatio(colors.textFaint, colors.canvas);
      expect(
        ratio,
        greaterThanOrEqualTo(3.0),
        reason: colors.isDark
            ? 'dark textFaint/canvas'
            : 'light textFaint/canvas',
      );
    }
  });

  testWidgets('正负与零分桶同图呈现，pp单位就近定义', (tester) async {
    await openParking(tester, <Uri>[]);
    expect(find.textContaining('只反映已记录的变化'), findsOneWidget);
    expect(find.textContaining('不预测未来'), findsOneWidget);
    expect(find.byKey(const Key('parking-trend-chart')), findsOneWidget);
    // 首桶为 -2：读值带真负号与「个百分点」；0 分桶不画零柱但可选。
    expect(find.textContaining('−2.0 个百分点'), findsWidgets);
    expect(find.textContaining('折合每天 −4.0 个百分点'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('状态分布图例与类别行并列，分母为有效窗口观测小时', (tester) async {
    await openParking(tester, <Uri>[]);
    for (final name in ['在线', '睡眠', '离线', '未知']) {
      expect(find.text(name), findsWidgets, reason: name);
    }
    expect(find.textContaining('按有效停车时长计算占比'), findsOneWidget);
    expect(find.text('16.7%'), findsOneWidget);
    expect(find.text('50.0%'), findsOneWidget);
    expect(find.text('8.3%'), findsOneWidget);
    expect(find.text('25.0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄片段按真实比例且未知share缺失不伪造全日状态', (tester) async {
    await openParking(
      tester,
      <Uri>[],
      response: (uri) => parkingScenario('fragments', uri),
    );
    expect(find.textContaining('按有效停车时长计算占比'), findsOneWidget);
    // 窄片段真实比例：0.1 小时读作 6 分钟；share 缺失显示 —，不补 0%。
    expect(find.text('6 分钟'), findsOneWidget);
    expect(find.text('0.1%'), findsOneWidget);
    expect(find.text('19 小时 54 分钟'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('中间分桶缺失留槽不补零，读值给缺失口径', (tester) async {
    await openParking(
      tester,
      <Uri>[],
      response: (uri) => parkingScenario('missing', uri),
    );
    final next = stepButton(MileafChartGrammar.nextStep);
    await tester.scrollUntilVisible(
      next.hitTestable(),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(next);
    await tester.pumpAndSettle();
    // 缺失分桶读值给缺失口径：值为 —，脚注「缺失，不补零」。
    expect(find.text('缺失，不补零'), findsOneWidget);
    // 全部分桶未缺失时不显示整行说明。
    expect(find.text('分桶电量变化缺失，不补零'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('全部分桶缺失时保留图区说明，不画零柱', (tester) async {
    await openParking(
      tester,
      <Uri>[],
      response: (uri) => parkingScenario('allnull', uri),
    );
    expect(find.text('分桶电量变化缺失，不补零'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('全零分桶不崩溃，零柱在基线且量程下限为1', (tester) async {
    // Standards审查Major修复回归：maxAbs=0 时 log(0) 曾崩溃。
    await openParking(
      tester,
      <Uri>[],
      response: (uri) => parkingScenario('zeros', uri),
    );
    expect(find.textContaining('0.0 个百分点'), findsWidgets);
    expect(find.textContaining('折合每天 0.0 个百分点'), findsWidgets);
    expect(find.byKey(const Key('parking-trend-chart')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('无有效窗口时主值为缺失且不展示零变化', (tester) async {
    await openParking(tester, <Uri>[], empty: true);
    expect(find.textContaining('— 个百分点'), findsWidgets);
    expect(find.text('暂无有效停车窗口，无法判断电量变化'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('200%下前后按钮实际触控至少44且读值随之变化', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openParking(tester, <Uri>[]);
    for (final label in [
      MileafChartGrammar.previousStep,
      MileafChartGrammar.nextStep,
    ]) {
      final rect = tester.getRect(stepButton(label));
      expect(rect.width, greaterThanOrEqualTo(44), reason: label);
      expect(rect.height, greaterThanOrEqualTo(44), reason: label);
    }
    final prev = stepButton(MileafChartGrammar.previousStep);
    await tester.scrollUntilVisible(prev.hitTestable(), 100);
    await tester.tap(prev);
    await tester.pumpAndSettle();
    expect(find.textContaining('−2.0 个百分点'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('正负柱图支持键盘左右与语义增减', (tester) async {
    await openParking(tester, <Uri>[]);
    final plot = trendPlot();
    final semanticsHandle = tester.ensureSemantics();
    final semantics = tester
        .widgetList<Semantics>(plot)
        .whereType<Semantics>()
        .firstOrNull!;
    // 默认选中首桶（-2）：只能加，不能减。
    expect(semantics.properties.onIncrease, isNotNull);
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
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.textContaining('0.0 个百分点'), findsOneWidget);
    expect(
      tester
          .widgetList<Semantics>(trendPlot())
          .whereType<Semantics>()
          .first
          .properties
          .onDecrease,
      isNotNull,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.textContaining('−2.0 个百分点'), findsWidgets);
    semanticsHandle.dispose();
  });

  testWidgets('宽屏专题主体限宽并与标题共享左线', (tester) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openParking(tester, <Uri>[]);
    final chart = find.byKey(const Key('parking-trend-chart'));
    expect(tester.getSize(chart).width, lessThanOrEqualTo(560));
    final header = find.text('停车电量变化');
    final card = find
        .ancestor(of: chart, matching: find.byType(MileafModuleCard))
        .first;
    // R24：卡片外缘与身份块标题共享左线；卡内内容由卡内边对齐。
    expect(tester.getRect(card).left, closeTo(tester.getRect(header).left, 1));
    expect(tester.takeException(), isNull);
  });

  const output = String.fromEnvironment('MILEAF_U09E_RENDER_OUTPUT');
  const font = String.fromEnvironment('MILEAF_RENDER_FONT');
  testWidgets('U09e 正式Flutter停放观察矩阵及完整滚动', (tester) async {
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
        for (final scenario in ['normal', 'missing', 'empty'])
          for (final scale in [1.0, 2.0])
            (const Size(360, 800), scale, scenario, dark),
        for (final scale in [1.3, 1.5])
          (const Size(360, 800), scale, 'normal', dark),
        (const Size(320, 568), 2, 'normal', dark),
        (const Size(390, 844), 1, 'normal', dark),
        (const Size(768, 1024), 2, 'normal', dark),
        for (final scenario in ['error', 'allnull', 'fragments', 'zeros'])
          (const Size(360, 800), 1, scenario, dark),
      ],
    ];
    for (final (size, scale, scenario, dark) in cases) {
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      final boundary = GlobalKey();
      final name =
          'u09e-parking-$scenario-${dark ? 'dark' : 'light'}-${size.width.toInt()}-${(scale * 100).round()}';
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
            client: parkingClient([], scenario: scenario),
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
        find.text('展开停放观察').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('展开停放观察').first);
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
      if (scenario == 'normal' && scale == 2.0) {
        // 大字/窄屏完整滚动：200% 至少到达最后一个内容和动作。
        var step = 0;
        while (tester.state<ScrollableState>(scroll).position.extentAfter > 0 &&
            step < 60) {
          await tester.drag(scroll, Offset(0, -size.height * .65));
          await tester.pumpAndSettle();
          step++;
          await save('scroll$step');
        }
        await save('bottom');
        final prev = stepButton(MileafChartGrammar.previousStep);
        await tester.scrollUntilVisible(prev.hitTestable(), -150);
        await tester.tap(prev);
        await tester.pumpAndSettle();
        expect(find.textContaining('−2.0 个百分点'), findsOneWidget);
      }
      if (scenario == 'normal' && size.width == 360 && scale == 1) {
        final plot = tester.getRect(
          find.byKey(const Key('parking-trend-chart')),
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
        // 前一点动作可达：滚到读值区点击后读值回到首桶。
        final prev = stepButton(MileafChartGrammar.previousStep);
        await tester.scrollUntilVisible(prev.hitTestable(), -150);
        await tester.tap(prev);
        await tester.pumpAndSettle();
        expect(find.textContaining('−2.0 个百分点'), findsOneWidget);
      }
      if (scenario == 'normal' ||
          scenario == 'missing' ||
          scenario == 'fragments') {
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
      await File('$output/gallery/u09e-manifest.json').writeAsString(
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
