import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/tokens.dart';

import 'drives_test.dart' show jsonResponse;
import 'drive_detail_test.dart' show fixture, openDetail;

/// 读值区与事实表的排版合同：一处左线、一条右线、一个折叠动作。
void main() {
  testWidgets('对照电量与同页文字共用左线，不再是缩进的文本按钮', (tester) async {
    await openDetail(
      tester,
      (r) async => jsonResponse(
        jsonEncode(
          fixture(
            r.url.path.endsWith('/series') ? 'drive-series' : 'drive-detail',
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('对照电量').hitTestable(), 200);
    final toggle = tester.getRect(find.text('对照电量'));
    final note = tester.getRect(find.text('采样数据说明'));
    final title = tester.getRect(find.text('速度过程'));
    expect(toggle.left, note.left, reason: '折叠行、说明行与图表标题同一条左线');
    expect(toggle.left, title.left);
    // 旧实现在 Align + TextButton，标签因此缩进 16。
    expect(find.widgetWithText(TextButton, '对照电量'), findsNothing);
    // 标签与第二行说明都从内容左沿起算。
    expect(tester.getRect(find.text('与速度过程同屏')).left, toggle.left);
  });

  testWidgets('对照电量就地展开第二张图，箭头 160ms 翻转并可再收起', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await openDetail(
        tester,
        (r) async => jsonResponse(
          jsonEncode(
            fixture(
              r.url.path.endsWith('/series') ? 'drive-series' : 'drive-detail',
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('对照电量').hitTestable(), 200);
      expect(find.byKey(const ValueKey('paired-sample-chart')), findsNothing);
      expect(
        find.bySemanticsLabel('对照电量'),
        findsOneWidget,
        reason: '折叠行读成一个可展开的按钮',
      );
      AnimatedRotation rotation() => tester.widget<AnimatedRotation>(
        find
            .descendant(
              of: find.byKey(const ValueKey('battery-pair')),
              matching: find.byType(AnimatedRotation),
            )
            .first,
      );
      expect(rotation().turns, .25, reason: '收起时箭头朝下');
      expect(rotation().duration, MileafDurations.chevron);

      await tester.tap(find.text('对照电量'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paired-sample-chart')), findsOneWidget);
      expect(rotation().turns, -.25, reason: '展开时箭头朝上');

      await tester.tap(find.text('对照电量'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paired-sample-chart')), findsNothing);
      expect(rotation().turns, .25);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('减少动效时折叠行不旋转也不留时长', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await openDetail(
      tester,
      (r) async => jsonResponse(
        jsonEncode(
          fixture(
            r.url.path.endsWith('/series') ? 'drive-series' : 'drive-detail',
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('对照电量').hitTestable(), 200);
    final rotation = tester.widget<AnimatedRotation>(
      find
          .descendant(
            of: find.byKey(const ValueKey('battery-pair')),
            matching: find.byType(AnimatedRotation),
          )
          .first,
    );
    expect(rotation.duration, Duration.zero);
  });

  testWidgets('驾驶与环境是字段名/值两列：数字右边缘落在同一条竖线', (tester) async {
    await openDetail(
      tester,
      (r) async => jsonResponse(
        jsonEncode(
          fixture(
            r.url.path.endsWith('/series') ? 'drive-series' : 'drive-detail',
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('驾驶与环境').hitTestable(), 200);
    final facts = find.byKey(const ValueKey('drive-facts'));
    Rect value(String text) =>
        tester.getRect(find.descendant(of: facts, matching: find.text(text)));
    final ten = value('10');
    final ninetyOne = value('90');
    final power = value('120');
    expect(ninetyOne.right, ten.right, reason: '单位列固定宽度，数字右边缘对齐');
    expect(power.right, ten.right);
    // 字段名一列、值一列：值不与字段名混排在同一段文字里。
    final label = tester.getRect(
      find.descendant(of: facts, matching: find.text('平均速度')),
    );
    expect(label.left, lessThan(ten.left));
    expect(label.right, lessThan(ten.left));
    // 值比字段名大一档（17 与 14）。
    final numberStyle = tester
        .widget<Text>(find.descendant(of: facts, matching: find.text('10')))
        .style!;
    final labelStyle = tester
        .widget<Text>(find.descendant(of: facts, matching: find.text('平均速度')))
        .style!;
    expect(numberStyle.fontSize, MileafType.bodySize);
    expect(labelStyle.fontSize, MileafType.labelSize);
  });

  testWidgets('缺失的驾驶与环境值只出「—」，且仍落在同一条数字右线', (tester) async {
    final detail = fixture('drive-detail');
    detail['speed_avg_kmh'] = null;
    await openDetail(
      tester,
      (r) async => jsonResponse(
        jsonEncode(
          r.url.path.endsWith('/series') ? fixture('drive-series') : detail,
        ),
      ),
    );
    final semantics = tester.ensureSemantics();
    try {
      await tester.scrollUntilVisible(find.text('驾驶与环境').hitTestable(), 200);
      expect(find.bySemanticsLabel('平均速度 —'), findsOneWidget);
      expect(find.text('— — km/h'), findsNothing);
      final facts = find.byKey(const ValueKey('drive-facts'));
      final dash = tester.getRect(
        find.descendant(of: facts, matching: find.text('—')),
      );
      final ninetyOne = tester.getRect(
        find.descendant(of: facts, matching: find.text('90')),
      );
      expect(dash.right, ninetyOne.right);
      expect(
        find.descendant(of: facts, matching: find.text('km/h')),
        findsOneWidget,
        reason: '缺失值不带单位，所以只有「最高速度」一行有 km/h',
      );
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('200% 字号下事实表改为字段名在上、值在下', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await openDetail(
      tester,
      (r) async => jsonResponse(
        jsonEncode(
          fixture(
            r.url.path.endsWith('/series') ? 'drive-series' : 'drive-detail',
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('驾驶与环境').hitTestable(), 200);
    final facts = find.byKey(const ValueKey('drive-facts'));
    final label = tester.getRect(
      find.descendant(of: facts, matching: find.text('平均速度')),
    );
    final number = tester.getRect(
      find.descendant(of: facts, matching: find.text('10 km/h')),
    );
    expect(number.top, greaterThanOrEqualTo(label.bottom));
    expect(number.left, label.left);
    expect(tester.takeException(), isNull);
  });
  testWidgets('切到电量指标再回到速度，对照电量保持上次的展开状态', (tester) async {
    await openDetail(
      tester,
      (r) async => jsonResponse(
        jsonEncode(
          fixture(
            r.url.path.endsWith('/series') ? 'drive-series' : 'drive-detail',
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('对照电量').hitTestable(), 200);
    await tester.tap(find.text('对照电量'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('paired-sample-chart')), findsOneWidget);
    // 切到「电量」指标时该行被卸载，再切回来时由页面状态恢复展开。
    Finder chip(String label) => find
        .descendant(of: find.byType(StatusChip), matching: find.text(label))
        .hitTestable();
    await tester.scrollUntilVisible(chip('电量'), -160);
    await tester.tap(chip('电量'));
    await tester.pumpAndSettle();
    expect(find.text('对照电量'), findsNothing);
    await tester.scrollUntilVisible(chip('速度'), -160);
    await tester.tap(chip('速度'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('对照电量').hitTestable(), 200);
    expect(find.byKey(const ValueKey('paired-sample-chart')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
