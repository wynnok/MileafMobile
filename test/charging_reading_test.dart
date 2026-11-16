import 'overview_statistics_reading_test.dart'
    show pumpReadingApp, openChargingTopic, readingClient, chargingDays;

import 'package:mileaf/src/design/layout.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/src/charging_page.dart';
import 'package:mileaf/src/design/components/components.dart';

import 'charging_cost_test.dart' show openCostSheet;
import 'charging_detail_test.dart' show fixture;
import 'charging_expansion_test.dart' show chargingStatsV2;
import 'charging_test.dart' show initial, jsonResponse;
import 'overview_test.dart' show background, foreground;
import 'reading_continuity_test.dart' show openTab;

/// A controllable charging ledger: real cursor pages, filters honoured like
/// the server, fee writes that change the record, and an optional downgrade to
/// the 0.1 contract.
class LedgerSite {
  LedgerSite({
    this.version = '0.4.0',
    this.capability = true,
    this.pageSize = 2,
  });

  String version;
  bool capability;
  int pageSize;
  int maxAge = 0, statsMaxAge = 0;
  int listFailures = 0, statsFailures = 0;

  bool wrote = false, windowBuckets = false;
  int matchedOffset = 0;
  String? repeatedCursor, failCursor;

  /// Holds the next cursor-less list read until it completes, so a test can
  /// hide the ledger while the first page is still in flight.
  Completer<void>? holdFirstPage;
  final hidden = <int>{};
  final records = <LedgerRecord>[
    LedgerRecord(9, '2026-03-29T01:00:00Z', '2026-03-29T02:00:00Z', cost: null),
    LedgerRecord(31, '2026-03-28T01:00:00Z', '2026-03-28T02:00:00Z'),
    LedgerRecord(
      32,
      '2026-03-27T01:00:00Z',
      '2026-03-27T02:00:00Z',
      cost: null,
    ),
    LedgerRecord(33, '2026-03-26T01:00:00Z', '2026-03-26T02:00:00Z'),
    LedgerRecord(34, '2026-03-25T01:00:00Z', '2026-03-25T02:00:00Z'),
    LedgerRecord(35, '2026-03-24T01:00:00Z', '2026-03-24T02:00:00Z'),
  ];
  final reads = <http.Request>[];
  final writes = <http.Request>[];
  late final client = MockClient(handle);

