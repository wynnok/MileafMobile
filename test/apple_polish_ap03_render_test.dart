// AP03 控件图板：AQ02 的八种状态、浅深、100/200%、320/390/768 机位。
// opt-in：未设置 MILEAF_RENDER_OUTPUT / MILEAF_RENDER_FONT 时跳过。
// 正式渲染见交付手册 §5；输出目录 docs/implementation/apple-polish-renders/AP03。
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

const output = String.fromEnvironment('MILEAF_RENDER_OUTPUT');
const fontPath = String.fromEnvironment('MILEAF_RENDER_FONT');

/// 字体身份：crypto 不是本项目的依赖（R32「依赖 0 变更」），这里用 32 位
/// FNV-1a 记录同一份字体文件的可比对指纹。
String _fontFingerprint(List<int> bytes) {
  var hash = 0x811C9DC5;
  for (final byte in bytes) {
    hash = ((hash ^ byte) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

MileafTextStyles _type(Brightness brightness) => MileafTextStyles.resolve(
  brightness == Brightness.dark
      ? const MileafColors.dark()
      : const MileafColors.light(),
);

Widget _scaffold(Brightness brightness, Widget child) => MaterialApp(
  theme: mileafTheme(brightness),
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: child,
    ),
  ),
);

/// 图板 1：分段与期间行（默认、选中、禁用、2×2 重排、期间行）。
Widget _segmentsBoard(Brightness brightness) {
  final t = _type(brightness);
  return _scaffold(
    brightness,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('行笺 · 分段与期间行', style: t.title2),
        const SizedBox(height: 4),
        Text('R27 胶囊轨道 40 / 选中底 36（AP03）', style: t.subheadline),
        const SizedBox(height: 16),
        ChipRow(
          children: [
            StatusChip(label: '里程', selected: true, onTap: () {}),
            StatusChip(label: '电耗', onTap: () {}),
            StatusChip(label: '补能', onTap: () {}),
          ],
        ),
        const SizedBox(height: 12),
        ChipRow(
          children: [
            StatusChip(label: '近30天', onTap: () {}),
            StatusChip(label: '近7天', onTap: () {}),
            StatusChip(label: '自定义', selected: true, onTap: () {}),
            StatusChip(label: '禁用', enabled: false, onTap: () {}),
          ],
        ),
        const SizedBox(height: 12),
        ChipRow(
          equalWidth: true,
          children: [
            StatusChip(label: '里程', onTap: () {}),
            StatusChip(label: '电耗', selected: true, onTap: () {}),
            StatusChip(label: '补能', onTap: () {}),
            StatusChip(label: '费用', onTap: () {}),
          ],
        ),
        const SizedBox(height: 16),
        Text('期间行（分段占剩余宽度 + 行尾刷新圆钮）', style: t.groupTitle),
        const SizedBox(height: 8),
        MileafPeriodRow(
          trailing: MileafIconButton(
            icon: MileafIconName.refresh,
            tooltip: '刷新概览',
            fill: MileafIconButtonFill.track,
            onPressed: () {},
          ),
          children: [
            StatusChip(label: '本月', selected: true, onTap: () {}),
            StatusChip(label: '近7天', onTap: () {}),
          ],
        ),
      ],
    ),
  );
}

