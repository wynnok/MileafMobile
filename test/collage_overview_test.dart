import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/collage.dart';
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/data_cards.dart';
import 'package:mileaf/src/workspace.dart';

import 'c_gallery_render_test.dart' show cGalleryClient;
import 'support/c_fixture.dart' show cNow, cSite;
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'widget_test.dart' show MemoryTrustStore;

class _Cny implements CurrencyPreferenceStore {
  @override
  Future<String?> read(String site) async => 'CNY';
  @override
  Future<void> write(String site, String? code) async {}
}

Future<void> openOverview(
  WidgetTester tester, {
  double textScale = 1,
  Size size = const Size(390, 844),
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });
  final store = MemorySessionStore()
    ..value = jsonEncode({
      'site': cSite,
      'token': 'test',
      'expires_at': '2099-01-01T00:00:00Z',
    });
  await tester.pumpWidget(
    MileafApp(
      client: cGalleryClient(),
      sessionStore: store,
      trustStore: MemoryTrustStore(),
      vehiclePreferences: MemoryVehiclePreferences(),
      currencyPreferences: _Cny(),
      now: () => cNow,
      calendar: () async => CalendarContext('Asia/Shanghai'),
    ),
  );
  await tester.pumpAndSettle();
}

double contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance(), b = background.computeLuminance();
  return (a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05));
}

void main() {
  for (final (size, scale) in const [
    (Size(390, 844), 1.0),
    (Size(390, 844), 1.3),
    (Size(390, 844), 2.0), // ≥150% 走 hero 纵向堆叠分支
    (Size(320, 640), 1.3), // 窄屏 + 大字号是 hero 行最紧的组合
  ]) {
    testWidgets('概览电量环完整落在 hero 内容区内（${size.width.round()}dp ×$scale）', (
      tester,
    ) async {
      await openOverview(tester, textScale: scale, size: size);

      final ring = find.byType(BatteryLevelIndicator);
      expect(ring, findsOneWidget);
      final hero = find.ancestor(of: ring, matching: find.byType(CollageTile));
      expect(hero, findsOneWidget);

      // 描边向内收：环的绘制范围就是布局盒，不会再溢出到被裁切的内容区边缘。
      final indicator = tester.widget<CircularProgressIndicator>(
        find.descendant(
          of: ring,
          matching: find.byType(CircularProgressIndicator),
        ),
      );
      expect(
        indicator.strokeAlign,
        CircularProgressIndicator.strokeAlignInside,
        reason: '居中描边会让弧线外溢半个笔画，外层裁切后右侧被切平',
      );

      const tilePadding = 12.0; // CollageTile 默认内边距
      final ringRect = tester.getRect(ring);
      final heroRect = tester.getRect(hero);
      expect(
        ringRect.right,
        lessThanOrEqualTo(heroRect.right - tilePadding - 1),
        reason: '环贴住内容区右缘会被 Stack 的裁切削平',
      );
      expect(ringRect.left, greaterThanOrEqualTo(heroRect.left + tilePadding));
      expect(ringRect.top, greaterThanOrEqualTo(heroRect.top + tilePadding));
      expect(ringRect.bottom, lessThanOrEqualTo(heroRect.bottom - tilePadding));
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('概览最近充电卡在深色 tile 上保持可读对比度（${brightness.name}）', (tester) async {
      await openOverview(tester, brightness: brightness);
      await tester.scrollUntilVisible(
        find.text('最近充电').hitTestable(),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();

      final hero = find.ancestor(
        of: find.text('最近充电'),
        matching: find.byType(CollageTile),
      );
      final background = tester
          .widget<Card>(
            find.descendant(of: hero, matching: find.byType(Card)).first,
          )
          .color!;
      expect(
        background.computeLuminance(),
        lessThan(.2),
        reason: '该卡按 C 是深色 hero tile',
      );

      // 卡内每一处文字都要在深底上可读，而不是沿用外层浅色主题的近黑字。
      final texts = find.descendant(of: hero, matching: find.byType(Text));
      expect(texts, findsAtLeastNWidgets(4));
      for (final element in texts.evaluate()) {
        final text = (element.widget as Text).data!;
        // 逐段取 RenderParagraph 合并后的实际前景色，而不是 Text.style。
        final color =
            (element.renderObject! as RenderParagraph).text.style?.color;
        expect(color, isNotNull, reason: '深色 tile 上的「$text」必须有明确前景色');
        expect(
          contrast(color!, background),
          greaterThanOrEqualTo(4.5),
          reason: '「$text」在深色 tile 上对比度不足：$color',
        );
      }
    });
  }
}
