import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'charging_test.dart' show app, chargingFixture, initial, jsonResponse;
import 'overview_test.dart' show background, foreground;

Map<String, dynamic> chargingStatsV2() {
  final stats = jsonDecode(
    File('test/fixtures/charging-stats.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  Map<String, dynamic> enrich(Map<String, dynamic> item) => {
    ...item,
    'energy_known_sessions': item['sessions'] == 8 ? 7 : item['sessions'],
    'cost_known_sessions': 2,
    'cost_known_energy_kwh': 30.0,
    'duration_min_total': 125.0,
    'duration_known_sessions': 3,
    'classification_known_sessions': 7,
    'unknown_energy_kwh': 20.0,
    'ac_duration_min': 90.0,
    'dc_duration_min': 35.0,
    'unknown_duration_min': 0.0,
    'unit_cost_added': {
      'value': 0.4,
      'numerator_cost': 12.0,
      'denominator_kwh': 30.0,
      'eligible_sessions': 1,
      'excluded_cost_sessions': 1,
    },
    'unit_cost_grid': {
      'value': null,
      'numerator_cost': 0.0,
      'denominator_kwh': 0.0,
      'eligible_sessions': 0,
      'excluded_cost_sessions': 2,
    },
  };
  stats['totals'] = {
    ...enrich(stats['totals'] as Map<String, dynamic>),
    'cost_per_kwh': 2.4,
  };
  const cost = <double?>[null, 12, 60, 0];
  const knownCost = [0, 1, 1, 0];
  const knownEnergy = [1, 2, 4, 0];
  const pairedEnergy = [0.0, 30.0, 0.0, 0.0];
  const duration = [15.0, 30.0, 80.0, 0.0];
  const durationKnown = [1, 1, 1, 0];
  const knownClass = [1, 2, 4, 0];
  const unknownEnergy = [0.0, 0.0, 20.0, 0.0];
  const acDuration = [15.0, 0.0, 75.0, 0.0];
  const dcDuration = [0.0, 30.0, 5.0, 0.0];
  stats['buckets'] = (stats['buckets'] as List)
      .asMap()
      .entries
      .map(
        (entry) => {
          ...enrich(entry.value as Map<String, dynamic>),
          'cost': cost[entry.key],
          'cost_per_kwh': entry.key == 1 ? 0.4 : null,
          'cost_known_sessions': knownCost[entry.key],
          'energy_known_sessions': knownEnergy[entry.key],
          'cost_known_energy_kwh': pairedEnergy[entry.key],
          'duration_min_total': duration[entry.key],
          'duration_known_sessions': durationKnown[entry.key],
          'classification_known_sessions': knownClass[entry.key],
          'unknown_energy_kwh': unknownEnergy[entry.key],
          'ac_duration_min': acDuration[entry.key],
          'dc_duration_min': dcDuration[entry.key],
          'unit_cost_added': {
            'value': entry.key == 1 ? 0.4 : null,
            'numerator_cost': entry.key == 1 ? 12.0 : 0.0,
            'denominator_kwh': pairedEnergy[entry.key],
            'eligible_sessions': entry.key == 1 ? 1 : 0,
            'excluded_cost_sessions': entry.key == 2 ? 1 : 0,
          },
          'unit_cost_grid': {
            'value': null,
            'numerator_cost': 0.0,
            'denominator_kwh': 0.0,
            'eligible_sessions': 0,
            'excluded_cost_sessions': knownCost[entry.key],
          },
          'bucket_start': DateTime.utc(
            2026,
            3,
            27 + entry.key,
          ).toIso8601String(),
        },
      )
      .toList();
  stats['query'] = chargingQuery();
  stats['as_of'] = '2026-03-30T12:00:00Z';
  return stats;
}

Map<String, dynamic> chargingQuery() => {
  'from': '2026-03-01T00:00:00Z',
  'to': '2026-03-30T12:00:00Z',
  'tz': 'UTC',
  'time_basis': 'ended_at',
  'filters': {
    'charging_type': null,
    'cost_status': null,
    'location_id': null,
    'query': null,
  },
};

Map<String, dynamic> chargingPageV2() {
  final page = chargingFixture();
  page['items'] = (page['items'] as List)
      .map(
        (v) => {
          ...(v as Map<String, dynamic>),
          'location_id': 'geofence:1',
          'location': {
            'display_name': '家 · 地库',
            'geofence': '家 · 地库',
            'address': null,
            'lat': null,
            'lon': null,
          },
          if (v['id'] == 9) ...{
            'started_at': '2026-03-28T23:10:00Z',
            'ended_at': '2026-03-29T03:30:00Z',
            'duration_min': 260,
          },
        },
      )
      .toList();
  page.addAll({
    'matched_sessions': (page['items'] as List).length,
    'query': chargingQuery(),
    'as_of': '2026-03-30T12:00:00Z',
  });
  return page;
}

http.Response expansionResponse(http.Request request) {
  if (request.url.path.endsWith('/meta')) {
    return jsonResponse({
      'version': '0.2.0',
      'charging_experience': {
        'contract_version': 'charging-experience-v1',
        'minimum_server_version': '0.2.0',
        'tested_schema_version': 20260808090000,
        'fields': <String, bool>{},
      },
    });
  }
  if (request.url.path.endsWith('/charging-locations')) {
    final totals = chargingStatsV2()['totals'] as Map<String, dynamic>;
    return jsonResponse({
      'items': [
        {
          ...totals,
          'location_id': 'geofence:1',
          'identity_kind': 'geofence',
          'location': {
            'display_name': '家 · 地库',
            'geofence': '家 · 地库',
            'address': null,
            'lat': null,
            'lon': null,
          },
          'representative_session_id': 9,
          'coordinate_source': null,
        },
      ],
      'next_cursor': null,
      'total_locations': 1,
      'unlocated_sessions': 0,
      'query': chargingQuery(),
      'as_of': '2026-03-30T12:00:00Z',
    });
  }
  if (request.url.path.endsWith('/charging-sessions')) {
    final page = chargingPageV2();
    if (request.url.queryParameters['time_basis'] == 'ended_at') {
      page['items'] = (page['items'] as List)
          .where((item) => (item as Map<String, dynamic>)['ended_at'] != null)
          .toList();
      page['matched_sessions'] = (page['items'] as List).length;
    }
    return jsonResponse(page);
  }
  if (request.url.path.endsWith('/stats') &&
      request.url.queryParameters['kind'] == 'charging') {
    return jsonResponse(chargingStatsV2());
  }
  return initial(request);
}

Map<String, dynamic> detailV2() {
  final result = jsonDecode(
    File('test/fixtures/charging-detail.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  result.addAll({
    'started_at': '2026-01-05T08:00:00Z',
    'ended_at': '2026-01-05T08:34:00Z',
    'duration_min': 34,
    'energy_added_kwh': 46.8,
    'energy_used_kwh': 49.5,
    'start_soc': 18,
    'end_soc': 82,
    'start_battery_level': 18,
    'end_battery_level': 82,
    'cost': 71.28,
    'is_dc': true,
    'outside_temp_c_avg': 23.4,
    'location_id': 'geofence:1',
    'unit_cost_added': {
      'value': 1.5230769,
      'numerator_cost': 71.28,
      'denominator_kwh': 46.8,
      'eligible_sessions': 1,
      'excluded_cost_sessions': 0,
    },
    'unit_cost_grid': {
      'value': 1.44,
      'numerator_cost': 71.28,
      'denominator_kwh': 49.5,
      'eligible_sessions': 1,
      'excluded_cost_sessions': 0,
    },
    'start_rated_range_km': 82.0,
    'end_rated_range_km': 374.0,
    'charger': {
      'fast_charger_present': true,
      'fast_charger_brand': 'Tesla',
      'fast_charger_type': 'CCS',
      'conn_charge_cable': null,
      'source_sample_at': '2026-01-05T08:34:00Z',
    },
    'capabilities': {
      'fields': {'voltage_v': true, 'battery_heater_on': true},
    },
    'process_metrics': {
      'power_max_kw': 175.0,
      'power_valid_samples': 24,
      'power_time_weighted_kw': 87.4,
      'observed_seconds': 1800.0,
      'uncovered_seconds': 240.0,
      'soc_windows': [
        {
          'start_at': '2026-01-05T08:01:00Z',
          'end_at': '2026-01-05T08:29:00Z',
          'elapsed_seconds': 1680.0,
          'start_observed_soc': 22,
          'end_observed_soc': 81,
          'status': 'available',
          'reason': null,
          'threshold_precision': 'crossed',
          'observed_seconds': 1680.0,
          'uncovered_seconds': 0.0,
        },
      ],
    },
  });
  return result;
}

Map<String, dynamic> seriesV2() {
  final result = jsonDecode(
    File('test/fixtures/charging-series.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  result.addAll({
    'points': 14,
    'series': [
      for (final (index, entry) in const [
        (0, 8, 18),
        (1, 164, 22),
        (3, 166, 27),
        (5, 150, 34),
        (8, 132, 43),
        (11, 115, 51),
        (14, 96, 58),
        (17, 79, 64),
        (20, 65, 69),
        (23, 54, 73),
        (26, 42, 77),
        (29, 32, 81),
        (32, 22, 81),
        (34, 0, 82),
      ].indexed)
        {
          't': DateTime.utc(2026, 1, 5, 8, entry.$1).toIso8601String(),
          'power': entry.$2,
          'soc': entry.$3,
          'voltage_v': 370 + index * 2,
          if (index == 5) 'voltage_v': null,
        },
    ],
    'capabilities': {
      'fields': {'voltage_v': true, 'battery_heater_on': true},
    },
    'as_of': '2026-03-30T12:00:00Z',
    'state_events': {
      'events': [
        {
          't': '2026-01-05T08:01:00Z',
          'field': 'battery_heater_on',
          'value': true,
        },
      ],
      'total_events': 1,
      'truncated': false,
    },
  });
  return result;
}

void main() {
  testWidgets('充电主页读取已完成统计并展示费用覆盖和配对均价', (tester) async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return expansionResponse(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();

    expect(find.textContaining('费用有记录 2 / 8'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('有效入电均价 0.4')), findsOneWidget);
    expect(
      requests.any(
        (url) =>
            url.path.endsWith('/stats') &&
            url.queryParameters['kind'] == 'charging' &&
            url.queryParameters['time_basis'] == 'ended_at',
      ),
      isTrue,
    );
  });

  testWidgets('地点搜索应用到列表、统计和地点的完整结束日查询', (tester) async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return expansionResponse(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部记录'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('charging-search')),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.enterText(find.byKey(const Key('charging-search')), '家');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    for (final suffix in [
      '/charging-sessions',
      '/stats',
      '/charging-locations',
    ]) {
      expect(
        requests.any(
          (url) =>
              url.path.endsWith(suffix) &&
              url.queryParameters['query'] == '家' &&
              url.queryParameters['time_basis'] == 'ended_at' &&
              url.queryParameters['tz'] == 'UTC',
        ),
        isTrue,
        reason: suffix,
      );
    }
  });

  testWidgets('充电详情显示原始峰值、覆盖及实际SOC阈值端点', (tester) async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      if (request.url.path.endsWith('/charging-sessions/1')) {
        return jsonResponse(detailV2());
      }
      if (request.url.path.endsWith('/charging-sessions/1/series')) {
        return jsonResponse(seriesV2());
      }
      if (request.url.path.endsWith('/summary')) {
        final body = jsonDecode(initial(request).body) as Map<String, dynamic>;
        (body['last_charge'] as Map<String, dynamic>)['id'] = 1;
        return jsonResponse(body);
      }
      return expansionResponse(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('最近充电').hitTestable(), 300);
    await tester.tap(find.text('最近充电').hitTestable());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('过程数据说明').hitTestable(), 200);
    await tester.tap(find.text('过程数据说明').hitTestable());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('原始功率峰值'), 200);
    expect(find.textContaining('原始功率峰值 175'), findsOneWidget);
    expect(find.textContaining('记录平均功率 87.4'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('记录跨越 22% → 81%'), 200);
    expect(find.textContaining('记录跨越 22% → 81%'), findsOneWidget);
    expect(
      requests.any(
        (url) =>
            url.path.endsWith('/charging-sessions/1/series') &&
            (url.queryParameters['fields']?.contains('voltage_v') ?? false),
      ),
      isTrue,
    );
    await tester.scrollUntilVisible(find.text('按电量').hitTestable(), -200);
    await tester.tap(find.text('按电量').hitTestable());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('charging-soc-chart')), findsOneWidget);
    expect(find.textContaining('横轴为电量'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('电池加热状态变化').hitTestable(), 200);
    await tester.tap(find.text('电池加热状态变化').hitTestable());
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('charging-heater-battery_heater_on')),
      findsOneWidget,
    );
  });

  testWidgets('进行中充电独立于按结束日统计和列表', (tester) async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return expansionResponse(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    expect(find.textContaining('正在充电'), findsOneWidget);
    expect(
      requests.any(
        (url) =>
            url.path.endsWith('/charging-sessions') &&
            url.queryParameters['time_basis'] == 'started_at',
      ),
      isTrue,
    );
    expect(find.textContaining('费用有记录 2 / 8'), findsOneWidget);
  });

  testWidgets('车辆已离线时不把未结束会话当成正在充电', (tester) async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      if (request.url.path.endsWith('/summary')) {
        final body = jsonDecode(initial(request).body) as Map<String, dynamic>;
        body['state'] = {'value': 'offline', 'since': '2026-03-30T09:00:00Z'};
        return jsonResponse(body);
      }
      return expansionResponse(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    expect(
      requests.any((url) => url.path.endsWith('/summary')),
      isTrue,
      reason: '充电页必须用车辆状态确认此刻是否真的在充电',
    );
    expect(find.textContaining('正在充电'), findsNothing);
    expect(find.textContaining('不计入已完成统计'), findsNothing);
    expect(find.textContaining('费用有记录 2 / 8'), findsOneWidget);
  });

  testWidgets('无法确认车辆状态时不显示正在充电', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/summary')) {
        return http.Response('unavailable', 503);
      }
      return expansionResponse(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    expect(find.textContaining('正在充电'), findsNothing);
  });

  testWidgets('概览读过的车辆状态切到充电页不重复请求', (tester) async {
    var summaries = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/summary')) {
        summaries++;
        // 站点声明 max-age 时两个页面共用同一个缓存键。
        return http.Response(
          initial(request).body,
          200,
          headers: {
            'content-type': 'application/json; charset=utf-8',
            'cache-control': 'max-age=30',
          },
        );
      }
      return expansionResponse(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    expect(summaries, 1);
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    expect(summaries, 1, reason: '同一 summary 缓存键应命中，不重复请求');
    expect(find.textContaining('正在充电'), findsOneWidget);
  });

  testWidgets('下拉刷新绕过缓存重读车辆状态', (tester) async {
    var summaries = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/summary')) {
        summaries++;
        return http.Response(
          initial(request).body,
          200,
          headers: {
            'content-type': 'application/json; charset=utf-8',
            'cache-control': 'max-age=30',
          },
        );
      }
      return expansionResponse(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    final before = summaries;
    await tester.fling(find.byType(ListView).first, const Offset(0, 350), 1200);
    await tester.pumpAndSettle();
    expect(summaries, greaterThan(before), reason: '下拉刷新必须绕过 max-age 重读车辆状态');
  });

  testWidgets('充电统计使用配对有效均价而非旧口径', (tester) async {
    final client = MockClient((request) async => expansionResponse(request));
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('统计'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电统计'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('有效入电均价'), 200);
    expect(find.textContaining('有效入电均价  0.4'), findsOneWidget);
    expect(find.textContaining('费用有记录 2 / 8'), findsOneWidget);
  });

  testWidgets('结束日图表下钻保留跨午夜充电', (tester) async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return expansionResponse(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    // C04: the chart opens on the latest bucket with charging, which is the
    // cross-midnight 结束日 this test drills into.
    await tester.scrollUntilVisible(find.text('看当天').hitTestable(), 200);
    await tester.tap(find.text('看当天').hitTestable());
    await tester.pumpAndSettle();
    final query = requests
        .lastWhere(
          (url) =>
              url.path.endsWith('/charging-sessions') &&
              url.queryParameters['time_basis'] == 'ended_at',
        )
        .queryParameters;
    expect(query['from'], '2026-03-29T00:00:00.000Z');
    expect(query['to'], '2026-03-30T00:00:00.000Z');
    await tester.scrollUntilVisible(
      find.textContaining('仅看 2026年3月29日'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('仅看 2026年3月29日'), findsOneWidget);
    expect(find.textContaining('2026-03-28 23:10'), findsOneWidget);
  });

  testWidgets('地点账目点击后以稳定地点键查询整个匹配集', (tester) async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return expansionResponse(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, '家 · 地库').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(ListTile, '家 · 地库').hitTestable());
    await tester.pumpAndSettle();
    for (final suffix in [
      '/charging-sessions',
      '/stats',
      '/charging-locations',
    ]) {
      expect(
        requests.any(
          (url) =>
              url.path.endsWith(suffix) &&
              url.queryParameters['location_id'] == 'geofence:1' &&
              url.queryParameters['time_basis'] == 'ended_at',
        ),
        isTrue,
        reason: suffix,
      );
    }
  });

  testWidgets('0.1站点保留旧记录并说明新增能力不可用', (tester) async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      if (request.url.path.endsWith('/meta')) {
        return jsonResponse({'version': '0.1.0'});
      }
      if (request.url.path.endsWith('/charging-sessions')) {
        return jsonResponse(chargingFixture());
      }
      if (request.url.path.endsWith('/stats') &&
          request.url.queryParameters['kind'] == 'charging') {
        return http.Response(
          File('test/fixtures/charging-stats.json').readAsStringSync(),
          200,
        );
      }
      return initial(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    expect(find.textContaining('未提供充电扩展能力'), findsOneWidget);
    expect(find.byKey(const Key('charging-search')), findsNothing);
    expect(
      requests.any((url) => url.path.endsWith('/charging-locations')),
      isFalse,
    );
    expect(
      requests
          .where((url) => url.path.endsWith('/charging-sessions'))
          .every((url) => !url.queryParameters.containsKey('time_basis')),
      isTrue,
    );
  });

  testWidgets('统计失败不遮挡记录和地点', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/stats') &&
          request.url.queryParameters['time_basis'] == 'ended_at') {
        return http.Response('', 503);
      }
      return expansionResponse(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    expect(find.textContaining('充电统计暂时不可用'), findsOneWidget);
    await tester.tap(find.text('全部记录'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('charge-9')).hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('charge-9')), findsOneWidget);
  });

  testWidgets('旧查询统计迟到不会覆盖新地点搜索结果', (tester) async {
    final oldStats = Completer<http.Response>();
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/stats') &&
          request.url.queryParameters['time_basis'] == 'ended_at') {
        if (request.url.queryParameters['query'] == null) {
          return oldStats.future;
        }
        final body = chargingStatsV2();
        (body['totals'] as Map<String, dynamic>)['cost_known_sessions'] = 1;
        (body['totals'] as Map<String, dynamic>)['sessions'] = 1;
        return jsonResponse(body);
      }
      return expansionResponse(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('全部记录'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('charging-search')), '家');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('返回账本').hitTestable(),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('返回账本').hitTestable());
    await tester.pumpAndSettle();
    expect(find.textContaining('费用有记录 1 / 1'), findsOneWidget);
    oldStats.complete(jsonResponse(chargingStatsV2()));
    await tester.pumpAndSettle();
    expect(find.textContaining('费用有记录 1 / 1'), findsOneWidget);
    expect(find.textContaining('费用有记录 2 / 8'), findsNothing);
  });

  testWidgets('全缺失不显示成零，明确免费保留真实零值', (tester) async {
    var free = false;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/stats') &&
          request.url.queryParameters['time_basis'] == 'ended_at') {
        final body = chargingStatsV2();
        final totals = body['totals'] as Map<String, dynamic>;
        totals.addAll({
          'cost': free ? 0 : null,
          'cost_known_sessions': free ? 2 : 0,
          'cost_known_energy_kwh': free ? 10 : 0,
          'energy_added_kwh': free ? 10 : 0,
          'energy_known_sessions': free ? 8 : 0,
          'duration_min_total': 0,
          'duration_known_sessions': free ? 8 : 0,
          'unit_cost_added': {
            'value': free ? 0 : null,
            'numerator_cost': 0,
            'denominator_kwh': free ? 10 : 0,
            'eligible_sessions': free ? 2 : 0,
            'excluded_cost_sessions': 0,
          },
        });
        return jsonResponse(body);
      }
      return expansionResponse(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    expect(find.textContaining('费用有记录 0 / 8'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('补入电池'), 160);
    expect(find.bySemanticsLabel(RegExp('补入电池 —')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('记录时长 —.*非等待时间')), findsOneWidget);
    free = true;
    final refresh = find.byTooltip('刷新充电');
    await tester.scrollUntilVisible(refresh, -160);
    await Scrollable.ensureVisible(tester.element(refresh), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r'有效入电均价 0')), findsOneWidget);
    await tester.scrollUntilVisible(find.text('记录时长'), 160);
    expect(find.bySemanticsLabel(RegExp('记录时长 0 分钟.*非等待时间')), findsOneWidget);
  });

  testWidgets('地点分页失败保留已有组并从原游标重试', (tester) async {
    var failMore = true;
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      if (request.url.path.endsWith('/charging-locations')) {
        final cursor = request.url.queryParameters['cursor'];
        if (cursor == 'group-cursor' && failMore) return http.Response('', 503);
        final body =
            jsonDecode(expansionResponse(request).body) as Map<String, dynamic>;
        body['total_locations'] = 2;
        if (cursor == null) {
          body['next_cursor'] = 'group-cursor';
        } else {
          final item = (body['items'] as List).first as Map<String, dynamic>;
          item['location_id'] = 'address:2';
          (item['location'] as Map<String, dynamic>)['display_name'] = '园区';
          body['next_cursor'] = null;
        }
        return jsonResponse(body);
      }
      return expansionResponse(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('加载更多地点').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('加载更多地点').hitTestable());
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, '家 · 地库'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('保留上次快照').hitTestable(),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('保留上次快照'), findsOneWidget);
    failMore = false;
    await tester.scrollUntilVisible(
      find.text('重试地点账目').hitTestable(),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('重试地点账目').hitTestable());
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, '家 · 地库'), findsOneWidget);
    expect(find.text('园区'), findsOneWidget);
    expect(
      requests
          .where((url) => url.queryParameters['cursor'] == 'group-cursor')
          .length,
      2,
    );
  });

  testWidgets('能力查询失败后可恢复并切换到扩展接口', (tester) async {
    var metadataAvailable = false;
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      if (request.url.path.endsWith('/meta') && !metadataAvailable) {
        return http.Response('', 503);
      }
      return expansionResponse(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    expect(find.textContaining('无法更新站点能力'), findsOneWidget);
    metadataAvailable = true;
    await tester.tap(find.text('重试站点能力'));
    await tester.pumpAndSettle();
    expect(find.textContaining('费用有记录 2 / 8'), findsOneWidget);
    expect(
      requests.any((url) => url.path.endsWith('/charging-locations')),
      isTrue,
    );
  });

  testWidgets('充电统计条件304复用同一查询的已授权快照', (tester) async {
    final conditional = <String?>[];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/stats') &&
          request.url.queryParameters['time_basis'] == 'ended_at') {
        final tag = request.headers['if-none-match'];
        conditional.add(tag);
        if (tag == 'W/"charging"') {
          return http.Response('', 304, headers: {'etag': tag!});
        }
        return jsonResponse(
          chargingStatsV2(),
          headers: {'etag': 'W/"charging"'},
        );
      }
      return expansionResponse(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    expect(find.textContaining('费用有记录 2 / 8'), findsOneWidget);
    await tester.tap(find.byTooltip('刷新充电'));
    await tester.pumpAndSettle();
    expect(conditional, [null, 'W/"charging"']);
    expect(find.textContaining('费用有记录 2 / 8'), findsOneWidget);
    expect(find.textContaining('充电统计暂时不可用'), findsNothing);
  });

  testWidgets('结束日记录分页保留完整匹配数，筛选后从首游标开始', (tester) async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      if (request.url.path.endsWith('/charging-sessions') &&
          request.url.queryParameters['time_basis'] == 'ended_at') {
        final body = chargingPageV2();
        final item = (body['items'] as List).first as Map<String, dynamic>;
        if (request.url.queryParameters['cursor'] == 'page-two') {
          item['id'] = 10;
          body['items'] = [item];
          body['next_cursor'] = null;
        } else {
          body['items'] = [item];
          body['next_cursor'] = request.url.queryParameters['query'] == null
              ? 'page-two'
              : null;
        }
        body['matched_sessions'] = request.url.queryParameters['query'] == null
            ? 2
            : 1;
        return jsonResponse(body);
      }
      return expansionResponse(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全部记录'));
    await tester.pumpAndSettle();
    expect(find.text('匹配 2 次充电'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('charge-10')).hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('charge-10')), findsOneWidget);
    expect(
      requests.any((url) => url.queryParameters['cursor'] == 'page-two'),
      isTrue,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('charging-search')).hitTestable(),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byKey(const Key('charging-search')), '园区');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    final filtered = requests.lastWhere(
      (url) =>
          url.path.endsWith('/charging-sessions') &&
          url.queryParameters['time_basis'] == 'ended_at',
    );
    expect(filtered.queryParameters['query'], '园区');
    expect(filtered.queryParameters['cursor'], isNull);
    expect(find.text('匹配 1 次充电'), findsOneWidget);
  });

  testWidgets('前台站点能力降级后命中旧列表缓存仍恢复记录', (tester) async {
    var upgraded = false;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/meta')) {
        return upgraded
            ? expansionResponse(request)
            : jsonResponse({'version': '0.1.0'});
      }
      if (request.url.path.endsWith('/charging-sessions')) {
        final body = upgraded
            ? jsonDecode(expansionResponse(request).body)
            : chargingFixture();
        return jsonResponse(body, headers: {'cache-control': 'max-age=30'});
      }
      return expansionResponse(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    upgraded = true;
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    expect(find.text('全部记录'), findsOneWidget);
    upgraded = false;
    background(tester);
    foreground(tester);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('charge-9')).hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('charge-9')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('未提供充电扩展能力').hitTestable(),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('未提供充电扩展能力'), findsOneWidget);
  });

  testWidgets('记录重试不改变区间或使地点分页游标失效', (tester) async {
    var now = DateTime.utc(2026, 3, 30, 12);
    var failList = true;
    String? locationEnd;
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      if (request.url.path.endsWith('/charging-sessions') &&
          request.url.queryParameters['time_basis'] == 'ended_at' &&
          failList) {
        return http.Response('', 503);
      }
      if (request.url.path.endsWith('/charging-locations')) {
        final cursor = request.url.queryParameters['cursor'];
        if (cursor == null) locationEnd = request.url.queryParameters['to'];
        if (cursor != null &&
            request.url.queryParameters['to'] != locationEnd) {
          return http.Response('', 400);
        }
        final body =
            jsonDecode(expansionResponse(request).body) as Map<String, dynamic>;
        body['next_cursor'] = cursor == null ? 'group-cursor' : null;
        return jsonResponse(body);
      }
      return expansionResponse(request);
    });
    await tester.pumpWidget(app(client, now: () => now));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('重试充电').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    failList = false;
    now = DateTime.utc(2026, 3, 31, 0, 1);
    await tester.tap(find.text('重试充电').hitTestable());
    await tester.pumpAndSettle();
    final retried = requests.lastWhere(
      (url) =>
          url.path.endsWith('/charging-sessions') &&
          url.queryParameters['time_basis'] == 'ended_at',
    );
    expect(retried.queryParameters['to'], locationEnd);
    // U06 places recent records before locations. Rebuilt records may move
    // this target below the restored offset after retry.
    tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('加载更多地点').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('加载更多地点').hitTestable());
    await tester.pumpAndSettle();
    expect(find.textContaining('地点账目暂时不可用'), findsNothing);
    final next = requests.lastWhere(
      (url) =>
          url.path.endsWith('/charging-locations') &&
          url.queryParameters['cursor'] == 'group-cursor',
    );
    expect(next.queryParameters['to'], locationEnd);
  });
}
