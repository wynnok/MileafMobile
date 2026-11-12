import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
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
    expect(
      tester
          .getSize(
            find
                .descendant(
                  of: find.byType(MapPanel),
                  matching: find.byType(ClipRRect),
                )
                .first,
          )
          .height,
      240,
    );
    await tester.scrollUntilVisible(find.bySemanticsLabel('距离 20.0 km'), 160);
    final distance = tester.getTopLeft(find.bySemanticsLabel('距离 20.0 km'));
    final duration = tester.getTopLeft(find.bySemanticsLabel('时长 120 分钟'));
    final net = tester.getTopLeft(find.bySemanticsLabel('净电耗 188 Wh/km'));
    expect(duration.dy, distance.dy);
    expect(net.dy, greaterThan(distance.dy));
    // Scroll on the widget itself: `.hitTestable()` on a semantics finder is
    // empty whenever the node's centre lands between the track and its labels.
    await tester.scrollUntilVisible(find.byType(SocIntervalBar), 160);
    expect(
      find.descendant(
        of: find.byType(SocIntervalBar),
        matching: find.bySemanticsLabel(RegExp('电量区间')),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('A 200% 底图同意条全文可见且不遮挡启用地图', (tester) async {
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
    final privacy = find.textContaining('不读取手机定位。');
    expect(privacy, findsOneWidget, reason: '隐私说明必须完整留在页面上');
    final text = tester.widget<Text>(privacy);
    expect(text.maxLines, isNull, reason: '不得用 maxLines 截断');
    expect(text.overflow, isNull, reason: '不得用 ellipsis 截断');
    final map = tester.getRect(find.byType(MapPanel));
    final copy = tester.getRect(privacy);
    final button = tester.getRect(find.text('启用地图'));
    final surface = tester.getRect(
      find
          .descendant(
            of: find.byType(MapPanel),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    expect(surface.height, 240, reason: 'R03/P04 地图图面保留，状态区自然增高');
    expect(copy.top, greaterThanOrEqualTo(surface.bottom));
    expect(copy.top, greaterThanOrEqualTo(map.top));
    expect(copy.bottom, lessThanOrEqualTo(button.top), reason: '文案与按钮不重叠');
    expect(
      button.bottom,
      lessThanOrEqualTo(map.bottom),
      reason: '按钮不超出地图、不被裁切',
    );
    expect(find.textContaining('设备/网络信息'), findsOneWidget);
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
    await tester.scrollUntilVisible(find.bySemanticsLabel('距离 20.0 km'), 160);
    expect(find.bySemanticsLabel('距离 20.0 km'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
