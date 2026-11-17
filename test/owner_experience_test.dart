import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';

import 'overview_visualization_test.dart';
import 'statistics_usage_test.dart' show usageClient;
import 'statistics_test.dart' show openStats, custom;
import 'support/statistics_insights_fixture.dart';
import 'charging_expansion_test.dart' show chargingStatsV2;

void main() {
  testWidgets('重复点击统计保留自定义期间且不发请求', (tester) async {
    final seen = <Uri>[];
    await openStats(
      tester,
      usageClient(seen),
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await custom(tester, '2026-10-02', '2026-10-03');
    expect(
      tester.widget<StatusChip>(find.widgetWithText(StatusChip, '本月')).selected,
      isFalse,
    );
    seen.clear();
    await tester.tap(
      find.descendant(of: find.byType(MileafNavBar), matching: find.text('统计')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<StatusChip>(find.widgetWithText(StatusChip, '本月')).selected,
      isFalse,
    );
    expect(seen, isEmpty);
  });

  testWidgets('概览使用已声明配对净电耗和费用覆盖，旧值不冒充配对值', (tester) async {
    await openOverviewVisual(
      tester,
      (r) async {
        if (r.url.path.endsWith('/summary')) {
          return overviewResponse(overviewFixture('summary'));
        }
        if (r.url.path.endsWith('/meta')) {
          final meta = statisticsInsightsMeta();
          meta['charging_experience'] = {
            'contract_version': 'charging-experience-v1',
            'fields': <String, bool>{},
          };
          return overviewResponse(meta);
        }
        if (r.url.queryParameters['kind'] == 'charging') {
          return overviewResponse(chargingStatsV2());
        }
        final reference =
            DateTime.parse(r.url.queryParameters['to']!).month == 9;
        final stats = statisticsInsightsFixture(
          r.url,
          consumption: reference ? 200 : 187.5,
        );
        stats['totals']['consumption_wh_km_net'] = 91;
        return overviewResponse(stats);
      },
      now: () => DateTime.utc(2026, 10, 28, 11),
      briefing: true,
      ownerCapabilities: true,
    );
    // P01：读值第三行把参照与差值写成一句（CP03 用「持平」写进句子）。
    expect(find.textContaining('，持平'), findsWidgets);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('overview-reading-plate')),
        matching: find.textContaining('188'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('overview-reading-plate')),
        matching: find.text('已记录费用'),
      ),
      findsOneWidget,
    );
    // 电耗对比：配对净电耗与上月同期的实际差值（旧「配对净电耗较参照差」迁到这里）。
    await tester.scrollUntilVisible(find.text('电耗对比').hitTestable(), 150);
    await tester.pumpAndSettle();
    // 对照句按「电耗」口径写成句子（不再有箭头与「差 +x」）。
    expect(find.text('电耗与上月同期相同'), findsOneWidget);
    final page = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('关于这些数据').hitTestable(),
      150,
      scrollable: page,
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('记录与缺失').hitTestable(),
      150,
      scrollable: page,
    );
    await tester.tap(find.text('记录与缺失').hitTestable());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('费用记录：8 次中 2 次有费用'),
      150,
      scrollable: page,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('费用记录：8 次中 2 次有费用'), findsOneWidget);
    // 概览的数值按 0 位小数写（187.5 → 188）。
    expect(find.textContaining('有效行程电耗 188 Wh/km'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('口径与估算').hitTestable(),
      150,
      scrollable: page,
    );
    await tester.tap(find.text('口径与估算').hitTestable());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('充入均价按充入电池的电量计'),
      150,
      scrollable: page,
    );
    expect(find.textContaining('充入均价按充入电池的电量计'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('声明配对能力但统计缺字段时不把旧净电耗当配对值', (tester) async {
    await openOverviewVisual(
      tester,
      (r) async {
        if (r.url.path.endsWith('/meta')) {
          return overviewResponse(statisticsInsightsMeta());
        }
        return overviewResponse(
          overviewFixture(
            r.url.path.endsWith('/summary')
                ? 'summary'
                : r.url.queryParameters['kind'] == 'charging'
                ? 'charging-stats'
                : 'driving-stats',
          ),
        );
      },
      briefing: true,
      ownerCapabilities: true,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('overview-plate-net')),
        matching: find.text('—'),
      ),
      findsOneWidget,
      reason: '缺失的净电耗落在自己的格子里',
    );
    // 缺配对字段：不给「有效行程电耗」，也不编造区间比较结论。
    final page = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('电耗对比').hitTestable(),
      150,
      scrollable: page,
    );
    await tester.pumpAndSettle();
    // 配对口径缺失时对照句只说「口径未确认」，不给旧值差值。
    expect(find.text('数据口径未确认，暂不比较'), findsOneWidget);
    expect(find.textContaining('电耗比上月同期'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('关于这些数据').hitTestable(),
      150,
      scrollable: page,
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('记录与缺失').hitTestable(),
      150,
      scrollable: page,
    );
    await tester.tap(find.text('记录与缺失').hitTestable());
    await tester.pumpAndSettle();
    expect(find.textContaining('有效行程电耗'), findsNothing);
    expect(find.textContaining('缺失显示 —，未知不等于 0'), findsOneWidget);
  });
  testWidgets('车主从概览直达用车节奏，沿用本月与车辆且不提前加载专题', (tester) async {
    final seen = <Uri>[];
    final client = usageClient(seen);
    await openOverviewVisual(
      tester,
      (r) async {
        if (r.url.path.endsWith('/meta')) {
          return overviewResponse(
            statisticsInsightsMeta(
              features: {'driving_coverage': true, 'driving_analysis': true},
            ),
          );
        }
        if (r.url.queryParameters['kind'] == 'charging') {
          return overviewResponse(overviewFixture('charging-stats'));
        }
        return client.get(r.url);
      },
      now: () => DateTime.utc(2026, 10, 28, 11),
      briefing: true,
      ownerCapabilities: true,
    );
    expect(seen.where((u) => u.path.endsWith('/driving-analysis')), isEmpty);
    await tester.scrollUntilVisible(find.text('节奏').hitTestable(), 160);
    await tester.tap(find.text('节奏').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('用车 12 天'), findsOneWidget);
    final query = seen.lastWhere((u) => u.path.endsWith('/driving-analysis'));
    expect(query.path, contains('/vehicles/1/'));
    expect(query.queryParameters['tz'], 'Asia/Shanghai');
    expect(query.queryParameters['view'], 'usage');
    expect(
      DateTime.parse(query.queryParameters['from']!),
      DateTime.utc(2026, 9, 30, 16),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(
      find.descendant(of: find.byType(MileafNavBar), matching: find.text('统计')),
    );
    await tester.pumpAndSettle();
    expect(find.text('用车 12 天'), findsOneWidget);
  });

  testWidgets('统计主结果包含驾驶时长和有效趟数，节奏有显式入口', (tester) async {
    await openStats(
      tester,
      usageClient([]),
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    final page = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('关于这些数据').hitTestable(),
      120,
      scrollable: page,
    );
    await tester.scrollUntilVisible(
      find.text('记录与缺失').hitTestable(),
      120,
      scrollable: page,
    );
    await tester.tap(find.text('记录与缺失').hitTestable());
    await tester.pumpAndSettle();
    // CP03：驾驶时长写「1 小时」，趟数紧随其后。
    await tester.scrollUntilVisible(
      find.textContaining('有记录的驾驶时长 1 小时'),
      120,
      scrollable: page,
    );
    expect(find.textContaining('有记录的驾驶时长 1 小时'), findsOneWidget);
    expect(find.textContaining('5 趟有记录'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('节奏').hitTestable(),
      -240,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('节奏').first);
    await tester.pumpAndSettle();
    expect(find.text('短途、中途与长途'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
