import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';
import 'chip.dart';

/// A shared inset track. Compact periods hug their content; metric groups fill
/// the available width. Text measurement keeps every option readable at scale.
class ChipRow extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.children,
    this.alignment = WrapCrossAlignment.center,
    this.equalWidth = false,
  });

  final List<StatusChip> children;
  final WrapCrossAlignment alignment;
  final bool equalWidth;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        const inset = MileafSpace.s4;
        const labelInset = MileafSpace.s12;
        final touchTarget = MileafLayout.touchTarget(context);
        var preferred = touchTarget;
        final naturalWidths = <double>[];
        for (final chip in children) {
          final painter = TextPainter(
            text: TextSpan(
              text: chip.label,
              style: context.type.label.copyWith(fontWeight: FontWeight.w600),
            ),
            textDirection: direction,
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final natural = math.max(
            touchTarget,
            // Leave one spacing step for fallback-font and pixel rounding.
            painter.width + labelInset * 2 + MileafSpace.s4,
          );
          naturalWidths.add(natural);
          preferred = math.max(preferred, natural);
          painter.dispose();
        }
        final available = constraints.hasBoundedWidth
            ? math.max(1.0, constraints.maxWidth - inset * 2)
            : preferred * children.length;
        var columns = (available / preferred).floor().clamp(1, children.length);
        if (children.length == 4 && columns == 3) columns = 2;
        final reflowFour =
            children.length == 4 &&
            (MileafLayout.largeText(context) ||
                MediaQuery.sizeOf(context).width <= 320);
        if (reflowFour) {
          columns = math.min(columns, 2);
        }
        final naturalTotal = naturalWidths.reduce((a, b) => a + b);
        final compactRow =
            !equalWidth && !reflowFour && naturalTotal <= available;
        if (compactRow) columns = children.length;
        final width = equalWidth
            ? available
            : compactRow
            ? naturalTotal
            : math.min(available, preferred * columns);
        final cellWidth = width / columns;
        final widths = compactRow
            ? naturalWidths
            : List<double>.filled(children.length, cellWidth);
        var height = touchTarget;
        for (final (index, chip) in children.indexed) {
          final painter = TextPainter(
            text: TextSpan(text: chip.label, style: context.type.label),
            textDirection: direction,
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: math.max(1, widths[index] - labelInset * 2));
          height = math.max(height, painter.height + MileafSpace.s16);
          painter.dispose();
        }
        final selected = children.indexWhere((chip) => chip.selected);
        final rows = (children.length / columns).ceil();
        final column = selected < 0 ? 0 : selected % columns;
        final selectedWidth = selected < 0 ? cellWidth : widths[selected];
        final startX = compactRow && selected >= 0
            ? widths.take(selected).fold(0.0, (sum, value) => sum + value)
            : column * cellWidth;
        final x = direction == TextDirection.ltr
            ? startX
            : width - startX - selectedWidth;
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            width: width + inset * 2,
            padding: const EdgeInsets.all(inset),
            decoration: BoxDecoration(
              color: colors.segmentTrack,
              borderRadius: MileafRadius.mdAll,
            ),
            child: ChipTrackScope(
              child: Stack(
                children: [
                  if (selected >= 0)
                    AnimatedContainer(
                      duration: MileafLayout.motion(
                        context,
                        MileafDurations.selection,
                      ),
                      curve: Curves.easeOutCubic,
                      transform: Matrix4.translationValues(
                        x,
                        (selected ~/ columns) * height,
                        0,
                      ),
                      child: Container(
                        width: selectedWidth,
                        height: height,
                        decoration: BoxDecoration(
                          color: colors.segmentSelected,
                          borderRadius: BorderRadius.circular(MileafSpace.s8),
                        ),
                        child: const ChipSelectionMark(),
                      ),
                    ),
                  SizedBox(
                    height: rows * height,
                    child: Wrap(
                      crossAxisAlignment: alignment,
                      children: [
                        for (final (index, child) in children.indexed)
                          SizedBox(
                            width: widths[index],
                            height: height,
                            child: child,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
