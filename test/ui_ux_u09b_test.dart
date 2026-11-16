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

import 'statistics_conditions_test.dart' show conditionsFixture, openConditions;
import 'statistics_test.dart' show openStats;
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'ui_ux_u09a_test.dart' show dailyClient;
import 'widget_test.dart' show MemoryTrustStore;

/// U09b 专属回归：旧测试未覆盖的组边界短标签与读屏、全缺失/单组、
/// 200% 分组控件、点图键盘与语义增减、刷新 44 命中及宽屏限宽。

http.Client conditionsClient(List<Uri> seen, {String scenario = 'normal'}) {
  final base = dailyClient(seen);
  return MockClient((request) async {
    if (request.url.path.endsWith('/driving-analysis') &&
        request.url.queryParameters['view'] == 'conditions') {
      seen.add(request.url);
      if (scenario == 'error') return http.Response('{}', 503);
      return http.Response(
        jsonEncode(conditionsScenario(scenario)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    final forwarded = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return http.Response.fromStream(await base.send(forwarded));
  });
}

Map<String, dynamic> conditionsScenario(String scenario) {
  final body = conditionsFixture();
  final bin = (body['temperature_bins'] as List).first as Map<String, dynamic>;
  switch (scenario) {
    case 'normal':
      // 负温度、组边界、无样本与充分样本并存；客户端从不插值。
      body['temperature_bins'] = [
        for (final (lower, value, status) in [
          (-10, 248, 'sparse'),
          (-5, 210, 'adequate'),
          (0, null, 'insufficient_data'),
          (5, 195, 'adequate'),
        ])
          {
            ...bin,
            'lower_c': lower,
            'upper_c': lower + 5,
            'drives': 3,
            'distance_km': 30,
            'consumption_wh_km': value,
            'sample_status': status,
            'evidence_filter': {
              ...(bin['evidence_filter'] as Map),
              'outside_temp_min_c': lower,
              'outside_temp_max_c': lower + 5,
            },
          },
      ];
    case 'missing':
      for (final b in body['temperature_bins'] as List) {
        (b as Map)['consumption_wh_km'] = null;
      }
    case 'single':
      body['temperature_bins'] = [bin];
    case 'empty':
      body['status'] = 'no_records';
    case 'unsupported':
      body['status'] = 'unsupported';
  }
  return body;
}

Future<void> openU09b(WidgetTester tester, http.Client client) async {
  await openStats(
    tester,
    client,
    () => DateTime.utc(2026, 10, 28, 11),
    () => 'Asia/Shanghai',
    statisticsInsights: true,
  );
  await openConditions(tester);
}

Semantics? semanticsOf(WidgetTester tester, Finder finder) =>
    tester.widgetList<Semantics>(finder).firstOrNull;

void main() {
  testWidgets('负温度与组边界短标签可读，读屏保留精确区间并明确左闭右开', (tester) async {
    await openU09b(tester, conditionsClient([]));
    expect(find.text('−10至−5°C'), findsWidgets);
    expect(find.text('0至5°C'), findsWidgets);
    // 图例在图旁明确半开口径，只显示真实分组值。
    expect(find.textContaining('左闭右开'), findsWidgets);
    final value = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          (widget.properties.label?.startsWith('所选温度组') ?? false),
    );
    expect(
      semanticsOf(tester, value)!.properties.label,
      contains('[−10, −5) °C，左闭右开'),
    );
    final plot = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          (widget.properties.label?.startsWith('温度分组点图') ?? false),
    );
    final plotLabel = semanticsOf(tester, plot)!.properties.label!;
    expect(plotLabel, contains('−10至−5°C（[−10, −5) °C，左闭右开）净电耗 248 Wh/km'));
    expect(plotLabel, contains('0至5°C（[0, 5) °C，左闭右开）无样本'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('点图支持键盘左右与语义增减', (tester) async {
    await openU09b(tester, conditionsClient([]));
    final plot = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          (widget.properties.label?.startsWith('温度分组点图') ?? false),
    );
    final semanticsHandle = tester.ensureSemantics();
    // 语义增减与键盘左右同源；首组无前一组，右移后两者均可用。
    expect(semanticsOf(tester, plot)!.properties.onIncrease, isNotNull);
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
    expect(find.text('所选温度组 · −5至0°C'), findsOneWidget);
    expect(
      semanticsOf(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.label?.startsWith('温度分组点图') ?? false),
        ),
      )!.properties.onDecrease,
      isNotNull,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('所选温度组 · −10至−5°C'), findsOneWidget);
    semanticsHandle.dispose();
  });

  testWidgets('全缺失保持基线与组标签，不伪造数值', (tester) async {
    await openU09b(tester, conditionsClient([], scenario: 'missing'));
    expect(find.text('— Wh/km'), findsOneWidget);
    expect(find.text('暂无净电耗'), findsOneWidget);
    expect(find.text('小样本，仅供点读'), findsOneWidget);
    final plot = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          (widget.properties.label?.startsWith('温度分组点图') ?? false),
    );
    final label = semanticsOf(tester, plot)!.properties.label!;
    expect(label, contains('无样本'), reason: label);
    expect(label.contains('Wh/km'), isFalse, reason: label);
    expect(tester.takeException(), isNull);
  });

  testWidgets('单组时前后操作禁用且选组稳定', (tester) async {
    await openU09b(tester, conditionsClient([], scenario: 'single'));
    TextButton button(String label) => tester.widget<TextButton>(
      find.ancestor(of: find.text(label), matching: find.byType(TextButton)),
    );
    expect(button('下一温度组').onPressed, isNull);
    expect(button('上一温度组').onPressed, isNull);
    expect(find.text('210 Wh/km'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360宽200%分组控件换行无溢出，芯片实际命中至少44', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openU09b(tester, conditionsClient([]));
    for (final label in ['−10至−5°C', '−5至0°C', '0至5°C', '5至10°C']) {
      final chip = find.widgetWithText(StatusChip, label).hitTestable();
      await tester.scrollUntilVisible(chip, 150);
      final rect = tester.getRect(chip);
      expect(rect.height, greaterThanOrEqualTo(44));
    }
    // P08：大字下分组选择换行重排，不产生三行胶囊残片或横向溢出。
    expect(tester.takeException(), isNull);
  });

  testWidgets('刷新为图标动作，实际命中至少44并有具体名称', (tester) async {
    await openU09b(tester, conditionsClient([]));
    final refresh = find.byTooltip('刷新能耗条件');
    expect(refresh, findsOneWidget);
    final rect = tester.getRect(refresh);
    expect(rect.width, greaterThanOrEqualTo(44));
    expect(rect.height, greaterThanOrEqualTo(44));
    final icon = tester.widget<MileafIconButton>(
      find.byType(MileafIconButton).first,
    );
    expect(icon.tooltip, '刷新能耗条件');
  });

  testWidgets('宽屏专题主体限宽并与标题共享左线', (tester) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openU09b(tester, conditionsClient([]));
    final plot = find.byKey(const ValueKey('conditions-plot'));
    final header = find.text('所选温度组 · −10至−5°C');
    expect(tester.getSize(plot).width, lessThanOrEqualTo(560));
    expect(tester.getRect(plot).left, closeTo(tester.getRect(header).left, 1));
  });

  testWidgets('点图命中按绘图区换算，左右边缘选中首末组', (tester) async {
    await openU09b(tester, conditionsClient([]));
    final plot = find.byKey(const ValueKey('conditions-plot'));
    await tester.scrollUntilVisible(plot.hitTestable(), 150);
    final rect = tester.getRect(plot);
    // 越过Y轴留白后的最左绘图区仍选中第一组。
    await tester.tapAt(Offset(rect.left + 60, rect.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('所选温度组 · −10至−5°C'), findsOneWidget);
    // 最右缘选中最后一组，而不是因未扣轴留白偏移到相邻组。
    await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('所选温度组 · 5至10°C'), findsOneWidget);
  });

  const output = String.fromEnvironment('MILEAF_U09B_RENDER_OUTPUT');
  const font = String.fromEnvironment('MILEAF_RENDER_FONT');
  testWidgets('U09b 正式Flutter能耗条件矩阵及完整滚动', (tester) async {
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
        for (final scenario in ['normal', 'empty', 'missing'])
          for (final scale in [1.0, 2.0])
            (const Size(360, 800), scale, scenario, dark),
        for (final scale in [1.3, 1.5])
          (const Size(360, 800), scale, 'normal', dark),
        (const Size(320, 568), 2, 'normal', dark),
        (const Size(390, 844), 1, 'normal', dark),
        (const Size(768, 1024), 2, 'normal', dark),
        for (final scenario in ['single', 'error', 'unsupported'])
          (const Size(360, 800), 1, scenario, dark),
      ],
    ];
    for (final (size, scale, scenario, dark) in cases) {
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      final boundary = GlobalKey();
      final name =
          'u09b-conditions-$scenario-${dark ? 'dark' : 'light'}-${size.width.toInt()}-${(scale * 100).round()}';
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
            client: conditionsClient([], scenario: scenario),
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
        find.text('能耗').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('能耗').first);
      await tester.pumpAndSettle();
      Future<void> save(String camera, {bool evidence = false}) async {
        final path =
            '$output/gallery/${evidence ? name.replaceFirst('conditions', 'evidence') : name}-$camera.png';
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
          find.byKey(const ValueKey('conditions-plot')),
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
        // 温度组证据下钻与返回。
        await tester.scrollUntilVisible(
          find.text('查看该温度组行程').hitTestable(),
          -150,
          scrollable: scroll,
        );
        await tester.tap(find.text('查看该温度组行程'));
        await tester.pumpAndSettle();
        await save('top', evidence: true);
        final list = find.byType(Scrollable).last;
        while (tester.state<ScrollableState>(list).position.extentAfter > 0) {
          await tester.drag(list, Offset(0, -size.height * .65));
          await tester.pumpAndSettle();
        }
        await save('bottom', evidence: true);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        // 返回后温度组选择保留。
        expect(find.text('所选温度组 · −10至−5°C'), findsOneWidget);
      }
      if (scenario == 'normal' || scenario == 'missing') {
        final notes = find.widgetWithText(ExpansionTile, '数据说明');
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
      await File('$output/gallery/u09b-manifest.json').writeAsString(
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
