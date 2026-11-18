// AP09 行程列表、行程详情与地图呈现（P02/P04）行为测试。
//
// 接缝：公开页面（MileafApp + 可控 HTTP）、页面路由与回调、共享格式化器。
// 每个用例都读用户能看到的结果，不读私有字段。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/tokens.dart';
import 'package:mileaf/src/map/map_consent.dart';
import 'package:mileaf/src/map/map_panel.dart';
import 'package:mileaf/src/workspace.dart';

import 'drive_detail_test.dart' show fixture, openDetail;
import 'drives_test.dart' show jsonResponse, openDrives;
import 'support/fake_map_platform.dart';

void main() {
  group('P02 行程列表', () {
    testWidgets('自定义日期改用共享日期区间弹层：默认近30天、含首尾、校验由页面注入', (tester) async {
      final queries = <Map<String, String>>[];
      await openDrives(
        tester,
        (request) async {
          queries.add(request.url.queryParameters);
          return jsonResponse('{"items":[],"next_cursor":null}');
        },
        now: () => DateTime.utc(2026, 3, 30, 12),
        calendar: () async => CalendarContext('Asia/Shanghai'),
      );
      await tester.tap(find.text('自定义'));
      await tester.pumpAndSettle();
      // R27 共享弹层：两行开始/结束、脚注「包含结束当天」与键盘输入路径。
      expect(find.text('选择日期'), findsOneWidget);
      expect(find.text('包含结束当天'), findsOneWidget);
      expect(find.text('开始'), findsOneWidget);
      expect(find.text('结束'), findsOneWidget);
      // 默认区间沿用页面原来的近 30 天窗口（今天 - 29 天 … 今天）。
      expect(find.text('3月1日'), findsOneWidget);
      expect(find.text('3月30日'), findsOneWidget);
      await tester.tap(find.text('改为输入'));
      await tester.pumpAndSettle();
      final start = find.byKey(const ValueKey('date-range-start-input'));
      final end = find.byKey(const ValueKey('date-range-end-input'));
      // 校验由调用方注入：结束晚于今天被拒绝，弹层保持打开并给一句原因。
      await tester.enterText(start, '2024-03-09');
      await tester.enterText(end, '2026-04-10');
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      expect(find.text('结束日期不能晚于今天'), findsOneWidget);
      // 开始晚于结束也被拒绝。
      await tester.enterText(start, '2024-03-11');
      await tester.enterText(end, '2024-03-10');
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      expect(find.text('开始日期不能晚于结束日期'), findsOneWidget);
      // 合法区间：与原 showDateRangePicker 相同，含首尾两天。
      await tester.enterText(start, '2024-03-09');
      await tester.tap(find.text('应用'));
      await tester.pumpAndSettle();
      expect(queries.last['from'], '2024-03-08T16:00:00.000Z');
      expect(queries.last['to'], '2024-03-10T16:00:00.000Z');
      expect(find.text('自定义区间'), findsOneWidget);
      expect(find.text('3月9日\u201310日'), findsOneWidget);
    });
  });

  group('P02 共享状态句', () {
    testWidgets('空期间用共享空态句，不写「还没有」', (tester) async {
      await openDrives(
        tester,
        (_) async => jsonResponse('{"items":[],"next_cursor":null}'),
      );
      expect(find.text('这段时间没有行程'), findsOneWidget);
      expect(find.text('还没有行程'), findsNothing);
      expect(find.text('正在加载行程'), findsNothing);
    });

    testWidgets('刷新失败有旧数据：共享状态句说明显示的是哪一刻的数据', (tester) async {
      var failing = false;
      await openDrives(tester, (_) async {
        if (failing) return http.Response('', 503);
        return jsonResponse(
          File('test/fixtures/drives.json').readAsStringSync(),
        );
      });
      failing = true;
      await tester.tap(find.byTooltip('刷新行程'));
      await tester.pumpAndSettle();
      expect(find.textContaining('没能更新，显示的是'), findsOneWidget);
      expect(find.textContaining('保留上次快照'), findsNothing);
    });
  });

  group('P04 行程详情', () {
    testWidgets('顶部只有一个刷新入口，一次点按依次刷新明细与曲线', (tester) async {
      var detailReads = 0, seriesReads = 0;
      await openDetail(tester, (request) async {
        if (request.url.path.endsWith('/series')) {
          seriesReads++;
          return jsonResponse(jsonEncode(fixture('drive-series')));
        }
        detailReads++;
        return jsonResponse(jsonEncode(fixture('drive-detail')));
      });
      final detailBefore = detailReads, seriesBefore = seriesReads;
      expect(find.byTooltip('刷新行程详情'), findsOneWidget);
      expect(find.byTooltip('刷新行程明细'), findsNothing);
      expect(find.byTooltip('刷新行程采样'), findsNothing);
      await tester.tap(find.byTooltip('刷新行程详情'));
      await tester.pumpAndSettle();
      expect(detailReads - detailBefore, 1);
      expect(seriesReads - seriesBefore, 1);
    });

    testWidgets('身份块：路线 + 一行日期与起止时间；地图卡 220 圆角 20 与路线示意脚注', (tester) async {
      final consent = MapConsentController();
      await consent.grant();
      final platform = FakeMapPlatform();
      await openDetail(
        tester,
        (request) async => jsonResponse(
          jsonEncode(
            fixture(
              request.url.path.endsWith('/series')
                  ? 'drive-series'
                  : 'drive-detail',
            ),
          ),
        ),
        mapConsent: consent,
        mapPlatform: platform,
      );
      platform.completeLoad();
      await tester.pumpAndSettle();
      expect(find.text('未知地点 → 未知地点'), findsWidgets);
      // CP04/DF1 + DF4：一行日期与起止时间，用共享格式化器。
      expect(find.text('3月15日 16:00\u201318:00'), findsOneWidget);
      final panel = tester.widget<MapPanel>(find.byType(MapPanel));
      expect(panel.height, MapPanel.detailHeight);
      expect(panel.borderRadius, BorderRadius.circular(MileafRadius.lg));
      expect(find.byTooltip('查看完整地图'), findsWidgets);
      // CP09：图下脚注写「路线示意，非导航路线」，不再用「·」拼接。
      expect(find.text('路线示意，非导航路线'), findsOneWidget);
      expect(find.text('路线示意 · 非导航'), findsNothing);
      expect(find.text('行程地图'), findsNothing);
    });

    testWidgets('三项关键值用 metricSm，按 R21.5 重排', (tester) async {
      await openDetail(
        tester,
        (request) async => jsonResponse(
          jsonEncode(
            fixture(
              request.url.path.endsWith('/series')
                  ? 'drive-series'
                  : 'drive-detail',
            ),
          ),
        ),
      );
      for (final label in ['距离 20.0 km', '时长 120 分钟', '电耗 188 Wh/km']) {
        await tester.scrollUntilVisible(find.bySemanticsLabel(label), 160);
        expect(find.bySemanticsLabel(label), findsOneWidget);
      }
      final scales = tester
          .widgetList<MetricBlock>(
            find.descendant(
              of: find.byType(MetricGrid),
              matching: find.byType(MetricBlock),
            ),
          )
          .map((block) => block.scale)
          .toList();
      expect(scales, everyElement(MetricValueScale.metricSm));
      expect(find.text('净电耗 188 Wh/km'), findsNothing);
    });

    testWidgets('行驶过程卡：标题、分段、完整读数头与步进、绘图区 200', (tester) async {
      await openDetail(
        tester,
        (request) async => jsonResponse(
          jsonEncode(
            fixture(
              request.url.path.endsWith('/series')
                  ? 'drive-series'
                  : 'drive-detail',
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('行驶过程').hitTestable(), 160);
      expect(find.text('行驶过程'), findsOneWidget);
      for (final segment in ['速度', '电量', '海拔']) {
        expect(find.text(segment), findsWidgets);
      }
      final chart = tester.widget<TimeSeriesChart>(
        find.byType(TimeSeriesChart),
      );
      expect(chart.height, MileafSpace.detailChartHeight);
      expect(chart.readoutScale, ChartReadoutScale.detail);
      // R29 完整读数头：日期/时间行 + 数值行，步进圆钮在读数头尾部。
      expect(
        find.descendant(
          of: find.byType(MileafChartReadout),
          matching: find.text('16:00'),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('上一个数据点'), findsOneWidget);
      expect(find.bySemanticsLabel('下一个数据点'), findsOneWidget);
      // 提示句删除，图表语义提示保留。
      expect(find.text('点按图形读值'), findsNothing);
    });

    testWidgets('「同时查看电量」折叠行：展开就地长出第二张电量图', (tester) async {
      await openDetail(
        tester,
        (request) async => jsonResponse(
          jsonEncode(
            fixture(
              request.url.path.endsWith('/series')
                  ? 'drive-series'
                  : 'drive-detail',
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('同时查看电量').hitTestable(), 200);
      expect(find.text('对照电量'), findsNothing);
      expect(find.byKey(const ValueKey('paired-sample-chart')), findsNothing);
      await tester.tap(find.text('同时查看电量').hitTestable());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('paired-sample-chart')),
        160,
      );
      expect(find.byKey(const ValueKey('paired-sample-chart')), findsOneWidget);
    });

    testWidgets('电量变化卡：区间与百分点差，未知端点只出「—」', (tester) async {
      await openDetail(
        tester,
        (request) async => jsonResponse(
          jsonEncode(
            fixture(
              request.url.path.endsWith('/series')
                  ? 'drive-series'
                  : 'drive-detail',
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('电量变化').hitTestable(), 200);
      expect(find.text('电量变化'), findsOneWidget);
      expect(find.text('行程电量区间'), findsNothing);
      expect(find.text('出发 70%'), findsOneWidget);
      expect(find.text('到达 70%'), findsOneWidget);
      expect(find.text('电量下降 0 个百分点'), findsOneWidget);
      expect(find.text('电量增加 0 个百分点'), findsNothing);
    });

    testWidgets('与近 30 天相比：本次与近 30 天两个值 + 一句共享限定', (tester) async {
      await openDetail(
        tester,
        (request) async => jsonResponse(
          jsonEncode(
            fixture(
              request.url.path.endsWith('/series')
                  ? 'drive-series'
                  : 'drive-detail',
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('与近 30 天相比').hitTestable(),
        220,
      );
      expect(find.bySemanticsLabel('本次 188 Wh/km'), findsOneWidget);
      expect(find.bySemanticsLabel('近 30 天 188 Wh/km'), findsOneWidget);
      expect(find.text('均为服务器估算；路线、天气和交通不同，不代表驾驶好坏。'), findsOneWidget);
    });

    testWidgets('关于这些数据：速度数据、数据点说明与可复制的记录信息', (tester) async {
      await openDetail(
        tester,
        (request) async => jsonResponse(
          jsonEncode(
            fixture(
              request.url.path.endsWith('/series')
                  ? 'drive-series'
                  : 'drive-detail',
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('关于这些数据').hitTestable(), 260);
      expect(find.text('关于这些数据'), findsOneWidget);
      for (final label in ['口径与估算', '记录与缺失', '时间与时区', '来源与生成时间', '技术详情']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('更多行程指标'), findsNothing);
      // 技术详情正文是可复制的 SelectableText，它自带一个可滚动区；
      // 这里始终用页面自身的纵向列表来滚动。
      final pageScroll = find
          .descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('技术详情').hitTestable(),
        200,
        scrollable: pageScroll,
      );
      await tester.tap(find.text('技术详情').hitTestable());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('行程记录 1'),
        200,
        scrollable: pageScroll,
      );
      expect(find.textContaining('行程记录 1'), findsOneWidget);
      expect(find.textContaining('续航口径 额定'), findsOneWidget);
    });
  });
}
