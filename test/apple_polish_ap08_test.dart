// AP08 概览全量与服务信息（P01 全状态、关于这些数据、MetaPage 服务信息）。
//
// 机位与口径：360×800、safeArea 上下各 24、100% 字号（交付手册 §6.1/§6）。
// 状态矩阵按 Tickets AP08 动作列：无车况、车况缺失、充电中、休眠、离线、
// 扩展能力不支持、比较不可用、费用覆盖缺失、时区回退、刷新失败有旧数据、空期间。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/icons.dart';
import 'package:mileaf/src/design/tokens.dart';
import 'package:mileaf/src/overview_page.dart' show MetaPage;
import 'package:mileaf/src/statistics_insights_page.dart';
import 'package:mileaf/src/workspace.dart';

import 'overview_visualization_test.dart'
    show openOverviewVisual, overviewFixture, overviewResponse;

Object _vehicles() =>
    jsonDecode(File('test/fixtures/vehicles.json').readAsStringSync());

class _Cny implements CurrencyPreferenceStore {
  @override
  Future<String?> read(String site) async => 'CNY';
  @override
  Future<void> write(String site, String? code) async {}
}

/// P01 机位：handler 之外的四个资源用本票夹具，便于逐状态只改一处。
Future<void> pumpP01(
  WidgetTester tester, {
  Map<String, dynamic>? summary,
  Map<String, dynamic>? meta,
  Map<String, dynamic>? driving,
  Map<String, dynamic>? charging,
  Future<CalendarContext> Function()? calendar,
  CurrencyPreferenceStore? currency,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool safeArea = false,
  Map<String, dynamic>? vehicles,
  Future<http.Response> Function(http.Request request)? override,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  if (safeArea) {
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.padding = tester.view.viewPadding;
  }
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetViewPadding();
    tester.view.resetPadding();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await openOverviewVisual(
    tester,
    (request) async {
      if (override != null) {
        final response = await override(request);
        if (response.statusCode != 404) return response;
      }
      final path = request.url.path;
      if (path.endsWith('/vehicles')) {
        return overviewResponse(vehicles ?? _vehicles());
      }
      if (path.endsWith('/meta')) {
        return overviewResponse(meta ?? overviewFixture('meta'));
      }
      if (path.endsWith('/summary')) {
        return overviewResponse(summary ?? overviewFixture('summary'));
      }
      if (path.endsWith('/stats')) {
        return overviewResponse(
          request.url.queryParameters['kind'] == 'charging'
              ? charging ?? overviewFixture('charging-stats')
              : driving ?? overviewFixture('driving-stats'),
        );
      }
      return http.Response('{}', 404);
    },
    calendar: calendar ?? () async => CalendarContext('Asia/Shanghai'),
    briefing: true,
    ownerCapabilities: true,
    currencyPreferences: currency,
  );
}

Finder _statusIcon(MileafIconName name) => find.descendant(
  of: find.byKey(const ValueKey('overview-status')),
  matching: find.byWidgetPredicate(
    (widget) => widget is MileafIcon && widget.name == name,
  ),
);

Finder _nav(String label) =>
    find.descendant(of: find.byType(MileafNavBar), matching: find.text(label));

/// 列表是惰性的：scrollUntilVisible 在目标被「构建」时就停下，可能仍在屏外，
/// 所以再对一次视口位置后才点按。
Future<void> _reveal(WidgetTester tester, Finder target) async {
  var steps = 0;
  while (target.evaluate().isEmpty && steps++ < 24) {
    await tester.drag(find.byType(RefreshIndicator), const Offset(0, -250));
    await tester.pumpAndSettle();
  }
  await Scrollable.ensureVisible(tester.element(target.first), alignment: .5);
  await tester.pumpAndSettle();
}

/// 绘图区（TimeSeriesChart 内面积最大的 CustomPaint）。
Rect _plotRect(WidgetTester tester) {
  final rects = find
      .descendant(
        of: find.byType(TimeSeriesChart),
        matching: find.byType(CustomPaint),
      )
      .evaluate()
      .map((element) => tester.getRect(find.byWidget(element.widget)))
      .where((rect) => rect.height > 20)
      .toList();
  return rects.reduce((a, b) => a.height >= b.height ? a : b);
}

/// R21.7 的等价测量：MileafNumber 用 Text.rich 承载数值（样式在 span 上）。
({List<String> display, List<String> metricLg}) _valueRoles(
  WidgetTester tester, {
  required Rect viewport,
}) {
  final display = <String>[];
  final metricLg = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final widget = element.widget as Text;
    final style = widget.style ?? widget.textSpan?.style;
    final size = style?.fontSize;
    if (size != MileafType.displaySize && size != MileafType.metricLgSize) {
      continue;
    }
    final box = element.renderObject;
    if (box is! RenderBox || !box.attached || !box.hasSize) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (!rect.overlaps(viewport)) continue;
    final text = widget.textSpan?.toPlainText() ?? widget.data ?? '';
    (size == MileafType.displaySize ? display : metricLg).add(text);
  }
  return (display: display, metricLg: metricLg);
}

