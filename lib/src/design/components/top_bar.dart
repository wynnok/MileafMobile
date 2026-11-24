import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../icons.dart';
import '../layout.dart';
import '../motion.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';
import 'glass_surface.dart';
import 'large_content_viewer.dart';
import 'navigation_material.dart';

/// Root page shell: collapsible large title, vehicle lens capsule and settings
/// circle (R26/PD01).
///
/// 展开态与 canvas 同底；滚动 0–16 期间大标题与收起标题交叉淡出、磨砂材质与
/// 分隔线从 0 到 1、外壳高度随之插值（M03，减少动效在 8 处直接切换）。滚动由
/// [scrollListenable] 驱动：外壳自己监听并只重建自己，页面与工作区不重建。
class MileafTopBar extends StatefulWidget {
  const MileafTopBar({
    super.key,
    this.title = '概览',
    required this.vehicleName,
    required this.onVehicle,
    required this.onSettings,
    this.onHero = false,
    this.includeTopInset = true,
    this.forceSolid = false,
    this.scrollListenable,
  });

  final String title;
  final String vehicleName;
  final VoidCallback? onVehicle;
  final VoidCallback onSettings;
  final bool onHero;
  final bool includeTopInset;
  final bool forceSolid;

  /// 根页滚动位置（逻辑像素）。为空时外壳停在展开态。
  final ValueListenable<double>? scrollListenable;

  @override
  State<MileafTopBar> createState() => _MileafTopBarState();
}

class _MileafTopBarState extends State<MileafTopBar> {
  MileafLargeContentViewerHost? _viewer;
  final _collapsedTitleKey = GlobalKey();

  @override
  void dispose() {
    _viewer?.dispose();
    super.dispose();
  }

