// AP12a 专题页合同测试（P07 节奏、P08 能耗、P09 补能）。
//
// 覆盖：专题骨架（R25：身份块、结论卡、主图卡、样本明细、关于这些数据）、
// P07 日历重做、P08 点图步进、P09 结论与文案对照表、CP07 状态句、
// 枚举人话标签（R30.4：snake_case 只进技术详情）与渲染树文案探针。
import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/tokens.dart';

import 'statistics_charging_test.dart' show statisticsChargingResponse;
import 'statistics_conditions_test.dart' show conditionsFixture, openConditions;
import 'statistics_test.dart' show openStats;
import 'statistics_usage_test.dart' show usageClient;
import 'ui_ux_u09a_test.dart' show dailyClient;
import 'support/copy_probe.dart';

/// 收集页面上全部可见文本（含富文本 span），用于渲染树文案探针。
List<String> visibleTexts(WidgetTester tester) {
  final element = tester.element(find.byType(Directionality).first);
  return collectedTexts(element);
}

final RegExp _snakeCase = RegExp(r'[a-z]+_[a-z0-9_]+');

void main() {
  group('P07 节奏', () {
    Future<void> openUsage(WidgetTester tester, http.Client client) async {
      await openStats(
        tester,
        client,
        () => DateTime.utc(2026, 10, 28, 11),
        () => 'Asia/Shanghai',
        statisticsInsights: true,
      );
      await tester.scrollUntilVisible(find.text('节奏').hitTestable(), 150);
      await tester.tap(find.text('节奏').first);
      await tester.pumpAndSettle();
    }

    testWidgets('身份块写出区间与统计口径，区间只出现一次', (tester) async {
      await openUsage(tester, usageClient([]));
      expect(find.text('用车节奏'), findsOneWidget);
      expect(find.textContaining('，按开始日期统计'), findsOneWidget);
      expect(find.textContaining('10月1日–28日'), findsOneWidget);
    });

    testWidgets('结论卡：用车天数 metricLg、一句上下文与必要限定', (tester) async {
      await openUsage(tester, dailyClient([]));
      final active = tester.widget<Text>(find.text('用车 5 天'));
      final number = (active.textSpan as TextSpan).children![1] as TextSpan;
      expect(number.style!.fontSize, MileafType.metricLgSize);
      expect(find.text('共 209 km，平均每个用车日 41.8 km'), findsOneWidget);
      expect(find.text('今天尚未结束'), findsOneWidget);
      expect(find.text('活跃 5 天'), findsNothing);
    });

    testWidgets('日历格子无描边框，格内日期 caption、数值 subheadline 600', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openUsage(tester, dailyClient([]));
      final date = find.text('10月1日');
      final dateStyle = tester.widget<Text>(date).style!;
      expect(dateStyle.fontSize, MileafType.captionSize);
      final valueStyle = tester
          .widget<Text>(
            find.descendant(
              of: find.ancestor(of: date, matching: find.byType(TextButton)),
              matching: find.text('0'),
            ),
          )
          .style!;
      expect(valueStyle.fontSize, MileafType.subheadlineSize);
      expect(valueStyle.fontWeight, MileafType.weightSemiBold);
      final button = find.ancestor(of: date, matching: find.byType(TextButton));
      final material = tester.widget<Material>(
        find.descendant(of: button, matching: find.byType(Material)).first,
      );
      final shape = material.shape! as OutlinedBorder;
      // 未选中格无可见描边框（描边与档位填充同色，只为完整命中区）；
      // 填充加纹理承担分档。
      expect(shape.side.width, lessThan(2));
      // 当天下钻沿原语义：点按日期打开当天证据，返回后选中环保留。
      await tester.tap(date);
      await tester.pumpAndSettle();
      expect(find.text('10月1日的行程'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      final selectedMaterial = tester.widget<Material>(
        find.descendant(of: button, matching: find.byType(Material)).first,
      );
      final selectedShape = selectedMaterial.shape! as OutlinedBorder;
      expect(selectedShape.side.width, 2);
      expect(
        selectedShape.side.color,
        MileafColors.of(tester.element(date)).accent,
      );
    });

    testWidgets('样本明细改用对照表词，平均速度不再写全称', (tester) async {
      await openUsage(tester, usageClient([]));
      expect(find.text('样本明细'), findsOneWidget);
      expect(find.text('证据'), findsNothing);
      expect(find.text('平均速度'), findsOneWidget);
      expect(find.text('平均记录速度'), findsNothing);
    });

    testWidgets('页尾关于这些数据五类，算法与快照只进技术详情', (tester) async {
      await openUsage(tester, usageClient([]));
      expect(find.text('关于这些数据'), findsOneWidget);
      for (final label in ['口径与估算', '记录与缺失', '时间与时区', '来源与生成时间', '技术详情']) {
        expect(find.text(label), findsOneWidget);
      }
      // 折叠态不外露 snake_case（R30.4）。
      expect(
        visibleTexts(tester).where((text) => _snakeCase.hasMatch(text)),
        isEmpty,
      );
    });

    testWidgets('读取失败按 CP07 生成并可重试，可见按钮统一「重试」', (tester) async {
      final base = usageClient([]);
      var reads = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/driving-analysis')) {
          reads++;
          if (reads == 1) return http.Response('{}', 503);
          return base.get(request.url);
        }
        return base.get(request.url);
      });
      await openUsage(tester, client);
      expect(find.text('没能读取用车节奏'), findsOneWidget);
      final semantics = tester.ensureSemantics();
      try {
        final retry = find.bySemanticsLabel('重试用车节奏');
        expect(retry, findsOneWidget);
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(find.text('没能读取用车节奏'), findsNothing);
        expect(find.text('用车 12 天'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('有旧数据时失败写明快照时刻，技术原值不回主界面', (tester) async {
      final base = usageClient([]);
      var analysisReads = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/driving-analysis')) {
          analysisReads++;
          if (analysisReads == 1) {
            final body = jsonDecode(
              (await base.get(request.url)).body,
            ) as Map<String, dynamic>;
            body['as_of'] = '2026-10-28T09:00:00Z';
            return http.Response(jsonEncode(body), 200);
          }
          return http.Response('{}', 503);
        }
        if (request.url.path.endsWith('/stats') &&
            request.url.queryParameters['kind'] == 'driving') {
          return http.Response('{}', 503);
        }
        return base.get(request.url);
      });
      await openUsage(tester, client);
      // 每日里程一直失败：重试会带着旧摘要强制刷新，读 2 失败但保留读 1。
      expect(find.text('没能读取每日里程'), findsOneWidget);
      final semantics = tester.ensureSemantics();
      try {
        final retry = find.bySemanticsLabel('重试每日里程');
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(find.textContaining('没能更新，显示的是'), findsOneWidget);
        expect(find.textContaining('17:00'), findsOneWidget);
        // as_of 原值（RFC3339）不进主界面。
        expect(
          visibleTexts(tester).where((t) => t.contains('2026-10-28T')),
          isEmpty,
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('渲染树无「点按读值」类提示且无 snake_case 界面文案', (tester) async {
      await openUsage(tester, usageClient([]));
      final texts = visibleTexts(tester);
      expect(texts.where((text) => text.contains('点按读值')), isEmpty);
      expect(texts.where((text) => text.contains('·')), isEmpty);
      expect(texts.where((text) => _snakeCase.hasMatch(text)), isEmpty);
    });
  });

  group('P08 能耗', () {
    Future<void> openEnergy(WidgetTester tester) async {
      final base = usageClient([]);
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/driving-analysis') &&
            request.url.queryParameters['view'] == 'conditions') {
          return http.Response(jsonEncode(conditionsFixture()), 200);
        }
        return base.get(request.url);
      });
      await openStats(
        tester,
        client,
        () => DateTime.utc(2026, 10, 28, 11),
        () => 'Asia/Shanghai',
        statisticsInsights: true,
      );
      await openConditions(tester);
    }

    testWidgets('温度组结论与限定按对照表，组标签用空格分隔', (tester) async {
      await openEnergy(tester);
      expect(find.text('不同温度下的电耗'), findsOneWidget);
      expect(find.text('温度下的用车能耗'), findsNothing);
      expect(find.textContaining('−5 至 0°C'), findsWidgets);
      expect(find.textContaining('只反映相关性'), findsOneWidget);
    });

    testWidgets('前后操作是圆形步进圆钮，两端禁用且与点图同步', (tester) async {
      await openEnergy(tester);
      final previous = find.byTooltip('上一组');
      final next = find.byTooltip('下一组');
      expect(previous, findsOneWidget);
      expect(next, findsOneWidget);
      expect(
        tester
            .widget<MileafIconButton>(
              find.ancestor(
                of: previous,
                matching: find.byType(MileafIconButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.textContaining('0 至 5°C'), findsWidgets);
      expect(
        tester
            .widget<MileafIconButton>(
              find.ancestor(
                of: previous,
                matching: find.byType(MileafIconButton),
              ),
            )
            .onPressed,
        isNotNull,
      );
      // 夹具共三组：走到最后一步后「下一组」禁用。
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.textContaining('5 至 10°C'), findsWidgets);
      expect(
        tester
            .widget<MileafIconButton>(
              find.ancestor(of: next, matching: find.byType(MileafIconButton)),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('上一温度组'), findsNothing);
      expect(find.text('下一温度组'), findsNothing);
    });

    testWidgets('证据下钻入口改为「查看这些行程」', (tester) async {
      await openEnergy(tester);
      expect(find.text('查看这些行程'), findsOneWidget);
      expect(find.text('查看该温度组行程'), findsNothing);
    });
  });

  group('P09 补能', () {
    Future<void> openChargingTopic(WidgetTester tester) async {
      await openStats(
        tester,
        MockClient((request) async => statisticsChargingResponse(request)),
        () => DateTime.utc(2026, 3, 30, 12),
        () => 'UTC',
        statisticsInsights: true,
      );
      await tester.scrollUntilVisible(
        find.text('补能').hitTestable(),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('补能'));
      await tester.pumpAndSettle();
    }

    testWidgets('结论卡按对照表：已记录费用、覆盖一句与充入均价', (tester) async {
      await openChargingTopic(tester);
      expect(find.text('充电费用'), findsOneWidget);
      expect(find.textContaining('按结束日期统计，仅含已完成的充电'), findsOneWidget);
      expect(find.textContaining('8 次中 2 次有费用'), findsOneWidget);
      expect(find.textContaining('充入均价'), findsOneWidget);
      expect(find.text('已知支出 · 覆盖同时看'), findsNothing);
      expect(find.textContaining('费用覆盖'), findsNothing);
    });

    testWidgets('主图是每日充电量，完整口径在图标题与读屏', (tester) async {
      await openChargingTopic(tester);
      expect(find.text('每日充电量'), findsOneWidget);
      expect(find.textContaining('入电量走势'), findsNothing);
      final labels = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .map((s) => s.properties.label)
          .whereType<String>()
          .where((label) => label.startsWith('每日充电量图表'))
          .toList();
      expect(labels, isNotEmpty);
      expect(labels.first, contains('按结束日'));
    });

    testWidgets('充电方式与地点按对照表命名，分类时长按 CP03 分级', (tester) async {
      await openChargingTopic(tester);
      expect(find.text('充电方式'), findsOneWidget);
      expect(find.text('充电地点'), findsOneWidget);
      expect(find.text('查看 AC 充电'), findsOneWidget);
      expect(find.text('查看 DC 充电'), findsOneWidget);
      expect(find.text('查看未知类型'), findsOneWidget);
      expect(find.text('查看这段时间的充电'), findsOneWidget);
      // CP03：分类记录时长按分级写法，不再是小数分钟拼接。
      expect(find.textContaining(RegExp(r'AC记录')), findsNothing);
    });
  });
}
