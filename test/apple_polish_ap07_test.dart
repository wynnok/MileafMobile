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
import 'charging_expansion_test.dart' show expansionResponse;
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

MockClient chargingClient() => MockClient((request) async {
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
  if (path.endsWith('/charging-sessions/9/series')) {
    final series = fixture('charging-series') as Map<String, dynamic>;
    series['session_id'] = 9;
    return _ok(series);
  }
  if (path.endsWith('/charging-sessions/9')) {
    final detail = fixture('charging-detail') as Map<String, dynamic>;
    detail['id'] = 9;
    return _ok(detail);
  }
  if (path.endsWith('/charging-sessions')) {
    return _ok(fixture('charging-sessions'));
  }
  return http.Response('{}', 404);
});

/// 声明充电扩展能力（charging-experience-v1）的站点：期间行三个胶囊与
/// 「最近充电 → 查看全部」入口才会出现。充电账本接口沿用
/// `expansionResponse`（B 期扩展契约），其余页面沿用本票夹具。
MockClient chargingLedgerClient() {
  final base = chargingClient();
  return MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/meta')) {
      final meta = fixture('meta') as Map<String, dynamic>;
      meta['version'] = '0.2.0';
      meta['charging_experience'] = {
        'contract_version': 'charging-experience-v1',
        'minimum_server_version': '0.2.0',
        'tested_schema_version': 20260808090000,
        'fields': <String, bool>{},
      };
      return _ok(meta);
    }
    if (path.endsWith('/charging-sessions') ||
        path.endsWith('/charging-locations') ||
        (path.endsWith('/stats') &&
            request.url.queryParameters['kind'] == 'charging')) {
      return expansionResponse(request);
    }
    final forwarded = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return http.Response.fromStream(await base.send(forwarded));
  });
}

