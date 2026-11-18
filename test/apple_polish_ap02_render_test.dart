// AP02 导航外壳正式渲染入口（交付手册 §5、§6.1 外壳机位）。
//
// opt-in：未设置 MILEAF_RENDER_OUTPUT / MILEAF_RENDER_FONT 时跳过。
// 机位：滚动 0/8/16/100（浅深）、320 宽 200% 大字、768 宽、底栏实色路径、
// 大内容查看器；另含全量应用浅深的展开首屏与深滚收起两屏。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/display_preferences.dart';
import 'package:mileaf/src/design/layout.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/tokens.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/c_fixture.dart' show cNow, cSite;
import 'support/c_gallery_client.dart';
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'support/test_trust_store.dart' show MemoryTrustStore;

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

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

/// 外壳机位的页面替身：画布 + 一列内容块，顶栏留白用外壳展开态高度。
class ShellScene extends StatelessWidget {
  const ShellScene({super.key, required this.scroll});

  final ValueListenable<double> scroll;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.only(
            top: MileafLayout.rootTopClearance(context),
            bottom: 240,
            left: MileafSpace.s20,
            right: MileafSpace.s20,
          ),
          children: [
            for (var i = 0; i < 10; i++)
              Container(
                height: 64,
                margin: const EdgeInsets.only(bottom: MileafSpace.s12),
                decoration: BoxDecoration(
                  color: i.isEven ? colors.surface : colors.surfaceRaised,
                  borderRadius: BorderRadius.circular(MileafRadius.lg),
                ),
                child: Center(child: Text('内容块 ${i + 1}')),
              ),
          ],
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MileafTopBar(
                vehicleName: '行笺测试车',
                onVehicle: () {},
                onSettings: () {},
                scrollListenable: scroll,
              ),
              const MileafNoticeBanner(text: null),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required Brightness brightness,
  required GlobalKey boundary,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.padding = tester.view.viewPadding;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  final session = MemorySessionStore()
    ..value = jsonEncode({
      'site': cSite,
      'token': 'test',
      'expires_at': '2099-01-01T00:00:00Z',
    });
  final appearance = AppearanceController(_AppearanceStore(brightness.name));
  await appearance.restore();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MileafApp(
        client: cGalleryClient(),
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
}

/// 外壳机位：真外壳 + 页面替身，滚动位置由 ValueNotifier 直接驱动。
Future<ValueNotifier<double>> _pumpShell(
  WidgetTester tester, {
  required Brightness brightness,
  required GlobalKey boundary,
  double scroll = 0,
  Size size = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
  bool highContrast = false,
  bool withBar = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.padding = tester.view.viewPadding;
  final preferences = DisplayPreferencesController(
    platform: DisplayPreferencesPlatform.android,
  );
  addTearDown(preferences.dispose);
  final notifier = ValueNotifier<double>(scroll);
  addTearDown(notifier.dispose);
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: DisplayPreferencesScope(
        controller: preferences,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: mileafTheme(brightness),
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: textScaler,
              devicePixelRatio: 1,
              highContrast: highContrast,
              viewPadding: const EdgeInsets.only(top: 24, bottom: 24),
              padding: const EdgeInsets.only(top: 24, bottom: 24),
            ),
            child: Scaffold(
              extendBody: withBar,
              body: ShellScene(scroll: notifier),
              bottomNavigationBar: withBar
                  ? MileafNavBar(index: 0, onSelected: (_) {})
                  : null,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return notifier;
}

void main() {
  setUpAll(() async {
    if (fontPath.isNotEmpty) await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('AP02 shell gallery', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
      tester.view.resetPadding();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });
    final geometry = <String, Object?>{
      'logical_size': '390x844',
      'pixel_ratio': 2,
      'safe_area': <String, int>{'top': 24, 'bottom': 24},
      'timezone': 'Asia/Shanghai',
      'fixture': 'cGalleryClient / CostSite',
      'font': fontPath,
      'input_sha': 'FP1-c18f2fc',
      'scene': 'R26/PD01 可收起大标题外壳、底栏封顶、大内容查看器',
      'dpr': 2,
      'keyboard': 'none',
      'material_preferences': <String, Object?>{
        'reduce_transparency': false,
        'high_contrast': false,
        'platform': 'android',
      },
      'text_scales': <int>[100, 200],
    };

    for (final brightness in Brightness.values) {
      final mode = brightness.name;
      final app = GlobalKey();
      await _pumpApp(tester, brightness: brightness, boundary: app);
      await saveRenderPng(
        tester,
        find.byKey(app),
        '$output/AP02-shell-expanded-glass-$mode-390x844-100-top.png',
      );
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -320));
      await tester.pumpAndSettle();
      await saveRenderPng(
        tester,
        find.byKey(app),
        '$output/AP02-shell-collapsed-glass-$mode-390x844-100-scrolled.png',
      );
      geometry['app-$mode'] = {
        'top_bar': _rect(tester.getRect(find.byType(MileafTopBar))),
        'bottom_bar': _rect(tester.getRect(find.byType(MileafNavBar))),
      };

      for (final scroll in [0.0, 8.0, 16.0, 100.0]) {
        final boundary = GlobalKey();
        await tester.pumpWidget(const SizedBox.shrink());
        await _pumpShell(
          tester,
          brightness: brightness,
          boundary: boundary,
          scroll: scroll,
        );
        final tag = scroll.toInt().toString().padLeft(3, '0');
        await saveRenderPng(
          tester,
          find.byKey(boundary),
          '$output/AP02-shell-scroll$tag-glass-$mode-390x844-100-top.png',
        );
        geometry['shell-$scroll-$mode'] = {
          'top_bar': _rect(tester.getRect(find.byType(MileafTopBar))),
          'bottom_bar': _rect(tester.getRect(find.byType(MileafNavBar))),
        };
      }
    }

    var boundary = GlobalKey();
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpShell(
      tester,
      brightness: Brightness.light,
      boundary: boundary,
      size: const Size(320, 800),
      textScaler: const TextScaler.linear(2),
    );
    await saveRenderPng(
      tester,
      find.byKey(boundary),
      '$output/AP02-shell-expanded-glass-light-320x800-200-top.png',
    );

    boundary = GlobalKey();
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpShell(
      tester,
      brightness: Brightness.light,
      boundary: boundary,
      size: const Size(768, 1024),
    );
    await saveRenderPng(
      tester,
      find.byKey(boundary),
      '$output/AP02-shell-expanded-glass-light-768x1024-100-top.png',
    );

    boundary = GlobalKey();
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpShell(
      tester,
      brightness: Brightness.dark,
      boundary: boundary,
      highContrast: true,
    );
    await saveRenderPng(
      tester,
      find.byKey(boundary),
      '$output/AP02-shell-expanded-solid-dark-390x844-100-top.png',
    );

    boundary = GlobalKey();
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpShell(tester, brightness: Brightness.light, boundary: boundary);
    final gesture = await tester.startGesture(tester.getCenter(_nav('行程')));
    // 一次 pump 只让长按计时器到点并插入浮层（首帧 alpha 0），第二次 pump 推进
    // M10 的 150ms 淡入，截图才看得到浮层本身。
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 200));
    await saveRenderPng(
      tester,
      find.byKey(boundary),
      '$output/AP02-shell-viewer-glass-light-390x844-100-top.png',
      settle: false,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    File(
      '$output/geometry.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(geometry));
  }, skip: output.isEmpty || fontPath.isEmpty);
}

Map<String, num> _rect(Rect rect) => {
  'left': rect.left,
  'top': rect.top,
  'right': rect.right,
  'bottom': rect.bottom,
  'width': rect.width,
  'height': rect.height,
};
