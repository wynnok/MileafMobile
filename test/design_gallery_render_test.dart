import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/icons.dart';
import 'package:mileaf/src/design/layout.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/typography.dart';

import 'support/render_png.dart';

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

/// Opt-in component state gallery; run with MILEAF_RENDER_OUTPUT set.
void main() {
  setUpAll(() async {
    if (output.isEmpty) return;
    final bytes = ByteData.sublistView(File(fontPath).readAsBytesSync());
    for (final family in [
      'PingFang SC',
      'Noto Sans CJK SC',
      'Heiti SC',
      'sans-serif',
    ]) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
    for (final file in [
      'Inter-Regular.ttf',
      'Inter-Medium.ttf',
      'Inter-SemiBold.ttf',
    ]) {
      final font = await rootBundle.load('assets/fonts/$file');
      await (FontLoader('Inter')..addFont(Future.value(font))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets('A 组件状态画廊', (tester) async {
    tester.view.physicalSize = const Size(360, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final boundary = GlobalKey();
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: mileafTheme(brightness),
              home: const _Gallery(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await saveRenderPng(
          tester,
          find.byKey(boundary),
          '$output/gallery-${brightness.name}-${scale == 1 ? '100' : '200'}.png',
        );
      }
    }
  }, skip: output.isEmpty);
}

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final times = [for (var i = 0; i < 8; i++) DateTime(2026, 10, 1 + i)];
    return Scaffold(
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MileafHero(
                child: Padding(
                  padding: mileafHeroPadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const MileafTopBar(
                        vehicleName: '白露',
                        onVehicle: null,
                        onSettings: _noop,
                        onHero: true,
                        includeTopInset: false,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: context.colors.accentHero,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '充电中 · 11.0 kW',
                            style: context.type.label.copyWith(
                              color: context.colors.heroMuted,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '2 分钟前',
                            style: context.type.label.copyWith(
                              color: context.colors.heroFaint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const MileafNumber(
                                  value: '320',
                                  unit: 'km',
                                  scale: MetricValueScale.display,
                                  onHero: true,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '额定续航 · 非实时',
                                  style: context.type.micro.copyWith(
                                    color: context.colors.heroMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const BatteryArc(level: 68, onHero: true),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(color: context.colors.heroText.withValues(alpha: .12)),
                      const SizedBox(height: 8),
                      if (MileafLayout.largeText(context))
                        const Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: MetricBlock(
                                    label: '今日 km',
                                    value: '60.0',
                                    onHero: true,
                                  ),
                                ),
                                Expanded(
                                  child: MetricBlock(
                                    label: '次行程',
                                    value: '3',
                                    onHero: true,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: MetricBlock(
                                label: '估算 kWh',
                                value: '11.25',
                                onHero: true,
                              ),
                            ),
                          ],
                        )
                      else
                        const Row(
                          children: [
                            Expanded(
                              child: MetricBlock(
                                label: '今日 km',
                                value: '60.0',
                                onHero: true,
                              ),
                            ),
                            Expanded(
                              child: MetricBlock(
                                label: '次行程',
                                value: '3',
                                onHero: true,
                              ),
                            ),
                            Expanded(
                              child: MetricBlock(
                                label: '估算 kWh',
                                value: '11.25',
                                onHero: true,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(
                      title: '本月 · 驾驶里程',
                      range: 'OCT 2026',
                    ),
                    const SizedBox(height: 10),
                    const MetricBlock(
                      semanticLabel: '本月驾驶里程 1,198.6 km',
                      value: '1,198.6',
                      unit: 'km',
                      note: '净电耗 158 Wh/km · 比上月低 8',
                      scale: MetricValueScale.metricLg,
                      trailing: MetricDelta(
                        text: '8.2%',
                        label: '较上月同期',
                        up: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TimeSeriesChart(
                      title: '每日里程',
                      unit: 'km',
                      times: times,
                      series: const [
                        ChartSeries(
                          label: '里程',
                          values: [12, 30, 18, 60, 24, 38, 12, 60],
                          style: ChartSeriesStyle.area,
                        ),
                        ChartSeries(
                          label: '参照',
                          values: [10, 22, 16, 50, 20, 30, 14, 55],
                          style: ChartSeriesStyle.reference,
                        ),
                      ],
                      semanticsLabel: '每日里程图表',
                      subtitle: '10.01 — 10.08',
                      selectedIndex: 7,
                      readout: (index) => '10/${index + 1} · ${[12, 30, 18, 60, 24, 38, 12, 60][index]}.0 km',
                      trailing: const Text('点按读值'),
                    ),
                    const SizedBox(height: 20),
                    MileafDataRow(
                      title: '松岚小区 → 云栖中心',
                      meta: '10/26 · 46 分钟 · 154 Wh/km',
                      value: '32.9',
                      unit: 'km',
                      icon: MileafIconName.route,
                      showChevron: true,
                      topLine: true,
                      onTap: _noop,
                    ),
                    MileafDataRow(
                      title: '湖畔超级充电站',
                      meta: '10/25 · 18→82% · 34 分钟',
                      value: '46.8',
                      unit: 'kWh',
                      icon: MileafIconName.bolt,
                      showChevron: true,
                      bottomLine: true,
                      onTap: _noop,
                    ),
                    const SizedBox(height: 16),
                    const Wrap(
                      spacing: 8,
                      children: [
                        StatusChip(label: '近30天', selected: true),
                        StatusChip(label: '近7天'),
                        StatusChip(label: '日期'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    StemChart(
                      title: '每日补能',
                      unit: 'kWh',
                      times: times,
                      values: const [10, 0, 26, null, 14, 8, 0, 22],
                      semanticsLabel: '每日补能图表',
                      selectedIndex: 2,
                      readout: (index) => '10/${index + 1} · 26.0 kWh',
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(height: 20),
                    MileafButton(
                      label: '验证并替换连接',
                      onPressed: _noop,
                    ),
                    const SizedBox(height: 10),
                    MileafButton(
                      label: '允许地图底图',
                      kind: MileafButtonKind.secondary,
                      onPressed: _noop,
                    ),
                    const SizedBox(height: 10),
                    const MileafButton(
                      label: '不可用',
                      onPressed: null,
                    ),
                    const SizedBox(height: 20),
                    const InlineBanner(
                      message: '比较数据暂不可用；保留上次结果',
                      tone: BannerTone.warning,
                      actionLabel: '重试',
                    ),
                    const SizedBox(height: 20),
                    const StateView(
                      kind: StateViewKind.empty,
                      title: '这段时间还没有行程',
                      message: '换一个区间或下拉刷新',
                      actionLabel: '重试',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }
}

void _noop() {}
