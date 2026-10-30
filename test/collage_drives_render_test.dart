import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'drives_test.dart' show openDrives, jsonResponse;

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');
void main() {
  setUpAll(() async {
    if (output.isEmpty) return;
    final bytes = ByteData.sublistView(File(fontPath).readAsBytesSync());
    for (final family in ['Roboto', 'Arial', 'sans-serif']) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  testWidgets('C行程浅深正常空缺失200%正式渲染', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    Future<void> save(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: name);
      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first,
      );
      await tester.runAsync(() async {
        final image = await render.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$output/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final scenario in ['normal', 'empty', 'missing']) {
      for (final brightness in Brightness.values) {
        for (final scale in [1.0, 2.0]) {
          final name = '$scenario-${brightness.name}-${scale == 1 ? 100 : 200}';
          tester.platformDispatcher.platformBrightnessTestValue = brightness;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await openDrives(
            tester,
            (_) async {
              final body = jsonDecode(
                File('test/fixtures/drives.json').readAsStringSync(),
              );
              if (scenario == 'empty') {
                body['items'] = [];
                body['next_cursor'] = null;
              }
              if (scenario == 'missing') {
                for (final d in body['items']) {
                  d['distance_km'] = null;
                  d['energy_kwh'] = null;
                  d['consumption_wh_km'] = null;
                  d['start']['display_name'] = '很长的起点地址与围栏名称用于验证大字体下仍然完整可读';
                }
              }
              return jsonResponse(jsonEncode(body));
            },
            statsHandler: (_) async {
              final body = jsonDecode(
                File('test/fixtures/driving-stats.json').readAsStringSync(),
              );
              if (scenario == 'empty') {
                body['buckets'] = [];
                for (final key in body['totals'].keys.toList()) {
                  body['totals'][key] =
                      (key == 'drives' || key == 'distance_km') ? 0 : null;
                }
              }
              if (scenario == 'missing') {
                // Distance is required by the frozen statistics contract.
                body['totals']['energy_kwh'] = null;
                body['totals']['consumption_wh_km_net'] = null;
              }
              return jsonResponse(jsonEncode(body));
            },
          );
          expect(find.text('行程统计读取失败'), findsNothing);
          await save('$name-top');
          if (scenario != 'empty') {
            await tester.scrollUntilVisible(
              find.byKey(const ValueKey('drive-17')),
              100,
            );
            await save('$name-record');
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      }
    }
  }, skip: output.isEmpty);
}
