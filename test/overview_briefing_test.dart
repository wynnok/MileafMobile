import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mileaf/src/workspace.dart';

import 'overview_visualization_test.dart';
import 'charging_test.dart' show MemoryCurrency;
import 'overview_test.dart' show background, foreground;

void main() {
  testWidgets('审查回归：四个主数可通过读屏tap语义切图', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
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
      final node = tester.getSemantics(
        find.bySemanticsLabel('已知充电费用 72（币种未知），仅含费用已知记录'),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.semantics.tap(find.semantics.byLabel('已知充电费用 72（币种未知），仅含费用已知记录'));
      await tester.pump();
      await tester.scrollUntilVisible(find.bySemanticsLabel('已知费用趋势图表'), 120);
      expect(find.bySemanticsLabel('已知费用趋势图表'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('审查回归：前台跨月下拉失败不能把上月数据标为本月', (tester) async {
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
    expect(find.text('160.0 kWh'), findsOneWidget);
    now = DateTime.utc(2026, 4, 1, 12);
    fail = true;
    await tester.drag(find.byType(RefreshIndicator), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.text('160.0 kWh'), findsNothing);
    expect(find.text('960.0 km'), findsNothing);
    expect(find.text('21 %'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('审查回归：补能失败重返前台尊重驾驶独立TTL', (tester) async {
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
  testWidgets('审查回归：比较刷新失败保留配对数值和原区间', (tester) async {
    var now = DateTime.utc(2026, 3, 15, 12), fail = false;
    await openOverviewVisual(
      tester,
      (r) async {
        if (r.url.path.endsWith('/summary')) {
          return overviewResponse(overviewFixture('summary'));
        }
        if (r.url.queryParameters['kind'] == 'charging') {
          return overviewResponse(overviewFixture('charging-stats'));
        }
        final baseline =
            DateTime.parse(r.url.queryParameters['to']!).month == 2;
        if (baseline && fail) return http.Response('', 503);
        final b = overviewFixture('driving-stats');
        b['totals']['consumption_wh_km_net'] = baseline ? 166 : 158;
        return overviewResponse(b);
      },
      briefing: true,
      now: () => now,
    );
    fail = true;
    now = now.add(const Duration(seconds: 10));
    await tester.tap(find.byTooltip('刷新里程趋势'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('保留上次比较快照'), 150);
    expect(find.text('估算净电耗比前一同长区间低 8 Wh/km'), findsOneWidget);
    expect(find.textContaining('保留上次比较快照'), findsOneWidget);
  });
  testWidgets('费用均价与AC/DC使用服务端原值，未知和真实零保持区别', (tester) async {
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
      expect(find.bySemanticsLabel('已知充电费用 0 CNY，仅含费用已知记录'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('AC'), 150);
      await tester.pumpAndSettle();
      expect(find.text('120.00 kWh'), findsOneWidget);
      expect(find.text('20.00 kWh'), findsOneWidget);
      expect(find.textContaining('14.3 %'), findsOneWidget);
      expect(find.text('—（缺失）/kWh'), findsOneWidget);
      expect(find.textContaining('覆盖率'), findsNothing);
      expect(find.textContaining('未知能量'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('补能局部失败与迟到的比较不阻塞驾驶图，补能重试不重读其他资源', (tester) async {
    final prior = Completer<http.Response>();
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
        if (r.url.queryParameters['from'] == '2026-01-31T16:00:00.000Z') {
          calls.add('comparison');
          return prior.future;
        }
        calls.add('driving');
        return overviewResponse(monthTrend());
      },
      briefing: true,
      settle: false,
    );
    expect(find.textContaining('服务暂不可用'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('里程读数 30.5 km'), 120);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('里程读数 30.5 km'), findsOneWidget);
    fail = false;
    final previousCalls = List<String>.from(calls);
    await tester.scrollUntilVisible(find.text('重试补能'), -120);
    await tester.pump();
    await tester.tap(find.text('重试补能'));
    for (var i = 0; i < 8; i++) {
      await tester.pump();
    }
    expect(calls.skip(previousCalls.length), ['charging']);
    expect(find.textContaining('服务暂不可用'), findsNothing);
    prior.complete(overviewResponse(overviewFixture('driving-stats')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('切区间拒绝迟到旧补能与旧比较，使用新期间总计', (tester) async {
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
          final body = overviewFixture('charging-stats');
          body['totals']['energy_added_kwh'] = 23.7;
          return overviewResponse(body);
        }
        if (from == '2026-01-31T16:00:00.000Z') return oldPrior.future;
        return overviewResponse(overviewFixture('driving-stats'));
      },
      briefing: true,
      settle: false,
    );
    await tester.tap(find.text('近7天'));
    await tester.pumpAndSettle();
    expect(find.text('23.7 kWh'), findsOneWidget);
    oldCharge.complete(overviewResponse(overviewFixture('charging-stats')));
    oldPrior.complete(overviewResponse(overviewFixture('driving-stats')));
    await tester.pumpAndSettle();
    expect(find.text('23.7 kWh'), findsOneWidget);
    expect(find.text('160.0 kWh'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final date in [
    DateTime.utc(2026, 3, 31, 12),
    DateTime.utc(2026, 3, 15, 6, 30),
    DateTime.utc(2026, 11, 8, 6, 30),
  ]) {
    testWidgets('不可对齐的月底或DST比较不发送猜测基期 ${date.toIso8601String()}', (
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
      await tester.scrollUntilVisible(find.textContaining('没有可对齐'), 150);
      expect(find.textContaining('没有可对齐'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('概览补能入口下钻到相同日期范围的充电统计', (tester) async {
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
    await tester.scrollUntilVisible(find.text('充电统计'), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电统计'));
    await tester.pumpAndSettle();
    expect(find.text('2026-03-09 至 2026-03-15'), findsOneWidget);
    expect(find.text('充电结果'), findsOneWidget);
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
  testWidgets('近7天与基期使用同一IANA日历截止且比较采用服务端净电耗', (tester) async {
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
    await tester.scrollUntilVisible(find.text('估算净电耗比前一同长区间低 8 Wh/km'), 150);
    expect(find.text('估算净电耗比前一同长区间低 8 Wh/km'), findsOneWidget);
    await tester.ensureVisible(find.text('查看比较依据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看比较依据'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Asia/Shanghai'), findsWidgets);
    expect(find.textContaining('基期  166 Wh/km'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('用车简报用服务端期间总计展示四个主数并切换费用主图', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await openOverviewVisual(tester, (request) async {
        if (request.url.path.endsWith('/summary')) {
          return overviewResponse(overviewFixture('summary'));
        }
        return overviewResponse(
          overviewFixture(
            request.url.queryParameters['kind'] == 'charging'
                ? 'charging-stats'
                : 'driving-stats',
          ),
        );
      }, briefing: true);
      expect(find.text('已知充电费用'), findsOneWidget);
      expect(find.bySemanticsLabel('充入电池 160.0 kWh，8 次充电'), findsOneWidget);
      await tester.tap(find.text('已知充电费用'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.bySemanticsLabel('已知费用趋势图表'), 120);
      expect(find.bySemanticsLabel('已知费用趋势图表'), findsOneWidget);
      expect(find.textContaining('已知费用读数 12（币种未知）'), findsWidgets);
      expect(find.textContaining('币种未知'), findsWidgets);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
