import 'package:flutter/material.dart';

import '../icons.dart';
import '../layout.dart';
import '../motion.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';
import 'button.dart' show MileafControlMetrics;
import 'icon_button.dart';

/// R28 弹层样式。
enum MileafSheetStyle {
  /// 贴边：高内容与表单（费用补录、日期区间、地图同意），顶部半径 28。
  edge,

  /// 浮动：短内容与选择类（车辆、外观），左右下各留 8，四角半径 28。
  floating,
}

/// Bottom sheet. 现有调用的行为合同不变：不给 [style] 时维持原几何与表面色，
/// 新样式通过参数启用（R28）。
///
/// M05：进入 280ms、退出 220ms easeOutCubic，减少动效时归零；关闭后焦点回到
/// 触发控件。
Future<T?> showMileafSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  MileafSheetStyle? style,
}) {
  final duration = MileafLayout.motion(context, MileafDurations.sheetIn);
  final reverseDuration = MileafLayout.motion(
    context,
    MileafDurations.sheetOut,
  );
  final previousFocus = FocusManager.instance.primaryFocus;
  final result = showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    showDragHandle: false,
    // R28：弹层正文不透明（surfaceRaised）；浮动样式由框架自己画带外边距的卡。
    backgroundColor: style == null
        ? null
        : style == MileafSheetStyle.floating
        ? Colors.transparent
        : context.colors.surfaceRaised,
    sheetAnimationStyle: AnimationStyle(
      duration: duration,
      reverseDuration: reverseDuration,
      curve: MileafCurves.sheet,
      reverseCurve: MileafCurves.sheet,
    ),
    builder: (sheetContext) => MileafSheetFrame(
      title: title,
      style: style,
      onClose: () => Navigator.pop(sheetContext),
      child: builder(sheetContext),
    ),
  );
  return result.whenComplete(() {
    // R28：关闭后焦点回到触发控件。
    if (previousFocus != null &&
        previousFocus.context != null &&
        previousFocus.canRequestFocus) {
      previousFocus.requestFocus();
    }
  });
}

/// 弹层框架：把手 36×4、标题行 headline + 关闭圆钮、单一滚动内容、最大宽 520。
class MileafSheetFrame extends StatelessWidget {
  const MileafSheetFrame({
    super.key,
    required this.title,
    required this.child,
    this.onClose,
    this.closeEnabled = true,
    this.closeLabel = '关闭',
    this.style,
  });

  final String title;
  final Widget child;
  final VoidCallback? onClose;
  final bool closeEnabled;
  final String closeLabel;
  final MileafSheetStyle? style;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final floating = style == MileafSheetStyle.floating;
    final inset = MileafControlMetrics.floatingSheetInset;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final compact =
        (MediaQuery.sizeOf(context).width <= MileafBreakpoints.compact &&
            MileafLayout.largeText(context)) ||
        MediaQuery.sizeOf(context).height - viewInsets < 400;
    final heading = Row(
      children: [
        Expanded(
          child: Text(
            title,
            // R25/R28：弹层标题 headline，左对齐。
            style: context.type.headline,
          ),
        ),
        if (onClose != null)
          MileafIconButton(
            icon: MileafIconName.close,
            tooltip: closeLabel,
            onPressed: closeEnabled ? onClose : null,
          ),
      ],
    );
    final body = Column(
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
              // R28：键盘按 viewInsets 避让——滚动内容的末段留出键盘高度，
              // 表单的最后一项与主按钮都能滚到键盘之上。
              padding: EdgeInsets.only(bottom: MileafSpace.s8 + viewInsets),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [if (compact) heading, child],
              ),
            ),
          ),
        ),
      ],
    );
    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        MileafLayout.pageInset(context),
        MileafSpace.s12,
        MileafLayout.pageInset(context),
        MileafSpace.s20,
      ),
      child: body,
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
            // R28：浮动样式左右下各留 8。键盘避让由 modal 路由（按 viewInsets
            // 抬起弹层）与本组件的单一滚动区共同完成，不重复加内边距。
            padding: EdgeInsets.fromLTRB(
              floating ? inset : 0,
              0,
              floating ? inset : 0,
              floating ? inset : 0,
            ),
            child: DecoratedBox(
              key: const ValueKey('sheet-surface'),
              decoration: BoxDecoration(
                color: style == null ? null : colors.surfaceRaised,
                borderRadius: floating
                    ? BorderRadius.circular(MileafRadius.sheet)
                    : const BorderRadius.vertical(
                        top: Radius.circular(MileafRadius.sheet),
                      ),
                boxShadow: floating ? colors.sheetShadow : null,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
