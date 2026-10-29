import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'overview_visualization_test.dart';
import 'statistics_usage_test.dart' show usageClient;
import 'statistics_test.dart' show openStats;
import 'support/statistics_insights_fixture.dart';
import 'charging_expansion_test.dart' show chargingStatsV2;

void main() {
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
    expect(find.text('驾驶净电耗 · 配对估算'), findsOneWidget);
    expect(find.text('188 Wh/km'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('费用有记录 2 / 8 次'), 120);
    expect(find.textContaining('有效入电均价 0.4'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('配对净电耗较参照差 -12.5'),
      150,
    );
    expect(find.textContaining('配对净电耗较参照差 -12.5'), findsOneWidget);
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
    expect(find.text('驾驶净电耗 · 配对估算'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('未用旧净电耗替代配对值'), 150);
    expect(find.textContaining('未用旧净电耗替代配对值'), findsOneWidget);
    expect(find.textContaining('配对净电耗较参照差'), findsNothing);
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
    await tester.scrollUntilVisible(find.text('我的用车节奏').hitTestable(), 160);
    await tester.tap(find.text('我的用车节奏'));
    await tester.pumpAndSettle();
    expect(find.text('活跃 12 天'), findsOneWidget);
    final query = seen.lastWhere((u) => u.path.endsWith('/driving-analysis'));
    expect(query.path, contains('/vehicles/1/'));
    expect(query.queryParameters['tz'], 'Asia/Shanghai');
    expect(query.queryParameters['view'], 'usage');
    expect(
      DateTime.parse(query.queryParameters['from']!),
      DateTime.utc(2026, 9, 30, 16),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(NavigationDestination, '统计'));
    await tester.pumpAndSettle();
    expect(find.text('期间里程'), findsOneWidget);
  });

  testWidgets('统计主结果包含驾驶时长和有效趟数，节奏有显式入口', (tester) async {
    await openStats(
      tester,
      usageClient([]),
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await tester.scrollUntilVisible(
      find.text('记录驾驶时长'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('记录驾驶时长'), findsOneWidget);
    expect(find.text('60 分钟'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, '节奏'));
    await tester.pumpAndSettle();
    expect(find.text('短途、中途与长途'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
