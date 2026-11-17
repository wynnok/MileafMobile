import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/charts.dart';

import 'drives_test.dart' show openDrives, jsonResponse;

void main() {
  testWidgets('A 期间主数、三格与记录同屏可读，节奏卡在记录之后', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await openDrives(
      tester,
      (_) async =>
          jsonResponse(File('test/fixtures/drives.json').readAsStringSync()),
    );
    // P02 焦点卡：期间名 → metricLg 里程 → 三格（行程/估算耗电/电耗）。
    expect(find.text('近 30 天'), findsOneWidget);
    expect(find.textContaining('960.0'), findsWidgets);
    expect(find.text('49 趟'), findsOneWidget);
    expect(find.text('估算耗电'), findsOneWidget);
    expect(find.textContaining('180.00 kWh'), findsWidgets);
    expect(find.text('电耗'), findsOneWidget);
    expect(find.textContaining('188 Wh/km'), findsWidgets);
    // 记录按天分组后仍在首屏；节奏卡（「每日里程」）移到记录之后。
    expect(
      find.byKey(const ValueKey('drive-17')).hitTestable(),
      findsOneWidget,
    );
    expect(find.text('每日里程').hitTestable(), findsNothing);
    await tester.scrollUntilVisible(find.text('每日里程').hitTestable(), 200);
    expect(find.text('每日里程').hitTestable(), findsOneWidget);
  });

  testWidgets('A 空期间不画全零节奏并给出空态', (tester) async {
    final body = jsonDecode(
      File('test/fixtures/driving-stats.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    body['buckets'] = [];
    body['totals'] = {
      'drives': 0,
      'distance_km': 0.0,
      'energy_kwh': 0.0,
      'consumption_wh_km_net': null,
      'consumption_wh_km_gross': null,
      'speed_max_kmh': null,
    };
    await openDrives(
      tester,
      (_) async => jsonResponse('{"items":[],"next_cursor":null}'),
      statsHandler: (_) async => jsonResponse(jsonEncode(body)),
    );
    expect(find.text('0 趟'), findsOneWidget);
    expect(find.text('这段时间没有行程'), findsWidgets);
    expect(find.byType(TimeSeriesChart), findsNothing);
    expect(find.text('看当天'), findsNothing);
  });

  testWidgets('A 统计失败保留列表并以破折号显示缺失主数', (tester) async {
    await openDrives(
      tester,
      (_) async =>
          jsonResponse(File('test/fixtures/drives.json').readAsStringSync()),
      statsHandler: (_) async =>
          jsonResponse('{"error":{"code":"db_unavailable"}}'),
    );
    expect(find.text('重试行程统计'), findsOneWidget);
    expect(find.textContaining('—'), findsWidgets);
    expect(find.byKey(const ValueKey('drive-17')), findsOneWidget);
  });

  testWidgets('A 200% 期间与记录行不溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await openDrives(
      tester,
      (_) async =>
          jsonResponse(File('test/fixtures/drives.json').readAsStringSync()),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('49 趟'), findsOneWidget);
    // 节奏卡在记录之后：200% 下滚到它仍不溢出。
    await tester.scrollUntilVisible(find.text('每日里程').hitTestable(), 300);
    expect(find.text('每日里程'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
