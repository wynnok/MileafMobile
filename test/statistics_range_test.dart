import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mileaf/src/design/components/components.dart';

import 'overview_test.dart' show background, foreground;
import 'statistics_test.dart' show openStats, fixture;
import 'support/statistics_insights_fixture.dart';

Map<String, dynamic> rangeResponse({
  int months = 6,
  bool sparse = false,
  bool missing = false,
  bool empty = false,
}) => {
  'query': {
    'vehicle_id': 1,
    'from': DateTime.utc(
      2026,
      11 - months,
      1,
    ).subtract(const Duration(hours: 8)).toIso8601String(),
    'to': '2026-10-28T11:00:00Z',
    'tz': 'Asia/Shanghai',
    'filters': {'months': months},
  },
  'as_of': '2026-10-28T11:00:00Z',
  'first_observed_at': '2026-05-02T00:00:00Z',
  'first_observed_scope': 'query',
  'totals': {
    'status': empty ? 'no_records' : 'available',
    'sample_status': sparse ? 'sparse' : 'adequate',
  },
  'buckets': [
    for (var m = 0; m < (empty ? 0 : months); m++)
      {
        'bucket_start': DateTime.utc(
          2026,
          11 - months + m,
          1,
        ).subtract(const Duration(hours: 8)).toIso8601String(),
        'partial': m == months - 1,
        'status': missing && m == months - 1 ? 'no_records' : 'available',
        'sample_status': missing && m == months - 1
            ? 'insufficient_data'
            : sparse
            ? 'sparse'
            : 'adequate',
        'median_range_km': missing && m == months - 1
            ? null
            : m == months - 1
            ? 432
            : 440,
        'p10_range_km': missing && m == months - 1 ? null : 422,
        'p90_range_km': missing && m == months - 1 ? null : 449,
        'coverage': {
          'valid_days': missing && m == months - 1
              ? 0
              : sparse
              ? 2
              : 8,
          'candidate_sessions': missing && m == months - 1 ? 0 : 10,
          'valid_sessions': missing && m == months - 1 ? 0 : 10,
          'candidate_points': missing && m == months - 1 ? 0 : 120,
          'valid_points': missing && m == months - 1 ? 0 : 120,
          'excluded_points': 0,
        },
      },
  ],
};
Future<void> openRange(
  WidgetTester tester,
  List<int> requests, {
  bool sparse = false,
  bool missing = false,
  bool empty = false,
  bool fail = false,
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
              features: {'driving_coverage': true, 'range_observations': true},
            ),
          ),
          200,
        );
      }
      if (r.url.path.endsWith('/range-observations')) {
        expect(r.url.queryParameters.containsKey('from'), isFalse);
        requests.add(int.parse(r.url.queryParameters['months']!));
        if (fail) return http.Response('{}', 503);
        return http.Response(
          jsonEncode(
            rangeResponse(
              sparse: sparse,
              empty: empty,
              missing: missing,
              months: int.parse(r.url.queryParameters['months']!),
            ),
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
    find.text('展开长期续航').hitTestable(),
    100,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('展开长期续航').hitTestable());
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
  testWidgets('长期续航经展开入口建立后，统计Tab隐藏不请求，可见时按30秒规则校验', (tester) async {
    // P15/U08交接：长期索引不再嵌入专题；先通过「展开长期续航」入口建立
    // 专题路由，再保留隐藏不请求、可见后校验及30秒 TTL 等业务断言。
    var now = DateTime.utc(2026, 10, 28, 11);
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
              statisticsInsightsMeta(features: {'range_observations': true}),
            ),
            200,
          );
        }
        if (r.url.path.endsWith('/range-observations')) {
          reads.add(r.url);
          return http.Response(
            jsonEncode(
              rangeResponse(
                months: int.parse(r.url.queryParameters['months']!),
              ),
            ),
            200,
          );
        }
        return http.Response(jsonEncode(statisticsInsightsFixture(r.url)), 200);
      }),
      () => now,
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await tester.tap(find.text('长期'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('展开长期续航'));
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
    now = now.add(const Duration(minutes: 5));
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(reads, isEmpty, reason: '统计Tab隐藏时，长期续航不得在后台请求');
    // 重新可见：经同一入口重建专题后按自己的30秒规则校验。
    await tester.tap(
      find.descendant(of: find.byType(MileafNavBar), matching: find.text('统计')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('展开长期续航'));
    await tester.pumpAndSettle();
    final afterReopen = reads.length;
    expect(afterReopen, greaterThan(0), reason: '重新可见后经入口重建专题并读取');
    now = now.add(const Duration(seconds: 10));
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(reads.length, afterReopen, reason: '30秒内的后台/前台恢复不重新读取');
    now = now.add(const Duration(minutes: 5));
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(reads.length, greaterThan(afterReopen), reason: '超过30秒后按自己的规则重新校验');
    expect(tester.takeException(), isNull);
  });

  testWidgets('续航专题读取6/12月服务端波动带和原值', (tester) async {
    final requests = <int>[];
    await openRange(tester, requests);
    // R25/P10：身份块术语标题与口径一句；结论卡月中位数与必要限定。
    expect(find.text('满电额定续航（估算）'), findsOneWidget);
    expect(find.text('独立本地月窗口，逐月估算额定续航'), findsOneWidget);
    expect(find.text('月中位数'), findsWidgets);
    expect(find.text('根据行程记录估算，不是电池健康检测'), findsOneWidget);

    expect(find.byKey(const Key('range-observation-chart')), findsOneWidget);
    expect(find.text('日常波动范围（P10–P90）'), findsOneWidget);
    expect(find.textContaining('432'), findsWidgets);
    await tester.tap(find.text('12个月'));
    await tester.pumpAndSettle();
    expect(requests.last, 12);
  });
  testWidgets('续航available但仅两有效日时明确稀疏，保留服务端点读', (tester) async {
    await openRange(tester, <int>[], sparse: true);
    // CP08：稀疏样本在有效天数事实旁给限定。
    expect(find.text('样本较少，仅供参考'), findsOneWidget);
    expect(find.textContaining('432'), findsWidgets);
    await scrollToStep(tester, MileafChartGrammar.previousStep);
    await tester.tap(stepButton(MileafChartGrammar.previousStep));
    await tester.pumpAndSettle();
    expect(find.textContaining('440'), findsWidgets);
  });
  testWidgets('缺月保留破折号及未结束标识，前后读取不补零', (tester) async {
    await openRange(tester, <int>[], missing: true);
    // 缺失月不补零：结论卡给缺失口径，读数头日期带未结束标识。
    expect(find.text('暂无有效月样本'), findsOneWidget);
    expect(find.textContaining('本月未结束'), findsOneWidget);
    await scrollToStep(tester, MileafChartGrammar.previousStep);
    await tester.tap(stepButton(MileafChartGrammar.previousStep));
    await tester.pumpAndSettle();
    expect(find.textContaining('440'), findsWidgets);
  });
  testWidgets('续航资源失败不清除统计承载并提供独立重试', (tester) async {
    await openRange(tester, <int>[], fail: true);
    // CP07：共享状态句「没能读取{对象}」+ 通用「重试」。
    expect(find.text('没能读取续航观察'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('长期续航'), findsOneWidget);
  });
}
