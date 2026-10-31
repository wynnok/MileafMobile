import 'support/render_png.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'statistics_parking_test.dart' show openParking;

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const font = String.fromEnvironment('MILEAF_RENDER_FONT');
void main() {
  setUpAll(() async {
    if (output.isEmpty) return;
    final bytes = ByteData.sublistView(File(font).readAsBytesSync());
    for (final family in ['Roboto', 'Arial', 'sans-serif']) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('C停放观察正式渲染', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    for (final state in ['normal', 'missing', 'empty']) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 2.0]) {
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await openParking(
            tester,
            [],
            missing: state == 'missing',
            empty: state == 'empty',
          );
          Future<void> save(String part) => saveRenderPng(
            tester,
            find.byType(RepaintBoundary).first,
            '$output/$state-${brightness.name}-${scale == 1 ? 100 : 200}-$part.png',
          );

          await save('result');
          if (state != 'empty') {
            await tester.scrollUntilVisible(
              find.byKey(const Key('parking-trend-chart')),
              80,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.ensureVisible(
              find.byKey(const Key('parking-trend-chart')),
            );
            await save('chart');
          }
          await tester.scrollUntilVisible(
            find.text('加载更多窗口').hitTestable(),
            120,
            scrollable: find.byType(Scrollable).last,
          );
          await save('evidence');
          await tester.pumpWidget(const SizedBox());
        }
      }
    }
  }, skip: output.isEmpty);
}
