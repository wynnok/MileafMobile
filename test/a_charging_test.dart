import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mileaf/src/design/components/charts.dart';
import 'package:mileaf/src/design/components/components.dart'
    show MetricBlock, MileafModuleCard, MileafShareRing, ShareRingLegendRow;
import 'package:mileaf/src/design/components/nav_bar.dart';
import 'package:mileaf/src/design/icons.dart' show MileafIcon, MileafIconName;
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/tokens.dart' show MileafIconMetrics;

import 'charging_test.dart' show app, jsonResponse;
import 'charging_expansion_test.dart' show chargingStatsV2, expansionResponse;

/// AP07：概览等页面也出现「充电」字样，底栏点击按导航栏定位。
Finder navTab(String label) =>
    find.descendant(of: find.byType(MileafNavBar), matching: find.text(label));

void main() {
  testWidgets('U06 账本同底摘要、三读数与每日充电', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(MockClient((r) async => expansionResponse(r))));
    await tester.pumpAndSettle();
    await tester.tap(navTab('充电'));
    await tester.pumpAndSettle();
    expect(find.text('已记录费用'), findsOneWidget);
    expect(find.textContaining('次有费用'), findsOneWidget);
    expect(find.textContaining('8 次中 2 次有费用'), findsOneWidget);
    final dailyTop = tester.getTopLeft(find.text('每日充电')).dy;
    expect(tester.getTopLeft(find.text('已记录费用')).dy, lessThan(dailyTop));
    await tester.scrollUntilVisible(find.text('充入电量'), 160);
    expect(find.text('充入电量'), findsOneWidget);
    // P03 三格：充入电量 / 充入均价 / 充电时长（充电次数并入覆盖句）。
    expect(find.text('充入均价'), findsOneWidget);
    expect(find.text('充电时长'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A 空期间不画全零补能图', (tester) async {
    await tester.pumpWidget(
      app(
        MockClient((request) async {
          if (request.url.path.endsWith('/stats') &&
              request.url.queryParameters['kind'] == 'charging') {
            final body = chargingStatsV2();
            body['buckets'] = [];
            final totals = body['totals'] as Map<String, dynamic>;
            totals.addAll({
              'sessions': 0,
              'energy_added_kwh': 0,
              'cost': null,
              'cost_known_sessions': 0,
              'cost_known_energy_kwh': 0,
              'energy_known_sessions': 0,
              'duration_min_total': 0,
              'duration_known_sessions': 0,
              'unit_cost_added': {
                'value': null,
                'numerator_cost': 0,
                'denominator_kwh': 0,
                'eligible_sessions': 0,
                'excluded_cost_sessions': 0,
              },
            });
            return jsonResponse(body);
          }
          return expansionResponse(request);
        }),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(navTab('充电'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('每日充电'), 160);
    expect(find.text('每日充电'), findsOneWidget);
    // CP07 首次空：还没有充电记录（共享构造函数）。
    // 每日充电卡空态句（充电方式卡的首次空结论在下方，惰性构建）。
    expect(find.text('这段时间没有充电'), findsOneWidget);
    expect(find.byType(StemChart), findsNothing);
    expect(find.textContaining('0 次中 0 次有费用'), findsOneWidget);
  });

  testWidgets('A 费用缺少币种时不默认人民币', (tester) async {
    await tester.pumpWidget(app(MockClient((r) async => expansionResponse(r))));
    await tester.pumpAndSettle();
    await tester.tap(navTab('充电'));
    await tester.pumpAndSettle();
    expect(find.textContaining('¥'), findsNothing);
    expect(find.textContaining('币种未记录'), findsWidgets);
  });

  testWidgets('A 200% 三读数与构成不溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(app(MockClient((r) async => expansionResponse(r))));
    await tester.pumpAndSettle();
    await tester.tap(navTab('充电'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('充入电量'), 300);
    expect(find.text('充入电量'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('充电时长'), 300);
    expect(find.text('充电时长'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MC08 账目卡 energy tint、每日充电图随指标域、AC/DC 同域两档', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(MockClient((r) async => expansionResponse(r))));
    await tester.pumpAndSettle();
    await tester.tap(navTab('充电'));
    await tester.pumpAndSettle();

    final colors = MileafColors.of(tester.element(find.text('已记录费用')));
    const energy = MileafDataDomain.energy;
    const cost = MileafDataDomain.cost;

    // CL01/CL06：账目卡是 energy 域的焦点卡；≥10% 面积的面只允许 8% tint。
    final account = find.ancestor(
      of: find.text('已记录费用'),
      matching: find.byType(MileafModuleCard),
    );
    expect(tester.widget<MileafModuleCard>(account).hue, energy.hue);
    expect(
      tester
          .widget<Material>(
            find.descendant(of: account, matching: find.byType(Material)).first,
          )
          .color,
      Color.alphaBlend(energy.tint(colors), colors.surface),
    );

    // CL01：每日充电图默认画的是「电量」，属 energy 域。
    expect(tester.widget<StemChart>(find.byType(StemChart)).hue, energy.hue);
    // CL01/CL39：切到「费用」后图的数据身份变成 cost——同一指标在图上与记录行
    // 必须是同一个色相，因此这里不能用固定色相。
    await tester.tap(
      find.descendant(of: find.byType(StemChart), matching: find.text('费用')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<StemChart>(find.byType(StemChart)).hue, cost.hue);
    await tester.tap(
      find.descendant(of: find.byType(StemChart), matching: find.text('电量')),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<StemChart>(find.byType(StemChart)).hue, energy.hue);

    // CL02：AC / DC 是同一个 energy 域的 solid / strong 两档，图例样本同色。
    await tester.scrollUntilVisible(find.byType(MileafShareRing), 300);
    final ring = tester.widget<MileafShareRing>(find.byType(MileafShareRing));
    expect(ring.hue, energy.hue);
    expect(ring.segments.first.color, energy.solid(colors));
    expect(ring.segments[1].color, energy.strong(colors));
    final legends = tester
        .widgetList<ShareRingLegendRow>(find.byType(ShareRingLegendRow))
        .toList();
    expect(legends.length, 2);
    expect(legends.first.color, energy.solid(colors));
    expect(legends.last.color, energy.strong(colors));
  });

  testWidgets('MC08 记录行与地点行的身份图标取 energy strong、读数按域取色', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(MockClient((r) async => expansionResponse(r))));
    await tester.pumpAndSettle();
    await tester.tap(navTab('充电'));
    await tester.pumpAndSettle();

    final colors = MileafColors.of(tester.element(find.text('已记录费用')));
    const energy = MileafDataDomain.energy;
    const cost = MileafDataDomain.cost;

    // CL12/CL13：记录行行首 16 的 bolt 是身份图标，取 domain.strong。
    await tester.scrollUntilVisible(find.text('最近充电'), 300);
    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is MileafIcon &&
            widget.name == MileafIconName.bolt &&
            widget.size == MileafIconMetrics.inline &&
            widget.color == energy.strong(colors),
      ),
      findsWidgets,
    );
    final records = tester
        .widgetList<MetricBlock>(find.byType(MetricBlock))
        .map((block) => block.hue)
        .toSet();
    expect(records, containsAll([energy.hue, cost.hue]));

    // CL12：地点行行首 mapPin，两格读值充入 energy / 充入均价 cost。
    await tester.scrollUntilVisible(find.text('充电地点'), 300);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is MileafIcon &&
            widget.name == MileafIconName.mapPin &&
            widget.color == energy.strong(colors),
      ),
      findsWidgets,
    );
  });
}
