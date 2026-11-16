// AP01 证据渲染：角色图板与图标图板（浅深 × 100/200%）。
// opt-in：未设置 MILEAF_RENDER_OUTPUT / MILEAF_RENDER_FONT 时跳过。
// 正式渲染见交付手册 §5；输出目录 docs/implementation/apple-polish-renders/AP01。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/icons.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/tokens.dart';
import 'package:mileaf/src/design/typography.dart';

import 'support/render_fonts.dart';
import 'support/render_png.dart';

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

List<(String, String, TextStyle)> _roleRows(MileafTextStyles t) => [
  ('display', '407 km', t.display),
  ('metricLg', '407 km', t.metricLg),
  ('metricMd', '407 km', t.metricMd),
  ('metricSm', '407 km', t.metricSm),
  ('largeTitle', '概览', t.largeTitle),
  ('title2', '本期驾驶', t.title2),
  ('headline', '充电中', t.headline),
  ('body', '行笺 · TeslaMate 阅读器', t.body),
  ('subheadline', '字段名与元信息', t.subheadline),
  ('groupTitle（分组标题 500）', '本月 · 分组', t.groupTitle),
  ('control', '分段', t.control),
  ('controlSelected（选中 600）', '分段', t.controlSelected),
  ('footnote', '限定语与页尾脚注', t.footnote),
  ('caption', '图轴刻度', t.caption),
  ('navLabel', '概览', t.navLabel),
  ('title（过渡别名）', '区块标题', t.title),
  ('label（过渡别名）', '字段名', t.label),
  ('micro（过渡别名）', '元信息', t.micro),
  ('pageTitle（过渡别名）', '概览', t.pageTitle),
  ('navigationTitle（过渡别名）', '行程', t.navigationTitle),
  ('bodyStrong（过渡别名）', '设置行标题', t.bodyStrong),
];

Widget _roleBoard(Brightness brightness) {
  final colors = brightness == Brightness.dark
      ? const MileafColors.dark()
      : const MileafColors.light();
  final t = MileafTextStyles.resolve(colors);
  return MaterialApp(
    theme: mileafTheme(brightness),
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          Text('行笺 · 字体角色表', style: t.title2),
          const SizedBox(height: 4),
          Text('R22 新角色与过渡别名（AP01）', style: t.subheadline),
          const SizedBox(height: 16),
          for (final (role, sample, style) in _roleRows(t))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  SizedBox(width: 168, child: Text(role, style: t.caption)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(sample, style: style)),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

Widget _iconBoard(Brightness brightness) {
  final colors = brightness == Brightness.dark
      ? const MileafColors.dark()
      : const MileafColors.light();
  final t = MileafTextStyles.resolve(colors);
  return MaterialApp(
    theme: mileafTheme(brightness),
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          Text('行笺 · 自绘图标', style: t.title2),
          const SizedBox(height: 4),
          Text('R32 25 个关键图标 · 24 网格 1.5 描边（AP01）', style: t.subheadline),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final name in MileafIconName.values)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MileafIcon(
                      name,
                      size: MileafIconMetrics.header,
                      color: colors.text,
                    ),
                    const SizedBox(height: 6),
                    Text(name.name, style: t.caption),
                  ],
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    if (fontPath.isNotEmpty) await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('AP01 roles and icons boards', (tester) async {
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
          RepaintBoundary(key: boundary, child: _roleBoard(brightness)),
        );
        await tester.pumpAndSettle();
        final mode = brightness.name;
        final tag = (scale * 100).round().toString();
        final roles = 'AP01-roles-normal-$mode-390x844-$tag-top.png';
        await saveRenderPng(tester, find.byKey(boundary), '$output/$roles');
        files.add(roles);
        await tester.pumpWidget(
          RepaintBoundary(key: boundary, child: _iconBoard(brightness)),
        );
        await tester.pumpAndSettle();
        final icons = 'AP01-icons-normal-$mode-390x844-$tag-top.png';
        await saveRenderPng(tester, find.byKey(boundary), '$output/$icons');
        files.add(icons);
      }
    }
    File('$output/manifest.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'input_sha': '7cf8dd4',
        'ticket': 'AP01',
        'fixture':
            'typography roles + 25 icons (design layer, no business data)',
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
