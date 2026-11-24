import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/statistics_insights_fixture.dart';
import 'statistics_test.dart' show openStats, pickPeriod, fixture;

void main() {
  testWidgets('统计洞察使用能力声明展示总览与配对净电耗', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      if (r.url.path.endsWith('/meta')) {
        return http.Response(
          jsonEncode({
            'statistics_insights': {
              'contract_version': 'statistics-insights-v1',
              'minimum_server_version': '0.3.0',
              'features': {'driving_coverage': true},
            },
          }),
          200,
        );
      }
      if (r.url.queryParameters['kind'] == 'charging') {
        return fixture('charging-stats');
      }
      final d = statisticsInsightsFixture(r.url);
      return http.Response(jsonEncode(d), 200);
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    // P06 结论卡：期间名 + DF3 区间（不再出现「本月 · 2026年10月」这类月份串）。
    await tester.scrollUntilVisible(
      find.text('本月 10月1日\u201328日'),
      80,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('本月 10月1日\u201328日'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '总览'), findsNothing);
    // Spec mobile-v1 §11：电耗整数（原值 187.5 提供，上屏 188）。
    await tester.scrollUntilVisible(find.textContaining('188 Wh/km'), 160);
    expect(find.textContaining('188 Wh/km'), findsWidgets);

    expect(
      tester
          .getBottomRight(
            find.byKey(const ValueKey('statistics-insights-chart')),
          )
          .dy,
      lessThanOrEqualTo(736),
    );
    // R29/CP02：图例写参照的真实区间名，比较结论写成句子（「与…持平」）。
    expect(find.text('上月同期 9月1日\u201328日'), findsOneWidget);
    expect(find.text('与上月同期持平'), findsOneWidget);
    await tester.ensureVisible(find.text('节奏').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('节奏').first);
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.textContaining('Asia/Shanghai'), findsNothing);
    // D-AP12a-01：五个 W4 专题路由的宿主折叠已移除（区间进身份块、时区进
    // 页尾「关于这些数据」）；long 路由仍由宿主折叠承载「精确窗口与时区
    // 留在展开内容里」的同一口径（R30.4），在这里继续验证。
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('长期').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('长期').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('数据说明'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Asia/Shanghai'), findsWidgets);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('本月 10月1日\u201328日'),
      -160,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('本月 10月1日\u201328日'), findsOneWidget);
  });
  testWidgets('统计能力读取失败时仍可阅读旧统计', (tester) async {
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      if (r.url.path.endsWith('/meta')) return http.Response('{}', 503);
      return fixture('driving-stats');
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    expect(find.text('驾驶统计'), findsOneWidget);
  });
  testWidgets('已声明0.3能力但响应缺少契约字段时不展示伪成功', (tester) async {
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      if (r.url.path.endsWith('/meta')) {
        return http.Response(
          jsonEncode({
            'statistics_insights': {
              'contract_version': 'statistics-insights-v1',
              'minimum_server_version': '0.3.0',
              'features': {'driving_coverage': true},
            },
          }),
          200,
        );
      }
      if (r.url.queryParameters['kind'] == 'charging') {
        return fixture('charging-stats');
      }
      final body = statisticsInsightsFixture(r.url)..remove('as_of');
      return http.Response(jsonEncode(body), 200);
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    expect(find.textContaining('统计读取失败'), findsWidgets);
    expect(find.textContaining('188'), findsNothing);
  });
  for (final scenario in ['normal', 'quality', 'version', 'range', 'zero']) {
    testWidgets('同进度比较可核查且拒绝不一致口径 $scenario', (tester) async {
      final client = comparisonClient(
        sample: scenario == 'quality' ? 'insufficient_data' : 'adequate',
        version: scenario == 'version' ? 2 : 1,
        range: scenario == 'range' ? 'ideal' : 'rated',
        referenceValue: scenario == 'zero' ? 0 : 200,
      );
      await openStats(
        tester,
        client,
        () => DateTime.utc(2026, 10, 28, 11),
        () => 'Asia/Shanghai',
        statisticsInsights: true,
      );
      await tester.scrollUntilVisible(
        find.text('节奏').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      if (scenario == 'normal') {
        expect(find.textContaining('比上月同期低 13 Wh/km'), findsOneWidget);
      } else if (scenario == 'zero') {
        expect(find.textContaining('上月同期为 0，无法比较'), findsOneWidget);
      } else {
        expect(find.textContaining('比上月同期'), findsNothing);
      }
      // R30：说明迁入页尾「关于这些数据」，参照原值进「技术详情」。
      await tester.scrollUntilVisible(
        find.text('技术详情').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('技术详情').hitTestable());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining(
          scenario == 'zero' ? '对比有效行程电耗 0 Wh/km' : '对比有效行程电耗 200 Wh/km',
        ),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(
        find.textContaining(
          scenario == 'zero' ? '对比有效行程电耗 0 Wh/km' : '对比有效行程电耗 200 Wh/km',
        ),
        findsOneWidget,
      );
    });
  }
  testWidgets('驾驶覆盖能力关闭不隐藏其他已声明长期入口', (tester) async {
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      if (r.url.path.endsWith('/meta')) {
        return http.Response(
          jsonEncode(
            statisticsInsightsMeta(
              features: {'driving_coverage': false, 'range_observations': true},
            ),
          ),
          200,
        );
      }
      return fixture('driving-stats');
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    expect(find.text('长期'), findsOneWidget);
    expect(find.text('驾驶统计'), findsOneWidget);
  });
  testWidgets('全部原指标沿用当前统计选择的周区间', (tester) async {
    final queries = <Map<String, String>>[];
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      if (r.url.path.endsWith('/meta')) {
        return http.Response(jsonEncode(statisticsInsightsMeta()), 200);
      }
      queries.add(r.url.queryParameters);
      if (r.url.queryParameters['kind'] == 'charging') {
        return fixture('charging-stats');
      }
      return http.Response(jsonEncode(statisticsInsightsFixture(r.url)), 200);
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await pickPeriod(tester, '本周');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(TextButton, '全部指标').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.widgetWithText(TextButton, '全部指标'));
    await tester.pumpAndSettle();
    // C03: every metric entry is a topic, never a second equal-weight tab bar.
    expect(find.text('驾驶统计'), findsNothing);
    for (final topic in ['节奏', '能耗', '补能', '长期']) {
      expect(find.text(topic), findsWidgets);
    }
    await tester.tap(find.text('节奏').first);
    await tester.pumpAndSettle();
    expect(
      queries.any((q) => q['from'] == '2026-10-25T16:00:00.000Z'),
      isTrue,
      reason: '专题沿用本周区间',
    );
  });
  for (final c in [
    ('月末', '2026-05-31T11:00:00Z', 'Asia/Shanghai', '本月'),
    ('DST不存在', '2026-03-15T06:30:00Z', 'America/New_York', '本周'),
    ('DST重复', '2026-11-08T06:30:00Z', 'America/New_York', '本周'),
    ('半小时DST不存在', '2026-10-10T15:15:00Z', 'Australia/Lord_Howe', '本周'),
  ]) {
    testWidgets('同进度日历边界拒绝强行对齐 ${c.$1}', (tester) async {
      await openStats(
        tester,
        comparisonClient(),
        () => DateTime.parse(c.$2),
        () => c.$3,
        statisticsInsights: true,
      );
      if (c.$4 != '本月') await pickPeriod(tester, c.$4);
      expect(find.textContaining('日历进度无法对齐'), findsOneWidget);
      expect(find.textContaining('里程较参照'), findsNothing);
    });
  }
  testWidgets('参照失败可单独重试且保留本期成功结果', (tester) async {
    var failReference = true;
    var currentRequests = 0;
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      if (r.url.path.endsWith('/meta')) {
        return http.Response(jsonEncode(statisticsInsightsMeta()), 200);
      }
      if (r.url.queryParameters['kind'] == 'charging') {
        return fixture('charging-stats');
      }
      final ref = r.url.queryParameters['from']!.startsWith('2026-08-31');
      if (ref && failReference) return http.Response('{}', 503);
      if (!ref) currentRequests++;
      return http.Response(jsonEncode(statisticsInsightsFixture(r.url)), 200);
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    expect(find.textContaining('参照读取失败'), findsOneWidget);
    // Spec mobile-v1 §11：电耗整数（原值 187.5 提供，上屏 188）。
    await tester.scrollUntilVisible(find.textContaining('188 Wh/km'), 160);
    expect(find.textContaining('188 Wh/km'), findsWidgets);
    final before = currentRequests;
    failReference = false;
    // CP07：失败提示的动作统一写「重试」（原来按对象命名）。
    await tester.scrollUntilVisible(find.text('重试').hitTestable(), -100);
    await tester.tap(find.text('重试').hitTestable());
    await tester.pumpAndSettle();
    expect(currentRequests, before);
    expect(find.textContaining('参照读取失败'), findsNothing);
    expect(find.text('与上月同期持平'), findsOneWidget);
  });
  testWidgets('360宽200%深色可切换配对净电耗且原值完整可读', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });
    await openStats(
      tester,
      comparisonClient(),
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    await tester.scrollUntilVisible(
      find.text('能耗').hitTestable(),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('188 Wh/km'), findsWidgets, reason: '值与单位不再拆成两行');
    expect(find.textContaining('比上月同期低 13 Wh/km'), findsOneWidget);
  });

  testWidgets('驾驶汇总失败不遮挡其他专题与区间恢复操作', (tester) async {
    final client = MockClient((r) async {
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
      if (r.url.queryParameters['kind'] == 'charging') {
        return fixture('charging-stats');
      }
      return http.Response('{}', 503);
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 10, 28, 11),
      () => 'Asia/Shanghai',
      statisticsInsights: true,
    );
    expect(find.text('长期'), findsOneWidget);
    // The C 区间控件 stays usable while a metric read fails.
    expect(find.text('近7天'), findsOneWidget);
    expect(find.textContaining('统计读取失败'), findsOneWidget);
  });
}

http.Client comparisonClient({
  String sample = 'adequate',
  String range = 'rated',
  int version = 1,
  num referenceValue = 200,
}) => MockClient((r) async {
  if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
  if (r.url.path.endsWith('/summary')) return fixture('summary');
  if (r.url.path.endsWith('/meta')) {
    return http.Response(jsonEncode(statisticsInsightsMeta()), 200);
  }
  if (r.url.queryParameters['kind'] == 'charging') {
    return fixture('charging-stats');
  }
  final reference = r.url.queryParameters['from']!.startsWith('2026-08-31');
  return http.Response(
    jsonEncode(
      statisticsInsightsFixture(
        r.url,
        consumption: reference ? referenceValue : 187.5,
        energy: reference ? (referenceValue == 0 ? 0 : 4) : 3.75,
        sampleStatus: reference ? sample : 'adequate',
        rangeKind: reference ? range : 'rated',
        version: reference ? version : 1,
      ),
    ),
    200,
  );
});
