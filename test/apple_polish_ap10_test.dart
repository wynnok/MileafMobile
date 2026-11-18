import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mileaf/src/charging_page.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/tokens.dart';

import 'charging_expansion_test.dart' show chargingStatsV2, expansionResponse;
import 'charging_test.dart' show app, chargingFixture, jsonResponse, navTab;
import 'support/c_fixture.dart';

/// AP10（P03 充电账本 / P05 充电详情）：P03 卡片化、共享日期区间弹层、胶囊
/// 下拉、R30「关于这些数据」与 CP02/CP03/CP07/CP09 文案。S01–S08、Key、回调、
/// 请求类型与参数均不变；业务断言沿用既有口径。
void main() {
  Future<void> openCharging(WidgetTester tester, MockClient client) async {
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(navTab('充电'));
    await tester.pumpAndSettle();
  }

  /// 充电页自身的滚动：四个目的地在 IndexedStack 里都挂着，find.text 会命中
  /// 离屏页面，所以滚动与命中都限定在 ChargingPage 的滚动条内；ListView 惰性
  /// 销毁滚出视口的内容，因此以「进入组件树」为准，再 ensureVisible 到可视。
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    final scroll = find
        .descendant(
          of: find.byType(ChargingPage),
          matching: find.byType(Scrollable),
        )
        .first;
    var steps = 0;
    while (finder.evaluate().isEmpty && steps++ < 20) {
      await tester.drag(scroll, const Offset(0, -220));
      await tester.pumpAndSettle();
    }
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder.first);
      await tester.pumpAndSettle();
    }
  }

  group('P03 账目卡与每日充电卡', () {
    testWidgets('账目卡：已记录费用 metricLg + 覆盖句 + 三格充入电量/充入均价/充电时长', (tester) async {
      await openCharging(tester, MockClient((r) async => expansionResponse(r)));
      expect(find.text('已记录费用'), findsOneWidget);
      expect(find.textContaining('已知充电费用'), findsNothing);
      expect(find.textContaining('费用有记录'), findsNothing);
      expect(find.textContaining('8 次中 2 次有费用，对应充入'), findsOneWidget);
      // 三格在图后的格卡里（见下），顶部只有焦点值与覆盖句。
      expect(find.text('补入电池'), findsNothing);
      expect(find.text('记录时长'), findsNothing);
      // 账目卡是一张模块卡：标签在卡内，卡片是 surface 容器。
      final card = find.ancestor(
        of: find.text('已记录费用'),
        matching: find.byType(MileafModuleCard),
      );
      expect(card, findsOneWidget);
      // CP08：充入均价的口径限定语就近出现（滚到三格后再断言）。
      await scrollTo(tester, find.text('充入均价'));
      expect(find.textContaining('按充入电池的电量计'), findsOneWidget);
      // §6 阶梯第 4 步：三格在每日充电图之后的独立格卡里（最近充电之后）。
      final cellsCard = find.ancestor(
        of: find.text('充入电量'),
        matching: find.byType(MileafModuleCard),
      );
      expect(cellsCard, findsOneWidget);
      expect(
        find.descendant(of: cellsCard, matching: find.text('充入均价')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cellsCard, matching: find.text('充电时长')),
        findsOneWidget,
      );
      // CP03：125 分钟写成「2 小时 5 分钟」，不再写 5h05 一类紧凑串。
      expect(find.text('2 小时 5 分钟'), findsOneWidget);
    });

    testWidgets('每日充电卡：88 高紧凑读数行，日期走共享格式化器', (tester) async {
      await openCharging(tester, MockClient((r) async => expansionResponse(r)));
      expect(find.text('每日补能'), findsNothing);
      final chart = find.descendant(
        of: find.byType(ChargingPage),
        matching: find.byType(StemChart),
      );
      await scrollTo(tester, chart);
      final stem = tester.widget<StemChart>(chart.first);
      expect(stem.title, '每日充电');
      expect(stem.height, MileafSpace.rhythmHeight);
      expect(stem.compactReadout, isTrue);
      expect(stem.readout!(0), matches(RegExp(r'^\d+月\d+日，')));
      expect(stem.readout!(0), isNot(contains('/')));
    });

    testWidgets('空期间：每日充电卡保留空态句，不画全零图', (tester) async {
      await openCharging(
        tester,
        MockClient((request) async {
          if (request.url.path.endsWith('/stats') &&
              request.url.queryParameters['kind'] == 'charging') {
            final body = chargingStatsV2();
            body['buckets'] = <Object>[];
            final totals = body['totals'] as Map<String, dynamic>;
            totals['sessions'] = 0;
            totals['energy_known_sessions'] = 0;
            totals['cost_known_sessions'] = 0;
            totals['duration_known_sessions'] = 0;
            totals['cost'] = null;
            totals['energy_added_kwh'] = 0;
            totals['duration_min_total'] = 0;
            return jsonResponse(body);
          }
          return expansionResponse(request);
        }),
      );
      await scrollTo(
        tester,
        find.descendant(
          of: find.byType(ChargingPage),
          matching: find.text('每日充电'),
        ),
      );
      // 空态句在本票的每日充电卡里；充电方式卡的空态结论是另一句（同字面），
      // 所以限定在「每日充电」所在的模块卡内断言。
      final trendCard = find.ancestor(
        of: find.text('每日充电'),
        matching: find.byType(MileafModuleCard),
      );
      expect(
        find.descendant(
          of: trendCard,
          matching: find.textContaining('这段时间没有充电'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ChargingPage),
          matching: find.byType(StemChart),
        ),
        findsNothing,
      );
    });
  });

  group('P03 进行中卡与记录行', () {
    testWidgets('进行中：一张模块卡内「正在充电 + 已充入句」与进行中胶囊', (tester) async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/summary')) {
          final body = cSummary();
          (body['state'] as Map)['value'] = 'charging';
          return jsonResponse(body);
        }
        return expansionResponse(request);
      });
      await openCharging(tester, client);
      final card = find.ancestor(
        of: find.textContaining('正在充电'),
        matching: find.byType(MileafModuleCard),
      );
      expect(card, findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.textContaining('已充入')),
        findsOneWidget,
      );
      expect(find.textContaining('结束后计入统计'), findsOneWidget);
      expect(find.textContaining('不计入已完成统计'), findsNothing);
    });

    testWidgets('记录行：DF 元信息、AC/DC 独立标签、充入/电网用电结果行', (tester) async {
      await openCharging(tester, MockClient((r) async => expansionResponse(r)));
      final row = find.byKey(const ValueKey('charge-9'));
      await tester.scrollUntilVisible(row.hitTestable(), 120);
      // CP04：3月29日 07:10，34 分钟（DF5 + CP03 时长），不再是 ISO 串。
      expect(
        find.descendant(
          of: row,
          matching: find.textContaining(RegExp(r'\d+月\d+日 \d{2}:\d{2}，')),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('2026-03-29 07:10'), findsNothing);
      // CP02：结果行写「充入」「电网用电」；类型是独立小标签。
      expect(
        find.descendant(of: row, matching: find.textContaining('充入')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.textContaining('电网用电')),
        findsOneWidget,
      );
      // 夹具里 charge-9 是 AC；类型是独立小标签。
      expect(
        find.descendant(of: row, matching: find.text('AC')),
        findsOneWidget,
      );
      expect(find.textContaining('充电类型'), findsNothing);
      // 围栏与地址不再出现在记录行（记录信息在详情的关于这些数据里）。
      expect(find.textContaining('围栏：'), findsNothing);
      expect(find.textContaining('地址：'), findsNothing);
    });
  });

  group('P03 充电方式、充电地点与页尾', () {
    testWidgets('充电方式：结论一句 + 类型未知分行，分母口径进脚注', (tester) async {
      await openCharging(tester, MockClient((r) async => expansionResponse(r)));
      await tester.scrollUntilVisible(find.text('充电方式').hitTestable(), 300);
      expect(find.text('我的补能方式'), findsNothing);
      // CP09：结论句不再用「·」拼接类型未知。
      expect(find.text('AC 更多，DC 占 14.29%'), findsOneWidget);
      expect(find.text('类型未知 20 kWh'), findsOneWidget);
      expect(find.textContaining('14.29% ·'), findsNothing);
      expect(find.textContaining('只计已知类型的充电，8 次中 7 次类型已知'), findsOneWidget);
      expect(find.textContaining('DC 占已知分类能量'), findsNothing);
      // CP03：分类时长按共享分级（90 分钟 → 1 小时 30 分钟）。
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('charging-method-column-AC')),
          matching: find.text('1 小时 30 分钟'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('充电地点：分组卡承载地点行，校验时间移入关于这些数据', (tester) async {
      await openCharging(tester, MockClient((r) async => expansionResponse(r)));
      await tester.scrollUntilVisible(find.text('充电地点').hitTestable(), 300);
      expect(find.text('地点账目'), findsNothing);
      expect(find.textContaining('地点校验时间'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(MileafGroupCard),
          matching: find.textContaining('家 · 地库'),
        ),
        findsWidgets,
      );
      // CP02：地点行内不再写「有效入电均价」。
      expect(find.textContaining('有效入电均价'), findsNothing);
    });

    testWidgets('页尾：关于这些数据分组替代 ExpansionTile', (tester) async {
      await openCharging(tester, MockClient((r) async => expansionResponse(r)));
      Finder inPage(Finder f) =>
          find.descendant(of: find.byType(ChargingPage), matching: f);
      await scrollTo(tester, inPage(find.text('关于这些数据')));
      expect(inPage(find.text('数据说明')), findsNothing);
      expect(inPage(find.byType(ExpansionTile)), findsNothing);
      await scrollTo(tester, inPage(find.text('口径与估算')));
      await tester.tap(inPage(find.text('口径与估算')).hitTestable());
      await tester.pumpAndSettle();
      expect(find.textContaining('按结束时间归期'), findsOneWidget);
      expect(find.textContaining('不等于等待时间'), findsOneWidget);
      expect(find.textContaining('构成环只含 AC / DC'), findsOneWidget);
      await scrollTo(tester, inPage(find.text('来源与生成时间')));
      await tester.tap(inPage(find.text('来源与生成时间')).hitTestable());
      await tester.pumpAndSettle();
      // CP02/DF8：校验时间改「数据生成于」，精确时间只在说明层出现。
      expect(
        find.textContaining(
          RegExp(r'数据生成于 \d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'),
        ),
        findsOneWidget,
      );
    });
  });

  group('P03 共享日期区间弹层与全部记录模式', () {
    testWidgets('自定义日期走 MileafDateRangeSheet，原校验与回调保留', (tester) async {
      final requests = <Uri>[];
      await openCharging(
        tester,
        MockClient((request) async {
          if (request.url.path.endsWith('/charging-sessions')) {
            requests.add(request.url);
          }
          return expansionResponse(request);
        }),
      );
      await tester.tap(find.text('自定义'));
      await tester.pumpAndSettle();
      expect(find.text('选择日期'), findsOneWidget);
      expect(find.text('包含结束当天'), findsOneWidget);
      // R27：键盘路径保留——「改为输入」切到文本输入。
      await tester.tap(find.text('改为输入'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, '开始'),
        '2026-03-29',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '结束'),
        '2026-03-31',
      );
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      // 原校验：不选择未来日期。
      expect(find.textContaining('结束日期不能晚于今天'), findsOneWidget);
      final before = requests.length;
      await tester.enterText(
        find.widgetWithText(TextField, '结束'),
        '2026-03-29',
      );
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      expect(requests.length, greaterThan(before));
      final session = requests.lastWhere(
        (url) =>
            url.path.endsWith('/charging-sessions') &&
            url.queryParameters['time_basis'] != 'started_at',
      );
      // 归期沿原语义：结束日 +1 天为开区间上界（不早于 now 时截到 now）。
      expect(session.queryParameters['from'], '2026-03-29T00:00:00.000Z');
      expect(session.queryParameters['to'], '2026-03-30T00:00:00.000Z');
      expect(find.text('恢复近 30 天'), findsOneWidget);
    });

    testWidgets('全部记录：胶囊下拉（类型/费用/排序）+ 匹配数脚注 + 结束提示', (tester) async {
      await openCharging(tester, MockClient((r) async => expansionResponse(r)));
      // ui_ux_u06 同款入口滚动：小步拖拽 + 命中检查，避免一次越过惰性构建点。
      final entry = find.text('查看全部').hitTestable();
      final pageScroll = find
          .descendant(
            of: find.byType(ChargingPage),
            matching: find.byType(Scrollable),
          )
          .first;
      var steps = 0;
      while (entry.evaluate().isEmpty && steps++ < 14) {
        await tester.drag(pageScroll, const Offset(0, -160));
        await tester.pumpAndSettle();
      }
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.text('全部充电记录'), findsOneWidget);
      expect(find.byType(DropdownButton<dynamic>), findsNothing);
      expect(find.byType(MileafPullDown<String>), findsNWidgets(3));
      // 记录行的费用读值格语义也以「费用」开头，下拉断言收进胶囊控件内。
      Finder pullDownLabel(String prefix) => find.descendant(
        of: find.byType(MileafPullDown<String>),
        matching: find.bySemanticsLabel(RegExp('^' + prefix + ' ')),
      );
      expect(pullDownLabel('类型'), findsOneWidget);
      expect(pullDownLabel('费用'), findsOneWidget);
      expect(pullDownLabel('排序'), findsOneWidget);
      expect(find.textContaining('匹配'), findsOneWidget);
      // 选 AC：请求带 charging_type=ac，条件行以分项文字呈现（不用「·」串）。
      await tester.tap(pullDownLabel('类型').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('AC').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('类型：AC'), findsOneWidget);
      expect(find.text('已到最后一条'), findsNothing);
    });
  });

  group('P03 旧契约与错误文案', () {
    testWidgets('旧契约：摘要走 CP02 术语，无费用覆盖与充入均价', (tester) async {
      await openCharging(
        tester,
        MockClient(
          (r) async => r.url.path.endsWith('/meta')
              ? jsonResponse({'version': '0.1.0'})
              : expansionResponse(r),
        ),
      );
      expect(find.textContaining('已记录费用'), findsOneWidget);
      expect(find.textContaining('充入电量'), findsOneWidget);
      expect(find.textContaining('已完成'), findsOneWidget);
      expect(find.textContaining('当前服务未提供费用覆盖和充入均价'), findsOneWidget);
      expect(find.textContaining('有效入电均价'), findsNothing);
    });

    testWidgets('游标不前进：分页失败走共享构造函数，重试后显示全部', (tester) async {
      var recover = false;
      await openCharging(
        tester,
        MockClient(
          (r) async => r.url.path.endsWith('/meta')
              ? jsonResponse({'version': '0.1.0'})
              : r.url.path.endsWith('/charging-sessions')
              ? () {
                  final body = chargingFixture();
                  body['items'] = [body['items'][0]];
                  body['next_cursor'] = recover ? null : 'same-cursor';
                  return jsonResponse(body);
                }()
              : expansionResponse(r),
        ),
      );
      await tester.scrollUntilVisible(find.text('加载更多充电').hitTestable(), 300);
      await tester.tap(find.text('加载更多充电'));
      await tester.pumpAndSettle();
      expect(find.textContaining('没能加载更多充电，已保留当前列表'), findsOneWidget);
      expect(find.textContaining('分页游标未前进'), findsNothing);
      recover = true;
      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.textContaining('没能加载更多充电'), findsNothing);
      expect(find.text('已显示全部充电'), findsOneWidget);
    });

    testWidgets('能力不支持走共享构造函数', (tester) async {
      await openCharging(
        tester,
        MockClient(
          (r) async => r.url.path.endsWith('/meta')
              ? jsonResponse({'version': '0.1.0'})
              : expansionResponse(r),
        ),
      );
      expect(find.textContaining('当前站点暂不支持'), findsOneWidget);
    });
  });
}
