import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/overview_page.dart';
import 'package:mileaf/src/statistics_insights_page.dart';
import 'package:mileaf/src/statistics_period.dart';
import 'package:mileaf/src/workspace.dart';

import 'overview_statistics_reading_test.dart'
    show
        chargingDays,
        chargingReadout,
        openChargingTopic,
        dayStats,
        readingClient,
        tapChargingPlot;
import 'reading_continuity_test.dart'
    show journeyPage, readToEndOfRange, workspaceClient;
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'support/test_trust_store.dart' show MemoryTrustStore;

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

class _Appearance implements AppearancePreferenceStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? next) async => value = next;
}

Future<void> _select(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(MileafNavBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

Future<void> _chip(WidgetTester tester, Type page, String label) async {
  final chip = find.descendant(
    of: find.byType(page),
    matching: find.widgetWithText(StatusChip, label),
  );
  await tester.scrollUntilVisible(
    chip.hitTestable(),
    160,
    scrollable: find
        .descendant(of: find.byType(page), matching: find.byType(Scrollable))
        .first,
  );
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

/// Returned overview/statistics in the official Flutter widget tree, so the
/// restored state can be checked for layout regressions rather than described.
void main() {
  setUpAll(() async {
    if (output.isEmpty) return;
    await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('阅读恢复后的概览与统计 8 张样张', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final boundary = GlobalKey();
    for (final page in ['overview', 'statistics']) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 2.0]) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          final store = MemorySessionStore()
            ..value = jsonEncode({
              'site': 'https://example.com/prefix',
              'token': 'test',
              'expires_at': '2099-01-01T00:00:00Z',
            });
          final appearance = AppearanceController(
            _Appearance()
              ..value = brightness == Brightness.dark ? 'dark' : 'light',
          );
          await appearance.restore();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MileafApp(
                key: ValueKey('$page-${brightness.name}-$scale'),
                client: readingClient(
                  [],
                  driving: (url) => dayStats(url, days: 7),
                ),
                sessionStore: store,
                trustStore: MemoryTrustStore(),
                vehiclePreferences: MemoryVehiclePreferences(),
                appearance: appearance,
                now: () => DateTime.utc(2026, 3, 30, 12),
                calendar: () async => CalendarContext('UTC'),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (page == 'overview') {
            await _chip(tester, OverviewPage, '近7天');
            await tester.scrollUntilVisible(
              find.byType(TimeSeriesChart).first,
              220,
            );
            await _select(tester, '行程');
            await _select(tester, '概览');
            await tester.scrollUntilVisible(
              find.widgetWithText(StatusChip, '近7天').hitTestable(),
              -160,
              scrollable: find
                  .descendant(
                    of: find.byType(OverviewPage),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            expect(
              tester
                  .widget<StatusChip>(
                    find.descendant(
                      of: find.byType(OverviewPage),
                      matching: find.widgetWithText(StatusChip, '近7天'),
                    ),
                  )
                  .selected,
              isTrue,
            );
          } else {
            await _select(tester, '统计');
            await _chip(tester, StatisticsInsightsPage, '近7天');
            await tester.scrollUntilVisible(
              find.byType(TimeSeriesChart).first,
              220,
            );
            await _select(tester, '概览');
            await _select(tester, '统计');
            expect(
              tester
                  .widget<StatusChip>(
                    find.descendant(
                      of: find.byType(StatisticsInsightsPage),
                      matching: find.widgetWithText(StatusChip, '近7天'),
                    ),
                  )
                  .selected,
              isTrue,
            );
          }
          await saveRenderPng(
            tester,
            find.byKey(boundary),
            '$output/$page-${brightness.name}-${scale == 1 ? '100' : '200'}.png',
          );
          expect(tester.takeException(), isNull);
        }
      }
    }
  }, skip: output.isEmpty);

  testWidgets('补能统计选点与多页列表恢复后的 6 张样张', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final boundary = GlobalKey();
    var now = DateTime.utc(2026, 3, 30, 12);
    Future<void> boot({
      required Brightness brightness,
      required double scale,
      required http.Client client,
      required String key,
    }) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      final store = MemorySessionStore()
        ..value = jsonEncode({
          'site': 'https://example.com/prefix',
          'token': 'test',
          'expires_at': '2099-01-01T00:00:00Z',
        });
      final appearance = AppearanceController(
        _Appearance()..value = brightness == Brightness.dark ? 'dark' : 'light',
      );
      await appearance.restore();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MileafApp(
            key: ValueKey(key),
            client: client,
            sessionStore: store,
            trustStore: MemoryTrustStore(),
            vehiclePreferences: MemoryVehiclePreferences(),
            appearance: appearance,
            now: () => now,
            calendar: () async => CalendarContext('UTC'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        final name = '${brightness.name}-${scale == 1 ? '100' : '200'}';
        // The charging topic keeps the bucket the owner picked by its date.
        await boot(
          brightness: brightness,
          scale: scale,
          client: readingClient(
            [],
            driving: (url) => dayStats(url, days: 7),
            charging: chargingDays,
          ),
          key: 'topic-$name',
        );
        // The drill-down path from the overview is the one the defect was
        // reported on: the charging topic sits inside the statistics tab, so
        // the round trip uses the main entries.
        await openChargingTopic(tester);
        expect(find.text('补能账目'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '原始自定义日期不得溢出');
        final controls = find.byType(StatisticsPeriodControls);
        final selection = tester
            .widget<StatisticsPeriodControls>(controls)
            .selection;
        expect(selection.period, StatisticsPeriod.custom);
        final label =
            '${statisticsDate(selection.start!)} 至 ${statisticsDate(selection.end!)}';
        await tester.ensureVisible(controls);
        await saveRenderPng(
          tester,
          find.byKey(boundary),
          '$output/date-filter-$name.png',
        );
        final dateChip = find.widgetWithText(StatusChip, label);
        expect(tester.getSize(dateChip).height, greaterThanOrEqualTo(44));
        final semantics = tester.ensureSemantics();
        expect(
          tester.getSemantics(dateChip),
          matchesSemantics(
            label: label,
            isButton: true,
            isSelected: true,
            hasSelectedState: true,
            hasEnabledState: true,
            isEnabled: true,
          ),
        );
        semantics.dispose();
        await tester.tap(dateChip);
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(TextField, statisticsDate(selection.start!)),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextField, statisticsDate(selection.end!)),
          findsOneWidget,
        );
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<StatisticsPeriodControls>(controls).selection,
          same(selection),
        );
        await tapChargingPlot(tester, 0.8);
        final chosen = chargingReadout(tester);
        expect(chosen, isNot(startsWith('3/1 ')), reason: '前置：选中的不是首日');
        now = now.add(const Duration(minutes: 10));
        await _select(tester, '行程');
        await _select(tester, '统计');
        expect(chargingReadout(tester), chosen, reason: '往返后仍选中同一日期');
        await tester.ensureVisible(find.text(chosen));
        await saveRenderPng(
          tester,
          find.byKey(boundary),
          '$output/charging-topic-$name.png',
        );
      }
    }

    for (final (brightness, scale, name) in [
      (Brightness.light, 1.0, 'light-100'),
      (Brightness.dark, 2.0, 'dark-200'),
    ]) {
      // The journey list comes back with both pages it had read.
      await boot(
        brightness: brightness,
        scale: scale,
        client: workspaceClient([], (request) async => journeyPage(request)),
        key: 'drives-$name',
      );
      await _select(tester, '行程');
      await readToEndOfRange(tester);
      await _select(tester, '概览');
      await _select(tester, '行程');
      expect(
        tester.widget<MileafNavBar>(find.byType(MileafNavBar)).index,
        1,
        reason: '截图机位必须是行程列表本身',
      );
      expect(find.text('已显示全部行程'), findsOneWidget);
      expect(find.text('加载更多行程'), findsNothing);
      await saveRenderPng(
        tester,
        find.byKey(boundary),
        '$output/drives-restored-$name.png',
      );
    }
  }, skip: output.isEmpty);
}
