import 'package:flutter/material.dart';

import '../../copy/dates.dart' show rangeSeparator;
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

/// 卡头的一段区间：看得见的 DF3 写法与读得出的读法（连接号读作「至」）。
typedef PeriodRange = ({String text, String reading});

/// 焦点卡头：期间名（`headline`）+ 区间（`subheadline`，次要色）。
///
/// Apple 焕新 R21.4：区间只在这里出现一次。排法由实际宽度决定，不再用
/// 「150% 起改两行」的字号阈值近似：一行放得下时区间靠右、与卡片内容右沿同线；
/// 放不下时整段落到期间名下一行（`s4` 行距、左对齐）。两个文本框各自成行，
/// 日期不会被卡片内容宽的一半挤成「…11月18 / 日」这样的孤字；整段区间再放不下
/// 一行时，只在 DF3 的连接号后换行（「10月20日–」/「11月18日」）。
///
/// 跨年等长区间（连接号前半段本身超过一行）仍由 `Text` 按字折行——那已是本
/// 组件能给出的最窄形态，不做缩字号。
class MileafPeriodHeader extends StatelessWidget {
  const MileafPeriodHeader({super.key, required this.label, this.range});

  /// 期间名（「近 30 天」「近 7 天驾驶」…）；期间控件已经写过，不再重复。
  final String label;

  /// 区间；读值未到时为空，不占位。
  final PeriodRange? range;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final colors = context.colors;
    final range = this.range;
    // Wrap 按内容收缩；铺满可用宽度后 spaceBetween 才把区间推到右沿。约束为
    // 无限时（不会出现在卡片里）退回内容宽度，不抛错。
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        return SizedBox(
          width: available.isFinite ? available : null,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: MileafSpace.s8,
            runSpacing: MileafSpace.s4,
            children: [
              Semantics(
                header: true,
                child: Text(
                  label,
                  style: type.headline.copyWith(color: colors.text),
                ),
              ),
              if (range != null)
                _RangeText(
                  range,
                  style: type.subheadline.copyWith(
                    color: colors.textSecondary,
                  ),
                  available: available,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 区间：放得下一行就是一段文字；放不下时只在连接号后分成两行。
///
/// 两种情况都按读法朗读（DF3：连接号读作「至」），不把区间念成两半。
class _RangeText extends StatelessWidget {
  const _RangeText(
    this.range, {
    required this.style,
    required this.available,
  });

  final PeriodRange range;
  final TextStyle style;
  final double available;

  @override
  Widget build(BuildContext context) {
    final split = range.text.indexOf(rangeSeparator);
    final painter = TextPainter(
      text: TextSpan(text: range.text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final oneLine = painter.width <= available;
    painter.dispose();
    // 没有连接号（单日等）时没有可用的断点，只能整段交给 Text 自己排。
    final visual = oneLine || split < 0 || split == range.text.length - 1
        ? Text(range.text, style: style)
        : Wrap(
            runSpacing: 0,
            children: [
              Text(range.text.substring(0, split + 1), style: style),
              Text(range.text.substring(split + 1), style: style),
            ],
          );
    return Semantics(
      label: range.reading,
      excludeSemantics: true,
      child: visual,
    );
  }
}
