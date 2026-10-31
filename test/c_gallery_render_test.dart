import 'support/render_png.dart';

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:mileaf/main.dart';
import 'package:mileaf/src/workspace.dart';
import 'package:mileaf/src/currency.dart';

import 'support/c_fixture.dart';
import 'charging_expansion_test.dart' show expansionResponse;
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

http.Response _ok(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'max-age=30',
  },
);

class _Cny implements CurrencyPreferenceStore {
  @override
  Future<String?> read(String site) async => 'CNY';
  @override
  Future<void> write(String site, String? code) async {}
}

MockClient cGalleryClient({String scenario = 'normal'}) =>
    MockClient((request) async {
      final url = request.url;
      if (url.path.endsWith('/vehicles')) return _ok(cVehicles());
      if (url.path.endsWith('/summary')) {
        return _ok(scenario == 'empty' ? cEmptySummary() : cSummary());
      }
      if (url.path.endsWith('/meta')) return _ok(cMeta());
      if (url.path.endsWith('/drives')) return _ok(cDrives());
      if (url.path.endsWith('/drives/17/series')) return _ok(cDriveSeries());
      if (url.path.endsWith('/drives/17')) return _ok(cDriveDetail());
      if (url.path.endsWith('/charging-sessions/9/series')) {
        return _ok(cChargeSeries());
      }
      if (url.path.endsWith('/charging-sessions/9')) {
        return _ok(cChargeDetailBody());
      }
      if (url.path.contains('/charging-sessions') ||
          url.path.contains('/charging-locations') ||
          (url.path.endsWith('/stats') &&
              url.queryParameters['kind'] == 'charging')) {
        if (url.path.endsWith('/stats')) {
          return _ok(switch (scenario) {
            'empty' => cEmptyChargingV2(),
            'missing' => cMissingChargingV2(),
            _ => cChargingStatsV2(),
          });
        }
        final expanded = expansionResponse(request);
        if (url.path.endsWith('/charging-sessions')) {
          final body = jsonDecode(expanded.body) as Map<String, dynamic>;
          final items = [
            for (final item in (body['items'] as List).cast<Map>())
              if (item['is_active'] != true) Map<String, dynamic>.from(item),
          ];
          if (items.isNotEmpty) {
            items.first.addAll({
              'energy_added_kwh': cChargeDetail.energyKwh,
              'start_soc': cChargeDetail.startSoc,
              'end_soc': cChargeDetail.endSoc,
              'cost': cChargeDetail.cost,
              'duration_min': cChargeDetail.durationMin,
              'is_dc': true,
            });
          }
          body['items'] = items;
          return http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return expanded;
      }
      if (url.path.endsWith('/driving-analysis')) {
        return _ok(
          url.queryParameters['view'] == 'calendar'
              ? cCalendar(url)
              : (scenario == 'empty' ? cEmptyUsage() : cUsage()),
        );
      }
      if (url.path.endsWith('/stats')) {
        final charging = url.queryParameters['kind'] == 'charging';
        if (scenario == 'empty') {
          return _ok(charging ? cEmptyCharging(url) : cEmptyDriving(url));
        }
        if (scenario == 'missing' && !charging) {
          return _ok(cMissingDriving(url));
        }
        if (charging) return _ok(cChargingStatsV2());
        final from = url.queryParameters['from'] ?? '';
        return _ok(
          from.startsWith('2026-09-2') ? cDrivesStats(url) : cDriving(url),
        );
      }
      return http.Response('{}', 404);
    });

/// Every C page in one gallery, driven exclusively by test/support/c_fixture.dart.
void main() {
  setUpAll(() async {
    if (output.isEmpty) return;
    final bytes = ByteData.sublistView(File(fontPath).readAsBytesSync());
    for (final family in ['Roboto', 'Arial', 'sans-serif']) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('C 图册：概览/统计/行程/节奏共用同一 fixture', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final boundary = GlobalKey();
    Future<void> save(String name) =>
        saveRenderPng(tester, find.byKey(boundary), '$output/$name.png');

    void expectPage(String text, {String? absent}) {
      expect(find.textContaining(text), findsWidgets, reason: 'C 图册应包含 $text');
      if (absent != null) {
        expect(
          find.textContaining(absent),
          findsNothing,
          reason: 'C 图册不应包含 $absent',
        );
      }
    }

    Future<void> pumpApp(String key, {String scenario = 'normal'}) async {
      final store = MemorySessionStore()
        ..value = jsonEncode({
          'site': cSite,
          'token': 'test',
          'expires_at': '2099-01-01T00:00:00Z',
        });
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MileafApp(
            key: ValueKey(key),
            client: cGalleryClient(scenario: scenario),
            sessionStore: store,
            trustStore: MemoryTrustStore(),
            vehiclePreferences: MemoryVehiclePreferences(),
            currencyPreferences: _Cny(),
            now: () => cNow,
            calendar: () async => CalendarContext('Asia/Shanghai'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final scenario in ['normal', 'empty', 'missing']) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 2.0]) {
          final suffix =
              '$scenario-${brightness.name}-${scale == 1 ? '100' : '200'}';
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          tester.platformDispatcher.textScaleFactorTestValue = scale;

          await pumpApp('overview-$suffix', scenario: scenario);
          await save('overview-$suffix');
          if (scenario == 'normal' && scale == 1.0) {
            expectPage('每日里程', absent: '前一个采样');
            expectPage('本月 · 驾驶里程');
            expectPage('较参照');
          }

          if (scenario == 'normal') {
            await tester.scrollUntilVisible(
              find.text('最近充电').hitTestable(),
              200,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.tap(find.text('最近充电').hitTestable());
            await tester.pumpAndSettle();
            await save('charge-detail-$suffix');
            if (scale == 1.0) {
              expectPage('电量区间');
            }
            await pumpApp('overview-drive-$suffix', scenario: scenario);
            await tester.scrollUntilVisible(
              find.text('最近行程').hitTestable(),
              200,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.tap(find.text('最近行程').hitTestable());
            await tester.pumpAndSettle();
            await save('drive-detail-$suffix');
            expectPage('路线示意 · 非导航');
            await pumpApp('overview-return-$suffix', scenario: scenario);
          }
          if (scenario != 'normal' || scale == 1.0) {
            await pumpApp('charging-$suffix', scenario: scenario);
            await tester.tap(find.text('充电').last);
            await tester.pumpAndSettle();
            await save('charging-list-$suffix');
            if (scenario == 'normal' && scale == 1.0) {
              expectPage('已知充电费用');
              expectPage('每日补能');
              expectPage('费用有记录 8 / 9 次');
            }
            if (scenario == 'empty' && scale == 1.0) {
              // C07: empty must not draw a fake all-zero trend.
              expectPage('没有采样点');
            }
          }

          await tester.tap(find.text('统计').last);
          await tester.pumpAndSettle();
          await save('statistics-$suffix');
          if (scenario == 'normal' && scale == 1.0) {
            // C stats reads as conclusion → dark chart → 四个问题.
            expectPage('里程走势', absent: '趋势指标');
            expectPage('本期 vs 参照 · 同进度');
            expectPage('四个问题');
            expectPage('较参照低 8 Wh/km');
          }

          await tester.scrollUntilVisible(find.text('节奏').hitTestable(), 150);
          await tester.tap(find.text('节奏').hitTestable());
          await tester.pumpAndSettle();
          await save('rhythm-$suffix');
          if (scenario == 'normal' && scale == 1.0) {
            expectPage('活跃 22 天');
          }

          await pumpApp('drives-$suffix', scenario: scenario);
          await tester.tap(find.text('行程').last);
          await tester.pumpAndSettle();
          await save('drives-$suffix');
          if (scenario == 'normal' && scale == 1.0) {
            expectPage('出行节奏', absent: '筛选日期');
            expectPage('最近的路');
            expectPage('单次回顾');
          }
        }
      }
    }
  }, skip: output.isEmpty);
}
