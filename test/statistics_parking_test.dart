import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mileaf/src/design/components/components.dart';

import 'overview_test.dart' show background, foreground;
import 'statistics_test.dart' show openStats, fixture;
import 'support/statistics_insights_fixture.dart';

Map<String, dynamic> aggregate({bool empty = false}) => {
  'candidate_windows': 4,
  'valid_windows': empty ? 0 : 2,
  'excluded_windows': 1,
  'open_windows': 1,
  'observed_hours': empty ? 0 : 12,
  'soc_change_pp': empty ? null : -2,
  'soc_change_pp_per_24h': empty ? null : -4,
  // 无有效窗口时无观测小时：状态小时与占比同步归零，分母与图形自洽。
  'online_hours': empty ? 0 : 2,
  'asleep_hours': empty ? 0 : 6,
  'offline_hours': empty ? 0 : 1,
  'unknown_hours': empty ? 0 : 3,
  'online_share': empty ? null : 1 / 6,
  'asleep_share': empty ? null : .5,
  'offline_share': empty ? null : 1 / 12,
  'unknown_share': empty ? null : .25,
  'excluded_by_reason': {'missing_soc': 1},
};
Map<String, dynamic> parkingResponse(
  Uri uri, {
  bool empty = false,
  bool missing = false,
}) => {
  'status': empty ? 'insufficient_data' : 'available',
  'query': {
    'vehicle_id': 1,
    ...Map<String, String>.from(uri.queryParameters)..remove('cursor'),
    'time_basis': 'window_start',
    'filters': {},
  },
  'as_of': '2026-10-29T12:00:00Z',
  'totals': aggregate(empty: empty),
  'buckets': [
    if (!empty)
      for (final change in [-2, 0, 1])
        {
          'bucket_start': uri.queryParameters['from'],
          ...aggregate(empty: empty),
          'soc_change_pp': missing ? null : change,
        },
  ],
  'matched_windows': empty ? 0 : 4,
  // 无有效窗口时无已匹配窗口证据，也不发下一页。
  'next_cursor': empty
      ? null
      : uri.queryParameters.containsKey('cursor')
      ? null
      : 'page2',
  'items': [
    if (!empty && !uri.queryParameters.containsKey('cursor'))
      for (final quality in ['complete', 'partial_state_coverage', 'excluded'])
        {
          'window_id': quality,
          'start_event': {'type': 'drive', 'id': 1},
          'end_event': {'type': 'charge', 'id': 2},
          'window_start': '2026-10-27T22:00:00Z',
          'window_end': '2026-10-28T12:00:00Z',
          'duration_hours': 14,
          'start': {
            'raw_time': '2026-10-27T22:00:00Z',
            'soc': 70,
            'soc_source': 'drive_end_position',
            'odometer_km': 100,
            'odometer_source': 'drive_end_position',
            'position_id': 1,
          },
          'end': {
            'raw_time': '2026-10-28T12:00:00Z',
            'soc': quality == 'excluded' ? null : 69,
            'soc_source': 'charging_start_battery_level',
            'odometer_km': 99.8,
            'odometer_source': 'charging_start_position',
            'position_id': 2,
          },
          'included': quality != 'excluded',
          'quality': quality,
          'exclusion_reason': quality == 'excluded' ? 'missing_soc' : null,
          'soc_change_pp': quality == 'excluded' ? null : -1,
          'soc_change_pp_per_24h': quality == 'excluded' ? null : -1.714,
          'odometer_change_km': -.2,
          'negative_odometer_change': true,
          'online_hours': 2,
          'asleep_hours': 8,
          'offline_hours': 1,
          'unknown_hours': 3,
        },
    if (!empty && uri.queryParameters.containsKey('cursor'))
      {
        'window_id': uri.queryParameters.containsKey('cursor')
            ? 'open-tail'
            : 'closed-1',
        'start_event': {'type': 'drive', 'id': 1},
        'end_event': null,
        'window_start': '2026-10-28T00:00:00Z',
        'window_end': null,
        'duration_hours': null,
        'start': {
          'raw_time': '2026-10-28T00:00:00Z',
          'soc': 70,
          'soc_source': 'drive_end_position',
          'odometer_km': 100,
          'odometer_source': 'drive_end_position',
          'position_id': 1,
          'rated_range_km': 300,
        },
        'end': {},
        'included': false,
        'quality': 'open_window',
        'exclusion_reason': null,
        'soc_change_pp': null,
        'soc_change_pp_per_24h': null,
        'odometer_change_km': null,
        'negative_odometer_change': false,
        'online_hours': 0,
        'asleep_hours': 0,
        'offline_hours': 0,
        'unknown_hours': 1,
      },
  ],
};
Future<void> openParking(
  WidgetTester tester,
  List<Uri> requests, {
  bool empty = false,
  bool fail = false,
  bool missing = false,
  Map<String, dynamic> Function(Uri)? response,
}) async {
  await openStats(
    tester,
    MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      if (r.url.path.endsWith('/meta')) {
        return http.Response(
          jsonEncode(
            statisticsInsightsMeta(
              features: {
                'driving_coverage': true,
                'parking_observations': true,
              },
            ),
          ),
          200,
        );
      }
      if (r.url.path.endsWith('/parking-observations')) {
        requests.add(r.url);
        if (fail) return http.Response('{}', 503);
        return http.Response(
          jsonEncode(
            response?.call(r.url) ??
                parkingResponse(r.url, empty: empty, missing: missing),
          ),
          200,
        );
      }
      return http.Response(jsonEncode(statisticsInsightsFixture(r.url)), 200);
    }),
    () => DateTime.utc(2026, 10, 28, 11),
    () => 'Asia/Shanghai',
    statisticsInsights: true,
  );
  await tester.scrollUntilVisible(
    find.text('长期').hitTestable(),
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text('长期').hitTestable());
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('展开停放观察').hitTestable(),
    100,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('展开停放观察').hitTestable());
  await tester.pumpAndSettle();
}

