import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mileaf/src/design/tokens.dart';

/// R21.7 层级探针：统计有效视口内 `display` 与 `metricLg` 文字的数量。
///
/// 角色按 TextScaler 之前的基值判定（规格 §3）：fontSize 恰为
/// [MileafType.displaySize]（40）记为 display，恰为 [MileafType.metricLgSize]
/// （32）记为 metricLg；其余角色不计。viewport 之外的文本（例如未滚动到的
/// 列表项）不计入。
class HierarchyItem {
  const HierarchyItem({
    required this.text,
    required this.role,
    required this.rect,
  });

  final String text;
  final String role;
  final Rect rect;
}

class HierarchyReport {
  const HierarchyReport({required this.display, required this.metricLg});

  final List<HierarchyItem> display;
  final List<HierarchyItem> metricLg;

  int get displayCount => display.length;
  int get metricLgCount => metricLg.length;
  int get total => display.length + metricLg.length;
}

/// 扫描元素树，统计基值为 display/metricLg 的文字，并按 [viewport] 过滤。
HierarchyReport measureHierarchy(
  WidgetTester tester, {
  required Rect viewport,
}) {
  final display = <HierarchyItem>[];
  final metricLg = <HierarchyItem>[];
  void visit(Element element) {
    final widget = element.widget;
    if (widget is Text) {
      final size = widget.style?.fontSize;
      if (size != null) {
        final role = size == MileafType.displaySize
            ? 'display'
            : size == MileafType.metricLgSize
            ? 'metricLg'
            : null;
        if (role != null) {
          final rect = _rectOf(element);
          if (rect != null && rect.overlaps(viewport)) {
            (role == 'display' ? display : metricLg).add(
              HierarchyItem(text: _spanText(widget), role: role, rect: rect),
            );
          }
        }
      }
    }
    element.visitChildren(visit);
  }

  visit(tester.allElements.first);
  return HierarchyReport(display: display, metricLg: metricLg);
}

String _spanText(Text widget) {
  if (widget.data != null) {
    return widget.data!;
  }
  if (widget.textSpan is TextSpan) {
    return (widget.textSpan as TextSpan).text ?? '';
  }
  return '';
}

Rect? _rectOf(Element element) {
  final renderObject = element.renderObject;
  if (renderObject is RenderBox &&
      renderObject.attached &&
      renderObject.hasSize) {
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }
  return null;
}
