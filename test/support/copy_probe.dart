import 'dart:io';

import 'package:flutter/widgets.dart';

/// AP06 文案守卫探针（抽取口径见交付手册 §5）。
///
/// 源文件扫描口径与 AP00 的 copy-baseline.txt 一致：单引号字符串字面量、含 CJK、
/// 按行计数、注释行与 *.g.dart 排除。内容检查（CP09 1–4 与精确旧串）按字面量
/// 逐条进行；标注 // copy-guard: technical 的行整体豁免。
final RegExp _chineseLiteral = RegExp(r"'[^']*[\u4e00-\u9fff][^']*'");
final RegExp _cjk = RegExp(r'[\u4e00-\u9fff]');
final RegExp _asciiWord = RegExp(r'[0-9A-Za-z]');

/// 行内全部含中文的单引号字面量内容（注释行返回空列表）。
List<String> chineseLiterals(String line) {
  if (line.trim().startsWith('//')) return [];
  final out = <String>[];
  for (final match in _chineseLiteral.allMatches(line)) {
    final raw = match.group(0);
    if (raw == null || raw.length < 2) continue;
    out.add(raw.substring(1, raw.length - 1));
  }
  return out;
}

/// 与 AP00 抽取命令一致的按行计数。
int chineseLiteralCount(String source) =>
    source.split('\n').where((line) => chineseLiterals(line).isNotEmpty).length;

/// lib/src 与 lib/main.dart 下的全部 Dart 源文件（排除 *.g.dart）。
List<String> appSourceFiles() {
  final files = <String>[];
  for (final entry in Directory('lib/src').listSync(recursive: true)) {
    if (entry is File &&
        entry.path.endsWith('.dart') &&
        !entry.path.endsWith('.g.dart')) {
      files.add(entry.path);
    }
  }
  if (File('lib/main.dart').existsSync()) files.add('lib/main.dart');
  files.sort();
  return files;
}

/// CP09.1：「·」拼接——任一段含 ASCII 字母或数字即违规。
bool copyGuardViolationDotJoin(String literal) {
  if (!literal.contains('·')) return false;
  return literal
      .split('·')
      .any((segment) => _asciiWord.hasMatch(segment.trim()));
}

/// CP09.2：单位当标签——单位 token 前一个非空字符是 CJK 即违规。
bool copyGuardViolationUnitLabel(String literal) {
  for (final match in RegExp(r'(km|kWh|Wh/km|kW|°C|pp)').allMatches(literal)) {
    var i = match.start - 1;
    while (i >= 0 && literal[i] == ' ') {
      i--;
    }
    if (i >= 0 && _cjk.hasMatch(literal[i])) return true;
  }
  return false;
}

/// CP09.3：主界面出现服务端字段名、枚举原值、snake_case、算法版本、
/// 快照 ID、schema、IANA、YYYY-MM-DD 占位。
bool copyGuardViolationTechnicalToken(String literal) =>
    RegExp(r'[a-z]+_[a-z0-9_]+').hasMatch(literal) ||
    literal.contains('YYYY-MM-DD') ||
    literal.contains('IANA') ||
    literal.contains('schema');

/// CP09.4：用符号代替词——↑ ↓、#17、独立 pp。
bool copyGuardViolationSymbolSubstitute(String literal) =>
    literal.contains('↑') ||
    literal.contains('↓') ||
    RegExp(r'#\d').hasMatch(literal) ||
    RegExp(r'(?<![A-Za-z])pp(?![A-Za-z])').hasMatch(literal);

/// 渲染后检查（AP14/AP15 使用）：收集页面树中的可见文本。
/// Semantics 标签在 3.47 为属性式存储，由 AP14/AP15 用 tester 语义 API 补充。
List<String> collectedTexts(Element root) {
  final out = <String>[];
  void visit(Element element) {
    final widget = element.widget;
    if (widget is Text) {
      if (widget.data != null) out.add(widget.data!);
      final span = widget.textSpan;
      if (span is TextSpan && span.text != null) out.add(span.text!);
    }
    element.visitChildren(visit);
  }

  visit(root);
  return out;
}
