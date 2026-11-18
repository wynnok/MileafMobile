import 'package:flutter/material.dart';

import '../icons.dart';
import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';
import 'glass_surface.dart';
import 'large_content_viewer.dart';
import 'navigation_material.dart';

/// 选中镜片的垂直内边距（原 inline6；镜片几何随底栏冻结，本地化保留原值）。
const double kNavLensVerticalPad = 6.0;

class MileafNavItem {
  const MileafNavItem(this.label, this.icon);
  final String label;
  final MileafIconName icon;
}

/// Floating root navigation: one capsule of liquid glass with one moving lens.
///
/// The bar is a single bounded blur region. Its glass sits above the page, the
/// selection lens sits above the glass, and the four destinations sit above
/// both, so a destination is never painted through glass.
///
/// R26/PD05：标签文字放大封顶 [labelMaxScale]，长按任一项显示大内容查看器
/// （M10）；抬手落在哪一项上就切到哪一项，移出栏外抬手只收起浮层。
class MileafNavBar extends StatefulWidget {
  const MileafNavBar({
    super.key,
    required this.index,
    required this.onSelected,
    this.forceSolid = false,
    this.items = const [
      MileafNavItem('概览', MileafIconName.home),
      MileafNavItem('行程', MileafIconName.car),
      MileafNavItem('充电', MileafIconName.bolt),
      MileafNavItem('统计', MileafIconName.chart),
    ],
  });

  /// 底栏标签的放大封顶（ADR0014 PD05，修订 ADR0013 L09）。
  static const labelMaxScale = MileafLayout.rootChromeLabelMaxScale;

  final int index;
  final ValueChanged<int> onSelected;
  final bool forceSolid;
  final List<MileafNavItem> items;

  @override
  State<MileafNavBar> createState() => _MileafNavBarState();
}

class _MileafNavBarState extends State<MileafNavBar> {
  final _itemsKey = GlobalKey();
  MileafLargeContentViewerHost? _viewer;
  int? _hovered;

  @override
  void dispose() {
    _viewer?.dispose();
    super.dispose();
  }

  MileafLargeContentViewerHost? get _viewerHost {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return null;
    return _viewer ??= MileafLargeContentViewerHost(overlay);
  }

  /// 长按点落在第几项上；栏外返回 null（移出即消失，抬手不切换）。
  int? _indexAt(Offset global) {
    final box = _itemsKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final local = box.globalToLocal(global);
    final size = box.size;
    if (local.dx < 0 || local.dy < 0) return null;
    if (local.dx > size.width || local.dy > size.height) return null;
    final count = widget.items.length;
    if (count == 0) return null;
    final index = (local.dx / (size.width / count)).floor();
    return index.clamp(0, count - 1);
  }

  void _longPressStart(int index) {
    _hovered = index;
    _viewerHost?.show(
      label: widget.items[index].label,
      icon: widget.items[index].icon,
    );
  }

  void _longPressMove(Offset global) {
    final index = _indexAt(global);
    if (index == null) {
      if (_hovered != null) {
        _hovered = null;
        _viewer?.hide();
      }
      return;
    }
    if (index == _hovered) return;
    _hovered = index;
    _viewerHost?.show(
      label: widget.items[index].label,
      icon: widget.items[index].icon,
    );
  }