  void _showViewer(String label) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final host = _viewer ??= MileafLargeContentViewerHost(overlay);
    host.show(label: label);
  }

  void _hideViewer() => _viewer?.hide();

  /// M10「抬手或移出即消失」：长按期间一旦移出目标范围就收起浮层。
  void _hideViewerIfOutside(Offset global, GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      _hideViewer();
      return;
    }
    if (!(Offset.zero & box.size).contains(box.globalToLocal(global))) {
      _hideViewer();
    }
  }

  /// 0（展开）到 1（收起）；减少动效时在 8 处直接切换。
  double _progress(BuildContext context, double scroll) {
    if (MileafLayout.reduceMotion(context)) {
      return scroll >= MileafMotion.collapseScroll / 2 ? 1 : 0;
    }
    return (scroll / MileafMotion.collapseScroll).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final listenable = widget.scrollListenable;
    if (listenable == null) return _build(context, 0);
    return ValueListenableBuilder<double>(
      valueListenable: listenable,
      builder: (context, value, _) => _build(context, value),
    );
  }

  Widget _build(BuildContext context, double scroll) {
    final colors = context.colors;
    final type = context.type;
    final scaler = MediaQuery.textScalerOf(context);
    final top = widget.includeTopInset
        ? MediaQuery.paddingOf(context).top
        : 0.0;
    final progress = _progress(context, scroll);
    final large = MileafLayout.largeText(context);
    final insets = MileafLayout.pageInset(context);
    final solid = NavigationMaterial.resolvesSolid(
      context,
      forceSolid: widget.forceSolid,
    );
    final titleColor = widget.onHero ? colors.heroText : colors.text;
    final touch = MileafLayout.touchTarget(context);
    final titleHeight = scaler.scale(MileafType.largeTitleHeight);
    final collapsedTitleHeight = MileafLayout.rootChromeLabelScaler(context)
        .scale(MileafType.headlineHeight);
    final gapTop = MileafSpace.s8 * (1 - progress);
    final gapBottom = MileafSpace.s8 * (1 - progress);

    final expandedTitle = Text(
      widget.title,
      key: const ValueKey('top-bar-expanded-title'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: type.largeTitle.copyWith(color: titleColor),
    );
    final collapsedTitle = MediaQuery(
      key: _collapsedTitleKey,
      data: MediaQuery.of(context)
          .copyWith(textScaler: MileafLayout.rootChromeLabelScaler(context)),
      child: GestureDetector(
        onLongPressStart: (_) => _showViewer(widget.title),
        onLongPressMoveUpdate: (details) =>
            _hideViewerIfOutside(details.globalPosition, _collapsedTitleKey),
        onLongPressEnd: (_) => _hideViewer(),
        child: Text(
          widget.title,
          key: const ValueKey('top-bar-collapsed-title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: type.headline.copyWith(color: titleColor),
        ),
      ),
    );

    final double rowHeight;
    final double titleRow;
    final Widget controls;
    final Widget titleArea;
    if (large) {
      // 大字：控件一行靠右，大标题独占下一行；收起后只保留控件。
      rowHeight = touch;
      titleRow = progress < 1 ? titleHeight * (1 - progress) : 0;
      controls = Padding(
        padding: EdgeInsets.symmetric(horizontal: insets),
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: _controls(context, solid: solid),
        ),
      );
      titleArea = progress < 1
          ? ClipRect(
              child: SizedBox(
                height: titleRow,
                child: OverflowBox(
                  alignment: AlignmentDirectional.topStart,
                  minHeight: titleHeight,
                  maxHeight: titleHeight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: insets),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: expandedTitle,
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink();
    } else {
      // 普通字号：标题与两个控件同一行，标题在两种角色之间交叉淡出。
      rowHeight = math.max(
        touch,
        math.max(titleHeight * (1 - progress), collapsedTitleHeight * progress),
      );
      titleRow = 0;
      controls = const SizedBox.shrink();
      titleArea = const SizedBox.shrink();
    }

    final Widget row = large
        ? SizedBox(height: rowHeight, child: controls)
        : SizedBox(
            height: rowHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: insets),
              child: LayoutBuilder(
                builder: (context, constraints) => Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: rowHeight,
                        child: ClipRect(
                          child: Stack(
                            alignment: AlignmentDirectional.centerStart,
                            children: [
                              if (progress < 1)
                                Opacity(
                                  key: const ValueKey('top-bar-expanded-layer'),
                                  opacity: 1 - progress,
                                  child: expandedTitle,
                                ),
                              if (progress > 0)
                                Opacity(
                                  key: const ValueKey(
                                    'top-bar-collapsed-layer',
                                  ),
                                  opacity: progress,
                                  child: collapsedTitle,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: MileafSpace.s12),
                    _controls(
                      context,
                      solid: solid,
                      maxCapsule: constraints.maxWidth * .45,
                    ),
                  ],
                ),
              ),
            ),
          );

    // 高度与布局函数同源：展开态取 rootTopBarHeight、收起态取
    // rootTopBarCollapsedHeight，中间按滚动进度插值（页面顶部留白仍用展开态）。
    final expanded = MileafLayout.rootTopBarHeight(context, topInset: top);
    final collapsed = MileafLayout.rootTopBarCollapsedHeight(
      context,
      topInset: top,
    );
    final contentHeight = expanded + (collapsed - expanded) * progress;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: top),
        SizedBox(height: gapTop),
        row,
        if (large) titleArea,
        if (large) SizedBox(height: MileafSpace.s4 * (1 - progress)),
        SizedBox(height: gapBottom),
      ],
    );

    return SizedBox(
      key: const ValueKey('root-top-bar-surface'),
      height: contentHeight,
      child: ClipRect(
        child: Stack(
          children: [
            if (progress > 0)
              Positioned.fill(
                child: Opacity(
                  opacity: progress,
                  child: NavigationMaterial(
                    style: NavigationMaterialStyle.chrome,
                    borderRadius: BorderRadius.zero,
                    forceSolid: widget.forceSolid,
                    solidColor: colors.canvas,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            PositionedDirectional(
              start: 0,
              end: 0,
              top: 0,
              child: MileafContent(child: content),
            ),
            if (progress > 0)
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 0,
                child: Opacity(
                  key: const ValueKey('top-bar-divider'),
                  opacity: progress,
                  child: SizedBox(
                    height: 1 / MediaQuery.devicePixelRatioOf(context),
                    child: ColoredBox(color: colors.line),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 车辆胶囊 + 设置圆钮。两者都用 ADR0013 选中镜片同款的半透明填充与受光
  /// 边（不另开模糊），实色路径改用 segmentTrack。胶囊宽度上限是外壳宽度的
  /// 45%，由调用方传入的 [maxCapsule] 或本行的约束算出。
  Widget _controls(
    BuildContext context, {
    required bool solid,
    double? maxCapsule,
  }) {
    final capsule = _VehicleCapsule(
      key: const ValueKey('top-bar-vehicle'),
      name: widget.vehicleName,
      solid: solid,
      maxWidth: maxCapsule,
      onTap: widget.onVehicle,
      onLongPress: () => _showViewer(widget.vehicleName),
      onLongPressEnd: _hideViewer,
      onLongPressExit: _hideViewer,
    );
    final settings = _TopBarCircleButton(
      icon: MileafIconName.settings,
      tooltip: '设置',
      solid: solid,
      onPressed: widget.onSettings,
    );
    const gap = SizedBox(width: MileafSpace.s8);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cap = maxCapsule ?? constraints.maxWidth * .45;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: cap),
              child: capsule,
            ),
            gap,
            settings,
          ],
        );
      },
    );
  }
}

/// 车辆切换：镜片胶囊，control 文字 + 向下箭头 12，最大宽度为外壳宽度的 45%。
class _VehicleCapsule extends StatefulWidget {
  const _VehicleCapsule({
    super.key,
    required this.name,
    required this.solid,
    required this.maxWidth,
    required this.onTap,
    required this.onLongPress,
    required this.onLongPressEnd,
    required this.onLongPressExit,
  });

  final String name;
  final bool solid;
  final double? maxWidth;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;
  final VoidCallback onLongPressEnd;
  final VoidCallback onLongPressExit;

  @override
  State<_VehicleCapsule> createState() => _VehicleCapsuleState();
}

class _VehicleCapsuleState extends State<_VehicleCapsule> {
  final _boxKey = GlobalKey();

  /// M10「抬头或移出即消失」：长按期间移出胶囊就收起浮层。
  void _onMove(LongPressMoveUpdateDetails details) {
    final box = _boxKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final local = box.globalToLocal(details.globalPosition);
    if (!(Offset.zero & box.size).contains(local)) {
      widget.onLongPressExit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onLongPressStart: (_) => widget.onLongPress(),
      onLongPressMoveUpdate: _onMove,
      onLongPressEnd: (_) => widget.onLongPressEnd(),
      child: KeyedSubtree(
        key: _boxKey,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: widget.maxWidth ?? double.infinity,
          ),
          child: _lens(
            context,
            solid: widget.solid,
            child: Semantics(
              button: true,
              label: '选择车辆，${widget.name}',
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MileafLayout.touchTarget(context),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: MileafRadius.fullAll,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: widget.onTap,
                    borderRadius: MileafRadius.fullAll,
                    highlightColor: colors.pressOverlay,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MileafSpace.s12,
                        vertical: MileafSpace.s8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                textScaler: MileafLayout.rootChromeLabelScaler(
                                  context,
                                ),
                              ),
                              child: Text(
                                widget.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.type.control.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: MileafSpace.s4),
                          MileafIcon(
                            MileafIconName.chevronDown,
                            size: 12,
                            color: colors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 顶栏圆形图标钮：视觉 36、命中 44/48，镜片填充（R26/R27）。
class _TopBarCircleButton extends StatefulWidget {
  const _TopBarCircleButton({
    required this.icon,
    required this.tooltip,
    required this.solid,
    required this.onPressed,
  });

  final MileafIconName icon;
  final String tooltip;
  final bool solid;
  final VoidCallback? onPressed;

  @override
  State<_TopBarCircleButton> createState() => _TopBarCircleButtonState();
}

class _TopBarCircleButtonState extends State<_TopBarCircleButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = widget.onPressed != null;
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.tooltip,
        child: SizedBox.square(
          dimension: MileafLayout.touchTarget(context),
          child: Focus(
            onFocusChange: (value) => setState(() => _focused = value),
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: _focused
                      ? Border.all(color: colors.focusRing, width: 2)
                      : null,
                ),
                child: _lens(
                  context,
                  solid: widget.solid,
                  circle: true,
                  child: SizedBox.square(
                    dimension: 36,
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: widget.onPressed,
                        customBorder: const CircleBorder(),
                        highlightColor: colors.pressOverlay,
                        child: Center(
                          child: MileafIcon(
                            widget.icon,
                            size: MileafIconMetrics.nav,
                            color: enabled
                                ? colors.textSecondary
                                : colors.textFaint.withValues(alpha: .38),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 顶栏背板已负责背景模糊，控件镜片只绘制边缘和阴影。
Widget _lens(
  BuildContext context, {
  required bool solid,
  required Widget child,
  bool circle = false,
}) {
  final colors = context.colors;
  // 填充层只做背景，控件子树始终在同一个位置：材质在玻璃与实色之间切换时
  // 子树（含 InkWell 的焦点节点）不重建，关闭弹层后的焦点能回到触发控件。
  return Stack(
    fit: StackFit.passthrough,
    children: [
      Positioned.fill(
        child: IgnorePointer(
          child: solid
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.segmentTrack,
                    shape: circle ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: circle ? null : MileafRadius.fullAll,
                  ),
                )
              : MileafGlassSurface.control(
                  borderRadius: MileafRadius.fullAll,
                  blurBackdrop: false,
                  child: const SizedBox.expand(),
                ),
        ),
      ),
      child,
    ],
  );
}

/// workspace.notice 横幅：外壳下方、与页面边距对齐，出现与消失按 M11
/// （高度 200ms + 透明度 160ms）。文案为空时高度归零但留在树里，好让下一次
/// 出现仍然有动画。
class MileafNoticeBanner extends StatelessWidget {
  const MileafNoticeBanner({super.key, required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final message = text;
    final inset = MileafLayout.pageInset(context);
    return AnimatedSize(
      duration: MileafLayout.motion(context, MileafDurations.statusHeight),
      curve: MileafCurves.fade,
      alignment: AlignmentDirectional.topCenter,
      child: AnimatedOpacity(
        duration: MileafLayout.motion(context, MileafDurations.statusOpacity),
        opacity: message == null ? 0 : 1,
        child: message == null
            ? const SizedBox(width: double.infinity, height: 0)
            : ColoredBox(
                color: colors.surface,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    inset,
                    MileafSpace.s12,
                    inset,
                    MileafSpace.s12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MileafIcon(
                        MileafIconName.info,
                        size: MileafIconMetrics.inline,
                        color: colors.warning,
                      ),
                      const SizedBox(width: MileafSpace.s8),
                      Expanded(
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            message,
                            style: context.type.body.copyWith(
                              color: colors.textSecondary,
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
