import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/overview_page.dart';
import 'package:mileaf/src/workspace.dart';

import 'a_overview_render_test.dart' show sampleClient;
import 'support/c_fixture.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';

import 'support/render_fonts.dart';

import 'a_overview_test.dart' show openOverview;
import 'overview_visualization_test.dart'
    show openOverviewVisual, overviewResponse, overviewFixture, monthTrend;
import 'overview_statistics_reading_test.dart'
    show pumpReadingApp, selectTab, readingFixture, ok;

const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');
const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');

class _Appearance implements AppearancePreferenceStore {
  _Appearance(this.value);
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? next) async => value = next;
}

void main() {
  setUpAll(() async {
    if (fontPath.isNotEmpty) await loadRenderFonts(cjkFontPath: fontPath);
  });
  testWidgets('U04 summary failure retains driving and charging details', (
    tester,
  ) async {
    await openOverviewVisual(tester, (request) async {
      if (request.url.path.endsWith('/summary')) return http.Response('', 503);
      return overviewResponse(
        overviewFixture(
          request.url.queryParameters['kind'] == 'charging'
              ? 'charging-stats'
              : 'driving-stats',
        ),
      );
    }, briefing: true);
    // P01：摘要失败不影响统计卡与「关于这些数据」的驾驶/充电读数。
    await tester.scrollUntilVisible(find.text('本期账目').hitTestable(), 200);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('overview-reading-plate')),
        matching: find.textContaining('趟'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('overview-reading-plate')),
        matching: find.text('充电'),
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('关于这些数据').hitTestable(), 200);
    await tester.scrollUntilVisible(find.text('口径与估算').hitTestable(), 200);
    await tester.tap(find.text('口径与估算').hitTestable());
    await tester.pumpAndSettle();
    expect(find.textContaining('估算耗电'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('U04 driving failure leaves charging and cost charts reachable', (
    tester,
  ) async {
    await openOverviewVisual(tester, (request) async {
      if (request.url.path.endsWith('/summary')) {
        return overviewResponse(overviewFixture('summary'));
      }
      if (request.url.queryParameters['kind'] == 'driving') {
        return http.Response('', 503);
      }
      return overviewResponse(overviewFixture('charging-stats'));
    }, briefing: true);
    // CP02：分段短标签改成「充电」，图表标题「每日充电量 / 每日已记录费用」。
    await tester.scrollUntilVisible(
      find.widgetWithText(StatusChip, '充电').hitTestable(),
      200,
    );
    await tester.tap(find.widgetWithText(StatusChip, '充电').hitTestable());
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('每日充电量图表'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.widgetWithText(StatusChip, '费用').hitTestable(),
      -120,
    );
    await tester.tap(find.widgetWithText(StatusChip, '费用').hitTestable());
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('每日已记录费用图表'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'U04 mileage readout includes reference range value and difference',
    (tester) async {
      await openOverviewVisual(tester, (request) async {
        if (request.url.path.endsWith('/summary')) {
          return overviewResponse(overviewFixture('summary'));
        }
        if (request.url.queryParameters['kind'] == 'charging') {
          return overviewResponse(overviewFixture('charging-stats'));
        }
        final reference =
            DateTime.parse(request.url.queryParameters['to']!).month == 2;
        return overviewResponse(
          monthTrend(firstDistance: reference ? 20 : 30.5),
        );
      }, briefing: true);
      // P01/R29：读值第三行把参照区间与差值写成一句（CP03 多/少 + CP04 DF3）。
      await tester.scrollUntilVisible(
        find.textContaining('多 10.5 km').hitTestable(),
        200,
      );
      expect(
        find.text('上月同期 2月1日–15日 20 km，多 10.5 km'),
        findsOneWidget,
        reason: '参照行的区间与取值仍在同一行成对出现',
      );
    },
  );

  testWidgets(
    'U04 H01 hidden late driving response defers comparison until return',
    (tester) async {
      final response = Completer<http.Response>();
      final comparisons = <Uri>[];
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/vehicles')) return ok(readingFixture('vehicles'));
        if (path.endsWith('/meta')) return ok(readingFixture('meta'));
        if (path.endsWith('/summary')) return ok(readingFixture('summary'));
        if (path.endsWith('/drives')) return ok(readingFixture('drives'));
        if (path.endsWith('/stats')) {
          if (request.url.queryParameters['kind'] == 'charging') {
            return ok(readingFixture('charging-stats'));
          }
          if (DateTime.parse(request.url.queryParameters['from']!).month == 3) {
            return response.future;
          }
          comparisons.add(request.url);
          return ok(readingFixture('driving-stats'));
        }
        return ok({});
      });
      addTearDown(client.close);
      await pumpReadingApp(tester, client);
      await selectTab(tester, '行程');
      comparisons.clear();
      response.complete(ok(readingFixture('driving-stats')));
      await tester.pumpAndSettle();
      expect(comparisons, isEmpty);
      await selectTab(tester, '概览');
      expect(comparisons, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  for (final mode in [MileafAppearance.light, MileafAppearance.dark]) {
    testWidgets('U04 ${mode.name} compact status and first viewport plot', (
      tester,
    ) async {
      tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      await openOverview(tester, size: const Size(360, 800), mode: mode);
      final status = tester.getRect(
        find.byKey(const ValueKey('overview-status')),
      );
      expect(status.height, inInclusiveRange(180, 212));
      final chart = tester.widget<TimeSeriesChart>(
        find.byType(TimeSeriesChart),
      );
      final plotBox = tester.getRect(find.byKey(chart.plotKey!));
      final painter = tester
          .widget<CustomPaint>(
            find.descendant(
              of: find.byKey(chart.plotKey!),
              matching: find.byType(CustomPaint),
            ),
          )
          .painter;
      final plot = ((painter as dynamic).plot as Rect).shift(plotBox.topLeft);
      final viewport = tester.getRect(find.byType(RefreshIndicator));
      final visible = plot.intersect(viewport);
      expect(visible.height, greaterThanOrEqualTo(80));
      debugPrint(
        'U04 ${mode.name}: status=${status.height}, plot=$plot, viewport=$viewport, visible=${visible.height}',
      );
      expect(tester.takeException(), isNull);
    }, skip: fontPath.isEmpty);
  }

  testWidgets('U04 formal overview matrix and complete reading path', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
      tester.view.resetPadding();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final scenes = [
      for (final scenario in ['normal', 'empty', 'missing'])
        for (final mode in Brightness.values)
          for (final scale in [1.0, 2.0])
            (scenario, mode, const Size(360, 800), scale, false),
      ('long', Brightness.dark, const Size(320, 568), 2.0, false),
      ('normal', Brightness.light, const Size(390, 844), 1.0, false),
      ('long', Brightness.dark, const Size(768, 1024), 2.0, false),
      ('normal', Brightness.light, const Size(360, 800), 1.3, false),
      ('normal', Brightness.dark, const Size(360, 800), 1.5, false),
      ('normal', Brightness.light, const Size(360, 800), 1.0, true),
      ('normal', Brightness.dark, const Size(360, 800), 1.0, true),
    ];
    for (final (scenario, mode, size, scale, safeZero) in scenes) {
      tester.view.physicalSize = size;
      tester.view.viewPadding = safeZero
          ? FakeViewPadding.zero
          : const FakeViewPadding(top: 24, bottom: 24);
      tester.view.padding = tester.view.viewPadding;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      final client = sampleClient(scenario == 'long' ? 'normal' : scenario);
      final wrapped = MockClient((request) async {
        if (scenario == 'long' && request.url.path.endsWith('/vehicles')) {
          final vehicles = cVehicles() as List;
          (vehicles.first as Map)['name'] =
              '行笺长车辆名称测试 上海至杭州日常通勤 Model 3 Long Range';
          return http.Response(
            jsonEncode(vehicles),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response.fromStream(
          await client.send(
            http.Request(request.method, request.url)
              ..headers.addAll(request.headers),
          ),
        );
      });
      final store = MemorySessionStore()
        ..value = jsonEncode({
          'site': cSite,
          'token': 'test',
          'expires_at': '2099-01-01T00:00:00Z',
        });
      final appearance = AppearanceController(_Appearance(mode.name));
      await appearance.restore();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MileafApp(
            key: UniqueKey(),
            client: wrapped,
            sessionStore: store,
            trustStore: MemoryTrustStore(),
            vehiclePreferences: MemoryVehiclePreferences(),
            appearance: appearance,
            now: () => cNow,
            calendar: () async => CalendarContext('Asia/Shanghai'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final prefix =
          '$output/overview-$scenario-${mode.name}-${size.width.round()}-${(scale * 100).round()}${safeZero ? '-safe0' : ''}';
      await saveRenderPng(tester, find.byKey(boundary), '$prefix-top.png');
      if (scenario == 'missing') expect(find.text('— 暂无续航'), findsOneWidget);
      final scrollable = find
          .descendant(
            of: find.byType(OverviewPage),
            matching: find.byType(Scrollable),
          )
          .first;
      if (scenario == 'long' && size.width == 320) {
        await tester.scrollUntilVisible(
          find.text('近7天').hitTestable(),
          200,
          scrollable: scrollable,
        );
        await tester.tap(find.text('近7天').hitTestable());
        await tester.pumpAndSettle();
        final month = find.widgetWithText(StatusChip, '本月');
        await tester.scrollUntilVisible(month, -120, scrollable: scrollable);
        await tester.pumpAndSettle();
        tester.widget<StatusChip>(month).onTap!();
        await tester.pumpAndSettle();
        await tester.pumpAndSettle();
        for (final label in ['电耗', '充电', '费用', '里程']) {
          tester.state<ScrollableState>(scrollable).position.jumpTo(0);
          await tester.pumpAndSettle();
          final control = find.widgetWithText(StatusChip, label);
          await tester.scrollUntilVisible(
            control.hitTestable(),
            200,
            scrollable: scrollable,
          );
          await tester.pumpAndSettle();
          final rect = tester.getRect(control);
          expect(rect.width, greaterThanOrEqualTo(44));
          expect(rect.height, greaterThanOrEqualTo(44));
          tester.widget<StatusChip>(control).onTap!();
          await tester.pumpAndSettle();
          expect(tester.widget<StatusChip>(control).selected, isTrue);
        }
        await saveRenderPng(
          tester,
          find.byKey(boundary),
          '$prefix-controls.png',
        );
      }
      // P01/R30：旧「数据说明与更多」弹层并入页尾「关于这些数据」分组卡，
      // 不再有可点开的入口；这里只确认说明层在整页末尾仍可达。
      await tester.scrollUntilVisible(
        find.text('关于这些数据').hitTestable(),
        300,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      // Every scenario reaches the last explanatory action at full text scale.
      final fullSequence =
          scenario == 'normal' &&
          mode == Brightness.light &&
          scale == 1 &&
          size.width == 360 &&
          !safeZero;
      if (fullSequence) {
        tester.state<ScrollableState>(scrollable).position.jumpTo(0);
        await tester.pumpAndSettle();
        for (var frame = 0; frame < 30; frame++) {
          await saveRenderPng(
            tester,
            find.byKey(boundary),
            '$prefix-scroll$frame.png',
          );
          final position = tester.state<ScrollableState>(scrollable).position;
          if (position.extentAfter == 0) break;
          await tester.drag(scrollable, const Offset(0, -400));
          await tester.pumpAndSettle();
        }
      }
      await tester.scrollUntilVisible(
        find.text('技术详情').hitTestable(),
        300,
        scrollable: scrollable,
      );
      // R30.4：说明层不是只截折叠标题——展开后技术详情必须可读、可复制。
      await tester.tap(find.text('技术详情').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsWidgets);
      await saveRenderPng(tester, find.byKey(boundary), '$prefix-end.png');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      wrapped.close();
      client.close();
    }
  }, skip: output.isEmpty || fontPath.isEmpty);
}
