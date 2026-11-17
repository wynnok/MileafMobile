import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mileaf/src/design/components/components.dart';

import 'support/map_key_fixture.dart';
import 'charging_detail_test.dart' show app, fixture, initial, response;

void main() {
  testWidgets('A 充电详情以电量弧开场并给出三结果', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/charging-sessions/1')) {
        return response(fixture('charging-detail'));
      }
      if (request.url.path.endsWith('/charging-sessions/1/series')) {
        return response(fixture('charging-series'));
      }
      return initial(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('最近充电').hitTestable(), 300);
    await tester.tap(find.text('最近充电').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('电量区间'), findsOneWidget);
    expect(find.byType(BatteryArc), findsOneWidget);
    expect(find.text('40% → 70%'), findsOneWidget);
    expect(find.text('20 kWh'), findsOneWidget);
    expect(find.text('费用'), findsOneWidget);
    expect(find.text('60 分钟'), findsOneWidget);
    expect(find.text('40% → 70%'), findsOneWidget);
  });

  testWidgets('U01 充电详情同底横向SOC与页边对齐', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/charging-sessions/1')) {
        return response(fixture('charging-detail'));
      }
      if (request.url.path.endsWith('/charging-sessions/1/series')) {
        return response(fixture('charging-series'));
      }
      return initial(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('最近充电').hitTestable(), 300);
    await tester.tap(find.text('最近充电').hitTestable());
    await tester.pumpAndSettle();
    // R04/P05 取代旧浅色深底卡片。横向SOC摘要与页边对齐。
    expect(find.byType(MileafHero), findsNothing);
    final arc = tester.getRect(find.byType(BatteryArc));
    expect(arc.left, 20);
    // R29：环内只放数值，「电量」标签移到环外，组件因此比 88 高一行；
    // 88 仍是电量弧本身的尺寸。
    expect(
      tester
          .getRect(
            find
                .descendant(
                  of: find.byType(BatteryArc),
                  matching: find.byType(CustomPaint),
                )
                .first,
          )
          .height,
      88,
    );
    final title = tester.getRect(find.text('电量区间'));
    expect(title.left, arc.right + 16);
    final results = tester.getRect(find.text('20 kWh'));
    expect(results.left, greaterThanOrEqualTo(20));
    expect(
      tester.getTopLeft(find.text('20 kWh')).dy,
      tester.getTopLeft(find.text('60 分钟')).dy,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('A 200% 电量弧 88 且结果不溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/charging-sessions/1')) {
        return response(fixture('charging-detail'));
      }
      if (request.url.path.endsWith('/charging-sessions/1/series')) {
        return response(fixture('charging-series'));
      }
      return initial(request);
    });
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('最近充电').hitTestable(), 300);
    await tester.tap(find.text('最近充电').hitTestable());
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(BatteryArc)), const Size(88, 88));
    expect(tester.takeException(), isNull);
  });

  testWidgets('A 200% 充电地点地图同意条全文可见且不遮挡启用地图', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/charging-sessions/1')) {
        return response(fixture('charging-detail'));
      }
      if (request.url.path.endsWith('/charging-sessions/1/series')) {
        return response(fixture('charging-series'));
      }
      return initial(request);
    });
    final mapKeys = await configuredMapKeys();
    addTearDown(mapKeys.dispose);
    await tester.pumpWidget(app(client, mapKeys: mapKeys));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('最近充电').hitTestable(), 300);
    await tester.tap(find.text('最近充电').hitTestable());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('启用地图').hitTestable(), 200);
    await tester.tap(find.text('启用地图').hitTestable());
    await tester.pumpAndSettle();
    expect(find.textContaining('不会读取手机定位'), findsOneWidget);
    expect(find.textContaining('设备/网络信息'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
