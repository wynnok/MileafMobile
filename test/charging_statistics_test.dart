import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'statistics_test.dart' show openStats, fixture, custom, tapDateAction;

import 'package:mileaf/src/design/components/components.dart';

import 'charging_test.dart' show MemoryCurrency, app;

void main() {
  testWidgets('充电图表保留零费用和缺失均价，并可读取AC/DC时间分布', (tester) async {
    final requests = <http.Request>[];
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      requests.add(r);
      if (r.url.queryParameters['kind'] == 'driving') {
        return fixture('driving-stats');
      }
      final body =
          jsonDecode(fixture('charging-stats').body) as Map<String, dynamic>;
      body['buckets'][0]['cost'] = 0;
      body['buckets'][0]['cost_per_kwh'] = 0;
      body['buckets'][1]['cost'] = null;
      body['buckets'][1]['cost_per_kwh'] = null;
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 4, 2),
      () => 'Asia/Shanghai',
    );
    await tester.tap(find.text('充电统计'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(StatusChip, '均价'), findsOneWidget);
    final count = requests.length;
    await tester.tap(find.widgetWithText(StatusChip, '均价'));
    await tester.pumpAndSettle();
    expect(find.text('均价读数 0/kWh'), findsOneWidget);
    await tester.drag(find.text('已知费用均价趋势'), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('statistics-charging-next')));
    await tester.pumpAndSettle();
    expect(find.text('均价读数 —/kWh'), findsOneWidget);
    expect(requests.length, count);
    await tester.scrollUntilVisible(find.text('AC / DC 时间分布'), 200);
    expect(find.text('AC / DC 时间分布'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('DC读数 0.00 kWh'), 150);
    expect(find.text('AC读数 20.00 kWh'), findsOneWidget);
    expect(find.text('DC读数 0.00 kWh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('充电统计360宽200%深色，零费用与缺失均价占比不同且桶读数可访问', (tester) async {
    // 语义标签校验需要启用 semantics 树。
    final semantics = tester.ensureSemantics();
    try {
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
      var missingCost = false;
      final client = MockClient((r) async {
        if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
        if (r.url.path.endsWith('/summary')) return fixture('summary');
        if (r.url.queryParameters['kind'] == 'driving') {
          return fixture('driving-stats');
        }
        final body = jsonDecode(
          File('test/fixtures/charging-stats.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        body['totals'] = {
          'sessions': 0,
          'energy_added_kwh': 0,
          'cost': missingCost ? null : 0,
          'cost_per_kwh': null,
          'ac_energy_kwh': 0,
          'dc_energy_kwh': 0,
          'dc_energy_share': null,
        };
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      await openStats(
        tester,
        client,
        () => DateTime.utc(2026, 5, 15, 12),
        () => 'UTC',
      );
      await tester.tap(find.text('充电统计'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('已知费用合计 0'), findsOneWidget);
      expect(find.text('币种未记录'), findsWidgets);
      await tester.scrollUntilVisible(find.text('DC 能量占比（已知分类）  —'), 200);
      await tester.pumpAndSettle();
      expect(find.text('DC 能量占比（已知分类）  —'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('已知费用均价  —/kWh'), 60);
      await tester.pumpAndSettle();
      expect(find.text('已知费用均价  —/kWh'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('2025-12-31 · 20.00 kWh'), 250);
      await tester.pumpAndSettle();
      await tester.tap(find.text('2025-12-31 · 20.00 kWh'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('会话数  1 次'), 200);
      await tester.pumpAndSettle();
      expect(find.text('会话数  1 次'), findsOneWidget);
      expect(tester.takeException(), isNull);
      missingCost = true;
      await tester.scrollUntilVisible(find.text('充电结果'), -400);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('刷新统计'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('已知费用合计 —'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('充电复用DST和跨度校验，恢复前台只校验当前kind', (tester) async {
    final requests = <http.Request>[];
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
      if (r.url.path.endsWith('/summary')) return fixture('summary');
      requests.add(r);
      return fixture(
        r.url.queryParameters['kind'] == 'charging'
            ? 'charging-stats'
            : 'driving-stats',
      );
    });
    await openStats(
      tester,
      client,
      () => DateTime.utc(2026, 12, 15, 12),
      () => 'America/New_York',
    );
    await tester.tap(find.text('充电统计'));
    await tester.pumpAndSettle();
    await custom(tester, '2026-03-08', '2026-03-08');
    expect(requests.last.url.queryParameters['kind'], 'charging');
    expect(
      requests.last.url.queryParameters['from'],
      '2026-03-08T05:00:00.000Z',
    );
    expect(requests.last.url.queryParameters['to'], '2026-03-09T04:00:00.000Z');
    final count = requests.length;
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
    expect(
      requests.skip(count).map((r) => r.url.queryParameters['kind']).toList(),
      ['charging'],
    );
    await tester.tap(find.textContaining('2026-03-08 至 2026-03-08'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, '开始日期'),
      '2020-01-01',
    );
    await tester.tap(find.text('应用区间'));
    await tester.pumpAndSettle();
    expect(find.textContaining('不超过 730×24 小时'), findsOneWidget);
    expect(requests.length, count + 1);
  });

  testWidgets('两种统计区间独立、条件304与充电失败不抹掉驾驶成功结果', (tester) async {
    // 语义标签校验需要启用 semantics 树。
    final semantics = tester.ensureSemantics();
    try {
      final requests = <http.Request>[];
      var fail = false;
      final client = MockClient((r) async {
        if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
        if (r.url.path.endsWith('/summary')) return fixture('summary');
        requests.add(r);
        if (r.url.queryParameters['kind'] == 'charging' && fail) {
          return http.Response('', 503);
        }
        if (r.headers['if-none-match'] != null) return http.Response('', 304);
        return http.Response(
          File(
            'test/fixtures/${r.url.queryParameters['kind'] == 'charging' ? 'charging' : 'driving'}-stats.json',
          ).readAsStringSync(),
          200,
          headers: {
            'content-type': 'application/json; charset=utf-8',
            'etag': '"${r.url.queryParameters['kind']}"',
            'cache-control': 'max-age=30',
          },
        );
      });
      await openStats(
        tester,
        client,
        () => DateTime.utc(2026, 3, 15, 12),
        () => 'UTC',
      );
      await tapDateAction(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(ActionChip, '本年'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('充电统计'));
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['bucket'], 'day');
      await custom(tester, '2026-03-01', '2026-03-02');
      expect(
        requests.last.url.queryParameters['to'],
        '2026-03-03T00:00:00.000Z',
      );
      await tester.tap(find.byTooltip('刷新统计'));
      await tester.pumpAndSettle();
      expect(requests.last.headers['if-none-match'], '"charging"');
      fail = true;
      await tester.tap(find.byTooltip('刷新统计'));
      await tester.pumpAndSettle();
      expect(find.textContaining('保留上次快照'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('会话数  8 次'), 250);
      await tester.pumpAndSettle();
      expect(find.text('会话数  8 次'), findsOneWidget);
      await tester.tap(find.text('驾驶统计'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('行程数 49 次'), findsOneWidget);
      expect(find.textContaining('保留上次快照'), findsNothing);
      expect(
        find.widgetWithText(StatusChip, '本年'),
        findsOneWidget,
        reason: '驾驶统计沿用同一年区间，控件显示当前为 本年',
      );
      await tester.tap(find.text('充电统计'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('2026-03-01 至 2026-03-02'),
        -250,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('2026-03-01 至 2026-03-02'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('会话数  8 次'), 250);
      await tester.pumpAndSettle();
      expect(find.text('会话数  8 次'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('驾驶响应迟到不污染充电视图，切车后旧充电不覆盖新车', (tester) async {
    // 语义标签校验需要启用 semantics 树。
    final semantics = tester.ensureSemantics();
    try {
      final drive = Completer<http.Response>(),
          charge = Completer<http.Response>();
      var pendingCharge = false;
      final client = MockClient((r) async {
        if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
        if (r.url.path.endsWith('/summary')) return fixture('summary');
        if (r.url.path.contains('/1/') &&
            r.url.queryParameters['kind'] == 'driving') {
          return drive.future;
        }
        if (r.url.path.contains('/1/') && pendingCharge) return charge.future;
        final body = jsonDecode(
          File('test/fixtures/charging-stats.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        if (r.url.path.contains('/2/')) body['totals']['sessions'] = 3;
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      // The initial driving request stays pending; use pump rather than waiting on its spinner.
      await tester.pumpWidget(app(client));
      await tester.pumpAndSettle();
      await tester.tap(find.text('统计'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('充电统计'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('会话数  8 次'), 250);
      await tester.pumpAndSettle();
      expect(find.text('会话数  8 次'), findsOneWidget);
      drive.complete(fixture('driving-stats'));
      await tester.pumpAndSettle();
      expect(find.text('会话数  8 次'), findsOneWidget);
      // 回到顶部：迟到的驾驶响应不得污染充电总计，刷新入口也需可见。
      await tester.scrollUntilVisible(find.byTooltip('刷新统计'), -250);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('行程数 49 次'), findsNothing);
      expect(find.bySemanticsLabel('充入电池能量 160.00 kWh'), findsOneWidget);
      pendingCharge = true;
      await tester.tap(find.byTooltip('刷新统计'));
      await tester.pump();
      await tester.tap(find.text('行笺测试车'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Y · 尾号 0002'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('充电统计'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('会话数  3 次'), 250);
      await tester.pumpAndSettle();
      expect(find.text('会话数  3 次'), findsOneWidget);
      charge.complete(fixture('charging-stats'));
      await tester.pumpAndSettle();
      expect(find.text('会话数  8 次'), findsNothing);
      expect(find.text('会话数  3 次'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('站点币种更改仅标签，重新进入统计共享设置且数值不换汇', (tester) async {
    // 语义标签校验需要启用 semantics 树。
    final semantics = tester.ensureSemantics();
    try {
      final preferences = MemoryCurrency();
      final client = MockClient((r) async {
        if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
        if (r.url.path.endsWith('/summary')) return fixture('summary');
        return fixture(
          r.url.queryParameters['kind'] == 'charging'
              ? 'charging-stats'
              : 'driving-stats',
        );
      });
      await tester.pumpWidget(app(client, currency: preferences));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('币种'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('USD'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('统计'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('充电统计'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('已知费用合计 72 USD'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('已知费用均价  0.51 USD/kWh'), 250);
      await tester.pumpAndSettle();
      expect(find.text('已知费用均价  0.51 USD/kWh'), findsOneWidget);
      expect(preferences.values, {'https://example.com/prefix': 'USD'});
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('切换充电统计独立请求并直接展示真实totals和未知币种', (tester) async {
    // 语义标签校验需要启用 semantics 树。
    final semantics = tester.ensureSemantics();
    try {
      final kinds = <String>[];
      final client = MockClient((r) async {
        if (r.url.path.endsWith('/vehicles')) return fixture('vehicles');
        if (r.url.path.endsWith('/summary')) return fixture('summary');
        final kind = r.url.queryParameters['kind']!;
        kinds.add(kind);
        return fixture(kind == 'charging' ? 'charging-stats' : 'driving-stats');
      });
      await openStats(
        tester,
        client,
        () => DateTime.utc(2026, 3, 15, 12),
        () => 'Asia/Shanghai',
      );
      expect(kinds, ['driving']);
      await tester.tap(find.text('充电统计'));
      await tester.pumpAndSettle();
      expect(kinds, ['driving', 'charging']);
      expect(find.bySemanticsLabel('充入电池能量 160.00 kWh'), findsOneWidget);
      expect(find.bySemanticsLabel('已知费用合计 72'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('DC 能量占比（已知分类）  14.29 %'), 250);
      await tester.pumpAndSettle();
      expect(find.text('DC 能量占比（已知分类）  14.29 %'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('会话数  8 次'), 250);
      await tester.pumpAndSettle();
      expect(find.text('会话数  8 次'), findsOneWidget);
      expect(find.text('已知费用均价  0.51/kWh'), findsOneWidget);
      expect(find.text('按结束时间归期 · 仅统计已结束充电'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
}
