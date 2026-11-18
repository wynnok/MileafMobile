import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'charging_cost_test.dart' show CostSite, pumpCostApp, openCostSheet;
import 'support/render_fonts.dart';
import 'support/render_png.dart';

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

class PrecheckSite extends CostSite {
  Completer<void>? holdRead;

  @override
  Future<http.Response> handle(http.Request request) async {
    if (request.method == 'GET' &&
        request.url.path.endsWith('/charging-sessions/1')) {
      await holdRead?.future;
    }
    return super.handle(request);
  }
}

Future<void> openForm(
  WidgetTester tester,
  CostSite site, {
  Size size = const Size(360, 800),
  String? currency = 'CNY',
  GlobalKey? boundary,
}) async {
  await pumpCostApp(
    tester,
    site,
    size: size,
    currencyCode: currency,
    boundary: boundary,
  );
  await tester.tap(find.text('充电').last);
  await tester.pumpAndSettle();
  await openCostSheet(tester);
}

Finder get formScroll => find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .last;

Future<void> scrollToAction(WidgetTester tester, String label) async {
  // 从视口底部开始拖动，避开正在编辑的输入框及其选词浮层。
  for (
    var step = 0;
    step < 100 && find.text(label).hitTestable().evaluate().isEmpty;
    step++
  ) {
    final rect = tester.getRect(formScroll);
    await tester.dragFrom(
      Offset(rect.right - 8, rect.bottom - 12),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
  }
  expect(find.text(label).hitTestable(), findsOneWidget);
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    if (output.isNotEmpty) await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('P14 单价输入52高，计费电量先于预估费用，记录元信息分行', (tester) async {
    await openForm(tester, CostSite());
    expect(tester.getSize(find.byType(TextField)).height, 52);
    expect(find.text('单价（CNY/kWh）').hitTestable(), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('计费电量 22 kWh')).dy,
      lessThan(tester.getTopLeft(find.text('预估费用')).dy),
    );
    expect(find.textContaining(' · 充电 #'), findsNothing);
  });

  for (final status in [403, 409, 503]) {
    testWidgets('320×568 200%键盘300 坐标输入、滚动提交和$status恢复', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        tester.view.resetViewInsets();
      });
      final site = CostSite()
        ..place = '上海湖畔超级充电站地下停车场新能源专用补能区域'
        ..patch = (_) async => http.Response('', status);
      await openForm(tester, site, size: const Size(320, 568), currency: null);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.byType(TextField)));
      tester.testTextInput.enterText('1.25');
      await tester.pumpAndSettle();
      await scrollToAction(tester, '确认补录');
      final action = tester.getCenter(find.text('确认补录'));
      expect(action.dy, lessThan(268));
      await tester.tapAt(action);
      await tester.pumpAndSettle();
      expect(site.writes, hasLength(1));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '1.25',
      );
      final recovery = status == 403 ? '重新检查' : '查询最新结果';
      await scrollToAction(tester, recovery);
      final reads = site.reads.length;
      await tester.tapAt(tester.getCenter(find.text(recovery)));
      await tester.pumpAndSettle();
      expect(site.reads.length, greaterThan(reads));
      expect(site.writes, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('减少动效时提交为静态提示且锁定，响应前不重复写入', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final pending = Completer<http.Response>();
    final site = CostSite()..patch = (_) => pending.future;
    await openForm(tester, site);
    await tester.enterText(find.byType(TextField), '1.25');
    await scrollToAction(tester, '确认补录');
    await tester.tapAt(tester.getCenter(find.text('确认补录')));
    await tester.pumpAndSettle();
    expect(find.text('正在补录费用…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
    await tester.tapAt(tester.getCenter(find.text('确认补录')));
    await tester.pump(const Duration(seconds: 1));
    expect(site.writes, hasLength(1));
    pending.complete(http.Response('', 503));
    await tester.pumpAndSettle();
    expect(find.text('查询最新结果'), findsOneWidget);
  });

  testWidgets('U11正式表单矩阵与输入动作机位', (tester) async {
    addTearDown(() {
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      tester.view.resetViewInsets();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    });
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    for (final size in [
      const Size(360, 800),
      const Size(320, 568),
      const Size(390, 844),
      const Size(768, 1024),
    ]) {
      for (final brightness in Brightness.values) {
        final scales = size.width == 360
            ? [1.0, 1.3, 1.5, 2.0]
            : size.width == 390
            ? [1.0]
            : [2.0];
        for (final scale in scales) {
          final scenarios =
              size.width == 360 && (scale == 1 || scale == 2) ||
                  size.width == 320
              ? [
                  'normal',
                  'loading',
                  'empty',
                  'free',
                  'unknown',
                  'maximum',
                  'invalid',
                  'blocked',
                  'uncertain',
                  'saving',
                  'read-error',
                  'existing-zero',
                ]
              : ['normal'];
          for (final scenario in scenarios) {
            await tester.pumpWidget(const SizedBox.shrink());
            tester.platformDispatcher.platformBrightnessTestValue = brightness;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            tester.view.resetViewInsets();
            tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
            tester.view.viewPadding = const FakeViewPadding(
              top: 24,
              bottom: 24,
            );
            final pending = Completer<http.Response>();
            final site = PrecheckSite();
            if (size.width == 320) site.place = '上海湖畔超级充电站地下停车场新能源专用补能区域';
            if (scenario == 'maximum') {
              site.added = 999999.99;
              site.used = null;
            }
            if (scenario == 'blocked') {
              site.patch = (_) async => http.Response('', 403);
            }
            if (scenario == 'uncertain') {
              site.patch = (_) async => http.Response('', 503);
            }
            if (scenario == 'saving') site.patch = (_) => pending.future;
            final boundary = GlobalKey();
            await pumpCostApp(
              tester,
              site,
              size: size,
              boundary: boundary,
              currencyCode: scenario == 'unknown' ? null : 'CNY',
            );
            await tester.tap(find.text('充电').last);
            await tester.pumpAndSettle();
            if (scenario == 'read-error') site.failRead = true;
            if (scenario == 'existing-zero') site.cost = 0;
            if (scenario == 'loading') site.holdRead = Completer<void>();
            await openCostSheet(tester);
            if (size.width == 320) {
              tester.view.viewInsets = const FakeViewPadding(bottom: 300);
              await tester.pumpAndSettle();
            }
            final name =
                'cost-$scenario-${brightness.name}-${size.width.toInt()}-${(scale * 100).round()}';
            Future<void> save(String camera) => saveRenderPng(
              tester,
              find.byKey(boundary),
              '$output/$name-$camera.png',
            );
            await save('first');
            if (scenario == 'loading') {
              expect(find.text('正在读取本次充电…'), findsOneWidget);
              expect(find.byType(TextField), findsNothing);
              site.holdRead!.complete();
              await tester.pumpAndSettle();
              continue;
            }
            var action = '确认补录';
            if (scenario == 'read-error') {
              action = '重试读取';
            } else if (scenario == 'existing-zero') {
              action = '关闭';
            } else {
              await tester.ensureVisible(find.byType(TextField));
              await tester.pumpAndSettle();
              await tester.tapAt(tester.getCenter(find.byType(TextField)));
              if (scenario != 'empty') {
                tester.testTextInput.enterText(
                  scenario == 'maximum'
                      ? '999999'
                      : scenario == 'free'
                      ? '0'
                      : scenario == 'invalid'
                      ? '-1'
                      : '1.25',
                );
              }
              if (scenario == 'invalid') {
                await tester.testTextInput.receiveAction(TextInputAction.done);
              }
              await tester.pumpAndSettle();
              await save('input');
              if (scenario == 'maximum') {
                var group = 0;
                for (final value in ['¥999,', '998,', '990,', '000.01']) {
                  await tester.ensureVisible(find.text(value));
                  await tester.pumpAndSettle();
                  await save('amount${++group}');
                }
              }
              if (['blocked', 'uncertain', 'saving'].contains(scenario)) {
                await scrollToAction(tester, action);
                await tester.tapAt(tester.getCenter(find.text(action)));
                await tester.pumpAndSettle();
                expect(site.writes, hasLength(1));
                if (scenario == 'blocked') action = '重新检查';
                if (scenario == 'uncertain') action = '查询最新结果';
              }
            }
            if (scenario == 'normal') {
              for (
                var step = 1;
                step <= 30 &&
                    find.text(action).hitTestable().evaluate().isEmpty;
                step++
              ) {
                await tester.drag(formScroll, const Offset(0, -120));
                await tester.pumpAndSettle();
                await save('scroll$step');
              }
            }
            await scrollToAction(tester, action);
            await save('action');
            expect(tester.takeException(), isNull, reason: name);
            if (scenario == 'saving') {
              expect(find.byType(CircularProgressIndicator), findsNothing);
              expect(
                tester.widget<TextField>(find.byType(TextField)).enabled,
                false,
              );
              pending.complete(http.Response('', 503));
              await tester.pumpAndSettle();
            }
          }
        }
      }
    }
  }, skip: output.isEmpty);
}
