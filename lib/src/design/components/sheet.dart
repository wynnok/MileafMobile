import 'package:flutter/material.dart';

import '../icons.dart';
import '../layout.dart';
import '../motion.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';
import 'icon_button.dart';

/// Bottom sheet: top radius 20, scrim, 36×4 handle, 18 title, 44 close.
///
/// Transition follows R07: 240ms easeOutCubic, zero when reduce motion is on
/// (U03 动效基础；U02 交接的弹层时长校准).
Future<T?> showMileafSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final duration = MileafLayout.motion(context, MileafDurations.sheet);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: false,
    sheetAnimationStyle: AnimationStyle(
      duration: duration,
      reverseDuration: duration,
      curve: MileafCurves.sheet,
      reverseCurve: MileafCurves.sheet,
    ),
    builder: (sheetContext) => MileafSheetFrame(
      title: title,
      onClose: () => Navigator.pop(sheetContext),
      child: builder(sheetContext),
    ),
  );
}

class MileafSheetFrame extends StatelessWidget {
  const MileafSheetFrame({
    super.key,
    required this.title,
    required this.child,
    this.onClose,
    this.closeEnabled = true,
    this.closeLabel = '关闭',
  });

  final String title;
  final Widget child;
  final VoidCallback? onClose;
  final bool closeEnabled;
  final String closeLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final compact =
        (MediaQuery.sizeOf(context).width <= MileafBreakpoints.compact &&
            MileafLayout.largeText(context)) ||
        MediaQuery.sizeOf(context).height -
                MediaQuery.viewInsetsOf(context).bottom <
            400;
    final heading = Row(
      children: [
        Expanded(child: Text(title, style: context.type.title)),
        if (onClose != null)
          MileafIconButton(
            icon: MileafIconName.close,
            tooltip: closeLabel,
            onPressed: closeEnabled ? onClose : null,
          ),
      ],
    );
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: MileafBreakpoints.sheetMax,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              MileafLayout.pageInset(context),
              MileafSpace.s12,
              MileafLayout.pageInset(context),
              MileafSpace.s20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.lineStrong,
                      borderRadius: MileafRadius.fullAll,
                    ),
                  ),
                ),
                const SizedBox(height: MileafSpace.s8),
                if (!compact) heading,
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: MileafSpace.s8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [if (compact) heading, child],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
