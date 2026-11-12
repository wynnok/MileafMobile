import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/icons.dart';
import 'package:mileaf/src/design/layout.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/typography.dart';

import 'support/render_fonts.dart';
import 'support/render_png.dart';

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

/// Opt-in component state gallery; run with MILEAF_RENDER_OUTPUT set.
///
/// U02 图册矩阵：浅深 × 100/200%，三条画廊
/// `gallery-*`（代表组件）、`gallery-long-*`（长文本）、
/// `gallery-states-*`（焦点/禁用/处理中），每种角色均可查。
void main() {
  setUpAll(() async {
    if (output.isEmpty) return;
    await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('A 组件状态画廊', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    final boundary = GlobalKey();
    const galleries = {
      'gallery': (Size(360, 1200), _Gallery.new),
      'gallery-long': (Size(360, 2200), _LongGallery.new),
      'gallery-states': (Size(360, 1900), _StatesGallery.new),
    };
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        for (final entry in galleries.entries) {
          tester.view.physicalSize = entry.value.$1;
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: mileafTheme(brightness),
                home: entry.value.$2(),
              ),
            ),
          );
          if (entry.key == 'gallery-states') {
            // 焦点证据：Tab 把真实键盘焦点落在画廊第一个控件（焦点按钮），
            // 同屏其余控件保持未聚焦，便于对照焦点环。处理中的转圈不收敛，
            // 只推进固定帧，不使用 pumpAndSettle。
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
          } else {
            await tester.pumpAndSettle();
          }
          await saveRenderPng(
            tester,
            find.byKey(boundary),
            '$output/${entry.key}-${brightness.name}-${scale == 1 ? '100' : '200'}.png',
            settle: entry.key != 'gallery-states',
          );
        }
      }
    }
  }, skip: output.isEmpty);
}

