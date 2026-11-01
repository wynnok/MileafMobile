import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/map/map_consent.dart';
import 'package:mileaf/src/map/map_panel.dart';

import 'drive_detail_test.dart' show fixture, openDetail;
import 'drives_test.dart' show jsonResponse;

void main() {
  testWidgets('A 200% 地图 240、结果 2×2 且电量区间可读', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await openDetail(
      tester,
      (r) async => jsonResponse(
        jsonEncode(
          fixture(
            r.url.path.endsWith('/series') ? 'drive-series' : 'drive-detail',
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(MapPanel)).height, 240);
    await tester.scrollUntilVisible(find.bySemanticsLabel('距离 20.0 km'), 160);
    final distance = tester.getTopLeft(find.bySemanticsLabel('距离 20.0 km'));
    final duration = tester.getTopLeft(find.bySemanticsLabel('时长 120 分钟'));
    final net = tester.getTopLeft(find.bySemanticsLabel('净电耗 188 Wh/km'));
    expect(duration.dy, distance.dy);
    expect(net.dy, greaterThan(distance.dy));
    await tester.scrollUntilVisible(
      find.bySemanticsLabel(RegExp('电量区间')).hitTestable(),
      160,
    );
    expect(find.bySemanticsLabel(RegExp('电量区间')), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A 底图失败保留路线速写与结果', (tester) async {
    final consent = MapConsentController();
    addTearDown(consent.dispose);
    await openDetail(
      tester,
      (r) async => jsonResponse(
        jsonEncode(
          fixture(
            r.url.path.endsWith('/series') ? 'drive-series' : 'drive-detail',
          ),
        ),
      ),
      mapConsent: consent,
    );
    expect(find.textContaining('底图未启用'), findsOneWidget);
    expect(find.textContaining(' → '), findsWidgets);
    expect(find.bySemanticsLabel('距离 20.0 km'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
