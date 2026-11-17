import 'package:flutter/material.dart';

import '../icons.dart';
import '../semantic.dart';
import '../tokens.dart';

/// The one current-state block per page. Keeps it on the ordinary content
/// surface in both appearances, with the R24/PD06 20px container radius
/// ([MileafRadius.lg]). Status graphics (bolt / moon / offline) come from the
/// page's shared icons inside [child]; the card itself owns only the surface.
class MileafHero extends StatelessWidget {
  const MileafHero({super.key, required this.child, this.semanticLabel});

  final Widget child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final surface = Material(
      color: colors.hero,
      borderRadius: BorderRadius.circular(MileafRadius.lg),
      clipBehavior: Clip.hardEdge,
      child: semanticLabel == null
          ? child
          : Semantics(container: true, label: semanticLabel, child: child),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MileafSpace.cardInset),
      child: surface,
    );
  }
}

/// R31/P01 车况状态图形：充电中闪电、休眠月亮、离线离线图形；不再用圆点。
enum VehicleStatusKind { charging, sleeping, offline }

/// R31/P01：状态图形到 AP01 自绘图标的映射（页面按车况状态选其一）。
MileafIconName vehicleStatusIcon(VehicleStatusKind kind) => switch (kind) {
  VehicleStatusKind.charging => MileafIconName.bolt,
  VehicleStatusKind.sleeping => MileafIconName.moon,
  VehicleStatusKind.offline => MileafIconName.offline,
};

/// Default card box used by the design gallery. Real pages may pass their own
/// vertical rhythm through [MileafHero].
EdgeInsets mileafHeroPadding(BuildContext context) => const EdgeInsets.fromLTRB(
  MileafSpace.cardPad,
  MileafSpace.s20,
  MileafSpace.cardPad,
  MileafSpace.s20,
);
