import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'charging_cost_test.dart'
    show CostSite, pumpCostApp, openCostSheet, tapCostAction;
import 'support/render_fonts.dart';
import 'support/render_png.dart';

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

void main() {
  setUpAll(() async {
    if (output.isEmpty) return;
    await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('320宽200%与键盘下输入、语义、错误和底部动作完整可达', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        tester.view.resetViewInsets();
      });
      await pumpCostApp(tester, CostSite(), size: const Size(320, 640));
      await tester.tap(find.text('充电').last);
      await tester.pumpAndSettle();
      await openCostSheet(tester);
      expect(find.bySemanticsLabel(RegExp('充电单价')), findsWidgets);
      expect(
        tester.getSize(find.byTooltip('关闭费用补录')).shortestSide,
        greaterThanOrEqualTo(44),
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.enterText(find.byType(TextField), '-1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.textContaining('请输入有效单价'), findsOneWidget);
      await tester.ensureVisible(find.text('确认补录'));
      await tester.pumpAndSettle();
      expect(find.text('确认补录').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('充电费用正式页面 × 浅深 × 100/200% × 键盘/窄屏/平板', (tester) async {
    addTearDown(() {
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.view.resetViewInsets();
    });
    final cameras = <Size, List<String>>{
      const Size(360, 800): [
        'list',
        'detail',
        'empty',
        'preview',
        'free',
        'invalid',
        'blocked',
        'uncertain',
      ],
      const Size(320, 640): ['long', 'unknown', 'maximum', 'keyboard'],
      const Size(390, 844): ['preview', 'keyboard'],
      const Size(768, 1024): ['preview'],
    };
    var saved = 0;
    for (final camera in cameras.entries) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 2.0]) {
          for (final scenario in camera.value) {
            await tester.pumpWidget(const SizedBox.shrink());
            tester.platformDispatcher.platformBrightnessTestValue = brightness;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            tester.view.resetViewInsets();
            final site = CostSite();
            if (scenario == 'long') site.place = '上海湖畔超级充电站地下停车场新能源专用补能区域';
            if (scenario == 'maximum') {
              site.added = 999999.99;
              site.used = null;
            }
            if (scenario == 'blocked') {
              site.patch = (_) async => http.Response('', 403);
            }
            if (scenario == 'uncertain') {
              site.patch = (_) async => throw TimeoutException('fixture');
            }
            final boundary = GlobalKey();
            await pumpCostApp(
              tester,
              site,
              size: camera.key,
              boundary: boundary,
              currencyCode: scenario == 'unknown' ? null : 'CNY',
            );
            if (scenario == 'list') {
              await tester.tap(find.text('充电').last);
              await tester.pumpAndSettle();
              await tester.scrollUntilVisible(
                find.text('补录费用').hitTestable(),
                160,
              );
            } else {
              await tester.scrollUntilVisible(
                find.text('最近充电').hitTestable(),
                240,
              );
              await tester.tap(find.text('最近充电').hitTestable());
              await tester.pumpAndSettle();
              if (scenario == 'detail') {
                await tester.scrollUntilVisible(
                  find.text('补录费用').hitTestable(),
                  150,
                );
              } else {
                await openCostSheet(tester);
                expect(find.text('充电单价'), findsOneWidget);
                if (scenario != 'empty') {
                  await tester.enterText(
                    find.byType(TextField),
                    switch (scenario) {
                      'free' => '0',
                      'invalid' => '1,25',
                      'maximum' => '999999',
                      _ => '1.25',
                    },
                  );
                  await tester.testTextInput.receiveAction(
                    TextInputAction.done,
                  );
                  await tester.pumpAndSettle();
                }
                if (scenario == 'blocked' || scenario == 'uncertain') {
                  await tapCostAction(tester, '确认补录');
                  expect(
                    find.text(
                      scenario == 'blocked'
                          ? '站点尚未开启费用补录，请联系管理员'
                          : '补录结果尚未确认，请先查询最新结果',
                    ),
                    findsOneWidget,
                  );
                }
                if (scenario == 'free') {
                  expect(find.text('将记录为免费充电'), findsOneWidget);
                }
                if (scenario == 'invalid') {
                  expect(find.textContaining('请输入有效单价'), findsOneWidget);
                }
                if (scenario == 'preview') {
                  expect(find.text('¥27.50'), findsOneWidget);
                }
                if (scenario == 'unknown') {
                  expect(find.text('27.50'), findsOneWidget);
                }
                if (scenario == 'maximum') {
                  for (final group in ['¥999,', '998,', '990,', '000.01']) {
                    expect(find.text(group), findsOneWidget);
                  }
                }
                if (scenario == 'keyboard') {
                  tester.view.viewInsets = const FakeViewPadding(bottom: 280);
                  await tester.tap(find.byType(TextField));
                  await tester.pumpAndSettle();
                }
              }
            }
            final name =
                '${camera.key.width.toInt()}-$scenario-${brightness.name}-${scale == 1 ? '100' : '200'}';
            await saveRenderPng(
              tester,
              find.byKey(boundary),
              '$output/$name.png',
            );
            saved++;
            if (scenario != 'list' && scenario != 'detail') {
              final action = scenario == 'blocked'
                  ? '重新检查'
                  : scenario == 'uncertain'
                  ? '查询最新结果'
                  : '确认补录';
              await tester.ensureVisible(find.text(action).last);
              await tester.pumpAndSettle();
              expect(find.text(action).last.hitTestable(), findsOneWidget);
              await saveRenderPng(
                tester,
                find.byKey(boundary),
                '$output/$name-action.png',
              );
            }
          }
        }
      }
    }
    expect(saved, 60);
  }, skip: output.isEmpty);
}
