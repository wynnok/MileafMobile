import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/design/components/nav_bar.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

class MemoryAppearanceStore implements AppearancePreferenceStore {
  String? value;
  bool failWrites = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? next) async {
    if (failWrites) throw StateError('disk full');
    value = next;
  }
}

dynamic fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync());

http.Response _ok(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

MockClient shellClient({List<Uri>? calls}) => MockClient((request) async {
  calls?.add(request.url);
  final path = request.url.path;
  if (path.endsWith('/vehicles')) return _ok(fixture('vehicles'));
  if (path.endsWith('/meta')) return _ok(fixture('meta'));
  if (path.endsWith('/summary')) return _ok(fixture('summary'));
  if (path.endsWith('/stats')) {
    return _ok(
      fixture(
        request.url.queryParameters['kind'] == 'charging'
            ? 'charging-stats'
            : 'driving-stats',
      ),
    );
  }
  if (path.endsWith('/drives')) return _ok(fixture('drives'));
  if (path.endsWith('/charging-sessions')) {
    return _ok({'items': [], 'next_cursor': null});
  }
  return http.Response('{}', 404);
});

Future<AppearanceController> pumpShell(
  WidgetTester tester, {
  AppearanceController? appearance,
  List<Uri>? calls,
  double textScale = 1,
}) async {
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() => tester.platformDispatcher.clearTextScaleFactorTestValue());
  final controller =
      appearance ?? AppearanceController(MemoryAppearanceStore());
  final store = MemorySessionStore()
    ..value = jsonEncode({
      'site': 'https://example.com/prefix',
      'token': 'test',
      'expires_at': '2099-01-01T00:00:00Z',
    });
  await tester.pumpWidget(
    MileafApp(
      client: shellClient(calls: calls),
      appearance: controller,
      sessionStore: store,
      trustStore: MemoryTrustStore(),
      vehiclePreferences: MemoryVehiclePreferences(),
      now: () => DateTime.utc(2026, 10, 26, 10, 40),
      calendar: () async => CalendarContext('Asia/Shanghai'),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  group('外观控制器', () {
    test('默认跟随系统，保存后恢复', () async {
      final store = MemoryAppearanceStore();
      final controller = AppearanceController(store);
      expect(controller.mode, MileafAppearance.system);
      expect(controller.themeMode, ThemeMode.system);
      await controller.select(MileafAppearance.light);
      expect(store.value, 'light');

      final restored = AppearanceController(store);
      await restored.restore();
      expect(restored.mode, MileafAppearance.light);
      expect(restored.themeMode, ThemeMode.light);
    });

    test('未知值回退跟随系统，写入失败回滚', () async {
      final store = MemoryAppearanceStore()..value = 'sepia';
      final controller = AppearanceController(store);
      await controller.restore();
      expect(controller.mode, MileafAppearance.system);
      expect(controller.themeMode, ThemeMode.system);

      store.failWrites = true;
      await expectLater(
        controller.select(MileafAppearance.light),
        throwsA(isA<StateError>()),
      );
      expect(controller.mode, MileafAppearance.system);
    });
  });

  testWidgets('冷启动跟随系统，切换浅色即时生效并重启保持', (tester) async {
    // No saved preference: `main()` restores before `runApp`, so the first
    // frame is the system theme rather than a dark frame that flips later.
    final store = MemoryAppearanceStore();
    final first = AppearanceController(store);
    await first.restore();
    await pumpShell(tester, appearance: first);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
    expect(
      tester
          .widget<MaterialApp>(find.byType(MaterialApp))
          .themeAnimationDuration,
      const Duration(milliseconds: 200),
      reason: 'Spec §11：主题切换 200ms，accentStrong 参与插值',
    );
    expect(
      Theme.of(tester.element(find.byType(MileafNavBar))).brightness,
      Brightness.light,
      reason: '测试平台亮度默认浅色，首帧即为浅色，不先深后浅',
    );

    await first.select(MileafAppearance.light);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    expect(
      Theme.of(tester.element(find.byType(MileafNavBar))).brightness,
      Brightness.light,
    );

    final second = AppearanceController(store);
    await second.restore();
    await pumpShell(tester, appearance: second);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
  });

  testWidgets('冷启动首帧即为主题亮度，不先深后浅', (tester) async {
    // §13 第 2 条：`restore()` 在 `runApp` 之前完成，所以第一帧（未 settle）
    // 就必须解析成平台亮度，而不是先渲染深色再被 `restore` 翻过来。
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final controller = AppearanceController(MemoryAppearanceStore());
    await controller.restore();
    final store = MemorySessionStore()
      ..value = jsonEncode({
        'site': 'https://example.com/prefix',
        'token': 'test',
        'expires_at': '2099-01-01T00:00:00Z',
      });
    await tester.pumpWidget(
      MileafApp(
        client: shellClient(),
        appearance: controller,
        sessionStore: store,
        trustStore: MemoryTrustStore(),
        vehiclePreferences: MemoryVehiclePreferences(),
        now: () => DateTime.utc(2026, 10, 26, 10, 40),
        calendar: () async => CalendarContext('Asia/Shanghai'),
      ),
    );
    Brightness? firstFrame;
    for (final theme in tester.widgetList<Theme>(find.byType(Theme))) {
      firstFrame = theme.data.brightness;
      break;
    }
    expect(firstFrame, Brightness.dark, reason: '首帧必须直接是深色，不能先浅后深');
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(MileafNavBar))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('system 下平台亮度切换后 Theme.brightness 跟随', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    final store = MemoryAppearanceStore();
    final controller = AppearanceController(store);
    await pumpShell(tester, appearance: controller);

    expect(controller.mode, MileafAppearance.system);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
    expect(
      Theme.of(tester.element(find.byType(MileafNavBar))).brightness,
      Brightness.dark,
    );

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(MileafNavBar))).brightness,
      Brightness.light,
    );
    expect(store.value, isNull, reason: '跟随系统不写入本机偏好');

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.byType(MileafNavBar))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('已保存的偏好优先于系统亮度', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    final store = MemoryAppearanceStore()..value = 'light';
    final controller = AppearanceController(store);
    await controller.restore();
    await pumpShell(tester, appearance: controller);
    expect(controller.mode, MileafAppearance.light);
    expect(
      Theme.of(tester.element(find.byType(MileafNavBar))).brightness,
      Brightness.light,
      reason: '已存偏好不被系统深色覆盖',
    );
  });

  testWidgets('顶栏唯一刷新入口：AppBar 刷新移除，车辆刷新在车辆 sheet', (tester) async {
    final calls = <Uri>[];
    await pumpShell(tester, calls: calls);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byTooltip('刷新概览'), findsOneWidget);
    expect(find.byTooltip('刷新车辆'), findsNothing);
    expect(find.text('行笺'), findsWidgets);
    expect(find.text('行笺测试车'), findsOneWidget);
    expect(find.byTooltip('设置'), findsOneWidget);

    await tester.tap(find.text('行笺测试车'));
    await tester.pumpAndSettle();
    expect(find.text('选择车辆'), findsOneWidget);
    expect(find.byTooltip('刷新车辆'), findsOneWidget);
    final before = calls.where((u) => u.path.endsWith('/vehicles')).length;
    await tester.tap(find.byTooltip('刷新车辆'));
    await tester.pumpAndSettle();
    expect(
      calls.where((u) => u.path.endsWith('/vehicles')).length,
      greaterThan(before),
    );
  });

  testWidgets('四 Tab 导航可切换并保留可点区域', (tester) async {
    await pumpShell(tester);
    expect(find.byType(MileafNavBar), findsOneWidget);
    for (final label in ['概览', '行程', '充电', '统计']) {
      expect(
        find.descendant(
          of: find.byType(MileafNavBar),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }
    await tester.tap(
      find.descendant(of: find.byType(MileafNavBar), matching: find.text('行程')),
    );
    await tester.pumpAndSettle();
    expect(find.text('行程'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('200% 字号下导航标签不截断、顶栏不横向溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await pumpShell(tester, textScale: 2.0);
    final nav = tester.getRect(find.byType(MileafNavBar));
    for (final label in ['概览', '行程', '充电', '统计']) {
      final rect = tester.getRect(
        find.descendant(
          of: find.byType(MileafNavBar),
          matching: find.text(label),
        ),
      );
      expect(rect.width, greaterThan(0));
      expect(rect.bottom, lessThanOrEqualTo(nav.bottom));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('设置中的外观切换生效并持久化', (tester) async {
    final store = MemoryAppearanceStore();
    final controller = AppearanceController(store);
    await pumpShell(tester, appearance: controller);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('连接与本地访问'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget, reason: '默认项即当前值');

    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    for (final label in ['跟随系统', '浅色', '深色']) {
      expect(
        find.descendant(of: sheet, matching: find.text(label)),
        findsOneWidget,
      );
    }
    // 顺序固定为 跟随系统 / 浅色 / 深色，默认项置顶。
    final tops = [
      for (final label in ['跟随系统', '浅色', '深色'])
        tester
            .getTopLeft(find.descendant(of: sheet, matching: find.text(label)))
            .dy,
    ];
    expect(tops[0], lessThan(tops[1]));
    expect(tops[1], lessThan(tops[2]));
    expect(find.text('默认跟随系统。切换后立即生效，并保存在本机。'), findsOneWidget);

    await tester.tap(find.descendant(of: sheet, matching: find.text('浅色')));
    await tester.pumpAndSettle();
    expect(controller.mode, MileafAppearance.light);
    expect(store.value, 'light');
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    expect(find.text('跟随系统'), findsNothing);
    expect(find.text('浅色'), findsOneWidget);
  });
}
