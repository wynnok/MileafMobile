// AP12b 长期续航与停放观察 after 渲染入口（P10/P11 状态矩阵）。opt-in：
// 未设置 MILEAF_RENDER_OUTPUT / MILEAF_RENDER_FONT 时跳过。机位按交付手册
// §5 页面包要求：390/360/320 宽、浅深、100/150/200%、safeArea=0，另含
// 两专题状态（中间缺月/空/全缺失/读取失败、分桶缺失/空/全零/读取失败）、
// 完整滚动与「关于这些数据」展开，并实测规格 §6 五专题首屏（主图可见 ≥120）。
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/workspace.dart';

import 'statistics_parking_test.dart' show parkingResponse;
import 'statistics_range_test.dart' show rangeResponse;
import 'statistics_test.dart' show fixture;
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/statistics_insights_fixture.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

/// 字体身份：生成图册时用 --dart-define=MILEAF_RENDER_FONT_SHA 传入实测 sha256。
const fontSha = String.fromEnvironment('MILEAF_RENDER_FONT_SHA');

class _AppearanceStore implements AppearancePreferenceStore {
  _AppearanceStore(this.value);
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? value) async => this.value = value;
}

DateTime _now() => DateTime.utc(2026, 10, 28, 11);

http.Client _client({
  required String topic,
  String scenario = 'normal',
}) => MockClient((request) async {
  if (request.url.path.endsWith('/vehicles')) return fixture('vehicles');
  if (request.url.path.endsWith('/summary')) return fixture('summary');
  if (request.url.path.endsWith('/meta')) {
    return http.Response(
      jsonEncode(
        statisticsInsightsMeta(
          features: {
            'driving_coverage': true,
            if (topic == 'range') 'range_observations': true,
            if (topic == 'parking') 'parking_observations': true,
          },
        ),
      ),
      200,
    );
  }
  if (topic == 'range' && request.url.path.endsWith('/range-observations')) {
    if (scenario == 'error') return http.Response('{}', 503);
    final months = int.parse(request.url.queryParameters['months']!);
    final body = rangeResponse(months: months);
    switch (scenario) {
      case 'empty':
        return http.Response(
          jsonEncode(rangeResponse(months: months, empty: true)),
          200,
        );
      case 'midmissing':
        final bucket = (body['buckets'] as List)[2] as Map;
        bucket
          ..['status'] = 'no_records'
          ..['sample_status'] = 'insufficient_data'
          ..['median_range_km'] = null
          ..['p10_range_km'] = null
          ..['p90_range_km'] = null;
      case 'allmissing':
        body['totals'] = {
          ...(body['totals'] as Map<String, dynamic>),
          'status': 'insufficient_data',
        };
    }
    return http.Response(jsonEncode(body), 200);
  }
  if (topic == 'parking' &&
      request.url.path.endsWith('/parking-observations')) {
    if (scenario == 'error') return http.Response('{}', 503);
    final body = parkingResponse(request.url, empty: scenario == 'empty');
    if (scenario == 'missing') {
      (body['buckets'] as List)[1]['soc_change_pp'] = null;
      (body['buckets'] as List)[1]['soc_change_pp_per_24h'] = null;
    }
    if (scenario == 'allnull') {
      for (final bucket in body['buckets'] as List) {
        (bucket as Map)
          ..['soc_change_pp'] = null
          ..['soc_change_pp_per_24h'] = null;
      }
    }
    return http.Response(jsonEncode(body), 200);
  }
  return http.Response(jsonEncode(statisticsInsightsFixture(request.url)), 200);
});

Finder _nav(String label) =>
    find.descendant(of: find.byType(MileafNavBar), matching: find.text(label));

