import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/page_bar.dart';
import 'package:mileaf/src/design/theme.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('二级导航 320 宽 $scale 字号完整标题与返回可用', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
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
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      final back = tester.getRect(find.byType(BackButton));
      expect(back.width, greaterThanOrEqualTo(44));
      expect(back.height, greaterThanOrEqualTo(44));
      if (scale == 2) {
        expect(
          tester.getTopLeft(find.text('数据说明')).dy,
          greaterThan(tester.getBottomLeft(find.text('全部指标与口径')).dy),
        );
      }
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('打开'), findsOneWidget);
    });
  }
}
