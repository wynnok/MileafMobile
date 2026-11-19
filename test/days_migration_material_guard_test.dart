import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// MG07 材质三分守卫（days-matter-migration）：玻璃材质只进 Chrome 层。
///
/// components/ 下除四个 Chrome 持有文件外，禁止 import 玻璃/磨砂材质
/// （glass_surface.dart、navigation_material.dart）或直接引用玻璃类型
/// （MileafGlassSurface / MileafGlassLens / NavigationMaterial）。
/// Chrome 持有文件：底栏（nav_bar）、顶栏（top_bar 的镜片控件）、二级导航
/// 磨砂（page_bar）、材质定义与解析（glass_surface、navigation_material）、
/// barrel 转发导出（components.dart）。
/// workspace_page.dart 属外壳（Chrome），不在内容层扫描集内。
void main() {
  const chromeFiles = {
    'glass_surface.dart',
    'navigation_material.dart',
    'nav_bar.dart',
    'top_bar.dart',
    'page_bar.dart', // R14/R26 二级导航磨砂，Chrome 层
    'components.dart', // barrel 转发导出，非消费
  };
  const glassImports = ['glass_surface.dart', 'navigation_material.dart'];
  const glassTypes = [
    'MileafGlassSurface',
    'MileafGlassLens',
    'NavigationMaterial',
    'LiquidGlass',
  ];

  List<String> contentComponents() {
    final dir = Directory('lib/src/design/components');
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
        .map((f) => f.path)
        .where((p) => !chromeFiles.contains(p.split('/').last))
        .toList()
      ..sort();
  }

  test('内容层组件不 import 玻璃材质', () {
    final problems = <String>[];
    for (final path in contentComponents()) {
      final source = File(path).readAsStringSync();
      for (final glass in glassImports) {
        if (source.contains("import") && source.contains(glass)) {
          problems.add('$path import 了 $glass');
        }
      }
    }
    expect(problems, isEmpty, reason: '玻璃只允许出现在 Chrome 层：$problems');
  });

  test('内容层组件不直接引用玻璃类型', () {
    final problems = <String>[];
    for (final path in contentComponents()) {
      final source = File(path).readAsStringSync();
      for (final type in glassTypes) {
        if (source.contains(type)) {
          problems.add('$path 引用了 $type');
        }
      }
    }
    expect(problems, isEmpty, reason: '内容层用 surface/canvas 分层，不用玻璃：$problems');
  });

  test('Chrome 持有文件存在（扫描排除集与现状一致）', () {
    for (final name in chromeFiles) {
      expect(
        File('lib/src/design/components/$name').existsSync(),
        isTrue,
        reason: '排除集里的 $name 应真实存在；文件改名时同步本守卫',
      );
    }
  });
}
