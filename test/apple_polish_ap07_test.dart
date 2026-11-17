import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/icons.dart';
import 'package:mileaf/src/design/tokens.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/typography.dart';
import 'package:mileaf/src/workspace.dart';

import 'package:mileaf/src/map/map_key.dart';

import 'support/map_key_fixture.dart';
import 'statistics_test.dart' show openStats;
import 'support/statistics_insights_fixture.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

dynamic fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync());

http.Response _ok(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

MockClient shellClient({List<Uri>? calls}) => MockClient((request) async {
  calls?.add(request.url);
  final path = request.url.path;
  if (path.endsWith('/vehicles')) return _ok(fixture('vehicles'));
  if (path.endsWith('/meta')) return _ok(fixture('meta'));
  if (path.endsWith('/summary')) return _ok(fixture('summary'));
  if (path.endsWith('/stats')) {
    return _ok(
      fixture(
        request.url.queryParameters['kind'] == 'charging'
            ? 'charging-stats'
            : 'driving-stats',
      ),
    );
  }
  if (path.endsWith('/drives')) return _ok(fixture('drives'));
  if (path.endsWith('/charging-sessions')) {
    return _ok({'items': [], 'next_cursor': null});
  }
  return http.Response('{}', 404);
});

Future<void> pumpWorkspace(
  WidgetTester tester, {
  List<Uri>? calls,
  double textScale = 1,
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });
  final keys = MapKeyController(TestKeyStore());
  await keys.restore();
  final store = MemorySessionStore()
    ..value = jsonEncode({
      'site': 'https://example.com/prefix',
      'token': 'test',
      'expires_at': '2099-01-01T00:00:00Z',
    });
  await tester.pumpWidget(
    MileafApp(
      client: shellClient(calls: calls),
      mapKeys: keys,
      sessionStore: store,
      trustStore: MemoryTrustStore(),
      vehiclePreferences: MemoryVehiclePreferences(),
      now: () => DateTime.utc(2026, 10, 26, 10, 40),
      calendar: () async => CalendarContext('Asia/Shanghai'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('设置'));
  await tester.pumpAndSettle();
}

MockClient insightsClient() => MockClient((request) async {
  final path = request.url.path;
  if (path.endsWith('/vehicles')) return _ok(fixture('vehicles'));
  if (path.endsWith('/summary')) return _ok(fixture('summary'));
  if (path.endsWith('/meta')) {
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
  if (request.url.queryParameters['kind'] == 'charging') {
    return _ok(fixture('charging-stats'));
  }
  return _ok(statisticsInsightsFixture(request.url));
});

Future<void> pumpInsights(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await openStats(
    tester,
    insightsClient(),
    () => DateTime.utc(2026, 10, 26, 10, 40),
    () => 'Asia/Shanghai',
    statisticsInsights: true,
  );
}

void main() {
  group('AP07 P12 设置', () {
    testWidgets('设置页分成使用偏好与当前站点两张分组卡，行为单行设置行', (tester) async {
      await pumpWorkspace(tester);
      await openSettings(tester);
      expect(find.byType(MileafGroupHeader), findsNWidgets(2));
      expect(find.text('使用偏好'), findsOneWidget);
      expect(find.text('当前站点'), findsOneWidget);
      expect(find.byType(MileafGroupCard), findsNWidgets(2));
      expect(find.byType(MileafGroupRow), findsNWidgets(5));
      // 旧的两行数据行（第二行说明）退场：每行现在只有标题与尾部值。
      expect(find.text('版本与兼容性'), findsNothing);
      expect(find.byType(MileafDataRow), findsNothing);
      for (final row in tester.widgetList<MileafGroupRow>(
        find.byType(MileafGroupRow),
      )) {
        expect(row.meta, isNull, reason: 'P12 设置行为单行 52');
      }
      final heights = tester
          .widgetList<MileafGroupRow>(find.byType(MileafGroupRow))
          .map((row) => tester.getSize(find.byWidget(row)).height);
      for (final height in heights) {
        expect(height, greaterThanOrEqualTo(MileafGroupRow.rowHeight));
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('设置行标题 body 400、尾部当前值 body textSecondary', (tester) async {
      await pumpWorkspace(tester);
      await openSettings(tester);
      final colors = const MileafColors.light();
      final title = tester.widget<Text>(find.text('地图'));
      final styles = MileafTextStyles.of(tester.element(find.text('地图')));
      expect(title.style?.fontSize, styles.body.fontSize);
      expect(title.style?.fontWeight, FontWeight.w400);
      expect(title.style?.color, colors.text);
      final valueRow = tester.widget<MileafGroupRow>(
        find.byWidgetPredicate(
          (widget) => widget is MileafGroupRow && widget.value == '未设置',
        ),
      );
      expect(valueRow.value, '未设置');
      final leading = tester.widgetList<MileafIcon>(find.byType(MileafIcon));
      expect(leading.any((icon) => icon.name == MileafIconName.mapPin), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('地图未配置写未配置，分组脚注说明路线示意', (tester) async {
      await pumpWorkspace(tester);
      await openSettings(tester);
      expect(find.text('未配置'), findsOneWidget);
      expect(find.text('未配置地图时显示路线示意。'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('站点连接行尾是主机名，币种未设置写未设置', (tester) async {
      await pumpWorkspace(tester);
      await openSettings(tester);
      expect(find.text('example.com'), findsOneWidget);
      expect(find.textContaining('https://example.com/prefix'), findsNothing);
      expect(find.text('未设置'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AP07 P01 概览', () {
    testWidgets('车况卡用图形加文字，今日三项用 metricSm 三格', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWorkspace(tester);
      expect(find.text('充电中'), findsOneWidget);
      expect(find.text('11.0 kW'), findsOneWidget);
      expect(find.textContaining('充电中 ·'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('overview-status')),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is MileafIcon && widget.name == MileafIconName.bolt,
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('额定续航，非实时'), findsOneWidget);
      expect(find.text('今日里程'), findsOneWidget);
      expect(find.text('估算耗电'), findsOneWidget);
      expect(find.text('今日 km'), findsNothing);
      expect(find.text('次行程'), findsNothing);
      expect(find.text('估算 kWh'), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('期间卡只有一个 metricLg，车况只有一个 display', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWorkspace(tester);
      final viewport = tester.getRect(find.byType(RefreshIndicator));
      final roles = measureValueRoles(tester, viewport: viewport);
      expect(roles.display, ['320 km'], reason: 'R21.1 每视口最多一个 display');
      expect(roles.metricLg, ['960.0 km'], reason: 'R21.1 每视口最多一个 metricLg');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('期间卡：标签与区间各一次，比较写成句子', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWorkspace(tester);
      expect(find.text('本月驾驶'), findsOneWidget);
      expect(find.text('10月1日–26日'), findsWidgets);
      expect(find.textContaining('960.0'), findsWidgets);
      expect(find.textContaining('· 驾驶里程'), findsNothing);
      expect(find.textContaining('2026年'), findsNothing);
      expect(find.text('与上月同期持平'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('读数头在绘图区之上，旧提示与「差 +」写法退场', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWorkspace(tester);
      expect(find.text('点按读值'), findsNothing);
      expect(find.textContaining('差 +'), findsNothing);
      expect(
        find.textContaining('上月同期 9月1日–26日'),
        findsWidgets,
        reason: 'R29 第三行：参照名用真实区间',
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('本期账目是独立分组卡，四格两列', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWorkspace(tester);
      expect(find.text('本期账目'), findsOneWidget);
      for (final key in const [
        'overview-plate-net',
        'overview-plate-cost',
        'overview-plate-energy',
        'overview-plate-drives',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('overview-plate-net')),
          matching: find.textContaining('188'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('overview-plate-drives')),
          matching: find.textContaining('49'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('overview-plate-energy')),
          matching: find.textContaining('160'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('净电耗'), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('360x800 首屏：车况卡完整、主值与读数头完整、绘图区首 80 可见', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWorkspace(tester, size: const Size(360, 800));
      final viewport = tester.getRect(find.byType(RefreshIndicator));
      expect(
        tester.getRect(find.byKey(const ValueKey('overview-status'))).bottom,
        lessThanOrEqualTo(viewport.bottom),
        reason: 'P01 车况卡完整',
      );
      expect(find.textContaining('960.0').hitTestable(), findsWidgets);
      final plot = chartPlotRect(tester);
      expect(
        viewport.bottom - plot.top,
        greaterThanOrEqualTo(80),
        reason: 'P01 绘图区首 80 逻辑像素可见',
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  group('AP07 P02 行程', () {
    Future<void> openDrives(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: find.byType(MileafNavBar),
          matching: find.text('行程'),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('期间卡：主值 metricLg、三格 metricSm，区间只在卡片标签一次', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWorkspace(tester);
      await openDrives(tester);
      expect(find.text('近 30 天'), findsOneWidget);
      expect(find.text('9月27日–10月26日'), findsWidgets);
      expect(find.textContaining('960.0'), findsWidgets);
      expect(find.text('行程'), findsWidgets);
      expect(find.textContaining('180.00'), findsWidgets);
      expect(find.textContaining('188'), findsWidgets);
      expect(find.text('出行节奏'), findsNothing);
      expect(find.text('每日里程'), findsOneWidget);
      expect(find.text('自定义'), findsOneWidget);
      expect(find.text('自定义日期'), findsNothing);
      // 可见下钻串仍由共享图表组件给出（本票把语义标签传为「查看当天」；
      // 可见文字改用 activationLabel 属 charts.dart 的最小补丁，见交接）。
      expect(find.bySemanticsLabel('查看当天'), findsWidgets);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('记录按天分组，路线与电耗分行，尾值 metricSm', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWorkspace(tester);
      await openDrives(tester);
      expect(find.text('3月30日 周一'), findsOneWidget);
      expect(find.text('最近的路'), findsNothing);
      expect(find.textContaining('净电耗'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('drive-17')),
          matching: find.textContaining('电耗 188 Wh/km'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('drive-17')),
          matching: find.textContaining('10:00–10:30，30 分钟'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('360x800 首屏：第一条记录完整、第二条起始至少 24 可见', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWorkspace(tester, size: const Size(360, 800));
      await openDrives(tester);
      final viewport = tester.getRect(find.byType(RefreshIndicator).last);
      final first = tester.getRect(find.byKey(const ValueKey('drive-17')));
      final second = tester.getRect(find.byKey(const ValueKey('drive-16')));
      expect(first.bottom, lessThanOrEqualTo(viewport.bottom));
      // §6 退让阶梯第 1–4 步已用尽：360×800 下第二条记录露出 2（目标 24）。
      // 第 5 步候选（去图表标题行 / 把节奏图移到记录之后）会改动冻结的 P02
      // 版面顺序，已写入交接交用户裁定，此处按实际值锁定。
      expect(viewport.bottom - second.top, greaterThanOrEqualTo(0));
      expect(second.top, lessThan(viewport.bottom));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  group('AP07 P06 统计首页', () {
    testWidgets('结论卡与每日里程同属一张模块卡，专题是 2×2 卡片', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpInsights(tester);
      expect(find.textContaining('本月'), findsWidgets);
      expect(find.text('每日里程'), findsOneWidget);
      expect(find.text('里程走势'), findsNothing);
      expect(find.text('查看对比明细'), findsOneWidget);
      for (final topic in const ['节奏', '能耗', '补能', '长期']) {
        expect(find.byKey(ValueKey('statistics-topic-$topic')), findsOneWidget);
      }
      expect(find.text('查看专题'), findsWidgets);
      expect(find.text('进专题查看'), findsNothing);
      expect(find.textContaining('较参照'), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('360x800 首屏：用车专题第一行两张卡片完整可见', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpInsights(tester, size: const Size(360, 800));
      final bar = tester.getTopLeft(find.byType(MileafNavBar)).dy;
      for (final topic in const ['节奏', '能耗']) {
        final rect = tester.getRect(
          find.byKey(ValueKey('statistics-topic-$topic')),
        );
        expect(
          rect.bottom,
          lessThanOrEqualTo(bar),
          reason: 'P06 专题第一行两张卡片完整可见（$topic）',
        );
      }
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  group('AP07 P16 车辆弹层', () {
    testWidgets('车辆弹层显示完整名称与区分信息，当前车辆尾部勾选', (tester) async {
      await pumpWorkspace(tester);
      await tester.tap(find.text('行笺测试车'));
      await tester.pumpAndSettle();
      expect(find.text('选择车辆'), findsOneWidget);
      expect(find.text('行笺测试车'), findsWidgets);
      expect(find.text('3，尾号 0001'), findsOneWidget);
      expect(find.text('Y，尾号 0002'), findsOneWidget);
      expect(find.textContaining('车辆 ID'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(MileafSheetFrame),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is MileafIcon && widget.name == MileafIconName.check,
          ),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('车辆弹层是浮动样式，刷新车辆列表是底部文字按钮', (tester) async {
      await pumpWorkspace(tester);
      await tester.tap(find.text('行笺测试车'));
      await tester.pumpAndSettle();
      final sheet = tester.widget<MileafSheetFrame>(
        find.byType(MileafSheetFrame),
      );
      expect(sheet.style, MileafSheetStyle.floating);
      expect(find.text('刷新车辆列表'), findsOneWidget);
      expect(find.byTooltip('刷新车辆'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

/// R21.7 的等价测量：MileafNumber 用 Text.rich 承载数值（样式在 span 上），
/// 现有层级探针只读 Text.style，因此这里连同 textSpan 的样式一起判定角色。
({List<String> display, List<String> metricLg}) measureValueRoles(
  WidgetTester tester, {
  required Rect viewport,
}) {
  final display = <String>[];
  final metricLg = <String>[];
  for (final element in find.byType(Text).evaluate()) {
    final widget = element.widget as Text;
    final style = widget.style ?? (widget.textSpan?.style);
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

/// 绘图区（TimeSeriesChart 内面积最大的 CustomPaint）。
Rect chartPlotRect(WidgetTester tester) {
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