/// R27/CP06：读数头步进圆钮（语义「上一个数据点」「下一个数据点」）。
Finder stepButton(String label) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      widget.properties.button == true &&
      widget.properties.label == label,
);

Future<void> scrollToStep(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    stepButton(label).hitTestable(),
    100,
    scrollable: find.byType(Scrollable).last,
  );
}

void main() {
  testWidgets('停放结果重排及删除后读数保持有效', (tester) async {
    var phase = 0;
    await openParking(
      tester,
      <Uri>[],
      response: (uri) {
        final body = parkingResponse(uri);
        final rows = body['buckets'] as List;
        if (phase == 1) body['buckets'] = rows.reversed.toList();
        if (phase == 2) body['buckets'] = [rows.last];
        return body;
      },
    );
    await scrollToStep(tester, MileafChartGrammar.nextStep);
    await tester.tap(stepButton(MileafChartGrammar.nextStep));
    await tester.pumpAndSettle();
    phase = 1;
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('0.0 个百分点'), findsWidgets);
    phase = 2;
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('1.0 个百分点'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('同日刷新保留重复日期中的有效选点', (tester) async {
    await openParking(tester, <Uri>[]);
    await scrollToStep(tester, MileafChartGrammar.nextStep);
    await tester.tap(stepButton(MileafChartGrammar.nextStep));
    await tester.pumpAndSettle();
    expect(find.textContaining('0.0 个百分点'), findsWidgets);
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('0.0 个百分点'), findsWidgets);
  });

  testWidgets('停放观察经展开入口建立后，统计Tab隐藏不请求，可见后才校验', (tester) async {
    // P15/U08交接：长期索引不再嵌入专题；先通过「展开停放观察」入口建立
    // 专题路由，再保留隐藏不请求、重新可见后才校验等业务断言（S03）。
    final reads = <Uri>[];
    await openStats(
      tester,
      MockClient((r) async {
        if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
        if (r.url.path.endsWith('/summary')) return fixture('summary');
        if (r.url.path.endsWith('/meta')) {
          // No insights overview: the long topics live behind the index.
          return http.Response(
            jsonEncode(
              statisticsInsightsMeta(features: {'parking_observations': true}),
            ),
            200,
          );
        }
        if (r.url.path.endsWith('/parking-observations')) {
          reads.add(r.url);
          return http.Response(jsonEncode(parkingResponse(r.url)), 200);
        }
        return http.Response(jsonEncode(statisticsInsightsFixture(r.url)), 200);
      }),
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await tester.tap(find.text('长期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('展开停放观察'));
    await tester.pumpAndSettle();
    expect(reads, isNotEmpty, reason: '前置：专题路由确实读过');
    // 隐藏：关闭专题路由并把统计Tab切走；隐藏页面不取新数据（S03）。
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    // P15：返回长期索引时统计承载上下文保留（索引两入口仍在）；专题路由
    // 重建沿 baseCommit 的既有路由结构。
    expect(find.text('展开长期续航'), findsOneWidget);
    expect(find.text('展开停放观察'), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(MileafNavBar), matching: find.text('行程')),
    );
    await tester.pumpAndSettle();
    reads.clear();
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(reads, isEmpty, reason: '统计Tab隐藏时，停放观察不得在后台请求');
    await tester.tap(
      find.descendant(of: find.byType(MileafNavBar), matching: find.text('统计')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('展开停放观察'));
    await tester.pumpAndSettle();
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(reads.length, greaterThan(0), reason: '重新可见后才校验');
    expect(tester.takeException(), isNull);
  });

  testWidgets('360宽双倍字号完整页可滚动无溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await openParking(tester, <Uri>[]);
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('加载更多停车记录').hitTestable(),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('停车资源失败保留统计承载并可独立重试', (tester) async {
    final requests = <Uri>[];
    await openParking(tester, requests, fail: true);
    // CP07：共享状态句「没能读取{对象}」+ 通用「重试」。
    expect(find.text('没能读取停放观察'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('重试').hitTestable(),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    final beforeRetry = requests.length;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(requests.length, beforeRetry + 1);
    expect(find.text('停放观察'), findsOneWidget);
  });
  testWidgets('停车服务端汇总与冻结分页证据独立显示', (tester) async {
    final requests = <Uri>[];
    await openParking(tester, requests);
    // R25/P11：主图卡为「每段停车」；限定语 CP08 改写。
    expect(find.textContaining('每段停车'), findsWidgets);
    expect(find.textContaining('不预测未来'), findsOneWidget);
    expect(find.text('关于这些数据'), findsOneWidget);
    expect(find.textContaining('查询生成于'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('parking-trend-chart')), findsOneWidget);
    expect(find.textContaining('−2.0 个百分点'), findsWidgets);
    await scrollToStep(tester, MileafChartGrammar.nextStep);
    await tester.tap(stepButton(MileafChartGrammar.nextStep));
    await tester.pumpAndSettle();
    expect(find.textContaining('0.0 个百分点'), findsWidgets);
    await tester.tap(stepButton(MileafChartGrammar.nextStep));
    await tester.pumpAndSettle();
    expect(find.textContaining('1.0 个百分点'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('加载更多停车记录').hitTestable(),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('加载更多停车记录'));
    await tester.pumpAndSettle();
    expect(
      requests.last.queryParameters['to'],
      requests.first.queryParameters['to'],
    );
    expect(requests.last.queryParameters['cursor'], 'page2');
    // CP10：记录行用人话标签；开放窗口行标题「尚未结束」，展开后可见编号。
    expect(find.text('尚未结束'), findsOneWidget);
    expect(find.text('状态记录不完整（仍计入）'), findsOneWidget);
    await tester.tap(find.text('尚未结束'));
    await tester.pumpAndSettle();
    expect(find.textContaining('open-tail'), findsOneWidget);
    final tech = find.text('技术详情');
    await tester.ensureVisible(tech.last);
    await tester.pumpAndSettle();
    await tester.tap(tech.last);
    await tester.pumpAndSettle();
    // 技术详情（可复制）：算法版本与阈值原值在此出现（R30.4）。
    expect(find.textContaining('method closed-window-soc-v1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('无有效窗口不展示零损耗', (tester) async {
    await openParking(tester, <Uri>[], empty: true);
    expect(find.textContaining('— 个百分点'), findsWidgets);
  });
}
