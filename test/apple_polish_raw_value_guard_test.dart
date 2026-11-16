// AP01 页面裸值守卫（R32）：扫描 lib 页面文件的裸 fontSize、Color(0x、
// Duration(milliseconds、Radius.circular( 数字，按源文件计数与基线比较，
// 只许下降。基线在 test/support/raw_value_baseline/（每个源文件一个）。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _patterns = <String, RegExp>{
  'fontSize': RegExp(r'fontSize:\s*[0-9.]'),
  'color0x': RegExp(r'Color\(0x[0-9A-Fa-f]'),
  'durationMilliseconds': RegExp(r'Duration\(milliseconds:\s*[0-9]'),
  'radiusCircular': RegExp(r'Radius\.circular\([0-9.]'),
};

/// 扫描集：lib 下全部 .dart，排除设计层（lib/src/design/**，裸值合法）
/// 与生成契约（*.g.dart）。
List<String> _sourceFiles() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => !file.path.contains('/design/'))
        .where((file) => !file.path.endsWith('.g.dart'))
        .map((file) => file.path)
        .toList();

Map<String, int> _counts(String source) {
  final out = <String, int>{};
  for (final entry in _patterns.entries) {
    out[entry.key] = entry.value.allMatches(source).length;
  }
  return out;
}

/// 基线文件不存在时按全 0 处理：新建文件不允许引入裸值。
Map<String, int> _baseline(String relative) {
  final file = File('test/support/raw_value_baseline/$relative.txt');
  final out = <String, int>{for (final name in _patterns.keys) name: 0};
  if (!file.existsSync()) return out;
  for (final line in file.readAsStringSync().split('\n')) {
    final eq = line.indexOf('=');
    if (eq > 0) {
      final key = line.substring(0, eq).trim();
      if (_patterns.containsKey(key)) {
        out[key] = int.parse(line.substring(eq + 1).trim());
      }
    }
  }
  return out;
}

String _baselinePath(String relative) =>
    'test/support/raw_value_baseline/$relative.txt';

void main() {
  test('基线覆盖全部扫描文件（每个源文件一个基线文件）', () {
    final files = _sourceFiles();
    expect(files, isNotEmpty);
    for (final file in files) {
      expect(
        File(_baselinePath(file)).existsSync(),
        isTrue,
        reason: '$file 缺少裸值守卫基线',
      );
    }
  });

  test('页面裸值计数只许下降（R32）', () {
    for (final file in _sourceFiles()) {
      final current = _counts(File(file).readAsStringSync());
      final base = _baseline(file);
      for (final entry in current.entries) {
        final name = entry.key;
        final count = entry.value;
        expect(
          count,
          lessThanOrEqualTo(base[name]!),
          reason: '$file 的 $name 裸值从基线 ${base[name]} 升到 $count',
        );
      }
    }
  });

  test('全局裸值总数只许下降', () {
    int total(Map<String, int> counts) =>
        counts.values.fold(0, (a, b) => a + b);
    var baseTotal = 0;
    var currentTotal = 0;
    for (final file in _sourceFiles()) {
      baseTotal += total(_baseline(file));
      currentTotal += total(_counts(File(file).readAsStringSync()));
    }
    expect(
      currentTotal,
      lessThanOrEqualTo(baseTotal),
      reason: '全局裸值总数从 $baseTotal 升到 $currentTotal',
    );
  });
}