  List<LedgerRecord> matching(Map<String, String> query) {
    final term = query['query'];
    final type = query['charging_type'];
    final cost = query['cost_status'];
    final place = query['location_id'];
    return records.where((record) {
      if (hidden.contains(record.id)) return false;
      if (term != null && !record.name.contains(term)) return false;
      if (type != null && record.type != type) return false;
      if (cost == 'known' && record.cost == null) return false;
      if (cost == 'unknown' && record.cost != null) return false;
      if (cost == 'zero' && record.cost != 0) return false;
      if (place != null && record.place != place) return false;
      return true;
    }).toList();
  }

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    final query = request.url.queryParameters;
    if (request.method == 'GET') reads.add(request);
    if (path.endsWith('/meta')) {
      return jsonResponse({
        'version': version,
        if (capability) ...{
          'charging_experience': {
            'contract_version': 'charging-experience-v1',
            'minimum_server_version': '0.2.0',
            'tested_schema_version': 20260808090000,
            'fields': <String, bool>{},
          },
        },
      });
    }
    if (path.endsWith('/vehicles/1/charging-sessions')) {
      final pending = holdFirstPage;
      if (pending != null && query['cursor'] == null) {
        holdFirstPage = null;
        await pending.future;
      }
      if (listFailures > 0) {
        listFailures--;
        return http.Response('', 503);
      }
      if (failCursor != null && query['cursor'] == failCursor) {
        failCursor = null;
        return http.Response('', 503);
      }
      final found = matching(query);
      final cursor = query['cursor'];
      final start = cursor == null ? 0 : int.parse(cursor.substring(1));
      final page = found.skip(start).take(pageSize).toList();
      final next = start + pageSize < found.length
          ? 'p${start + pageSize}'
          : null;
      return jsonResponse(
        {
          'items': [for (final record in page) record.json],
          'next_cursor': repeatedCursor ?? next,
          'matched_sessions': found.length + matchedOffset,
          'query': {
            'from': query['from'],
            'to': query['to'],
            'tz': query['tz'],
            'time_basis': 'ended_at',
            'filters': {
              'charging_type': query['charging_type'],
              'cost_status': query['cost_status'],
              'location_id': query['location_id'],
              'query': query['query'],
            },
          },
          'as_of': '2026-03-30T12:00:00Z',
        },
        headers: {'cache-control': 'max-age=$maxAge'},
      );
    }
    if (path.endsWith('/charging-sessions/9') ||
        path.endsWith('/charging-sessions/32')) {
      final id = int.parse(path.split('/').last);
      return jsonResponse({
        ..._detailFixture,
        'id': id,
        'vehicle_id': 1,
        'cost': records.firstWhere((record) => record.id == id).cost,
        'ended_at': '2026-03-29T02:00:00Z',
        'is_active': false,
      });
    }
    if (path.endsWith('/series')) {
      return jsonResponse(_seriesFixture);
    }
    if (path.endsWith('/cost')) {
      writes.add(request);
      return _writeCost(request);
    }
    if (path.endsWith('/charging-locations')) {
      return jsonResponse({
        'items': [
          for (final record in records)
            if (query['location_id'] == null ||
                query['location_id'] == record.place)
              {
                ...chargingStatsV2()['totals'] as Map<String, dynamic>,
                'location_id': record.place,
                'identity_kind': 'geofence',
                'location': {
                  'display_name': record.name,
                  'geofence': record.name,
                  'address': null,
                  'lat': null,
                  'lon': null,
                },
                'representative_session_id': record.id,
                'coordinate_source': null,
              },
        ],
        'next_cursor': null,
        'total_locations': records.length,
        'unlocated_sessions': 0,
        'query': {
          'from': query['from'],
          'to': query['to'],
          'tz': query['tz'],
          'time_basis': 'ended_at',
          'filters': {
            'charging_type': query['charging_type'],
            'cost_status': query['cost_status'],
            'location_id': query['location_id'],
            'query': query['query'],
          },
        },
        'as_of': '2026-03-30T12:00:00Z',
      });
    }
    if (path.endsWith('/stats') && query['kind'] == 'charging') {
      if (statsFailures > 0) {
        statsFailures--;
        return http.Response('', 503);
      }
      final body = windowBuckets ? _windowStats(query) : chargingStatsV2();
      if (wrote) {
        final totals = body['totals'] as Map<String, dynamic>;
        totals['cost_known_sessions'] =
            (totals['cost_known_sessions'] as int) + 1;
      }
      return jsonResponse(
        body,
        headers: {'cache-control': 'max-age=$statsMaxAge'},
      );
    }
    return initial(request);
  }

  /// One bucket per calendar day of the requested window, like the server.
  Map<String, dynamic> _windowStats(Map<String, String> query) {
    final base = chargingStatsV2();
    final template = (base['buckets'] as List).first as Map<String, dynamic>;
    final from = DateTime.parse(query['from']!);
    final to = DateTime.parse(query['to']!);
    final buckets = <Map<String, dynamic>>[];
    for (
      var day = from;
      day.isBefore(to);
      day = day.add(const Duration(days: 1))
    ) {
      buckets.add({...template, 'bucket_start': day.toIso8601String()});
    }
    return {...base, 'buckets': buckets};
  }

  http.Response _writeCost(http.Request request) {
    wrote = true;
    final id = int.parse(
      RegExp(r'/charging-sessions/(\d+)/cost')
          .firstMatch(request.url.path)!
          .group(1)!,
    );
    final unit = jsonDecode(request.body)['unit_price'] as String;
    final record = records.firstWhere((value) => value.id == id);
    final billed = (record.added ?? 0) > (record.used ?? 0)
        ? record.added!
        : record.used!;
    record.cost = double.parse(
      (billed * double.parse(unit)).toStringAsFixed(2),
    );
    return jsonResponse({
      'session_id': id,
      'unit_price': unit,
      'billing_energy_kwh': '$billed',
      'cost': record.cost!.toStringAsFixed(2),
    });
  }
}

class LedgerRecord {
  LedgerRecord(
    this.id,
    this.started,
    this.ended, {
    this.cost = 12.0,
    this.added = 20.0,
    this.used = 22.0,
    this.dc = false,
    this.place = 'geofence:1',
    this.name = '家 · 地库',
  });
  final int id;
  final String started, ended;
  double? cost, added, used;
  final bool dc;
  final String place, name;
  String get type => dc ? 'dc' : 'ac';
  Map<String, dynamic> get json => {
    'id': id,
    'started_at': started,
    'ended_at': ended,
    'duration_min': 60,
    'energy_added_kwh': added,
    'energy_used_kwh': used,
    'start_soc': 40,
    'end_soc': 70,
    'cost': cost,
    'is_dc': dc,
    'is_active': false,
    'location_id': place,
    'location': {
      'display_name': name,
      'geofence': name,
      'address': null,
      'lat': null,
      'lon': null,
    },
  };
}

