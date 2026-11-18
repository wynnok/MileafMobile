// AP08 概览 P01 全状态矩阵（交付手册 §5 正式渲染）。opt-in：未设置
// MILEAF_RENDER_OUTPUT / MILEAF_RENDER_FONT 时跳过。
//
// 机位按交付手册 §6.1 的页面包要求：R21/R25/R29/R30 与规格 §5 P01、
// 规格 §6 首屏预算（360×800、safeArea 上下 24）为基准，补 430 宽、130/150%、
// 200%、768 宽与 safeArea=0；状态按 Tickets AP08 动作列逐条取一机位。
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/overview_page.dart' show MetaPage;
import 'package:mileaf/src/workspace.dart';

import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'support/test_trust_store.dart' show MemoryTrustStore;

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

dynamic _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync());

http.Response _ok(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

class _AppearanceStore implements AppearancePreferenceStore {
  _AppearanceStore(this.value);
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String? next) async => value = next;
}

class _CurrencyStore implements CurrencyPreferenceStore {
  @override
  Future<String?> read(String site) async => 'CNY';

  @override
  Future<void> write(String site, String? code) async {}
}

/// 一条状态机位：P01 的每个状态只改一个资源，其余沿用本票夹具。
MockClient _client(String scenario) {
  return MockClient((request) async {
    final path = request.url.path;
    if (path.endsWith('/vehicles')) return _ok(_fixture('vehicles'));
    if (path.endsWith('/meta')) {
      if (scenario == 'capability') return http.Response('', 503);
      return _ok(_fixture('meta'));
    }
    if (path.endsWith('/summary')) {
      if (scenario == 'no-status') return http.Response('', 503);
      final body = _fixture('summary') as Map<String, dynamic>;
      switch (scenario) {
        case 'missing':
          body['battery'] = null;
          body['state'] = null;
        case 'asleep':
          body['state'] = {'value': 'asleep', 'since': '2026-03-15T11:00:00Z'};
          body['charging_power_kw'] = null;
        case 'offline':
          body['state'] = {'value': 'offline', 'since': '2026-03-15T11:00:00Z'};
          body['charging_power_kw'] = null;
      }
      return _ok(body);
    }
    if (path.endsWith('/stats')) {
      final kind = request.url.queryParameters['kind'];
      final from = request.url.queryParameters['from'] ?? '';
      if (scenario == 'charging-fail' && kind == 'charging') {
        return http.Response('', 503);
      }
      if (scenario == 'no-reference' && from.startsWith('2026-01')) {
        return http.Response('', 503);
      }
      if (kind == 'charging') return _ok(_fixture('charging-stats'));
      final driving = _fixture('driving-stats') as Map<String, dynamic>;
      if (scenario == 'empty-period') {
        driving['buckets'] = <Object>[];
        final totals = driving['totals'] as Map<String, dynamic>;
        totals['drives'] = 0;
        totals['distance_km'] = 0;
        totals['energy_kwh'] = 0;
      }
      return _ok(driving);
    }
    return http.Response('{}', 404);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Brightness brightness,
  required GlobalKey boundary,
  required Size size,
  required double scale,
  required String scenario,
  bool safeArea = true,
  bool fallbackZone = false,
  bool settle = true,
  http.Client? client,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = safeArea
      ? const FakeViewPadding(top: 24, bottom: 24)
      : FakeViewPadding.zero;
  tester.view.padding = tester.view.viewPadding;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  final session = MemorySessionStore()
    ..value = jsonEncode({
      'site': 'https://example.com/prefix',
      'token': 'test',
      'expires_at': '2099-01-01T00:00:00Z',
    });
  final appearance = AppearanceController(_AppearanceStore(brightness.name));
  await appearance.restore();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MileafApp(
        client: client ?? _client(scenario),
        sessionStore: session,
        trustStore: MemoryTrustStore(),
        vehiclePreferences: MemoryVehiclePreferences(),
        currencyPreferences: _CurrencyStore(),
        appearance: appearance,
        now: () => DateTime.utc(2026, 3, 15, 12),
        calendar: () async => CalendarContext(
          fallbackZone ? 'UTC' : 'Asia/Shanghai',
          fallback: fallbackZone,
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump();
    }
  }
}

/// FNV-1a 64：manifest 里的图像/字体哈希（无额外依赖，算法名一并记录）。
/// 以 63 位掩码收敛，避免 Dart 有符号 64 位整数出现负串。
String _hash(List<int> bytes) {
  var hash = 0xcbf29ce484222325;
  for (final byte in bytes) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & 0x7FFFFFFFFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

void main() {
  setUpAll(() async {
    if (fontPath.isNotEmpty) await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('AP08 P01 full-state matrix and service information', (
    tester,
  ) async {
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
      String scene,
      String mode,
      String camera, {
      String page = 'overview',
      bool settle = true,
    }) async {
      final name = 'AP08-$page-$scene-glass-$mode-$camera-top.png';
      final path = '$output/$name';
      await saveRenderPng(tester, find.byKey(boundary), path, settle: settle);
      images[name] = {
        'page': page,
        'scene': scene,
        'mode': mode,
        'camera': camera,
        'size': tester.getSize(find.byKey(boundary)).toString(),
        'fnv1a64': _hash(File(path).readAsBytesSync()),
      };
    }

    Future<void> shoot(
      String scenario,
      String scene, {
      Brightness brightness = Brightness.light,
      Size size = const Size(390, 844),
      double scale = 1,
      bool safeArea = true,
      bool fallbackZone = false,
      bool settle = true,
      http.Client? client,
    }) async {
      final boundary = GlobalKey();
      await _pump(
        tester,
        brightness: brightness,
        boundary: boundary,
        size: size,
        scale: scale,
        scenario: scenario,
        safeArea: safeArea,
        fallbackZone: fallbackZone,
        settle: settle,
        client: client,
      );
      final mode = brightness.name;
      final camera =
          '${size.width.round()}x${size.height.round()}-'
          '${(scale * 100).round()}${safeArea ? '' : '-safe0'}';
      await capture(boundary, scene, mode, camera, settle: settle);
    }

    // 正常态：浅深与代表机位。
    for (final brightness in Brightness.values) {
      await shoot('normal', 'normal', brightness: brightness);
    }
    await shoot('normal', 'normal', size: const Size(360, 800));
    await shoot('normal', 'normal', size: const Size(430, 932));
    // 代表机位补齐：320 宽 100%、360 宽深色 100%（§6.1 页面包）。
    await shoot('normal', 'normal', size: const Size(320, 568));
    await shoot(
      'normal',
      'normal',
      size: const Size(360, 800),
      brightness: Brightness.dark,
    );
    await shoot('normal', 'normal', scale: 1.3, size: const Size(360, 800));
    await shoot('normal', 'normal', scale: 1.5, size: const Size(360, 800));
    await shoot('normal', 'normal', scale: 2);
    await shoot('normal', 'normal', scale: 2, size: const Size(768, 1024));
    await shoot(
      'normal',
      'normal',
      size: const Size(360, 800),
      safeArea: false,
    );

    // 状态：无车况、车况缺失、休眠、离线、能力回退、比较不可用、
    // 费用覆盖缺失（补能失败）、时区回退、空期间。
    await shoot('no-status', 'no-status');
    await shoot('missing', 'missing');
    await shoot('asleep', 'asleep');
    await shoot('offline', 'offline');
    await shoot('capability', 'capability');
    await shoot('no-reference', 'no-reference');
    await shoot('charging-fail', 'charging-fail');
    await shoot('normal', 'timezone', fallbackZone: true);
    await shoot('empty-period', 'empty-period');

    // R31 首次加载：与最终结构同形的静态骨架。summary 挂起时截图，随后放行
    // 响应并落到终态，避免把挂起的请求计时器留到用例结束。
    final pendingSummary = Completer<http.Response>();
    final loadingClient = _client('normal');
    final loadingBoundary = GlobalKey();
    await _pump(
      tester,
      brightness: Brightness.light,
      boundary: loadingBoundary,
      size: const Size(390, 844),
      scale: 1,
      scenario: 'normal',
      settle: false,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/summary')) {
          return pendingSummary.future;
        }
        return http.Response.fromStream(
          await loadingClient.send(
            http.Request(request.method, request.url)
              ..headers.addAll(request.headers),
          ),
        );
      }),
    );
    await capture(
      loadingBoundary,
      'loading',
      'light',
      '390x844-100',
      settle: false,
    );
    pendingSummary.complete(_ok(_fixture('summary')));
    await tester.pumpAndSettle();

    // 刷新失败有旧数据：首帧成功后让 summary 改报失败再下拉。
    var failing = false;
    final refreshClient = _client('normal');
    final refreshBoundary = GlobalKey();
    await _pump(
      tester,
      brightness: Brightness.light,
      boundary: refreshBoundary,
      size: const Size(390, 844),
      scale: 1,
      scenario: 'normal',
      client: MockClient((request) async {
        if (failing && request.url.path.endsWith('/summary')) {
          return http.Response('', 503);
        }
        return http.Response.fromStream(
          await refreshClient.send(
            http.Request(request.method, request.url)
              ..headers.addAll(request.headers),
          ),
        );
      }),
    );
    failing = true;
    await tester.drag(find.byType(RefreshIndicator), const Offset(0, 300));
    await tester.pumpAndSettle();
    await capture(refreshBoundary, 'refresh-failed', 'light', '390x844-100');

    // 服务信息（P12）：分组卡 + 技术详情。
    for (final brightness in Brightness.values) {
      final boundary = GlobalKey();
      await _pump(
        tester,
        brightness: brightness,
        boundary: boundary,
        size: const Size(390, 844),
        scale: 1,
        scenario: 'normal',
      );
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('服务信息'), 180);
      await tester.tap(find.text('服务信息'));
      await tester.pumpAndSettle();
      expect(find.byType(MetaPage), findsOneWidget);
      await capture(
        boundary,
        'normal',
        brightness.name,
        '390x844-100',
        page: 'service',
      );
    }

    File('$output/manifest.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'ticket': 'AP08',
        'freeze_point': 'FP3 (eeefe83)',
        'input_sha': '8ea7e29',
        'fixture': 'test/fixtures/{summary,driving-stats,charging-stats,meta,vehicles}.json',
        'timezone': 'Asia/Shanghai（timezone 机位为 UTC 回退）',
        'sampled_at': '2026-03-15T12:00:00Z',
        'font': fontPath.isEmpty
            ? ''
            : {
                'path': fontPath,
                'fnv1a64': _hash(File(fontPath).readAsBytesSync()),
              },
        'dpr': 1,
        'safe_area': '上下各 24（safe0 机位为 0）',
        'keyboard': 'hidden',
        'material_preferences': 'glass',
        'hash_algorithm': 'fnv1a64',
        'images': images,
      }),
    );
  }, skip: output.isEmpty || fontPath.isEmpty);
}
