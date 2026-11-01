import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/semantic.dart';
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
  final appearance = AppearanceController(appearanceStore);
  await appearance.restore();
  await tester.pumpWidget(
    MileafApp(
      client: cGalleryClient(),
      sessionStore: store,
      trustStore: MemoryTrustStore(),
      vehiclePreferences: MemoryVehiclePreferences(),
      currencyPreferences: _Cny(),
      appearance: appearance,
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
    expect(
      chartTitle.top - value.bottom,
      lessThan(160),
      reason: '本月块不应留下整块空白',
    );
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
      final wordmark = tester.widget<Text>(find.text('行笺').first);
      expect(wordmark.style?.color, colors.heroText);
      expect(
        Theme.of(tester.element(find.byType(MileafHero))).scaffoldBackgroundColor,
        colors.canvas,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
