import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/workspace.dart';

import 'charging_expansion_test.dart' show chargingStatsV2;
import 'statistics_charging_test.dart' show statisticsChargingResponse;
import 'support/statistics_insights_fixture.dart' show statisticsInsightsMeta;
import 'statistics_test.dart' show openStats;
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

/// U09c 专属回归：旧测试未覆盖的指标短词与完整口径、320/大字与 200%
/// 均 2×2、费用缺失不画假 0、刷新 44 命中、宽屏限宽及期间记录返回。
/// 渲染矩阵沿交付手册 §4，输出独占 gallery/u09c-*。

http.Client chargingClient(List<Uri> seen, {String scenario = 'normal'}) {
  return MockClient((request) async {
    if (request.url.path.endsWith('/stats') &&
        request.url.queryParameters['kind'] == 'charging') {
      seen.add(request.url);
      if (scenario == 'error') {
        return http.Response(
          '{"error":{"code":"db_unavailable","message":"unavailable"}}',
          503,
        );
      }
      return http.Response(
        jsonEncode(chargingScenario(scenario)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (scenario == 'legacy' && request.url.path.endsWith('/meta')) {
      // 旧版回退只摘除充电体验能力，统计洞察特性保持声明。
      seen.add(request.url);
      final body = statisticsInsightsMeta()..remove('charging_experience');
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return statisticsChargingResponse(request);
  });
}

Map<String, dynamic> chargingScenario(String scenario) {
  final body = chargingStatsV2();
  switch (scenario) {
    case 'normal':
      // 桶0：有过充电但没有一条已知费用——旧实现会把服务端 0 画成柱，
      // 现在（R06.8/S05）必须表现为缺失读值「—」。
      (body['buckets'] as List)[0]['cost'] = 0;
    case 'missing':
      // 费用全缺失：结论必须是「—」而不是 0 元，桶图全部留槽。
      final totals = body['totals'] as Map<String, dynamic>;
      totals['cost_known_sessions'] = 0;
      totals['cost_known_energy_kwh'] = 0.0;
      totals['unit_cost_added'] = {
        'value': null,
        'numerator_cost': 0.0,
        'denominator_kwh': 0.0,
        'eligible_sessions': 0,
        'excluded_cost_sessions': 0,
      };
      for (final bucket in body['buckets'] as List) {
        (bucket as Map)['cost'] = 0;
        bucket['cost_known_sessions'] = 0;
        bucket['cost_known_energy_kwh'] = 0.0;
        bucket['unit_cost_added'] = totals['unit_cost_added'];
      }
    case 'empty':
      body['totals'] = {
        ...(body['totals'] as Map<String, dynamic>),
        'sessions': 0,
      };
      body['buckets'] = <Map<String, dynamic>>[];
  }
  return body;
}

Future<void> openU09c(WidgetTester tester, http.Client client) async {
  // 沿 statistics_charging_test 的固定输入：桶日期与窗口对齐，
  // 「查看此期间补能」的期间换算才能落在窗口内。
  await openStats(
    tester,
    client,
    () => DateTime.utc(2026, 3, 30, 12),
    () => 'UTC',
    statisticsInsights: true,
  );
  await tester.scrollUntilVisible(
    find.text('补能').hitTestable(),
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('补能'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('指标短词可读，图标题与读屏保留完整口径', (tester) async {
    await openU09c(tester, chargingClient([]));
    for (final short in ['电量', '费用', '均价', '次数']) {
      expect(find.widgetWithText(StatusChip, short), findsOneWidget);
    }
    // 默认指标：图标题用完整口径，而不是短词。
    expect(find.text('每日充电量'), findsOneWidget);
    final labels = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .map((s) => s.properties.label)
        .whereType<String>()
        .where((label) => label.contains('图表，单位'))
        .toList();
    expect(labels, isNotEmpty);
    expect(labels.first, contains('每日充电量'));
    expect(labels.first, contains('kWh'));
    await tester.tap(find.widgetWithText(StatusChip, '均价'));
    await tester.pumpAndSettle();
    expect(find.text('充入均价'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('有过充电但无已知费用的桶读值为缺失，不画假 0 元', (tester) async {
    await openU09c(tester, chargingClient([], scenario: 'normal'));
    // 切到费用指标：桶0被默认选中，读值必须是「日期 —」，不能出现 0 元。
    final fee = find.widgetWithText(StatusChip, '费用');
    await tester.scrollUntilVisible(fee.hitTestable(), 150);
    await tester.tap(fee);
    await tester.pumpAndSettle();
    // R29：读数头把日期与数值分行，缺失值的数值行就是「—」。
    expect(find.textContaining(RegExp(r'^\d{1,2}/\d{1,2}$')), findsWidgets);
    expect(find.text('—'), findsWidgets);
    expect(find.textContaining(RegExp(r'¥0$')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('费用全缺失时结论为「—」且桶图读值留槽', (tester) async {
    await openU09c(tester, chargingClient([], scenario: 'missing'));
    final fee = find.widgetWithText(StatusChip, '费用');
    await tester.scrollUntilVisible(fee.hitTestable(), 150);
    await tester.tap(fee);
    await tester.pumpAndSettle();
    final chart = tester.widget<TimeSeriesChart>(
      find.byType(TimeSeriesChart).first,
    );
    expect(chart.readout!.call(0), endsWith('—'));
    expect(chart.readout!.call(2), endsWith('—'));
    // 已知费用 0 条：主值显示缺失符号，覆盖行明确 0 条已知。
    expect(find.text('—'), findsWidgets);
    expect(find.textContaining(RegExp(r'0 / ')), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320宽普通字号四指标为2×2，每格命中至少44高且无溢出', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openU09c(tester, chargingClient([]));
    final fee = find.widgetWithText(StatusChip, '费用');
    await tester.scrollUntilVisible(fee.hitTestable(), 120);
    final feeRect = tester.getRect(fee);
    final energyRect = tester.getRect(find.widgetWithText(StatusChip, '电量'));
    // 2×2：电量/费用同排。
    expect(feeRect.top, closeTo(energyRect.top, 1));
    expect(feeRect.height, greaterThanOrEqualTo(44));
    final avg = find.widgetWithText(StatusChip, '均价');
    await tester.ensureVisible(avg.hitTestable());
    await tester.pumpAndSettle();
    // 同一稳定帧内比较两排位置。
    final avgRect = tester.getRect(avg);
    final energyNow = tester.getRect(find.widgetWithText(StatusChip, '电量'));
    expect(avgRect.top, greaterThan(energyNow.bottom - 1), reason: '均价应换到第二排');
    expect(tester.takeException(), isNull);
  });

  testWidgets('360宽200%四指标保持2×2且无溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openU09c(tester, chargingClient([]));
    // R03：大字采用2×2（短词可容纳，无需单列），每格仍至少44高。
    final feeRect = tester.getRect(find.widgetWithText(StatusChip, '费用'));
    final energyRect = tester.getRect(find.widgetWithText(StatusChip, '电量'));
    expect(feeRect.top, closeTo(energyRect.top, 1));
    expect(feeRect.height, greaterThanOrEqualTo(44));
    final avgRect = tester.getRect(find.widgetWithText(StatusChip, '均价'));
    expect(avgRect.top, greaterThan(energyRect.bottom - 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('刷新为图标按钮且实际命中至少44', (tester) async {
    await openU09c(tester, chargingClient([]));
    final refresh = find.byTooltip('刷新补能统计');
    expect(refresh, findsOneWidget);
    final rect = tester.getRect(refresh);
    expect(rect.width, greaterThanOrEqualTo(44));
    expect(rect.height, greaterThanOrEqualTo(44));
    final icon = tester.widget<MileafIconButton>(
      find.byType(MileafIconButton).first,
    );
    expect(icon.tooltip, '刷新补能统计');
  });

  testWidgets('宽屏专题主体限宽并与标题共享左线', (tester) async {
    tester.view.physicalSize = const Size(768, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openU09c(tester, chargingClient([]));
    final chart = find.byType(TimeSeriesChart).first;
    expect(tester.getSize(chart).width, lessThanOrEqualTo(560));
    final header = find.text('充电费用');
    expect(tester.getRect(chart).left, closeTo(tester.getRect(header).left, 1));
  });

  testWidgets('主图与读值后可查看期间记录，返回保留选点', (tester) async {
    await openU09c(tester, chargingClient([]));
    final plot = find.byKey(const ValueKey('charging-topic-plot'));
    await tester.scrollUntilVisible(plot.hitTestable(), 150);
    final rect = tester.getRect(plot);
    // 选中一个非默认桶，进入记录后返回，选点必须保留。
    await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
    await tester.pumpAndSettle();
    final chart = tester.widget<TimeSeriesChart>(
      find.byType(TimeSeriesChart).first,
    );
    final chosen = chart.selectedIndex;
    expect(chosen, isNotNull);
    final records = find.text('查看此期间补能');
    await tester.scrollUntilVisible(records.hitTestable(), 150);
    await tester.tap(records);
    await tester.pumpAndSettle();
    expect(find.text('补能记录'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TimeSeriesChart>(find.byType(TimeSeriesChart).first)
          .selectedIndex,
      chosen,
      reason: '普通返回保留阅读选点',
    );
    expect(tester.takeException(), isNull);
  });

  const output = String.fromEnvironment('MILEAF_U09C_RENDER_OUTPUT');
  const font = String.fromEnvironment('MILEAF_RENDER_FONT');
  testWidgets('U09c 正式Flutter补能专题矩阵及完整滚动', (tester) async {
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
        for (final scenario in ['error', 'legacy'])
          (const Size(360, 800), 1, scenario, dark),
      ],
    ];
    for (final (size, scale, scenario, dark) in cases) {
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      final boundary = GlobalKey();
      final name =
          'u09c-charging-$scenario-${dark ? 'dark' : 'light'}-${size.width.toInt()}-${(scale * 100).round()}';
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
            client: chargingClient([], scenario: scenario),
            sessionStore: store,
            trustStore: MemoryTrustStore(),
            vehiclePreferences: MemoryVehiclePreferences(),
            appearance: appearance,
            now: () => DateTime.utc(2026, 3, 30, 12),
            calendar: () async => CalendarContext('UTC'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('统计').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('补能').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('补能').first);
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
          find.byKey(const ValueKey('charging-topic-plot')),
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
        // 期间记录入口与返回：入口在主图/读值之后。
        final records = find.text('查看此期间补能');
        await tester.scrollUntilVisible(records.hitTestable(), -150);
        await tester.tap(records);
        await tester.pumpAndSettle();
        await save('records-top');
        final list = find.byType(Scrollable).last;
        while (tester.state<ScrollableState>(list).position.extentAfter > 0) {
          await tester.drag(list, Offset(0, -size.height * .65));
          await tester.pumpAndSettle();
        }
        await save('records-bottom');
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }
      if (scenario == 'normal' || scenario == 'missing') {
        // D-AP12a-01：页尾「关于这些数据」的五类说明行改 MileafDisclosure。
        final notes = find.widgetWithText(MileafDisclosure, '口径与估算');
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
      await File('$output/gallery/u09c-manifest.json').writeAsString(
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
