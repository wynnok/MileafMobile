import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/src/design/components/components.dart';

import 'charging_test.dart' show app, MemoryCurrency, jsonResponse;
import 'charging_expansion_test.dart' show expansionResponse;

import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/charging_page.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/a_gallery_fixture.dart';
import 'support/c_fixture.dart';
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets('U06 同底账目与88高每日补能', (tester) async {
    await tester.pumpWidget(app(MockClient((r) async => expansionResponse(r))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('充电'));
    await tester.pumpAndSettle();
    expect(find.byType(MileafHero), findsNothing);
    await tester.scrollUntilVisible(find.byType(StemChart), 100);
    expect(tester.widget<StemChart>(find.byType(StemChart)).height, 88);
    final scroll = find
        .descendant(
          of: find.byType(ChargingPage),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('最近的充电'),
      160,
      scrollable: scroll,
    );
    await tester.pumpAndSettle();
    final recentTop =
        tester.getTopLeft(find.text('最近的充电')).dy +
        tester.state<ScrollableState>(scroll).position.pixels;
    await tester.scrollUntilVisible(
      find.text('我的补能方式'),
      160,
      scrollable: scroll,
    );
    await tester.pumpAndSettle();
    final methodTop =
        tester.getTopLeft(find.text('我的补能方式')).dy +
        tester.state<ScrollableState>(scroll).position.pixels;
    expect(recentTop, lessThan(methodTop));
  });
  testWidgets('U06 正式字体矩阵与首屏预算实测', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final scenes = [
      for (final scenario in ['normal', 'empty', 'missing'])
        for (final mode in Brightness.values)
          for (final scale in [1.0, 2.0])
            (scenario, mode, const Size(360, 800), scale, false),
      for (final mode in Brightness.values)
        ('long', mode, const Size(320, 568), 2.0, false),
      for (final scenario in ['active', 'unknown', 'legacy'])
        for (final mode in Brightness.values)
          (scenario, mode, const Size(360, 800), 1.0, false),
      ('normal', Brightness.light, const Size(390, 844), 1.0, false),
      ('long', Brightness.dark, const Size(768, 1024), 2.0, false),
      ('long', Brightness.light, const Size(360, 800), 1.0, false),
      ('normal', Brightness.light, const Size(360, 800), 1.3, false),
      ('normal', Brightness.dark, const Size(360, 800), 1.5, false),
      ('normal', Brightness.light, const Size(360, 800), 1.0, true),
      ('normal', Brightness.dark, const Size(360, 800), 1.0, true),
    ];
    final measurements = <Map<String, Object>>[];
    for (final (scenario, mode, size, scale, safeZero) in scenes) {
      tester.view.physicalSize = size;
      tester.view.viewPadding = safeZero
          ? FakeViewPadding.zero
          : const FakeViewPadding(top: 24, bottom: 24);
      tester.view.padding = tester.view.viewPadding;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      final gallery = aGalleryClient(
        scenario: scenario == 'long' ? 'normal' : scenario,
        irregular: true,
        longFields: scenario == 'long',
      );
      final client = MockClient((request) async {
        if (scenario == 'legacy' && request.url.path.endsWith('/meta')) {
          return jsonResponse({'version': '0.1.0'});
        }
        if (scenario == 'active') {
          if (request.url.path.endsWith('/summary')) {
            final body = cSummary();
            (body['state'] as Map)['value'] = 'charging';
            return jsonResponse(body);
          }
          if (request.url.path.endsWith('/charging-sessions') &&
              request.url.queryParameters['time_basis'] == 'started_at') {
            return expansionResponse(request);
          }
        }
        final forwarded = http.Request(request.method, request.url)
          ..headers.addAll(request.headers)
          ..bodyBytes = request.bodyBytes;
        final response = await http.Response.fromStream(
          await gallery.send(forwarded),
        );
        if (scenario == 'long' &&
            (request.url.path.endsWith('/charging-sessions') ||
                request.url.path.endsWith('/charging-locations'))) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          for (final item in body['items'] as List) {
            (item['location'] as Map)['display_name'] =
                '上海临港新片区湖畔地下停车场新能源专用充电站东侧入口';
          }
          return jsonResponse(body);
        }
        return response;
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
            client: client,
            sessionStore: store,
            appearance: appearance,
            trustStore: MemoryTrustStore(),
            vehiclePreferences: MemoryVehiclePreferences(),
            currencyPreferences: scenario == 'unknown'
                ? MemoryCurrency()
                : (MemoryCurrency()..values[cSite] = 'CNY'),
            now: () => cNow,
            calendar: () async => CalendarContext('Asia/Shanghai'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('充电').last);
      await tester.pumpAndSettle();
      final prefix =
          '$output/charging-$scenario-${mode.name}-${size.width.round()}-${(scale * 100).round()}${safeZero ? '-safe0' : ''}';
      final scroll = find
          .descendant(
            of: find.byType(ChargingPage),
            matching: find.byType(Scrollable),
          )
          .first;
      if ((scenario == 'normal' || scenario == 'active') &&
          size.width == 360 &&
          scale == 1 &&
          !safeZero) {
        final viewport = tester.getRect(scroll);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('charge-9')),
          100,
          scrollable: scroll,
        );
        await tester.pumpAndSettle();
        final offset = tester.state<ScrollableState>(scroll).position.pixels;
        final first = tester.getRect(find.byKey(const ValueKey('charge-9')));
        measurements.add({
          'scene': '$scenario-${mode.name}',
          'bodyHeight': viewport.height,
          'firstTop': first.top + offset - viewport.top,
          'firstBottom': first.bottom + offset - viewport.top,
          'requiredFirstHeight': scenario == 'active' ? 44 : first.height,
          'visibleFirstHeight': (viewport.bottom - first.top - offset).clamp(
            0,
            first.height,
          ),
          'targetMet':
              (scenario == 'active' ? first.top + 44 : first.bottom) + offset <=
              viewport.bottom,
        });
        debugPrint(
          'U06 ${mode.name} body=$viewport first=$first offset=$offset',
        );

        tester.state<ScrollableState>(scroll).position.jumpTo(0);
        await tester.pumpAndSettle();
      }
      await saveRenderPng(tester, find.byKey(boundary), '$prefix-top.png');
      if (scenario == 'long' || scenario == 'missing') {
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('charge-9')).hitTestable(),
          160,
          scrollable: scroll,
        );
        await saveRenderPng(tester, find.byKey(boundary), '$prefix-record.png');
      }
      await tester.scrollUntilVisible(
        find.text('数据说明').hitTestable(),
        250,
        scrollable: scroll,
      );
      await tester.tap(find.text('数据说明').hitTestable());
      await tester.pumpAndSettle();
      final position = tester.state<ScrollableState>(scroll).position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      await saveRenderPng(tester, find.byKey(boundary), '$prefix-end.png');
      if (scenario == 'normal' &&
          mode == Brightness.light &&
          scale == 1 &&
          size.width == 360 &&
          !safeZero) {
        position.jumpTo(0);
        await tester.pumpAndSettle();
        for (var i = 0; i < 50; i++) {
          await saveRenderPng(
            tester,
            find.byKey(boundary),
            '$prefix-scroll$i.png',
          );
          if (position.extentAfter == 0) break;
          position.jumpTo(
            (position.pixels + size.height * .7).clamp(
              0,
              position.maxScrollExtent,
            ),
          );
          await tester.pumpAndSettle();
        }
      }
      position.jumpTo(0);
      await tester.pumpAndSettle();
      if (scenario != 'legacy') {
        await tester.tap(find.text('全部记录').hitTestable());
      }
      await tester.pumpAndSettle();
      await saveRenderPng(tester, find.byKey(boundary), '$prefix-records.png');
      if (size.width == 320) {
        final types = find.byType(DropdownButton<String>);
        await tester.scrollUntilVisible(types.first, 120, scrollable: scroll);
        await tester.pumpAndSettle();
        expect(tester.getSize(types.first).height, greaterThanOrEqualTo(44));
        await tester.tapAt(tester.getRect(types.first).center);
        await tester.pumpAndSettle();
        await tester.tap(find.text('AC').last);
        await tester.pumpAndSettle();
        expect(tester.widget<DropdownButton<String>>(types.first).value, 'ac');
        await tester.scrollUntilVisible(
          find.textContaining('类型：AC'),
          -120,
          scrollable: scroll,
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('类型：AC'), findsOneWidget);
        await saveRenderPng(
          tester,
          find.byKey(boundary),
          '$prefix-filter-action.png',
        );
      }

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      client.close();
      gallery.close();
    }
    await tester.runAsync(() async {
      await File(
        '$output/measurements.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(measurements));
    });
  }, skip: fontPath.isEmpty || output.isEmpty);
}
