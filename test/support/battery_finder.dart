import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/battery_arc.dart';

/// Finds the arc's value text in both real-font (one `68 %` span) and
/// test-font (split `68` + `%`) layouts.
Finder batteryText(int level) => find.descendant(
  of: find.byType(BatteryArc),
  matching: find.byWidgetPredicate((widget) {
    if (widget is! Text) return false;
    final text = widget.data ?? widget.textSpan?.toPlainText() ?? '';
    return text == '$level' || text.startsWith('$level %');
  }),
);
