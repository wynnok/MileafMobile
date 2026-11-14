import 'package:mileaf/src/drive_detail_page.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/drives_page.dart';
import 'package:mileaf/src/workspace.dart';

import 'drives_test.dart' show openDrives, jsonResponse;
import 'overview_test.dart' show background, foreground;
import 'overview_visualization_test.dart';
import 'statistics_test.dart' show openStats, custom;
import 'statistics_usage_test.dart' show usageClient;
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

Future<void> selectTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(MileafNavBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

/// Switches tabs without waiting for HTTP: a held read keeps the target tab
/// loading, so only the frames the navigation needs are pumped.
Future<void> tapNav(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(MileafNavBar), matching: find.text(label)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 32));
}

/// One complete drive row, so the list renders it as a normal record.
Map<String, dynamic> driveRow(
  int id,
  String startedAt, {
  double? distance = 8.4,
}) => {
  'id': id,
  'started_at': startedAt,
  'ended_at': startedAt,
  'distance_km': distance,
  'duration_min': 18,
  'energy_kwh': 1.7,
  'consumption_wh_km': 202.0,
  'start': {
    'display_name': null,
    'geofence': null,
    'address': null,
    'lat': null,
    'lon': null,
  },
  'end': {
    'display_name': null,
    'geofence': null,
    'address': null,
    'lat': null,
    'lon': null,
  },
};

ScrollPosition drivesScroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(DrivesPage),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

double drivesOffset(WidgetTester tester) => drivesScroll(tester).pixels;

/// Serves a cursor page per request; [tail] keeps a cursor after page two.
http.Response journeyPage(http.Request request, {String? tail}) {
  final cursor = request.url.queryParameters['cursor'];
  final items = switch (cursor) {
    null => [
      driveRow(17, '2026-03-30T02:00:00Z'),
      driveRow(16, '2026-03-29T21:30:00Z'),
    ],
    'page-2' => [
      driveRow(15, '2026-03-29T20:00:00Z'),
      driveRow(14, '2026-03-28T19:00:00Z'),
    ],
    _ => <Map<String, dynamic>>[],
  };
  final next = switch (cursor) {
    null => 'page-2',
    'page-2' => tail,
    _ => null,
  };
  return jsonResponse(
    jsonEncode({'items': items, 'next_cursor': next}),
    headers: {'cache-control': 'max-age=300'},
  );
}

/// Routes a journey detail route and the shared endpoints around it.
http.Response journeyRoutes(http.Request request) {
  final path = request.url.path;
  if (path.endsWith('/meta')) {
    return jsonResponse(File('test/fixtures/meta.json').readAsStringSync());
  }
  if (path.endsWith('/series')) {
    return jsonResponse(
      File('test/fixtures/drive-series.json').readAsStringSync(),
    );
  }
  if (RegExp(r'/drives/\d+$').hasMatch(path)) {
    return jsonResponse(
      File('test/fixtures/drive-detail.json').readAsStringSync(),
    );
  }
  return journeyPage(request);
}