  void _longPressEnd(Offset global) {
    final index = _indexAt(global);
    _hovered = null;
    _viewer?.hide();
    if (index != null) widget.onSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final target = MileafLayout.rootNavigationHeight(context);
    final bottom = MediaQuery.viewPaddingOf(context).bottom + MileafSpace.s8;
    final solid = NavigationMaterial.resolvesSolid(
      context,
      forceSolid: widget.forceSolid,
    );
    final labelScaler = MileafLayout.rootChromeLabelScaler(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(MileafSpace.s16, 0, MileafSpace.s16, bottom),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 528),
          child: NavigationMaterial(
            borderRadius: MileafRadius.fullAll,
            forceSolid: widget.forceSolid,
            style: NavigationMaterialStyle.glass,
            child: SizedBox(
              height: target,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final count = widget.items.length;
                  final itemWidth = constraints.maxWidth / count;
                  final alignment = count <= 1
                      ? Alignment.center
                      : Alignment(-1 + 2 * widget.index / (count - 1), 0);
                  return Stack(
                    children: [
                      AnimatedAlign(
                        key: const ValueKey('nav-selection'),
                        alignment: alignment,
                        duration: MileafLayout.motion(
                          context,
                          MileafDurations.selection,
                        ),
                        curve: Curves.easeOutCubic,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: MileafSpace.s4,
                            vertical: kNavLensVerticalPad,
                          ),
                          child: _LensStretch(
                            index: widget.index,
                            child: _SelectionLens(
                              solid: solid,
                              borderRadius: MileafRadius.fullAll,
                              width: itemWidth - MileafSpace.s8,
                              height: target - MileafSpace.s12,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        key: _itemsKey,
                        children: [
                          for (var i = 0; i < count; i++)
                            Expanded(
                              child: _NavItem(
                                item: widget.items[i],
                                active: i == widget.index,
                                labelStyle: type.navLabel,
                                labelScaler: labelScaler,
                                onTap: () => widget.onSelected(i),
                                onLongPressStart: (_) => _longPressStart(i),
                                onLongPressMove: (details) =>
                                    _longPressMove(details.globalPosition),
                                onLongPressEnd: (details) =>
                                    _longPressEnd(details.globalPosition),
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The lit capsule that marks the selected destination.
///
/// In the glass path it is a second, denser sheet of glass with its own top
/// edge; in the solid path it falls back to the one neutral selected surface,
/// so the same geometry exists on both sides of the material switch.
class _SelectionLens extends StatelessWidget {
  const _SelectionLens({
    required this.solid,
    required this.borderRadius,
    required this.width,
    required this.height,
  });

  final bool solid;
  final BorderRadius borderRadius;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final box = SizedBox(width: width, height: height);
    if (!solid) {
      return MileafGlassLens(
        key: const ValueKey('nav-selection-surface'),
        borderRadius: borderRadius,
        sheen: true,
        child: box,
      );
    }
    final colors = context.colors;
    final hairline = 1 / MediaQuery.devicePixelRatioOf(context);
    return DecoratedBox(
      key: const ValueKey('nav-selection-surface'),
      decoration: BoxDecoration(
        color: colors.navigationSelection,
        borderRadius: borderRadius,
        border: Border.all(color: colors.navigationBorder, width: hairline),
      ),
      child: box,
    );
  }
}

/// 镜片移动时的黏性：起步时横向略宽，180ms 内回落到自身宽度。
///
/// 减少动效时不产生过冲（控制器停在中值），位置仍由 [AnimatedAlign] 处理。
class _LensStretch extends StatefulWidget {
  const _LensStretch({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_LensStretch> createState() => _LensStretchState();
}

class _LensStretchState extends State<_LensStretch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: 1,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: MileafMaterialMetrics.glassLensStretch,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void didUpdateWidget(covariant _LensStretch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    final duration = MileafLayout.motion(context, MileafDurations.selection);
    if (duration == Duration.zero) {
      _controller.value = 1;
      return;
    }
    _controller.duration = duration;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _scale,
    builder: (context, child) =>
        Transform.scale(scaleX: _scale.value, child: child),
    child: widget.child,
  );
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.item,
    required this.active,
    required this.labelStyle,
    required this.labelScaler,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressMove,
    required this.onLongPressEnd,
  });

  final MileafNavItem item;
  final bool active;
  final TextStyle labelStyle;
  final TextScaler labelScaler;
  final VoidCallback onTap;
  final GestureLongPressStartCallback onLongPressStart;
  final GestureLongPressMoveUpdateCallback onLongPressMove;
  final GestureLongPressEndCallback onLongPressEnd;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 玻璃越薄，背后内容的明度范围越大：未选目的地不能再用页面次级灰
    // （textMuted 在透出的蓝色图表上不足 4.5:1），改用底栏专用的
    // navigationLabel——浅色压深一档、深色提亮一档（L03 修订）。
    // 镜片比底栏更亮，图形若用 accent（对白底 3:1）只剩 3.0:1，因此选中图形
    // 与选中文字同用 accentStrong（浅色首屏实测 5.16:1）。
    final itemColor = widget.active
        ? colors.accentStrong
        : colors.navigationLabel;
    return Semantics(
      button: true,
      selected: widget.active,
      label: widget.item.label,
      child: GestureDetector(
        onLongPressStart: widget.onLongPressStart,
        onLongPressMoveUpdate: widget.onLongPressMove,
        onLongPressEnd: widget.onLongPressEnd,
        child: FocusableActionDetector(
          onShowFocusHighlight: (value) => setState(() => focused = value),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: MileafRadius.fullAll,
              border: Border.all(
                color: focused ? colors.focusRing : Colors.transparent,
                width: 2,
              ),
            ),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: MileafRadius.fullAll,
              highlightColor: colors.pressOverlay,
              splashColor: colors.accentSoft,
              child: ExcludeSemantics(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MileafIcon(
                      widget.item.icon,
                      size: MileafIconMetrics.nav,
                      color: itemColor,
                    ),
                    const SizedBox(height: MileafSpace.s4),
                    MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: widget.labelScaler),
                      child: Text(
                        widget.item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: widget.labelStyle.copyWith(color: itemColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
