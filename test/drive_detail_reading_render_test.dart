import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/design/components/components.dart';
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

/// 默认生成改动后的样张；改动前的对照帧用
/// --dart-define=MILEAF_RENDER_STAGE=before。
const stage = String.fromEnvironment(
  'MILEAF_RENDER_STAGE',
  defaultValue: 'after',
);

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

/// 打开指定宽度的行程详情（夹具 drive 17）。
Future<void> _openDetail(
  WidgetTester tester, {
  required Brightness brightness,
  required double width,
  required double scale,
  required GlobalKey boundary,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
  tester.view.padding = tester.view.viewPadding;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
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
  await tester.tap(_nav('行程'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('drive-17')).hitTestable(),
    200,
  );
  await tester.tap(find.byKey(const ValueKey('drive-17')));
  await tester.pumpAndSettle();
}

Future<void> _frame(
  WidgetTester tester,
  Finder anchor,
  double alignment,
) async {
  // 页面是懒构建的 ListView：先滚到锚点被构建，再对齐。
  await tester.scrollUntilVisible(anchor, 160);
  await Scrollable.ensureVisible(tester.element(anchor), alignment: alignment);
  await tester.pumpAndSettle();
}

/// 行程详情「过程图 + 电量对照」与「驾驶与环境」两处样张。
///
/// 390/320 宽 × 浅深色 × 100/200% 字号；每条锚点各出一帧，方便逐处比对。
void main() {
  setUpAll(() async {
    if (fontPath.isNotEmpty) await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('行程详情读数区样张', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewPadding();
      tester.view.resetPadding();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    });
    // frames：3 = 过程图/展开/事实表三帧；1 = 只出事实表（换版的临界点）。
    for (final brightness in Brightness.values) {
      for (final (width, scale, frames) in const [
        (390.0, 1.0, 3),
        (390.0, 2.0, 3),
        (320.0, 1.0, 3),
        (320.0, 2.0, 1),
        (360.0, 1.5, 1),
      ]) {
        final suffix =
            '${brightness.name}-${width.toInt()}-${(scale * 100).round()}';
        final boundary = GlobalKey();
        await _openDetail(
          tester,
          brightness: brightness,
          width: width,
          scale: scale,
          boundary: boundary,
        );
        if (frames == 3) {
          // 过程图与其下的对照电量、数据说明同屏。
          await _frame(tester, find.text('行驶过程'), scale == 1 ? .84 : .9);
          await saveRenderPng(
            tester,
            find.byKey(boundary),
            '$output/$stage-chart-$suffix.png',
          );
          // 展开对照电量，确认第二张图与其折叠行同屏。
          final toggle = find.text('同时查看电量');
          await tester.scrollUntilVisible(toggle.hitTestable(), 120);
          await tester.tap(toggle.hitTestable());
          await tester.pumpAndSettle();
          await _frame(
            tester,
            find.byKey(const ValueKey('paired-sample-chart')),
            .95,
          );
          await saveRenderPng(
            tester,
            find.byKey(boundary),
            '$output/$stage-paired-$suffix.png',
          );
        }
        // 驾驶与环境事实表。
        await _frame(tester, find.text('驾驶与环境'), .3);
        await saveRenderPng(
          tester,
          find.byKey(boundary),
          '$output/$stage-facts-$suffix.png',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  }, skip: output.isEmpty || fontPath.isEmpty);
}
