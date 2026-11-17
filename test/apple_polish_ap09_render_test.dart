// AP09 行程列表与行程详情 after 渲染入口（P02/P04 全状态矩阵）。opt-in：
// 未设置 MILEAF_RENDER_OUTPUT / MILEAF_RENDER_FONT 时跳过。机位按交付手册
// §6.1 的页面包要求：390/360/320 宽、浅深、100/150/200%、safeArea=0 与 430 宽，
// 另含本页状态（空、失败、刷新失败有旧数据）与地图状态（无 Key、未同意、
// 待重启、底图失败、无轨迹、单点）。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/map/map_consent.dart';
import 'package:mileaf/src/map/map_key.dart';
import 'package:mileaf/src/map/map_platform.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/c_fixture.dart' show cNow, cSite;
import 'support/c_gallery_client.dart';
import 'support/fake_map_platform.dart';
import 'support/map_key_fixture.dart';
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
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

class _CurrencyStore implements CurrencyPreferenceStore {
  @override
  Future<String?> read(String site) async => 'CNY';

  @override
  Future<void> write(String site, String? code) async {}
}

Finder _nav(String label) =>
    find.descendant(of: find.byType(MileafNavBar), matching: find.text(label));

Future<void> _pump(
  WidgetTester tester, {
  required Brightness brightness,
  required GlobalKey boundary,
  required Size size,
  required double scale,
  double topInset = 24,
  double bottomInset = 24,
  http.Client? client,
  MapConsentController? consent,
  MapKeyController? keys,
  MapPlatform? platform,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = FakeViewPadding(top: topInset, bottom: bottomInset);
  tester.view.padding = tester.view.viewPadding;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  final session = MemorySessionStore()
    ..value = jsonEncode({
      'site': cSite,
      'token': 'test',
      'expires_at': '2099-01-01T00:00:00Z',
    });
  final appearance = AppearanceController(_AppearanceStore(brightness.name));
  await appearance.restore();
  final mapKeys = keys ?? await configuredMapKeys();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MileafApp(
        client: client ?? cGalleryClient(),
        mapConsent: consent,
        mapKeys: mapKeys,
        mapPlatform: platform,
        sessionStore: session,
        trustStore: MemoryTrustStore(),
        vehiclePreferences: MemoryVehiclePreferences(),
        currencyPreferences: _CurrencyStore(),
        appearance: appearance,
        now: () => cNow,
        calendar: () async => CalendarContext('Asia/Shanghai'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(_nav('行程'));
  await tester.pumpAndSettle();
}

Future<void> _openDetail(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('drive-17')).hitTestable(),
    200,
  );
  await tester.tap(find.byKey(const ValueKey('drive-17')));
  await tester.pumpAndSettle();
}

/// 以 C 快照为底，按需替换行程列表、明细或曲线。
MockClient _client({
  String drives = 'normal',
  String series = 'normal',
  String? driveDetail,
}) {
  final inner = cGalleryClient();
  return MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/drives/17/series')) {
      if (series == 'empty') {
        return http.Response(
          jsonEncode({
            'drive_id': 17,
            'resolution': 'empty',
            'points': 0,
            'series': <Object>[],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (series == 'single') {
        return http.Response(
          jsonEncode({
            'drive_id': 17,
            'resolution': 'server_sampled',
            'points': 1,
            'series': [
              {
                't': '2026-03-15T08:00:00Z',
                'lat': null,
                'lon': null,
                'speed_kmh': 0,
                'battery_level': 70,
                'elevation_m': null,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
    }
    if (path.endsWith('/drives')) {
      if (drives == 'failed') return http.Response('', 503);
      if (drives == 'empty') {
        return http.Response(
          jsonEncode({'items': <Object>[], 'next_cursor': null}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
    }
    if (path.endsWith('/drives/17') && driveDetail != null) {
      return http.Response(
        driveDetail,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    final forwarded = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return http.Response.fromStream(await inner.send(forwarded));
  });
}

/// 由用例控制何时开始失败，用于「刷新失败有旧数据」。
MockClient _clientWithFailFlag(List<bool> flag) {
  final base = _client();
  return MockClient((request) async {
    final path = request.url.path;
    if (flag[0] &&
        (path.endsWith('/drives') ||
            path.endsWith('/drives/17') ||
            path.endsWith('/drives/17/series'))) {
      return http.Response('', 503);
    }
    final forwarded = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return http.Response.fromStream(await base.send(forwarded));
  });
}

void main() {
  setUpAll(() async {
    if (fontPath.isNotEmpty) await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('AP09 行程列表与行程详情状态矩阵', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
      tester.view.resetPadding();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final images = <String, Map<String, Object?>>{};

    Future<void> capture(
      GlobalKey boundary,
      String page,
      String scene,
      String mode,
      String camera,
      String position,
    ) async {
      final name = 'AP09-$page-$scene-glass-$mode-$camera-$position.png';
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

    /// 390/360/320/430 宽与 100/150/200%、safeArea=0 的列表机位。
    for (final config in const [
      (
        brightness: Brightness.light,
        size: Size(390, 844),
        scale: 1.0,
        inset: 24.0,
        camera: '390x844-100',
      ),
      (
        brightness: Brightness.dark,
        size: Size(390, 844),
        scale: 1.0,
        inset: 24.0,
        camera: '390x844-100',
      ),
      (
        brightness: Brightness.light,
        size: Size(360, 800),
        scale: 1.0,
        inset: 24.0,
        camera: '360x800-100',
      ),
      (
        brightness: Brightness.light,
        size: Size(320, 568),
        scale: 2.0,
        inset: 24.0,
        camera: '320x568-200',
      ),
      (
        brightness: Brightness.light,
        size: Size(430, 932),
        scale: 1.0,
        inset: 24.0,
        camera: '430x932-100',
      ),
      (
        brightness: Brightness.light,
        size: Size(390, 844),
        scale: 1.5,
        inset: 24.0,
        camera: '390x844-150',
      ),
      (
        brightness: Brightness.light,
        size: Size(390, 844),
        scale: 1.0,
        inset: 0.0,
        camera: '390x844-100-safearea0',
      ),
    ]) {
      final boundary = GlobalKey();
      await _pump(
        tester,
        brightness: config.brightness,
        boundary: boundary,
        size: config.size,
        scale: config.scale,
        topInset: config.inset,
        bottomInset: config.inset,
      );
      await capture(
        boundary,
        '行程',
        'normal',
        config.brightness.name,
        config.camera,
        'top',
      );
      if (config.camera == '390x844-100' &&
          config.brightness == Brightness.light) {
        await tester.scrollUntilVisible(find.text('今天'), 200);
        await Scrollable.ensureVisible(
          tester.element(find.text('今天')),
          alignment: .1,
        );
        await tester.pumpAndSettle();
        await capture(
          boundary,
          '行程',
          'records',
          'light',
          config.camera,
          'scrolled',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }

    // 空、失败、刷新失败有旧数据三种 P02 状态。
    final staleFlag = <bool>[false];
    for (final (scene, client) in [
      ('empty', _client(drives: 'empty')),
      ('failed', _client(drives: 'failed')),
      ('stale', _clientWithFailFlag(staleFlag)),
    ]) {
      final boundary = GlobalKey();
      await _pump(
        tester,
        brightness: Brightness.light,
        boundary: boundary,
        size: const Size(390, 844),
        scale: 1,
        client: client,
      );
      if (scene == 'stale') {
        staleFlag[0] = true;
        await tester.tap(find.byTooltip('刷新行程'));
        await tester.pumpAndSettle();
      }
      await capture(boundary, '行程', scene, 'light', '390x844-100', 'top');
      await tester.pumpWidget(const SizedBox.shrink());
    }

    /// 详情机位：底图状态由 consent / keys / platform 注入。
    Future<void> detailScene(
      String scene, {
      Brightness brightness = Brightness.light,
      Size size = const Size(390, 844),
      double scale = 1,
      double inset = 24,
      String camera = '390x844-100',
      String series = 'normal',
      bool readyMap = true,
      bool failMap = false,
      String? keyMode,
      bool consentGranted = true,
    }) async {
      final boundary = GlobalKey();
      final consent = MapConsentController();
      if (consentGranted) await consent.grant();
      final platform = FakeMapPlatform();
      MapKeyController? keys;
      if (keyMode == 'nokey') {
        keys = MapKeyController(TestKeyStore());
        await keys.restore();
      } else if (keyMode == 'restart') {
        keys = MapKeyController(
          TestKeyStore()..value = 'a' * 32,
          readProcessKey: () async => 'b' * 32,
        );
        await keys.restore();
      }
      await _pump(
        tester,
        brightness: brightness,
        boundary: boundary,
        size: size,
        scale: scale,
        topInset: inset,
        bottomInset: inset,
        client: _client(series: series),
        consent: consent,
        keys: keys,
        platform: platform,
      );
      await _openDetail(tester);
      if (failMap) {
        platform.fail();
      } else if (readyMap && keyMode == null && consentGranted) {
        platform.completeLoad('GS(test)');
      }
      await tester.pumpAndSettle();
      await capture(boundary, '行程详情', scene, brightness.name, camera, 'top');
      await tester.pumpWidget(const SizedBox.shrink());
      consent.dispose();
      keys?.dispose();
    }

    await detailScene('normal');
    await detailScene('normal', brightness: Brightness.dark);
    await detailScene(
      'normal',
      size: const Size(360, 800),
      camera: '360x800-100',
    );
    await detailScene(
      'normal',
      size: const Size(430, 932),
      camera: '430x932-100',
    );
    await detailScene(
      'normal',
      size: const Size(320, 568),
      scale: 2,
      camera: '320x568-200',
    );
    await detailScene('normal', scale: 1.5, camera: '390x844-150');
    await detailScene('normal', inset: 0, camera: '390x844-100-safearea0');
    await detailScene('nokey', keyMode: 'nokey', camera: '390x844-100');
    await detailScene(
      'no-consent',
      consentGranted: false,
      readyMap: false,
      camera: '390x844-100',
    );
    await detailScene('restart', keyMode: 'restart', camera: '390x844-100');
    await detailScene('map-failed', failMap: true, camera: '390x844-100');
    await detailScene('no-track', series: 'empty', camera: '390x844-100');
    await detailScene('single-point', series: 'single', camera: '390x844-100');

    // 详情刷新失败有旧数据。
    {
      final boundary = GlobalKey();
      final consent = MapConsentController();
      await consent.grant();
      final failFlag = <bool>[false];
      await _pump(
        tester,
        brightness: Brightness.light,
        boundary: boundary,
        size: const Size(390, 844),
        scale: 1,
        client: _clientWithFailFlag(failFlag),
        consent: consent,
        platform: FakeMapPlatform(),
      );
      await _openDetail(tester);
      failFlag[0] = true;
      await tester.tap(find.byTooltip('刷新行程详情'));
      await tester.pumpAndSettle();
      await capture(boundary, '行程详情', 'stale', 'light', '390x844-100', 'top');
      await tester.pumpWidget(const SizedBox.shrink());
      consent.dispose();
    }

    // 详情下滚：过程图与「同时查看电量」、事实表与参考电耗、关于这些数据。
    for (final (scene, anchor, align) in [
      ('过程图', '行驶过程', .05),
      ('事实表', '驾驶与环境', .2),
      ('关于这些数据', '关于这些数据', .1),
    ]) {
      final boundary = GlobalKey();
      final consent = MapConsentController();
      await consent.grant();
      final platform = FakeMapPlatform();
      await _pump(
        tester,
        brightness: Brightness.light,
        boundary: boundary,
        size: const Size(390, 844),
        scale: 1,
        consent: consent,
        platform: platform,
      );
      await _openDetail(tester);
      platform.completeLoad('GS(test)');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(anchor), 200);
      await Scrollable.ensureVisible(
        tester.element(find.text(anchor)),
        alignment: align,
      );
      await tester.pumpAndSettle();
      await capture(
        boundary,
        '行程详情',
        scene,
        'light',
        '390x844-100',
        'scrolled',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      consent.dispose();
    }

    // 200% 详情：过程图与分段重排。
    {
      final boundary = GlobalKey();
      final consent = MapConsentController();
      await consent.grant();
      final platform = FakeMapPlatform();
      await _pump(
        tester,
        brightness: Brightness.light,
        boundary: boundary,
        size: const Size(390, 844),
        scale: 2,
        consent: consent,
        platform: platform,
      );
      await _openDetail(tester);
      platform.completeLoad('GS(test)');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('行驶过程'), 200);
      await Scrollable.ensureVisible(
        tester.element(find.text('行驶过程')),
        alignment: .05,
      );
      await tester.pumpAndSettle();
      await capture(
        boundary,
        '行程详情',
        '过程图',
        'light',
        '390x844-200',
        'scrolled',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      consent.dispose();
    }

    File('$output/manifest.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'ticket': 'AP09',
        'input_sha': '8ea7e29',
        'freeze_point': 'FP3 (eeefe83)',
        'fixture': 'cGalleryClient / CostSite',
        'timezone': 'Asia/Shanghai',
        'sampled_at': cNow.toIso8601String(),
        'font': fontPath,
        'font_sha256': fontSha,
        'dpr': 1,
        'keyboard': 'hidden',
        'material_preferences': 'default',
        'images': images,
      }),
    );
  }, skip: output.isEmpty || fontPath.isEmpty);
}
