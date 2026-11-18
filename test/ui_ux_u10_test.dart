import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/map/map_key.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/shell_harness.dart'
    show MemoryAppearanceStore, shellClient, fixture;
import 'charging_test.dart' show MemoryCurrency;
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'support/map_key_fixture.dart';
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/test_trust_store.dart' show MemoryTrustStore;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/shell_harness.dart' show pumpShell;

const _output = String.fromEnvironment('MILEAF_U10_RENDER_OUTPUT');
const _font = String.fromEnvironment('MILEAF_RENDER_FONT');

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          MapBinding.channel,
          (_) async => {
            '包名': 'app.mileaf.mileaf',
            '签名 SHA-1': List.filled(20, 'AB').join(':'),
          },
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MapBinding.channel, null),
    );
  });
  setUpAll(() async {
    if (_output.isNotEmpty) await loadRenderFonts(cjkFontPath: _font);
  });
  testWidgets('外观弹层在320大字可滚动选择并有44关闭命中区', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await pumpShell(tester, textScale: 2);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('外观'));
    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final close = find.byTooltip('关闭');
    expect(close, findsOneWidget);
    expect(tester.getSize(close).shortestSide, greaterThanOrEqualTo(44));
    await tester.ensureVisible(find.text('深色'));
    await tester.tap(find.text('深色'));
    await tester.pumpAndSettle();
    expect(find.text('默认跟随系统。切换后立即生效，并保存在本机。'), findsNothing);
  });

  testWidgets('币种保存中保留文字反馈并禁用重复操作', (tester) async {
    final store = PendingCurrencyStore();
    final settings = CurrencySettings('https://example.com', store);
    await tester.pumpWidget(
      MaterialApp(
        theme: mileafTheme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: CurrencyPage(settings: settings),
      ),
    );
    await tester.tap(find.text('CNY'));
    await tester.pump();
    expect(find.text('正在保存币种偏好…'), findsOneWidget);
    await tester.tap(find.text('USD'));
    expect(store.writes, 1);
    store.pending.complete();
    await tester.pumpAndSettle();
    expect(settings.code, 'CNY');
    settings.dispose();
  });

  testWidgets('外观关闭后焦点返回原入口', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    final triggerFocus = Focus.of(tester.element(find.text('外观')));
    triggerFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byTooltip('关闭'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(triggerFocus.hasFocus, isTrue);
  });

  testWidgets('车辆关闭返回焦点且重复选同车保留期间而不刷新车辆', (tester) async {
    final calls = <Uri>[];
    await pumpShell(tester, calls: calls);
    final trigger = find.text('行笺测试车');
    final triggerFocus = Focus.of(tester.element(trigger));
    triggerFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(triggerFocus.hasFocus, isTrue);
    final month = find.widgetWithText(StatusChip, '本月');
    await tester.scrollUntilVisible(
      month,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    tester.widget<StatusChip>(month).onTap!();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      trigger,
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final before = calls.where((uri) => uri.path.endsWith('/vehicles')).length;
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.text('行笺测试车').last);
    await tester.pumpAndSettle();
    expect(calls.where((uri) => uri.path.endsWith('/vehicles')).length, before);
    expect(
      tester.widget<StatusChip>(find.widgetWithText(StatusChip, '本月')).selected,
      isTrue,
    );
    expect(find.text('选择车辆'), findsNothing);
    expect(trigger, findsOneWidget);
  });

  for (final empty in [false, true]) {
    testWidgets('320大字键盘从连接初始化到${empty ? '无车' : '有车'}接入完成', (tester) async {
      configureView(tester, const Size(320, 568), 2);
      await pumpFlow(tester, loggedIn: false, empty: empty);
      await connectAndSetup(tester);
      expect(tester.takeException(), isNull);
      expect(find.textContaining(empty ? '此站点暂无车辆' : '行笺测试车'), findsOneWidget);
    });
  }

  testWidgets('U10 接入表单处理中与服务错误正式渲染', (tester) async {
    for (final brightness in Brightness.values) {
      for (final scene in ['connect', 'login', 'setup', 'edit']) {
        configureView(tester, const Size(320, 568), 2);
        final pending = <String, Completer<http.Response>>{};
        final boundary = GlobalKey();
        await pumpFlow(
          tester,
          loggedIn: scene == 'edit',
          brightness: brightness,
          boundary: boundary,
          pendingResponses: pending,
        );
        if (scene == 'edit') {
          await tester.tap(find.byTooltip('设置'));
          await tester.pumpAndSettle();
          await tapText(tester, '站点连接');
          await tapText(tester, '更换连接');
        } else if (scene != 'connect') {
          await enterAndCheck(tester);
          if (scene == 'setup') await tapText(tester, '首次设置站点口令');
        }
        final endpoint = switch (scene) {
          'connect' || 'edit' => 'health',
          'login' => 'login',
          _ => 'setup',
        };
        final response = Completer<http.Response>();
        pending[endpoint] = response;
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        if (scene == 'connect') {
          await tester.enterText(find.byType(TextFormField), longSite);
        } else {
          final labels = scene == 'setup' ? ['新站点口令', '再次输入口令'] : ['站点访问口令'];
          for (final label in labels) {
            final field = find.widgetWithText(TextFormField, label);
            await tester.ensureVisible(field);
            await tester.enterText(field, 'synthetic-password');
          }
        }
        final label = switch (scene) {
          'connect' => '检查连接',
          'login' => '登录',
          'setup' => '设置口令并登录',
          _ => '验证并替换连接',
        };
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text(label).hitTestable(), findsOneWidget, reason: scene);
        await tester.tapAt(tester.getCenter(find.text(label)));
        await tester.pump(const Duration(milliseconds: 100));
        // Material starts its disabled text-colour transition on that frame.
        await tester.pump(const Duration(milliseconds: 300));
        // AP13（R27）：主按钮处理中保留原文字，只在尾部加活动指示器。
        expect(
          tester.widget<MileafButton>(find.byType(MileafButton)).loading,
          isTrue,
          reason: scene,
        );
        expect(find.text(label), findsOneWidget, reason: '处理中保留文字');
        expect(
          tester.widget<MileafButton>(find.byType(MileafButton)).onPressed,
          isNull,
        );
        final prefix = '$_output/u10-$scene';
        await saveRenderPng(
          tester,
          find.byKey(boundary),
          '$prefix-processing-${brightness.name}-320-200-keyboard.png',
          settle: false,
        );
        response.complete(
          http.Response(
            '{"error":{"code":"upstream_timeout","message":"synthetic"}}',
            503,
          ),
        );
        await tester.pumpAndSettle();
        final error = find.textContaining('上游');
        expect(error, findsOneWidget);
        await tester.ensureVisible(error);
        await tester.pumpAndSettle();
        await saveRenderPng(
          tester,
          find.byKey(boundary),
          '$prefix-error-${brightness.name}-320-200-keyboard.png',
        );
        await tester.pumpWidget(const SizedBox());
      }
    }
  }, skip: _output.isEmpty);

  testWidgets('U10 正式页面流程与完整滚动矩阵', (tester) async {
    final manifest = <String>[
      for (final brightness in Brightness.values)
        for (final scene in ['connect', 'login', 'setup', 'edit'])
          for (final state in ['processing', 'error'])
            'u10-$scene-$state-${brightness.name}-320-200-keyboard.png',
    ];
    for (final brightness in Brightness.values) {
      for (final spec in [
        (360.0, 800.0, 1.0),
        (360.0, 800.0, 2.0),
        (320.0, 568.0, 2.0),
        (390.0, 844.0, 1.3),
        (390.0, 844.0, 1.5),
        (768.0, 1024.0, 2.0),
      ]) {
        final (width, height, scale) = spec;
        configureView(tester, Size(width, height), scale);
        for (final scene in [
          'settings',
          'appearance',
          'currency',
          'service',
          'connection',
          'edit',
          'vehicles',
          'map',
          'map-saved',
          'map-restart',
          'map-failure',
          'map-help',
          'map-privacy',
          'connect',
          'login',
          'setup',
          'no-vehicles',
        ]) {
          tester.view.viewInsets = const FakeViewPadding();
          final boundary = GlobalKey();
          final isEntry = ['connect', 'login', 'setup'].contains(scene);
          final keys = MapKeyController(
            TestKeyStore()..failRead = scene == 'map-failure',
          );
          await keys.restore();
          if (scene == 'map-saved' || scene == 'map-restart') {
            await keys.save('a' * 32);
          }
          if (scene == 'map-restart') {
            keys.keyForMap();
            await keys.save('b' * 32);
          }
          await pumpFlow(
            tester,
            loggedIn: !isEntry,
            brightness: brightness,
            empty: scene == 'no-vehicles',
            long: width == 320,
            boundary: boundary,
            keys: keys,
          );
          if (!isEntry && scene != 'no-vehicles') {
            if (scene == 'vehicles') {
              await tapText(tester, width == 320 ? longName : '行笺测试车');
            } else {
              await tester.tap(find.byTooltip('设置'));
              await tester.pumpAndSettle();
              final target = switch (scene) {
                'appearance' => '外观',
                'currency' => '币种',
                'service' => '服务信息',
                'connection' || 'edit' => '站点连接',
                'map' ||
                'map-saved' ||
                'map-restart' ||
                'map-failure' ||
                'map-help' ||
                'map-privacy' => '地图',
                _ => null,
              };
              if (target != null) await tapText(tester, target);
              if (scene == 'edit') await tapText(tester, '更换连接');
              if (scene == 'map-help') await tapText(tester, '如何申请 Key');
              if (scene == 'map-privacy') await tapText(tester, '数据使用说明');
            }
          } else if (scene == 'login' || scene == 'setup') {
            await enterAndCheck(tester);
            if (scene == 'setup') await tapText(tester, '首次设置站点口令');
          }
          final prefix =
              'u10-$scene-${brightness.name}-${width.toInt()}-${(scale * 100).round()}';
          Future<void> capture(String position) async {
            final name = '$prefix-$position.png';
            await saveRenderPng(tester, find.byKey(boundary), '$_output/$name');
            manifest.add(name);
          }

          await capture('top');
          // Capture the real scroll path, including the final content/action.
          final scrolls = find.byType(Scrollable);
          if (scrolls.evaluate().isNotEmpty) {
            final scroll = scrolls.last;
            final position = tester.state<ScrollableState>(scroll).position;
            var index = 0;
            while (position.pixels < position.maxScrollExtent - 1 &&
                index < 24) {
              await tester.drag(scroll, Offset(0, -height * .6));
              await tester.pumpAndSettle();
              await capture('scroll${++index}');
            }
          }
          if (width == 320 &&
              ['connect', 'login', 'setup', 'edit', 'map'].contains(scene)) {
            final fields = find.byType(TextFormField).evaluate().isNotEmpty
                ? find.byType(TextFormField)
                : find.byType(TextField);
            await tester.ensureVisible(fields.first);
            await tester.tap(fields.first);
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            await tester.pumpAndSettle();
            await capture('keyboard-input');
            final action = switch (scene) {
              'connect' => '检查连接',
              'login' => '登录',
              'setup' => '设置口令并登录',
              'edit' => '验证并替换连接',
              _ => '保存 Key',
            };
            await tester.ensureVisible(find.text(action));
            await tester.pumpAndSettle();
            await capture('keyboard-action');
            // Real coordinates exercise validation/error feedback while keyboard is up.
            await tester.tapAt(tester.getCenter(find.text(action)));
            await tester.pumpAndSettle();
            await capture('keyboard-result');
          }
          expect(tester.takeException(), isNull, reason: prefix);
          await tester.pumpWidget(const SizedBox());
          keys.dispose();
        }
      }
    }
    await tester.runAsync(() async {
      await File('$_output/u10-manifest.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({'images': manifest}),
      );
    });
  }, skip: _output.isEmpty);
}