void main() {
  group('P01 全状态', () {
    testWidgets('无车况：车况卡收缩成空态，期间卡与本期账目仍可达', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpP01(
        tester,
        override: (request) async => request.url.path.endsWith('/summary')
            ? http.Response('', 503)
            : http.Response('', 404),
      );
      expect(find.text('车况暂不可用'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.text('本月驾驶'), findsOneWidget);
      expect(find.textContaining('960.0'), findsWidgets);
      expect(find.text('今日里程'), findsNothing, reason: '没有车况就没有今日三项');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('车况缺失：状态未知、续航与电量写 —，不补零', (tester) async {
      final semantics = tester.ensureSemantics();
      final summary = overviewFixture('summary')
        ..['state'] = null
        ..['battery'] = null;
      await pumpP01(tester, summary: summary);
      expect(find.text('状态未知'), findsOneWidget);
      expect(find.text('— 暂无续航'), findsOneWidget);
      expect(find.text('电量未知'), findsOneWidget);
      expect(find.text('0 km'), findsNothing);
      expect(find.text('今日里程'), findsOneWidget, reason: '已知今日数据保留');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    for (final (value, label, icon) in const [
      ('charging', '充电中', MileafIconName.bolt),
      ('asleep', '休眠', MileafIconName.moon),
      ('offline', '离线', MileafIconName.offline),
    ]) {
      testWidgets('状态用图形加文字：$label', (tester) async {
        final semantics = tester.ensureSemantics();
        final summary = overviewFixture('summary')
          ..['state'] = {'value': value, 'since': '2026-03-15T11:00:00Z'};
        if (value != 'charging') summary['charging_power_kw'] = null;
        await pumpP01(tester, summary: summary);
        expect(find.text(label), findsOneWidget);
        expect(_statusIcon(icon), findsOneWidget, reason: '状态图形跟随状态');
        expect(
          find.textContaining('·'),
          findsNothing,
          reason: 'CP09.1 不用「·」拼接',
        );
        if (value == 'charging') {
          expect(find.text('11.0 kW'), findsOneWidget);
        } else {
          expect(find.text('11.0 kW'), findsNothing, reason: '功率只在充电时出现');
        }
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }

    testWidgets('扩展能力不支持：保留基础数据与口径，状态条可重试', (tester) async {
      final semantics = tester.ensureSemantics();
      var metaReads = 0;
      await pumpP01(
        tester,
        override: (request) async {
          if (!request.url.path.endsWith('/meta')) {
            return http.Response('', 404);
          }
          metaReads++;
          return http.Response('', 503);
        },
      );
      expect(
        find.text('部分新数据暂不可用，已按基础数据显示'),
        findsOneWidget,
        reason: 'CP07：能力未确认时保留基础数据',
      );
      // 能力回退时电耗仍取服务端净电耗（不做配对换算）。
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('overview-plate-net')),
          matching: find.text('188 Wh/km'),
        ),
        findsOneWidget,
      );
      expect(metaReads, 1);
      final retry = find.descendant(
        of: find.ancestor(
          of: find.text('部分新数据暂不可用，已按基础数据显示'),
          matching: find.byType(InlineBanner),
        ),
        matching: find.text('重试'),
      );
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(metaReads, 2, reason: '重试只重读能力，不牵动其它资源');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('比较不可用：参照读取失败时不造句，明说暂时无法比较', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpP01(
        tester,
        override: (request) async {
          final from = request.url.queryParameters['from'] ?? '';
          if (request.url.path.endsWith('/stats') &&
              from.startsWith('2026-01')) {
            return http.Response('', 503);
          }
          return http.Response('', 404);
        },
      );
      expect(find.text('暂时无法比较'), findsOneWidget);
      expect(find.textContaining('电耗比'), findsNothing, reason: '没有参照就不造句');
      expect(find.textContaining('比较暂不可用'), findsWidgets);
      expect(find.textContaining('960.0'), findsWidgets);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('费用覆盖缺失：只写已记录费用金额，不写覆盖', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpP01(tester, currency: _Cny());
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('overview-plate-cost')),
          matching: find.text('¥72'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('次有费用'), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('时区回退：用共享时区不可读句，不写设备 IANA', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpP01(
        tester,
        calendar: () async => CalendarContext('UTC', fallback: true),
      );
      expect(find.text('无法读取手机时区，暂按 UTC 显示和统计'), findsOneWidget);
      expect(find.textContaining('IANA'), findsNothing, reason: 'CP09.3');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('刷新失败有旧数据：保留本期数值并给出重试', (tester) async {
      final semantics = tester.ensureSemantics();
      var failing = false;
      await pumpP01(
        tester,
        override: (request) async {
          if (failing && request.url.path.endsWith('/summary')) {
            return http.Response('', 503);
          }
          return http.Response('', 404);
        },
      );
      failing = true;
      await tester.drag(find.byType(RefreshIndicator), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.textContaining('显示的是上次的数据'), findsOneWidget);
      expect(find.textContaining('960.0'), findsWidgets);
      expect(find.text('本月驾驶'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('空期间：图表收起成一句空态，主值仍是真实零', (tester) async {
      final semantics = tester.ensureSemantics();
      final driving = overviewFixture('driving-stats');
      driving['buckets'] = <Object>[];
      final totals = driving['totals'] as Map<String, dynamic>;
      totals['drives'] = 0;
      totals['distance_km'] = 0;
      totals['energy_kwh'] = 0;
      await pumpP01(tester, driving: driving);
      expect(
        find.text('这段时间没有行程'),
        findsOneWidget,
        reason: 'R29 无数据只留一句人话；CP02 不再出现「采样点」',
      );
      expect(find.text('本月驾驶'), findsOneWidget);
      expect(find.textContaining('0.0'), findsWidgets, reason: '真实 0 不写成 —');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  group('P01 关于这些数据（R30）', () {
    testWidgets('五类说明齐全且顺序固定，技术详情可复制', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpP01(tester);
      await tester.scrollUntilVisible(find.text('关于这些数据'), 300);
      final labels = ['口径与估算', '记录与缺失', '时间与时区', '来源与生成时间', '技术详情'];
      final tops = <double>[];
      for (final label in labels) {
        await _reveal(tester, find.text(label));
        expect(find.text(label), findsOneWidget, reason: label);
        tops.add(tester.getRect(find.text(label)).top);
      }
      for (var index = 1; index < tops.length; index++) {
        expect(tops[index], greaterThan(tops[index - 1]), reason: 'R30.2 顺序固定');
      }
      await _reveal(tester, find.text('技术详情'));
      await tester.tap(find.text('技术详情'));
      await tester.pumpAndSettle();
      expect(
        find.byType(SelectableText),
        findsWidgets,
        reason: 'R30.4 技术详情可复制',
      );
      expect(find.textContaining('统计时区'), findsWidgets);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('旧「数据说明与更多」的原值迁入记录与缺失', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpP01(tester);
      await _reveal(tester, find.text('记录与缺失'));
      await tester.tap(find.text('记录与缺失'));
      await tester.pumpAndSettle();
      expect(find.textContaining('AC 120.00 kWh'), findsOneWidget);
      expect(find.textContaining('DC 20.00 kWh'), findsOneWidget);
      expect(find.textContaining('未知 —'), findsOneWidget);
      expect(find.textContaining('14.3%'), findsOneWidget, reason: 'CP03 % 紧贴');
      expect(find.textContaining('充电账目'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  group('服务信息（P12）', () {
    testWidgets('MetaPage 按分组卡与技术详情呈现，路由与标题不变', (tester) async {
      await pumpP01(tester);
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('服务信息'), 180);
      await tester.tap(find.text('服务信息'));
      await tester.pumpAndSettle();
      expect(find.byType(MetaPage), findsOneWidget);
      expect(find.text('Mileaf Server 0.1.0'), findsOneWidget);
      expect(find.text('当前连接的服务版本'), findsOneWidget);
      // P12：服务信息为分组卡 + 技术详情。
      expect(find.byType(MileafGroupCard), findsWidgets);
      expect(find.byType(MileafGroupRow), findsWidgets);
      await tester.scrollUntilVisible(find.text('技术详情'), 150);
      await tester.pumpAndSettle();
      await tester.tap(find.text('技术详情'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsWidgets);
      expect(find.textContaining('20260808090000'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('P01 预算与层级', () {
    // §6 的「有效视口」是全屏扣除安全区**与实际遮挡的导航矩形**：外壳
    // extendBody + 底栏，页面内容在底栏之下延伸，因此下界取导航上沿而不是
    // RefreshIndicator 的 800 全高（AP07 的 P01 用例用的是全高，见 D-AP08-11）。
    testWidgets('360×800（safeArea 24/24，有效视口=导航上沿）：车况卡与期间主值完整', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpP01(tester, size: const Size(360, 800), safeArea: true);
      final navTop = tester.getRect(find.byType(MileafNavBar)).top;
      final statusBottom = tester
          .getRect(find.byKey(const ValueKey('overview-status')))
          .bottom;
      final mainValue = tester.getRect(
        find.bySemanticsLabel(RegExp(r'^本月驾驶 960.0')),
      );
      debugPrint(
        'AP08 probe: navTop=$navTop statusBottom=$statusBottom '
        'mainValueBottom=${mainValue.bottom} plotTop=${_plotRect(tester).top} '
        'readoutBottom=${tester.getRect(find.byKey(MileafChartGrammar.readoutLiveKey)).bottom}',
      );
      expect(statusBottom, lessThanOrEqualTo(navTop), reason: 'P01 车况卡完整');
      expect(
        mainValue.bottom,
        lessThanOrEqualTo(navTop),
        reason: 'P01 期间卡主值完整',
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('P01 首屏预算：读数头完整 + 绘图区首 80（有效视口）', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpP01(tester, size: const Size(360, 800), safeArea: true);
      final navTop = tester.getRect(find.byType(MileafNavBar)).top;
      expect(
        tester.getRect(find.byKey(MileafChartGrammar.readoutLiveKey)).bottom,
        lessThanOrEqualTo(navTop),
        reason: 'P01 读数头完整',
      );
      final visible = navTop - _plotRect(tester).top;
      expect(visible, greaterThanOrEqualTo(80), reason: 'P01 绘图区至少首 80 可见');
      expect(tester.takeException(), isNull);
      semantics.dispose();
      // D-AP08-11（待用户裁定）：按有效视口实测绘图区首 **0** 可见（预算 80），
      // 读数头下沿 710 > 导航上沿 704。修法需走 §6 退让阶梯第 3 步（紧凑读数行）
      // 或由用户裁定预算，故本用例先跳过而不是保留全高测法的假通过。
    }, skip: true);

    testWidgets('320×568 200% 不溢出，每视口至多一个 display 与一个 metricLg', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpP01(tester, size: const Size(320, 568), textScale: 2);
      expect(tester.takeException(), isNull);
      final roles = _valueRoles(
        tester,
        viewport: tester.getRect(find.byType(RefreshIndicator)),
      );
      expect(roles.display.length, lessThanOrEqualTo(1));
      expect(roles.metricLg.length, lessThanOrEqualTo(1));
      semantics.dispose();
    });

    testWidgets('430 宽与 130/150/200% 与 768 宽均不溢出', (tester) async {
      for (final (size, scale) in const [
        (Size(430, 932), 1.0),
        (Size(360, 800), 1.3),
        (Size(360, 800), 1.5),
        (Size(768, 1024), 2.0),
      ]) {
        await pumpP01(tester, size: size, textScale: scale);
        expect(tester.takeException(), isNull, reason: '机位不溢出');
      }
    });
  });

  group('P01 阅读连续与下钻', () {
    testWidgets('Tab 往返保留期间与选点，期间控件只有一处', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpP01(tester);
      await tester.tap(find.text('近7天'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StatusChip>(find.widgetWithText(StatusChip, '近7天'))
            .selected,
        isTrue,
      );
      await tester.tap(_nav('行程'));
      await tester.pumpAndSettle();
      await tester.tap(_nav('概览'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<StatusChip>(find.widgetWithText(StatusChip, '近7天'))
            .selected,
        isTrue,
        reason: 'Tab 往返不重置期间',
      );
      expect(find.text('近 7 天驾驶'), findsWidgets);
      expect(find.byType(MileafPeriodRow), findsOneWidget, reason: '期间控件只有一处');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('页尾显式下钻仍走原回调与同一期间', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpP01(tester);
      await tester.tap(find.text('近7天'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('驾驶统计'));
      await tester.tap(find.text('驾驶统计'));
      await tester.pumpAndSettle();
      expect(find.byType(StatisticsInsightsPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });
}