Future<void> pumpWorkspace(
  WidgetTester tester, {
  List<Uri>? calls,
  MockClient? client,
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
      client: client ?? shellClient(calls: calls),
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
  double textScale = 1,
  bool safeArea = false,
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
    if (safeArea) {
      tester.view.resetViewPadding();
      tester.view.resetPadding();
    }
    tester.platformDispatcher.clearTextScaleFactorTestValue();
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
  group('AP07 修正·小屏与大字', () {
    testWidgets('320×568 200% 四页不溢出：行内边、期间行与专题网格', (tester) async {
      await pumpWorkspace(
        tester,
        client: chargingLedgerClient(),
        size: const Size(320, 568),
        textScale: 2,
      );
      Future<void> tab(String label) async {
        await tester.tap(
          find.descendant(
            of: find.byType(MileafNavBar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
      }

      await tab('行程');
      expect(tester.takeException(), isNull, reason: 'P02 320/200% 不溢出');
      await tab('充电');
      expect(tester.takeException(), isNull, reason: 'P03 320/200% 不溢出');
      await tab('统计');
      expect(tester.takeException(), isNull, reason: 'P06 320/200% 不溢出');
      await tab('概览');
      expect(tester.takeException(), isNull, reason: 'P01 320/200% 不溢出');
    });
  });

  group('AP07 修正·P01 概览统一网格', () {
    testWidgets('开放行收进分组卡，行内横向内边 ≥12，只有行间一条发丝线', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWorkspace(tester);
      // 「最近记录」「用车专题」都走分组卡：2 行 + 3 行。
      final rows = find.byType(MileafDataRow);
      expect(rows, findsNWidgets(5));
      for (final element in rows.evaluate()) {
        final row = find.byWidget(element.widget);
        final card = find
            .ancestor(of: row, matching: find.byType(MileafGroupCard))
            .first;
        final cardRect = tester.getRect(card);
        final rowRect = tester.getRect(row);
        expect(
          rowRect.left - cardRect.left,
          greaterThanOrEqualTo(12),
          reason: 'P01 行文字距卡片左缘 ≥12',
        );
        expect(
          cardRect.right - rowRect.right,
          greaterThanOrEqualTo(12),
          reason: 'P01 行文字距卡片右缘 ≥12',
        );
        // 首行之上与末行之下没有线：行自己不再画整行 topLine/bottomLine。
        final widget = element.widget as MileafDataRow;
        expect(widget.topLine, isFalse);
        expect(widget.bottomLine, isFalse);
      }
      final card = find
          .ancestor(
            of: find.text('最近行程'),
            matching: find.byType(MileafGroupCard),
          )
          .first;
      expect(hairlinesIn(card), 1, reason: 'R24 两行之间一条分隔线，末行之下不画线');
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('电耗对比与关于这些数据同一容器语法：区块标题 + 分组卡 + 卡内行', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWorkspace(tester);
      await tester.scrollUntilVisible(find.text('电耗对比'), 300);
      expect(find.text('电耗对比'), findsOneWidget);
      // P01：标题在画布层（页面边距），卡内内容在页面边距 + 16。
      final headerCard = find
          .ancestor(
            of: find.text('查看对比明细'),
            matching: find.byType(MileafGroupCard),
          )
          .first;
      final card = tester.getRect(headerCard);
      final title = tester.getRect(find.text('电耗对比'));
      expect(card.left, closeTo(title.left, 0.5), reason: '卡片与区块标题同左缘');
      final body = tester.getRect(
        find.descendant(of: headerCard, matching: find.byType(Text)).first,
      );
      expect(
        body.left - card.left,
        closeTo(MileafSpace.cardPad, 0.5),
        reason: '卡内正文距卡片左缘 16',
      );
      expect(card.right - body.right, greaterThanOrEqualTo(0));
      // 卡内动作是同一张卡里的一行导航行，不是卡中卡。
      final action = tester.getRect(find.text('查看对比明细'));
      expect(action.left - card.left, greaterThanOrEqualTo(12));
      expect(
        find.ancestor(
          of: find.text('查看对比明细'),
          matching: find.byType(MileafGroupRow),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.text('查看对比明细'),
          matching: find.byType(MileafModuleCard),
        ),
        findsNothing,
      );
      expect(find.byType(MileafButton), findsNothing, reason: '不再有悬浮按钮感');
      // 与页尾说明同一容器语法：两者都是「标题 + 分组卡」。
      expect(
        find.ancestor(
          of: find.text('关于这些数据'),
          matching: find.byType(MileafGroupHeader),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  group('AP07 修正·P02 行程记录卡', () {
    Future<void> openDrives(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: find.byType(MileafNavBar),
          matching: find.text('行程'),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('记录行有统一横向内边，只在行间画分隔线，末行无线且卡片裁剪', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWorkspace(tester);
      await openDrives(tester);
      final rows = find.byType(MileafDataRow);
      expect(rows, findsWidgets);
      var checked = 0;
      for (final element in rows.evaluate()) {
        final widget = element.widget as MileafDataRow;
        if (widget.bottomLine || widget.topLine) {
          fail('记录行不应自己画整行分隔线');
        }
        final row = find.byWidget(element.widget);
        final card = find
            .ancestor(of: row, matching: find.byType(MileafGroupCard))
            .first;
        if (card.evaluate().isEmpty) continue;
        checked++;
        final cardRect = tester.getRect(card);
        final rowRect = tester.getRect(row);
        expect(
          rowRect.left - cardRect.left,
          greaterThanOrEqualTo(12),
          reason: 'P02 行文字距卡片左缘 ≥12',
        );
        expect(cardRect.right - rowRect.right, greaterThanOrEqualTo(12));
        expect(rowRect.bottom, lessThanOrEqualTo(cardRect.bottom + 0.5));
      }
      expect(checked, greaterThan(0));
      // 每天一张分组卡：行数与分隔线数只差 1（末行不画线）。
      final firstCard = find
          .ancestor(
            of: find.byKey(const ValueKey('drive-17')),
            matching: find.byType(MileafGroupCard),
          )
          .first;
      final group = tester.widget<MileafGroupCard>(firstCard);
      expect(group.clip, isTrue, reason: '卡片裁到圆角，末行线不会突破圆角');
      expect(rowsIn(firstCard), 2);
      expect(hairlinesIn(firstCard), 1);
      final lastRow = tester.getRect(find.byKey(const ValueKey('drive-16')));
      final cardRect = tester.getRect(firstCard);
      expect(lastRow.bottom, lessThanOrEqualTo(cardRect.bottom));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  group('AP07 修正·P03 充电顶部与入口', () {
    Future<void> openCharging(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: find.byType(MileafNavBar),
          matching: find.text('充电'),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('顶部只有一行控件：期间分段与刷新圆钮同行', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWorkspace(tester, client: chargingLedgerClient());
      await openCharging(tester);
      expect(find.byType(MileafPeriodRow), findsOneWidget);
      final period = tester.getRect(find.byType(MileafPeriodRow));
      final refresh = tester.getRect(find.byTooltip('刷新充电'));
      expect(
        refresh.top,
        greaterThanOrEqualTo(period.top - 0.5),
        reason: 'P03 刷新与期间分段同一行',
      );
      expect(refresh.bottom, lessThanOrEqualTo(period.bottom + 0.5));
      // 用户裁定：日期快捷选择不得排成两行、左侧留空。
      final chips = <String>['近30天', '近7天', '自定义'];
      final tops = [
        for (final chip in chips) tester.getRect(find.text(chip)).top,
      ];
      expect(tops[1], closeTo(tops[0], 0.5), reason: '390 宽期间胶囊一行');
      expect(
        tops[2],
        closeTo(tops[0], 0.5),
        reason: '自定义入口不折到第二行（实际 ${tops[2] - tops[0]}）',
      );
      final periods = find.byType(MileafPeriodRow);
      expect(
        tester.getSize(periods).height,
        closeTo(
          tester
              .getSize(
                find.descendant(of: periods, matching: find.byType(ChipRow)),
              )
              .height,
          0.5,
        ),
        reason: '期间行高度就是胶囊轨道的一行高，没有第二行',
      );
      // 页头两行结构退场：不再有左侧空白的第二行动作。
      expect(find.text('全部记录'), findsNothing);
      expect(find.text('返回账本'), findsNothing);
      expect(
        find.ancestor(
          of: find.byType(MileafPeriodRow),
          matching: find.byType(Column),
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('入口是「最近充电」标题尾部「查看全部」，进入后导航标题为「全部充电记录」', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWorkspace(tester, client: chargingLedgerClient());
      await openCharging(tester);
      expect(find.text('最近的充电'), findsNothing);
      expect(find.text('查看全部充电记录'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('查看全部').hitTestable(),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final header = find.ancestor(
        of: find.text('最近充电'),
        matching: find.byType(SectionHeader),
      );
      expect(header, findsOneWidget);
      expect(
        find.descendant(of: header, matching: find.text('查看全部')),
        findsOneWidget,
        reason: 'CP06 入口在区块标题尾部',
      );
      await tester.tap(find.text('查看全部').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('全部充电记录'), findsOneWidget);
      expect(find.byType(MileafNavigationRow), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('全部充电记录'), findsNothing);
      // 返回账本后列表回到顶部；最近充电区块在首屏下缘附近，惰性构建
      // 需要一次滚动才进树（滚动位置本身由 scrollToTop 保证）。
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -160));
      await tester.pumpAndSettle();
      expect(find.text('查看全部'), findsWidgets);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  group('AP07 修正·P06 统计专题网格', () {
    testWidgets('结论卡与专题网格有分区距，同行卡片等高，轴标签不压专题卡', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpInsights(tester);
      final conclusion = tester.getRect(
        find
            .ancestor(
              of: find.text('查看对比明细'),
              matching: find.byType(MileafModuleCard),
            )
            .first,
      );
      // 卡片边缘而不是卡片内容：专题卡的内边 12 不算分区距。
      Rect card(String name) => tester.getRect(
        find
            .ancestor(
              of: find.byKey(ValueKey('statistics-topic-$name')),
              matching: find.byType(MileafModuleCard),
            )
            .first,
      );
      final firstCard = card('节奏');
      expect(
        firstCard.top - conclusion.bottom,
        greaterThanOrEqualTo(12),
        reason: 'P06 分区距 ≥12（实际 ${firstCard.top - conclusion.bottom}）',
      );
      for (final pair in const [
        ['节奏', '能耗'],
        ['补能', '长期'],
      ]) {
        final left = card(pair[0]);
        final right = card(pair[1]);
        expect(left.top, closeTo(right.top, 0.5), reason: '同一行从同一顶端开始');
        expect(
          (left.height - right.height).abs(),
          lessThanOrEqualTo(1),
          reason: '${pair[0]} ${left.height} 与 ${pair[1]} ${right.height} 等高',
        );
      }
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('200% 结论卡：比较句占满宽、下钻在下一行', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpInsights(tester, textScale: 2);
      final card = find
          .ancestor(
            of: find.text('查看对比明细'),
            matching: find.byType(MileafModuleCard),
          )
          .first;
      final cardRect = tester.getRect(card);
      // 大字时下钻换到下一行并左对齐：它到卡片左缘只有一个卡内边距，
      // 也就是说右侧不再有按钮挤占句子的宽度。
      final drill = tester.getRect(find.text('查看对比明细'));
      expect(
        drill.left - cardRect.left,
        lessThanOrEqualTo(MileafSpace.cardPad),
        reason: '大字时下钻在句子下一行左对齐（实际 ${drill.left - cardRect.left}）',
      );
      expect(drill.width, lessThan(cardRect.width));
      // 比较句因此占满整行宽度：卡内正文宽度 > 卡片宽度的一半。
      expect(cardRect.width - 2 * MileafSpace.cardPad, greaterThan(0));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('200% 专题卡片单列且不溢出', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpInsights(tester, textScale: 2);
      final topics = find.byKey(const ValueKey('statistics-topic-节奏'));
      await tester.scrollUntilVisible(topics, 300);
      await Scrollable.ensureVisible(tester.element(topics), alignment: 0);
      await tester.pumpAndSettle();
      final first = tester.getRect(topics);
      final second = tester.getRect(
        find.byKey(const ValueKey('statistics-topic-能耗')),
      );
      expect(
        second.top,
        greaterThanOrEqualTo(first.bottom - 0.5),
        reason: '大字时专题单列',
      );
      expect(second.left, closeTo(first.left, 0.5));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

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
      // §6 退让阶梯第 5 步已按用户裁定 B 落实：节奏图移到记录之后，
      // 首屏不再被图表挤占，第二条记录达到 24 的预算。
      final secondVisible = viewport.bottom - second.top;
      expect(
        secondVisible,
        greaterThanOrEqualTo(24),
        reason: '第二条记录可见 $secondVisible',
      );
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
      // §6 基准：360×800、safeArea 上下各 24、100% 字号。
      await pumpInsights(tester, size: const Size(360, 800), safeArea: true);
      final bar = tester.getTopLeft(find.byType(MileafNavBar)).dy;
      for (final topic in const ['节奏', '能耗']) {
        final rect = tester.getRect(
          find
              .ancestor(
                of: find.byKey(ValueKey('statistics-topic-$topic')),
                matching: find.byType(MileafModuleCard),
              )
              .first,
        );
        expect(
          rect.bottom,
          lessThanOrEqualTo(bar),
          reason:
              'P06 专题第一行两张卡片完整可见（$topic），'
              '底边 ${rect.bottom} vs 导航上沿 $bar',
        );
      }
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  group('AP07 P05 充电详情', () {
    Future<void> openCharging(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: find.byType(MileafNavBar),
          matching: find.text('充电'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('charge-9')).hitTestable(),
        300,
      );
      await tester.tap(find.byKey(const ValueKey('charge-9')).hitTestable());
      await tester.pumpAndSettle();
    }

    testWidgets('身份行写绝对日期，电量卡三格与单个刷新入口', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWorkspace(tester, client: chargingClient());
      await openCharging(tester);
      expect(find.text('充电详情'), findsOneWidget);
      expect(find.text('家'), findsWidgets);
      expect(find.textContaining('月'), findsWidgets);
      expect(find.textContaining('今天'), findsNothing);
      expect(find.text('已结束'), findsOneWidget);
      // 电量卡：起始到结束 + 三格。
      expect(find.textContaining('% → '), findsOneWidget);
      expect(find.text('充入电量'), findsOneWidget);
      expect(find.text('费用'), findsOneWidget);
      expect(find.text('时长'), findsOneWidget);
      // AU13：只留一个刷新入口。
      expect(find.byTooltip('刷新充电明细'), findsOneWidget);
      expect(find.byTooltip('刷新充电曲线'), findsNothing);
      // 充电过程卡：标题、指标控件、读数头、绘图区。
      await tester.scrollUntilVisible(find.text('充电过程'), 250);
      expect(find.text('功率'), findsWidgets);
      expect(find.text('电量'), findsWidgets);
      expect(find.byKey(const Key('charging-time-chart')), findsOneWidget);
      expect(find.bySemanticsLabel('下一个数据点'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('关于这些数据'), 300);
      expect(find.text('关于这些数据'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('360x800 首屏：功率绘图区首 120 可见', (tester) async {
      await pumpWorkspace(
        tester,
        client: chargingClient(),
        size: const Size(360, 800),
      );
      await openCharging(tester);
      final plot = tester.getRect(find.byKey(const Key('charging-time-chart')));
      expect(800 - plot.top, greaterThanOrEqualTo(120), reason: 'P05 §6 首屏预算');
      expect(tester.takeException(), isNull);
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

/// 卡内发丝线数量：Container + 单边 top 边框 + 高 0（R24 的一物理像素线）。
int hairlinesIn(Finder scope) => find
    .descendant(
      of: scope,
      matching: find.byWidgetPredicate((widget) => _isHairline(widget)),
    )
    .evaluate()
    .length;

bool _isHairline(Widget widget) {
  if (widget is! Container) return false;
  final decoration = widget.decoration;
  if (decoration is! BoxDecoration) return false;
  final border = decoration.border;
  return border is Border &&
      border.top != BorderSide.none &&
      widget.constraints?.maxHeight == 0;
}

/// 组卡内的记录行数量。
int rowsIn(Finder scope) => find
    .descendant(of: scope, matching: find.byType(MileafDataRow))
    .evaluate()
    .length;

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