const longName = '行笺测试车 · 长途旅行与家庭通勤专用车辆 完整名称展示';
const longSite =
    'https://mileaf.example.com:8443/teslamate/family/long-proxy-prefix';

void configureView(WidgetTester tester, Size size, double scale) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.viewInsets = const FakeViewPadding();
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
    tester.view.resetViewPadding();
    tester.view.resetViewInsets();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

Future<void> pumpFlow(
  WidgetTester tester, {
  bool loggedIn = true,
  bool empty = false,
  bool long = false,
  Brightness brightness = Brightness.light,
  GlobalKey? boundary,
  MapKeyController? keys,
  Map<String, Completer<http.Response>>? pendingResponses,
}) async {
  final fallback = shellClient();
  final client = MockClient((request) async {
    final pending = pendingResponses?[request.url.path.split('/').last];
    if (pending != null) return pending.future;
    if (request.url.path.endsWith('/health')) {
      return http.Response('{"status":"ok","version":"0.1.0"}', 200);
    }
    if (request.url.path.endsWith('/auth/setup')) {
      return http.Response('{"status":"ok"}', 200);
    }
    if (request.url.path.endsWith('/auth/login')) {
      return http.Response(
        '{"token":"synthetic-token","expires_at":"2099-01-01T00:00:00Z"}',
        200,
      );
    }
    if (request.url.path.endsWith('/vehicles')) {
      final vehicles = fixture('vehicles') as List;
      if (long) vehicles[0]['name'] = longName;
      return http.Response(
        jsonEncode(empty ? [] : vehicles),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response.fromStream(await fallback.send(request));
  });
  final appearance = AppearanceController(
    MemoryAppearanceStore()..value = brightness.name,
  );
  await appearance.restore();
  final store = MemorySessionStore();
  if (loggedIn) {
    store.value = jsonEncode({
      'site': long ? longSite : 'https://mileaf.example.com',
      'token': 'synthetic-token',
      'expires_at': '2099-01-01T00:00:00Z',
    });
  }
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MileafApp(
        key: UniqueKey(),
        client: client,
        sessionStore: store,
        appearance: appearance,
        currencyPreferences: MemoryCurrency(),
        mapKeys: keys,
        trustStore: MemoryTrustStore(),
        vehiclePreferences: MemoryVehiclePreferences(),
        now: () => DateTime.utc(2026, 10, 26, 10, 40),
        calendar: () async => CalendarContext('Asia/Shanghai'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  if (find.text(text).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(text),
      120,
      scrollable: find.byType(Scrollable).last,
    );
  }
  final target = find.text(text).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget, reason: text);
  await tester.tapAt(tester.getCenter(target));
  await tester.pumpAndSettle();
}

Future<void> enterAndCheck(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField), longSite);
  await tapText(tester, '检查连接');
  await tapText(tester, '登录此站点');
}

Future<void> connectAndSetup(WidgetTester tester) async {
  await enterAndCheck(tester);
  await tapText(tester, '首次设置站点口令');
  tester.view.viewInsets = const FakeViewPadding(bottom: 300);
  await tester.pumpAndSettle();
  for (final label in ['新站点口令', '再次输入口令']) {
    final field = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(field);
    await tester.enterText(field, 'synthetic-password');
  }
  await tapText(tester, '设置口令并登录');
}

class PendingCurrencyStore implements CurrencyPreferenceStore {
  final pending = Completer<void>();
  int writes = 0;
  @override
  Future<String?> read(String site) async => null;
  @override
  Future<void> write(String site, String? code) {
    writes++;
    return pending.future;
  }
}