final Map<String, dynamic> _detailFixture = fixture('charging-detail');
final Map<String, dynamic> _seriesFixture = fixture('charging-series');

ScrollPosition ledgerScroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(ChargingPage),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

double ledgerOffset(WidgetTester tester) => ledgerScroll(tester).pixels;

int ledgerReads(LedgerSite site) => site.reads
    .where(
      (request) => request.url.path.endsWith('/vehicles/1/charging-sessions'),
    )
    .length;

Future<void> openLedger(
  WidgetTester tester,
  LedgerSite site, {
  DateTime Function()? now,
  String Function()? zone,
}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await openTab(
    tester,
    site.client,
    tab: '充电',
    now: now,
    zone: zone ?? () => 'UTC',
  );
}

/// Reads the ledger list to its loaded end by following the cursor once.
Future<void> readLedgerToEnd(WidgetTester tester) async {
  final scrollable = find
      .descendant(
        of: find.byType(ChargingPage),
        matching: find.byType(Scrollable),
      )
      .first;
  final more = find.text('加载更多充电').hitTestable();
  final end = find.text('已到最后一条').hitTestable();
  for (
    var step = 0;
    step < 60 && more.evaluate().isEmpty && end.evaluate().isEmpty;
    step++
  ) {
    await tester.drag(scrollable, const Offset(0, -200));
    await tester.pumpAndSettle();
  }
  expect(more.evaluate().isNotEmpty || end.evaluate().isNotEmpty, isTrue);
  if (more.evaluate().isNotEmpty) {
    await tester.tapAt(tester.getCenter(more));
    await tester.pumpAndSettle();
  }
  await tester.scrollUntilVisible(end, 200, scrollable: scrollable);
  await tester.pumpAndSettle();
}

class DelayedLedger extends LedgerSite {
  bool armed = false, held = false;
  final hold = Completer<void>();
  @override
  Future<http.Response> handle(http.Request request) async {
    if (armed && request.url.path.endsWith('/meta')) {
      held = true;
      await hold.future;
    }
    return super.handle(request);
  }
}

