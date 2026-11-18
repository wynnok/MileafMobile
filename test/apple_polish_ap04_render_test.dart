// AP04 证据渲染：内容组件图板（浅深 × 100/200%）。
// opt-in：未设置 MILEAF_RENDER_OUTPUT / MILEAF_RENDER_FONT 时跳过。
// 正式渲染见交付手册 §5；输出目录 docs/implementation/apple-polish-renders/AP04。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/icons.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/tokens.dart';
import 'package:mileaf/src/design/typography.dart';

import 'support/render_fonts.dart';
import 'support/render_png.dart';

const renderOutput = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const renderFontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

TextStyle _bodyStyle(Brightness brightness) => MileafTextStyles.resolve(
  brightness == Brightness.dark
      ? const MileafColors.dark()
      : const MileafColors.light(),
).body;

Widget _sectionTitle(String text) => Builder(
  builder: (context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(text, style: context.type.groupTitle),
  ),
);

Widget _componentsBoard(Brightness brightness) => MaterialApp(
  theme: mileafTheme(brightness),
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('模块卡与网格'),
          MileafModuleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const MetricGrid(
                  children: [
                    MetricBlock(label: '行程数', value: '52', unit: '次'),
                    MetricBlock(label: '电耗', value: '154', unit: 'Wh/km'),
                  ],
                ),
                const SizedBox(height: 16),
                const MetricGrid(
                  columns: 3,
                  children: [
                    MetricBlock(
                      label: '里程',
                      value: '60.0',
                      unit: 'km',
                      scale: MetricValueScale.metricSm,
                    ),
                    MetricBlock(
                      label: '电耗',
                      value: '11.25',
                      unit: 'kWh',
                      scale: MetricValueScale.metricSm,
                    ),
                    MetricBlock(
                      label: '次数',
                      value: '3',
                      unit: '趟',
                      scale: MetricValueScale.metricSm,
                    ),
                  ],
                ),
              ],
            ),
          ),
          _sectionTitle('分组标题与分组行'),
          const MileafGroupHeader(title: '设置'),
          const SizedBox(height: 8),
          MileafGroupCard(
            child: Column(
              children: [
                MileafGroupRow(
                  title: '地图',
                  leading: MileafIconName.mapPin,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('未配置', style: _bodyStyle(brightness)),
                      const SizedBox(width: 4),
                      const MileafIcon(
                        MileafIconName.chevron,
                        size: MileafIconMetrics.inline,
                      ),
                    ],
                  ),
                  bottomLine: true,
                  onTap: () {},
                ),
                MileafGroupRow(
                  title: '外观',
                  leading: MileafIconName.moon,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('跟随系统', style: _bodyStyle(brightness)),
                      const SizedBox(width: 4),
                      const MileafIcon(
                        MileafIconName.chevron,
                        size: MileafIconMetrics.inline,
                      ),
                    ],
                  ),
                  bottomLine: true,
                  onTap: () {},
                ),
                MileafGroupRow(
                  title: '站点连接',
                  meta: 'mileaf.example.com',
                  leading: MileafIconName.settings,
                  onTap: () {},
                ),
              ],
            ),
          ),
          _sectionTitle('数值与单位（永不拆行）'),
          const MileafModuleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MileafNumber(
                  value: '320',
                  unit: 'km',
                  scale: MetricValueScale.display,
                ),
                SizedBox(height: 8),
                MileafNumber(
                  value: '1,198.6',
                  unit: 'km',
                  scale: MetricValueScale.metricLg,
                ),
                SizedBox(height: 8),
                MileafNumber(
                  value: '46.8',
                  unit: 'kWh',
                  scale: MetricValueScale.metricMd,
                ),
                SizedBox(height: 8),
                MileafNumber(
                  value: '154',
                  unit: 'Wh/km',
                  scale: MetricValueScale.metricSm,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const MileafDataNotes(
            groups: [
              MileafDataNoteGroup(
                category: DataNoteCategory.caliber,
                note: '净电耗与驾驶消耗为估算。',
              ),
              MileafDataNoteGroup(
                category: DataNoteCategory.records,
                note: '缺失的费用不表示免费。',
              ),
              MileafDataNoteGroup(
                category: DataNoteCategory.time,
                note: '时间按站点日历本地化。',
              ),
              MileafDataNoteGroup(
                category: DataNoteCategory.source,
                note: '数据来自 Mileaf Server。',
              ),
              MileafDataNoteGroup(
                category: DataNoteCategory.technical,
                note: 'temperature-association-v1',
                copyable: true,
              ),
            ],
          ),
          _sectionTitle('车况卡'),
          const MileafHero(
            semanticLabel: '车况',
            child: Padding(
              padding: EdgeInsets.all(MileafSpace.cardPad),
              child: MileafNumber(
                value: '320',
                unit: 'km',
                scale: MetricValueScale.display,
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);

Widget _statesBoard(Brightness brightness) => MaterialApp(
  theme: mileafTheme(brightness),
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('整页状态'),
          const StateView(
            kind: StateViewKind.empty,
            title: '这段时间还没有行程',
            message: '换一个区间或下拉刷新',
            actionLabel: '重试',
          ),
          _sectionTitle('模块内状态'),
          const MileafModuleCard(
            child: StateView(
              kind: StateViewKind.error,
              title: '没能更新',
              message: '保留上次快照',
              compact: true,
            ),
          ),
          _sectionTitle('进行中与行内状态条'),
          const Align(
            alignment: Alignment.centerLeft,
            child: MileafRunningPill(),
          ),
          const SizedBox(height: 8),
          InlineBanner(
            message: '没能更新，显示的是 10:02 的数据',
            actionLabel: '重试',
            onAction: () {},
          ),
          _sectionTitle('折叠（展开态）'),
          MileafModuleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const MileafDisclosure(
                  label: '对照电量',
                  meta: '展开后显示第二张图',
                  emphasis: true,
                  child: Text('第二张图的说明'),
                ),
                const SizedBox(height: 8),
                MileafDisclosure(
                  key: const ValueKey('expanded'),
                  label: '采样数据说明',
                  expanded: true,
                  onExpandedChanged: (_) {},
                  child: Text('缺失值断线，不补点或补零。', style: _bodyStyle(brightness)),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    if (renderFontPath.isNotEmpty) {
      await loadRenderFonts(cjkFontPath: renderFontPath);
    }
  });

  testWidgets('AP04 component boards', (tester) async {
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
        final mode = brightness.name;
        final tag = (scale * 100).round().toString();
        for (final (board, builder) in [
          ('components', _componentsBoard),
          ('states', _statesBoard),
        ]) {
          await tester.pumpWidget(
            RepaintBoundary(key: boundary, child: builder(brightness)),
          );
          await tester.pumpAndSettle();
          final name = 'AP04-$board-normal-$mode-390x844-$tag-top.png';
          await saveRenderPng(
            tester,
            find.byKey(boundary),
            '$renderOutput/$name',
          );
          files.add(name);
        }
      }
    }
    File('$renderOutput/manifest.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'input_sha': 'c18f2fc',
        'ticket': 'AP04',
        'fixture': 'content components (cards, rows, numbers, notes, states)',
        'timezone': 'Asia/Shanghai',
        'font': renderFontPath,
        'logical_size': '390x844',
        'pixel_ratio': 2,
        'text_scales': ['100', '200'],
        'material': 'default',
        'images': files,
      }),
    );
  }, skip: renderOutput.isEmpty || renderFontPath.isEmpty);
}
