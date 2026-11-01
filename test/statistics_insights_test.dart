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
    expect(find.textContaining('本月 · 2026年10月'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, '总览'), findsNothing);
    expect(find.textContaining('187.5'), findsWidgets);

    expect(
      tester
          .getBottomRight(
            find.byKey(const ValueKey('statistics-insights-chart')),
          )
          .dy,
      lessThanOrEqualTo(736),
    );
    expect(find.textContaining('参照 20.0'), findsOneWidget);
    await tester.ensureVisible(find.text('节奏').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('节奏').first);
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.textContaining('Asia/Shanghai'), findsNothing);
    await tester.tap(find.text('数据说明'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Asia/Shanghai'), findsWidgets);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('本月 · 2026年10月'), findsOneWidget);
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
    expect(find.textContaining('187.5'), findsNothing);
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
        find.text('四个问题').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      if (scenario == 'normal') {
        expect(find.textContaining('较参照低 13 Wh/km'), findsOneWidget);
      } else if (scenario == 'zero') {
        expect(find.textContaining('参照为0'), findsOneWidget);
      } else {
        expect(find.textContaining('较参照'), findsNothing);
      }
      await tester.scrollUntilVisible(
        find.text('数据说明与更多').hitTestable(),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('数据说明与更多').hitTestable());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('参照原值与质量'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -160));
      await tester.pumpAndSettle();
      await tester.tap(find.text('参照原值与质量'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      expect(
        find.textContaining(
          scenario == 'zero' ? '参照配对净电耗 0 Wh/km' : '参照配对净电耗 200 Wh/km',
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
    expect(find.textContaining('187.5'), findsWidgets);
    final before = currentRequests;
    failReference = false;
    await tester.tap(find.text('重试参照'));
    await tester.pumpAndSettle();
    expect(currentRequests, before);
    expect(find.textContaining('参照读取失败'), findsNothing);
    expect(find.text('与参照同期持平'), findsOneWidget);
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
      find.text('四个问题').hitTestable(),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('187.5 Wh/km'), findsWidgets);
    expect(find.textContaining('较参照低 13 Wh/km'), findsOneWidget);
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
