// AP11 统计首页、全部指标与期间选择（P06/P15）的票内测试。
// 覆盖：期间行胶囊与唯一刷新圆钮（PD10/R27）、统计期间接入共享日期区间弹层
// （预设、键盘路径、730×24 小时上界、脚注）、长期索引两入口、全部指标分组卡。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/src/design/components/components.dart';

import 'statistics_insights_test.dart' show comparisonClient;
import 'statistics_test.dart' show fixture, openStats;
import 'support/statistics_insights_fixture.dart';

void main() {
  testWidgets('统计期间行：本月、近7天、自定义胶囊与唯一刷新圆钮', (tester) async {
    await openStats(
      tester,
      comparisonClient(),
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    expect(find.widgetWithText(StatusChip, '本月'), findsOneWidget);
    expect(
      tester.widget<StatusChip>(find.widgetWithText(StatusChip, '本月')).selected,
      isTrue,
    );
    expect(find.widgetWithText(StatusChip, '近7天'), findsOneWidget);
    // R27/CP06：期间入口统一为「自定义」，旧「自定义日期」退出。
    expect(find.widgetWithText(StatusChip, '自定义'), findsOneWidget);
    expect(find.text('自定义日期'), findsNothing);
    // PD10：期间行尾部有且只有一个刷新圆钮。
    expect(find.byTooltip('刷新统计'), findsOneWidget);
  });

  testWidgets('自定义打开共享日期区间弹层，预设直接应用对应期间', (tester) async {
    final queries = <Map<String, String>>[];
    await openStats(
      tester,
      insightsClient(queries),
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await tester.tap(find.widgetWithText(StatusChip, '自定义'));
    await tester.pumpAndSettle();
    // R27：贴边弹层、标题「选择日期」、两行开始/结束、脚注「包含结束当天」。
    expect(find.text('选择日期'), findsOneWidget);
    expect(find.text('开始'), findsOneWidget);
    expect(find.text('结束'), findsOneWidget);
    expect(find.text('包含结束当天'), findsOneWidget);
    // 预设在弹层内：本周、近7天、本月、本年。
    for (final preset in ['本周', '近7天', '本月', '本年']) {
      expect(
        find.descendant(
          of: find.byType(MileafSheetFrame),
          matching: find.widgetWithText(StatusChip, preset),
        ),
        findsOneWidget,
        reason: '预设 $preset 在日期弹层内',
      );
    }
    await tester.tap(
      find.descendant(
        of: find.byType(MileafSheetFrame),
        matching: find.widgetWithText(StatusChip, '近7天'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MileafSheetFrame), findsNothing);
    // 近7天窗口发出本期查询（参照与充电查询随后，取 any 而非 last）。
    expect(
      queries.any(
        (q) =>
            q['kind'] == 'driving' &&
            q['from'] == '2026-10-21T16:00:00.000Z' &&
            q['to'] == '2026-10-28T11:00:00.000Z',
      ),
      isTrue,
    );
  });

  testWidgets('键盘路径应用自定义区间，730×24 小时上界拒绝且不发请求', (tester) async {
    final queries = <Map<String, String>>[];
    await openStats(
      tester,
      insightsClient(queries),
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await tester.tap(find.widgetWithText(StatusChip, '自定义'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('改为输入'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('date-range-start-input')),
      '2024-01-01',
    );
    await tester.enterText(
      find.byKey(const ValueKey('date-range-end-input')),
      '2026-10-28',
    );
    final before = queries.length;
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    // CP07：上界文案按文案规范改写。
    expect(find.textContaining('最长可选 730 天'), findsOneWidget);
    expect(queries.length, before, reason: '超上界不发请求');
    await tester.enterText(
      find.byKey(const ValueKey('date-range-start-input')),
      '2026-08-01',
    );
    await tester.tap(find.text('应用'));
    await tester.pumpAndSettle();
    expect(find.byType(MileafSheetFrame), findsNothing);
    expect(
      queries.any(
        (q) =>
            q['kind'] == 'driving' &&
            q['from'] == '2026-07-31T16:00:00.000Z' &&
            q['to'] == '2026-10-28T11:00:00.000Z',
      ),
      isTrue,
    );
  });

  testWidgets('长期索引两入口为分组行，能力未声明时给出不支持说明', (tester) async {
    await openStats(
      tester,
      comparisonClient(),
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await tester.scrollUntilVisible(
      find.text('长期').hitTestable(),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('长期').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byType(MileafGroupRow), findsNWidgets(2));
    expect(find.text('展开长期续航'), findsOneWidget);
    expect(find.text('展开停放观察'), findsOneWidget);
    expect(find.textContaining('当前站点暂不支持'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('全部指标为分组卡列表，说明行原位展开', (tester) async {
    await openStats(
      tester,
      comparisonClient(),
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(TextButton, '全部指标').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.widgetWithText(TextButton, '全部指标'));
    await tester.pumpAndSettle();
    // CP05：页面标题改「全部指标」。
    expect(find.text('全部指标'), findsWidgets);
    expect(find.byType(MileafGroupRow), findsNWidgets(5));
    // 底下的首页专题卡仍在树中，专题名允许多处出现。
    for (final label in ['节奏', '能耗', '补能', '长期']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('原始统计指标'), findsOneWidget);
    expect(find.byType(MileafDisclosure), findsOneWidget);
    expect(find.textContaining('各专题只回答一个问题'), findsNothing);
    await tester.tap(find.text('数据说明'));
    await tester.pumpAndSettle();
    expect(find.textContaining('各专题只回答一个问题'), findsOneWidget);
  });
}

http.Client insightsClient(List<Map<String, String>> queries) =>
    MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      if (r.url.path.endsWith('/meta')) {
        return http.Response(jsonEncode(statisticsInsightsMeta()), 200);
      }
      queries.add(r.url.queryParameters);
      if (r.url.queryParameters['kind'] == 'charging') {
        return fixture('charging-stats');
      }
      return http.Response(jsonEncode(statisticsInsightsFixture(r.url)), 200);
    });
