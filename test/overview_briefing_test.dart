import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mileaf/src/design/components/chip.dart';
import 'package:mileaf/src/workspace.dart';

import 'overview_visualization_test.dart';
import 'support/statistics_insights_fixture.dart';
import 'charging_test.dart' show MemoryCurrency;
import 'overview_test.dart' show background, foreground;

Finder battery(int level) => find.bySemanticsLabel('电池电量 $level%');

void main() {
  testWidgets('A概览辅助读数显示已知费用与币种缺失，并可切到费用趋势图', (tester) async {
    await openOverviewVisual(
      tester,
      (r) async => overviewResponse(
        overviewFixture(
          r.url.path.endsWith('/summary')
              ? 'summary'
              : r.url.queryParameters['kind'] == 'charging'
              ? 'charging-stats'
              : 'driving-stats',
        ),
      ),
      briefing: true,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('overview-reading-plate')),
        matching: find.text('72'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('币种未记录'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('费用'), 150);
    await Scrollable.ensureVisible(
      tester.element(find.text('费用')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('费用'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('已知费用趋势图表'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('C概览前台跨月下拉失败不把上月数据标为本月', (tester) async {
    final semantics = tester.ensureSemantics();
    var now = DateTime.utc(2026, 3, 31, 12), fail = false;
    await openOverviewVisual(
      tester,
      (r) async {
        if (r.url.path.endsWith('/summary')) {
          final b = overviewFixture('summary');
          if (fail) b['battery']['level'] = 21;
          return overviewResponse(b);
        }
        if (fail) return http.Response('', 503);
        return overviewResponse(
          overviewFixture(
            r.url.queryParameters['kind'] == 'charging'
                ? 'charging-stats'
                : 'driving-stats',
          ),
        );
      },
      briefing: true,
      now: () => now,
    );
    await tester.scrollUntilVisible(find.textContaining('960'), 120);
    expect(find.textContaining('960'), findsOneWidget);
    now = DateTime.utc(2026, 4, 1, 12);
    fail = true;
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(battery(21), -150);
    await tester.pumpAndSettle();
    expect(battery(21), findsOneWidget);
    expect(battery(68), findsNothing);
    // The failed stats must be surfaced as unavailable, never silently shown as
    // the new month's current result.
    expect(find.textContaining('服务暂不可用'), findsWidgets);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
  testWidgets('C概览费用零与币种、AC/DC 使用服务端原值在数据说明层', (tester) async {
    final currency = MemoryCurrency()
      ..values['https://example.com/prefix'] = 'CNY';
    final semantics = tester.ensureSemantics();
    try {
      await openOverviewVisual(
        tester,
        (r) async {
          if (r.url.path.endsWith('/summary')) {
            return overviewResponse(overviewFixture('summary'));
          }
          if (r.url.queryParameters['kind'] == 'charging') {
            final b = overviewFixture('charging-stats');
            b['totals']['cost'] = 0;
            b['totals']['cost_per_kwh'] = null;
            return overviewResponse(b);
          }
          return overviewResponse(overviewFixture('driving-stats'));
        },
        briefing: true,
        currencyPreferences: currency,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('overview-reading-plate')),
          matching: find.text('¥0'),
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.text('数据说明与更多').hitTestable(), 150);
      await tester.pumpAndSettle();
      await tester.tap(find.text('数据说明与更多'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('AC 120.00 kWh'),
        150,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('AC 120.00 kWh'), findsOneWidget);
      expect(find.textContaining('未知 —'), findsOneWidget);
      expect(find.textContaining('14.3 %'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('C概览补能局部失败重试只读补能且不阻塞驾驶图', (tester) async {
    var fail = true;
    final calls = <String>[];
    await openOverviewVisual(
      tester,
      (r) async {
        if (r.url.path.endsWith('/summary')) {
          calls.add('summary');
          return overviewResponse(overviewFixture('summary'));
        }
        if (r.url.queryParameters['kind'] == 'charging') {
          calls.add('charging');
          return fail
              ? http.Response('', 503)
              : overviewResponse(overviewFixture('charging-stats'));
        }
        calls.add('driving');
        return overviewResponse(monthTrend());
      },
      briefing: true,
      settle: false,
    );
    expect(find.textContaining('服务暂不可用'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('960'), 120);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('960'), findsOneWidget);
    fail = false;
    final previousCalls = List<String>.from(calls);
    await tester.scrollUntilVisible(find.text('重试补能'), -120);
    await Scrollable.ensureVisible(
      tester.element(find.text('重试补能')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('重试补能'));
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(calls.skip(previousCalls.length), ['charging']);
    expect(find.textContaining('服务暂不可用'), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('A概览数据说明中的充电统计入口沿用相同日期范围', (tester) async {
    final queries = <Map<String, String>>[];
    await openOverviewVisual(tester, (request) async {
      if (request.url.path.endsWith('/summary')) {
        return overviewResponse(overviewFixture('summary'));
      }
      queries.add(request.url.queryParameters);
      return overviewResponse(
        overviewFixture(
          request.url.queryParameters['kind'] == 'charging'
              ? 'charging-stats'
              : 'driving-stats',
        ),
      );
    }, briefing: true);
    await tester.tap(find.text('近7天'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('数据说明与更多'), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('数据说明与更多'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('充电统计'), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电统计'));
    await tester.pumpAndSettle();
    expect(
      queries,
      contains(
        allOf(
          containsPair('kind', 'charging'),
          containsPair('from', '2026-03-08T16:00:00.000Z'),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
  for (final date in [
    DateTime.utc(2026, 3, 31, 12),
    DateTime.utc(2026, 3, 15, 6, 30),
    DateTime.utc(2026, 11, 8, 6, 30),
  ]) {
    testWidgets('C概览不可对齐的月底或DST比较不发送猜测基期 ${date.toIso8601String()}', (
      tester,
    ) async {
      final drivingQueries = <Map<String, String>>[];
      await openOverviewVisual(
        tester,
        (r) async {
          if (r.url.path.endsWith('/summary')) {
            return overviewResponse(overviewFixture('summary'));
          }
          if (r.url.queryParameters['kind'] == 'charging') {
            return overviewResponse(overviewFixture('charging-stats'));
          }
          drivingQueries.add(r.url.queryParameters);
          return overviewResponse(overviewFixture('driving-stats'));
        },
        briefing: true,
        now: () => date,
        calendar: () async => CalendarContext('America/New_York'),
      );
      if (date.day != 31) {
        drivingQueries.clear();
        await tester.tap(find.text('近7天'));
        await tester.pumpAndSettle();
      }
      expect(drivingQueries, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('C概览近7天与基期使用同一 IANA 日历截止且比较采用服务端净电耗', (tester) async {
    final requests = <Map<String, String>>[];
    await openOverviewVisual(
      tester,
      (request) async {
        if (request.url.path.endsWith('/summary')) {
          return overviewResponse(overviewFixture('summary'));
        }
        final query = request.url.queryParameters;
        requests.add(query);
        if (query['kind'] == 'charging') {
          return overviewResponse(overviewFixture('charging-stats'));
        }
        final body = overviewFixture('driving-stats');
        body['totals']['consumption_wh_km_net'] =
            query['from'] == '2026-03-01T16:00:00.000Z' ? 166 : 158;
        return overviewResponse(body);
      },
      now: () => DateTime.utc(2026, 3, 15, 12),
      briefing: true,
    );
    await tester.tap(find.text('近7天'));
    await tester.pumpAndSettle();
    expect(
      requests,
      contains(
        allOf(
          containsPair('kind', 'driving'),
          containsPair('from', '2026-03-08T16:00:00.000Z'),
          containsPair('to', '2026-03-15T12:00:00.000Z'),
        ),
      ),
    );
    expect(
      requests,
      contains(
        allOf(
          containsPair('kind', 'driving'),
          containsPair('from', '2026-03-01T16:00:00.000Z'),
          containsPair('to', '2026-03-08T12:00:00.000Z'),
        ),
      ),
    );
    // The server net value (158 vs 166) drives the comparison wording.
    await tester.scrollUntilVisible(find.text('数据说明与更多').hitTestable(), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('数据说明与更多'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('估算净电耗比前一同长区间低 8 Wh/km'), 150);
    expect(find.text('估算净电耗比前一同长区间低 8 Wh/km'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('C概览补能失败重返前台尊重驾驶独立TTL', (tester) async {
    var now = DateTime.utc(2026, 3, 15, 12);
    final requests = <String>[];
    await openOverviewVisual(
      tester,
      (r) async {
        if (r.url.path.endsWith('/summary')) {
          return overviewResponse(overviewFixture('summary'));
        }
        final kind = r.url.queryParameters['kind']!;
        requests.add(kind);
        if (kind == 'charging') return http.Response('', 503);
        return overviewResponse(overviewFixture('driving-stats'), maxAge: 3600);
      },
      briefing: true,
      now: () => now,
    );
    final before = requests.length;
    now = now.add(const Duration(seconds: 40));
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(requests.skip(before), ['charging']);
  });
  testWidgets('C概览比较刷新失败保留配对数值和原区间', (tester) async {
    var now = DateTime.utc(2026, 3, 15, 12), fail = false;
    await openOverviewVisual(
      tester,
      (r) async {
        if (r.url.path.endsWith('/meta')) {
          return overviewResponse(statisticsInsightsMeta());
        }
        if (r.url.path.endsWith('/summary')) {
          return overviewResponse(overviewFixture('summary'));
        }
        if (r.url.queryParameters['kind'] == 'charging') {
          return overviewResponse(overviewFixture('charging-stats'));
        }
        final baseline =
            DateTime.parse(r.url.queryParameters['to']!).month == 2;
        if (baseline && fail) return http.Response('', 503);
        return overviewResponse(
          statisticsInsightsFixture(r.url, consumption: baseline ? 166 : 158),
        );
      },
      briefing: true,
      now: () => now,
      ownerCapabilities: true,
    );
    fail = true;
    now = now.add(const Duration(seconds: 10));
    await tester.drag(find.byType(RefreshIndicator), const Offset(0, 300));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('数据说明与更多').hitTestable(), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('数据说明与更多'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('配对估算净电耗'), 150);
    // The failed refresh must keep both the paired value and its original range.
    expect(find.textContaining('比较暂不可用'), findsWidgets);
    expect(find.text('配对估算净电耗'), findsOneWidget);
    expect(find.textContaining('158'), findsWidgets);
    expect(find.text('比较区间与口径'), findsOneWidget);
  });
  testWidgets('C概览切区间拒绝迟到旧补能与旧比较', (tester) async {
    final oldCharge = Completer<http.Response>(),
        oldPrior = Completer<http.Response>();
    await openOverviewVisual(
      tester,
      (r) async {
        if (r.url.path.endsWith('/summary')) {
          return overviewResponse(overviewFixture('summary'));
        }
        final from = r.url.queryParameters['from'];
        if (r.url.queryParameters['kind'] == 'charging') {
          if (from == '2026-02-28T16:00:00.000Z') return oldCharge.future;
          return overviewResponse(overviewFixture('charging-stats'));
        }
        if (from == '2026-01-31T16:00:00.000Z') return oldPrior.future;
        return overviewResponse(overviewFixture('driving-stats'));
      },
      briefing: true,
      settle: false,
    );
    await tester.tap(find.text('近7天'));
    await tester.pumpAndSettle();
    oldCharge.complete(overviewResponse(overviewFixture('charging-stats')));
    oldPrior.complete(overviewResponse(overviewFixture('driving-stats')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<StatusChip>(find.widgetWithText(StatusChip, '近7天'))
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
