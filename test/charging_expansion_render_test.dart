import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'charging_expansion_test.dart'
    show detailV2, expansionResponse, seriesV2;
import 'charging_test.dart' show app, initial, jsonResponse;

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

void main() {
  setUpAll(() async {
    if (output.isEmpty) return;
    final data = ByteData.sublistView(File(fontPath).readAsBytesSync());
    for (final family in ['Roboto', 'Arial', 'sans-serif']) {
      await (FontLoader(family)..addFont(Future.value(data))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('补能账本在360宽浅深色和200%字号下实际渲染', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final boundary = GlobalKey();
    Future<void> save(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: name);
      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundary),
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

    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final scale in [1.0, 2.0]) {
        final suffix = '${brightness.name}-${scale == 1 ? '100' : '200'}';
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/summary')) {
            final body =
                jsonDecode(initial(request).body) as Map<String, dynamic>;
            (body['last_charge'] as Map<String, dynamic>)['id'] = 1;
            return jsonResponse(body);
          }
          if (request.url.path.endsWith('/charging-sessions/1')) {
            return jsonResponse(detailV2());
          }
          if (request.url.path.endsWith('/charging-sessions/1/series')) {
            return jsonResponse(seriesV2());
          }
          if (request.url.path.endsWith('/charging-sessions') &&
              request.url.queryParameters['time_basis'] == 'started_at') {
            final body = jsonDecode(
              expansionResponse(request).body,
            ) as Map<String, dynamic>;
            body['items'] = <Object>[];
            return jsonResponse(body);
          }
          return expansionResponse(request);
        });
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: app(client, key: ValueKey(suffix)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('充电'));
        await save('home-$suffix');
        if (scale == 1) {
          final chart = find.byKey(const Key('charging-briefing-chart'));
          expect(chart, findsOneWidget, reason: '首屏应露出实际绘图区');
          expect(tester.getRect(chart).top, lessThan(720));
        }
        await tester.scrollUntilVisible(
          find.widgetWithText(ListTile, '家 · 地库').hitTestable(),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await save('locations-$suffix');
        await tester.scrollUntilVisible(
          find.text('全部记录').hitTestable(),
          -180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('全部记录'));
        await save('records-$suffix');
        await tester.tap(find.text('概览').last);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('最近充电').hitTestable(), 180);
        await tester.tap(find.text('最近充电').hitTestable());
        await save('detail-$suffix');
        await tester.scrollUntilVisible(find.text('按电量').hitTestable(), 180);
        await tester.tap(find.text('按电量').hitTestable());
        await save('soc-$suffix');
        await tester.scrollUntilVisible(
          find.text('电池加热状态变化').hitTestable(),
          180,
        );
        await save('heater-$suffix');
        // 过程指标收在「过程数据说明」折叠层里，先展开再截取。
        await tester.scrollUntilVisible(find.text('过程数据说明').hitTestable(), 180);
        await tester.tap(find.text('过程数据说明').hitTestable());
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.textContaining('原始功率峰值').hitTestable(),
          180,
        );
        await save('process-$suffix');
        await tester.pumpWidget(const SizedBox());
      }
    }
  }, skip: output.isEmpty);
}
