import 'package:mileaf/src/drive_detail_page.dart';

import 'dart:async';
import 'dart:convert';

import 'overview_test.dart' show background, foreground;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/design/components/charts.dart';
import 'package:mileaf/src/workspace.dart';
import 'package:mileaf/src/map/map_consent.dart';
import 'package:mileaf/src/map/map_platform.dart';

import 'support/session_store.dart';
import 'support/map_key_fixture.dart';
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
  MapConsentController? mapConsent,
  MapPlatform? mapPlatform,
  Future<CalendarContext> Function()? calendar,
  Future<http.Response> Function(http.Request)? statsHandler,
}) async {
  final keys = await configuredMapKeys();
  addTearDown(keys.dispose);
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
      mapConsent: mapConsent,
      mapKeys: keys,
      mapPlatform: mapPlatform,
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

/// R27/PD10：打开共享日期区间弹层，走键盘输入路径应用一个区间。
Future<void> applyCustomRange(
  WidgetTester tester,
  String start,
  String end,
) async {
  await tester.tap(find.text('自定义'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('改为输入'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('date-range-start-input')),
    start,
  );
  await tester.enterText(
    find.byKey(const ValueKey('date-range-end-input')),
    end,
  );
  await tester.tap(find.text('应用'));
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
    // 节奏卡已移到记录之后（P02 用户裁定 B）：回到列表上方的「返回完整区间」要往上滚。
    await tester.scrollUntilVisible(find.text('返回完整区间').hitTestable(), -100);
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
    await applyCustomRange(tester, '2020-01-01', '2026-03-30');
    expect(lists.last['from'], '2019-12-31T16:00:00.000Z');
    expect(statsCount, before);
    // CP07：技术原因留给「关于这些数据」，主界面只说结果与可用范围。
    expect(find.textContaining('730 天，行程列表不受影响'), findsOneWidget);
    expect(find.text('这段时间没有行程'), findsOneWidget);
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
    // P16：车辆行改为完整名称 +「Y，尾号 0002」（CP09.1 用逗号，不用「·」）。
    await tester.ensureVisible(find.text('Y，尾号 0002'));
    await tester.tap(find.text('Y，尾号 0002'));
    await tester.pumpAndSettle();
    expect(find.text('3 趟'), findsOneWidget);
    slow.complete(jsonResponse(original));
    await tester.pumpAndSettle();
    expect(find.text('3 趟'), findsOneWidget);
    expect(find.text('49 趟'), findsNothing);
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
    expect(listQueries.last['from'], '2026-03-29T16:00:00.000Z');
    expect(listQueries.last['to'], '2026-03-30T12:00:00.000Z');
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
    expect(find.textContaining('没能更新，显示的是'), findsOneWidget);
    expect(find.text('49 趟'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('drive-17')),
      180,
    );
    expect(find.byKey(const ValueKey('drive-17')), findsOneWidget);
  });
  testWidgets('360x800首屏可看到期间摘要与第一条行程，节奏卡在记录之后', (tester) async {
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
    // §6 行程首屏预算：第一条记录完整可见；节奏卡按 P02 移到记录之后。
    expect(
      find.byKey(const ValueKey('drive-17')).hitTestable(),
      findsOneWidget,
    );
    // §6 行程预算的另一半：第二条记录起始至少 24 可见（底栏上沿 736）。
    expect(
      736 - tester.getTopLeft(find.byKey(const ValueKey('drive-16'))).dy,
      greaterThanOrEqualTo(24),
      reason: '第二条记录起始应至少 24 可见',
    );
    // 节奏卡已移到记录之后：首屏不再留给它，向下滚动才可读（用户裁定 B）。
    expect(find.text('每日里程').hitTestable(), findsNothing);
    await tester.scrollUntilVisible(find.text('每日里程').hitTestable(), 200);
    expect(find.text('每日里程').hitTestable(), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(TimeSeriesChart)).dy,
      greaterThan(tester.getTopLeft(find.byKey(const ValueKey('drive-17'))).dy),
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
        find.descendant(of: record, matching: find.textContaining('电耗')),
        findsOneWidget,
      );
    }
  });
  testWidgets('行程期间摘要使用独立统计总计而非列表分页', (tester) async {
    await openDrives(
      tester,
      (_) async =>
          jsonResponse(File('test/fixtures/drives.json').readAsStringSync()),
      // 统计总计与列表记录给不同的电耗，才能分辨焦点卡读的是哪一份。
      statsHandler: (_) async {
        final body = jsonDecode(
          File('test/fixtures/driving-stats.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        body['totals']['consumption_wh_km_net'] = 155;
        return jsonResponse(jsonEncode(body));
      },
    );
    expect(find.textContaining('960.0'), findsWidgets);
    expect(find.text('49 趟'), findsOneWidget);
    // 焦点卡三格的「电耗」来自统计 totals（155），不是列表每趟的 188。
    expect(find.text('155 Wh/km'), findsWidgets);
    expect(find.textContaining('电耗 188 Wh/km'), findsWidgets);
  });
  testWidgets('C 记录按天分组并保留每趟的时间与独立详情入口', (tester) async {
    await openDrives(
      tester,
      (request) async =>
          jsonResponse(File('test/fixtures/drives.json').readAsStringSync()),
    );
    // P02：记录改成按天分组卡，分组标题用 CP04 DF2（今天/昨天/M月D日 周X）。
    await tester.scrollUntilVisible(find.text('今天'), 140);
    expect(find.text('今天'), findsOneWidget);
    // 每行仍保留本趟的时间与时长（CP09 用逗号分行，不用「·」）。
    expect(find.textContaining('10:00\u201310:30，30 分钟'), findsWidgets);
    expect(find.textContaining('05:30\u201306:00，30 分钟'), findsWidgets);
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
        await applyCustomRange(
          tester,
          '2026-03-29',
          range == 'today' ? '2026-03-30' : '2026-03-29',
        );
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

  testWidgets('行程从固定后端多页样本读取，展示未知地点与电耗并产生详情目标', (tester) async {
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
    expect(find.textContaining('电耗 188 Wh/km'), findsWidgets);
    expect(find.textContaining('未知地点'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('drive-17')).hitTestable(),
      140,
    );
    await tester.tap(find.byKey(const ValueKey('drive-17')));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is DriveDetailPage && widget.id == 17,
      ),
      findsOneWidget,
    );
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
    expect(find.textContaining('没能加载更多行程，已保留当前列表'), findsOneWidget);
    expect(find.byKey(const ValueKey('drive-16')), findsOneWidget);
    failing = false;
    // 记录之后还有节奏卡与页尾说明：重试入口要移到视口中部，否则会被收起顶栏遮住。
    await Scrollable.ensureVisible(
      tester.element(find.text('重试加载更多')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('重试加载更多'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('drive-15')),
      200,
    );
    expect(find.text('进行中'), findsOneWidget);
    expect(find.textContaining('电耗 0 Wh/km'), findsOneWidget);
    expect(find.textContaining('—'), findsWidgets);
    expect(find.byKey(const ValueKey('drive-16')), findsOneWidget);
    refresh = true;
    final refreshAction = find.byTooltip('刷新行程');
    await tester.scrollUntilVisible(refreshAction, -300);
    await Scrollable.ensureVisible(
      tester.element(refreshAction),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(refreshAction);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drive-15')), findsNothing);
    expect(find.textContaining('电耗 188 Wh/km'), findsWidgets);
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
    expect(find.text('这段时间没有行程'), findsOneWidget);
    await applyCustomRange(tester, '2024-03-09', '2024-03-10');
    expect(queries.last['from'], '2024-03-09T05:00:00.000Z');
    expect(queries.last['to'], '2024-03-11T04:00:00.000Z');
    zone = 'Asia/Shanghai';
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    // CP04 DF3：自定义区间只出现在焦点卡标签上（期间名 + 区间）。
    expect(find.text('自定义区间'), findsOneWidget);
    expect(find.text('3月9日\u201310日'), findsOneWidget);
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
    // P16：车辆行改为完整名称 +「Y，尾号 0002」（CP09.1 用逗号，不用「·」）。
    await tester.ensureVisible(find.text('Y，尾号 0002'));
    await tester.tap(find.text('Y，尾号 0002'));
    await tester.pumpAndSettle();
    expect(find.text('这段时间没有行程'), findsOneWidget);
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
    expect(find.textContaining('数据格式不受支持'), findsOneWidget);
    invalid = false;
    await tester.tap(find.text('重试行程'));
    await tester.pumpAndSettle();
    expect(find.textContaining('电耗 188 Wh/km'), findsWidgets);
    failure = true;
    await tester.tap(find.byTooltip('刷新行程'));
    await tester.pumpAndSettle();
    expect(find.textContaining('没能更新，显示的是'), findsOneWidget);
    expect(find.textContaining('电耗 188 Wh/km'), findsWidgets);
  });
}
