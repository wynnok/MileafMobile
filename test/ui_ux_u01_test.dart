import 'dart:io';
import 'dart:convert';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/semantic.dart';

import 'support/a_gallery_fixture.dart';
import 'support/color_math.dart';

import 'package:mileaf/src/design/typography.dart';

import 'drives_test.dart' show openDrives, jsonResponse;

void main() {
  testWidgets('R02 正式组件以36号周期主值和16号正文阅读', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: mileafTheme(Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                Text('期间', style: context.type.body),
                const MileafNumber(
                  value: '1,280.6',
                  unit: 'km',
                  scale: MetricValueScale.metricLg,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.widget<Text>(find.text('期间')).style!.fontSize, 16);
    final number = tester.widget<Text>(find.text('1,280.6 km'));
    expect(number.textSpan!.style!.fontSize, 36);
  });
  testWidgets('P02 首条记录完整且第二条起始可见', (tester) async {
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
    final first = tester.getRect(find.byKey(const ValueKey('drive-17')));
    final viewport = tester.getRect(find.byType(ListView).last);
    expect(first.bottom, lessThanOrEqualTo(viewport.bottom));
    // 规格§5 P02「第一条完整记录、第二条起始≥24可见」以记录起点计量：
    // 第二条整行可见高度须 ≥24，标题本身可被视口边缘裁切（滚动提示）。
    final second = tester.getRect(find.byKey(const ValueKey('drive-16')));
    expect(
      (viewport.bottom - second.top).clamp(0.0, second.height),
      greaterThanOrEqualTo(24),
    );
  });
  testWidgets('R05 筛选上下边缘实际可点击', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: mileafTheme(Brightness.light),
        home: Scaffold(
          body: Center(
            child: StatusChip(label: '近30天', onTap: () => taps++),
          ),
        ),
      ),
    );
    final rect = tester.getRect(find.byType(InkWell));
    expect(rect.height, greaterThanOrEqualTo(44));
    await tester.tapAt(Offset(rect.center.dx, rect.top + 1));
    await tester.tapAt(Offset(rect.center.dx, rect.bottom - 1));
    expect(taps, 2);
  });

  test('R04 输入边界与焦点按最终背景达到3比1', () {
    for (final colors in [
      const MileafColors.light(),
      const MileafColors.dark(),
    ]) {
      expect(
        contrastRatio(colors.controlBorder, colors.surface),
        greaterThanOrEqualTo(3),
      );
      expect(
        contrastRatio(colors.accentStrong, colors.surface),
        greaterThanOrEqualTo(3),
      );
    }
  });

  test('R02 自绘轴使用非线性TextScaler的12号实际值', () {
    expect(
      chartAxisLabelStyle(
        color: Colors.black,
        scaler: const _NonlinearScaler(),
      ).fontSize,
      24,
    );
  });

  test('U01 不规则日桶与原总计、能量、次数和配对率自洽', () async {
    final uri = Uri.parse(
      'https://example.test/vehicles/1/stats?kind=driving&from=2026-10-01T00:00:00Z&to=2026-10-27T00:00:00Z',
    );
    final regular = aGalleryClient();
    final irregular = aGalleryClient(irregular: true);
    addTearDown(regular.close);
    addTearDown(irregular.close);
    final before = jsonDecode((await regular.get(uri)).body) as Map;
    final after = jsonDecode((await irregular.get(uri)).body) as Map;
    expect(after['totals'], before['totals']);
    final buckets = (after['buckets'] as List).cast<Map>();
    final original = (before['buckets'] as List).cast<Map>();
    num sum(List<Map> rows, String key) =>
        rows.fold<num>(0, (total, row) => total + (row[key] as num? ?? 0));
    expect(sum(buckets, 'distance_km'), closeTo(1198.6, .00001));
    expect(sum(buckets, 'drives'), 46);
    expect(
      sum(buckets, 'energy_kwh'),
      closeTo(sum(original, 'energy_kwh'), .00001),
    );
    expect(buckets.map((b) => b['distance_km']).toSet().length, greaterThan(4));
    for (final b in buckets.where((b) => (b['distance_km'] as num) > 0)) {
      final paired = b['net_consumption_paired'] as Map;
      expect(paired['value_wh_km'], 158);
      expect(
        paired['numerator_energy_kwh'] /
            paired['denominator_distance_km'] *
            1000,
        closeTo(158, .5),
      );
    }
  });
  testWidgets('R05 普通字号看当天保留独立可操作语义', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(Brightness.light),
          home: Scaffold(
            body: TimeSeriesChart(
              title: '出行节奏',
              unit: 'km',
              times: [DateTime.utc(2026, 10, 1)],
              series: const [
                ChartSeries(label: '里程', values: [12]),
              ],
              semanticsLabel: '每日里程',
              onActivateSelected: () {},
            ),
          ),
        ),
      );
      final node = tester.getSemantics(find.bySemanticsLabel('查看这一天'));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('P14 320宽大字无键盘时标题也进入同一滚动流', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: mileafTheme(Brightness.light),
        home: Scaffold(
          body: MileafSheetFrame(
            title: '补录费用',
            child: Text(List.filled(10, '说明').join('\n')),
          ),
        ),
      ),
    );
    expect(
      find.ancestor(
        of: find.text('补录费用'),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _NonlinearScaler extends TextScaler {
  const _NonlinearScaler();
  @override
  double scale(double fontSize) => fontSize == 12 ? 24 : fontSize * 1.5;
  @override
  double get textScaleFactor => 1.5;
}
