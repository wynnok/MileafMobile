import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mileaf/src/map/map_key.dart';

import 'charging_cost_test.dart' show CostSite, pumpCostApp, openCostSheet;
import 'support/map_key_fixture.dart';
import 'support/render_fonts.dart';
import 'support/render_png.dart';
import 'ui_ux_u10_test.dart'
    show configureView, enterAndCheck, pumpFlow, tapText;

const _output = String.fromEnvironment('MILEAF_AP13_RENDER_OUTPUT');
const _font = String.fromEnvironment('MILEAF_RENDER_FONT');

/// AP13 正式渲染入口（opt-in）：P12–P16 设置、接入、费用补录与弹层机位。
/// 命名沿交付手册 §5：AP13-<页面>-<场景>-glass-<浅深>-<宽>x<高>-<字号>-top.png。
void main() {
  setUp(() {
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
  });

  setUpAll(() async {
    if (_output.isEmpty) return;
    await loadRenderFonts(cjkFontPath: _font);
  });

  testWidgets('AP13 设置、接入与费用补录机位矩阵', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    final manifest = <String, dynamic>{
      'input_freeze': 'FP3',
      'ticket': 'AP13',
      'font': _font,
      'images': <String>[],
    };
    for (final brightness in Brightness.values) {
      for (final spec in [
        (const Size(390, 844), 1.0),
        (const Size(320, 568), 2.0),
      ]) {
        final (size, scale) = spec;
        for (final scene in [
          'settings',
          'appearance',
          'currency',
          'map',
          'map-help',
          'connection',
          'connection-edit',
          'login',
          'setup',
        ]) {
          configureView(tester, size, scale);
          final keys = MapKeyController(TestKeyStore());
          await keys.restore();
          if (scene == 'map-help' || scene == 'currency') {
            await keys.save('a' * 32);
          }
          final boundary = GlobalKey();
          if (scene == 'login' || scene == 'setup') {
            final pending = <String, Completer<http.Response>>{};
            await pumpFlow(
              tester,
              loggedIn: false,
              brightness: brightness,
              boundary: boundary,
              pendingResponses: pending,
            );
            await enterAndCheck(tester);
            if (scene == 'setup') await tapText(tester, '首次设置站点口令');
          } else {
            await pumpFlow(
              tester,
              loggedIn: true,
              brightness: brightness,
              boundary: boundary,
              keys: keys,
            );
            await tester.tap(find.byTooltip('设置'));
            await tester.pumpAndSettle();
            switch (scene) {
              case 'appearance':
                await tapText(tester, '外观');
              case 'currency':
                await tapText(tester, '币种');
              case 'map' || 'map-help':
                await tapText(tester, '地图');
                if (scene == 'map-help') await tapText(tester, '如何申请 Key');
              case 'connection':
                await tapText(tester, '站点连接');
              case 'connection-edit':
                await tapText(tester, '站点连接');
                await tapText(tester, '更换连接');
            }
          }
          final name =
              'AP13-$scene-glass-${brightness.name}-${size.width.toInt()}x${size.height.toInt()}-${(scale * 100).round()}-top';
          await saveRenderPng(
            tester,
            find.byKey(boundary),
            '$_output/$name.png',
          );
          manifest['images'] = [
            ...(manifest['images'] as List<String>),
            '$name.png',
          ];
          expect(tester.takeException(), isNull, reason: name);
          await tester.pumpWidget(const SizedBox());
          keys.dispose();
        }
        // P14 费用补录贴边弹层（独立夹具）。
        final costBoundary = GlobalKey();
        final site = CostSite();
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await pumpCostApp(tester, site, size: size, boundary: costBoundary);
        await tester.tap(find.text('充电').last);
        await tester.pumpAndSettle();
        await openCostSheet(tester);
        final costName =
            'AP13-cost-form-glass-${brightness.name}-${size.width.toInt()}x${size.height.toInt()}-${(scale * 100).round()}-top';
        await saveRenderPng(
          tester,
          find.byKey(costBoundary),
          '$_output/$costName.png',
        );
        manifest['images'] = [
          ...(manifest['images'] as List<String>),
          '$costName.png',
        ];
        expect(tester.takeException(), isNull, reason: costName);
        await tester.pumpWidget(const SizedBox());
      }
    }
    await tester.runAsync(() async {
      await File('$_output/manifest.json')
          .writeAsString(const JsonEncoder.withIndent('  ').convert(manifest));
    });
  }, skip: _output.isEmpty);
}
