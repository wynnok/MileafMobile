import 'package:flutter/material.dart';

import '../icons.dart';
import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';
import 'glass_surface.dart';
import 'navigation_material.dart';

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
class MileafNavBar extends StatelessWidget {
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

  final int index;
  final ValueChanged<int> onSelected;
  final bool forceSolid;
  final List<MileafNavItem> items;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    final target = MileafLayout.rootNavigationHeight(context);
    final bottom = MediaQuery.viewPaddingOf(context).bottom + MileafSpace.s8;
    final solid = NavigationMaterial.resolvesSolid(
      context,
      forceSolid: forceSolid,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(MileafSpace.s16, 0, MileafSpace.s16, bottom),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 528),
          child: NavigationMaterial(
            borderRadius: MileafRadius.fullAll,
            forceSolid: forceSolid,
            style: NavigationMaterialStyle.glass,
            child: SizedBox(
              height: target,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final count = items.length;
                  final itemWidth = constraints.maxWidth / count;
                  final alignment = count <= 1
                      ? Alignment.center
                      : Alignment(-1 + 2 * index / (count - 1), 0);
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
                            vertical: MileafSpace.inline6,
                          ),
                          child: _LensStretch(
                            index: index,
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
                        children: [
                          for (var i = 0; i < count; i++)
                            Expanded(
                              child: _NavItem(
                                item: items[i],
                                active: i == index,
                                labelStyle: type.navLabel,
                                onTap: () => onSelected(i),
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
    required this.onTap,
  });

  final MileafNavItem item;
  final bool active;
  final TextStyle labelStyle;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // 玻璃底会把饱和内容带进来（浅色实测最低 4.25:1），未选目的地因此比
    // 实色页面上的次级文字再深一档：textMuted 在两种模式下都 ≥4.9:1。
    final iconColor = widget.active ? colors.accent : colors.textMuted;
    final labelColor = widget.active ? colors.accentStrong : colors.textMuted;
    return Semantics(
      button: true,
      selected: widget.active,
      label: widget.item.label,
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
                    color: iconColor,
                  ),
                  const SizedBox(height: MileafSpace.s4),
                  Text(
                    widget.item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: widget.labelStyle.copyWith(color: labelColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