/// 短文本代表画廊：hero、主数、图表、记录行、chip 与按钮。
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
                        Flexible(
                          child: Text(
                            '充电中 · 11.0 kW',
                            style: context.type.label.copyWith(
                              color: context.colors.heroMuted,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            '2 分钟前',
                            style: context.type.label.copyWith(
                              color: context.colors.heroFaint,
                            ),
                            textAlign: TextAlign.end,
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
                    Divider(
                      color: context.colors.heroText.withValues(alpha: .12),
                    ),
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
                  const SectionHeader(title: '本月 · 驾驶里程', range: 'OCT 2026'),
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
                    readout: (index) =>
                        '10/${index + 1} · ${[12, 30, 18, 60, 24, 38, 12, 60][index]}.0 km',
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
                  MileafButton(label: '验证并替换连接', onPressed: _noop),
                  const SizedBox(height: 10),
                  MileafButton(
                    label: '允许地图底图',
                    kind: MileafButtonKind.secondary,
                    onPressed: _noop,
                  ),
                  const SizedBox(height: 10),
                  const MileafButton(label: '不可用', onPressed: null),
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

/// 长文本画廊：顶栏长车名、长地点、长金额、长 URL、长按钮与长错误。
class _LongGallery extends StatelessWidget {
  const _LongGallery();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: MileafTopBar(
                vehicleName: '北仑港·滨海超级充电站有限公司车队二号车',
                onVehicle: _noop,
                onSettings: _noop,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MileafDataRow(
                    title: '杭州市西湖区文三路 199 号创业大厦 12 层 A 座充电桩',
                    meta: '10/25 · 18→82% · 34 分钟 · 估算 197.47 kWh',
                    value: '12,345.67',
                    unit: 'kWh',
                    icon: MileafIconName.bolt,
                    showChevron: true,
                    topLine: true,
                    bottomLine: true,
                    onTap: _noop,
                  ),
                  const SizedBox(height: 16),
                  const ChipRow(
                    children: [
                      StatusChip(
                        label: '2026-03-01 至 2026-03-30',
                        selected: true,
                      ),
                      StatusChip(label: '查看期间补能记录'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  MileafButton(
                    label: '验证并替换当前站点连接配置并保留历史数据',
                    onPressed: _noop,
                    expand: true,
                  ),
                  const SizedBox(height: 12),
                  const MileafCopyRow(
                    label: '设备标识',
                    value: 'app.mileaf.mileaf.device-9f2c7a1e5b3d4c6a8b0d2e4f6a8c0e2b',
                  ),
                  const SizedBox(height: 20),
                  const InlineBanner(
                    message: '更新失败：无法读取设备 IANA 时区，保留 10/26 旧数据与选点，重试仅刷新当前资源。',
                    tone: BannerTone.error,
                    actionLabel: '重试',
                  ),
                  const SizedBox(height: 20),
                  const MileafNumber(
                    value: null,
                    unit: 'km',
                    scale: MetricValueScale.metricLg,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '暂无本月数据 · 期间 10.01 — 10.31 · 估算口径',
                    style: context.type.micro.copyWith(
                      color: context.colors.textMuted,
                    ),
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

/// 状态画廊：焦点（真实 autofocus）、禁用、处理中、选中与图形组件。
class _StatesGallery extends StatelessWidget {
  const _StatesGallery();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FocusSection(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('处理中 / 禁用', style: context.type.title),
                  const SizedBox(height: 12),
                  const MileafButton(
                    label: '正在提交',
                    loading: true,
                    onPressed: _noop,
                  ),
                  const SizedBox(height: 10),
                  const MileafButton(
                    label: '不可用',
                    kind: MileafButtonKind.secondary,
                    onPressed: null,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      StatusChip(label: '里程', selected: true),
                      StatusChip(label: '禁用', enabled: false),
                      StatusChip(label: '近7天'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: const [
                      MileafIconButton(
                        icon: MileafIconName.refresh,
                        tooltip: '刷新',
                        onPressed: _noop,
                      ),
                      MileafIconButton(
                        icon: MileafIconName.settings,
                        tooltip: '设置',
                        selected: true,
                        onPressed: _noop,
                      ),
                      MileafIconButton(
                        icon: MileafIconName.close,
                        tooltip: '不可用',
                        onPressed: null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('图形组件', style: context.type.title),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      BatteryArc(level: 68),
                      SizedBox(width: 16),
                      BatteryArc(level: null),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SocIntervalBar(start: 68, end: 82),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      MileafShareRing(
                        segments: [
                          ShareRingSegment(
                            label: 'AC',
                            value: 62,
                            color: Color(0xFF2688F5),
                          ),
                          ShareRingSegment(
                            label: 'DC',
                            value: 38,
                            color: Color(0xFF0B62C4),
                          ),
                        ],
                        centerValue: '62',
                        centerLabel: 'AC',
                        size: 104,
                      ),
                    ],
                  ),
                  ShareRingLegendRow(
                    color: const Color(0xFF2688F5),
                    label: 'AC 交流',
                    share: '62%',
                    onTap: _noop,
                  ),
                  const ShareRingLegendRow(
                    color: Color(0xFF0B62C4),
                    label: 'DC 直流',
                    share: '38%',
                  ),
                  const SizedBox(height: 20),
                  Text('弹层框架', style: context.type.title),
                  const SizedBox(height: 12),
                  MileafSheetFrame(
                    title: '外观',
                    onClose: _noop,
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MileafDataRow(title: '跟随系统', selected: true),
                        MileafDataRow(title: '浅色'),
                        MileafDataRow(title: '深色', bottomLine: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('底栏', style: context.type.title),
                  const SizedBox(height: 12),
                  // 底栏预览：固定高度组件可直接内嵌，选中标记与实色可查。
                  ClipRect(child: MileafNavBar(index: 0, onSelected: (_) {})),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 真实键盘焦点探测：渲染后由测试发送 Tab，焦点按钮画出 2px 外环。
class _FocusSection extends StatelessWidget {
  const _FocusSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('焦点（键盘可达，即时 2px 外环）', style: context.type.title),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: const [
              MileafButton(label: '焦点按钮', onPressed: _noop),
              StatusChip(label: '焦点 chip', selected: true),
              MileafIconButton(
                icon: MileafIconName.settings,
                tooltip: '焦点图标',
                onPressed: _noop,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _noop() {}
