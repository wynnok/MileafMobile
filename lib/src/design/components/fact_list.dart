import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

/// 一条事实：字段名 + 值 + 单位。
class MileafFact {
  const MileafFact({required this.label, this.value, this.unit});

  final String label;

  /// 已排版好的数字；null 表示缺失，渲染为 `—` 且不带单位。
  final String? value;

  /// 单位跟随值，比字段名小一档；缺失值不配单位。
  final String? unit;
}

/// 细分隔事实表：字段名在左，值靠右对齐成一条竖线。
///
/// 每行之上 1px `line`（首行可由 [topLine] 决定是否也画），末行不封口，
/// 所以表在视觉上是「一组行」而不是一张卡片。行高由 12 上下内边距与 17/25
/// 的行高自然得出；大字下值与字段名换成上下两行，不缩字号。
///
/// 值靠右是这张表的秩序来源：同一屏里 `到达 68%` 已在右边缘，事实表的
/// 数值列与它共用同一条右线。单位另占一列、宽度取本表最长单位，因此
/// `10 km/h` 与 `120 kW` 的数字右边缘落在同一条竖线上，而不是随单位
/// 长短左右浮动。
class MileafFactList extends StatelessWidget {
  const MileafFactList({super.key, required this.facts});

  final List<MileafFact> facts;

  static const _unitGap = MileafSpace.s4;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final large = MileafLayout.largeText(context);
    final textDirection = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final valueStyle = type.body.copyWith(
      color: colors.text,
      fontWeight: MileafType.weightMedium,
    );
    final unitStyle = type.subheadline.copyWith(color: colors.textFaint);
    final labelStyle = type.subheadline.copyWith(color: colors.textMuted);

    /// 单位列宽：本表最长单位的实测宽度。用尺而不是固定数字，换字体或
    /// 放大字号时列宽随之变化，数字仍对齐。
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: textDirection,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    var unitColumn = 0.0;
    for (final fact in facts) {
      final unit = fact.value == null ? null : fact.unit;
      if (unit == null || unit.isEmpty) continue;
      unitColumn = math.max(unitColumn, measure(unit, unitStyle));
    }

    Widget row(MileafFact fact, {required bool divided}) {
      final unit = fact.value == null ? null : fact.unit;
      final hasUnit = unit != null && unit.isNotEmpty;
      final label = Text(fact.label, style: labelStyle);
      final Widget number = Text(
        fact.value ?? '—',
        style: valueStyle,
        textAlign: TextAlign.end,
        maxLines: 1,
      );
      Widget body;
      if (large) {
        // 大字：字段名与值上下两行，单位随值同行。
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            label,
            const SizedBox(height: MileafSpace.s4),
            Text.rich(
              TextSpan(
                text: fact.value ?? '—',
                style: valueStyle,
                children: [
                  if (hasUnit) TextSpan(text: ' $unit', style: unitStyle),
                ],
              ),
            ),
          ],
        );
      } else {
        body = Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: label),
            const SizedBox(width: MileafSpace.s16),
            number,
            // 单位列固定宽度：数字右边缘因此排成一条竖线。
            if (unitColumn > 0) ...[
              const SizedBox(width: _unitGap),
              SizedBox(
                width: unitColumn,
                // 单位在定宽列里靠右：单位右边缘与整页右线齐平，数字右边缘
                // 则由列宽固定成一条竖线，两者都不随单位长短浮动。
                child: hasUnit
                    ? Text(
                        unit,
                        style: unitStyle,
                        maxLines: 1,
                        textAlign: TextAlign.end,
                      )
                    : null,
              ),
            ],
          ],
        );
      }
      return Semantics(
        container: true,
        excludeSemantics: true,
        label: '${fact.label} ${fact.value ?? '—'}${hasUnit ? ' $unit' : ''}',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: MileafSpace.s12),
          decoration: divided
              ? BoxDecoration(
                  border: Border(top: BorderSide(color: colors.line)),
                )
              : null,
          child: body,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, fact) in facts.indexed)
          row(fact, divided: index > 0),
      ],
    );
  }
}
