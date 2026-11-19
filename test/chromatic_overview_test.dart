import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/copy/terms.dart' as terms;
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/icons.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/c_fixture.dart' show cNow, cSite;
import 'support/c_gallery_client.dart';
import 'support/session_store.dart';
import 'support/test_trust_store.dart' show MemoryTrustStore;
import 'support/vehicle_preferences.dart';

/// MC06 概览页接线守卫（CL01/CL02/CL05/CL06/CL07/CL08/CL12/CL14）。
///
/// 只断言「哪一块数据绑到哪个域的色相」与「色相只落在允许的位置」，不改版面、
/// 不改文案、不改数据口径；取值一律经 `MileafDataDomain.hue` 与 `MileafHueTone`
/// 解析，测试里不出现十六进制。

class _Cny implements CurrencyPreferenceStore {
  @override
  Future<String?> read(String site) async => 'CNY';
  @override
  Future<void> write(String site, String? code) async {}
}

class _MemoryAppearance implements AppearancePreferenceStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? next) async => value = next;
}

Future<void> openOverview(
  WidgetTester tester, {
  String scenario = 'normal',
  MileafAppearance mode = MileafAppearance.dark,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final store = MemorySessionStore()
    ..value = jsonEncode({
      'site': cSite,
      'token': 'test',
      'expires_at': '2099-01-01T00:00:00Z',
    });
  final appearance = AppearanceController(
    _MemoryAppearance()..value = mode.name,
  );
  await appearance.restore();
  await tester.pumpWidget(
    MileafApp(
      client: cGalleryClient(scenario: scenario),
      sessionStore: store,
      trustStore: MemoryTrustStore(),
      vehiclePreferences: MemoryVehiclePreferences(),
      currencyPreferences: _Cny(),
      appearance: appearance,
      now: () => cNow,
      calendar: () async => CalendarContext('Asia/Shanghai'),
    ),
  );
  await tester.pumpAndSettle();
}

/// 一页里某个 widget 类型携带的色相（[find] 命中多个时取第一个）。
MileafHue? hueOf<T extends Widget>(WidgetTester tester, Finder finder) {
  final widget = tester.widget<T>(finder.first);
  return switch (widget) {
    MetricBlock(:final hue) => hue,
    MileafModuleCard(:final hue) => hue,
    MileafGroupRow(:final hue) => hue,
    MileafDataRow(:final hue) => hue,
    TimeSeriesChart(:final hue) => hue,
    _ => throw StateError('未覆盖的组件 $T'),
  };
}

/// 首屏（视口内）可见的数据身份色相集合（CL07）。
Set<MileafHue> visibleHues(WidgetTester tester) {
  final viewport = tester.getRect(find.byType(RefreshIndicator));
  final hues = <MileafHue>{};
  for (final element
      in find
          .byWidgetPredicate(
            (widget) =>
                widget is MetricBlock ||
                widget is MileafModuleCard ||
                widget is MileafGroupRow ||
                widget is MileafDataRow ||
                widget is TimeSeriesChart,
          )
          .evaluate()) {
    final hue = switch (element.widget) {
      MetricBlock(:final hue) => hue,
      MileafModuleCard(:final hue) => hue,
      MileafGroupRow(:final hue) => hue,
      MileafDataRow(:final hue) => hue,
      TimeSeriesChart(:final hue) => hue,
      _ => null,
    };
    if (hue == null) continue;
    if (tester.getRect(find.byWidget(element.widget)).overlaps(viewport)) {
      hues.add(hue);
    }
  }
  return hues;
}

MileafIcon iconNamed(WidgetTester tester, Finder scope, MileafIconName name) =>
    tester.widget<MileafIcon>(
      find.descendant(
        of: scope,
        matching: find.byWidgetPredicate(
          (widget) => widget is MileafIcon && widget.name == name,
        ),
      ),
    );

void main() {
  final colors = const MileafColors.dark();
  final journey = MileafDataDomain.journey.hue;
  final efficiency = MileafDataDomain.efficiency.hue;
  final energy = MileafDataDomain.energy.hue;
  final cost = MileafDataDomain.cost.hue;
  final dwell = MileafDataDomain.dwell.hue;

  testWidgets('焦点卡：8% journey tint + route 卡头图标 + 焦点值 journey strong', (
    tester,
  ) async {
    await openOverview(tester);
    final card = find.ancestor(
      of: find.text('本月驾驶'),
      matching: find.byType(MileafModuleCard),
    );
    expect(hueOf<MileafModuleCard>(tester, card), journey);
    // CL06：≥10% 面积的面只有 8% tint 这一档，页面不叠第二层 alpha。
    final material = tester.widget<Material>(
      find.descendant(of: card, matching: find.byType(Material)).first,
    );
    expect(
      material.color,
      Color.alphaBlend(journey.tint(colors), colors.surface),
    );

    // CL13.2：身份块卡头不带前置图标——R24 要求标题与卡片外缘共享左线，
    // 前置图标会把标题文字推离这条线（ui_ux_u09d/u09e 钉住该不变量）。
    expect(
      find.descendant(
        of: find.byType(MileafPeriodHeader),
        matching: find.byType(MileafIcon),
      ),
      findsNothing,
      reason: '卡头不带图标，身份由 tint 与焦点值颜色承担',
    );

    final focus = find.byWidgetPredicate(
      (widget) =>
          widget is MetricBlock && widget.scale == MetricValueScale.metricLg,
    );
    expect(hueOf<MetricBlock>(tester, focus), journey);
    final number = tester.widget<MileafNumber>(
      find.descendant(of: focus, matching: find.byType(MileafNumber)).first,
    );
    expect(number.color, journey.strong(colors), reason: 'CL12 读数取 strong');
    expect(tester.takeException(), isNull);
  });

  testWidgets('主图色相跟着指标所属域走：里程 / 电耗 / 充电 / 费用', (tester) async {
    await openOverview(tester);
    Finder chip(String label) =>
        find.descendant(of: find.byType(ChipRow), matching: find.text(label));
    Future<void> tapMetric(String label) async {
      await tester.tap(chip(label));
      await tester.pumpAndSettle();
    }

    expect(
      hueOf<TimeSeriesChart>(tester, find.byType(TimeSeriesChart)),
      journey,
    );
    await tapMetric(terms.energyPerKm);
    expect(
      hueOf<TimeSeriesChart>(tester, find.byType(TimeSeriesChart)),
      efficiency,
    );
    await tapMetric(terms.charging);
    expect(
      hueOf<TimeSeriesChart>(tester, find.byType(TimeSeriesChart)),
      energy,
    );
    await tapMetric('费用');
    expect(hueOf<TimeSeriesChart>(tester, find.byType(TimeSeriesChart)), cost);
    expect(tester.takeException(), isNull);
  });

  testWidgets('本期账目四格分域：电耗 efficiency / 费用 cost / 充入 energy / 行程 journey', (
    tester,
  ) async {
    await openOverview(tester);
    await tester.scrollUntilVisible(find.text('本期账目'), 200);
    await tester.pumpAndSettle();
    const expected = {
      'overview-plate-net': 0,
      'overview-plate-cost': 1,
      'overview-plate-energy': 2,
      'overview-plate-drives': 3,
    };
    final hues = [efficiency, cost, energy, journey];
    expected.forEach((key, index) {
      final cell = find.byKey(ValueKey(key));
      expect(hueOf<MetricBlock>(tester, cell), hues[index], reason: key);
      final number = tester.widget<MileafNumber>(
        find.descendant(of: cell, matching: find.byType(MileafNumber)).first,
      );
      expect(
        number.color,
        hues[index].strong(colors),
        reason: '$key 读数取 strong',
      );
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('最近记录行：行程 journey / 充电 energy，行首图标取 strong', (tester) async {
    await openOverview(tester);
    await tester.scrollUntilVisible(
      find.text('最近充电').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    final driveRow = find
        .ancestor(of: find.text('最近行程'), matching: find.byType(MileafDataRow))
        .first;
    expect(hueOf<MileafDataRow>(tester, driveRow), journey);
    expect(
      iconNamed(tester, driveRow, MileafIconName.route).color,
      journey.strong(colors),
    );
    final chargeRow = find
        .ancestor(of: find.text('最近充电'), matching: find.byType(MileafDataRow))
        .first;
    expect(hueOf<MileafDataRow>(tester, chargeRow), energy);
    expect(
      iconNamed(tester, chargeRow, MileafIconName.bolt).color,
      energy.strong(colors),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('用车专题三行：节奏 dwell / 能耗 efficiency / 长期中性（无读数即无身份色）', (
    tester,
  ) async {
    await openOverview(tester);
    await tester.scrollUntilVisible(find.text('用车专题'), 200);
    await tester.pumpAndSettle();
    final rows = {
      '节奏': (dwell, MileafIconName.clock),
      '能耗': (efficiency, MileafIconName.leaf),
      // CL01/CL08：这一行没有读数（只是「续航与停放」的入口），与统计根页
      // 的「长期」章节卡同构——中性 + battery 字形，不着身份色。
      '长期': (null, MileafIconName.battery),
    };
    rows.forEach((title, spec) {
      final (hue, icon) = spec;
      final row = find
          .ancestor(of: find.text(title), matching: find.byType(MileafDataRow))
          .first;
      expect(hueOf<MileafDataRow>(tester, row), hue, reason: title);
      expect(
        iconNamed(tester, row, icon).color,
        hue == null ? colors.textSecondary : hue.strong(colors),
        reason: '$title 的身份图标取色',
      );
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets('按钮补图标：刷新 refresh、对比明细 chart、统计下钻 chart', (tester) async {
    await openOverview(tester);
    // 刷新仍是图标按钮（CL14：图标按钮只用于栏位与行尾）。
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is MileafIconButton &&
            widget.icon == MileafActionIcon.refresh,
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('电耗对比'), 200);
    await tester.pumpAndSettle();
    final detailRow = find
        .ancestor(
          of: find.text('查看对比明细'),
          matching: find.byType(MileafGroupRow),
        )
        .first;
    expect(
      tester.widget<MileafGroupRow>(detailRow).leading,
      MileafActionIcon.compare,
    );
    await tester.scrollUntilVisible(find.text('驾驶统计'), 200);
    await tester.pumpAndSettle();
    for (final label in const ['驾驶统计', '充电统计']) {
      final button = find.widgetWithText(TextButton, label);
      expect(button, findsOneWidget, reason: label);
      expect(
        find.descendant(
          of: button,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is MileafIcon && widget.name == MileafActionIcon.compare,
          ),
        ),
        findsOneWidget,
        reason: 'CL14 $label 图标在左、复述词义',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('CL07 首屏可见数据身份色相 ≤3，CL06 大面只有焦点卡 tint', (tester) async {
    await openOverview(tester, size: const Size(360, 800));
    final hues = visibleHues(tester);
    expect(hues.length, lessThanOrEqualTo(3), reason: '首屏色相 $hues');
    expect(hues, contains(journey));
    expect(tester.takeException(), isNull);
  });

  for (final scenario in const ['normal', 'empty']) {
    testWidgets('CL08 缺失读数与缺失记录不着语义色相（$scenario）', (tester) async {
      await openOverview(tester, scenario: scenario);
      await tester.scrollUntilVisible(find.text('本期账目'), 200);
      await tester.pumpAndSettle();
      final plate = find.byKey(const ValueKey('overview-reading-plate'));
      final cells = tester.widgetList<MetricBlock>(
        find.descendant(of: plate, matching: find.byType(MetricBlock)),
      );
      expect(cells, isNotEmpty);
      for (final cell in cells) {
        if (cell.value == null) {
          expect(cell.hue, isNull, reason: 'CL08 缺失读数不得着色：${cell.label}');
        } else {
          expect(cell.hue, isNotNull, reason: '有数据的格子必须带域色相：${cell.label}');
        }
      }
      await tester.scrollUntilVisible(find.text('最近充电').hitTestable(), 200);
      await tester.pumpAndSettle();
      final chargeRow = find
          .ancestor(of: find.text('最近充电'), matching: find.byType(MileafDataRow))
          .first;
      if (scenario == 'empty') {
        expect(hueOf<MileafDataRow>(tester, chargeRow), isNull);
        expect(
          iconNamed(tester, chargeRow, MileafIconName.bolt).color,
          colors.textMuted,
          reason: 'CL08 没有记录时图标退回中性',
        );
      } else {
        expect(hueOf<MileafDataRow>(tester, chargeRow), energy);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
