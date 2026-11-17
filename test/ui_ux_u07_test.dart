import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mileaf/src/map/map_consent.dart';
import 'package:mileaf/src/map/map_panel.dart';

import 'drive_detail_test.dart' as drive;
import 'charging_detail_test.dart' as charge;
import 'drives_test.dart' show jsonResponse;
import 'support/fake_map_platform.dart';

import 'package:mileaf/src/design/components/components.dart';

import 'charging_expansion_test.dart' show detailV2, seriesV2;

import 'package:mileaf/src/map/map_key.dart';
import 'package:mileaf/src/map/map_scene.dart';
import 'package:mileaf/src/design/theme.dart';

import 'support/map_key_fixture.dart';
import 'support/render_fonts.dart';
import 'support/render_png.dart';

const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');
const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');

void main() {
  setUpAll(() async {
    if (fontPath.isNotEmpty) await loadRenderFonts(cjkFontPath: fontPath);
  });
  testWidgets('U07 展开地图返回保持选点且不重复下载', (tester) async {
    var downloads = 0;
    await drive.openDetail(tester, (r) async {
      if (r.url.path.endsWith('/series')) downloads++;
      return jsonResponse(
        jsonEncode(
          drive.fixture(
            r.url.path.endsWith('/series') ? 'drive-series' : 'drive-detail',
          ),
        ),
      );
    });
    // R29：读数头取代「速度读数」句，步进圆钮只在读数头里出现；
    // 这里直接点绘图区取靠后的采样点，读数头日期行即「当前选点」。
    await tester.scrollUntilVisible(find.text('行驶过程').hitTestable(), 180);
    final chart = tester.getRect(find.byKey(const ValueKey('sample-chart')));
    await tester.tapAt(Offset(chart.left + chart.width * 0.9, chart.center.dy));
    await tester.pumpAndSettle();
    final before = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere(
          (t) => RegExp(r'^\d{2}:\d{2}$').hasMatch(t),
          orElse: () => fail('读数头日期行未出现'),
        );
    await tester.scrollUntilVisible(
      find.byTooltip('查看完整地图').hitTestable(),
      -180,
    );
    final scroll = tester
        .state<ScrollableState>(find.byType(Scrollable).last)
        .position;
    final offset = scroll.pixels;
    await tester.tap(find.byTooltip('查看完整地图'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(scroll.pixels, offset);
    await tester.scrollUntilVisible(find.text('行驶过程'), 180);
    expect(
      tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? ''),
      contains(before),
    );
    expect(downloads, 1);
    // CP04 DF9：读数头日期行只到 HH:mm（上面 contains(before) 已断言选点
    // 保持）；精确时间只活在页尾「关于这些数据」，惰性列表在当前滚动位置
    // 不构建，不再以可见性断言全日期。
    await tester.scrollUntilVisible(find.text('电量').hitTestable(), -100);
    await tester.tap(find.text('电量').hitTestable());
    await tester.pumpAndSettle();
    expect(
      tester.widget<TimeSeriesChart>(find.byType(TimeSeriesChart)).yRange,
      (0, 100),
    );
  });

  testWidgets('U07 扩展契约大字过程切换与电量轴完整缩放', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });
    await tester.pumpWidget(
      charge.app(
        MockClient((r) async {
          if (r.url.path.endsWith('/charging-sessions/1/series')) {
            return charge.response(seriesV2());
          }
          if (r.url.path.endsWith('/charging-sessions/1')) {
            return charge.response(detailV2());
          }
          return charge.initial(r);
        }),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('最近充电').hitTestable(), 160);
    await tester.tap(find.text('最近充电').hitTestable());
    await tester.pumpAndSettle();
    // P05：过程卡只有 功率 / 电量 两个指标（横轴固定为时间），旧的
    // 「按电量」横轴视图已并入电量指标；这里验证大字下切到电量仍完整。
    await tester.scrollUntilVisible(find.text('电量').hitTestable(), 160);
    await tester.tap(find.text('电量').hitTestable());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('charging-time-chart')),
      160,
    );
    expect(tester.takeException(), isNull);
    if (output.isNotEmpty) {
      await saveRenderPng(
        tester,
        find.byType(RepaintBoundary).first,
        '$output/charge-expanded-dark-320-200-soc.png',
      );
    }
  });

  testWidgets('U07 地图状态矩阵', (tester) async {
    for (final small in [false, true]) {
      for (final state in [
        'no-key',
        'consent',
        'ready',
        'failed',
        'restart',
        'empty',
        'single',
      ]) {
        final keys = MapKeyController(
          TestKeyStore()..value = state == 'no-key' ? null : 'a' * 32,
        );
        await keys.restore();
        final consent = MapConsentController();
        if (state != 'consent') await consent.grant();
        if (state == 'restart') keys.keyForMap();
        final platform = FakeMapPlatform();
        tester.view.physicalSize = small
            ? const Size(320, 568)
            : const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        final scene = driveScene(
          start: null,
          end: null,
          selected: null,
          selectedLabel: null,
          coordinates: state == 'empty'
              ? []
              : [
                  const MapCoordinate(31.23, 121.47),
                  if (state != 'single') const MapCoordinate(31.24, 121.48),
                ],
          brightness: small ? Brightness.dark : Brightness.light,
          interactive: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: mileafTheme(small ? Brightness.dark : Brightness.light),
            home: MapKeyScope(
              controller: keys,
              child: MediaQuery(
                data: MediaQueryData(
                  size: small ? const Size(320, 568) : const Size(360, 800),
                  textScaler: TextScaler.linear(small ? 2 : 1),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: MapPanel(
                      scene: scene,
                      consent: consent,
                      platform: platform,
                      height: MapPanel.detailHeight,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        if (state == 'failed') {
          platform.fail();
        } else {
          platform.completeLoad();
        }
        if (state == 'restart') await keys.save('b' * 32);
        await tester.pumpAndSettle();
        if (state == 'restart') {
          expect(find.text('已保存 · 重新启动后生效'), findsOneWidget);
        }
        if (state == 'failed') {
          double surfaceHeight() => tester
              .getSize(
                find
                    .descendant(
                      of: find.byType(MapPanel),
                      matching: find.byType(ClipRRect),
                    )
                    .first,
              )
              .height;
          expect(surfaceHeight(), 120);
          await tester.scrollUntilVisible(find.text('重试底图').hitTestable(), 100);
          await tester.tap(find.text('重试底图').hitTestable());
          await tester.pump();
          expect(
            surfaceHeight(),
            120,
            reason: 'P04 retry preserves known geometry',
          );
          platform.fail();
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: state);
        if (output.isNotEmpty) {
          await saveRenderPng(
            tester,
            find.byType(RepaintBoundary).first,
            '$output/map-$state-${small ? 'dark-320-200' : 'light-360-100'}-first.png',
          );
        }
        await tester.pumpWidget(const SizedBox());
        keys.dispose();
        consent.dispose();
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  for (final page in ['drive', 'charge']) {
    testWidgets('U07 $page 正式矩阵', (tester) async {
      final measurements = <String, Object>{};
      for (final scenario in [
        'normal',
        'safe-zero',
        'empty',
        'missing',
        'long',
        if (page == 'charge') 'expanded',
      ]) {
        for (final dark in [false, true]) {
          for (final scale in [
            1.0,
            2.0,
            if (scenario == 'normal') 1.3,
            if (scenario == 'normal') 1.5,
          ]) {
            final sizes = [
              const Size(360, 800),
              if (scale == 2 && scenario == 'long') const Size(320, 568),
              if (scenario == 'normal' && scale == 1) const Size(390, 844),
              if (scenario == 'normal' && scale == 2) const Size(768, 1024),
            ];
            for (final size in sizes) {
              await tester.pumpWidget(const SizedBox());
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1;
              tester.view.padding = FakeViewPadding(
                top: scenario == 'safe-zero' ? 0 : 24,
                bottom: scenario == 'safe-zero' ? 0 : 24,
              );
              tester.view.viewPadding = FakeViewPadding(
                top: scenario == 'safe-zero' ? 0 : 24,
                bottom: scenario == 'safe-zero' ? 0 : 24,
              );
              tester.platformDispatcher.textScaleFactorTestValue = scale;
              tester.platformDispatcher.platformBrightnessTestValue = dark
                  ? Brightness.dark
                  : Brightness.light;
              final chargeKeys = await configuredMapKeys();
              final platform = FakeMapPlatform();
              final consent = MapConsentController();
              if (scenario == 'normal' || scenario == 'safe-zero') {
                await consent.grant();
              }
              Map<String, dynamic> data(String name) {
                final value =
                    scenario == 'expanded' && name == 'charging-detail'
                    ? detailV2()
                    : scenario == 'expanded' && name == 'charging-series'
                    ? seriesV2()
                    : drive.fixture(name);
                if (name.endsWith('series') && scenario == 'empty') {
                  value['series'] = <Object>[];
                  value['points'] = 0;
                }
                if (name == 'drive-detail' && scenario == 'long') {
                  value['start']['display_name'] = '很长的出发地点 上海市浦东新区世纪大道一千二百号';
                  value['end']['display_name'] = '很长的目的地 苏州市工业园区金鸡湖大道充电站';
                }
                if (name == 'charging-detail' && scenario == 'long') {
                  value['location']['display_name'] =
                      '很长的充电地点 上海市浦东新区世纪大道地下停车场';
                }
                if (name == 'drive-detail' && scenario == 'missing') {
                  value['distance_km'] = null;
                  value['consumption_wh_km'] = null;
                }
                if (name == 'charging-detail' && scenario == 'missing') {
                  value['cost'] = null;
                  value['start_soc'] = null;
                  value['end_soc'] = null;
                }
                return value;
              }

              if (page == 'drive') {
                await drive.openDetail(
                  tester,
                  (r) async => jsonResponse(
                    jsonEncode(
                      data(
                        r.url.path.endsWith('/series')
                            ? 'drive-series'
                            : 'drive-detail',
                      ),
                    ),
                  ),
                  mapConsent: consent,
                  mapPlatform: platform,
                );
                if (scenario == 'normal' || scenario == 'safe-zero') {
                  platform.completeLoad();
                  await tester.pumpAndSettle();
                }
              } else {
                await tester.pumpWidget(
                  charge.app(
                    MockClient((r) async {
                      if (r.url.path.endsWith('/charging-sessions/1/series')) {
                        return charge.response(data('charging-series'));
                      }
                      if (r.url.path.endsWith('/charging-sessions/1')) {
                        return charge.response(data('charging-detail'));
                      }
                      return charge.initial(r);
                    }),
                    mapKeys: chargeKeys,
                  ),
                );
                await tester.pumpAndSettle();
                await tester.scrollUntilVisible(
                  find.text('最近充电').hitTestable(),
                  200,
                );
                await tester.tap(find.text('最近充电').hitTestable());
                await tester.pumpAndSettle();
              }
              final name =
                  '$page-$scenario-${dark ? 'dark' : 'light'}-${size.width.toInt()}-${(scale * 100).toInt()}';
              final scroll = find.byType(Scrollable).last;
              final position = tester.state<ScrollableState>(scroll).position;
              if ((scenario == 'normal' || scenario == 'expanded') &&
                  size.width == 360 &&
                  scale == 1) {
                final body = tester.getRect(find.byType(ListView).last);
                final plot = tester.getRect(
                  find.byKey(
                    ValueKey(
                      page == 'drive' ? 'sample-chart' : 'charging-time-chart',
                    ),
                  ),
                );
                final paint = tester.widget<CustomPaint>(
                  find
                      .descendant(
                        of: find.byKey(
                          ValueKey(
                            page == 'drive'
                                ? 'sample-chart'
                                : 'charging-time-chart',
                          ),
                        ),
                        matching: find.byType(CustomPaint),
                      )
                      .first,
                );
                final localPlot = (paint.painter as dynamic).plot as Rect;
                final dataTop = plot.top + localPlot.top;
                final visible = (body.bottom - dataTop).clamp(
                  0,
                  localPlot.height,
                );
                measurements[name] = {
                  'bodyHeight': body.height,
                  'plotTop': dataTop - body.top,
                  'plotHeight': localPlot.height,
                  'visible': visible,
                };
                expect(
                  visible,
                  greaterThanOrEqualTo(page == 'drive' ? 64 : 120),
                );
              }
              Future<void> shot(String station) async {
                expect(
                  tester.takeException(),
                  isNull,
                  reason: '$name-$station',
                );
                if (output.isNotEmpty) {
                  await saveRenderPng(
                    tester,
                    find.byType(RepaintBoundary).first,
                    '$output/$name-$station.png',
                  );
                }
              }

              await shot('first');
              if (scale == 1 && scenario == 'normal' && size.width == 360) {
                var index = 0;
                while (position.pixels < position.maxScrollExtent) {
                  position.jumpTo(
                    (position.pixels + 500).clamp(0, position.maxScrollExtent),
                  );
                  await tester.pumpAndSettle();
                  await shot('scroll${++index}');
                }
              } else {
                position.jumpTo(position.maxScrollExtent);
                await tester.pumpAndSettle();
                await shot('end');
              }
              await tester.pumpWidget(const SizedBox());
              consent.dispose();
              chargeKeys.dispose();
            }
          }
        }
      }
      if (output.isNotEmpty) {
        File('$output/$page-measurements.json').writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(measurements),
        );
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
      tester.view.resetPadding();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    }, skip: fontPath.isEmpty);
  }
}
