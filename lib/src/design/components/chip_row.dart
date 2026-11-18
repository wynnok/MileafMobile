import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout.dart';
import '../motion.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';
import 'button.dart' show MileafControlMetrics;
import 'chip.dart';

/// 共享胶囊轨道。紧凑期间贴住内容，指标组占满可用宽度。
///
/// R27 折行规则：一行放不下时在自身区域内折行，每行至多 3 项（4 项 2+2，
/// 5 项 3+2）；320 宽或大字时四项 2×2；仍放不下时单列。轨道视觉高 40、选中底
/// 36，命中区按平台触控尺寸透明扩展。
class ChipRow extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.children,
    this.alignment = WrapCrossAlignment.center,
    this.equalWidth = false,
  });

  /// 轨道水平内边距：轨道 40 包住选中底 36，上下左右各留 2。
  static const trackInset = MileafSpace.inline2;

  final List<StatusChip> children;
  final WrapCrossAlignment alignment;
  final bool equalWidth;

  /// 首行高度（含透明命中带），供 [MileafPeriodRow] 对齐行尾圆钮。
  static double rowHeight(BuildContext context, List<StatusChip> children) =>
      _Metrics.of(context, children, double.infinity).cellHeight;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _Metrics.of(
          context,
          children,
          constraints.hasBoundedWidth ? constraints.maxWidth : double.infinity,
          equalWidth: equalWidth,
        );
        final count = children.length;
        final selected = children.indexWhere((chip) => chip.selected);
        final rows = (count / metrics.columns).ceil();
        final totalHeight = rows * metrics.cellHeight;
        final trackHeight =
            (rows - 1) * metrics.cellHeight +
            metrics.capsuleHeight +
            trackInset * 2;
        final row = selected < 0 ? 0 : selected ~/ metrics.columns;
        final column = selected < 0 ? 0 : selected % metrics.columns;
        final selectedWidth = selected < 0
            ? metrics.cellWidth
            : metrics.widths[selected];
        final startX = metrics.compact && selected >= 0
            ? metrics.widths
                  .take(selected)
                  .fold(0.0, (sum, value) => sum + value)
            : column * metrics.cellWidth;
        final reduced = MileafLayout.reduceMotion(context);
        final duration = MileafLayout.motion(
          context,
          MileafDurations.selection,
        );
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: metrics.trackWidth,
            height: totalHeight,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  // 轨道从首行胶囊上沿再让出 2：多行时也包住全部行。
                  top:
                      (metrics.cellHeight - metrics.capsuleHeight) / 2 -
                      trackInset,
                  height: trackHeight,
                  child: Container(
                    key: MileafChipKeys.track,
                    decoration: BoxDecoration(
                      color: colors.segmentTrack,
                      borderRadius: BorderRadius.circular(MileafRadius.full),
                    ),
                  ),
                ),
                if (selected >= 0)
                  AnimatedPositioned(
                    duration: duration,
                    curve: MileafCurves.selection,
                    left: trackInset + startX,
                    top:
                        row * metrics.cellHeight +
                        (metrics.cellHeight - metrics.capsuleHeight) / 2,
                    width: selectedWidth,
                    height: metrics.capsuleHeight,
                    child: TweenAnimationBuilder<double>(
                      // M02：起步横向拉伸 1.04 后回落；减少动效时不拉伸。
                      key: ValueKey('segment-stretch-$selected'),
                      tween: Tween(
                        begin: reduced ? 1.0 : MileafMotion.segmentStretch,
                        end: 1.0,
                      ),
                      duration: duration,
                      curve: MileafCurves.selection,
                      builder: (context, stretch, child) => Transform.scale(
                        scaleX: stretch,
                        alignment: Alignment.center,
                        child: child,
                      ),
                      child: Container(
                        key: MileafChipKeys.selected,
                        decoration: BoxDecoration(
                          color: colors.segmentSelected,
                          borderRadius: BorderRadius.circular(
                            MileafRadius.full,
                          ),
                          boxShadow: MileafControlMetrics.selectionShadow(
                            colors,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: trackInset,
                  top: 0,
                  width: metrics.contentWidth,
                  child: ChipTrackScope(
                    capsuleHeight: metrics.capsuleHeight,
                    child: Column(
                      children: [
                        for (var index = 0; index < rows; index++)
                          Row(
                            children: [
                              for (
                                var offset = 0;
                                offset < metrics.columns &&
                                    index * metrics.columns + offset < count;
                                offset++
                              )
                                SizedBox(
                                  width: metrics
                                      .widths[index * metrics.columns + offset],
                                  height: metrics.cellHeight,
                                  child:
                                      children[index * metrics.columns +
                                          offset],
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// R27 期间行：期间分段占剩余宽度，行尾为刷新圆钮；圆钮贴行右上、与第一行
/// 垂直居中；分段在自身区域内折行（每行至多 3 项）。
class MileafPeriodRow extends StatelessWidget {
  const MileafPeriodRow({
    super.key,
    required this.children,
    this.trailing,
    this.spacing = MileafSpace.s8,
  });

  final List<StatusChip> children;

  /// 行尾唯一圆钮（刷新）；为空时期间分段独占整行。
  final Widget? trailing;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    if (trailing == null) return ChipRow(children: children);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // R27：期间分段占剩余宽度（equalWidth 撑满），行尾留唯一刷新圆钮。
        Expanded(child: ChipRow(equalWidth: true, children: children)),
        Padding(
          padding: EdgeInsets.only(left: spacing),
          child: SizedBox(
            // 与第一行（含透明命中带）等高并居中，圆钮因此贴在期间行右上。
            height: ChipRow.rowHeight(context, children),
            child: Center(widthFactor: 1, child: trailing),
          ),
        ),
      ],
    );
  }
}

/// 一次算清轨道、胶囊与格子几何；每个分段的文字宽度只量一次。
class _Metrics {
  const _Metrics({
    required this.widths,
    required this.columns,
    required this.compact,
    required this.contentWidth,
    required this.cellWidth,
    required this.cellHeight,
    required this.capsuleHeight,
  });

  final List<double> widths;
  final int columns;
  final bool compact;
  final double contentWidth;
  final double cellWidth;
  final double cellHeight;
  final double capsuleHeight;

  double get trackWidth => contentWidth + ChipRow.trackInset * 2;

  static _Metrics of(
    BuildContext context,
    List<StatusChip> children,
    double available, {
    bool equalWidth = false,
  }) {
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final type = context.type;
    final touch = MileafLayout.touchTarget(context);
    if (children.isEmpty) {
      return _Metrics(
        widths: const [],
        columns: 1,
        compact: true,
        contentWidth: 0,
        cellWidth: 0,
        cellHeight: touch,
        capsuleHeight: MileafControlMetrics.segmentSelectedHeight,
      );
    }
    var textHeight = 0.0;
    final natural = <double>[];
    for (final chip in children) {
      final style = chip.selected ? type.controlSelected : type.control;
      final painter = TextPainter(
        text: TextSpan(text: chip.label, style: style),
        textDirection: direction,
        textScaler: scaler,
      )..layout();
      textHeight = math.max(textHeight, painter.height);
      natural.add(
        math.max(
          touch,
          // 两侧 12 内边距，另留一档给 600 字重与像素取整。
          painter.width + MileafSpace.s12 * 2 + MileafSpace.s4,
        ),
      );
      painter.dispose();
    }
    final capsuleHeight = math.max(
      MileafControlMetrics.segmentSelectedHeight,
      textHeight + MileafSpace.s8,
    );
    final cellHeight = math.max(touch, capsuleHeight + ChipRow.trackInset * 2);
    final inner = available.isFinite
        ? math.max(1.0, available - ChipRow.trackInset * 2)
        : double.infinity;
    final preferred = natural.fold<double>(0, math.max);
    final naturalTotal = natural.fold<double>(0, (a, b) => a + b);
    final screenWidth = MediaQuery.sizeOf(context).width;
    // R27：四项在 320 宽或大字时 2×2。
    final reflowFour =
        children.length == 4 &&
        (MileafLayout.largeText(context) ||
            screenWidth <= MileafBreakpoints.compact);
    final compactRow = !equalWidth && !reflowFour && naturalTotal <= inner;
    int columns;
    if (compactRow) {
      columns = children.length;
    } else {
      columns = inner.isFinite
          ? math.max(1, (inner / preferred).floor())
          : children.length;
      columns = math.min(columns, children.length);
      if (reflowFour) {
        // R27：320 宽或大字时四项 2×2。
        columns = math.min(columns, 2);
      } else if (children.length == 4) {
        // R27：四项能放一行就一行；只放得下三项时 2+2，不出现 3+1。
        if (columns == 3) columns = 2;
      } else if (columns > 3) {
        // R27：折行时每行至多 3 项（5 项 3+2）。
        columns = 3;
      }
      columns = math.max(1, columns);
    }
    // equalWidth（指标组、期间行）占满可用宽度；紧凑期间贴住内容。
    final contentWidth = equalWidth
        ? (inner.isFinite ? inner : naturalTotal)
        : compactRow
        ? naturalTotal
        : math.min(inner, preferred * columns);
    final cellWidth = contentWidth / columns;
    return _Metrics(
      widths: compactRow
          ? natural
          : List<double>.filled(children.length, cellWidth),
      columns: columns,
      compact: compactRow,
      contentWidth: contentWidth,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      capsuleHeight: capsuleHeight,
    );
  }
}
