import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/overview_page.dart';
import 'package:mileaf/src/statistics_insights_page.dart';
import 'package:mileaf/src/workspace.dart';

import 'drives_test.dart' show jsonResponse;
import 'statistics_test.dart' show custom;
import 'statistics_usage_test.dart' show usageFixture;
import 'charging_cost_test.dart' show tapCostAction;
import 'charging_detail_test.dart' as detail show response;
import 'charging_expansion_test.dart' show chargingPageV2, chargingStatsV2;
import 'statistics_charging_test.dart' show statisticsChargingResponse;
import 'support/statistics_insights_fixture.dart';
import 'overview_test.dart' show background, foreground;
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'charging_test.dart' show MemoryCurrency;
import 'widget_test.dart' show MemoryTrustStore;

Future<void> pumpReadingApp(
  WidgetTester tester,
  http.Client client, {
  DateTime Function()? now,
  String Function()? zone,
  CurrencyPreferenceStore? currency,
}) async {
  final store = MemorySessionStore()
    ..value = jsonEncode({
      'site': 'https://example.com/prefix',
      'token': 'test',
      'expires_at': '2099-01-01T00:00:00Z',
    });
  await tester.pumpWidget(
    MileafApp(
      client: client,
      sessionStore: store,
      trustStore: MemoryTrustStore(),
      vehiclePreferences: MemoryVehiclePreferences(),
      now: now ?? () => DateTime.utc(2026, 3, 15, 12),
      calendar: () async => CalendarContext(zone?.call() ?? 'UTC'),
      currencyPreferences: currency,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> selectTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(MileafNavBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

Future<void> tapChipIn(WidgetTester tester, Type page, String label) async {
  final chip = find.descendant(
    of: find.byType(page),
    matching: find.widgetWithText(StatusChip, label),
  );
  await Scrollable.ensureVisible(tester.element(chip), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Finder tabScrollable(Type page) => find
    .descendant(of: find.byType(page), matching: find.byType(Scrollable))
    .first;

double tabOffset(WidgetTester tester, Type page) =>
    tester.state<ScrollableState>(tabScrollable(page)).position.pixels;

/// Taps the shared time-series plot at [fraction] of its width.
Future<void> tapPlot(WidgetTester tester, double fraction) async {
  final chart = find.byType(TimeSeriesChart).first;
  final interactivePlot = find.descendant(
    of: chart,
    matching: find.byWidgetPredicate(
      (widget) => widget is GestureDetector && widget.onTapUp != null,
    ),
  );
  final plots = [
    for (var i = 0; i < interactivePlot.evaluate().length; i++)
      tester.getRect(interactivePlot.at(i)),
  ];
  final plot = plots.reduce(
    (left, right) =>
        left.width * left.height >= right.width * right.height ? left : right,
  );
  await tester.tapAt(Offset(plot.left + plot.width * fraction, plot.center.dy));
  await tester.pumpAndSettle();
}

Object readingFixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync());

/// Three calendar-day buckets so a point can be told apart by date.
Map<String, dynamic> dayStats(Uri url, {int days = 3}) {
  final base = statisticsInsightsFixture(url);
  final first = DateTime.parse(url.queryParameters['from']!);
  final bucket = Map<String, dynamic>.from(
    (base['buckets'] as List).first as Map,
  );
  base['buckets'] = [
    for (var i = 0; i < days; i++)
      {
        ...bucket,
        'bucket_start': first.add(Duration(days: i)).toIso8601String(),
        // The day number makes a bucket identifiable by value as well as date.
        'distance_km': first.add(Duration(days: i)).day.toDouble(),
      },
  ];
  return base;
}

Map<String, dynamic> chargingDays(Uri url, {int days = 7}) {
  final base = readingFixture('charging-stats') as Map<String, dynamic>;
  final first = DateTime.parse(url.queryParameters['from']!);
  final bucket = Map<String, dynamic>.from(
    (base['buckets'] as List).first as Map,
  );
  base['buckets'] = [
    for (var i = 0; i < days; i++)
      {
        ...bucket,
        'bucket_start': first.add(Duration(days: i)).toIso8601String(),
        'cost': i.toDouble(),
        'energy_added_kwh': 10.0,
      },
  ];
  base['totals'] = {
    ...(base['totals'] as Map<String, dynamic>),
    'cost': (days * (days - 1) / 2).toDouble(),
    'energy_added_kwh': days * 10.0,
  };
  return base;
}

http.Response ok(Object body, {int maxAge = 300}) => jsonResponse(
  body is String ? body : jsonEncode(body),
  headers: {'cache-control': 'max-age=$maxAge'},
);

http.Client readingClient(
  List<Uri> seen, {
  Map<String, dynamic> Function(Uri url)? driving,
  Map<String, dynamic> Function(Uri url)? charging,
  int maxAge = 300,
  bool insights = true,
}) => MockClient((request) async {
  seen.add(request.url);
  final path = request.url.path;
  if (path.endsWith('/vehicles')) return ok(readingFixture('vehicles'));
  if (path.endsWith('/meta')) {
    if (!insights) return ok({'version': '0.4.0'});
    return ok(
      statisticsInsightsMeta(
        features: {'driving_coverage': true, 'driving_analysis': true},
      ),
    );
  }
  if (path.endsWith('/summary')) return ok(readingFixture('summary'));
  if (path.endsWith('/drives')) return ok(readingFixture('drives'));
  if (path.endsWith('/driving-analysis')) return ok(usageFixture());
  if (path.endsWith('/charging-sessions')) {
    return ok(readingFixture('charging-sessions'));
  }
  if (path.endsWith('/stats')) {
    final kind = request.url.queryParameters['kind'];
    final body = kind == 'charging'
        ? charging?.call(request.url) ?? readingFixture('charging-stats')
        : driving?.call(request.url) ?? readingFixture('driving-stats');
    return ok(body, maxAge: maxAge);
  }
  return ok('{}');
});

/// A site with one completed, cost-less charge. A successful entry changes the
/// ledger and every aggregate that includes it.
class ReadingCostSite {
  ReadingCostSite({this.insights = false});
  final bool insights;
  bool costed = false;
  int chargingMaxAge = 300;
  final reads = <http.Request>[];
  final writes = <http.Request>[];
  late final client = MockClient(handle);

  Map<String, dynamic> get chargingStats {
    final body = readingFixture('charging-stats') as Map<String, dynamic>;
    body['totals'] = {
      ...(body['totals'] as Map<String, dynamic>),
      'cost': costed ? 99.5 : 72.0,
    };
    return body;
  }

  http.Response meta() {
    if (!insights) return ok({'version': '0.4.0'});
    final body = statisticsInsightsMeta(features: {'driving_coverage': true});
    body['version'] = '0.4.0';
    return ok(body);
  }

  Map<String, dynamic> row() {
    final body = readingFixture('charging-detail') as Map<String, dynamic>;
    return {
      ...body,
      'id': 1,
      'cost': costed ? 27.5 : null,
      'ended_at': '2026-01-05T09:00:00Z',
      'is_active': false,
    };
  }

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (request.method == 'GET') reads.add(request);
    if (request.method == 'PATCH' &&
        path.endsWith('/charging-sessions/1/cost')) {
      writes.add(request);
      costed = true;
      return ok({
        'session_id': 1,
        'unit_price': '1.25',
        'billing_energy_kwh': '22',
        'cost': '27.50',
      });
    }
    if (path.endsWith('/vehicles')) return ok(readingFixture('vehicles'));
    if (path.endsWith('/meta')) return meta();
    if (path.endsWith('/summary')) {
      final body = readingFixture('summary') as Map<String, dynamic>;
      body['last_charge'] = {
        ...(body['last_charge'] as Map<String, dynamic>),
        'id': 1,
      };
      return ok(body);
    }
    if (path.endsWith('/stats')) {
      if (request.url.queryParameters['kind'] == 'charging') {
        return ok(chargingStats, maxAge: chargingMaxAge);
      }
      return ok(
        insights
            ? dayStats(request.url, days: 7)
            : readingFixture('driving-stats'),
      );
    }
    if (path.endsWith('/charging-sessions/1/series')) {
      return ok(readingFixture('charging-series'));
    }
    if (path.endsWith('/charging-sessions/1')) return ok(row());
    if (path.endsWith('/charging-sessions')) {
      return ok({
        'items': [row()],
        'next_cursor': null,
      });
    }
    if (path.endsWith('/drives')) return ok(readingFixture('drives'));
    if (path.endsWith('/driving-analysis')) return ok(usageFixture());
    return ok({});
  }
}

/// Opens the charging topic from the statistics home's 2×2 topic grid (P06).
///
/// 旧入口是概览「数据说明与更多 → 充电统计」，P01 之后概览不再有该下钻
/// （onStatistics 已无调用方）；P06 的补能专题改为统计首页的专题卡。
Future<void> openChargingTopic(WidgetTester tester) async {
  // P01 页尾仍有「驾驶统计 / 充电统计」下钻（onStatistics 回调未变），
  // 统计 Tab 内的补能专辑仍按概览期间打开，而不是 push 独立路由。
  await selectTab(tester, '概览');
  await tester.scrollUntilVisible(find.text('充电统计').hitTestable(), 300);
  await tester.pumpAndSettle();
  await tester.tap(find.text('充电统计').hitTestable());
  await tester.pumpAndSettle();
}

/// Taps the charging topic's own plot and returns the bucket it reports.
Future<void> tapChargingPlot(WidgetTester tester, double fraction) async {
  final plot = find.byKey(const ValueKey('charging-topic-plot'));
  await tester.scrollUntilVisible(plot.hitTestable(), 120);
  await tester.pumpAndSettle();
  final rect = tester.getRect(plot);
  await tester.tapAt(Offset(rect.left + rect.width * fraction, rect.center.dy));
  await tester.pumpAndSettle();
}

/// Presses the topic's own refresh action, scrolling back up to it first.
Future<void> refreshChargingTopic(WidgetTester tester) async {
  final button = find.byTooltip('刷新补能统计');
  for (var i = 0; i < 6 && button.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 300));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// The charging topic's chart readout date (R29/DF1): 读数头日期行是「M月D日」，
/// 这里归一成「M/D」便于跨刷新比较。
String chargingReadout(WidgetTester tester) {
  final day = RegExp(r'^(\d{1,2})月(\d{1,2})日$');
  final slash = RegExp(r'^(\d{1,2})/(\d{1,2})$');
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final value = text.data ?? '';
    final match = day.firstMatch(value) ?? slash.firstMatch(value);
    if (match != null) {
      return '${int.parse(match.group(1)!)}/${int.parse(match.group(2)!)}';
    }
  }
  return '';
}

int chargingStatsReads(List<Uri> seen) => seen
    .where(
      (uri) =>
          uri.path.endsWith('/stats') &&
          uri.queryParameters['kind'] == 'charging',
    )
    .length;

String chartDate(WidgetTester tester) {
  // R29/CP04：概览读数头日期行用 DF1「M月D日」；统计页的图表刻度仍以 M/D
  // 覆盖。两种写法都归一成「M/D」便于跨刷新比较。
  final day = RegExp(r'^(\d{1,2})月(\d{1,2})日$');
  final slash = RegExp(r'^(\d{1,2})/(\d{1,2})$');
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    final value = text.data ?? '';
    final match = day.firstMatch(value) ?? slash.firstMatch(value);
    if (match != null) {
      return '${int.parse(match.group(1)!)}/${int.parse(match.group(2)!)}';
    }
  }
  fail('chart readout not found');
}

http.Client capableClient(List<Uri> seen, {int maxAge = 1}) => MockClient((
  request,
) async {
  seen.add(request.url);
  final path = request.url.path;
  if (path.endsWith('/vehicles')) return ok(readingFixture('vehicles'));
  if (path.endsWith('/meta')) {
    final body = statisticsInsightsMeta(
      features: {'driving_coverage': true, 'driving_analysis': true},
    );
    body['version'] = '0.4.0';
    body['charging_experience'] = {
      'contract_version': 'charging-experience-v1',
      'minimum_server_version': '0.2.0',
      'tested_schema_version': 20260808090000,
      'fields': <String, bool>{},
    };
    return ok(body);
  }
  if (path.endsWith('/summary')) return ok(readingFixture('summary'));
  if (path.endsWith('/drives')) return ok(readingFixture('drives'));
  if (path.endsWith('/driving-analysis')) return ok(readingFixture('drives'));
  if (path.endsWith('/charging-sessions')) {
    return ok(chargingPageV2(), maxAge: maxAge);
  }
  if (path.endsWith('/stats')) {
    final kind = request.url.queryParameters['kind'];
    return ok(
      kind == 'charging'
          ? chargingDaysV2(request.url)
          : readingFixture('driving-stats'),
      maxAge: maxAge,
    );
  }
  return ok({}, maxAge: maxAge);
});

/// Seven day buckets in the charging-experience contract, each with its own
/// date and cost, so a chosen date is distinguishable by value as well.
Map<String, dynamic> chargingDaysV2(Uri url, {int days = 7}) {
  final body = chargingStatsV2();
  final first = DateTime.parse(url.queryParameters['from']!);
  final bucket = Map<String, dynamic>.from(
    (body['buckets'] as List).first as Map,
  );
  body['buckets'] = [
    for (var i = 0; i < days; i++)
      {
        ...bucket,
        'bucket_start': first.add(Duration(days: i)).toIso8601String(),
        'sessions': 1,
        'energy_known_sessions': 1,
        'cost_known_sessions': 1,
        'cost': i.toDouble(),
        'energy_added_kwh': 10.0,
      },
  ];
  body['totals'] = {
    ...(body['totals'] as Map<String, dynamic>),
    'cost': (days * (days - 1) / 2).toDouble(),
    'energy_added_kwh': days * 10.0,
  };
  return body;
}

void main() {
  testWidgets('F4-g 补能专题普通Tab往返只应读取一次同一期间', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final seen = <Uri>[];
    await pumpReadingApp(tester, capableClient(seen), now: () => now);
    await openChargingTopic(tester);
    await tapChargingPlot(tester, 0.8);
    final before = chargingStatsReads(seen);
    now = now.add(const Duration(seconds: 5));
    await selectTab(tester, '行程');
    await selectTab(tester, '统计');
    expect(
      chargingStatsReads(seen) - before,
      1,
      reason: '同一次可见帧只校验一次，不重复读取同一期间',
    );
  });

  testWidgets('F4-f 补能专题跨日后回前台仍按日期保留选点', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final seen = <Uri>[];
    await pumpReadingApp(tester, capableClient(seen), now: () => now);
    await openChargingTopic(tester);
    await tapChargingPlot(tester, 0.8);
    final chosen = chargingReadout(tester);
    now = DateTime.utc(2026, 3, 30, 16, 30); // Asia/Shanghai 次日 00:30
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(chargingReadout(tester), chosen, reason: '跨日重算相对期间后仍按日期保留选点');
  });

  testWidgets('F4-e 补能专题保持可见时回前台（父窗口按TTL重算）仍选中同一日期', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final seen = <Uri>[];
    await pumpReadingApp(tester, capableClient(seen), now: () => now);
    await openChargingTopic(tester);
    await tapChargingPlot(tester, 0.8);
    final chosen = chargingReadout(tester);
    now = now.add(const Duration(minutes: 10));
    final before = chargingStatsReads(seen);
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(chargingStatsReads(seen), greaterThan(before), reason: '前置：确实重新校验过');
    expect(chargingReadout(tester), chosen, reason: 'TTL 重算同一期间不得丢弃已选日期');
  });

  testWidgets('F4-d 有补能能力站点：选非首日期后跨过一次父窗口校验仍选中同一日期', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final seen = <Uri>[];
    await pumpReadingApp(tester, capableClient(seen), now: () => now);
    await openChargingTopic(tester);
    await tapChargingPlot(tester, 0.8);
    final chosen = chargingReadout(tester);
    now = now.add(const Duration(seconds: 5));
    await selectTab(tester, '行程');
    await selectTab(tester, '统计');
    expect(chargingReadout(tester), chosen, reason: '窗口校验后仍选中同一日期');
  });

  testWidgets('概览在主入口往返保留期间、指标、选点与滚动位置', (tester) async {
    final seen = <Uri>[];
    final currency = MemoryCurrency()
      ..values['https://example.com/prefix'] = 'CNY';
    await pumpReadingApp(
      tester,
      readingClient(
        seen,
        driving: (url) => dayStats(url, days: 7),
        charging: chargingDays,
      ),
      currency: currency,
    );
    await tester.tap(find.widgetWithText(StatusChip, '近7天'));
    await tester.pumpAndSettle();
    await tester.drag(
      find
          .descendant(
            of: find.byType(OverviewPage),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(StatusChip, '费用'));
    await tester.pumpAndSettle();
    // R29：读值改由图表读数头承载（live region 节点），不再有「点按读值」提示。
    final readout = find.byKey(MileafChartGrammar.readoutLiveKey);
    await tester.scrollUntilVisible(readout, 220);
    await tester.pumpAndSettle();
    // R29：Y 轴刻度移到绘图区右侧后，绘图区比手势区窄，0.9 的手势比例
    // 落在最后一个桶（3/15），仍是「末点」这一语义。
    await tapPlot(tester, 0.9);
    expect(
      find.descendant(of: readout, matching: find.text('3月15日')),
      findsOneWidget,
      reason: '读数头日期行用 DF1',
    );
    expect(
      find.descendant(of: readout, matching: find.text('6 CNY')),
      findsOneWidget,
      reason: '费用读数按服务端币种代码带单位',
    );
    final offset = tabOffset(tester, OverviewPage);
    expect(offset, greaterThan(0));
    await selectTab(tester, '行程');
    await selectTab(tester, '概览');
    expect(
      tester
          .widget<StatusChip>(find.widgetWithText(StatusChip, '近7天'))
          .selected,
      isTrue,
    );
    expect(
      tester.widget<StatusChip>(find.widgetWithText(StatusChip, '费用')).selected,
      isTrue,
    );
    expect(
      find.descendant(of: readout, matching: find.text('3月15日')),
      findsOneWidget,
      reason: '主入口往返后仍按日期保留已选点',
    );
    expect(
      find.descendant(of: readout, matching: find.text('6 CNY')),
      findsOneWidget,
    );
    expect(tabOffset(tester, OverviewPage), closeTo(offset, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('统计在主入口往返保留自定义期间、选点、内容与滚动位置', (tester) async {
    final seen = <Uri>[];
    await pumpReadingApp(
      tester,
      readingClient(seen, driving: (url) => dayStats(url, days: 3)),
      now: () => DateTime.utc(2026, 10, 28, 11),
    );
    await selectTab(tester, '统计');
    await custom(tester, '2026-10-02', '2026-10-04');
    await tester.scrollUntilVisible(find.byType(TimeSeriesChart), 220);
    await tapPlot(tester, 0.9);
    final offset = tabOffset(tester, StatisticsInsightsPage);
    expect(offset, greaterThan(0));
    await selectTab(tester, '行程');
    await selectTab(tester, '统计');
    expect(tabOffset(tester, StatisticsInsightsPage), closeTo(offset, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('隐藏概览不因补录主动请求，返回后费用与汇总按失效更新', (tester) async {
    final site = ReadingCostSite();
    final currency = MemoryCurrency()
      ..values['https://example.com/prefix'] = 'CNY';
    await pumpReadingApp(
      tester,
      site.client,
      now: () => DateTime.utc(2026, 3, 30, 12),
      currency: currency,
    );
    await tapChipIn(tester, OverviewPage, '近7天');
    final overviewFrom = site.reads
        .lastWhere(
          (r) =>
              r.url.path.endsWith('/stats') &&
              r.url.queryParameters['kind'] == 'charging',
        )
        .url
        .queryParameters['from'];
    await selectTab(tester, '充电');
    site.reads.clear();
    await tester.scrollUntilVisible(
      find.text('补录费用').hitTestable(),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('补录费用').hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1.25');
    await tapCostAction(tester, '确认补录');
    expect(find.textContaining('费用已补录'), findsOneWidget);
    expect(
      find.textContaining('部分汇总暂未更新'),
      findsOneWidget,
      reason: '隐藏页面的暂不刷新不得报成已更新',
    );
    expect(
      site.reads.where((r) => r.url.path.endsWith('/summary')),
      isEmpty,
      reason: '隐藏概览不得因费用失效主动请求',
    );
    expect(
      site.reads.where(
        (r) =>
            r.url.path.endsWith('/stats') &&
            r.url.queryParameters['from'] == overviewFrom,
      ),
      isEmpty,
      reason: '隐藏概览不得读取自己的期间',
    );
    await selectTab(tester, '概览');
    expect(
      site.reads.any(
        (r) =>
            r.url.path.endsWith('/stats') &&
            r.url.queryParameters['from'] == overviewFrom &&
            r.url.queryParameters['kind'] == 'charging',
      ),
      isTrue,
      reason: '返回后即使本地快照 TTL 未过期也必须校验费用',
    );
    expect(site.reads.any((r) => r.url.path.endsWith('/summary')), isTrue);
    // CP02：本期账目的费用格标签是「已记录费用」。
    await tester.scrollUntilVisible(
      find.textContaining('已记录费用').hitTestable(),
      220,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('overview-reading-plate')),
        matching: find.text('¥99.5'),
      ),
      findsOneWidget,
    );
    expect(site.writes, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('隐藏统计不因补录主动请求，返回后费用与汇总按失效更新', (tester) async {
    final site = ReadingCostSite(insights: true);
    final currency = MemoryCurrency()
      ..values['https://example.com/prefix'] = 'CNY';
    await pumpReadingApp(
      tester,
      site.client,
      now: () => DateTime.utc(2026, 3, 30, 12),
      currency: currency,
    );
    await selectTab(tester, '统计');
    await tester.tap(find.widgetWithText(StatusChip, '近7天'));
    await tester.pumpAndSettle();
    // P06：首页的补能专题卡显示已记录费用（CP02 把「已知支出」改称「已记录费用」）。
    final chargingCard = find.byKey(const ValueKey('statistics-topic-补能'));
    await tester.scrollUntilVisible(chargingCard, 160);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: chargingCard, matching: find.text('¥72')),
      findsOneWidget,
    );
    final statisticsFrom = site.reads
        .lastWhere(
          (r) =>
              r.url.path.endsWith('/stats') &&
              r.url.queryParameters['kind'] == 'charging',
        )
        .url
        .queryParameters['from'];
    await selectTab(tester, '充电');
    site.reads.clear();
    await tester.scrollUntilVisible(
      find.text('补录费用').hitTestable(),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('补录费用').hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1.25');
    await tapCostAction(tester, '确认补录');
    expect(find.textContaining('费用已补录'), findsOneWidget);
    expect(find.textContaining('部分汇总暂未更新'), findsOneWidget);
    expect(
      site.reads.where(
        (r) =>
            r.url.path.endsWith('/stats') &&
            r.url.queryParameters['from'] == statisticsFrom,
      ),
      isEmpty,
      reason: '隐藏统计不得读取自己的期间',
    );
    await selectTab(tester, '统计');
    expect(
      site.reads.any(
        (r) =>
            r.url.path.endsWith('/stats') &&
            r.url.queryParameters['from'] == statisticsFrom &&
            r.url.queryParameters['kind'] == 'charging',
      ),
      isTrue,
      reason: '返回后即使本地快照 TTL 未过期也必须校验费用',
    );
    await tester.scrollUntilVisible(chargingCard, 160);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: chargingCard, matching: find.text('¥99.5')),
      findsOneWidget,
      reason: '返回可见后补能卡的费用按失效更新',
    );
    expect(site.writes, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('旧版统计回退页同样在返回后更新费用且不隐藏请求', (tester) async {
    final site = ReadingCostSite();
    final currency = MemoryCurrency()
      ..values['https://example.com/prefix'] = 'CNY';
    await pumpReadingApp(
      tester,
      site.client,
      now: () => DateTime.utc(2026, 3, 30, 12),
      currency: currency,
    );
    await selectTab(tester, '统计');
    await tester.tap(find.widgetWithText(StatusChip, '充电统计'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(StatusChip, '近7天').hitTestable().first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('72'), findsWidgets);
    final statisticsFrom = site.reads
        .lastWhere(
          (r) =>
              r.url.path.endsWith('/stats') &&
              r.url.queryParameters['kind'] == 'charging',
        )
        .url
        .queryParameters['from'];
    await selectTab(tester, '充电');
    site.reads.clear();
    await tester.scrollUntilVisible(
      find.text('补录费用').hitTestable(),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('补录费用').hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1.25');
    await tapCostAction(tester, '确认补录');
    expect(find.textContaining('费用已补录'), findsOneWidget);
    expect(find.textContaining('部分汇总暂未更新'), findsOneWidget);
    expect(
      site.reads.where(
        (r) =>
            r.url.path.endsWith('/stats') &&
            r.url.queryParameters['from'] == statisticsFrom,
      ),
      isEmpty,
    );
    await selectTab(tester, '统计');
    expect(
      site.reads.any(
        (r) =>
            r.url.path.endsWith('/stats') &&
            r.url.queryParameters['from'] == statisticsFrom &&
            r.url.queryParameters['kind'] == 'charging',
      ),
      isTrue,
    );
    expect(find.textContaining('99.5'), findsWidgets);
    expect(site.writes, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('嵌入统计页的补能专题隐藏时不请求，返回后消费失效', (tester) async {
    final site = ReadingCostSite(insights: true);
    final currency = MemoryCurrency()
      ..values['https://example.com/prefix'] = 'CNY';
    await pumpReadingApp(
      tester,
      site.client,
      now: () => DateTime.utc(2026, 3, 30, 12),
      currency: currency,
    );
    await openChargingTopic(tester);
    await tapChipIn(tester, StatisticsInsightsPage, '近7天');
    await tapChargingPlot(tester, 0.8);
    final chosenBucket = chargingReadout(tester);
    expect(
      tester
          .widget<TimeSeriesChart>(find.byType(TimeSeriesChart).first)
          .selectedIndex,
      greaterThan(0),
      reason: '前置：确实选中了非首日期',
    );
    final statisticsFrom = site.reads
        .lastWhere(
          (r) =>
              r.url.path.endsWith('/stats') &&
              r.url.queryParameters['kind'] == 'charging',
        )
        .url
        .queryParameters['from'];
    await selectTab(tester, '充电');
    site.reads.clear();
    await tester.scrollUntilVisible(
      find.text('补录费用').hitTestable(),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('补录费用').hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1.25');
    await tapCostAction(tester, '确认补录');
    expect(find.textContaining('部分汇总暂未更新'), findsOneWidget);
    expect(
      site.reads.where(
        (r) =>
            r.url.path.endsWith('/stats') &&
            r.url.queryParameters['from'] == statisticsFrom,
      ),
      isEmpty,
      reason: '隐藏的嵌入专题不得读取自己的期间',
    );
    await selectTab(tester, '统计');
    expect(
      site.reads.any(
        (r) =>
            r.url.path.endsWith('/stats') &&
            r.url.queryParameters['from'] == statisticsFrom &&
            r.url.queryParameters['kind'] == 'charging',
      ),
      isTrue,
    );
    expect(
      tester
          .widget<StatusChip>(
            find.descendant(
              of: find.byType(StatisticsInsightsPage),
              matching: find.widgetWithText(StatusChip, '近7天'),
            ),
          )
          .selected,
      isTrue,
    );
    expect(chargingReadout(tester), chosenBucket, reason: '费用失效刷新后仍按日期保留已选点');
    expect(site.writes, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('统计在TTL过期后返回仍保留期间并重新校验', (tester) async {
    var now = DateTime.utc(2026, 10, 28, 11);
    final seen = <Uri>[];
    await pumpReadingApp(
      tester,
      readingClient(seen, driving: (url) => dayStats(url, days: 7), maxAge: 30),
      now: () => now,
    );
    await selectTab(tester, '统计');
    await custom(tester, '2026-10-02', '2026-10-04');
    await tester.scrollUntilVisible(find.byType(TimeSeriesChart), 220);
    await tapPlot(tester, 0.5);
    final chosen = chartDate(tester);
    final offset = tabOffset(tester, StatisticsInsightsPage);
    await selectTab(tester, '行程');
    final before = seen.where((u) => u.path.endsWith('/stats')).length;
    now = now.add(const Duration(minutes: 10));
    await selectTab(tester, '统计');
    expect(
      seen.where((u) => u.path.endsWith('/stats')).length,
      greaterThan(before),
      reason: 'TTL 过期后重新可见必须校验',
    );
    expect(chartDate(tester), chosen);
    expect(tabOffset(tester, StatisticsInsightsPage), closeTo(offset, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('统计前台换时区保留自定义日期并清掉旧快照', (tester) async {
    var zone = 'Asia/Shanghai';
    final seen = <Uri>[];
    await pumpReadingApp(
      tester,
      readingClient(seen, driving: (url) => dayStats(url, days: 3)),
      now: () => DateTime.utc(2026, 10, 28, 11),
      zone: () => zone,
    );
    await selectTab(tester, '统计');
    await custom(tester, '2026-10-02', '2026-10-04');
    expect(
      seen.any(
        (u) =>
            u.path.endsWith('/stats') &&
            u.queryParameters['tz'] == 'Asia/Shanghai' &&
            u.queryParameters['from'] == '2026-10-01T16:00:00.000Z',
      ),
      isTrue,
    );
    await selectTab(tester, '行程');
    zone = 'UTC';
    seen.clear();
    await selectTab(tester, '统计');
    expect(
      seen.any(
        (u) =>
            u.path.endsWith('/stats') &&
            u.queryParameters['tz'] == 'UTC' &&
            u.queryParameters['from'] == '2026-10-02T00:00:00.000Z',
      ),
      isTrue,
    );
    expect(find.textContaining('2026-10-02 至 2026-10-04'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('统计切车清旧阅读状态且迟到结果不覆盖新车', (tester) async {
    final pending = Completer<http.Response>();
    var slowArmed = false;
    final seen = <Uri>[];
    final client = MockClient((request) async {
      seen.add(request.url);
      final path = request.url.path;
      if (path.endsWith('/vehicles')) return ok(readingFixture('vehicles'));
      if (path.endsWith('/meta')) {
        return ok(
          statisticsInsightsMeta(
            features: {'driving_coverage': true, 'driving_analysis': true},
          ),
        );
      }
      if (path.endsWith('/summary')) return ok(readingFixture('summary'));
      if (path.endsWith('/stats')) {
        if (slowArmed && path.contains('/vehicles/1/')) return pending.future;
        final body = dayStats(request.url, days: 7);
        if (path.contains('/vehicles/2/')) body['totals']['drives'] = 8;
        return ok(body);
      }
      return ok({});
    });
    await pumpReadingApp(
      tester,
      client,
      now: () => DateTime.utc(2026, 10, 28, 11),
    );
    await selectTab(tester, '统计');
    slowArmed = true;
    await custom(tester, '2026-10-02', '2026-10-04');
    await tester.tap(find.text('行笺测试车').first);
    await tester.pumpAndSettle();
    // P16：车辆行无名称时写「型号，尾号 0002」。
    await tester.tap(find.text('Y，尾号 0002'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<StatusChip>(find.widgetWithText(StatusChip, '本月')).selected,
      isTrue,
      reason: '切车后重新建立默认期间',
    );
    expect(find.text('8 趟'), findsOneWidget);
    pending.complete(
      ok(
        dayStats(
          Uri.parse(
            'https://x/y?from=2026-10-02T00:00:00Z&to=2026-10-05T00:00:00Z&bucket=day',
          ),
          days: 7,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('8 趟'), findsOneWidget);
    expect(find.text('5 趟'), findsNothing);
    expect(seen.any((u) => u.path.contains('/vehicles/2/')), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Navigator推入的补能专题在子路由下不抢先读取', (tester) async {
    var costed = false;
    final seen = <Uri>[];
    final writes = <http.Request>[];
    Map<String, dynamic> row() => {
      ...(readingFixture('charging-detail') as Map<String, dynamic>),
      'id': 1,
      'cost': costed ? 27.5 : null,
      'ended_at': '2026-01-05T09:00:00Z',
      'is_active': false,
    };
    final client = MockClient((request) async {
      seen.add(request.url);
      final path = request.url.path;
      if (request.method == 'PATCH' && path.endsWith('/cost')) {
        writes.add(request);
        costed = true;
        return detail.response({
          'session_id': 1,
          'unit_price': '1.25',
          'billing_energy_kwh': '22',
          'cost': '27.50',
        });
      }
      if (path.endsWith('/meta')) {
        final body = jsonDecode(
          statisticsChargingResponse(request).body,
        ) as Map<String, dynamic>;
        body['version'] = '0.4.0';
        return detail.response(body);
      }
      if (path.endsWith('/stats') &&
          request.url.queryParameters['kind'] == 'charging') {
        final body = chargingStatsV2();
        body['totals'] = {
          ...(body['totals'] as Map<String, dynamic>),
          'cost': costed ? 99.5 : 72.0,
        };
        return detail.response(body);
      }
      if (path.endsWith('/charging-sessions/1/cost')) {
        return detail.response({
          'session_id': 1,
          'unit_price': '1.25',
          'billing_energy_kwh': '22',
          'cost': '27.50',
        });
      }
      if (path.endsWith('/charging-sessions/1/series')) {
        return detail.response(readingFixture('charging-series'));
      }
      if (path.endsWith('/charging-sessions/1')) {
        return detail.response(row());
      }
      if (path.endsWith('/charging-sessions')) {
        final page = chargingPageV2();
        page['items'] = [
          {
            ...((page['items'] as List).first as Map<String, dynamic>),
            'id': 1,
            'cost': null,
            'is_active': false,
            'ended_at': '2026-03-29T03:30:00Z',
          },
        ];
        page['next_cursor'] = null;
        return detail.response(page);
      }
      return statisticsChargingResponse(request);
    });
    final currency = MemoryCurrency()
      ..values['https://example.com/prefix'] = 'CNY';
    await pumpReadingApp(
      tester,
      client,
      now: () => DateTime.utc(2026, 3, 30, 12),
      currency: currency,
    );
    await selectTab(tester, '统计');
    await tester.scrollUntilVisible(find.text('补能').hitTestable(), 180);
    await tester.tap(find.text('补能'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      if (find.text('查看这段时间的充电').evaluate().isNotEmpty) break;
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('查看这段时间的充电'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看这段时间的充电'));
    await tester.pumpAndSettle();
    final topicFrom = seen
        .lastWhere(
          (u) =>
              u.path.endsWith('/stats') &&
              u.queryParameters['kind'] == 'charging',
        )
        .queryParameters['from'];
    int reads() => seen
        .where(
          (u) =>
              u.path.endsWith('/stats') &&
              u.queryParameters['kind'] == 'charging' &&
              u.queryParameters['from'] == topicFrom,
        )
        .length;
    seen.clear();
    await tester.scrollUntilVisible(
      find.text('补录费用').hitTestable(),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('补录费用').hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '1.25');
    await tapCostAction(tester, '确认补录');
    final during = reads();
    expect(during, 1, reason: '子路由补录只刷新子路由，专题暂不抢先读取');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(reads(), during + 1, reason: '返回专题后才消费费用失效');
    expect(find.text('补能记录'), findsNothing);
    expect(find.text('查看这段时间的充电'), findsOneWidget);
    expect(writes, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('嵌入补能专题按自己的TTL在返回后校验', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final site = ReadingCostSite(insights: true)..chargingMaxAge = 1;
    final currency = MemoryCurrency()
      ..values['https://example.com/prefix'] = 'CNY';
    await pumpReadingApp(
      tester,
      site.client,
      now: () => now,
      currency: currency,
    );
    await openChargingTopic(tester);
    await tapChipIn(tester, StatisticsInsightsPage, '近7天');
    final topicFrom = site.reads
        .lastWhere(
          (r) =>
              r.url.path.endsWith('/stats') &&
              r.url.queryParameters['kind'] == 'charging',
        )
        .url
        .queryParameters['from'];
    int topicReads() => site.reads
        .where(
          (r) =>
              r.url.path.endsWith('/stats') &&
              r.url.queryParameters['kind'] == 'charging' &&
              r.url.queryParameters['from'] == topicFrom,
        )
        .length;
    final before = topicReads();
    await selectTab(tester, '充电');
    now = now.add(const Duration(seconds: 2));
    await selectTab(tester, '统计');
    expect(topicReads(), greaterThan(before), reason: '嵌入专题的充电快照过期后，返回可见必须校验');
    expect(find.text('充电费用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('会话失效重新登录后统计不重现旧阅读状态', (tester) async {
    var now = DateTime.utc(2026, 10, 28, 11);
    var unauthorized = false, signedIn = false;
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/auth/login')) {
        signedIn = true;
        return ok({'token': 'next', 'expires_at': '2099-01-01T00:00:00Z'});
      }
      if (path.endsWith('/vehicles')) return ok(readingFixture('vehicles'));
      if (path.endsWith('/meta')) {
        return ok(
          statisticsInsightsMeta(
            features: {'driving_coverage': true, 'driving_analysis': true},
          ),
        );
      }
      if (path.endsWith('/summary')) return ok(readingFixture('summary'));
      if (path.endsWith('/stats')) {
        if (unauthorized && !signedIn) {
          return http.Response(
            jsonEncode({
              'error': {'code': 'unauthorized', 'message': '授权已失效'},
            }),
            401,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return ok(dayStats(request.url, days: 7));
      }
      if (path.endsWith('/drives')) return ok(readingFixture('drives'));
      return ok({});
    });
    await pumpReadingApp(tester, client, now: () => now);
    await selectTab(tester, '统计');
    await custom(tester, '2026-10-02', '2026-10-04');
    expect(find.textContaining('2026-10-02 至 2026-10-04'), findsOneWidget);
    unauthorized = true;
    now = DateTime.utc(2026, 10, 29, 11);
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(find.text('站点访问口令'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'secret');
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
    await selectTab(tester, '统计');
    expect(
      tester.widget<StatusChip>(find.widgetWithText(StatusChip, '本月')).selected,
      isTrue,
      reason: '会话失效后重新建立默认阅读状态',
    );
    expect(find.textContaining('2026-10-02 至 2026-10-04'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('从概览进入记录补录后返回即更新，不改变阅读位置', (tester) async {
    final site = ReadingCostSite();
    final currency = MemoryCurrency()
      ..values['https://example.com/prefix'] = 'CNY';
    await pumpReadingApp(
      tester,
      site.client,
      now: () => DateTime.utc(2026, 3, 30, 12),
      currency: currency,
    );
    await tester.scrollUntilVisible(find.text('最近充电'), 300);
    await tester.pumpAndSettle();
    // 悬浮底栏会盖住刚好滚到的行：先居中再点，命中区才可点。
    await Scrollable.ensureVisible(
      tester.element(find.text('最近充电')),
      alignment: .4,
    );
    await tester.pumpAndSettle();
    final offset = tabOffset(tester, OverviewPage);
    await tester.tap(find.text('最近充电'));
    await tester.pumpAndSettle();
    site.reads.clear();
    // P05：费用格里的补录入口是小胶囊「补录」。
    await tester.scrollUntilVisible(
      find.text('补录').hitTestable(),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('补录').hitTestable());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1.25');
    await tapCostAction(tester, '确认补录');
    expect(find.textContaining('费用已补录'), findsOneWidget);
    expect(
      site.reads.where((r) => r.url.path.endsWith('/summary')),
      isEmpty,
      reason: '被记录详情覆盖的概览不得主动请求',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      site.reads.any((r) => r.url.path.endsWith('/summary')),
      isTrue,
      reason: '返回可见后必须校验费用与汇总',
    );
    expect(tabOffset(tester, OverviewPage), closeTo(offset, 1));
    await tester.scrollUntilVisible(
      find.textContaining('已记录费用').hitTestable(),
      -120,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('overview-reading-plate')),
        matching: find.text('¥99.5'),
      ),
      findsOneWidget,
    );
    expect(site.writes, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('旧版统计跨日重算后按日期保留采样点', (tester) async {
    var now = DateTime.utc(2026, 3, 15, 12);
    await pumpReadingApp(
      tester,
      readingClient(
        [],
        driving: (url) => dayStats(url, days: 7),
        maxAge: 0,
        insights: false,
      ),
      now: () => now,
    );
    await selectTab(tester, '统计');
    await tester.tap(
      find.widgetWithText(StatusChip, '近7天').hitTestable().first,
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(TimeSeriesChart).first, 200);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('driving-statistics-chart')).hitTestable(),
      100,
    );
    await tapPlot(tester, 0.5);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('driving-statistics-chart')).hitTestable(),
      100,
    );
    // R29：可见读值改为读数头（日期行 + 数值行），朗读句只进语义；
    // 「保留采样点」按读数头的日期行核对（chartDate）。
    final chosen = chartDate(tester);
    expect(find.text('2026-03-09—2026-03-15'), findsWidgets);
    await selectTab(tester, '行程');
    now = DateTime.utc(2026, 3, 16, 12);
    await selectTab(tester, '统计');
    expect(
      find.text('2026-03-10—2026-03-16'),
      findsWidgets,
      reason: '窗口整体后移一天',
    );
    expect(chartDate(tester), chosen, reason: '按日期保留采样点');
    expect(tester.takeException(), isNull);
  });

  testWidgets('概览跨日重算相对期间后按日期保留已选点', (tester) async {
    var now = DateTime.utc(2026, 3, 15, 12);
    await pumpReadingApp(
      tester,
      readingClient([], driving: (url) => dayStats(url, days: 7), maxAge: 0),
      now: () => now,
    );
    await tapChipIn(tester, OverviewPage, '近7天');
    await tester.scrollUntilVisible(find.byType(TimeSeriesChart), 220);
    final semantics = tester.ensureSemantics();
    for (var i = 0; i < 3; i++) {
      tester.semantics.decrease(find.semantics.byLabel('每日里程图表'));
      await tester.pumpAndSettle();
    }
    semantics.dispose();
    final chosen = chartDate(tester);
    expect(chosen, isNotEmpty);
    await selectTab(tester, '行程');
    now = DateTime.utc(2026, 3, 16, 12);
    await selectTab(tester, '概览');
    expect(chartDate(tester), chosen, reason: '窗口整体后移一天后仍选中同一日期，而不是同一下标');
    expect(tester.takeException(), isNull);
  });

  testWidgets('统计跨日重算相对期间后按日期保留已选点', (tester) async {
    var now = DateTime.utc(2026, 3, 15, 12);
    await pumpReadingApp(
      tester,
      readingClient([], driving: (url) => dayStats(url, days: 7), maxAge: 0),
      now: () => now,
    );
    await selectTab(tester, '统计');
    await tapChipIn(tester, StatisticsInsightsPage, '近7天');
    await tester.scrollUntilVisible(find.byType(TimeSeriesChart), 100);
    await tapPlot(tester, 0.5);
    final chosen = chartDate(tester);
    await selectTab(tester, '行程');
    now = DateTime.utc(2026, 3, 16, 12);
    await selectTab(tester, '统计');
    expect(chartDate(tester), chosen);
    expect(tester.takeException(), isNull);
  });

  testWidgets('概览显式进入统计时入口期间优先于保留状态', (tester) async {
    final seen = <Uri>[];
    await pumpReadingApp(
      tester,
      readingClient(seen, driving: (url) => dayStats(url, days: 7)),
      now: () => DateTime.utc(2026, 3, 30, 12),
    );
    await selectTab(tester, '统计');
    await custom(tester, '2026-01-05', '2026-01-06');
    await selectTab(tester, '概览');
    await tapChipIn(tester, OverviewPage, '近7天');
    // P01：概览的显式统计下钻改为「用车专题」三行（旧「数据说明与更多 →
    // 驾驶统计」入口已移除）；这里走「节奏」，入口期间仍是概览当前期间。
    final drivingEntry = find.descendant(
      of: find.byType(OverviewPage),
      matching: find.text('节奏'),
    );
    await tester.scrollUntilVisible(drivingEntry, 300);
    await Scrollable.ensureVisible(tester.element(drivingEntry), alignment: .5);
    await tester.pumpAndSettle();
    seen.clear();
    await tester.tap(drivingEntry);
    await tester.pumpAndSettle();
    expect(
      seen.any(
        (u) =>
            u.path.endsWith('/driving-analysis') &&
            u.queryParameters['from'] == '2026-03-24T00:00:00.000Z',
      ),
      isTrue,
      reason: '入口的期间应优先于之前保留的自定义期间',
    );
    expect(
      seen.any((u) => u.queryParameters['from']!.startsWith('2026-01')),
      isFalse,
      reason: '旧阅读状态不得吞掉入口期间',
    );
    expect(
      seen.where((u) => u.path.contains('/vehicles/2/')),
      isEmpty,
      reason: '入口沿用当前车辆（行笺测试车 = 1）',
    );
    await selectTab(tester, '概览');
    expect(
      tester
          .widget<StatusChip>(find.widgetWithText(StatusChip, '近7天'))
          .selected,
      isTrue,
      reason: '显式下钻不联动改变其他主入口的期间',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('连续以不同期间进入同一专题时使用新期间且不混用旧内容', (tester) async {
    final seen = <Uri>[];
    await pumpReadingApp(
      tester,
      readingClient(seen, driving: (url) => dayStats(url, days: 7)),
      now: () => DateTime.utc(2026, 3, 30, 12),
    );
    // First visit the topic from statistics itself, with its own period.
    await selectTab(tester, '统计');
    await custom(tester, '2026-01-05', '2026-01-06');
    await tester.scrollUntilVisible(
      find.descendant(
        of: find.byType(StatisticsInsightsPage),
        matching: find.text('节奏').hitTestable(),
      ),
      200,
    );
    await tester.tap(
      find
          .descendant(
            of: find.byType(StatisticsInsightsPage),
            matching: find.text('节奏').hitTestable(),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('用车节奏'), findsWidgets);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    // Then enter the same topic from the overview with a new period.
    await selectTab(tester, '概览');
    await tapChipIn(tester, OverviewPage, '近7天');
    await tester.scrollUntilVisible(
      find.descendant(
        of: find.byType(OverviewPage),
        matching: find.text('节奏').hitTestable(),
      ),
      300,
    );
    seen.clear();
    await tester.tap(
      find.descendant(
        of: find.byType(OverviewPage),
        matching: find.text('节奏').hitTestable(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('用车节奏'), findsWidgets);
    final first = seen.lastWhere((u) => u.path.endsWith('/driving-analysis'));
    expect(first.queryParameters['from'], '2026-03-24T00:00:00.000Z');
    // A second explicit entry with another period must not reuse the first.
    await selectTab(tester, '概览');
    await tapChipIn(tester, OverviewPage, '本月');
    await tester.scrollUntilVisible(
      find.descendant(
        of: find.byType(OverviewPage),
        matching: find.text('节奏').hitTestable(),
      ),
      300,
    );
    seen.clear();
    await tester.tap(
      find.descendant(
        of: find.byType(OverviewPage),
        matching: find.text('节奏').hitTestable(),
      ),
    );
    await tester.pumpAndSettle();
    final second = seen.lastWhere((u) => u.path.endsWith('/driving-analysis'));
    expect(second.queryParameters['from'], '2026-03-01T00:00:00.000Z');
    expect(find.text('用车节奏'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('补能统计普通Tab往返与TTL校验后仍选中同一日期', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final seen = <Uri>[];
    await pumpReadingApp(
      tester,
      readingClient(seen, charging: chargingDays, maxAge: 1),
      now: () => now,
    );
    await openChargingTopic(tester);
    await tapChargingPlot(tester, 0.8);
    final chosen = chargingReadout(tester);
    expect(
      tester
          .widget<TimeSeriesChart>(find.byType(TimeSeriesChart).first)
          .selectedIndex,
      greaterThan(0),
      reason: '前置：确实选中了非首日期',
    );
    now = now.add(const Duration(seconds: 5));
    await selectTab(tester, '行程');
    await selectTab(tester, '统计');
    expect(chargingReadout(tester), chosen, reason: '普通Tab往返不得把已选日期重置到第一天');
    final before = chargingStatsReads(seen);
    now = now.add(const Duration(seconds: 5));
    await selectTab(tester, '行程');
    await selectTab(tester, '统计');
    expect(
      chargingStatsReads(seen),
      greaterThan(before),
      reason: 'TTL 过期后重新可见仍要校验',
    );
    expect(chargingReadout(tester), chosen, reason: 'TTL 校验后仍按日期保留选点');
    expect(tester.takeException(), isNull);
  });

  testWidgets('补能统计刷新保留选点，日期消失回到较早日期，显式新期间优先', (tester) async {
    var days = 7;
    final seen = <Uri>[];
    await pumpReadingApp(
      tester,
      readingClient(seen, charging: (url) => chargingDays(url, days: days)),
      now: () => DateTime.utc(2026, 3, 30, 12),
    );
    await openChargingTopic(tester);
    await tapChargingPlot(tester, 0.8);
    final chosen = chargingReadout(tester);
    await refreshChargingTopic(tester);
    expect(chargingReadout(tester), chosen, reason: '刷新不得重置已选日期');
    // The chosen date is no longer served: fall back to the nearest earlier
    // bucket that still exists, not to the first one.
    days = 3;
    await refreshChargingTopic(tester);
    final chart = tester.widget<TimeSeriesChart>(
      find.byType(TimeSeriesChart).first,
    );
    expect(
      chart.selectedIndex,
      chart.times.length - 1,
      reason: '已选日期消失时落到仍在的最近较早日期',
    );
    final fallback = chargingReadout(tester);
    expect(fallback, isNot(chosen));
    // An explicit new period still wins over the old point.
    await tapChipIn(tester, StatisticsInsightsPage, '近7天');
    final explicit = chargingReadout(tester);
    expect(explicit, isNot(fallback), reason: '显式新期间使用自己的首日，不被旧选点阻挡');
    expect(find.text('充电费用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