void main() {
  testWidgets(
    'Spec meta probe: hidden charging topic must not derive requests after late meta',
    (tester) async {
      final baseSeen = <Uri>[];
      final seen = <Uri>[];
      final base = readingClient(baseSeen, charging: chargingDays);
      bool armed = false;
      final hold = Completer<void>();
      bool held = false;
      final client = MockClient((request) async {
        seen.add(request.url);
        if (armed && request.url.path.endsWith('/meta')) {
          held = true;
          await hold.future;
        }
        final copy = http.Request(request.method, request.url)
          ..headers.addAll(request.headers)
          ..bodyBytes = request.bodyBytes;
        return http.Response.fromStream(await base.send(copy));
      });
      await pumpReadingApp(tester, client);
      await openChargingTopic(tester);
      // R09：刷新入口改为图标按钮；仅更新定位器，探测断言不变。
      final refresh = find.byTooltip('刷新补能统计');
      await tester.ensureVisible(refresh);
      await tester.pumpAndSettle();
      armed = true;
      await tester.tap(refresh);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      expect(held, isTrue);
      await tester.tap(
        find.descendant(
          of: find.byType(MileafNavBar),
          matching: find.text('行程'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      final before = seen.length;
      armed = false;
      hold.complete();
      await tester.pumpAndSettle();
      final derived = seen
          .skip(before)
          .where(
            (u) =>
                u.path.endsWith('/charging-locations') ||
                (u.path.endsWith('/stats') &&
                    u.queryParameters['kind'] == 'charging'),
          )
          .toList();
      expect(
        derived,
        isEmpty,
        reason: '隐藏后meta完成只能结束原请求，不能派生新的补能查询。实际 $derived',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(MileafNavBar),
          matching: find.text('统计'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('补能账目'), findsOneWidget);
      expect(find.byType(MileafProgressLine), findsNothing);
    },
  );
  testWidgets(
    'Spec meta probe: hidden ledger must not derive requests after foreground meta',
    (tester) async {
      var now = DateTime.utc(2026, 3, 30, 12);
      final site = DelayedLedger();
      await openLedger(tester, site, now: () => now);
      Future<void> tab(String label, {bool settle = true}) async {
        await tester.tap(
          find.descendant(
            of: find.byType(MileafNavBar),
            matching: find.text(label),
          ),
        );
        if (settle) {
          await tester.pumpAndSettle();
        } else {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 32));
        }
      }

      await tab('概览');
      now = now.add(const Duration(minutes: 10));
      site.armed = true;
      await tab('充电', settle: false);
      expect(site.held, isTrue);
      await tab('行程', settle: false);
      final before = site.reads.length;
      site.armed = false;
      site.hold.complete();
      await tester.pumpAndSettle();
      final derived = site.reads
          .skip(before)
          .where(
            (r) =>
                r.url.path.endsWith('/charging-sessions') ||
                r.url.path.endsWith('/charging-locations') ||
                (r.url.path.endsWith('/stats') &&
                    r.url.queryParameters['kind'] == 'charging'),
          )
          .map((r) => r.url)
          .toList();
      expect(derived, isEmpty, reason: '账本隐藏后meta结束不得新派生查询。实际 $derived');
      await tab('充电');
      expect(
        site.reads
            .skip(before)
            .where((r) => r.url.path.endsWith('/charging-sessions')),
        isNotEmpty,
      );
      expect(find.byType(MileafProgressLine), findsNothing);
    },
  );

  testWidgets('TTL过期后返回账本保留已加载的第二页与阅读位置', (tester) async {
    final site = LedgerSite();
    await openLedger(tester, site);
    await tester.tap(find.text('全部记录'));
    await tester.pumpAndSettle();
    await readLedgerToEnd(tester);
    final offset = ledgerOffset(tester);
    expect(offset, greaterThan(0));
    await tester.tap(find.text('概览').last);
    await tester.pumpAndSettle();
    site.reads.clear();
    await tester.tap(find.text('充电').last);
    await tester.pumpAndSettle();
    expect(
      site.reads.where((r) => r.url.queryParameters['cursor'] == 'p2'),
      isNotEmpty,
    );
    expect(find.text('加载更多充电'), findsNothing);
    expect(find.text('已到最后一条'), findsOneWidget);
    expect(ledgerOffset(tester), closeTo(offset, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('图表指标与选日在账本刷新后按日期保留', (tester) async {
    final site = LedgerSite();
    await openLedger(tester, site);
    await tester.scrollUntilVisible(
      find.text('每日补能').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(StatusChip, '费用').hitTestable(),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(StatusChip, '费用').hitTestable());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('charging-briefing-chart')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final plot = tester.getRect(
      find.byKey(const Key('charging-briefing-chart')),
    );
    await tester.tapAt(Offset(plot.left + plot.width * 0.4, plot.center.dy));
    await tester.pumpAndSettle();
    final readout = tester
        .widget<Text>(find.textContaining(RegExp(r'^\d+/\d+ ')))
        .data!;
    expect(readout, contains('12'));
    await tester.tap(find.text('概览').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<StatusChip>(find.widgetWithText(StatusChip, '费用')).selected,
      isTrue,
    );
    expect(find.text(readout), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('隐藏账本收到费用失效不请求，恢复可见后读取新费用且失败仍重试', (tester) async {
    final site = LedgerSite()..maxAge = 300;
    await openLedger(tester, site);
    await tester.tap(find.text('全部记录'));
    await tester.pumpAndSettle();
    expect(find.text('费用 —，币种未记录'), findsWidgets);
    // A real entry from another main entry: the ledger tab stays hidden.
    await tester.tap(find.text('概览').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('最近充电').hitTestable(), 200);
    await tester.tap(find.text('最近充电').hitTestable());
    await tester.pumpAndSettle();
    await openCostSheet(tester);
    await tester.enterText(find.byType(TextField).last, '1.25');
    await tester.pumpAndSettle();
    site.reads.clear();
    await tester.tap(find.text('确认补录'));
    await tester.pumpAndSettle();
    expect(site.writes, hasLength(1));
    expect(
      site.reads.where(
        (request) =>
            request.url.path.endsWith('/vehicles/1/charging-sessions') ||
            request.url.path.endsWith('/stats') ||
            request.url.path.endsWith('/charging-locations'),
      ),
      isEmpty,
      reason: '隐藏页面不因费用失效主动刷新',
    );
    expect(find.textContaining('费用已补录'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    // The deferred refresh runs on the visible frame; the ledger keeps its
    // snapshot when that read fails.
    site.listFailures = 1;
    await tester.tap(find.text('充电').last);
    await tester.pumpAndSettle();
    expect(ledgerReads(site), greaterThan(0));
    expect(find.text('费用 —，币种未记录'), findsWidgets);
    // A failed deferred refresh stays pending instead of silently keeping the
    // old cost until the next TTL.
    await tester.tap(find.text('概览').last);
    await tester.pumpAndSettle();
    site.reads.clear();
    await tester.tap(find.text('充电').last);
    await tester.pumpAndSettle();
    expect(ledgerReads(site), greaterThan(0));
    expect(find.text('费用 27.5，币种未记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('补录后汇总读取失败，重新可见仍重试而不信任旧快照', (tester) async {
    final site = LedgerSite()
      ..maxAge = 300
      ..statsMaxAge = 300;
    await openLedger(tester, site);
    expect(find.textContaining('费用有记录 2 / 8 次'), findsOneWidget);
    await tester.tap(find.text('概览').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('最近充电').hitTestable(), 200);
    await tester.tap(find.text('最近充电').hitTestable());
    await tester.pumpAndSettle();
    await openCostSheet(tester);
    await tester.enterText(find.byType(TextField).last, '1.25');
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认补录'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    site
      ..listFailures = 1
      ..statsFailures = 1;
    await tester.tap(find.text('充电').last);
    await tester.pumpAndSettle();
    // The deferred fee refresh failed for the summary; the ledger keeps its
    // snapshot instead of claiming a new total.
    expect(find.textContaining('费用有记录 2 / 8 次'), findsOneWidget);
    await tester.tap(find.text('概览').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电').last);
    await tester.pumpAndSettle();
    // The pending fee revision must still force a real revalidation, not hit
    // the old local snapshot.
    expect(find.textContaining('费用有记录 3 / 8 次'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('跨日后保留搜索、类型、费用与排序条件并从第一页重建', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    var zone = 'UTC';
    final site = LedgerSite();
    await openLedger(tester, site, now: () => now, zone: () => zone);
    await tester.tap(find.text('全部记录'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('charging-search')), '家');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部类型'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AC').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部费用'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('费用未知').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('最近结束'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最近开始').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('地点搜索：家'), findsOneWidget);
    expect(find.textContaining('类型：AC'), findsOneWidget);
    site.reads.clear();
    now = DateTime.utc(2026, 3, 31, 0, 30);
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    final rebuilt = site.reads.lastWhere(
      (request) => request.url.path.endsWith('/vehicles/1/charging-sessions'),
    );
    expect(rebuilt.url.queryParameters['query'], '家');
    expect(rebuilt.url.queryParameters['charging_type'], 'ac');
    expect(rebuilt.url.queryParameters['cost_status'], 'unknown');
    expect(rebuilt.url.queryParameters['sort'], 'started_desc');
    expect(rebuilt.url.queryParameters.containsKey('cursor'), isFalse);
    expect(rebuilt.url.queryParameters['from'], '2026-03-02T00:00:00.000Z');
    expect(find.textContaining('地点搜索：家'), findsOneWidget);
    // A zone change re-parses the same conditions on the new calendar.
    site.reads.clear();
    zone = 'Asia/Shanghai';
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    final zoneRebuilt = site.reads.lastWhere(
      (request) => request.url.path.endsWith('/vehicles/1/charging-sessions'),
    );
    expect(zoneRebuilt.url.queryParameters['query'], '家');
    expect(zoneRebuilt.url.queryParameters['from'], '2026-03-01T16:00:00.000Z');
    expect(find.textContaining('地点搜索：家'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('分页重校验中间失败保留已读页，重试不回到第一页', (tester) async {
    final site = LedgerSite();
    await openLedger(tester, site);
    await tester.tap(find.text('全部记录'));
    await tester.pumpAndSettle();
    await readLedgerToEnd(tester);
    expect(find.byKey(const ValueKey('charge-34')), findsOneWidget);
    await tester.tap(find.text('概览').last);
    await tester.pumpAndSettle();
    site.failCursor = 'p2';
    site.reads.clear();
    await tester.tap(find.text('充电').last);
    await tester.pumpAndSettle();
    // The first page came back, the second did not: the pages already read
    // stay on screen instead of collapsing to the first one.
    expect(find.byKey(const ValueKey('charge-34')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('重试充电'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    site.reads.clear();
    await tester.tap(find.text('重试充电'));
    await tester.pumpAndSettle();
    // Page one is re-read together with the page that failed; a further
    // cursor belongs to the next scroll, not to the retry itself.
    expect(
      site.reads
          .where((r) => r.url.path.endsWith('/charging-sessions'))
          .map((r) => r.url.queryParameters['cursor'])
          .take(2),
      [null, 'p2'],
    );
    await tester.scrollUntilVisible(
      find.text('已到最后一条'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('已到最后一条'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('重新校验后记录减少，阅读位置与已读范围收敛到有效数据', (tester) async {
    final site = LedgerSite();
    await openLedger(tester, site);
    await tester.tap(find.text('全部记录'));
    await tester.pumpAndSettle();
    await readLedgerToEnd(tester);
    final offset = ledgerOffset(tester);
    expect(offset, greaterThan(0));
    site.hidden.addAll([33, 34, 35]);
    await tester.tap(find.text('概览').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('charge-35')), findsNothing);
    expect(find.byKey(const ValueKey('charge-34')), findsNothing);
    await tester.scrollUntilVisible(
      find.text('已到最后一条'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('已到最后一条'), findsOneWidget);
    expect(
      ledgerOffset(tester),
      lessThanOrEqualTo(ledgerScroll(tester).maxScrollExtent),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('游标不前进时明确报告且不继续翻页', (tester) async {
    final site = LedgerSite()..repeatedCursor = 'p2';
    await openLedger(tester, site);
    await tester.tap(find.text('全部记录'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('加载更多充电'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    site.reads.clear();
    await tester.tap(find.text('加载更多充电'));
    await tester.pumpAndSettle();
    expect(
      site.reads.where((r) => r.url.path.endsWith('/charging-sessions')).length,
      1,
    );
    await tester.scrollUntilVisible(
      find.textContaining('分页游标未前进'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('分页游标未前进'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('缺失费用筛选下补录后记录移出结果，匹配数随之更新', (tester) async {
    final site = LedgerSite();
    await openLedger(tester, site);
    await tester.tap(find.text('全部记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部费用'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('费用未知').last);
    await tester.pumpAndSettle();
    expect(find.text('匹配 2 次充电'), findsOneWidget);
    expect(find.byKey(const ValueKey('charge-9')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('补录费用').first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('补录费用').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '1.25');
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认补录'));
    await tester.pumpAndSettle();
    expect(find.textContaining('费用已补录'), findsOneWidget);
    expect(find.text('匹配 1 次充电'), findsOneWidget);
    expect(find.byKey(const ValueKey('charge-9')), findsNothing);
    expect(find.byKey(const ValueKey('charge-32')), findsOneWidget);
    expect(
      ledgerOffset(tester),
      lessThanOrEqualTo(ledgerScroll(tester).maxScrollExtent),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('详情入口补录返回列表即更新并保留已读范围', (tester) async {
    final site = LedgerSite()..maxAge = 300;
    await openLedger(tester, site);
    await tester.tap(find.text('全部记录'));
    await tester.pumpAndSettle();
    await readLedgerToEnd(tester);
    final offset = ledgerOffset(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('charge-9')).hitTestable(),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('charge-9')).hitTestable());
    await tester.pumpAndSettle();
    await openCostSheet(tester);
    await tester.enterText(find.byType(TextField).last, '1.25');
    await tester.pumpAndSettle();
    site.reads.clear();
    await tester.tap(find.text('确认补录'));
    await tester.pumpAndSettle();
    // The ledger sits under its own record detail: it keeps its snapshot and
    // revalidates once that route returns.
    expect(
      site.reads.where(
        (request) =>
            request.url.path.endsWith('/vehicles/1/charging-sessions') ||
            request.url.path.endsWith('/stats') ||
            request.url.path.endsWith('/charging-locations'),
      ),
      isEmpty,
    );
    expect(find.textContaining('费用已补录'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      site.reads.where(
        (request) => request.url.path.endsWith('/vehicles/1/charging-sessions'),
      ),
      isNotEmpty,
    );
    expect(find.text('费用 27.5，币种未记录'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('已到最后一条'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('已到最后一条'), findsOneWidget);
    expect(find.byKey(const ValueKey('charge-34')), findsOneWidget);
    expect(ledgerOffset(tester), closeTo(offset, 400));
    expect(tester.takeException(), isNull);
  });

  testWidgets('多条件筛选、多页与滚动位置在 Tab 往返后原样保留', (tester) async {
    final site = LedgerSite()..maxAge = 300;
    await openLedger(tester, site);
    await tester.tap(find.text('全部记录'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('charging-search')), '家');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部类型'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AC').last);
    await tester.pumpAndSettle();
    await readLedgerToEnd(tester);
    final offset = ledgerOffset(tester);
    expect(offset, greaterThan(0));
    site.reads.clear();
    await tester.tap(find.text('概览').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电').last);
    await tester.pumpAndSettle();
    expect(
      site.reads.where(
        (request) => request.url.path.endsWith('/vehicles/1/charging-sessions'),
      ),
      isEmpty,
      reason: 'TTL 未过期时 Tab 往返不重复读取',
    );
    // Re-tapping the current entry is a no-op: no reset, no scroll jump.
    await tester.tap(find.text('充电').last);
    await tester.pumpAndSettle();
    expect(
      site.reads.where(
        (request) => request.url.path.endsWith('/vehicles/1/charging-sessions'),
      ),
      isEmpty,
    );
    expect(ledgerOffset(tester), closeTo(offset, 400));
    expect(find.byKey(const ValueKey('charge-34')), findsOneWidget);
    expect(find.text('加载更多充电'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('已到最后一条'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('已到最后一条'), findsOneWidget);
    expect(ledgerOffset(tester), closeTo(offset, 400));
    await tester.scrollUntilVisible(
      find.textContaining('地点搜索：家'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('类型：AC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('选日与阅读位置在 Tab 往返后保留', (tester) async {
    final site = LedgerSite()..maxAge = 300;
    await openLedger(tester, site);
    await tester.scrollUntilVisible(
      find.text('每日补能').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final plot = tester.getRect(
      find.byKey(const Key('charging-briefing-chart')),
    );
    await tester.tapAt(Offset(plot.right - 2, plot.center.dy));
    await tester.pumpAndSettle();
    await tester.tap(find.text('看当天'));
    await tester.pumpAndSettle();
    expect(find.textContaining('仅看 2026年3月30日结束的充电'), findsOneWidget);
    await tester.tap(find.text('概览').last);
    await tester.pumpAndSettle();
    site.reads.clear();
    await tester.tap(find.text('充电').last);
    await tester.pumpAndSettle();
    expect(
      site.reads.where(
        (request) => request.url.path.endsWith('/vehicles/1/charging-sessions'),
      ),
      isEmpty,
    );
    await tester.scrollUntilVisible(
      find.textContaining('仅看 2026年3月30日结束的充电'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('返回完整区间'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('跨日后选中的日期落在窗口外时清除，不保留悬空选日', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final site = LedgerSite()..windowBuckets = true;
    await openLedger(tester, site, now: () => now);
    await tester.tap(find.widgetWithText(StatusChip, '近7天'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('每日补能').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final plot = tester.getRect(
      find.byKey(const Key('charging-briefing-chart')),
    );
    await tester.tapAt(Offset(plot.left + 2, plot.center.dy));
    await tester.pumpAndSettle();
    await tester.tap(find.text('看当天'));
    await tester.pumpAndSettle();
    expect(find.textContaining('仅看 2026年3月24日结束的充电'), findsOneWidget);
    now = DateTime.utc(2026, 3, 31, 0, 30);
    site.reads.clear();
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('自定义日期').hitTestable(),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.bySemanticsLabel(RegExp('自定义日期，2026/3/25–2026/3/31')),
      findsOneWidget,
    );
    expect(find.textContaining('仅看'), findsNothing);
    expect(find.text('返回完整区间'), findsNothing);
    final rebuilt = site.reads.lastWhere(
      (request) => request.url.path.endsWith('/vehicles/1/charging-sessions'),
    );
    expect(rebuilt.url.queryParameters['from'], '2026-03-25T00:00:00.000Z');
    expect(rebuilt.url.queryParameters.containsKey('cursor'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('地点与记录消失时给出一致空结果，不留下无效选中', (tester) async {
    final site = LedgerSite();
    await openLedger(tester, site);
    final locationRow = find.widgetWithText(ListTile, '家 · 地库');
    await tester.scrollUntilVisible(
      locationRow,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(locationRow);
    await tester.pumpAndSettle();
    expect(find.textContaining('地点：家 · 地库'), findsOneWidget);
    expect(find.text('匹配 6 次充电'), findsOneWidget);
    // The whole place disappears from the server, records included.
    site.hidden.addAll([9, 31, 32, 33, 34, 35]);
    await tester.tap(find.text('概览').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电').last);
    await tester.pumpAndSettle();
    expect(find.text('匹配 0 次充电'), findsOneWidget);
    expect(find.text('此区间无已完成充电记录'), findsOneWidget);
    expect(find.textContaining('地点：家 · 地库'), findsOneWidget);
    expect(find.text('清除筛选'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('能力降级后清除扩展条件并回退到旧站点查询', (tester) async {
    final site = LedgerSite();
    await openLedger(tester, site);
    await tester.tap(find.text('全部记录'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('charging-search')), '家');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.textContaining('地点搜索：家'), findsOneWidget);
    site
      ..version = '0.1.0'
      ..capability = false;
    site.reads.clear();
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    final legacy = site.reads.lastWhere(
      (request) => request.url.path.endsWith('/vehicles/1/charging-sessions'),
    );
    expect(legacy.url.queryParameters.containsKey('query'), isFalse);
    expect(legacy.url.queryParameters.containsKey('time_basis'), isFalse);
    expect(legacy.url.queryParameters.containsKey('sort'), isFalse);
    await tester.scrollUntilVisible(
      find.textContaining('未提供充电扩展能力').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('地点搜索：家'), findsNothing);
    expect(find.byKey(const ValueKey('charge-9')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('重校验遇到重复游标不无限翻页，保留已读页并说明原因', (tester) async {
    final site = LedgerSite();
    await openLedger(tester, site);
    await tester.tap(find.text('全部记录'));
    await tester.pumpAndSettle();
    await readLedgerToEnd(tester);
    expect(find.byKey(const ValueKey('charge-34')), findsOneWidget);
    // The server starts repeating a cursor in the middle of the range.
    site.repeatedCursor = 'p2';
    await tester.tap(find.text('概览').last);
    await tester.pumpAndSettle();
    site.reads.clear();
    await tester.tap(find.text('充电').last);
    await tester.pumpAndSettle();
    expect(
      site.reads.where((r) => r.url.path.endsWith('/charging-sessions')).length,
      lessThanOrEqualTo(4),
      reason: '重复游标必须终止翻页',
    );
    expect(find.byKey(const ValueKey('charge-34')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('分页游标未前进'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('服务返回格式不兼容'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('被详情遮挡的账本跨日不请求，返回后才补校验', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final site = LedgerSite()..maxAge = 300;
    await openLedger(tester, site, now: () => now);
    await tester.tap(find.text('全部记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('charge-9')).hitTestable());
    await tester.pumpAndSettle();
    // Cross the local midnight while the ledger sits under its own detail.
    now = DateTime.utc(2026, 3, 31, 0, 30);
    site.reads.clear();
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(
      site.reads.where(
        (request) =>
            request.url.path.endsWith('/vehicles/1/charging-sessions') ||
            request.url.path.endsWith('/charging-locations'),
      ),
      isEmpty,
      reason: '被路由遮挡的账本不得因跨日主动请求自己的区间',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      site.reads.where(
        (request) => request.url.path.endsWith('/vehicles/1/charging-sessions'),
      ),
      isNotEmpty,
      reason: '返回可见后必须补校验',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('账本重校验中途隐藏后不再翻页，返回后补齐全段', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final site = LedgerSite();
    await openLedger(tester, site, now: () => now);
    await tester.tap(find.text('全部记录'));
    await tester.pumpAndSettle();
    await readLedgerToEnd(tester);
    expect(find.text('已到最后一条'), findsOneWidget);
    await tester.tap(find.text('概览').last);
    await tester.pumpAndSettle();
    now = now.add(const Duration(minutes: 10));
    final gate = Completer<void>();
    site
      ..holdFirstPage = gate
      ..reads.clear();
    await tester.tap(find.text('充电').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    expect(
      site.reads.where(
        (request) =>
            request.url.path.endsWith('/vehicles/1/charging-sessions') &&
            request.url.queryParameters['cursor'] == null,
      ),
      isNotEmpty,
      reason: '前置：重校验的第一页请求确实在途',
    );
    await tester.tap(find.text('概览').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    gate.complete();
    await tester.pumpAndSettle();
    expect(
      site.reads.where(
        (request) => request.url.queryParameters['cursor'] == 'p2',
      ),
      isEmpty,
      reason: '页面隐藏后，第一页的迟到响应不得再请求第二页',
    );
    site.reads.clear();
    await tester.tap(find.text('充电').last);
    await tester.pumpAndSettle();
    expect(find.text('已到最后一条'), findsOneWidget, reason: '返回后补齐已读的两页，不塌回第一页');
    expect(find.text('加载更多充电'), findsNothing);
    expect(
      site.reads.where(
        (request) => request.url.queryParameters['cursor'] == 'p2',
      ),
      isNotEmpty,
      reason: '再次可见时按原条件补齐整段已读范围',
    );
    expect(tester.takeException(), isNull);
  });
}
