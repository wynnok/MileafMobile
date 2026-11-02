import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/tokens.dart';
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

class _MemoryAppearance implements AppearancePreferenceStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? next) async => value = next;
}

Future<void> openOverview(
  WidgetTester tester, {
  double textScale = 1,
  Size size = const Size(390, 844),
  MileafAppearance mode = MileafAppearance.dark,
  AppearanceController? appearance,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  final store = MemorySessionStore()
    ..value = jsonEncode({
      'site': cSite,
      'token': 'test',
      'expires_at': '2099-01-01T00:00:00Z',
    });
  final appearanceStore = _MemoryAppearance()..value = mode.name;
  final controller = appearance ?? AppearanceController(appearanceStore);
  await controller.restore();
  await tester.pumpWidget(
    MileafApp(
      client: cGalleryClient(),
      sessionStore: store,
      trustStore: MemoryTrustStore(),
      vehiclePreferences: MemoryVehiclePreferences(),
      currencyPreferences: _Cny(),
      appearance: controller,
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
    (Size(390, 844), 2.0),
    (Size(320, 640), 1.3),
  ]) {
    testWidgets('A 概览电量弧完整落在 hero 内容区内（${size.width.round()}dp ×$scale）', (
      tester,
    ) async {
      await openOverview(tester, textScale: scale, size: size);
      final arc = find.byType(BatteryArc);
      final hero = find.byType(MileafHero);
      expect(arc, findsOneWidget);
      expect(hero, findsOneWidget);
      final inset = size.width >= 390 ? 24.0 : 20.0;
      final arcRect = tester.getRect(arc);
      final heroRect = tester.getRect(hero);
      expect(arcRect.right, lessThanOrEqualTo(heroRect.right - inset + .5));
      expect(arcRect.left, greaterThanOrEqualTo(heroRect.left + inset - .5));
      expect(
        arcRect.bottom,
        lessThanOrEqualTo(heroRect.bottom - 18 + .5),
        reason: '弧不得被 hero 底边裁切',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('A 概览只有一个深色锚点，内容区没有卡片', (tester) async {
    await openOverview(tester);
    expect(find.byType(MileafHero), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(find.text('四个问题'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('最近充电').hitTestable(),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(MileafDataRow, '最近行程'), findsOneWidget);
    expect(find.widgetWithText(MileafDataRow, '最近充电'), findsOneWidget);
    expect(find.textContaining('净电耗 154 Wh/km'), findsOneWidget);
    expect(find.textContaining('充入 46.80 kWh'), findsOneWidget);
  });

  testWidgets('A 概览本月块不再拉伸等高，主图紧随其后', (tester) async {
    await openOverview(tester);
    final value = tester.getRect(find.textContaining('1,198.6'));
    final chartTitle = tester.getRect(find.text('每日里程'));
    expect(chartTitle.top - value.bottom, lessThan(160), reason: '本月块不应留下整块空白');
    expect(find.textContaining('净电耗 158 Wh/km · 已知费用 ¥186.4'), findsOneWidget);
    expect(find.textContaining('8/9 次'), findsOneWidget);
  });

  testWidgets('A 概览 200% 时 hero 纵向堆叠、今日读数两列', (tester) async {
    await openOverview(tester, textScale: 2, size: const Size(360, 800));
    final range = tester.getRect(find.textContaining('320'));
    final arc = tester.getRect(find.byType(BatteryArc));
    expect(arc.top, greaterThan(range.bottom), reason: '续航在上、弧在下');
    final first = tester.getRect(find.text('今日 km'));
    final second = tester.getRect(find.text('次行程'));
    final third = tester.getRect(find.text('估算 kWh'));
    expect(first.top, second.top, reason: '今日两项同处 2×2 首行');
    expect(third.top, greaterThan(first.bottom), reason: '第三项换行');
    await tester.scrollUntilVisible(
      find.text('最近充电').hitTestable(),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    final row = find
        .ancestor(of: find.text('最近行程'), matching: find.byType(MileafDataRow))
        .first;
    final title = tester.getRect(
      find.descendant(of: row, matching: find.text('最近行程')),
    );
    final value = tester.getRect(
      find.descendant(of: row, matching: find.textContaining('32.9')),
    );
    expect(value.top, greaterThanOrEqualTo(title.bottom), reason: '记录行两行');
    expect(tester.takeException(), isNull);
  });

  for (final mode in [MileafAppearance.dark, MileafAppearance.light]) {
    testWidgets('A 概览 ${mode.name} 下 hero 保持深色且文字可读', (tester) async {
      await openOverview(tester, mode: mode);
      final colors = mode == MileafAppearance.dark
          ? const MileafColors.dark()
          : const MileafColors.light();
      final heroMaterial = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(MileafHero),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(heroMaterial.color, colors.hero);
      expect(heroMaterial.color, isNot(colors.canvas));
      expect(contrast(colors.heroText, colors.hero), greaterThanOrEqualTo(4.5));
      expect(
        contrast(colors.heroMuted, colors.hero),
        greaterThanOrEqualTo(4.5),
      );
      // 旧断言一律期望 heroText — 它编码的是「概览 top bar 永远在 hero 内」这个
      // 被 ADR 0006 D4 推翻的决定。浅色 hero 成卡片后品牌行回到纸面（Spec §6.4），
      // 字标必须用纸面正文色；深色仍留在 hero 内，故仍是 heroText。
      final wordmark = tester.widget<Text>(find.text('行笺').first);
      expect(
        wordmark.style?.color,
        mode == MileafAppearance.dark ? colors.heroText : colors.text,
      );
      expect(
        Theme.of(tester.element(find.byType(MileafHero)))
            .scaffoldBackgroundColor,
        colors.canvas,
      );
      expect(tester.takeException(), isNull);
    });
  }

  // AV02 / AV03：形态由 MileafColors 推导。量的是可见卡片（hero 内的 Material），
  // 不是 MileafHero 自身的外框。
  for (final mode in [MileafAppearance.light, MileafAppearance.dark]) {
    for (final width in const [320.0, 360.0, 390.0]) {
      for (final scale in const [1.0, 2.0]) {
        testWidgets(
          'A 概览 ${mode.name} ${width.round()}宽 ${scale * 100}% hero 形态与内容宽',
          (tester) async {
            await openOverview(
              tester,
              mode: mode,
              size: Size(width, 800),
              textScale: scale,
            );
            final card = mode == MileafAppearance.light;
            final hero = find.byType(MileafHero);
            final box = tester.getRect(
              find.descendant(of: hero, matching: find.byType(Material)).first,
            );
            final bar = tester.getRect(find.byType(MileafTopBar));
            final outer = card ? MileafSpace.cardInset : 0.0;
            expect(box.left, outer, reason: 'hero 左外边距');
            expect(box.right, width - outer, reason: 'hero 右外边距');
            // 品牌行归属：卡片形态在纸面，满幅形态在 hero 内。
            expect(
              find.descendant(of: hero, matching: find.text('行笺')),
              card ? findsNothing : findsOneWidget,
            );
            if (card) {
              expect(box.top, bar.bottom, reason: '卡片紧接品牌行区块，不叠加 inset');
              expect(
                bar.bottom - tester.getRect(find.text('行笺')).bottom,
                greaterThanOrEqualTo(MileafSpace.cardInset),
                reason: '品牌行与卡片之间至少留 12',
              );
              expect(bar.top, 0, reason: '品牌行自己承担状态栏 inset（测试环境状态栏为 0）');
            } else {
              expect(box.top, 0, reason: '满幅 hero 贴上边');
              expect(bar.top, box.top, reason: '品牌行是 hero 的第一个子块');
              expect(
                bar.top + bar.height,
                lessThanOrEqualTo(box.bottom),
                reason: '品牌行完全落在 hero 内',
              );
            }
            // Spec §6.5 内容宽：卡片 = 宽 − 12×2 − 16×2；满幅 = 宽 − pageInset×2。
            final divider = tester.getRect(
              find.descendant(of: hero, matching: find.byType(Divider)).first,
            );
            final pageInset = width >= 390 ? 48.0 : 40.0;
            final content = card
                ? width - MileafSpace.cardInset * 2 - MileafSpace.cardPad * 2
                : width - pageInset;
            expect(divider.width, closeTo(content, .5), reason: 'hero 内容宽');
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('A 概览浅色→深色→浅色不残留双倍 inset', (tester) async {
    final appearance = AppearanceController(
      _MemoryAppearance()..value = 'light',
    );
    await openOverview(
      tester,
      mode: MileafAppearance.light,
      appearance: appearance,
    );
    Rect cardBox() => tester.getRect(
      find
          .descendant(
            of: find.byType(MileafHero),
            matching: find.byType(Material),
          )
          .first,
    );
    final light = cardBox();
    final lightBar = tester.getRect(find.byType(MileafTopBar));
    expect(light.left, MileafSpace.cardInset);
    expect(light.top, lightBar.bottom);

    await appearance.select(MileafAppearance.dark);
    await tester.pumpAndSettle();
    final dark = cardBox();
    expect(dark.left, 0, reason: '深色满幅贴边');
    expect(dark.top, 0, reason: '深色 hero 从屏幕顶部开始');
    expect(
      tester.getRect(find.byType(MileafTopBar)).top,
      dark.top,
      reason: '深色品牌行回到 hero 内',
    );

    await appearance.select(MileafAppearance.light);
    await tester.pumpAndSettle();
    final again = cardBox();
    final againBar = tester.getRect(find.byType(MileafTopBar));
    expect(again.left, MileafSpace.cardInset, reason: '切回浅色仍是 12，不叠加');
    expect(again.top, againBar.bottom, reason: '切回浅色不残留空档');
    expect(again, light, reason: '两次浅色的卡片位置一致');
    expect(tester.takeException(), isNull);
  });
}
