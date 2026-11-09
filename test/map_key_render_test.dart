import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/map/map_consent.dart';
import 'package:mileaf/src/map/map_key.dart';
import 'package:mileaf/src/map/map_privacy_page.dart';

import 'support/map_key_fixture.dart';
import 'support/render_png.dart';

const _output = String.fromEnvironment('MILEAF_MAP_RENDER_OUTPUT');
const _font = String.fromEnvironment('MILEAF_RENDER_FONT');

void main() {
  setUpAll(() async {
    if (_output.isEmpty) return;
    final bytes = ByteData.sublistView(File(_font).readAsBytesSync());
    for (final family in ['Inter', 'Roboto', 'Arial', 'sans-serif']) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('地图设置正式组件浅深渲染与大字号、键盘验收', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          MapBinding.channel,
          (_) async => {
            '包名': 'app.mileaf.mileaf',
            '签名 SHA-1': List.filled(20, 'AB').join(':'),
          },
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MapBinding.channel, null),
    );
    for (final brightness in Brightness.values) {
      for (final state in [
        'empty',
        'saved',
        'restart',
        'help',
        'large',
        'keyboard',
      ]) {
        final keys = MapKeyController(TestKeyStore());
        await keys.restore();
        if (state == 'saved' || state == 'restart') await keys.save('a' * 32);
        if (state == 'restart') {
          keys.keyForMap();
          await keys.save('b' * 32);
        }
        tester.view.physicalSize = Size(state == 'large' ? 320 : 360, 800);
        tester.view.viewInsets = FakeViewPadding(
          bottom: state == 'keyboard' ? 300 : 0,
        );
        tester.platformDispatcher.textScaleFactorTestValue = state == 'large'
            ? 2
            : 1;
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              key: UniqueKey(),
              debugShowCheckedModeBanner: false,
              theme: mileafTheme(brightness),
              home: MapPrivacyPage(
                consent: MapConsentController(),
                providerName: '高德地图',
                keys: keys,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (state == 'help') {
          await tester.tap(find.text('如何申请 Key'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('如何申请 Key'));
          await tester.pumpAndSettle();
        }
        if (state == 'keyboard') {
          await tester.tap(find.byType(TextField));
          await tester.pumpAndSettle();
          await Scrollable.ensureVisible(
            tester.element(find.text('保存 Key')),
            alignment: 1,
          );
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        await saveRenderPng(
          tester,
          find.byKey(boundary),
          '$_output/map-${brightness.name}-$state.png',
        );
        await tester.pumpWidget(const SizedBox());
        keys.dispose();
      }
    }
  }, skip: _output.isEmpty);
}
