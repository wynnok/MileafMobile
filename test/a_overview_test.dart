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

import 'support/c_gallery_client.dart';
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
      final hero = find.byKey(const ValueKey('overview-status'));
      expect(arc, findsOneWidget);
      expect(hero, findsOneWidget);
      final inset = MileafSpace.s16;
      final arcRect = tester.getRect(arc);
      final heroRect = tester.getRect(hero);
      expect(arcRect.right, lessThanOrEqualTo(heroRect.right - inset + .5));
      expect(arcRect.left, greaterThanOrEqualTo(heroRect.left + inset - .5));
      expect(
        arcRect.bottom,
        lessThanOrEqualTo(heroRect.bottom - MileafSpace.s12 + .5),
        reason: '弧不得被 hero 底边裁切',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('A 概览只有一个深色锚点，内容区没有卡片', (tester) async {
    await openOverview(tester);
    expect(find.byKey(const ValueKey('overview-status')), findsOneWidget);
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
    // CP02：行内短标签由「净电耗」改为「电耗」。
    expect(find.textContaining('电耗 154 Wh/km'), findsOneWidget);
    expect(find.textContaining('充入 46.80 kWh'), findsOneWidget);
  });

  testWidgets('A 概览本月块不再拉伸等高，主图紧随其后', (tester) async {
    await openOverview(tester);
    final value = tester.getRect(find.textContaining('1,198.6'));
    final chartTitle = tester.getRect(find.text('每日里程'));
    expect(chartTitle.top - value.bottom, lessThan(160), reason: '本月块不应留下整块空白');
    // P01：本期读数表独立成「本期账目」分组卡，仍在焦点卡下方。
    await tester.scrollUntilVisible(find.text('本期账目'), 200);
    await tester.pumpAndSettle();
    final plate = find.byKey(const ValueKey('overview-reading-plate'));
    expect(
      find.descendant(of: plate, matching: find.textContaining('158')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: plate, matching: find.text('¥186.4')),
      findsOneWidget,
    );
    // CP02：费用覆盖改写成「9 次中 8 次有费用」。
    expect(find.textContaining('9 次中 8 次有费用'), findsOneWidget);
  });

  testWidgets('A 概览 200% 时 hero 纵向堆叠、今日读数单列', (tester) async {
    await openOverview(tester, textScale: 2, size: const Size(360, 800));
    final range = tester.getRect(find.textContaining('320'));
    final arc = tester.getRect(find.byType(BatteryArc));
    expect(arc.top, greaterThan(range.bottom), reason: '续航在上、弧在下');
    // CP03：今日三项标签改为「今日里程 / 行程 / 估算耗电」（单位跟值）；
    // 「行程」也出现在本期账目格，取车况卡里的那一个。
    final status = find.byKey(const ValueKey('overview-status'));
    Finder cell(String label) =>
        find.descendant(of: status, matching: find.text(label));
    final first = tester.getRect(cell('今日里程'));
    final second = tester.getRect(cell('行程'));
    final third = tester.getRect(cell('估算耗电'));
    // P01/R11：100% 时三项一行三格；200% 时 MetricGrid 直接收成单列堆叠。
    expect(second.top, greaterThan(first.bottom), reason: '200% 时三项单列堆叠');
    expect(third.top, greaterThan(second.bottom), reason: '200% 时三项单列堆叠');
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
        find.byKey(const ValueKey('overview-status')),
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
      final wordmark = tester.widget<Text>(find.text('概览').first);
      expect(
        wordmark.style?.color,
        mode == MileafAppearance.dark ? colors.heroText : colors.text,
      );
      expect(
        Theme.of(tester.element(find.byKey(const ValueKey('overview-status'))))
            .scaffoldBackgroundColor,
        colors.canvas,
      );
      expect(tester.takeException(), isNull);
    });
  }

  // P01/R01/R04 replaces AV02/03: identical inset and radius in both modes.
  for (final mode in [MileafAppearance.light, MileafAppearance.dark]) {
    for (final width in const [320.0, 360.0, 390.0]) {
      for (final scale in const [1.0, 2.0]) {
        testWidgets('U04 ${mode.name} $width $scale status geometry', (
          tester,
        ) async {
          await openOverview(
            tester,
            mode: mode,
            size: Size(width, 800),
            textScale: scale,
          );
          final status = find.byKey(const ValueKey('overview-status'));
          final box = tester.getRect(status);
          final bar = tester.getRect(
            find.byKey(const ValueKey('root-top-bar-surface')),
          );
          final inset = width >= 390 ? 24.0 : 20.0;
          expect(box.left, inset);
          expect(box.right, width - inset);
          expect(box.top, greaterThanOrEqualTo(bar.bottom));
          expect(
            box.top - bar.bottom,
            inInclusiveRange(0, MileafSpace.s8),
            reason: '状态卡在顶栏下方 0–8px 的既定内容间距内',
          );
          expect(
            find.descendant(of: status, matching: find.text('概览')),
            findsNothing,
          );
          final material = tester.widget<Material>(status);
          // P01/R01：车况卡与所有内容卡同一半径（MileafRadius.lg = 20）。
          expect(
            material.borderRadius,
            const BorderRadius.all(Radius.circular(MileafRadius.lg)),
          );
          final divider = tester.getRect(
            find.descendant(of: status, matching: find.byType(Divider)).first,
          );
          expect(divider.width, width - inset * 2 - MileafSpace.s16 * 2);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('U04 appearance round trip preserves status geometry', (
    tester,
  ) async {
    final appearance = AppearanceController(
      _MemoryAppearance()..value = 'light',
    );
    await openOverview(
      tester,
      mode: MileafAppearance.light,
      appearance: appearance,
    );
    Rect box() => tester.getRect(find.byKey(const ValueKey('overview-status')));
    final light = box();
    await appearance.select(MileafAppearance.dark);
    await tester.pumpAndSettle();
    expect(box(), light);
    await appearance.select(MileafAppearance.light);
    await tester.pumpAndSettle();
    expect(box(), light);
    expect(tester.takeException(), isNull);
  });
}
