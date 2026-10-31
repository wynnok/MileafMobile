import 'dart:async';
import 'dart:convert';

import 'overview_test.dart' show background, foreground;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/workspace.dart';
import 'package:mileaf/src/map_candidate.dart';

import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

http.Response jsonResponse(
  String body, {
  Map<String, String> headers = const {},
}) => http.Response(
  body,
  200,
  headers: {'content-type': 'application/json; charset=utf-8', ...headers},
);
Future<void> openDrives(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler, {
  DateTime Function()? now,
  MapConfiguration? mapConfiguration,
  Future<CalendarContext> Function()? calendar,
  Future<http.Response> Function(http.Request)? statsHandler,
}) async {
  final store = MemorySessionStore()
    ..value = jsonEncode({
      'site': 'https://example.com/prefix',
      'token': 'test',
      'expires_at': '2099-01-01T00:00:00Z',
    });
  await tester.pumpWidget(
    MileafApp(
      client: MockClient((r) async {
        if (r.url.path.endsWith('/vehicles')) {
          return jsonResponse(
            File('test/fixtures/vehicles.json').readAsStringSync(),
          );
        }
        if (r.url.path.endsWith('/stats')) {
          if (statsHandler != null) return statsHandler(r);
          return jsonResponse(
            File('test/fixtures/driving-stats.json').readAsStringSync(),
          );
        }
        if (r.url.path.endsWith('/summary')) {
          return jsonResponse(
            File('test/fixtures/summary.json').readAsStringSync(),
          );
        }
        return handler(r);
      }),
      sessionStore: store,
      mapConfiguration: mapConfiguration,
      trustStore: MemoryTrustStore(),
      vehiclePreferences: MemoryVehiclePreferences(),
      now: now ?? () => DateTime.utc(2026, 3, 30, 12),
      calendar: calendar ?? () async => CalendarContext('Asia/Shanghai'),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('行程').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('前台持续跨午夜后日定位和返回沿用同一统计快照', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final requests = <Map<String, String>>[];
    final body = jsonDecode(
      File('test/fixtures/driving-stats.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final bucket = Map<String, dynamic>.from(
      (body['buckets'] as List).first as Map,
    );
    body['buckets'] = [
      {...bucket, 'bucket_start': '2026-03-23T16:00:00Z'},
    ];
    await openDrives(
      tester,
      (r) async {
        requests.add(r.url.queryParameters);
        return jsonResponse('{"items":[],"next_cursor":null}');
      },
      now: () => now,
      statsHandler: (_) async => jsonResponse(jsonEncode(body)),
    );
    await tester.tap(find.text('近7天'));
    await tester.pumpAndSettle();
    final period = Map<String, String>.of(requests.last);
    now = DateTime.utc(2026, 3, 30, 17);
    await tester.scrollUntilVisible(find.text('看当天').hitTestable(), 140);
    await tester.tap(find.text('看当天'));
    await tester.pumpAndSettle();
    expect(requests.last['from'], '2026-03-23T16:00:00.000Z');
    expect(requests.last['to'], '2026-03-24T16:00:00.000Z');
    await tester.scrollUntilVisible(find.text('返回完整区间').hitTestable(), 100);
    await tester.tap(find.text('返回完整区间'));
    await tester.pumpAndSettle();
    expect(requests.last['from'], period['from']);
    expect(requests.last['to'], period['to']);
  });
  testWidgets('跨日后移出近7日范围的日筛选恢复完整区间', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    final requests = <Map<String, String>>[];
    final body = jsonDecode(
      File('test/fixtures/driving-stats.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final bucket = Map<String, dynamic>.from(
      (body['buckets'] as List).first as Map,
    );
    body['buckets'] = [
      {...bucket, 'bucket_start': '2026-03-23T16:00:00Z'},
    ];
    await openDrives(
      tester,
      (r) async {
        requests.add(r.url.queryParameters);
        return jsonResponse('{"items":[],"next_cursor":null}');
      },
      now: () => now,
      statsHandler: (_) async => jsonResponse(jsonEncode(body)),
    );
    await tester.tap(find.text('近7天'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('看当天').hitTestable(), 140);
    await tester.tap(find.text('看当天'));
    await tester.pumpAndSettle();
    expect(requests.last['from'], '2026-03-23T16:00:00.000Z');
    now = DateTime.utc(2026, 3, 30, 17);
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(requests.last['from'], '2026-03-24T16:00:00.000Z');
    expect(requests.last['to'], '2026-03-30T17:00:00.000Z');
    expect(find.text('返回完整区间'), findsNothing);
  });
  testWidgets('超过730天仍可查询行程但不发送非法统计请求', (tester) async {
    var statsCount = 0;
    final lists = <Map<String, String>>[];
    await openDrives(
      tester,
      (r) async {
        lists.add(r.url.queryParameters);
        return jsonResponse('{"items":[],"next_cursor":null}');
      },
      statsHandler: (_) async {
        statsCount++;
        return jsonResponse(
          File('test/fixtures/driving-stats.json').readAsStringSync(),
        );
      },
    );
    final before = statsCount;
    await tester.tap(find.text('日期'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '2020/01/01');
    await tester.enterText(find.byType(TextField).at(1), '2026/03/30');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(lists.last['from'], '2019-12-31T16:00:00.000Z');
    expect(statsCount, before);
    expect(find.textContaining('不超过730天，行程列表仍可使用'), findsOneWidget);
    expect(find.text('所选日期没有行程'), findsOneWidget);
  });
  testWidgets('切车后迟到统计不能覆盖新车期间摘要', (tester) async {
    var delay = false;
    final slow = Completer<http.Response>();
    final original = File('test/fixtures/driving-stats.json')
        .readAsStringSync();
    await openDrives(
      tester,
      (_) async => jsonResponse('{"items":[],"next_cursor":null}'),
      statsHandler: (r) async {
        if (r.url.path.contains('/vehicles/1/') && delay) return slow.future;
        final body = jsonDecode(original) as Map<String, dynamic>;
        if (r.url.path.contains('/vehicles/2/')) body['totals']['drives'] = 3;
        return jsonResponse(jsonEncode(body));
      },
    );
    delay = true;
    await tester.tap(find.byTooltip('刷新行程'));
    await tester.pump();
    await tester.tap(find.text('行笺测试车'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('Y · 尾号 0002'));
    await tester.tap(find.text('Y · 尾号 0002'));
    await tester.pumpAndSettle();
    expect(find.text('3 趟'), findsOneWidget);
    slow.complete(jsonResponse(original));
    await tester.pumpAndSettle();
    expect(find.text('3 趟'), findsOneWidget);
    expect(find.text('期间行程 49 次'), findsNothing);
  });
  testWidgets('近7日统计与列表同区间，选中一天只筛列表', (tester) async {
    final listQueries = <Map<String, String>>[];
    final statsQueries = <Map<String, String>>[];
    final body = jsonDecode(
      File('test/fixtures/driving-stats.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final sample = Map<String, dynamic>.from(
      (body['buckets'] as List).first as Map,
    );
    body['buckets'] = [
      {...sample, 'bucket_start': '2026-03-28T16:00:00Z'},
      {...sample, 'bucket_start': '2026-03-29T16:00:00Z'},
    ];
    await openDrives(
      tester,
      (r) async {
        listQueries.add(r.url.queryParameters);
        return jsonResponse('{"items":[],"next_cursor":null}');
      },
      statsHandler: (r) async {
        statsQueries.add(r.url.queryParameters);
        return jsonResponse(jsonEncode(body));
      },
    );
    await tester.tap(find.text('近7天'));
    await tester.pumpAndSettle();
    expect(listQueries.last['from'], '2026-03-23T16:00:00.000Z');
    expect(statsQueries.last['from'], listQueries.last['from']);
    expect(statsQueries.last['to'], listQueries.last['to']);
    await tester.scrollUntilVisible(find.text('看当天'), 120);
    await tester.tap(find.text('看当天'));
    await tester.pumpAndSettle();
    expect(listQueries.last['from'], '2026-03-28T16:00:00.000Z');
    expect(listQueries.last['to'], '2026-03-29T16:00:00.000Z');
    expect(find.text('49 趟'), findsOneWidget);
  });

  testWidgets('刷新统计失败时保留已加载列表及原统计快照', (tester) async {
    var failing = false;
    await openDrives(
      tester,
      (_) async =>
          jsonResponse(File('test/fixtures/drives.json').readAsStringSync()),
      statsHandler: (_) async => failing
          ? http.Response('', 503)
          : jsonResponse(
              File('test/fixtures/driving-stats.json').readAsStringSync(),
            ),
    );
    failing = true;
    await tester.tap(find.byTooltip('刷新行程'));
    await tester.pumpAndSettle();
    expect(find.textContaining('保留上次统计快照'), findsOneWidget);
    expect(find.text('49 趟'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('drive-17')),
      180,
    );
    expect(find.byKey(const ValueKey('drive-17')), findsOneWidget);
  });
  testWidgets('360x800首屏可看到出行节奏与第一条行程', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await openDrives(
      tester,
      (_) async =>
          jsonResponse(File('test/fixtures/drives.json').readAsStringSync()),
    );
    expect(find.text('出行节奏').hitTestable(), findsOneWidget);
    expect(
      find.byKey(const ValueKey('drive-17')).hitTestable(),
      findsOneWidget,
    );
  });
  testWidgets('行程列表展示每趟估算净能量', (tester) async {
    await openDrives(
      tester,
      (_) async =>
          jsonResponse(File('test/fixtures/drives.json').readAsStringSync()),
    );
    for (final id in [17, 16]) {
      final record = find.byKey(ValueKey('drive-$id'));
      await tester.scrollUntilVisible(record, 140);
      expect(
        find.descendant(of: record, matching: find.text('估算净能量 3.75 kWh')),
        findsOneWidget,
      );
    }
  });
  testWidgets('行程期间摘要使用独立统计总计而非列表分页', (tester) async {
    await openDrives(
      tester,
      (_) async =>
          jsonResponse(File('test/fixtures/drives.json').readAsStringSync()),
    );
    expect(find.textContaining('960.0'), findsWidgets);
    expect(find.text('49 趟'), findsOneWidget);
    expect(find.textContaining('净电耗 188 Wh/km'), findsWidgets);
  });
  testWidgets('行程按本地日期分组，同日记录共享标题且保留独立详情入口', (tester) async {
    await openDrives(
      tester,
      (request) async =>
          jsonResponse(File('test/fixtures/drives.json').readAsStringSync()),
    );
    await tester.scrollUntilVisible(find.text('2026年3月30日'), 140);
    expect(find.text('2026年3月30日'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('drive-17')),
      140,
    );
    expect(find.byKey(const ValueKey('drive-17')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('drive-16')),
      140,
    );
    expect(find.byKey(const ValueKey('drive-16')), findsOneWidget);
  });
  for (final sample in [
    (400, 'invalid_request', '请求参数无效'),
    (422, 'invalid_request', '请求参数无效'),
    (503, 'db_unavailable', '数据库暂不可用'),
    (503, 'upstream_timeout', '上游服务超时'),
    (500, 'internal_error', '服务内部错误'),
    (404, 'not_found', '车辆或记录已不可用'),
  ]) {
    testWidgets('业务错误按HTTP与稳定code给恢复提示 ${sample.$1}/${sample.$2}', (
      tester,
    ) async {
      await openDrives(
        tester,
        (r) async => http.Response(
          jsonEncode({
            'error': {
              'code': sample.$2,
              'message': 'private-token https://private.example/path',
            },
          }),
          sample.$1,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      expect(find.textContaining(sample.$3), findsOneWidget);
      expect(find.textContaining('private-token'), findsNothing);
      expect(find.textContaining('private.example'), findsNothing);
      expect(find.text('重试行程'), findsOneWidget);
    });
  }
  for (final body in [
    '<html>private-token</html>',
    '{invalid-json',
    '{"error":{"code":42}}',
    '{"error":{"code":"${'x' * 9000}"}}',
  ]) {
    testWidgets('反代或不可信错误envelope安全回退 ${body.length}', (tester) async {
      await openDrives(tester, (r) async => http.Response(body, 502));
      expect(find.textContaining('数据读取失败'), findsOneWidget);
      expect(find.textContaining('private-token'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final range in ['default', 'today', 'history']) {
    testWidgets('行程前台按TTL校验并推进含今天窗口 $range', (tester) async {
      var now = DateTime.utc(2026, 3, 30, 12);
      final queries = <Map<String, String>>[];
      await openDrives(tester, (r) async {
        queries.add(r.url.queryParameters);
        return jsonResponse(
          '{"items":[],"next_cursor":"page2"}',
          headers: {'cache-control': 'max-age=30'},
        );
      }, now: () => now);
      if (range != 'default') {
        await tester.tap(find.text('日期'));
        await tester.pumpAndSettle();
        final inputs = find.byType(TextField);
        await tester.enterText(inputs.at(0), '2026/03/29');
        await tester.enterText(
          inputs.at(1),
          range == 'today' ? '2026/03/30' : '2026/03/29',
        );
        await tester.tap(find.text('确定'));
        await tester.pumpAndSettle();
      }
      final initial = queries.last;
      final count = queries.length;
      now = DateTime.utc(2026, 3, 30, 12, 0, 20);
      background(tester);
      foreground(tester);
      await tester.pumpAndSettle();
      expect(queries.length, count);
      now = DateTime.utc(2026, 3, 30, 14);
      background(tester);
      foreground(tester);
      await tester.pumpAndSettle();
      expect(queries.length, count + 1);
      expect(
        queries.last['to'],
        range == 'history' ? initial['to'] : '2026-03-30T14:00:00.000Z',
      );
      expect(queries.last['from'], initial['from']);
      expect(queries.last.containsKey('cursor'), isFalse);
    });
  }

  testWidgets('行程从固定后端多页样本读取，展示未知地点与净电耗并产生详情目标', (tester) async {
    await openDrives(tester, (request) async {
      if (request.url.path.endsWith('/17/series')) {
        return jsonResponse(
          '{"drive_id":17,"resolution":"empty","points":0,"series":[]}',
        );
      }
      if (request.url.path.endsWith('/drives/17')) {
        final body = jsonDecode(
          File('test/fixtures/drive-detail.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        body['id'] = 17;
        return jsonResponse(jsonEncode(body));
      }
      expect(request.url.path, '/prefix/v1/vehicles/1/drives');
      expect(request.url.queryParameters['from'], '2026-02-28T16:00:00.000Z');
      expect(request.url.queryParameters['to'], '2026-03-30T12:00:00.000Z');
      expect(request.url.queryParameters['limit'], '20');
      return jsonResponse(File('test/fixtures/drives.json').readAsStringSync());
    });
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('drive-17')),
      140,
    );
    expect(find.textContaining('净电耗 188 Wh/km'), findsWidgets);
    expect(find.textContaining('未知地点'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('drive-17')).hitTestable(),
      140,
    );
    await tester.tap(find.byKey(const ValueKey('drive-17')));
    await tester.pumpAndSettle();
    expect(find.textContaining('行程 #17'), findsOneWidget);
  });
  testWidgets('游标翻页失败保留记录，重试按ID去重且刷新清除后续页，304保留快照', (tester) async {
    var failing = true;
    var refresh = false;
    final fixture = jsonDecode(
      File('test/fixtures/drives.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    await openDrives(tester, (request) async {
      if (request.url.queryParameters.containsKey('cursor')) {
        expect(request.url.queryParameters['cursor'], fixture['next_cursor']);
        if (failing) return http.Response('', 503);
        final extra = Map<String, dynamic>.from(
          (fixture['items'] as List).last as Map,
        );
        extra['id'] = 15;
        extra['started_at'] = (fixture['items'] as List).last['started_at'];
        extra['ended_at'] = null;
        extra['distance_km'] = null;
        extra['duration_min'] = null;
        extra['consumption_wh_km'] = 0;
        return jsonResponse(
          jsonEncode({
            'items': [(fixture['items'] as List).last, extra],
            'next_cursor': null,
          }),
        );
      }
      if (refresh) {
        expect(request.headers['if-none-match'], '"drives"');
        return http.Response('', 304);
      }
      return jsonResponse(
        jsonEncode(fixture),
        headers: {'etag': '"drives"', 'cache-control': 'max-age=30'},
      );
    });
    await tester.scrollUntilVisible(find.text('重试加载更多'), 200);
    await tester.pumpAndSettle();
    expect(find.textContaining('已保留现有行程'), findsOneWidget);
    expect(find.byKey(const ValueKey('drive-16')), findsOneWidget);
    failing = false;
    await tester.tap(find.text('重试加载更多'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('drive-15')),
      200,
    );
    expect(find.text('进行中'), findsOneWidget);
    expect(find.textContaining('净电耗 0 Wh/km'), findsOneWidget);
    expect(find.textContaining('距离 —（缺失）'), findsOneWidget);
    expect(find.byKey(const ValueKey('drive-16')), findsOneWidget);
    refresh = true;
    await tester.scrollUntilVisible(find.byTooltip('刷新行程'), -300);
    await tester.tap(find.byTooltip('刷新行程'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drive-15')), findsNothing);
    expect(find.textContaining('净电耗 188 Wh/km'), findsWidgets);
  });
  testWidgets('自定义日期含首尾跨DST且无730天限制，前台换时区保留日历日期，默认窗口换日重算', (tester) async {
    var zone = 'America/New_York';
    var now = DateTime.utc(2026, 3, 30, 12);
    final queries = <Map<String, String>>[];
    await openDrives(
      tester,
      (request) async {
        queries.add(request.url.queryParameters);
        return jsonResponse(
          '{"items":[],"next_cursor":null}',
          headers: {'cache-control': 'max-age=3600'},
        );
      },
      now: () => now,
      calendar: () async => CalendarContext(zone),
    );
    expect(find.text('所选日期没有行程'), findsOneWidget);
    await tester.tap(find.text('日期'));
    await tester.pumpAndSettle();
    final inputs = find.byType(TextField);
    await tester.enterText(inputs.at(0), '2024/03/09');
    await tester.enterText(inputs.at(1), '2024/03/10');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(queries.last['from'], '2024-03-09T05:00:00.000Z');
    expect(queries.last['to'], '2024-03-11T04:00:00.000Z');
    zone = 'Asia/Shanghai';
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(find.text('2024-03-09 至 2024-03-10（含首尾）'), findsOneWidget);
    expect(queries.last['from'], '2024-03-08T16:00:00.000Z');
    expect(queries.last['to'], '2024-03-10T16:00:00.000Z');
    await tester.tap(find.text('近30天'));
    await tester.pumpAndSettle();
    now = DateTime.utc(2026, 3, 30, 17);
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(queries.last['from'], '2026-03-01T16:00:00.000Z');
    expect(queries.last['to'], '2026-03-30T17:00:00.000Z');
  });
  testWidgets('切车丢弃旧行程响应及旧游标，360宽200%字体可读', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final slow = Completer<http.Response>();
    var validating = false;
    await openDrives(tester, (request) async {
      if (request.url.path.endsWith('/1/drives') && validating) {
        return slow.future;
      }
      if (request.url.path.endsWith('/1/drives')) {
        return jsonResponse(
          File('test/fixtures/drives.json').readAsStringSync(),
        );
      }
      return jsonResponse('{"items":[],"next_cursor":null}');
    });
    validating = true;
    await tester.tap(find.byTooltip('刷新行程'));
    await tester.pump();
    await tester.tap(find.text('行笺测试车'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('Y · 尾号 0002'));
    await tester.tap(find.text('Y · 尾号 0002'));
    await tester.pumpAndSettle();
    expect(find.text('所选日期没有行程'), findsOneWidget);
    expect(find.byKey(const ValueKey('drive-17')), findsNothing);
    expect(tester.takeException(), isNull);
    slow.complete(
      jsonResponse(File('test/fixtures/drives.json').readAsStringSync()),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drive-17')), findsNothing);
  });
  testWidgets('非法数组显示兼容错误，手动重试后展示真实零值且刷新失败保留快照', (tester) async {
    var invalid = true;
    var failure = false;
    await openDrives(tester, (request) async {
      if (failure) return http.Response('', 503);
      if (invalid) return jsonResponse('{"items":[42],"next_cursor":null}');
      final body = jsonDecode(
        File('test/fixtures/drives.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      body['next_cursor'] = null;
      return jsonResponse(jsonEncode(body));
    });
    expect(find.textContaining('格式不兼容'), findsOneWidget);
    invalid = false;
    await tester.tap(find.text('重试行程'));
    await tester.pumpAndSettle();
    expect(find.textContaining('净电耗 188 Wh/km'), findsWidgets);
    failure = true;
    await tester.tap(find.byTooltip('刷新行程'));
    await tester.pumpAndSettle();
    expect(find.textContaining('保留上次快照'), findsOneWidget);
    expect(find.textContaining('净电耗 188 Wh/km'), findsWidgets);
  });
}
