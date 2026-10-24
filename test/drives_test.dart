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
    expect(find.textContaining('净电耗 188 Wh/km'), findsWidgets);
    expect(find.textContaining('未知地点'), findsWidgets);
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
    await tester.scrollUntilVisible(find.text('加载更多行程'), 200);
    await tester.tap(find.text('加载更多行程'));
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
    await tester.tap(find.text('筛选日期'));
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
    await tester.tap(find.text('最近30日'));
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
