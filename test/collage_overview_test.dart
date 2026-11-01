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

  Rect tileOf(WidgetTester tester, String label) => tester.getRect(
    find.ancestor(of: find.text(label), matching: find.byType(CollageTile)),
  );

  /// 卡内页脚（时间戳）相对卡底的留白：内边距 12 + CollageTile 下距 8。
  double footerGap(WidgetTester tester, String label) {
    final tile = find.ancestor(
      of: find.text(label),
      matching: find.byType(CollageTile),
    );
    final stamp = find.descendant(
      of: tile,
      matching: find.textContaining('2026-'),
    );
    return tester.getRect(tile).bottom - tester.getRect(stamp).bottom;
  }

  testWidgets('概览本月块左右两列等高且顶底对齐', (tester) async {
    await openOverview(tester);
    final lead = tileOf(tester, '本月 · 驾驶里程');
    final net = tileOf(tester, '净电耗 · 估算');
    final cost = tileOf(tester, '已知充电费用');
    expect(net.top, lead.top, reason: '右列首块应与主 tile 顶部对齐');
    expect(cost.bottom, lead.bottom, reason: '右列末块应与主 tile 底部对齐');
  });

  testWidgets('概览最近记录两张卡等高且标题主数口径页脚对齐', (tester) async {
    await openOverview(tester);
    await tester.scrollUntilVisible(
      find.text('最近充电').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    final drive = tileOf(tester, '最近行程');
    final charge = tileOf(tester, '最近充电');
    expect(drive.top, charge.top, reason: '两张记录卡顶部对齐');
    expect(drive.bottom, charge.bottom, reason: '两张记录卡底部对齐');
    expect(
      footerGap(tester, '最近行程'),
      closeTo(footerGap(tester, '最近充电'), .5),
      reason: '页脚时间戳贴各自的卡底，跨列同一基线',
    );
    // 12dp 内容内边距 + CollageTile 8dp 下距：页脚确实贴底，而不是随内容漂浮。
    expect(footerGap(tester, '最近行程'), closeTo(20, .5));
    expect(footerGap(tester, '最近充电'), closeTo(20, .5));
    expect(find.text('净电耗 154 Wh/km'), findsOneWidget, reason: '行程卡口径保持单行');
    expect(
      find.text('充入 46.80 kWh'),
      findsOneWidget,
      reason: '充电卡口径只写充入电量，不再拼接悬空的「结束电量」',
    );
  });

  testWidgets('概览 ≥150% 字号时两列区块纵向堆叠', (tester) async {
    await openOverview(tester, textScale: 2);
    final lead = tileOf(tester, '本月 · 驾驶里程');
    final net = tileOf(tester, '净电耗 · 估算');
    expect(lead.bottom, lessThanOrEqualTo(net.top), reason: '本月块改为单列');
    await tester.scrollUntilVisible(
      find.text('最近充电').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    final drive = tileOf(tester, '最近行程');
    final charge = tileOf(tester, '最近充电');
    expect(drive.bottom, lessThanOrEqualTo(charge.top), reason: '最近记录改为单列');
  });

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
