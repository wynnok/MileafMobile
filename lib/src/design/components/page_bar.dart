import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

/// Shared secondary navigation for routes and embedded statistics topics.
class MileafNavigationRow extends StatelessWidget {
  const MileafNavigationRow({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const [],
  });

  final Text title;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final large = MileafLayout.largeText(context);
    final inset = MileafLayout.pageInset(context);
    final actionRow = Row(mainAxisSize: MainAxisSize.min, children: actions);
    return Padding(
      // Let the invisible hit padding extend into the page margin, so the
      // chevron and action text share the content's visible edges.
      padding: EdgeInsetsDirectional.only(
        start: inset - (onBack != null ? MileafSpace.s12 : 0),
        end: inset - (actions.isNotEmpty ? MileafSpace.s12 : 0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: MileafSpace.s56),
            child: Row(
              children: [
                if (onBack != null)
                  SizedBox.square(
                    dimension: MileafSpace.touch,
                    child: _NavigationBackButton(onPressed: onBack!),
                  ),
                Expanded(
                  child: DefaultTextStyle(
                    style: context.type.title.copyWith(
                      color: context.colors.text,
                    ),
                    child: title,
                  ),
                ),
                if (!large) actionRow,
              ],
            ),
          ),
          if (large && actions.isNotEmpty)
            Align(alignment: AlignmentDirectional.centerEnd, child: actionRow),
        ],
      ),
    );
  }
}

AppBar mileafPageBar(
  BuildContext context, {
  required Text title,
  List<Widget> actions = const [],
}) {
  final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
  final large = MileafLayout.largeText(context);
  final contentWidth = math.min(
    MediaQuery.sizeOf(context).width - MediaQuery.paddingOf(context).horizontal,
    MileafBreakpoints.maxContent,
  );
  final painter =
      TextPainter(
        text: TextSpan(text: title.data, style: context.type.title),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(
        maxWidth: math.max(
          1,
          contentWidth -
              2 * MileafLayout.pageInset(context) -
              (canPop ? MileafSpace.touch - MileafSpace.s12 : 0) +
              (actions.isNotEmpty ? MileafSpace.s12 : 0) -
              (large ? 0 : actions.length * MileafSpace.s56),
        ),
      );
  final height =
      math.max(MileafSpace.s56, painter.height + MileafSpace.s16) +
      (large && actions.isNotEmpty ? MileafSpace.s56 : 0);
  painter.dispose();
  return AppBar(
    automaticallyImplyLeading: false,
    titleSpacing: 0,
    toolbarHeight: height,
    // AppBar caps its inherited text scaler; preserve the user's full scale.
    title: MediaQuery(
      data: MediaQuery.of(context),
      child: MileafContent(
        child: MileafNavigationRow(
          title: title,
          onBack: canPop ? () => Navigator.maybePop(context) : null,
          actions: actions,
        ),
      ),
    ),
  );
}

class _NavigationBackButton extends StatefulWidget {
  const _NavigationBackButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_NavigationBackButton> createState() => _NavigationBackButtonState();
}

class _NavigationBackButtonState extends State<_NavigationBackButton> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => setState(() => pressed = true),
    onPointerUp: (_) => setState(() => pressed = false),
    onPointerCancel: (_) => setState(() => pressed = false),
    child: Theme(
      data: Theme.of(context).copyWith(
        actionIconTheme: ActionIconThemeData(
          backButtonIconBuilder: (context) => AnimatedSlide(
            offset: pressed && !MileafLayout.reduceMotion(context)
                ? const Offset(-.05, 0)
                : Offset.zero,
            duration: MileafLayout.motion(context, MileafDurations.press),
            child: const Icon(Icons.chevron_left_rounded, size: 20),
          ),
        ),
      ),
      child: BackButton(
        onPressed: widget.onPressed,
        color: context.colors.textMuted,
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          minimumSize: const WidgetStatePropertyAll(
            Size.square(MileafSpace.touch),
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? BorderSide(color: context.colors.focusRing, width: 2)
                : BorderSide.none,
          ),
        ),
      ),
    ),
  );
}
