import 'package:flutter/material.dart';

import '../brand_mark.dart';
import '../icons.dart';
import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';
import 'icon_button.dart';

/// Brand / vehicle / settings header.
///
/// Overview embeds it inside the dark hero (`onHero`); other tabs place it on
/// the canvas. There is no second refresh action here.
class MileafTopBar extends StatelessWidget {
  const MileafTopBar({
    super.key,
    required this.vehicleName,
    required this.onVehicle,
    required this.onSettings,
    this.onHero = false,
    this.includeTopInset = true,
  });

  final String vehicleName;
  final VoidCallback? onVehicle;
  final VoidCallback onSettings;
  final bool onHero;
  final bool includeTopInset;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final top = includeTopInset ? MediaQuery.paddingOf(context).top : 0.0;
    final foreground = onHero ? colors.heroText : colors.text;
    final secondary = onHero ? colors.heroMuted : colors.textMuted;
    final faint = onHero ? colors.heroFaint : colors.textFaint;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MileafLayout.pageInset(context),
        top + MileafSpace.s12,
        MileafLayout.pageInset(context),
        MileafSpace.s12,
      ),
      child: MileafContent(
        child: Row(
          children: [
            BrandMark(
              size: MileafIconMetrics.brandDefault,
              color: onHero ? colors.accentHero : colors.accent,
            ),
            const SizedBox(width: MileafSpace.s8),
            Text(
              '行笺',
              style: type.title.copyWith(
                fontSize: MileafBrand.wordSize,
                height: 1.1,
                letterSpacing: MileafBrand.wordTracking * MileafBrand.wordSize,
                color: foreground,
              ),
            ),
            const SizedBox(width: MileafSpace.s12),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  button: true,
                  label: '选择车辆，$vehicleName',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: MileafSpace.touch,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: MileafRadius.smAll,
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onVehicle,
                        borderRadius: MileafRadius.smAll,
                        highlightColor: onHero
                            ? colors.accentHero.withValues(alpha: .12)
                            : colors.accentSoft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: MileafSpace.s4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  vehicleName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: type.body.copyWith(color: secondary),
                                ),
                              ),
                              const SizedBox(width: MileafSpace.s4),
                              Transform.rotate(
                                angle: 1.5707963267948966,
                                child: MileafIcon(
                                  MileafIconName.chevron,
                                  size: MileafIconMetrics.inline,
                                  color: faint,
                                ),
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
            MileafIconButton(
              icon: MileafIconName.settings,
              tooltip: '设置',
              size: MileafIconMetrics.nav,
              color: secondary,
              onPressed: onSettings,
            ),
          ],
        ),
      ),
    );
  }
}
