import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart' show StatusChip;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'charging_expansion_test.dart' show expansionResponse, chargingStatsV2;
import 'charging_test.dart' show jsonResponse;
import 'support/c_fixture.dart' show cEmptyChargingV2;
import 'support/statistics_insights_fixture.dart';
import 'statistics_test.dart' show openStats;

http.Response statisticsChargingResponse(http.Request request) {
  if (request.url.path.endsWith('/meta')) {
    final charging =
        jsonDecode(expansionResponse(request).body) as Map<String, dynamic>;
    final body = statisticsInsightsMeta()
      ..['charging_experience'] = charging['charging_experience'];
    return jsonResponse(body);
  }
  if (request.url.path.endsWith('/stats') &&
      request.url.queryParameters['kind'] == 'driving') {
    return jsonResponse(statisticsInsightsFixture(request.url));
  }
  return expansionResponse(request);
}

void main() {
  testWidgets('统计补能专题展示已有覆盖与有效均价而非旧均价', (tester) async {
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
    expect(find.text('充电费用'), findsOneWidget);
    expect(find.text('已记录费用'), findsOneWidget);
    expect(find.textContaining('8 次中 2 次有费用'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('充入均价 0.4'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('充入均价 0.4'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('充电方式'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('充电方式'), findsOneWidget);
  });
  testWidgets('统计地点账目以结束日和同一地点进入已有记录', (tester) async {
    final queries = <Map<String, String>>[];
    await openStats(
      tester,
      MockClient((request) async {
        if (request.url.path.endsWith('/charging-sessions')) {
          queries.add(request.url.queryParameters);
        }
        return statisticsChargingResponse(request);
      }),
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
    await tester.scrollUntilVisible(
      find.text('家 · 地库'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    // 字号增量后该行停在 800×600 视口下沿之外，滚动到“已构建”不等于可命中。
    await tester.ensureVisible(find.text('家 · 地库'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('家 · 地库').hitTestable());
    await tester.pumpAndSettle();
    expect(
      queries.any(
        (q) =>
            q['location_id'] == 'geofence:1' &&
            q['time_basis'] == 'ended_at' &&
            DateTime.parse(q['to']!) == DateTime.utc(2026, 3, 30, 12),
      ),
      isTrue,
    );
    expect(find.textContaining('地点：家 · 地库'), findsWidgets);
  });
  testWidgets('补能统计刷新失败保留快照且地点仍独立可读', (tester) async {
    var failing = false;
    await openStats(
      tester,
      MockClient((request) async {
        if (failing &&
            request.url.path.endsWith('/stats') &&
            request.url.queryParameters['kind'] == 'charging') {
          return http.Response(
            '{"error":{"code":"db_unavailable","message":"unavailable"}}',
            503,
          );
        }
        return statisticsChargingResponse(request);
      }),
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
    failing = true;
    await tester.tap(find.byTooltip('刷新补能统计'));
    await tester.pumpAndSettle();
    expect(find.textContaining('保留上次快照'), findsOneWidget);
    expect(find.textContaining('8 次中 2 次有费用'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('家 · 地库'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('家 · 地库'), findsOneWidget);
  });
  testWidgets('有充电但时长全缺时不把分类时长显示为零', (tester) async {
    await openStats(
      tester,
      MockClient((request) async {
        if (request.url.path.endsWith('/stats') &&
            request.url.queryParameters['kind'] == 'charging') {
          final body = chargingStatsV2();
          final total = body['totals'] as Map<String, dynamic>;
          total['duration_known_sessions'] = 0;
          total['duration_min_total'] = 0;
          total['ac_duration_min'] = 0;
          total['dc_duration_min'] = 0;
          total['unknown_duration_min'] = 0;
          return jsonResponse(body);
        }
        return statisticsChargingResponse(request);
      }),
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
    await tester.scrollUntilVisible(
      find.text('分类记录时长缺失'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('分类记录时长缺失'), findsOneWidget);
  });
  testWidgets('补能日图下钻冻结同一结束日边界', (tester) async {
    final queries = <Map<String, String>>[];
    await openStats(
      tester,
      MockClient((request) async {
        if (request.url.path.endsWith('/charging-sessions')) {
          queries.add(request.url.queryParameters);
        }
        return statisticsChargingResponse(request);
      }),
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
    await tester.scrollUntilVisible(
      find.text('查看此期间补能').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('查看此期间补能'));
    await tester.pumpAndSettle();
    expect(
      queries.any(
        (q) =>
            q['time_basis'] == 'ended_at' &&
            DateTime.parse(q['from']!) == DateTime.utc(2026, 3, 27) &&
            DateTime.parse(q['to']!) == DateTime.utc(2026, 3, 28),
      ),
      isTrue,
    );
  });
  testWidgets('补能专题360宽深色200%可切图并读取有效均价', (tester) async {
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
    // P09：可见短词「均价」，完整口径由图标题保留（原 ChoiceChip 定位更新）。
    final metric = find.widgetWithText(StatusChip, '均价').hitTestable();
    await tester.scrollUntilVisible(
      metric,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(metric);
    await tester.pumpAndSettle();
    expect(find.text('充入均价'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('补能专题 0 条记录走空态而不是 — + 0 / 0 次', (tester) async {
    await openStats(
      tester,
      MockClient((request) async {
        if (request.url.path.endsWith('/stats') &&
            request.url.queryParameters['kind'] == 'charging') {
          return jsonResponse(cEmptyChargingV2());
        }
        return statisticsChargingResponse(request);
      }),
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
    expect(find.text('这段时间没有充电记录'), findsOneWidget);
    // MG09：空态带四档分档的建议动作（刷新）。
    expect(find.text('刷新'), findsOneWidget);
    expect(find.text('已知支出 · 覆盖同时看'), findsNothing);
    expect(find.textContaining('费用有记录 0 / 0'), findsNothing);
    expect(find.text('充电方式'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
