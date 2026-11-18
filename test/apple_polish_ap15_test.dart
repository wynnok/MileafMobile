import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/map/map_consent.dart';
import 'package:mileaf/src/map/map_privacy_page.dart';

import 'charging_expansion_test.dart' show expansionResponse;
import 'charging_test.dart' show app, navTab;
import 'statistics_charging_test.dart' show statisticsChargingResponse;
import 'statistics_insights_test.dart' show comparisonClient;
import 'statistics_test.dart' show custom, fixture, openStats;
import 'support/map_key_fixture.dart' show configuredMapKeys;

/// AP15（收口）：双轴复核确认的文案最小修正——CP02 术语、CP04 共享日期格式、
/// CP09.1 点号拼接。S01–S08、Key、回调、路由与冻结符号签名均不变。
void main() {
  testWidgets('统计页口径脚注、折叠行与自定义期间走 CP02/CP04 共享格式', (tester) async {
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) {
        return fixture('vehicles');
      }
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      return fixture(
        r.url.queryParameters['kind'] == 'charging'
            ? 'charging-stats'
            : 'driving-stats',
      );
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 3, 30, 12),
      () => 'UTC',
    );
    // CP02：归期退役，口径句与 CP07 常用句对齐。
    await tester.scrollUntilVisible(find.text('按开始日期统计，仅统计已完成的行程'), 300);
    expect(find.text('按开始日期统计，仅统计已完成的行程'), findsOneWidget);
    expect(find.textContaining('按开始时间归期'), findsNothing);
    // CP04/CP09.1：折叠行日期走共享格式化器（DF1），日期与数值不再用「·」拼接。
    await tester.scrollUntilVisible(
      find.textContaining('12月31日 620.0 km'),
      300,
    );
    final drivingFold = tester
        .widget<Text>(find.textContaining('12月31日 620.0 km').first)
        .data!;
    expect(drivingFold.startsWith('2025年12月31日 620.0 km'), isTrue);
    expect(drivingFold.contains('·'), isFalse);
    // 充电区间指标由「充电统计」下钻加载（onStatistics 回调不变）。
    await tester.tap(find.text('充电统计'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('按结束日期统计，仅含已完成的充电'), 300);
    expect(find.text('按结束日期统计，仅含已完成的充电'), findsOneWidget);
    expect(find.textContaining('按结束时间归期'), findsNothing);
    await tester.scrollUntilVisible(
      find.textContaining('12月31日 20.00 kWh'),
      300,
    );
    final chargingFold = tester
        .widget<Text>(find.textContaining('12月31日 20.00 kWh').first)
        .data!;
    expect(chargingFold.contains('·'), isFalse);
    // CP04：自定义期间行由共享格式化器输出 DF3（– 连接号）。
    await custom(tester, '2026-03-02', '2026-03-04');
    // 期间行与卡片副标题（_range）都来自同一共享格式化器。
    expect(find.text('3月2日–4日'), findsWidgets);
    expect(find.textContaining(' 至 '), findsNothing);
    // CP04：图轴不再出现 M/D 斜杠刻度。
    expect(find.textContaining(RegExp(r'^\d{1,2}/\d{1,2}$')), findsNothing);
  });

  testWidgets('补能专题副标题改「按结束日期统计」，图轴不再自拼 M/D', (tester) async {
    await openStats(
      tester,
      MockClient((request) async => statisticsChargingResponse(request)),
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
    expect(find.text('按结束日期统计'), findsOneWidget);
    expect(find.text('按结束日'), findsNothing);
    expect(find.textContaining(RegExp(r'^\d{1,2}/\d{1,2}$')), findsNothing);
  });

  testWidgets('补能章节覆盖句改为「N 次中 M 次有费用」一句式', (tester) async {
    await openStats(
      tester,
      comparisonClient(),
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await tester.scrollUntilVisible(
      find.textContaining('次有费用'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('次中'), findsWidgets);
    expect(find.textContaining('次有费用'), findsWidgets);
    expect(find.textContaining('次有记录'), findsNothing);
    expect(find.textContaining(' · '), findsNothing);
  });

  testWidgets('充电页自定义胶囊语义标签走 CP02/DF3', (tester) async {
    await tester.pumpWidget(app(MockClient((r) async => expansionResponse(r))));
    await tester.pumpAndSettle();
    await tester.tap(navTab('充电'));
    await tester.pumpAndSettle();
    final chip = tester.widget<StatusChip>(
      find.widgetWithText(StatusChip, '自定义').first,
    );
    expect(chip.semanticLabel, contains('按结束日期统计'));
    expect(chip.semanticLabel, isNot(contains('归期')));
    expect(chip.semanticLabel, contains('–'));
  });

  testWidgets('地图 Key 待重启状态句不再用点号拼接', (tester) async {
    final keys = await configuredMapKeys();
    keys.keyForMap();
    await keys.save('b' * 32);
    await tester.pumpWidget(
      MaterialApp(
        theme: mileafTheme(Brightness.light),
        home: MapPrivacyPage(
          consent: MapConsentController(),
          providerName: '高德地图',
          keys: keys,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('已保存，重新启动后生效'), findsOneWidget);
    expect(find.text('已保存 · 重新启动后生效'), findsNothing);
  });
}
