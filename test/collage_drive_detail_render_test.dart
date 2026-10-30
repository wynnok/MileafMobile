import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:http/testing.dart';
import 'package:mileaf/src/map_candidate.dart';

import 'drive_map_test.dart' show provider, tile;

import 'drives_test.dart' show jsonResponse;
import 'drive_detail_test.dart' show openDetail, fixture;

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
  testWidgets('C详情浅深正常空序列缺失200%正式渲染', (tester) async {
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
          await openDetail(
            tester,
            (r) async {
              final series = r.url.path.endsWith('/series');
              final body = fixture(
                series && scenario == 'empty'
                    ? 'drive-empty-series'
                    : series
                    ? 'drive-series'
                    : 'drive-detail',
              );
              if (series) {
                body['drive_id'] = 1;
                if (scenario == 'normal') {
                  var i = 0;
                  for (final point in body['series']) {
                    point['lat'] = 31.23 + i * .001;
                    point['lon'] = 121.47 + i++ * .001;
                  }
                }
              }
              if (!series && scenario == 'missing') {
                for (final field in [
                  'distance_km',
                  'duration_min',
                  'energy_kwh',
                  'consumption_wh_km',
                ]) {
                  body[field] = null;
                }
                body['start']['battery_level'] = null;
                body['end']['battery_level'] = null;
              }
              return jsonResponse(jsonEncode(body));
            },
            mapConfiguration: scenario == 'normal'
                ? MapConfiguration(
                    provider: provider,
                    sourceCrs: 'EPSG:4326',
                    tileClient: MockClient((_) async => tile()),
                  )
                : null,
          );
          if (scenario == 'normal') {
            await tester.tap(find.text('允许加载底图'));
            await tester.pumpAndSettle();
          }
          await save('$name-map');
          await tester.scrollUntilVisible(
            find.text('行程电量区间').hitTestable(),
            140,
          );
          await save('$name-result');
          await tester.scrollUntilVisible(
            (scenario == 'empty'
                    ? find.text('无采样数据')
                    : find.byKey(const ValueKey('sample-chart')))
                .hitTestable(),
            140,
          );
          await save('$name-chart');
          await tester.scrollUntilVisible(
            find.text('驾驶与环境').hitTestable(),
            140,
          );
          await save('$name-environment');
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      }
    }
  }, skip: output.isEmpty);
}
