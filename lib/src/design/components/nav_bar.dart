import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../icons.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

class MileafNavItem {
  const MileafNavItem(this.label, this.icon);
  final String label;
  final MileafIconName icon;
}

/// 64px bottom navigation: 20px icon, 9px label, accent + 2px top marker.
class MileafNavBar extends StatelessWidget {
  const MileafNavBar({
    super.key,
    required this.index,
    required this.onSelected,
    this.items = const [
      MileafNavItem('概览', MileafIconName.home),
      MileafNavItem('行程', MileafIconName.car),
      MileafNavItem('充电', MileafIconName.bolt),
      MileafNavItem('统计', MileafIconName.chart),
    ],
  });

  final int index;
  final ValueChanged<int> onSelected;
  final List<MileafNavItem> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: ColoredBox(
          color: colors.nav,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: MileafSpace.navHeight,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: ColoredBox(
                      color: colors.line,
                      child: const SizedBox(height: 1),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _NavItem(
                            item: items[i],
                            active: i == index,
                            labelStyle: type.micro,
                            onTap: () => onSelected(i),
                          ),
                        ),
                    ],
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

class _NavItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Icon keeps `accent`; the label is text and takes `accentStrong` (§7.3).
    final iconColor = active ? colors.accent : colors.textFaint;
    final labelColor = active ? colors.accentStrong : colors.textFaint;
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        highlightColor: colors.accent.withValues(alpha: .12),
        splashColor: colors.accent.withValues(alpha: .12),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            if (active) Container(width: 18, height: 2, color: colors.accent),
            ExcludeSemantics(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  MileafIcon(
                    item.icon,
                    size: MileafIconMetrics.nav,
                    color: iconColor,
                  ),
                  const SizedBox(height: MileafSpace.s4),
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: labelStyle.copyWith(color: labelColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
