import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/nav_bar.dart';
import 'package:mileaf/src/design/components/page_bar.dart';
import 'package:mileaf/src/design/icons.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/layout.dart';
import 'package:mileaf/src/overview_page.dart';

import 'support/a_gallery_fixture.dart';
import 'statistics_test.dart' show openStats;
import 'support/render_fonts.dart';
import 'support/render_png.dart';

/// R26/R32：二级导航的返回图标改用自绘图标集（24 网格、1.5 描边）。
final backIcon = find.byWidgetPredicate(
  (widget) => widget is MileafIcon && widget.name == MileafIconName.back,
);

void main() {
  const output = String.fromEnvironment('MILEAF_NAV_RENDER_OUTPUT');
  const font = String.fromEnvironment('MILEAF_RENDER_FONT');
  for (final width in [360.0, 390.0, 768.0]) {
    testWidgets('统计专题 $width 宽导航与期间共用内容边线', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      if (output.isNotEmpty) await loadRenderFonts(cjkFontPath: font);
      await openStats(
        tester,
        aGalleryClient(),
        () => DateTime.utc(2026, 10, 28, 11),
        () => 'Asia/Shanghai',
        statisticsInsights: true,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(MileafNavBar),
          matching: find.text('概览'),
        ),
      );
      await tester.pumpAndSettle();
      final topic = find.descendant(
        of: find.byType(OverviewPage),
        matching: find.text('节奏').hitTestable(),
      );
      for (var i = 0; i < 20 && topic.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -240));
        await tester.pumpAndSettle();
      }
      expect(topic, findsOneWidget);
      await tester.tap(topic);
      await tester.pumpAndSettle();
      final period = tester.getRect(find.text('期间 · 2026年10月'));
      final icon = tester.getRect(backIcon);
      final title = tester.getRect(
        find.descendant(
          of: find.byType(MileafNavigationRow),
          matching: find.text('用车节奏'),
        ),
      );
      expect(icon.left, closeTo(period.left, .01));
      expect(title.left - icon.right, closeTo(12, .01));
      final action = tester.getRect(find.text('全部指标'));
      expect(width - action.right, closeTo(period.left, .01));
      expect(tester.takeException(), isNull);
      if (output.isNotEmpty) {
        await saveRenderPng(
          tester,
          find.byType(RepaintBoundary).first,
          '$output/statistics-navigation-${width.toInt()}.png',
        );
      }
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('统计'), findsWidgets);
    });
  }
  for (final width in [320.0, 768.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('二级导航 $width 宽 $scale 字号完整标题与返回可用', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: mileafTheme(Brightness.light),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => Scaffold(
                        appBar: mileafPageBar(
                          context,
                          title: const Text('全部指标与口径'),
                          actions: [
                            TextButton(
                              onPressed: () {},
                              child: const Text('数据说明'),
                            ),
                          ],
                        ),
                        body: MileafContent(
                          padding: MileafLayout.pageHorizontal(context),
                          child: const SizedBox(
                            width: double.infinity,
                            child: Text('内容'),
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('打开'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(backIcon, findsOneWidget);
        final back = tester.getRect(find.byType(BackButton));
        expect(back.width, greaterThanOrEqualTo(44));
        expect(back.height, greaterThanOrEqualTo(44));
        expect(
          tester.getTopLeft(backIcon).dx,
          closeTo(tester.getTopLeft(find.text('内容')).dx, .01),
        );
        if (scale == 2) {
          expect(
            tester.getTopLeft(find.text('数据说明')).dy,
            greaterThan(tester.getBottomLeft(find.text('全部指标与口径')).dy),
          );
        }
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('打开'), findsOneWidget);
      });
    }
  }
}