/// Reads the journey list to the end of its loaded range. The page button is
/// brought fully into view first, so the tap never lands off screen.
Future<void> readToEndOfRange(WidgetTester tester) async {
  await tester.ensureVisible(find.text('加载更多行程'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('加载更多行程'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('已显示全部行程'));
  await tester.pumpAndSettle();
}

/// Shared endpoint routing for the main workspace tabs.
http.Client workspaceClient(
  List<Uri> log,
  Future<http.Response> Function(http.Request) fallback,
) => MockClient((request) async {
  log.add(request.url);
  final path = request.url.path;
  if (path.endsWith('/vehicles')) {
    return jsonResponse(File('test/fixtures/vehicles.json').readAsStringSync());
  }
  if (path.endsWith('/meta')) {
    return jsonResponse(
      File('test/fixtures/meta.json').readAsStringSync(),
      headers: {'cache-control': 'max-age=30'},
    );
  }
  if (path.endsWith('/summary')) {
    return jsonResponse(File('test/fixtures/summary.json').readAsStringSync());
  }
  if (path.endsWith('/stats')) {
    final name = request.url.queryParameters['kind'] == 'charging'
        ? 'charging-stats'
        : 'driving-stats';
    return jsonResponse(File('test/fixtures/$name.json').readAsStringSync());
  }
  return fallback(request);
});

Future<void> openTab(
  WidgetTester tester,
  http.Client client, {
  required String tab,
  DateTime Function()? now,
  String Function()? zone,
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
      now: now ?? () => DateTime.utc(2026, 3, 30, 12),
      calendar: () async => CalendarContext(zone?.call() ?? 'Asia/Shanghai'),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(tab).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('隐藏统计不刷新自定义期间，返回后恢复并校验', (tester) async {
    final requests = <Uri>[];
    var now = DateTime.utc(2026, 10, 28, 11);
    await openStats(
      tester,
      usageClient(requests),
      () => now,
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await custom(tester, '2026-10-02', '2026-10-03');
    await selectTab(tester, '行程');
    requests.clear();
    now = now.add(const Duration(minutes: 2));
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(
      requests.where(
        (uri) => uri.queryParameters['from'] == '2026-10-01T16:00:00.000Z',
      ),
      isEmpty,
    );
    await selectTab(tester, '统计');
    expect(
      tester.widget<StatusChip>(find.widgetWithText(StatusChip, '本月')).selected,
      isFalse,
    );
    expect(
      requests.where(
        (uri) => uri.queryParameters['from'] == '2026-10-01T16:00:00.000Z',
      ),
      isNotEmpty,
    );
  });
  testWidgets('概览隐藏时回前台不读取车况，返回后才校验', (tester) async {
    final requests = <Uri>[];
    await openOverviewVisual(tester, (request) async {
      requests.add(request.url);
      return overviewResponse(
        overviewFixture(
          request.url.path.endsWith('/summary')
              ? 'summary'
              : request.url.path.endsWith('/drives')
              ? 'drives'
              : request.url.queryParameters['kind'] == 'charging'
              ? 'charging-stats'
              : 'driving-stats',
        ),
        maxAge: 0,
      );
    });
    await selectTab(tester, '行程');
    requests.clear();
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(requests.where((uri) => uri.path.endsWith('/summary')), isEmpty);
    await selectTab(tester, '概览');
    expect(requests.where((uri) => uri.path.endsWith('/summary')), isNotEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('行程近7天在主入口往返后保留，重复点击不产生请求', (tester) async {
    final requests = <Uri>[];
    await openDrives(tester, (request) async {
      requests.add(request.url);
      return jsonResponse(
        File('test/fixtures/drives.json').readAsStringSync(),
        headers: {'cache-control': 'max-age=300'},
      );
    });
    await tester.tap(find.widgetWithText(StatusChip, '近7天'));
    await tester.pumpAndSettle();
    final range = requests.last.queryParameters['from'];
    await selectTab(tester, '概览');
    await selectTab(tester, '行程');
    expect(
      tester
          .widget<StatusChip>(find.widgetWithText(StatusChip, '近7天'))
          .selected,
      isTrue,
    );
    expect(
      requests
          .where((uri) => uri.path.endsWith('/drives'))
          .last
          .queryParameters['from'],
      range,
    );
    final count = requests.length;
    await selectTab(tester, '行程');
    expect(requests.length, count);
    expect(tester.takeException(), isNull);
  });

  testWidgets('时间推进后返回仍保留已加载的第二页与阅读位置', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final requests = <Uri>[];
    await openDrives(tester, (request) async {
      requests.add(request.url);
      return journeyPage(request);
    }, now: () => now);
    await readToEndOfRange(tester);
    final offset = drivesOffset(tester);
    expect(offset, greaterThan(0));
    await selectTab(tester, '概览');
    now = now.add(const Duration(minutes: 6));
    await selectTab(tester, '行程');
    expect(find.text('加载更多行程'), findsNothing);
    expect(find.text('已显示全部行程'), findsOneWidget);
    expect(drivesOffset(tester), closeTo(offset, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('充电页隐藏时不因回前台或换日发请求，重新可见才补校验', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final requests = <Uri>[];
    int ledgerReads() =>
        requests.where((uri) => uri.path.endsWith('/charging-sessions')).length;
    await openTab(
      tester,
      workspaceClient(requests, (request) async {
        if (request.url.path.endsWith('/drives')) {
          return jsonResponse(
            File('test/fixtures/drives.json').readAsStringSync(),
            headers: {'cache-control': 'max-age=300'},
          );
        }
        return jsonResponse(
          File('test/fixtures/charging-sessions.json').readAsStringSync(),
          headers: {'cache-control': 'max-age=0'},
        );
      }),
      tab: '充电',
      now: () => now,
    );
    expect(ledgerReads(), greaterThan(0));
    await selectTab(tester, '行程');
    requests.clear();
    now = now.add(const Duration(minutes: 10));
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(ledgerReads(), 0);
    // Cross the local midnight while the ledger stays hidden.
    now = DateTime.utc(2026, 3, 31, 0, 30);
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(ledgerReads(), 0);
    await selectTab(tester, '充电');
    expect(ledgerReads(), greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('自定义日期与选日在详情往返和Tab往返后保留', (tester) async {
    final requests = <Uri>[];
    await openDrives(tester, (request) async {
      requests.add(request.url);
      return journeyRoutes(request);
    });
    await tester.tap(find.text('自定义日期'));
    await tester.pumpAndSettle();
    final inputs = find.byType(TextField);
    await tester.enterText(inputs.at(0), '2026/02/01');
    await tester.enterText(inputs.at(1), '2026/03/30');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026-02-01 至 2026-03-30'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('看当天').hitTestable(), 140);
    await tester.tap(find.text('看当天'));
    await tester.pumpAndSettle();
    expect(find.text('返回完整区间'), findsOneWidget);
    final day = requests.lastWhere((uri) => uri.path.endsWith('/drives'));
    expect(find.text('已显示全部行程'), findsNothing);
    await tester.ensureVisible(find.text('加载更多行程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加载更多行程'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('已显示全部行程'));
    await tester.pumpAndSettle();
    final offset = drivesOffset(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('drive-14')).hitTestable(),
      120,
    );
    final offsetBeforeDetail = drivesOffset(tester);
    await tester.tap(find.byKey(const ValueKey('drive-14')));
    await tester.pumpAndSettle();
    expect(find.byType(DriveDetailPage), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(drivesOffset(tester), closeTo(offsetBeforeDetail, 1));
    expect(find.text('返回完整区间'), findsOneWidget);
    await selectTab(tester, '概览');
    await selectTab(tester, '行程');
    expect(find.text('返回完整区间'), findsOneWidget);
    expect(find.textContaining('2026-02-01 至 2026-03-30'), findsOneWidget);
    expect(find.text('已显示全部行程'), findsOneWidget);
    expect(
      requests
          .lastWhere((uri) => uri.path.endsWith('/drives'))
          .queryParameters['from'],
      day.queryParameters['from'],
    );
    expect(drivesOffset(tester), closeTo(offsetBeforeDetail, 1));
    expect(offset, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('重校验失败保留已加载范围与游标，不混用旧游标', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    var failing = false;
    final requests = <Uri>[];
    await openDrives(tester, (request) async {
      requests.add(request.url);
      if (request.url.path.endsWith('/meta')) {
        return jsonResponse(File('test/fixtures/meta.json').readAsStringSync());
      }
      if (failing) return http.Response('', 503);
      return journeyPage(request, tail: 'page-3');
    }, now: () => now);
    await tester.ensureVisible(find.text('加载更多行程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加载更多行程'));
    await tester.pumpAndSettle();
    expect(find.text('加载更多行程'), findsOneWidget);
    expect(find.byKey(const ValueKey('drive-14')), findsOneWidget);
    failing = true;
    await selectTab(tester, '概览');
    now = now.add(const Duration(minutes: 10));
    await selectTab(tester, '行程');
    expect(find.textContaining('保留上次快照'), findsOneWidget);
    expect(find.text('加载更多行程'), findsOneWidget);
    expect(find.byKey(const ValueKey('drive-14')), findsOneWidget);
    expect(find.byKey(const ValueKey('drive-15')), findsOneWidget);
    failing = false;
    await tester.ensureVisible(find.text('加载更多行程'));
    await tester.pumpAndSettle();
    final before = requests.length;
    await tester.tap(find.text('加载更多行程'));
    await tester.pumpAndSettle();
    expect(
      requests
          .skip(before)
          .firstWhere((uri) => uri.path.endsWith('/drives'))
          .queryParameters['cursor'],
      'page-3',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('跨日重算相对期间并从第一页开始，不沿用旧游标', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final requests = <Uri>[];
    await openDrives(tester, (request) async {
      requests.add(request.url);
      if (request.url.path.endsWith('/meta')) {
        return jsonResponse(File('test/fixtures/meta.json').readAsStringSync());
      }
      return journeyPage(request);
    }, now: () => now);
    await readToEndOfRange(tester);
    final before = requests.lastWhere((uri) => uri.path.endsWith('/drives'));
    requests.clear();
    now = DateTime.utc(2026, 3, 30, 17); // 01:00 next day in Asia/Shanghai
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    final after = requests.firstWhere((uri) => uri.path.endsWith('/drives'));
    expect(
      after.queryParameters['from'],
      isNot(before.queryParameters['from']),
    );
    expect(after.queryParameters.containsKey('cursor'), isFalse);
    expect(find.text('加载更多行程'), findsOneWidget);
    expect(find.text('已显示全部行程'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('重启后不恢复阅读状态，回到默认期间', (tester) async {
    await openDrives(
      tester,
      (request) async => request.url.path.endsWith('/meta')
          ? journeyRoutes(request)
          : journeyPage(request),
    );
    await tester.tap(find.widgetWithText(StatusChip, '近7天'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(StatusChip, '近7天').hitTestable(),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await openDrives(
      tester,
      (request) async => request.url.path.endsWith('/meta')
          ? journeyRoutes(request)
          : journeyPage(request),
    );
    final chip = tester.widget<StatusChip>(
      find.widgetWithText(StatusChip, '近7天'),
    );
    expect(chip.selected, isFalse);
    expect(
      tester
          .widget<StatusChip>(find.widgetWithText(StatusChip, '近30天'))
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('快速切车丢弃迟到响应，切回旧车重新建立默认阅读', (tester) async {
    final slow = Completer<http.Response>();
    var slowArmed = false;
    await openDrives(tester, (request) async {
      if (request.url.path.endsWith('/meta')) {
        return jsonResponse(File('test/fixtures/meta.json').readAsStringSync());
      }
      if (slowArmed && request.url.path.endsWith('/1/drives')) {
        return slow.future;
      }
      if (request.url.path.endsWith('/2/drives')) {
        return jsonResponse(
          jsonEncode({
            'items': [driveRow(27, '2026-03-30T01:00:00Z')],
            'next_cursor': null,
          }),
        );
      }
      return journeyPage(request);
    });
    await tester.tap(find.widgetWithText(StatusChip, '近7天'));
    await tester.pumpAndSettle();
    await readToEndOfRange(tester);
    slowArmed = true;
    await tester.scrollUntilVisible(find.byTooltip('刷新行程'), -300);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('刷新行程'));
    await tester.pump();
    await tester.tap(find.text('行笺测试车'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('Y · 尾号 0002'));
    await tester.tap(find.text('Y · 尾号 0002'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drive-27')), findsOneWidget);
    expect(
      tester
          .widget<StatusChip>(find.widgetWithText(StatusChip, '近30天'))
          .selected,
      isTrue,
    );
    slow.complete(
      jsonResponse(
        jsonEncode({
          'items': [driveRow(17, '2026-03-30T02:00:00Z')],
          'next_cursor': null,
        }),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drive-17')), findsNothing);
    expect(find.byKey(const ValueKey('drive-27')), findsOneWidget);
    await tester.tap(find.text('Y · 尾号 0002'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('行笺测试车'));
    await tester.tap(find.text('行笺测试车'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<StatusChip>(find.widgetWithText(StatusChip, '近30天'))
          .selected,
      isTrue,
    );
    expect(find.byKey(const ValueKey('drive-27')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('换时区重算相对期间并从第一页开始', (tester) async {
    var zone = 'Asia/Shanghai';
    final requests = <Uri>[];
    await openDrives(tester, (request) async {
      requests.add(request.url);
      return journeyRoutes(request);
    }, calendar: () async => CalendarContext(zone));
    await readToEndOfRange(tester);
    final before = requests.lastWhere((uri) => uri.path.endsWith('/drives'));
    requests.clear();
    zone = 'America/New_York';
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    final after = requests.firstWhere((uri) => uri.path.endsWith('/drives'));
    expect(
      after.queryParameters['from'],
      isNot(before.queryParameters['from']),
    );
    expect(after.queryParameters.containsKey('cursor'), isFalse);
    expect(find.text('加载更多行程'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('自定义日期跨本地午夜保留区间与已读范围', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final requests = <Uri>[];
    await openDrives(tester, (request) async {
      requests.add(request.url);
      return journeyRoutes(request);
    }, now: () => now);
    await tester.tap(find.text('自定义日期'));
    await tester.pumpAndSettle();
    final inputs = find.byType(TextField);
    await tester.enterText(inputs.at(0), '2026/03/01');
    await tester.enterText(inputs.at(1), '2026/03/29');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    await readToEndOfRange(tester);
    final before = requests.lastWhere((uri) => uri.path.endsWith('/drives'));
    requests.clear();
    now = DateTime.utc(2026, 3, 30, 17); // past local midnight
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    final after = requests.firstWhere((uri) => uri.path.endsWith('/drives'));
    expect(after.queryParameters['from'], before.queryParameters['from']);
    expect(after.queryParameters['to'], before.queryParameters['to']);
    expect(find.text('已显示全部行程'), findsOneWidget);
    expect(find.byKey(const ValueKey('drive-15')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('退出此设备后重新登录不重现旧阅读上下文', (tester) async {
    var signedIn = false;
    final store = MemorySessionStore()
      ..value = jsonEncode({
        'site': 'https://example.com/prefix',
        'token': 'test',
        'expires_at': '2099-01-01T00:00:00Z',
      });
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/auth/login')) {
        signedIn = true;
        return jsonResponse(
          jsonEncode({'token': 'next', 'expires_at': '2099-01-01T00:00:00Z'}),
        );
      }
      if (path.endsWith('/vehicles')) {
        return jsonResponse(
          File('test/fixtures/vehicles.json').readAsStringSync(),
        );
      }
      if (path.endsWith('/meta')) {
        return jsonResponse(File('test/fixtures/meta.json').readAsStringSync());
      }
      if (path.endsWith('/summary')) {
        return jsonResponse(
          File('test/fixtures/summary.json').readAsStringSync(),
        );
      }
      if (path.endsWith('/stats')) {
        return jsonResponse(
          File('test/fixtures/driving-stats.json').readAsStringSync(),
        );
      }
      if (path.endsWith('/drives')) {
        return signedIn
            ? jsonResponse(
                jsonEncode({
                  'items': [driveRow(77, '2026-03-30T01:00:00Z')],
                  'next_cursor': null,
                }),
              )
            : journeyPage(request);
      }
      return jsonResponse('{"items":[],"next_cursor":null}');
    });
    await tester.pumpWidget(
      MileafApp(
        client: client,
        sessionStore: store,
        trustStore: MemoryTrustStore(),
        vehiclePreferences: MemoryVehiclePreferences(),
        now: () => DateTime.utc(2026, 3, 30, 12),
        calendar: () async => CalendarContext('Asia/Shanghai'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('行程').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('近7天'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drive-17')), findsOneWidget);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('站点连接'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('退出此设备'));
    await tester.tap(find.text('退出此设备'));
    await tester.pumpAndSettle();
    expect(find.text('站点访问口令'), findsOneWidget);
    expect(find.byKey(const ValueKey('drive-17')), findsNothing);
    await tester.enterText(find.byType(TextFormField), 'secret');
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('行程').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<StatusChip>(find.widgetWithText(StatusChip, '近7天'))
          .selected,
      isFalse,
    );
    expect(find.byKey(const ValueKey('drive-77')), findsOneWidget);
    expect(find.byKey(const ValueKey('drive-17')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('重校验进行中不接受翻页，完成后范围与游标一致', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final slow = Completer<http.Response>();
    var slowArmed = false;
    await openDrives(tester, (request) async {
      if (request.url.path.endsWith('/meta')) {
        return jsonResponse(File('test/fixtures/meta.json').readAsStringSync());
      }
      if (slowArmed && !request.url.queryParameters.containsKey('cursor')) {
        return slow.future;
      }
      return journeyPage(request, tail: 'page-3');
    }, now: () => now);
    await tester.ensureVisible(find.text('加载更多行程'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加载更多行程'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drive-14')), findsOneWidget);
    slowArmed = true;
    await tester.tap(
      find.descendant(of: find.byType(MileafNavBar), matching: find.text('概览')),
    );
    await tester.pump();
    now = now.add(const Duration(minutes: 10));
    await tester.tap(
      find.descendant(of: find.byType(MileafNavBar), matching: find.text('行程')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    expect(find.text('加载更多行程'), findsNothing);
    slow.complete(
      jsonResponse(
        jsonEncode({
          'items': [
            driveRow(17, '2026-03-30T02:00:00Z'),
            driveRow(16, '2026-03-29T21:30:00Z'),
          ],
          'next_cursor': 'page-2',
        }),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drive-14')), findsOneWidget);
    expect(find.byKey(const ValueKey('drive-15')), findsOneWidget);
    expect(find.text('加载更多行程'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未访问的主入口不预加载，重复点击当前入口不滚顶也不发请求', (tester) async {
    final requests = <Uri>[];
    await openDrives(tester, (request) async {
      requests.add(request.url);
      return journeyRoutes(request);
    });
    expect(
      requests.where((uri) => uri.path.endsWith('/charging-sessions')),
      isEmpty,
    );
    expect(requests.where((uri) => uri.path.endsWith('/summary')), isEmpty);
    await tester.ensureVisible(find.text('加载更多行程'));
    await tester.pumpAndSettle();
    final offset = drivesOffset(tester);
    expect(offset, greaterThan(0));
    final count = requests.length;
    await selectTab(tester, '行程');
    expect(requests.length, count);
    expect(drivesOffset(tester), closeTo(offset, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('401 退出后重新登录不重现旧阅读上下文', (tester) async {
    var unauthorized = false;
    var signedIn = false;
    final store = MemorySessionStore()
      ..value = jsonEncode({
        'site': 'https://example.com/prefix',
        'token': 'test',
        'expires_at': '2099-01-01T00:00:00Z',
      });
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/auth/login')) {
        signedIn = true;
        return jsonResponse(
          jsonEncode({'token': 'next', 'expires_at': '2099-01-01T00:00:00Z'}),
        );
      }
      if (path.endsWith('/vehicles')) {
        return jsonResponse(
          File('test/fixtures/vehicles.json').readAsStringSync(),
        );
      }
      if (path.endsWith('/meta')) {
        return jsonResponse(File('test/fixtures/meta.json').readAsStringSync());
      }
      if (path.endsWith('/summary')) {
        return jsonResponse(
          File('test/fixtures/summary.json').readAsStringSync(),
        );
      }
      if (path.endsWith('/stats')) {
        return jsonResponse(
          File('test/fixtures/driving-stats.json').readAsStringSync(),
        );
      }
      if (path.endsWith('/drives')) {
        if (unauthorized && !signedIn) {
          return http.Response(
            jsonEncode({
              'error': {'code': 'unauthorized', 'message': '授权已失效'},
            }),
            401,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return signedIn
            ? jsonResponse(
                jsonEncode({
                  'items': [driveRow(77, '2026-03-30T01:00:00Z')],
                  'next_cursor': null,
                }),
              )
            : journeyPage(request);
      }
      return jsonResponse('{"items":[],"next_cursor":null}');
    });
    await tester.pumpWidget(
      MileafApp(
        client: client,
        sessionStore: store,
        trustStore: MemoryTrustStore(),
        vehiclePreferences: MemoryVehiclePreferences(),
        now: () => DateTime.utc(2026, 3, 30, 12),
        calendar: () async => CalendarContext('Asia/Shanghai'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('行程').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('近7天'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drive-17')), findsOneWidget);
    unauthorized = true;
    await tester.tap(find.byTooltip('刷新行程'));
    await tester.pumpAndSettle();
    expect(find.text('站点访问口令'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'secret');
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('行程').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<StatusChip>(find.widgetWithText(StatusChip, '近7天'))
          .selected,
      isFalse,
    );
    expect(
      tester
          .widget<StatusChip>(find.widgetWithText(StatusChip, '近30天'))
          .selected,
      isTrue,
    );
    expect(find.byKey(const ValueKey('drive-77')), findsOneWidget);
    expect(find.byKey(const ValueKey('drive-17')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('重新校验后记录减少，阅读位置回到有效范围', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    var shrunk = false;
    await openDrives(tester, (request) async {
      if (request.url.path.endsWith('/meta')) {
        return jsonResponse(File('test/fixtures/meta.json').readAsStringSync());
      }
      if (shrunk) {
        return jsonResponse(
          jsonEncode({
            'items': [driveRow(17, '2026-03-30T02:00:00Z')],
            'next_cursor': null,
          }),
          headers: {'cache-control': 'max-age=300'},
        );
      }
      return journeyPage(request);
    }, now: () => now);
    await readToEndOfRange(tester);
    shrunk = true;
    await selectTab(tester, '概览');
    now = now.add(const Duration(minutes: 10));
    await selectTab(tester, '行程');
    await tester.pumpAndSettle();
    final position = drivesScroll(tester);
    expect(position.pixels, lessThanOrEqualTo(position.maxScrollExtent + 0.5));
    expect(find.text('已显示全部行程'), findsOneWidget);
    expect(find.text('加载更多行程'), findsNothing);
    expect(find.byKey(const ValueKey('drive-17')), findsOneWidget);
    expect(find.byKey(const ValueKey('drive-15')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('重校验中途隐藏后不再翻页，返回后补齐全段而不是截成第一页', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final requests = <Uri>[];
    final gate = Completer<void>();
    var holdFirstPage = false, holding = false;
    await openDrives(tester, (request) async {
      requests.add(request.url);
      if (request.url.path.endsWith('/meta')) {
        return jsonResponse(File('test/fixtures/meta.json').readAsStringSync());
      }
      if (holdFirstPage && request.url.queryParameters['cursor'] == null) {
        holdFirstPage = false;
        holding = true;
        await gate.future;
      }
      return journeyPage(request);
    }, now: () => now);
    await readToEndOfRange(tester);
    expect(find.text('已显示全部行程'), findsOneWidget);
    await selectTab(tester, '概览');
    now = now.add(const Duration(minutes: 10));
    holdFirstPage = true;
    await tapNav(tester, '行程');
    expect(holding, isTrue, reason: '前置：重校验的第一页请求确实在途');
    final before = requests.length;
    await tapNav(tester, '统计');
    gate.complete();
    await tester.pumpAndSettle();
    expect(
      requests
          .skip(before)
          .where(
            (uri) =>
                uri.path.endsWith('/drives') &&
                uri.queryParameters.containsKey('cursor'),
          ),
      isEmpty,
      reason: '页面隐藏后，第一页的迟到响应不得再发起下一页请求',
    );
    final afterHide = requests.length;
    await selectTab(tester, '行程');
    expect(find.text('已显示全部行程'), findsOneWidget, reason: '返回后补齐已读的两页，不塌回第一页');
    expect(find.text('加载更多行程'), findsNothing);
    expect(
      requests
          .skip(afterHide)
          .where(
            (uri) =>
                uri.path.endsWith('/drives') &&
                uri.queryParameters['cursor'] == 'page-2',
          ),
      hasLength(1),
      reason: '再次可见时按原查询补齐整段已读范围',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('重校验途中切换期间不把旧游标拼到新查询，迟到结果不覆盖新列表', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final requests = <Uri>[];
    final gate = Completer<void>();
    var holdFirstPage = false, holding = false;
    String? previousFrom;
    await openDrives(tester, (request) async {
      requests.add(request.url);
      if (request.url.path.endsWith('/meta')) {
        return jsonResponse(File('test/fixtures/meta.json').readAsStringSync());
      }
      final from = request.url.queryParameters['from'];
      previousFrom ??= from;
      if (holdFirstPage && request.url.queryParameters['cursor'] == null) {
        holdFirstPage = false;
        holding = true;
        await gate.future;
      }
      // A different record per window, so a late response cannot hide behind
      // identical rows. The second page is still reachable, so a revalidation
      // covers the range the owner already read.
      final item = from == previousFrom
          ? driveRow(17, '2026-03-30T02:00:00Z')
          : driveRow(41, '2026-03-26T02:00:00Z');
      return jsonResponse(
        jsonEncode({
          'items': [item],
          'next_cursor': request.url.queryParameters['cursor'] == null
              ? 'page-2'
              : null,
        }),
        headers: {'cache-control': 'max-age=300'},
      );
    }, now: () => now);
    expect(previousFrom, isNotNull);
    expect(find.byKey(const ValueKey('drive-17')), findsOneWidget);
    await readToEndOfRange(tester);
    await selectTab(tester, '概览');
    now = now.add(const Duration(minutes: 10));
    final heldStart = requests.length;
    holdFirstPage = true;
    await tapNav(tester, '行程');
    expect(holding, isTrue, reason: '前置：重校验的第一页请求确实在途');
    drivesScroll(tester).jumpTo(0);
    await tester.pump();
    await tester.tap(find.widgetWithText(StatusChip, '近7天'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 32));
    gate.complete();
    await tester.pumpAndSettle();
    expect(
      requests
          .skip(heldStart)
          .where(
            (uri) =>
                uri.path.endsWith('/drives') &&
                uri.queryParameters.containsKey('cursor'),
          ),
      isEmpty,
      reason: '旧的 cursor 不得拼到新期间上，迟到响应也不得继续翻页',
    );
    expect(find.byKey(const ValueKey('drive-41')), findsOneWidget);
    expect(find.byKey(const ValueKey('drive-17')), findsNothing);
    expect(
      tester
          .widget<StatusChip>(find.widgetWithText(StatusChip, '近7天'))
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('被详情遮挡的行程跨日不主动请求，返回后按新期间从第一页校验', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final requests = <Uri>[];
    await openDrives(tester, (request) async {
      requests.add(request.url);
      return journeyRoutes(request);
    }, now: () => now);
    await tester.ensureVisible(find.byKey(const ValueKey('drive-17')));
    await tester.pumpAndSettle();
    final before = requests
        .lastWhere((uri) => uri.path.endsWith('/drives'))
        .queryParameters['from'];
    await tester.tap(find.byKey(const ValueKey('drive-17')));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is DriveDetailPage && widget.id == 17,
      ),
      findsOneWidget,
    );
    requests.clear();
    // Cross the local midnight (and the cached day) while the detail covers
    // the list; the detail's own foreground pass bumps the workspace revision.
    now = DateTime.utc(2026, 3, 31, 0, 30);
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(
      requests.where((uri) => uri.path.endsWith('/drives')),
      isEmpty,
      reason: '被详情遮挡的列表不得因跨日主动请求自己的期间',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    final revalidated = requests.lastWhere(
      (uri) => uri.path.endsWith('/drives'),
    );
    expect(
      revalidated.queryParameters['from'],
      isNot(before),
      reason: '返回可见后按新的本地日历重算相对期间',
    );
    expect(
      revalidated.queryParameters.containsKey('cursor'),
      isFalse,
      reason: '旧期间的游标不得沿用到新期间',
    );
    expect(find.text('加载更多行程'), findsOneWidget);
    expect(find.text('已显示全部行程'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('详情未过期返回不重复读取行程，过期返回才校验同一范围', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final requests = <Uri>[];
    await openDrives(tester, (request) async {
      requests.add(request.url);
      return journeyRoutes(request);
    }, now: () => now);
    await tester.ensureVisible(find.byKey(const ValueKey('drive-17')));
    await tester.pumpAndSettle();
    final range = requests
        .lastWhere((uri) => uri.path.endsWith('/drives'))
        .queryParameters;
    requests.clear();
    await tester.tap(find.byKey(const ValueKey('drive-17')));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is DriveDetailPage && widget.id == 17,
      ),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      requests.where((uri) => uri.path.endsWith('/drives')),
      isEmpty,
      reason: 'TTL 未过期的普通返回不强制网络刷新',
    );

    requests.clear();
    await tester.tap(find.byKey(const ValueKey('drive-17')));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is DriveDetailPage && widget.id == 17,
      ),
      findsOneWidget,
    );
    // Stay in the foreground inside the detail until the list cache expires.
    now = now.add(const Duration(minutes: 10));
    requests.clear();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    final revalidated = requests
        .where((uri) => uri.path.endsWith('/drives'))
        .toList();
    expect(revalidated, isNotEmpty, reason: 'TTL 过期后返回可见必须校验');
    expect(revalidated.first.queryParameters['from'], range['from']);
    expect(revalidated.first.queryParameters.containsKey('cursor'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('统计自定义期间应用后只读取一次新期间', (tester) async {
    final requests = <Uri>[];
    await openTab(
      tester,
      workspaceClient(requests, (request) async {
        return jsonResponse(
          File('test/fixtures/driving-stats.json').readAsStringSync(),
        );
      }),
      tab: '统计',
      now: () => DateTime.utc(2026, 3, 30, 12),
    );
    expect(find.text('驾驶统计'), findsOneWidget);
    requests.clear();
    await custom(tester, '2026-03-02', '2026-03-05');
    final stats = requests.where((uri) => uri.path.endsWith('/stats')).toList();
    expect(stats, hasLength(1), reason: '应用自定义期间只读取一次新期间');
    expect(stats.single.queryParameters['from'], '2026-03-01T16:00:00.000Z');
    expect(stats.single.queryParameters['to'], '2026-03-05T16:00:00.000Z');
    expect(tester.takeException(), isNull);
  });

  testWidgets('日期选择器返回不重复读取同一期间', (tester) async {
    final requests = <Uri>[];
    await openDrives(tester, (request) async {
      requests.add(request.url);
      if (request.url.path.endsWith('/meta')) {
        return jsonResponse(File('test/fixtures/meta.json').readAsStringSync());
      }
      return jsonResponse(
        jsonEncode({
          'items': [driveRow(17, '2026-03-30T02:00:00Z')],
          'next_cursor': null,
        }),
        headers: {'cache-control': 'max-age=0'},
      );
    });
    requests.clear();
    await tester.tap(find.text('自定义日期'));
    await tester.pumpAndSettle();
    final inputs = find.byType(TextField);
    await tester.enterText(inputs.at(0), '2026/02/01');
    await tester.enterText(inputs.at(1), '2026/03/30');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026-02-01 至 2026-03-30'), findsOneWidget);
    expect(
      requests.where((uri) => uri.path.endsWith('/drives')),
      hasLength(1),
      reason: '选完日期只需一次读取，返回本身不得再触发一次',
    );
    expect(tester.takeException(), isNull);
  });
}
