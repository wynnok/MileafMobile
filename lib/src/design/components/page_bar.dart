import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../icons.dart';
import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';
import 'icon_button.dart';
import 'navigation_material.dart';

/// 二级导航尾部的一个「更多」菜单项（R26/R28）。
class MileafNavigationMenuEntry {
  const MileafNavigationMenuEntry({
    required this.label,
    required this.onSelected,
  });

  final String label;
  final VoidCallback onSelected;
}

/// Shared secondary navigation for routes and embedded statistics topics.
///
/// R26：标题 headline、返回图标用自绘图标集、尾部最多一个可见操作，第二个
/// 操作进「更多」菜单（[MileafNavigationMenuEntry]）。
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
    final backHitInset =
        (MileafLayout.touchTarget(context) - MileafIconMetrics.nav) / 2;
    final actionRow = Row(mainAxisSize: MainAxisSize.min, children: actions);
    return Padding(
      // Let the invisible hit padding extend into the page margin, so the
      // chevron and action text share the content's visible edges.
      padding: EdgeInsetsDirectional.only(
        start: inset - (onBack != null ? backHitInset : 0),
        end: inset - (actions.isNotEmpty ? MileafSpace.s12 : 0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _rowFloor),
            child: Row(
              children: [
                if (onBack != null)
                  SizedBox.square(
                    dimension: MileafLayout.touchTarget(context),
                    child: _NavigationBackButton(onPressed: onBack!),
                  ),
                Expanded(
                  child: Transform.translate(
                    offset: Offset(
                      onBack == null ? 0 : -(backHitInset - MileafSpace.s12),
                      0,
                    ),
                    child: DefaultTextStyle(
                      style: context.type.headline.copyWith(
                        color: context.colors.text,
                      ),
                      child: title,
                    ),
                  ),
                ),
                if (!large) actionRow,
              ],
            ),
          ),
          if (large && actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: MileafSpace.s8),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: actionRow,
              ),
            ),
        ],
      ),
    );
  }
}

