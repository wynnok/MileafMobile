import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 玻璃层职责守卫（ADR 0019 / VH17）。
///
/// 内容卡与控件只使用固定色面光学，背景取样集中于顶栏和浮层。
void main() {
  const chromeFiles = {
    'glass_surface.dart',
    'navigation_material.dart',
    'nav_bar.dart',
    'top_bar.dart',
    'page_bar.dart', // R14/R26 二级导航磨砂，Chrome 层
    'components.dart', // barrel 转发导出，非消费
    'pull_down.dart', // CL30/CL31：浮层菜单玻璃，浮层不是内容层
    'sheet.dart', // 仅浮动选择器使用有界背景取样
    'battery_arc.dart', // 仅概览车况的电量仪表镜片
  };
  const tintFiles = {
    'module.dart',
    'button.dart',
    'icon_button.dart',
    'chip_row.dart',
  };
  const glassImports = ['glass_surface.dart', 'navigation_material.dart'];
  const glassTypes = [
    'MileafGlassSurface',
    'MileafGlassLens',
    'NavigationMaterial',
    'LiquidGlass',
  ];

  /// CL32（ADR 0016）：玻璃的允许集是「Chrome + 浮层」，不是「只有 components/」。
  /// 页面级浮层（地图浮控）与外壳（工作区）也在允许集里，其余**全库**扫描。
  const floatingOrChrome = {
    'map_panel.dart', // CL30：地图四枚浮控的玻璃垫
    'semantic.dart', // 玻璃 token 的解析出口
  };

  Iterable<String> allSources() =>
      Directory('lib/src')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
          .map((f) => f.path)
          .toList()
        ..sort();

  List<String> contentComponents() => allSources()
      .where((p) => p.startsWith('lib/src/design/components/'))
      .where((p) => !chromeFiles.contains(p.split('/').last))
      .toList();

  /// 全库扫描：除 Chrome/浮层允许集之外，任何文件都不得引用玻璃。
  List<String> contentEverywhere() => allSources()
      .where((p) => !chromeFiles.contains(p.split('/').last))
      .where((p) => !floatingOrChrome.contains(p.split('/').last))
      .toList();

  test('固定色面之外的内容组件不 import 玻璃材质', () {
    final problems = <String>[];
    for (final path in contentComponents()) {
      final source = File(path).readAsStringSync();
      for (final glass in glassImports) {
        if (glass == 'glass_surface.dart' &&
            tintFiles.contains(path.split('/').last)) {
          continue;
        }
        if (source.contains("import") && source.contains(glass)) {
          problems.add('$path import 了 $glass');
        }
      }
    }
    expect(problems, isEmpty, reason: '内容层仅指定组件可使用固定色面：$problems');
  });

  test('CL32 全库扫描：内容层页面也不得引用玻璃（扫描范围不止 components/）', () {
    final problems = <String>[];
    for (final path in contentEverywhere()) {
      if (path.startsWith('lib/src/design/components/')) continue;
      final source = File(path).readAsStringSync();
      for (final glass in [...glassImports, ...glassTypes, 'BackdropFilter']) {
        if (source.contains(glass)) problems.add('$path 引用了 $glass');
      }
    }
    expect(
      problems,
      isEmpty,
      reason: 'CL32：玻璃只允许出现在底栏/顶栏/二级导航/浮层菜单/地图浮控：$problems',
    );
  });

  test('内容层组件只允许固定色面光学', () {
    final problems = <String>[];
    for (final path in contentComponents()) {
      final source = File(path).readAsStringSync();
      final checked = tintFiles.contains(path.split('/').last)
          ? source.replaceAll('MileafGlassSurface.tinted(', '')
          : source;
      for (final type in [...glassTypes, 'BackdropFilter']) {
        if (checked.contains(type)) {
          problems.add('$path 引用了 $type');
        }
      }
    }
    expect(problems, isEmpty, reason: '内容层不得取样背后内容：$problems');
  });

  test('Chrome 持有文件存在（扫描排除集与现状一致）', () {
    for (final name in {...chromeFiles, ...tintFiles}) {
      expect(
        File('lib/src/design/components/$name').existsSync(),
        isTrue,
        reason: '排除集里的 $name 应真实存在；文件改名时同步本守卫',
      );
    }
  });
}
