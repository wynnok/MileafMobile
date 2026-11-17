// AP05 证据渲染：图表语法图板（完整读数头、紧凑读数行、右 Y 轴、柱端圆角、
// 参照刻度、选中标记、无数据收起）。浅深 × 100/200%。
// opt-in：未设置 MILEAF_RENDER_OUTPUT / MILEAF_RENDER_FONT 时跳过。
// 正式渲染见交付手册 $5；输出目录 docs/implementation/apple-polish-renders/AP05。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/typography.dart';

import 'support/render_fonts.dart';
import 'support/render_png.dart';

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

List<DateTime> days(int count) => [
  for (var i = 0; i < count; i++) DateTime(2026, 10, 1 + i),
];

Widget _board(Brightness brightness) {
  final colors = brightness == Brightness.dark
      ? const MileafColors.dark()
      : const MileafColors.light();
  final type = MileafTextStyles.resolve(colors);
  Widget card(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
  return MaterialApp(
    theme: mileafTheme(brightness),
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      backgroundColor: colors.canvas,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('行笺 · 图表语法', style: type.title2),
            const SizedBox(height: 4),
            Text('R29 读数头 / 坐标 / 标记（AP05）', style: type.subheadline),
            const SizedBox(height: 16),
            card(
              TimeSeriesChart(
                title: '每日里程',
                unit: 'km',
                times: days(5),
                series: const [
                  ChartSeries(
                    label: '里程',
                    values: [12, 30, null, 65, 8],
                    style: ChartSeriesStyle.bars,
                  ),
                  ChartSeries(
                    label: '上月同期',
                    values: [14, 22, 28, 40, 50],
                    style: ChartSeriesStyle.reference,
                  ),
                ],
                semanticsLabel: '每日里程图表',
                selectedIndex: 3,
                showYAxis: true,
                height: 140,
                readout: (index) => '10月${index + 1}日',
              ),
            ),
            card(
              TimeSeriesChart(
                title: '净电耗趋势',
                unit: 'Wh/km',
                times: days(5),
                series: const [
                  ChartSeries(label: '本期', values: [158, 166, 172, 149, 161]),
                  ChartSeries(
                    label: '上月同期',
                    values: [168, 170, 175, 158, 166],
                    style: ChartSeriesStyle.reference,
                  ),
                ],
                semanticsLabel: '净电耗趋势图表',
                selectedIndex: 1,
                showYAxis: true,
                height: 140,
                note: '估算，按续航差计算',
              ),
            ),
            card(
              TimeSeriesChart(
                title: '停放电量变化',
                unit: 'kWh',
                times: days(5),
                series: const [
                  ChartSeries(
                    label: '停放变化',
                    values: [120, -45, 0, null, 260],
                    style: ChartSeriesStyle.bars,
                  ),
                ],
                semanticsLabel: '停放电量变化图表',
                selectedIndex: 1,
                showYAxis: true,
                height: 140,
              ),
            ),
            card(
              StemChart(
                title: '每日补能',
                unit: 'kWh',
                times: days(5),
                values: const [10, 0, null, null, 7],
                semanticsLabel: '每日补能图表',
                selectedIndex: 4,
                height: 88,
                compactReadout: true,
              ),
            ),
            card(
              TimeSeriesChart(
                title: '单点与长轴标',
                unit: 'Wh/km',
                times: [DateTime(2026, 10, 28)],
                series: const [
                  ChartSeries(label: '净电耗', values: [9800]),
                ],
                semanticsLabel: '单点与长轴标图表',
                showYAxis: true,
                height: 120,
              ),
            ),
            card(
              TimeSeriesChart(
                title: '全空',
                unit: 'km',
                times: const [],
                series: const [ChartSeries(label: '每日里程', values: [])],
                semanticsLabel: '全空图表',
                emptyMessage: '这段时间没有行程',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    if (output.isEmpty) return;
    if (fontPath.isNotEmpty) await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('AP05 chart grammar board', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final boundary = GlobalKey();
    final files = <String>[];
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pumpWidget(
          RepaintBoundary(key: boundary, child: _board(brightness)),
        );
        await tester.pumpAndSettle();
        final mode = brightness.name;
        final tag = (scale * 100).round().toString();
        final name = 'AP05-charts-normal-$mode-390x844-$tag-top.png';
        await saveRenderPng(tester, find.byKey(boundary), '$output/$name');
        files.add(name);
      }
    }
    File('$output/manifest.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'input_sha': 'c18f2fc',
        'ticket': 'AP05',
        'fixture':
            'chart grammar board: readout header, compact row, right Y axis, '
            'bar end radius, reference ticks, selection marker, empty state',
        'timezone': 'Asia/Shanghai',
        'font': fontPath,
        'logical_size': '390x844',
        'pixel_ratio': 2,
        'text_scales': ['100', '200'],
        'material': 'default',
        'images': files,
      }),
    );
  }, skip: output.isEmpty || fontPath.isEmpty);
}
