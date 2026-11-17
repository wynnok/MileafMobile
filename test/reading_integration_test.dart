import 'package:mileaf/src/drive_detail_page.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/drives_page.dart';
import 'package:mileaf/src/statistics_insights_page.dart';
import 'package:mileaf/src/workspace.dart';

import 'connection_management_test.dart' show openSettings, replace, saved;
import 'drives_test.dart' show openDrives;
import 'drives_test.dart' show jsonResponse;
import 'reading_continuity_test.dart' show driveRow, journeyPage;
import 'overview_statistics_reading_test.dart'
    show chartDate, dayStats, pumpReadingApp, selectTab, tabOffset, tapPlot;
import 'overview_test.dart' show background, foreground;
import 'statistics_usage_test.dart' show usageFixture;
import 'support/statistics_insights_fixture.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

Object fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Object;

http.Response ok(Object body, {int maxAge = 300}) => jsonResponse(
  body is String ? body : jsonEncode(body),
  headers: {'cache-control': 'max-age=$maxAge'},
);

/// A site where every entry of the composite journey has real data: the
/// overview period, the statistics insight window, the usage topic, its drive
/// evidence list and the drive detail itself.
http.Client journeyClient(List<Uri> seen) => MockClient((request) async {
  seen.add(request.url);
  final path = request.url.path;
  if (path.endsWith('/vehicles')) return ok(fixture('vehicles'), maxAge: 30);
  if (path.endsWith('/meta')) {
    return ok(
      statisticsInsightsMeta(
        features: {'driving_coverage': true, 'driving_analysis': true},
      ),
      maxAge: 30,
    );
  }
  if (path.endsWith('/summary')) return ok(fixture('summary'));
  if (path.endsWith('/driving-analysis')) return ok(usageFixture());
  if (path.endsWith('/series')) return ok(fixture('drive-series'));
  final detail = RegExp(r'/drives/(\d+)$').firstMatch(path);
  if (detail != null) {
    return ok({
      ...fixture('drive-detail') as Map<String, dynamic>,
      'id': int.parse(detail.group(1)!),
      'vehicle_id': 1,
    });
  }
  if (path.endsWith('/drives')) return ok(fixture('drives'));
  if (path.endsWith('/charging-sessions')) {
    return ok(fixture('charging-sessions'));
  }
  if (path.endsWith('/stats')) {
    return ok(
      request.url.queryParameters['kind'] == 'charging'
          ? fixture('charging-stats')
          : dayStats(request.url, days: 7),
    );
  }
  return ok(<String, dynamic>{});
});

Finder inPage(Type page, Finder matching) =>
    find.descendant(of: find.byType(page), matching: matching);

/// Drags the top route's list until the target exists, then brings it into
/// view. The target finder must be safe to evaluate when it matches nothing.
Future<void> bring(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 30 && target.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -240));
    await tester.pumpAndSettle();
  }
  expect(target, findsWidgets, reason: '滚动后仍未找到目标');
  await Scrollable.ensureVisible(tester.element(target.first), alignment: .5);
  await tester.pumpAndSettle();
}

/// Scrolls back up until the hero chart is laid out again, so its readout can
/// be read. The insights list is lazy, so a far scroll can drop the chart.
Future<void> showChart(WidgetTester tester) async {
  for (
    var i = 0;
    i < 20 && find.byType(TimeSeriesChart).evaluate().isEmpty;
    i++
  ) {
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 300));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.byType(TimeSeriesChart).first);
  await tester.pumpAndSettle();
}

/// Brings an already-built target into view without dragging: a drag on the
/// drives ledger would trip its own infinite-scroll paging.
Future<void> reveal(WidgetTester tester, Finder target) async {
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pumpAndSettle();
}