/// 图板 2：按钮、图标圆钮与下拉（默认、处理中、禁用、危险、选中）。
Widget _controlsBoard(Brightness brightness) {
  final t = _type(brightness);
  return _scaffold(
    brightness,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('行笺 · 按钮与圆钮', style: t.title2),
        const SizedBox(height: 4),
        Text('R27 主次按钮 50、文字按钮、圆钮 36 / 命中 44（AP03）', style: t.subheadline),
        const SizedBox(height: 16),
        MileafButton(label: '确认补录', expand: true, onPressed: () {}),
        const SizedBox(height: 12),
        MileafButton(
          label: '正在处理',
          expand: true,
          loading: true,
          onPressed: () {},
        ),
        const SizedBox(height: 12),
        MileafButton(
          label: '取消',
          expand: true,
          kind: MileafButtonKind.secondary,
          onPressed: () {},
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MileafButton(
              label: '查看全部',
              kind: MileafButtonKind.ghost,
              onPressed: () {},
            ),
            MileafButton(
              label: '清除 Key',
              kind: MileafButtonKind.ghost,
              destructive: true,
              onPressed: () {},
            ),
            MileafButton(label: '不可用', onPressed: null),
          ],
        ),
        const SizedBox(height: 20),
        Text('图标圆钮：无填充 / segmentTrack / 选中 / 禁用', style: t.groupTitle),
        const SizedBox(height: 8),
        Row(
          children: [
            MileafIconButton(
              icon: MileafIconName.expand,
              tooltip: '展开',
              onPressed: () {},
            ),
            const SizedBox(width: 12),
            MileafIconButton(
              icon: MileafIconName.refresh,
              tooltip: '刷新',
              fill: MileafIconButtonFill.track,
              onPressed: () {},
            ),
            const SizedBox(width: 12),
            MileafIconButton(
              icon: MileafIconName.settings,
              tooltip: '设置',
              selected: true,
              onPressed: () {},
            ),
            const SizedBox(width: 12),
            MileafIconButton(icon: MileafIconName.more, tooltip: '更多'),
          ],
        ),
        const SizedBox(height: 20),
        Text('小胶囊下拉', style: t.groupTitle),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            MileafPullDown<String>(
              label: '类型',
              value: 'all',
              onChanged: (_) {},
              options: const [
                MileafPullDownOption(value: 'all', label: '全部类型'),
                MileafPullDownOption(value: 'ac', label: 'AC'),
              ],
            ),
            MileafPullDown<String>(
              label: '排序',
              value: 'recent',
              onChanged: (_) {},
              options: const [
                MileafPullDownOption(value: 'recent', label: '最近结束'),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

/// 图板 3：选择列表与两种弹层（浮动 / 贴边）。
Widget _sheetsBoard(Brightness brightness) {
  final t = _type(brightness);
  final colors = brightness == Brightness.dark
      ? const MileafColors.dark()
      : const MileafColors.light();
  return _scaffold(
    brightness,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('行笺 · 选择与弹层', style: t.title2),
        const SizedBox(height: 4),
        Text('R27 选择只勾选；R28 浮动 / 贴边（AP03）', style: t.subheadline),
        const SizedBox(height: 16),
        Text('选择列表', style: t.groupTitle),
        const SizedBox(height: 8),
        Material(
          color: colors.surface,
          borderRadius: MileafRadius.lgTop,
          child: MileafSelectionList<String>(
            semanticLabel: '币种',
            value: 'cny',
            onChanged: (_) {},
            showDividers: true,
            options: const [
              MileafSelectionOption(value: 'cny', label: '人民币（CNY）'),
              MileafSelectionOption(
                value: 'usd',
                label: '美元（USD）',
                subtitle: '按站点账本显示',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('浮动弹层（左右下各留 8、四角 28）', style: t.groupTitle),
        const SizedBox(height: 8),
        SizedBox(
          height: 240,
          child: MileafSheetFrame(
            title: '选择车辆',
            style: MileafSheetStyle.floating,
            onClose: () {},
            child: MileafSelectionList<String>(
              value: 'a',
              onChanged: (_) {},
              options: const [
                MileafSelectionOption(value: 'a', label: '行笺测试车'),
                MileafSelectionOption(value: 'b', label: '白露'),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// 图板 4：日期区间弹层（折叠两行 + 脚注 + 应用）。
Widget _dateBoard(Brightness brightness) => _scaffold(
  brightness,
  SizedBox(
    height: 420,
    child: MileafSheetFrame(
      title: '选择日期',
      style: MileafSheetStyle.edge,
      onClose: () {},
      child: MileafDateRangeSheet(
        initialRange: DateTimeRange(
          start: DateTime(2026, 9, 28),
          end: DateTime(2026, 10, 26),
        ),
        firstDate: DateTime(2024, 1, 1),
        lastDate: DateTime(2026, 11, 17),
        today: DateTime(2026, 11, 17),
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    if (fontPath.isNotEmpty) await loadRenderFonts(cjkFontPath: fontPath);
  });

  testWidgets('AP03 control boards', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    tester.view.devicePixelRatio = 1;
    final boundary = GlobalKey();
    final files = <String>[];
    final boards = <String, Widget Function(Brightness)>{
      'segments': _segmentsBoard,
      'controls': _controlsBoard,
      'sheets': _sheetsBoard,
      'date': _dateBoard,
    };
    final shots = <({String name, double width, double height, double scale})>[
      (name: 'tel', width: 390, height: 844, scale: 1),
      (name: 'tel-large', width: 390, height: 844, scale: 2),
      (name: 'compact', width: 320, height: 568, scale: 1),
      (name: 'wide', width: 768, height: 1024, scale: 2),
    ];
    for (final entry in boards.entries) {
      for (final brightness in Brightness.values) {
        for (final shot in shots) {
          tester.view.physicalSize = Size(shot.width, shot.height);
          tester.platformDispatcher.textScaleFactorTestValue = shot.scale;
          await tester.pumpWidget(
            RepaintBoundary(key: boundary, child: entry.value(brightness)),
          );
          // 控件图板含"处理中"状态（无限旋转的活动指示器），不能 pumpAndSettle；
          // 固定推进两帧让选中过渡与阴影落到终态。
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          final board = entry.key;
          final mode = brightness.name;
          final w = shot.width.round();
          final h = shot.height.round();
          final size = [w, h].join('x');
          final tag = (shot.scale * 100).round().toString();
          final parts = [
            'AP03',
            board,
            'default',
            mode,
            size,
            tag,
            'top',
          ].join('-');
          final name = '$parts.png';
          await saveRenderPng(
            tester,
            find.byKey(boundary),
            '$output/$name',
            settle: false,
          );
          files.add(name);
        }
      }
    }
    final fontBytes = File(fontPath).readAsBytesSync();
    File('$output/manifest.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'input_sha': 'c18f2fc',
        'input_freeze': 'FP1',
        'ticket': 'AP03',
        'fixture':
            'shared controls: segments, period row, buttons, icon buttons, '
            'pull-down, selection list, sheets, date range',
        'timezone': 'Asia/Shanghai',
        'font': fontPath,
        'font_fingerprint_fnv1a32': _fontFingerprint(fontBytes),
        'logical_size': ['390x844', '320x568', '768x1024'],
        'pixel_ratio': 2,
        'text_scales': ['100', '200'],
        'material': 'default',
        'images': files,
      }),
    );
  }, skip: output.isEmpty || fontPath.isEmpty);
}
