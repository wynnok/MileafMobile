// AP14 集成收口守卫（R22 旧别名删除、R24 弃用间距删除、R32 裸值归零、
// AQ08 文案内容检查全局扩展、ADR0012 Q08 每 route blur 区域数登记）。
//
// 口径说明（D-AP08-01 裁定记录见 AP14.md）：页面级文案留在页面文件，
// 守卫基线只降不升；本票把 CP09 1–4 内容检查扩展到 copy 库以外的全部
// 源文件并归零，渲染树 probe 沿用 copy_probe（AP12a/AP12b 既有用例）。
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/tokens.dart';
import 'package:mileaf/src/design/typography.dart';

import 'package:flutter/services.dart';

import 'package:mileaf/src/design/components/battery_arc.dart';
import 'package:mileaf/src/design/components/state_view.dart';
import 'package:mileaf/src/design/theme.dart';

import 'support/copy_probe.dart';

/// lib 下全部 Dart 源文件（含设计层；生成契约除外）。
List<String> allLibFiles() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
        .map((f) => f.path)
        .toList()
      ..sort();

/// 行号定位前缀：path:line。
String at(String file, int line) => '$file:$line';

void doNothing() {}

void main() {
  group('R22 旧字体角色清理收口', () {
    test('lib 内不再引用旧尺寸常量与旧样式别名', () {
      final forbidden = <RegExp>[
        RegExp(
          r'MileafType\.(?:pageTitleSize|pageTitleHeight|navigationTitleSize|'
          r'navigationTitleHeight|titleSize|titleHeight|titleTracking|'
          r'labelSize|labelHeight|labelTracking|microSize|microHeight|'
          r'microTracking)\b',
        ),
        RegExp(r'(?:type|styles)\.pageTitle\b'),
        RegExp(r'(?:type|styles)\.navigationTitle\b'),
        RegExp(r'(?:type|styles)\.bodyStrong\b'),
        RegExp(r'(?:type|styles)\.title\b'),
        RegExp(r'(?:type|styles)\.label\b'),
        RegExp(r'(?:type|styles)\.micro\b'),
      ];
      final problems = <String>[];
      for (final file in allLibFiles()) {
        final lines = File(file).readAsStringSync().split('\n');
        for (var i = 0; i < lines.length; i++) {
          for (final pattern in forbidden) {
            if (pattern.hasMatch(lines[i])) {
              problems.add('${at(file, i + 1)} ${lines[i].trim()}');
            }
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });

  group('R24 弃用间距清理收口', () {
    test('lib 内不再引用 inline6/inline10/s18/s40/s56', () {
      final pattern = RegExp(
        r'MileafSpace\.(?:inline6|inline10|s18|s40|s56)\b',
      );
      final problems = <String>[];
      for (final file in allLibFiles()) {
        final lines = File(file).readAsStringSync().split('\n');
        for (var i = 0; i < lines.length; i++) {
          if (pattern.hasMatch(lines[i])) {
            problems.add('${at(file, i + 1)} ${lines[i].trim()}');
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });

  group('Material TextTheme 映射（R22 收口）', () {
    test('内置组件样式映射到新角色，不再出现旧 title 20/28', () {
      final textTheme = MileafTextStyles.resolve(const MileafColors.light())
          .materialTheme(const MileafColors.light());
      expect(textTheme.headlineSmall!.fontSize, MileafType.headlineSize);
      expect(textTheme.titleLarge!.fontSize, MileafType.title2Size);
      expect(textTheme.titleMedium!.fontSize, MileafType.headlineSize);
      expect(textTheme.bodySmall!.fontSize, MileafType.footnoteSize);
      expect(textTheme.labelLarge!.fontSize, MileafType.controlSize);
      expect(textTheme.labelSmall!.fontSize, MileafType.captionSize);
      final sizes = <TextStyle?>[
        textTheme.displayLarge,
        textTheme.displayMedium,
        textTheme.displaySmall,
        textTheme.headlineLarge,
        textTheme.headlineMedium,
        textTheme.headlineSmall,
        textTheme.titleLarge,
        textTheme.titleMedium,
        textTheme.titleSmall,
        textTheme.bodyLarge,
        textTheme.bodyMedium,
        textTheme.bodySmall,
        textTheme.labelLarge,
        textTheme.labelMedium,
        textTheme.labelSmall,
      ].whereType<TextStyle>().map((s) => s.fontSize).toList();
      for (final size in sizes) {
        expect(size, isNot(20), reason: '旧 title 20/28 应彻底退场');
      }
    });
  });

  group('R32 裸值守卫全局归零', () {
    test('lib（设计层外）四种裸值总数为 0', () {
      final patterns = <String, RegExp>{
        'fontSize': RegExp(r'fontSize:\s*[0-9.]'),
        'color0x': RegExp(r'Color\(0x[0-9A-Fa-f]'),
        'durationMilliseconds': RegExp(r'Duration\(milliseconds:\s*[0-9]'),
        'radiusCircular': RegExp(r'Radius\.circular\([0-9.]'),
      };
      final problems = <String>[];
      var total = 0;
      for (final file in allLibFiles()) {
        if (file.contains('/design/') || file.endsWith('.g.dart')) continue;
        final source = File(file).readAsStringSync();
        for (final entry in patterns.entries) {
          final count = entry.value.allMatches(source).length;
          total += count;
          if (count > 0) {
            problems.add('$file ${entry.key}=$count');
          }
        }
      }
      expect(total, 0, reason: problems.join('\n'));
    });
  });

  group('AQ08 CP09 内容检查全局扩展', () {
    test('copy 库以外的全部源文件无 CP09 1–4 违规', () {
      final problems = <String>[];
      for (final file in appSourceFiles()) {
        if (file.startsWith('lib/src/copy/')) continue;
        final lines = File(file).readAsStringSync().split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.contains('// copy-guard: technical')) continue;
          for (final lit in chineseLiterals(line)) {
            // 插值表达式内的标识符不进入渲染文本，检查前剔除。
            final rendered = lit.replaceAll(RegExp(r'\$\{[^}]*\}'), '{}');
            final where = at(file, i + 1);
            if (copyGuardViolationDotJoin(lit)) {
              problems.add('$where CP09.1 点号拼接: $lit');
            }
            if (copyGuardViolationUnitLabel(lit)) {
              problems.add('$where CP09.2 单位当标签: $lit');
            }
            if (copyGuardViolationTechnicalToken(rendered)) {
              problems.add('$where CP09.3 技术词: $lit');
            }
            if (copyGuardViolationSymbolSubstitute(lit)) {
              problems.add('$where CP09.4 符号代替词: $lit');
            }
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });

  group('D-AP08-03 状态动作的读屏对象名', () {
    testWidgets('StateView 动作按钮带完整对象名语义', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(Brightness.light),
          home: const Center(
            child: StateView(
              kind: StateViewKind.error,
              title: '读取失败',
              actionLabel: '重试',
              actionSemanticLabel: '重试读取概览',
              onAction: doNothing,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('重试读取概览'), findsOneWidget);
    });

    testWidgets('InlineBanner 动作按钮带完整对象名语义', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(Brightness.light),
          home: const Center(
            child: InlineBanner(
              message: '刷新失败，已保留旧数据',
              tone: BannerTone.error,
              actionLabel: '重试',
              actionSemanticLabel: '重试读取充电数据',
              onAction: doNothing,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('重试读取充电数据'), findsOneWidget);
    });
  });

  group('D-AP08-05 电量弧 130% 环内紧贴', () {
    Future<void> pumpArc(WidgetTester tester, double scale) async {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: MaterialApp(
            theme: mileafTheme(Brightness.light),
            home: const Center(
              child: BatteryArc(level: 68, label: '电量', showLabel: false),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    setUpAll(() async {
      // 用随包发布的 Inter 实字宽，避免 Ahem 方块把宽度测假。
      final loader = FontLoader('Inter');
      loader.addFont(rootBundle.load('assets/fonts/Inter-Regular.ttf'));
      loader.addFont(rootBundle.load('assets/fonts/Inter-Medium.ttf'));
      loader.addFont(rootBundle.load('assets/fonts/Inter-SemiBold.ttf'));
      await loader.load();
    });

    testWidgets('130% 下数值与 % 同行紧贴，不拆成上下两行', (tester) async {
      await pumpArc(tester, 1.3);
      final valueTop = tester.getTopLeft(find.text('68')).dy;
      final unitTop = tester.getTopLeft(find.text('%')).dy;
      expect(
        (unitTop - valueTop).abs(),
        lessThan(10),
        reason: 'R29：环内只放数值与紧贴的 %；130% 不得把 % 挪到下一行',
      );
    });

    testWidgets('100% 下同样同行紧贴', (tester) async {
      await pumpArc(tester, 1.0);
      final valueTop = tester.getTopLeft(find.text('68')).dy;
      final unitTop = tester.getTopLeft(find.text('%')).dy;
      expect(
        (unitTop - valueTop).abs(),
        lessThan(10),
        reason: '同行基线对齐（字号差带来 ~2px 顶差），拆行会到 ~24px',
      );
    });
  });

  group('ADR0012 Q08 每 route blur 区域数', () {
    test('玻璃区域只在外壳材质内，源码级计数不回增', () {
      final expected = <String, int>{
        'lib/src/design/components/glass_surface.dart': 1,
        'lib/src/design/components/navigation_material.dart': 1,
      };
      final problems = <String>[];
      for (final entry in expected.entries) {
        final source = File(entry.key).readAsStringSync();
        final count = RegExp(r'BackdropFilter\(').allMatches(source).length;
        if (count != entry.value) {
          problems.add('${entry.key} BackdropFilter=$count');
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });
}
