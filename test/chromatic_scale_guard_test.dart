import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/tokens.dart';

/// MC11（ADR 0016 / 规格 CL20–CL22）间距与半径档位守卫。
///
/// 只扫「间距 / 内边 / 圆角」这三类参数，不扫图形尺寸：
/// - 被扫：`SizedBox(height|width:)`、`spacing:`/`runSpacing:`、
///   `BorderRadius.circular()`、`Radius.circular()`、`EdgeInsets.all/
///   symmetric/only/fromLTRB(...)`。
/// - 不扫：`Container(height: 1)` 这类发丝线、`SkeletonBlock` 的占位形状、
///   `BorderSide(width:)`、图表几何常量——它们不是间距，管住它们只会制造噪声。
///
/// 允许值：间距 `MileafSpace.canonical`（2/4/8/12/16/20/24/32）；
/// 圆角 `MileafRadius` 的档位（0/4/10/12/20/24/28/999）。
/// 确实要保留的例外写 `// CL22-exempt: 理由`（本行或上一行），并登记到
/// docs/implementation/chromatic-language.md §「CL22 豁免」。
void main() {
  // 0 是「没有间距」，不是越级（RunSpacing: 0 这类显式贴合）。
  final spacing = {...MileafSpace.canonical.map((v) => v.toString()), '0'};
  const radiusText = <String>{'0', '4', '10', '12', '20', '24', '28', '999'};

  final sizedBox = RegExp(r'SizedBox\(\s*(?:height|width):\s*([0-9.]+)');
  // 一次给两个方向的 SizedBox（`SizedBox(width: x, height: 13)`）与
  // `SizedBox.square(dimension:)` 走这条，避免只查第一参数。
  final sizedBoxPair = RegExp(r'SizedBox\.square\(\s*dimension:\s*([0-9.]+)');
  final gaps = RegExp(r'\b(?:spacing|runSpacing):\s*([0-9.]+)');
  final borderRadius = RegExp(r'BorderRadius\.circular\(\s*([0-9.]+)');
  final radiusOnly = RegExp(r'(?<![A-Za-z])Radius\.circular\(\s*([0-9.]+)');
  final insets = RegExp(
    r'EdgeInsets\.(?:all|symmetric|only|fromLTRB)\(([^)]*)\)',
  );
  // 只认「裸数字」：`MileafSpace.s8`、`MileafRadius.md` 这类符号引用不算越级。
  final number = RegExp(r'(?<![A-Za-z0-9_.])[0-9]+(?:\.[0-9]+)?');

  List<String> violations() {
    final out = <String>[];
    for (final entity in Directory('lib/src').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      if (entity.path.endsWith('design/tokens.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        final exempted =
            line.contains('CL22-exempt') ||
            (i > 0 && lines[i - 1].contains('CL22-exempt'));
        void check(String value, Set<String> allowed, String kind) {
          if (allowed.contains(value)) return;
          if (exempted) return;
          out.add('${entity.path}:${i + 1} $kind 用了 $value（${line.trim()}）');
        }

        for (final m in sizedBox.allMatches(line)) {
          check(m.group(1)!, spacing, 'SizedBox 间距');
        }
        for (final m in sizedBoxPair.allMatches(line)) {
          check(m.group(1)!, spacing, 'SizedBox.square 尺寸');
        }
        // `SizedBox(...)` 里的第二个方向参数（上一条正则只抓第一个）。
        for (final box in RegExp(r'SizedBox\(([^)]*)\)').allMatches(line)) {
          for (final dir in RegExp(
            r'(height|width):\s*([0-9.]+)',
          ).allMatches(box.group(1)!)) {
            check(dir.group(2)!, spacing, 'SizedBox ${dir.group(1)}');
          }
        }
        for (final m in gaps.allMatches(line)) {
          check(m.group(1)!, spacing, '间距');
        }
        for (final m in borderRadius.allMatches(line)) {
          check(m.group(1)!, radiusText, '圆角');
        }
        for (final m in radiusOnly.allMatches(line)) {
          check(m.group(1)!, radiusText, '圆角');
        }
        for (final m in insets.allMatches(line)) {
          // 内边距只认间距刻度：`EdgeInsets.only(top: 10)` 不能用圆角档位蒙混过去。
          for (final n in number.allMatches(m.group(1)!)) {
            check(n.group(0)!, spacing, '内边距');
          }
        }
      }
    }
    return out;
  }

  test('CL22 间距与圆角只用有名档位（裸数字零放行）', () {
    final found = violations();
    expect(
      found,
      isEmpty,
      reason:
          '以下位置用了不在档位里的间距/圆角：\n${found.join('\n')}\n'
          '要么迁到最近的有名档位，要么写 // CL22-exempt: 理由 并登记。',
    );
  });

  test('CL20 间距档位集合冻结为 2/4/8/12/16/20/24/32', () {
    expect(MileafSpace.canonical, <double>[2, 4, 8, 12, 16, 20, 24, 32]);
  });

  test('CL21 半径档位不新增（0/4/10/12/20/24/28）', () {
    expect(MileafRadius.xs, 4);
    expect(MileafRadius.sm, 10);
    expect(MileafRadius.md, 12);
    expect(MileafRadius.lg, 20);
    expect(MileafRadius.surface, 24);
    expect(MileafRadius.sheet, 28);
  });
}