AppBar mileafPageBar(
  BuildContext context, {
  required Text title,
  List<Widget> actions = const [],
  List<MileafNavigationMenuEntry> moreActions = const [],
}) {
  final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
  final large = MileafLayout.largeText(context);
  final visible = [
    ...actions,
    if (moreActions.isNotEmpty) _MoreMenuButton(entries: moreActions),
  ];
  final contentWidth = math.min(
    MediaQuery.sizeOf(context).width - MediaQuery.paddingOf(context).horizontal,
    MileafBreakpoints.maxContent,
  );
  final painter =
      TextPainter(
        text: TextSpan(text: title.data, style: context.type.headline),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(
        maxWidth: math.max(
          1,
          contentWidth -
              2 * MileafLayout.pageInset(context) -
              (canPop
                  ? MileafLayout.touchTarget(context) -
                        (MileafLayout.touchTarget(context) -
                                MileafIconMetrics.nav) /
                            2
                  : 0) +
              (visible.isNotEmpty ? MileafSpace.s12 : 0) -
              (large ? 0 : visible.length * _rowFloor),
        ),
      );
  final height =
      math.max(_rowFloor, painter.height + MileafSpace.s16) +
      (large && visible.isNotEmpty ? _rowFloor : 0);
  painter.dispose();
  return AppBar(
    automaticallyImplyLeading: false,
    titleSpacing: 0,
    toolbarHeight: height,
    // R26：二级导航内容经过时使用磨砂材质；未滚过时与 canvas 同底（实色路径），
    // 因此静止态的观感与既有页面一致。
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    flexibleSpace: const _SecondaryChrome(),
    // AppBar caps its inherited text scaler; preserve the user's full scale.
    title: MediaQuery(
      data: MediaQuery.of(context),
      child: MileafContent(
        child: MileafNavigationRow(
          title: title,
          onBack: canPop ? () => Navigator.maybePop(context) : null,
          actions: visible,
        ),
      ),
    ),
  );
}

/// R24 间距表没有 56 这一档；52 + 4 与既有导航行几何一致。
const _rowFloor = MileafSpace.inputMinHeight + MileafSpace.s4;

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
            // R32：返回图标改用自绘里程图标（24 网格、1.5 描边）。
            child: MileafIcon(
              MileafIconName.back,
              size: MileafIconMetrics.nav,
              color: context.colors.textMuted,
            ),
          ),
        ),
      ),
      child: BackButton(
        onPressed: widget.onPressed,
        color: context.colors.textMuted,
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          minimumSize: WidgetStatePropertyAll(
            Size.square(MileafLayout.touchTarget(context)),
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

/// R28 菜单圆角（tokens 无 14 档，R28 明确规定 14）。
const _menuRadius = 14.0;

/// 尾部「更多」入口：把第二个及以后的操作收进 R28 菜单。
class _MoreMenuButton extends StatefulWidget {
  const _MoreMenuButton({required this.entries});

  final List<MileafNavigationMenuEntry> entries;

  @override
  State<_MoreMenuButton> createState() => _MoreMenuButtonState();
}

class _MoreMenuButtonState extends State<_MoreMenuButton> {
  final _anchorKey = GlobalKey();

  Future<void> _open() async {
    final box = _anchorKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final selected = await Navigator.of(
      context,
    ).push<String>(_MileafMenuRoute(anchor: anchor, entries: widget.entries));
    if (selected == null || !mounted) return;
    for (final entry in widget.entries) {
      if (entry.label == selected) entry.onSelected();
    }
  }

  @override
  Widget build(BuildContext context) => MileafIconButton(
    key: _anchorKey,
    icon: MileafIconName.more,
    tooltip: '更多',
    onPressed: _open,
  );
}

class _MileafMenuRoute extends PopupRoute<String> {
  _MileafMenuRoute({required this.anchor, required this.entries});

  final Rect anchor;
  final List<MileafNavigationMenuEntry> entries;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String get barrierLabel => '关闭菜单';

  // M05：弹层/菜单进入 280ms、退出 220ms。
  @override
  Duration get transitionDuration => MileafDurations.sheetIn;

  @override
  Duration get reverseTransitionDuration => MileafDurations.sheetOut;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => CustomSingleChildLayout(
    delegate: _MenuLayout(anchor),
    child: _MileafMenuCard(entries: entries),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 减少动效时 M05 的时长归零：直接给出终态。
    if (MileafLayout.reduceMotion(context)) return child;
    return FadeTransition(opacity: animation, child: child);
  }
}

class _MenuLayout extends SingleChildLayoutDelegate {
  const _MenuLayout(this.anchor);

  final Rect anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.min(280, constraints.maxWidth - 2 * MileafSpace.s16),
        maxHeight: math.max(0, constraints.maxHeight - 2 * MileafSpace.s16),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = math.min(
      anchor.right - childSize.width,
      size.width - childSize.width - MileafSpace.s16,
    );
    final top = math.min(
      anchor.bottom + MileafSpace.s8,
      size.height - childSize.height - MileafSpace.s16,
    );
    return Offset(
      math.max(MileafSpace.s16, left),
      math.max(MileafSpace.s16, top),
    );
  }

  @override
  bool shouldRelayout(covariant _MenuLayout oldDelegate) =>
      oldDelegate.anchor != anchor;
}

class _MileafMenuCard extends StatelessWidget {
  const _MileafMenuCard({required this.entries});

  final List<MileafNavigationMenuEntry> entries;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final radius = BorderRadius.circular(_menuRadius);
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: radius,
          boxShadow: colors.sheetShadow,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in entries)
                Semantics(
                  button: true,
                  label: entry.label,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(entry.label),
                    highlightColor: colors.pressOverlay,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MileafSpace.s16,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            entry.label,
                            style: context.type.body.copyWith(
                              color: colors.text,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// R26：二级导航的磨砂底层。Scaffold 已装 ScrollNotificationObserver，这里
/// 沿用 AppBar 的判据（滚动越过顶部）决定是否换成磨砂；未滚过时就是 canvas
/// 实色，静止观感与既有页面一致（R24：贴在内容上的导航不投阴影）。
class _SecondaryChrome extends StatefulWidget {
  const _SecondaryChrome();

  @override
  State<_SecondaryChrome> createState() => _SecondaryChromeState();
}

class _SecondaryChromeState extends State<_SecondaryChrome> {
  ScrollNotificationObserverState? _observer;
  bool _scrolledUnder = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final observer = ScrollNotificationObserver.maybeOf(context);
    if (observer == _observer) return;
    _observer?.removeListener(_handleScroll);
    _observer = observer;
    _observer?.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _observer?.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll(ScrollNotification notification) {
    if (notification.depth != 0) return;
    final under = notification.metrics.extentBefore > 0;
    if (under == _scrolledUnder) return;
    setState(() => _scrolledUnder = under);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    return Column(
      children: [
        Expanded(
          child: NavigationMaterial(
            borderRadius: BorderRadius.zero,
            forceSolid: !_scrolledUnder,
            solidColor: colors.canvas,
            elevated: false,
            child: const SizedBox.expand(),
          ),
        ),
        SizedBox(
          height: hairline,
          child: ColoredBox(
            color: _scrolledUnder ? colors.line : Colors.transparent,
          ),
        ),
      ],
    );
  }
}
