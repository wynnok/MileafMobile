import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/map/map_panel.dart';

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
    expect(find.text('充入电池 20 kWh'), findsOneWidget);
    expect(find.textContaining('费用 12'), findsOneWidget);
    expect(find.text('时长 60 分钟'), findsOneWidget);
    expect(find.text('40% → 70%'), findsOneWidget);
  });

  testWidgets('A 充电详情电池弧 hero 浅色为 12 外边距卡片，其余内容保留页边距', (tester) async {
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
    // 旧断言是 hero.left == 0 / right == 360，编码的是「hero 永远全出血」这个被
    // ADR 0006 D4 推翻的决定。浅色（本测试的默认外观）下 hero 是卡片，量可见
    // 卡片而不是 MileafHero 的外框——后者天然仍有整行宽。
    final card = tester.getRect(
      find
          .descendant(
            of: find.byType(MileafHero),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(card.left, 12, reason: '卡片左右各 12 外边距');
    expect(card.right, 348);
    final title = tester.getRect(find.text('电量区间'));
    expect(title.left, 28, reason: 'hero 内容距屏幕边 12 + 16');
    final results = tester.getRect(find.text('充入电池 20 kWh'));
    expect(results.left, greaterThanOrEqualTo(20), reason: '结果区保留页边距');
    expect(tester.takeException(), isNull);
  });

  testWidgets('A 200% 电量弧 72 且结果不溢出', (tester) async {
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
    expect(tester.getSize(find.byType(BatteryArc)), const Size(72, 72));
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
    final privacy = find.textContaining('不读取手机定位。');
    await tester.scrollUntilVisible(privacy, 300);
    await tester.pumpAndSettle();
    expect(privacy, findsOneWidget, reason: '隐私说明必须完整留在页面上');
    final text = tester.widget<Text>(privacy);
    expect(text.maxLines, isNull, reason: '不得用 maxLines 截断');
    expect(text.overflow, isNull, reason: '不得用 ellipsis 截断');
    final map = tester.getRect(find.byType(MapPanel));
    final copy = tester.getRect(privacy);
    final button = tester.getRect(find.text('启用地图'));
    expect(map.height, 240, reason: '≥150% 时地点地图与行程地图同为 240');
    expect(copy.top, greaterThanOrEqualTo(map.top), reason: '文案不超出地图上缘');
    expect(copy.bottom, lessThanOrEqualTo(button.top), reason: '文案与按钮不重叠');
    expect(button.bottom, lessThanOrEqualTo(map.bottom), reason: '按钮完整在地图内');
    expect(find.textContaining('设备/网络信息'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
