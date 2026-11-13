import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/layout.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/tokens.dart';
import 'package:mileaf/src/statistics_usage_page.dart';
import 'package:mileaf/src/workspace.dart';

import 'statistics_test.dart' show openStats;
import 'statistics_usage_test.dart' show usageClient, usageFixture, setCoverage;
import 'support/statistics_insights_fixture.dart';
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

http.Client dailyClient(
  List<Uri> seen, {
  String scenario = 'normal',
  Future<http.Response> Function(http.Request)? evidence,
}) {
  final base = usageClient(seen);
  var analysisRequested = false;
  var analysisReads = 0;
  return MockClient((request) async {
    if (request.url.path.endsWith('/drives')) {
      seen.add(request.url);
      if (evidence != null) return evidence(request);
      final empty =
          request.url.queryParameters['from'] == '2026-09-30T16:00:00.000Z';
      return http.Response(
        jsonEncode({
          'items': empty
              ? []
              : [
                  {
                    ...evidenceRecord(long: scenario == 'long'),
                    if (scenario == 'missing') ...{
                      'distance_km': null,
                      'duration_min': null,
                      'consumption_wh_km': null,
                    },
                  },
                ],
          'matched_drives': empty ? 0 : 1,
          'next_cursor': null,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (request.url.path.endsWith('/driving-analysis')) {
      analysisRequested = true;
      analysisReads++;
      seen.add(request.url);
      if (scenario == 'error' || (scenario == 'stale' && analysisReads > 1)) {
        return http.Response('{}', 503);
      }
      final body = usageFixture();
      final coverage = {
        ...setCoverage(),
        'candidate_count': 5,
        'valid_count': 5,
        'candidate_distance_km': 209,
        'valid_distance_km': 209,
        'candidate_duration_min': 210,
        'valid_duration_min': 210,
      };
      body.addAll({
        'active_days': 5,
        'driving_distance_km': 209,
        'distance_per_active_day_km': 41.8,
        'driving_duration_min': 210,
        'distance_p50_km': 12,
        'distance_p90_km': 120,
        'mean_speed_kmh': 59.7,
        'query': {
          ...body['query'] as Map,
          ...request.url.queryParameters,
          'vehicle_id': 1,
        },
        'coverage': {
          'candidate_count': 5,
          for (final key in ['distance', 'duration', 'speed', 'paired'])
            key: coverage,
        },
        'distance_bins': [
          for (final (lower, upper, count, km) in <(num, num?, int, num)>[
            (0, 50, 3, 24),
            (50, 100, 1, 65),
            (100, null, 1, 120),
          ])
            {
              ...(body['distance_bins'] as List).first as Map,
              'lower_km': lower,
              'upper_km': upper,
              'drives': count,
              'distance_km': km,
              'duration_min': km + (lower == 0 ? 1 : 0),
              'consumption_wh_km': 180,
              'paired_distance_km': km,
              'paired_energy_kwh': km * .18,
              'coverage': {
                for (final key in ['distance', 'duration', 'paired'])
                  key: {
                    ...coverage,
                    'valid_count': count,
                    'candidate_count': count,
                    'valid_distance_km': km,
                    'candidate_distance_km': km,
                    'valid_duration_min': km + (lower == 0 ? 1 : 0),
                    'candidate_duration_min': km + (lower == 0 ? 1 : 0),
                  },
              },
              'evidence_filter': {
                ...request.url.queryParameters,
                'completed_only': true,
                'distance_min_km': lower,
                'distance_max_km': ?upper,
              }..remove('view'),
            },
        ],
        'weekday_bins': [
          for (final (index, km) in [8, 120, 4, 0, 12, 0, 65].indexed)
            {
              'weekday': index + 1,
              'distance_km': km,
              'drives': km > 0 ? 1 : 0,
              'duration_min': km + (index == 4 ? 1 : 0),
              'status': 'available',
              'coverage': {
                for (final key in ['distance', 'duration'])
                  key: {
                    ...coverage,
                    'candidate_count': km > 0 ? 1 : 0,
                    'valid_count': km > 0 ? 1 : 0,
                    'valid_distance_km': km,
                    'candidate_distance_km': km,
                    'valid_duration_min': km + (index == 4 ? 1 : 0),
                    'candidate_duration_min': km + (index == 4 ? 1 : 0),
                  },
              },
            },
        ],
      });
      if (scenario == 'empty') {
        body.addAll({
          'status': 'no_records',
          'active_days': 0,
          'driving_distance_km': 0,
          'distance_per_active_day_km': null,
        });
      }
      if (scenario == 'missing') {
        body.addAll({
          'mean_speed_kmh': null,
          'distance_p50_km': null,
          'driving_duration_min': null,
        });
        for (final key in ['speed', 'duration']) {
          (body['coverage'] as Map)[key] = {
            ...coverage,
            'valid_count': 0,
            'excluded_count': 5,
          };
        }
      }
      if (scenario == 'zero') {
        body.addAll({
          'active_days': 1,
          'driving_distance_km': 0,
          'distance_per_active_day_km': 0,
          'driving_duration_min': 10,
          'distance_p50_km': 0,
          'distance_p90_km': 0,
          'mean_speed_kmh': 0,
          'distance_bins': [],
          'weekday_bins': [],
        });
      }
      if (scenario == 'unsupported') body['status'] = 'unsupported';
      return http.Response(jsonEncode(body), 200);
    }
    if (request.url.path.endsWith('/stats') &&
        request.url.queryParameters['kind'] == 'driving') {
      seen.add(request.url);
      if (analysisRequested &&
          (scenario == 'error' ||
              (scenario == 'stale' && analysisReads == 1))) {
        return http.Response('{}', 503);
      }
      final body = statisticsInsightsFixture(request.url);
      final metrics = (body['buckets'] as List).first as Map<String, dynamic>;
      body['totals'] = _dailyMetrics(
        metrics,
        scenario == 'zero' ? 0 : 209,
        5,
        scenario == 'zero' ? 10 : 210,
      );
      // Missing October 3 is an absent daily bucket. The published bucket
      // contract requires distance_km, so never fabricate a null DTO field.
      body['buckets'] = [
        for (final (day, km) in [
          (1, 0),
          (2, 12),
          (4, 65),
          (5, 8),
          (6, 120),
          (7, 4),
        ])
          {
            ..._dailyMetrics(
              metrics,
              km,
              km > 0 ? 1 : 0,
              km + (day == 2 ? 1 : 0),
            ),
            'bucket_start': DateTime.utc(
              2026,
              9,
              29 + day,
              16,
            ).toIso8601String(),
            'distance_km': km,
          },
        for (var day = 8; day <= 28; day++)
          {
            ..._dailyMetrics(metrics, 0, 0, 0),
            'bucket_start': DateTime.utc(
              2026,
              9,
              29 + day,
              16,
            ).toIso8601String(),
            'distance_km': 0,
          },
      ];
      if (scenario == 'zero') {
        body['buckets'] = [
          for (final bucket in body['buckets'] as List)
            {
              ...bucket as Map,
              ..._dailyMetrics(
                metrics,
                0,
                bucket['bucket_start'] == '2026-09-30T16:00:00.000Z' ? 5 : 0,
                bucket['bucket_start'] == '2026-09-30T16:00:00.000Z' ? 10 : 0,
              ),
            },
        ];
      }
      return http.Response(jsonEncode(body), 200);
    }
    final forwarded = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return http.Response.fromStream(await base.send(forwarded));
  });
}

Map<String, dynamic> _dailyMetrics(
  Map<String, dynamic> base,
  num km,
  int count,
  num minutes,
) {
  final coverage = {
    ...setCoverage(),
    'candidate_count': count,
    'valid_count': count,
    'candidate_distance_km': km,
    'valid_distance_km': km,
    'candidate_duration_min': minutes,
    'valid_duration_min': minutes,
  };
  return {
    ...base,
    'drives': count,
    'distance_km': km,
    'energy_kwh': km * .18,
    'consumption_wh_km_net': km == 0 ? null : 180,
    'driving_coverage': {
      ...base['driving_coverage'] as Map,
      'completed_drives': count,
      'distance_known_drives': count,
      'distance_known_km': km,
      'net_energy_known_drives': count,
      'net_energy_known_distance_km': km,
      'duration_known_drives': count,
      'duration_known_min': minutes,
      'distance': coverage,
      'net_energy': coverage,
      'duration': coverage,
    },
    'net_consumption_paired': {
      ...base['net_consumption_paired'] as Map,
      'value_wh_km': km == 0 ? null : 180,
      'numerator_energy_kwh': km * .18,
      'denominator_distance_km': km,
      'eligible_drives': count,
      'coverage': coverage,
    },
    'comparison_quality': {
      ...base['comparison_quality'] as Map,
      'eligible_drives': count,
    },
  };
}

Map<String, dynamic> evidenceRecord({bool long = false}) => {
  'id': 17,
  'started_at': '2026-10-02T05:00:00Z',
  'ended_at': '2026-10-02T05:13:00Z',
  'distance_km': 12,
  'duration_min': 13,
  'consumption_wh_km': 180,
  'start': {'display_name': long ? '上海虹桥交通枢纽地下停车场西侧新能源充电区与长名称地点完整展示起点' : '家'},
  'end': {'display_name': long ? '杭州未来科技城软件园南区东侧门办公楼地下二层终点完整名称' : '公司'},
};

Future<void> openUsage(
  WidgetTester tester,
  http.Client client, {
  DateTime? now,
  String zone = 'Asia/Shanghai',
}) async {
  await openStats(
    tester,
    client,
    () => now ?? DateTime.utc(2026, 10, 28, 11),
    () => zone,
    statisticsInsights: true,
  );
  await tester.scrollUntilVisible(find.text('节奏').hitTestable(), 150);
  await tester.tap(find.text('节奏').first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('360日期矩阵四列，真零与缺日均可读，日期实际命中至少44', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final seen = <Uri>[];
    await openUsage(tester, dailyClient(seen));
    final cells = [for (var day = 1; day <= 5; day++) find.text('10/$day')];
    final first = tester.getRect(cells[0]);
    expect(tester.getRect(cells[3]).top, first.top);
    expect(tester.getRect(cells[4]).top, greaterThan(first.bottom));
    expect(find.text('日期矩阵'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
    expect(find.text('—'), findsWidgets);
    expect(find.text('10/29'), findsNothing);
    final button = find.ancestor(
      of: cells.first,
      matching: find.byType(TextButton),
    );
    final rect = tester.getRect(button);
    expect(rect.width, greaterThanOrEqualTo(44));
    expect(rect.height, greaterThanOrEqualTo(44));
    for (final point in [
      rect.topLeft + const Offset(1, 1),
      rect.bottomRight - const Offset(1, 1),
    ]) {
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(find.text('10月1日行程'), findsOneWidget);
      final request = seen.lastWhere((uri) => uri.path.endsWith('/drives'));
      expect(request.queryParameters['from'], '2026-09-30T16:00:00.000Z');
      expect(request.queryParameters['to'], '2026-10-01T16:00:00.000Z');
      expect(request.queryParameters['tz'], 'Asia/Shanghai');
      expect(request.queryParameters['completed_only'], 'true');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
    }
    expect(tester.getRect(button).height, rect.height);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.selected == true &&
            (widget.properties.label?.contains('10月1日') ?? false),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('无匹配行程显示明确空态，未知匹配数不补零', (tester) async {
    await openUsage(
      tester,
      dailyClient(
        [],
        evidence: (_) async => http.Response(
          jsonEncode({
            'items': [],
            'matched_drives': null,
            'next_cursor': null,
          }),
          200,
        ),
      ),
    );
    await tester.tap(find.text('10/1'));
    await tester.pumpAndSettle();
    expect(find.text('没有匹配行程'), findsOneWidget);
    expect(find.text('完整匹配 — 趟'), findsOneWidget);
  });

  testWidgets('活跃天数36，日期文字与纹理在浅深最终背景上达到对比要求', (tester) async {
    await openUsage(tester, dailyClient([]));
    final active = tester.widget<Text>(find.text('活跃 5 天'));
    expect(
      ((active.textSpan as TextSpan).children![1] as TextSpan).style!.fontSize,
      36,
    );
    expect(
      MileafLayout.largeText(tester.element(find.text('活跃 5 天'))),
      isFalse,
    );
    double contrast(Color a, Color b) {
      final first = Color.alphaBlend(a, b).computeLuminance();
      final second = b.computeLuminance();
      return (math.max(first, second) + .05) / (math.min(first, second) + .05);
    }

    for (final colors in [
      const MileafColors.light(),
      const MileafColors.dark(),
    ]) {
      for (final background in [
        colors.surface,
        Color.alphaBlend(colors.accentSoft, colors.canvas),
      ]) {
        expect(contrast(colors.text, background), greaterThanOrEqualTo(4.5));
        expect(
          contrast(colors.controlBorder, background),
          greaterThanOrEqualTo(3),
        );
        expect(
          contrast(colors.accentStrong, background),
          greaterThanOrEqualTo(3),
        );
      }
    }
    expect(MileafSpace.touch, 44);
  });

  testWidgets('390实际内容宽允许七列，150%改逐日布局且按日值仍可下钻', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openUsage(tester, dailyClient([]));
    final first = tester.getRect(find.text('10/1'));
    expect(tester.getRect(find.text('10/7')).top, first.top);
    expect(tester.getRect(find.text('10/8')).top, greaterThan(first.bottom));
    final cell = find.ancestor(
      of: find.text('10/7'),
      matching: find.byType(TextButton),
    );
    expect(tester.getSize(cell).width, greaterThanOrEqualTo(44));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    await tester.pumpAndSettle();
    expect(find.text('每日记录'), findsOneWidget);
    expect(
      tester.getRect(find.text('2026年10月2日')).top,
      greaterThan(tester.getRect(find.text('2026年10月1日')).bottom),
    );
    await tester.scrollUntilVisible(
      find.text('2026年10月2日').hitTestable(),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('2026年10月2日'));
    await tester.pumpAndSettle();
    expect(find.text('10月2日行程'), findsOneWidget);
    expect(
      find.byType(MileafDataRow),
      findsWidgets,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data ?? text.textSpan?.toPlainText())
          .join('\n'),
    );
    await tester.scrollUntilVisible(
      find.text('12 km'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('12 km'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('局部失败有恢复动作，重试失败保留摘要且标明快照时间', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await openUsage(tester, dailyClient([], scenario: 'stale'));
    expect(find.text('活跃 5 天'), findsOneWidget);
    expect(find.text('每日里程读取失败'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('重试日历').hitTestable(),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('重试日历'));
    await tester.pumpAndSettle();
    expect(find.text('活跃 5 天'), findsOneWidget);
    expect(find.textContaining('保留上次结果（2026-10-28T11:00:00Z）'), findsOneWidget);
    expect(find.text('正在加载用车节奏'), findsNothing);
    expect(find.text('用车节奏更新中'), findsNothing);
    final message = tester.getRect(
      find.textContaining('保留上次结果（2026-10-28T11:00:00Z）'),
    );
    final action = tester.getRect(find.widgetWithText(TextButton, '重试用车节奏'));
    expect(message.width, greaterThanOrEqualTo(280));
    expect(action.top, greaterThanOrEqualTo(message.bottom));
  });

  testWidgets('星期极大读值与缺失在普通窄屏重排，语义覆盖说明可查', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final base = dailyClient([]);
    await openUsage(
      tester,
      MockClient((request) async {
        final forwarded = http.Request(request.method, request.url)
          ..headers.addAll(request.headers)
          ..bodyBytes = request.bodyBytes;
        final response = await http.Response.fromStream(
          await base.send(forwarded),
        );
        if (!request.url.path.endsWith('/driving-analysis')) return response;
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        // Isolate a potentially wide weekday label. The server remains the
        // authority for this value, and the client must keep it fully readable.
        (body['weekday_bins'] as List)[0]['distance_km'] = 1234567.8;
        (body['weekday_bins'] as List)[1]['distance_km'] = null;
        return http.Response(jsonEncode(body), 200);
      }),
    );
    await tester.scrollUntilVisible(
      find.text('周一  1234567.8 km').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('周二  — km'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final fact = find.byWidgetPredicate(
      (widget) => widget is MetricBlock && widget.label == '驾驶记录时长',
    );
    expect(
      tester.widget<MetricBlock>(fact).semanticLabel,
      contains('有效 5 趟，排除 0 趟'),
    );
  });

  testWidgets('日期可用键盘聚焦，焦点边界一帧内可见且按键可下钻', (tester) async {
    await openUsage(tester, dailyClient([]));
    final date = find.text('10/1');
    final focus = Focus.of(tester.element(date));
    for (var i = 0; !focus.hasFocus && i < 10; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focus.hasFocus, isTrue);
    final button = find.ancestor(of: date, matching: find.byType(TextButton));
    final material = tester.widget<Material>(
      find.descendant(of: button, matching: find.byType(Material)).first,
    );
    final side = (material.shape! as OutlinedBorder).side;
    expect(side.width, 2);
    expect(side.color, MileafColors.of(tester.element(button)).accentStrong);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('10月1日行程'), findsOneWidget);
  });

  testWidgets('全部真实0仍显示每日日期和0，缺日保持未知', (tester) async {
    await openUsage(tester, dailyClient([], scenario: 'zero'));
    expect(find.text('10/1'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
    expect(find.text('—'), findsWidgets);
    expect(find.text('还没有每日里程'), findsNothing);
  });

  testWidgets('按站点DST日界下钻25小时且今日截止沿原查询', (tester) async {
    final seen = <Uri>[];
    await openUsage(
      tester,
      usageClient(seen),
      now: DateTime.utc(2026, 11, 3, 19),
      zone: 'America/New_York',
    );
    await tester.tap(find.text('11/1'));
    await tester.pumpAndSettle();
    var request = seen.lastWhere((uri) => uri.path.endsWith('/drives'));
    expect(request.queryParameters['from'], '2026-11-01T04:00:00.000Z');
    expect(request.queryParameters['to'], '2026-11-02T05:00:00.000Z');
    expect(request.queryParameters['tz'], 'America/New_York');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('11/3'));
    await tester.pumpAndSettle();
    request = seen.lastWhere((uri) => uri.path.endsWith('/drives'));
    expect(request.queryParameters['to'], '2026-11-03T19:00:00.000Z');
  });

  testWidgets('证据翻页失败保留记录与完整匹配数，重试沿原筛选与cursor', (tester) async {
    final seen = <Uri>[];
    var more = 0;
    await openUsage(
      tester,
      dailyClient(
        seen,
        evidence: (request) async {
          final next = request.url.queryParameters['cursor'] != null;
          if (next && more++ == 0) return http.Response('{}', 503);
          return http.Response(
            jsonEncode({
              'items': [
                {...evidenceRecord(), 'id': next ? 18 : 17},
              ],
              'matched_drives': 3,
              'next_cursor': next ? null : 'page-2',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        },
      ),
    );
    await tester.scrollUntilVisible(
      find.text('0–50 km').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('0–50 km'));
    await tester.pumpAndSettle();
    expect(
      find.byType(DrivingEvidencePage),
      findsOneWidget,
      reason: seen.map((uri) => uri.path).join('\n'),
    );
    expect(
      find.byType(MileafDataRow),
      findsWidgets,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data ?? text.textSpan?.toPlainText())
          .join('\n'),
    );
    await tester.scrollUntilVisible(
      find.text('加载更多行程').hitTestable(),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('加载更多行程'));
    await tester.pumpAndSettle();
    expect(find.text('家 → 公司'), findsOneWidget);
    expect(find.text('完整匹配 3 趟'), findsOneWidget);
    expect(find.text('行程证据读取失败，已载记录保留'), findsOneWidget);
    await tester.ensureVisible(find.text('重试行程证据'));
    await tester.tap(find.text('重试行程证据'));
    await tester.pumpAndSettle();
    expect(find.text('家 → 公司'), findsNWidgets(2));
    final requests = seen.where((uri) => uri.path.endsWith('/drives')).toList();
    expect(requests, hasLength(3));
    expect(requests[1].queryParameters['cursor'], 'page-2');
    expect(requests[2].queryParameters, requests[1].queryParameters);
    expect(requests.first.queryParameters['distance_max_km'], '50');
  });

  const output = String.fromEnvironment('MILEAF_U09A_RENDER_OUTPUT');
  const font = String.fromEnvironment('MILEAF_RENDER_FONT');
  const before = bool.fromEnvironment('MILEAF_U09A_BEFORE');
  testWidgets('U09a 正式Flutter节奏与证据矩阵及完整滚动', (tester) async {
    await loadRenderFonts(cjkFontPath: font);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final files = <String>[];
    final measurements = <Map<String, Object?>>[];
    final cases = <(Size, double, String, bool)>[
      for (final dark in [false, true]) ...[
        for (final scenario in ['normal', 'empty', 'missing'])
          for (final scale in [1.0, 2.0])
            (const Size(360, 800), scale, scenario, dark),
        for (final scale in [1.3, 1.5])
          (const Size(360, 800), scale, 'normal', dark),
        (const Size(320, 568), 2, 'long', dark),
        (const Size(390, 844), 1, 'normal', dark),
        (const Size(768, 1024), 2, 'normal', dark),
        for (final scenario in ['zero', 'error', 'unsupported'])
          (const Size(360, 800), 1, scenario, dark),
        (const Size(360, 800), dark ? 2 : 1, 'stale', dark),
      ],
    ];
    for (final (size, scale, scenario, dark) in cases) {
      if (before &&
          (size.width != 360 || scale != 1 || scenario != 'normal' || dark)) {
        continue;
      }
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      final boundary = GlobalKey();
      final name =
          'u09a-${before ? 'before-' : ''}usage-$scenario-${dark ? 'dark' : 'light'}-${size.width.toInt()}-${(scale * 100).round()}';
      final appearance = AppearanceController(
        _Appearance(dark ? 'dark' : 'light'),
      );
      await appearance.restore();
      final store = MemorySessionStore()
        ..value = jsonEncode({
          'site': 'https://example.com/prefix',
          'token': 'test',
          'expires_at': '2099-01-01T00:00:00Z',
        });
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MileafApp(
            key: ValueKey(name),
            client: dailyClient([], scenario: scenario),
            sessionStore: store,
            trustStore: MemoryTrustStore(),
            vehiclePreferences: MemoryVehiclePreferences(),
            appearance: appearance,
            now: () => DateTime.utc(2026, 10, 28, 11),
            calendar: () async => CalendarContext('Asia/Shanghai'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('统计').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('节奏').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('节奏').first);
      await tester.pumpAndSettle();
      if (scenario == 'stale') {
        await tester.scrollUntilVisible(
          find.text('重试日历').hitTestable(),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text('重试日历'));
        await tester.pumpAndSettle();
        tester
            .state<ScrollableState>(
              find
                  .descendant(
                    of: find.byType(StatisticsUsagePage),
                    matching: find.byType(Scrollable),
                  )
                  .last,
            )
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
      }
      Future<void> save(String camera, {bool evidence = false}) async {
        final path =
            '$output/gallery/${evidence ? name.replaceFirst('usage', 'evidence') : name}-$camera.png';
        // Repaint retained layers before off-screen capture, including the
        // AppBar/back icon after a route transition. The app tree is unchanged.
        void repaint(RenderObject object) {
          object.markNeedsPaint();
          object.visitChildren(repaint);
        }

        repaint(tester.renderObject(find.byKey(boundary)));
        await tester.pump();
        await saveRenderPng(tester, find.byKey(boundary), path);
        files.add(path);
      }

      await save('top');
      if (!before && scenario == 'normal' && size.width == 360 && scale == 1) {
        final plot = tester.getRect(
          find.byKey(const ValueKey('usage-daily-plot')),
        );
        final bodyTop = tester.getRect(find.byType(AppBar).last).bottom;
        final visible =
            math.min(plot.bottom, size.height - 24) -
            math.max(plot.top, bodyTop);
        expect(visible, greaterThanOrEqualTo(120));
        measurements.add({
          'name': name,
          'bodyTop': bodyTop,
          'plotTopInBody': plot.top - bodyTop,
          'plotVisible': visible,
        });
      }
      final scroll = find
          .descendant(
            of: find.byType(StatisticsUsagePage),
            matching: find.byType(Scrollable),
          )
          .last;
      final state = tester.state<ScrollableState>(scroll);
      if (!before) {
        expect(tester.getSize(scroll).width, lessThanOrEqualTo(560));
        if (size.width == 768 && scenario == 'normal') {
          final header = tester.getRect(
            find.widgetWithText(ExpansionTile, '2026/10/1 — 2026/10/28'),
          );
          final plot = tester.getRect(
            find.byKey(const ValueKey('usage-daily-plot')),
          );
          expect(header.left, closeTo(plot.left, 1));
          expect(header.width, closeTo(plot.width, 1));
          measurements.add({
            'name': name,
            'headerLeft': header.left,
            'plotLeft': plot.left,
            'contentWidth': plot.width,
          });
        }
      }
      var step = 0;
      final full = scenario == 'normal' && size.width == 360 && scale == 1;
      while (state.position.extentAfter > 0 && step < 60) {
        await tester.drag(scroll, Offset(0, -size.height * .65));
        await tester.pumpAndSettle();
        step++;
        if (full) await save('scroll$step');
      }
      expect(state.position.extentAfter, 0);
      await save('bottom');
      if (scenario == 'normal' || scenario == 'missing' || scenario == 'long') {
        final notes = find.descendant(
          of: find.byType(StatisticsUsagePage),
          matching: find.widgetWithText(ExpansionTile, '数据说明'),
        );
        await tester.ensureVisible(notes);
        await tester.tap(notes);
        await tester.pumpAndSettle();
        state.position.jumpTo(state.position.maxScrollExtent);
        await tester.pumpAndSettle();
        await save('notes');
        state.position.jumpTo(0);
        await tester.pumpAndSettle();
        final date = find.text(scale >= 1.5 && !before ? '2026年10月2日' : '10/2');
        await tester.scrollUntilVisible(
          date.hitTestable(),
          100,
          scrollable: scroll,
        );
        await tester.tap(date);
        await tester.pumpAndSettle();
        await save('top', evidence: true);
        final list = find.byType(Scrollable).last;
        while (tester.state<ScrollableState>(list).position.extentAfter > 0) {
          await tester.drag(list, Offset(0, -size.height * .65));
          await tester.pumpAndSettle();
        }
        await save('bottom', evidence: true);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        if (!before) {
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics &&
                  widget.properties.selected == true &&
                  (widget.properties.label?.contains('10月2日') ?? false),
            ),
            findsOneWidget,
          );
        }
        if (!before &&
            scenario == 'normal' &&
            size.width == 360 &&
            (scale == 1 || scale == 2)) {
          state.position.jumpTo(0);
          await tester.pumpAndSettle();
          final zero = find.text(scale >= 1.5 ? '2026年10月1日' : '10/1');
          await tester.scrollUntilVisible(
            zero.hitTestable(),
            100,
            scrollable: scroll,
          );
          await tester.tap(zero);
          await tester.pumpAndSettle();
          await save('empty', evidence: true);
          expect(find.text('没有匹配行程'), findsOneWidget);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
        }
      }
      if (before) break;
    }
    await tester.runAsync(() async {
      await File('$output/gallery/u09a-${before ? 'before-' : ''}manifest.json')
          .writeAsString(
            const JsonEncoder.withIndent('  ')
                .convert({'files': files, 'measurements': measurements}),
          );
    });
  }, skip: output.isEmpty || font.isEmpty);
}

class _Appearance implements AppearancePreferenceStore {
  _Appearance(this.value);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? value) async => this.value = value;
}