Future<void> _pump(
  WidgetTester tester, {
  required Brightness brightness,
  required GlobalKey boundary,
  required Size size,
  required double scale,
  double inset = 24,
  required String topic,
  required http.Client client,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = FakeViewPadding(top: inset, bottom: inset);
  tester.view.padding = tester.view.viewPadding;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  final session = MemorySessionStore()
    ..value = jsonEncode({
      'site': 'https://example.com/prefix',
      'token': 'test',
      'expires_at': '2099-01-01T00:00:00Z',
    });
  final appearance = AppearanceController(
    _AppearanceStore(brightness == Brightness.dark ? 'dark' : 'light'),
  );
  await appearance.restore();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MileafApp(
        client: client,
        sessionStore: session,
        trustStore: MemoryTrustStore(),
        vehiclePreferences: MemoryVehiclePreferences(),
        appearance: appearance,
        now: _now,
        calendar: () async => CalendarContext('Asia/Shanghai'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(_nav('统计'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text('长期').hitTestable(),
    150,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text('长期').first);
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.text(topic == 'range' ? '展开长期续航' : '展开停放观察').hitTestable(),
    100,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.text(topic == 'range' ? '展开长期续航' : '展开停放观察').first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (fontPath.isNotEmpty) await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('AP12b 长期续航与停放观察状态矩阵', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
      tester.view.resetPadding();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final images = <String, Map<String, Object?>>{};
    final measurements = <Map<String, Object?>>[];

    Future<void> capture(
      GlobalKey boundary,
      String page,
      String scene,
      String mode,
      String camera,
      String position,
    ) async {
      final name = 'AP12b-$page-$scene-glass-$mode-$camera-$position.png';
      await saveRenderPng(tester, find.byKey(boundary), '$output/$name');
      images[name] = {
        'page': page,
        'scene': scene,
        'mode': mode,
        'camera': camera,
        'position': position,
        'size': tester.getSize(find.byKey(boundary)).toString(),
      };
    }

    final cameras = <(Brightness, Size, double, double, String)>[
      (Brightness.light, const Size(390, 844), 1.0, 24, '390x844-100'),
      (Brightness.dark, const Size(390, 844), 1.0, 24, '390x844-100'),
      (Brightness.light, const Size(360, 800), 1.0, 24, '360x800-100'),
      (Brightness.light, const Size(320, 568), 2.0, 24, '320x568-200'),
      (Brightness.light, const Size(390, 844), 1.5, 24, '390x844-150'),
      (Brightness.light, const Size(390, 844), 1.0, 0, '390x844-100-safearea0'),
    ];

    for (final topic in ['range', 'parking']) {
      final page = topic == 'range' ? '长期续航' : '停放观察';
      final chartKey = topic == 'range'
          ? const Key('range-observation-chart')
          : const Key('parking-trend-chart');
      final stepsLabel = topic == 'range'
          ? '上一个数据点'
          : MileafChartGrammar.previousStep;

      for (final (brightness, size, scale, inset, camera) in cameras) {
        final boundary = GlobalKey();
        await _pump(
          tester,
          topic: topic,
          brightness: brightness,
          boundary: boundary,
          size: size,
          scale: scale,
          inset: inset,
          client: _client(topic: topic),
        );
        await capture(
          boundary,
          page,
          'normal',
          brightness == Brightness.dark ? 'dark' : 'light',
          camera,
          'top',
        );
        // 规格 §6 五专题首屏：360x800、safeArea 上下 24、100% 时主图可见 ≥120。
        if (camera == '360x800-100' && brightness == Brightness.light) {
          final plot = tester.getRect(find.byKey(chartKey));
          final bodyTop = tester
              .getRect(find.byType(MileafNavigationRow).last)
              .bottom;
          final visible =
              math.min(plot.bottom, size.height - inset) -
              math.max(plot.top, bodyTop);
          expect(visible, greaterThanOrEqualTo(120), reason: page);
          measurements.add({
            'name': page,
            'bodyTop': bodyTop,
            'plotTopInBody': plot.top - bodyTop,
            'plotVisible': visible,
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }

      for (final (scenario, label) in [
        if (topic == 'range') ...[
          ('midmissing', 'midmissing'),
          ('empty', 'empty'),
          ('allmissing', 'allmissing'),
          ('error', 'error'),
        ] else ...[
          ('missing', 'missing'),
          ('empty', 'empty'),
          ('allnull', 'allnull'),
          ('error', 'error'),
        ],
      ]) {
        final boundary = GlobalKey();
        await _pump(
          tester,
          topic: topic,
          brightness: Brightness.light,
          boundary: boundary,
          size: const Size(360, 800),
          scale: 1,
          client: _client(topic: topic, scenario: scenario),
        );
        await capture(boundary, page, label, 'light', '360x800-100', 'top');
        await tester.pumpWidget(const SizedBox.shrink());
      }

      // 正常态完整滚动到页尾 + 展开「关于这些数据」技术详情。
      {
        final boundary = GlobalKey();
        await _pump(
          tester,
          topic: topic,
          brightness: Brightness.light,
          boundary: boundary,
          size: const Size(360, 800),
          scale: 1,
          client: _client(topic: topic),
        );
        final scroll = find.byType(Scrollable).last;
        var step = 0;
        while (tester.state<ScrollableState>(scroll).position.extentAfter > 0 &&
            step < 60) {
          await tester.drag(scroll, const Offset(0, -520));
          await tester.pumpAndSettle();
          step++;
        }
        await capture(
          boundary,
          page,
          'normal',
          'light',
          '360x800-100',
          'bottom',
        );
        final notes = find.widgetWithText(MileafDisclosure, '技术详情');
        await tester.ensureVisible(notes.last);
        await tester.pumpAndSettle();
        await tester.tap(notes.last);
        await tester.pumpAndSettle();
        await capture(boundary, page, 'notes', 'light', '360x800-100', 'notes');
        // 步进动作可达：滚回读数头，上一步进后读值回到前一个分桶/月份。
        final prev = find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.button == true &&
              widget.properties.label == stepsLabel,
        );
        if (prev.evaluate().isNotEmpty) {
          await tester.ensureVisible(prev.first);
          await tester.pumpAndSettle();
          await tester.tap(prev.first);
          await tester.pumpAndSettle();
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }

    File('$output/manifest.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'ticket': 'AP12b',
        'input_sha': '8ea7e29',
        'freeze_point': 'FP3 (eeefe83)',
        'fixture': 'statisticsInsightsFixture + range/parking responses',
        'timezone': 'Asia/Shanghai',
        'sampled_at': '2026-10-28T11:00:00.000Z',
        'font': fontPath,
        'font_sha256': fontSha,
        'dpr': 1,
        'keyboard': 'hidden',
        'material_preferences': 'default',
        'first_screen_measurements': measurements,
        'images': images,
      }),
    );
  }, skip: output.isEmpty || fontPath.isEmpty);
}
