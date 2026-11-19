import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// MG07 材质三分守卫（days-matter-migration）：玻璃材质只进 Chrome 层。
///
/// components/ 下除四个 Chrome 持有文件外，禁止 import 玻璃/磨砂材质
/// （glass_surface.dart、navigation_material.dart）或直接引用玻璃类型
/// （MileafGlassSurface / MileafGlassLens / NavigationMaterial）。
/// Chrome 持有文件：底栏（nav_bar）、顶栏（top_bar 的镜片控件）、二级导航
/// 磨砂（page_bar）、材质定义与解析（glass_surface、navigation_material）、
/// barrel 转发导出（components.dart）、浮层菜单（pull_down，CL30/CL31 起）。
///
/// CL30 把玻璃扩到「浮层菜单」与「地图浮控」两处（ADR 0016 D6）：这两层压在
/// 页面之上，模糊作用于背后内容；内容卡片/列表/图表仍然平涂（CL32 不变）。
/// workspace_page.dart 属外壳（Chrome），不在内容层扫描集内。
void main() {
  const chromeFiles = {
    'glass_surface.dart',
    'navigation_material.dart',
    'nav_bar.dart',
    'top_bar.dart',
    'page_bar.dart', // R14/R26 二级导航磨砂，Chrome 层
    'components.dart', // barrel 转发导出，非消费
    'pull_down.dart', // CL30/CL31：浮层菜单玻璃，浮层不是内容层
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
