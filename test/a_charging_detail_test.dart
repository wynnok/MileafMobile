import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/semantic.dart';

import 'support/map_key_fixture.dart';
import 'charging_detail_test.dart' show app, fixture, initial, response;

void main() {
  testWidgets('充电详情：电量弧与功率曲线用电量域，读数配焦点底', (tester) async {
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

    final colors = MileafColors.of(tester.element(find.text('充入电量')));
    const energy = MileafDataDomain.energy;

    final arc = tester.widget<BatteryArc>(find.byType(BatteryArc));
    expect(arc.hue, energy.hue);
    expect(arc.onHero, isTrue);
    expect(
      tester
          .widgetList<MetricBlock>(find.byType(MetricBlock))
          .firstWhere((block) => block.label == '充入电量')
          .hue,
      isNull,
    );
    expect(colors.surface, isNot(const MileafColors.light().surface));
    // CL01：功率曲线属 energy 域，整张图一个色相。
    await tester.scrollUntilVisible(find.byType(TimeSeriesChart), 300);
    expect(
      tester.widget<TimeSeriesChart>(find.byType(TimeSeriesChart)).hue,
      energy.hue,
    );
  });

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
    // P05：电量环与「起始 → 结束」并排，三格是 充入电量 / 费用 / 时长。
    expect(find.byType(BatteryArc), findsOneWidget);
    expect(find.text('40% → 70%'), findsOneWidget);
    expect(find.text('充入电量'), findsOneWidget);
    expect(find.textContaining('kWh', findRichText: true), findsWidgets);
    expect(find.text('费用'), findsOneWidget);
    expect(find.text('1 小时'), findsOneWidget);
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
    // R04/P05：电量摘要进模块卡（页边 20 + 卡内 16 = 36），不再同底。
    expect(find.byType(MileafHero), findsNothing);
    final arc = tester.getRect(find.byType(BatteryArc));
    expect(arc.left, 36);
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
    final title = tester.getRect(find.text('40% → 70%'));
    expect(title.left, arc.right + 16);
    final results = tester.getRect(
      find.textContaining('kWh', findRichText: true).first,
    );
    expect(results.left, greaterThanOrEqualTo(36));
    // 三格同排：充入电量、费用、时长的数值基线对齐。
    expect(
      tester.getTopLeft(find.text('充入电量')).dy,
      tester.getTopLeft(find.text('费用')).dy,
    );
    expect(
      tester.getTopLeft(find.text('费用')).dy,
      tester.getTopLeft(find.text('时长')).dy,
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
    // 大字下电量弧收到 largeTextSize（72），数值移到环外，不溢出。
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
      72,
    );
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