/// P02：记录按天分组后单行更高，第二页的行在断言时可能还没构建；
/// 先滚到它再断言，避免把「未构建」误判成「未保留」。
Future<void> revealRow(WidgetTester tester, int id) async {
  final row = find.byKey(ValueKey('drive-$id'));
  if (row.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      row,
      240,
      scrollable: find
          .descendant(
            of: find.byType(DrivesPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }
  await Scrollable.ensureVisible(tester.element(row), alignment: .5);
  await tester.pumpAndSettle();
}

/// P02：记录区上移到顶栏之下，「加载更多行程」常停在视口顶端被顶栏盖住；
/// 先居中对齐再点。
Future<void> tapLoadMore(WidgetTester tester) async {
  final more = find.text('加载更多行程');
  await tester.ensureVisible(more);
  await Scrollable.ensureVisible(tester.element(more), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(more);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('复合旅程：概览近7天→统计专题→行程详情→返回→充电→回统计各自正确', (tester) async {
    final seen = <Uri>[];
    await pumpReadingApp(
      tester,
      journeyClient(seen),
      now: () => DateTime.utc(2026, 3, 30, 12),
      zone: () => 'Asia/Shanghai',
    );

    // 1. The overview reads a relative week.
    await tester.tap(find.widgetWithText(StatusChip, '近7天'));
    await tester.pumpAndSettle();

    // 2. An explicit drill-down carries that period into statistics.
    // P01 把旧「数据说明与更多」弹层收进页尾，「驾驶统计」下钻仍在页尾，
    // 回调 onStatistics 与 StatisticsSelection 未变。
    await bring(tester, find.text('驾驶统计').hitTestable());
    await tester.tap(find.text('驾驶统计'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('3月24日'),
      findsOneWidget,
      reason: '统计使用概览入口携带的期间',
    );

    // 3. A deliberate chart point and a real reading position.
    await showChart(tester);
    await tapPlot(tester, 0.6);
    final chosen = chartDate(tester);
    final offset = tabOffset(tester, StatisticsInsightsPage);
    expect(offset, greaterThan(0));

    // 4. Statistics topic → drive evidence → drive detail.
    final topicCard = inPage(
      StatisticsInsightsPage,
      find.text('节奏').hitTestable(),
    );
    await bring(tester, topicCard);
    final beforePush = tabOffset(tester, StatisticsInsightsPage);
    final statsQueries = seen
        .where((uri) => uri.path.endsWith('/stats'))
        .map((uri) => uri.query)
        .toSet();
    final beforeTopic = seen.length;
    await tester.tap(topicCard.first);
    await tester.pumpAndSettle();
    expect(find.text('这段时间的用车节奏'), findsOneWidget);
    final bin = find.text('0–10 km').hitTestable();
    await bring(tester, bin);
    await tester.tap(bin);
    await tester.pumpAndSettle();
    expect(find.text('行程证据'), findsOneWidget);
    final records = find.textContaining('→').hitTestable();
    await bring(tester, records);
    await tester.tap(records.first);
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is DriveDetailPage && widget.id == 17,
      ),
      findsOneWidget,
      reason: '打开的是证据列表第一条行程',
    );

    // 5. Returning keeps the statistics period, position and point.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('行笺测试车'), findsOneWidget, reason: '车辆归属未改变');
    expect(
      seen
          .skip(beforeTopic)
          .where((uri) => uri.path.endsWith('/stats'))
          .where((uri) => statsQueries.contains(uri.query)),
      isEmpty,
      reason: '被专题与详情路由遮挡的统计页不得自行刷新自己的期间',
    );
    expect(
      tabOffset(tester, StatisticsInsightsPage),
      closeTo(beforePush, 1),
      reason: '返回后仍在离开时的阅读位置',
    );
    await showChart(tester);
    expect(chartDate(tester), chosen, reason: '返回后仍选中同一日期');
    final settled = tabOffset(tester, StatisticsInsightsPage);

    // 6. Charging and back: each entry keeps its own reading.
    await selectTab(tester, '充电');
    expect(
      find.descendant(of: find.byType(MileafTopBar), matching: find.text('充电')),
      findsOneWidget,
    );
    await selectTab(tester, '统计');
    expect(find.text('行笺测试车'), findsOneWidget);
    expect(tabOffset(tester, StatisticsInsightsPage), closeTo(settled, 1));
    await showChart(tester);
    expect(chartDate(tester), chosen);
    await selectTab(tester, '概览');
    expect(
      tester
          .widget<StatusChip>(find.widgetWithText(StatusChip, '近7天'))
          .selected,
      isTrue,
      reason: '统计的显式期间不反向改写概览',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('统计页被专题与详情遮挡时跨日不请求，返回后才按新期间校验', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final seen = <Uri>[];
    await pumpReadingApp(
      tester,
      journeyClient(seen),
      now: () => now,
      zone: () => 'UTC',
    );
    await selectTab(tester, '统计');
    await bring(tester, find.text('节奏').hitTestable());
    await tester.tap(find.text('节奏').hitTestable().first);
    await tester.pumpAndSettle();
    expect(find.text('这段时间的用车节奏'), findsOneWidget);
    final bin = find.text('0–10 km').hitTestable();
    await bring(tester, bin);
    await tester.tap(bin);
    await tester.pumpAndSettle();
    expect(find.text('行程证据'), findsOneWidget);
    final records = find.textContaining('→').hitTestable();
    await bring(tester, records);
    await tester.tap(records.first);
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is DriveDetailPage && widget.id == 17,
      ),
      findsOneWidget,
    );
    // The drive detail is the only visible page; crossing the local midnight
    // bumps the workspace revision behind the topic and the detail routes.
    seen.clear();
    now = DateTime.utc(2026, 3, 31, 0, 30);
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    bool ownPeriod(Uri uri) =>
        uri.path.endsWith('/stats') &&
        uri.queryParameters['to'] == '2026-03-31T00:30:00.000Z';
    expect(seen.where(ownPeriod), isEmpty, reason: '被专题与详情遮挡的统计页不得在后台刷新自己的期间');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(seen.where(ownPeriod), isNotEmpty, reason: '返回统计页后按新的本地日历校验');
    expect(tester.takeException(), isNull);
  });

  testWidgets('换站点清除旧站点的阅读上下文，切回行程不重现旧期间与旧分页', (tester) async {
    final store = saved();
    final seen = <Uri>[];
    http.Response rows(String from, String to, {String? cursor}) =>
        jsonResponse(
          jsonEncode({
            'items': [
              {
                'id': cursor == null ? 901 : 902,
                'started_at': '2026-03-29T02:00:00Z',
                'ended_at': '2026-03-29T02:30:00Z',
                'distance_km': 9.0,
                'duration_min': 30,
                'energy_kwh': 1.7,
                'consumption_wh_km': 189.0,
                'start': {
                  'display_name': '$from 起点',
                  'geofence': null,
                  'address': null,
                  'lat': null,
                  'lon': null,
                },
                'end': {
                  'display_name': '$to 终点',
                  'geofence': null,
                  'address': null,
                  'lat': null,
                  'lon': null,
                },
              },
            ],
            'next_cursor': cursor == null ? 'page-2' : null,
          }),
          headers: {'cache-control': 'max-age=300'},
        );
    final client = MockClient((request) async {
      seen.add(request.url);
      final host = request.url.host;
      final path = request.url.path;
      if (host == 'old.example') {
        if (path.endsWith('/vehicles')) {
          return ok([
            {
              'id': 1,
              'name': '旧站点车辆',
              'model': null,
              'vin_suffix': '',
              'state': null,
              'battery': null,
              'freshness': {'last_position_at': null, 'last_state_at': null},
            },
          ]);
        }
        if (path.endsWith('/meta')) return ok({'version': '0.1.0'});
        if (path.endsWith('/summary')) return ok(fixture('summary'));
        if (path.endsWith('/drives')) {
          return rows('旧', '旧', cursor: request.url.queryParameters['cursor']);
        }
        if (path.endsWith('/stats')) {
          return ok(
            request.url.queryParameters['kind'] == 'charging'
                ? fixture('charging-stats')
                : fixture('driving-stats'),
          );
        }
        return ok(<String, dynamic>{});
      }
      if (path.endsWith('/health')) {
        return jsonResponse('{"status":"ok","version":"0.1"}');
      }
      if (path.endsWith('/auth/login')) {
        return jsonResponse(
          '{"token":"new-token","expires_at":"2099-01-01T00:00:00Z"}',
        );
      }
      if (path.endsWith('/vehicles')) {
        return ok([
          {
            'id': 1,
            'name': '新站点车辆',
            'model': null,
            'vin_suffix': '',
            'state': null,
            'battery': null,
            'freshness': {'last_position_at': null, 'last_state_at': null},
          },
        ]);
      }
      if (path.endsWith('/meta')) return ok({'version': '0.1.0'});
      if (path.endsWith('/summary')) return ok(fixture('summary'));
      if (path.endsWith('/drives')) {
        return rows('新', '新', cursor: request.url.queryParameters['cursor']);
      }
      if (path.endsWith('/stats')) {
        return ok(
          request.url.queryParameters['kind'] == 'charging'
              ? fixture('charging-stats')
              : fixture('driving-stats'),
        );
      }
      return ok(<String, dynamic>{});
    });

    await tester.pumpWidget(
      MileafApp(
        client: client,
        trustStore: MemoryTrustStore(),
        sessionStore: store,
        vehiclePreferences: MemoryVehiclePreferences(),
        calendar: () async => CalendarContext('UTC'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(MileafNavBar), matching: find.text('行程')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(StatusChip, '近7天'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('加载更多行程'));
    await tester.tap(find.text('加载更多行程'));
    await tester.pumpAndSettle();
    expect(find.text('旧 起点 → 旧 终点'), findsWidgets);
    final oldOffset = tabOffset(tester, DrivesPage);

    // Replace the site from settings; the new site serves its own records.
    await openSettings(tester);
    await replace(tester, 'https://new.example/prefix');
    await tester.pumpAndSettle();
    expect(find.text('新站点车辆'), findsWidgets);
    await tester.tap(
      find.descendant(of: find.byType(MileafNavBar), matching: find.text('行程')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('近30天'), findsWidgets);
    expect(
      tester
          .widget<StatusChip>(find.widgetWithText(StatusChip, '近7天'))
          .selected,
      isFalse,
      reason: '换站点不保留旧阅读期间',
    );
    expect(find.text('新 起点 → 新 终点'), findsWidgets);
    expect(find.text('旧 起点 → 旧 终点'), findsNothing);
    expect(find.text('加载更多行程'), findsOneWidget);
    expect(
      tabOffset(tester, DrivesPage),
      isNot(closeTo(oldOffset, 1)),
      reason: '换站点后阅读位置从新上下文开始',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('重试失败的行程重校验仍保留已读页，不塌回第一页', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    var failing = false;
    await openDrives(tester, (request) async {
      if (request.url.path.endsWith('/meta')) {
        return jsonResponse(File('test/fixtures/meta.json').readAsStringSync());
      }
      if (failing) return http.Response('', 503);
      return journeyPage(request);
    }, now: () => now);
    await tapLoadMore(tester);
    await revealRow(tester, 15);
    expect(find.byKey(const ValueKey('drive-15')), findsOneWidget);
    failing = true;
    await selectTab(tester, '概览');
    now = now.add(const Duration(minutes: 10));
    await selectTab(tester, '行程');
    expect(find.textContaining('没能更新，显示的是'), findsOneWidget);
    await revealRow(tester, 15);
    expect(find.byKey(const ValueKey('drive-15')), findsOneWidget);
    failing = false;
    await Scrollable.ensureVisible(
      tester.element(find.text('重试行程')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('重试行程'));
    await tester.pumpAndSettle();
    await revealRow(tester, 15);
    expect(
      find.byKey(const ValueKey('drive-15')),
      findsOneWidget,
      reason: '重试仍覆盖已读的第二页',
    );
    await revealRow(tester, 14);
    expect(find.byKey(const ValueKey('drive-14')), findsOneWidget);
    await revealRow(tester, 17);
    expect(find.byKey(const ValueKey('drive-17')), findsOneWidget);
    expect(find.textContaining('没能更新，显示的是'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('行程重校验遇到重复游标报告游标未前进，不误报格式不兼容', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    var repeating = false;
    http.Response pages(http.Request request) {
      final cursor = request.url.queryParameters['cursor'];
      final first = [
        driveRow(17, '2026-03-30T02:00:00Z'),
        driveRow(16, '2026-03-29T21:30:00Z'),
      ];
      final second = [
        driveRow(15, '2026-03-29T20:00:00Z'),
        driveRow(14, '2026-03-28T19:00:00Z'),
      ];
      final third = [driveRow(13, '2026-03-27T19:00:00Z')];
      final String? next;
      final List<Map<String, dynamic>> items;
      switch (cursor) {
        case null:
          items = first;
          next = 'p2';
        case 'p2':
          items = second;
          next = repeating ? 'p2' : 'p3';
        case 'p3':
          items = third;
          next = repeating ? 'p2' : null;
        default:
          items = const [];
          next = null;
      }
      return jsonResponse(
        jsonEncode({'items': items, 'next_cursor': next}),
        headers: {'cache-control': 'max-age=300'},
      );
    }

    await openDrives(tester, (request) async {
      if (request.url.path.endsWith('/meta')) {
        return jsonResponse(File('test/fixtures/meta.json').readAsStringSync());
      }
      return pages(request);
    }, now: () => now);
    for (var i = 0; i < 2; i++) {
      await tapLoadMore(tester);
    }
    await revealRow(tester, 13);
    expect(find.byKey(const ValueKey('drive-13')), findsOneWidget);
    expect(find.textContaining('已显示全部'), findsOneWidget);
    repeating = true;
    await selectTab(tester, '概览');
    now = now.add(const Duration(minutes: 10));
    await selectTab(tester, '行程');
    // CP07：重复游标的人话是「没能加载更多行程，已保留当前列表」。
    expect(
      find.textContaining('没能加载更多行程'),
      findsOneWidget,
      reason: '重复游标是数据条件，不是契约版本问题',
    );
    expect(find.textContaining('格式不兼容'), findsNothing);
    await revealRow(tester, 13);
    expect(find.byKey(const ValueKey('drive-13')), findsOneWidget);
    await revealRow(tester, 17);
    expect(find.byKey(const ValueKey('drive-17')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
