import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class MileafCurves {
  const MileafCurves._();

  /// 自绘折叠 chevron（map_privacy_page）仍消费；R07 折叠指示箭头为
  /// 160ms easeOutCubic，U10 在 P12 迁移时改用 [MileafDurations.tab] 后
  /// 随 [MileafDurations.enter] 一并删除。
  static const enter = Curves.easeOutCubic;

  /// R16 M05：弹层 280/220ms easeOutCubic（showMileafSheet 的框架路由转场）。
  static const sheet = Curves.easeOutCubic;

  /// §4 M01：按压覆盖层消退。
  static const press = Curves.easeOut;

  /// §4 M02：互斥选中平移。
  static const selection = Curves.easeOutCubic;

  /// §4 M06：折叠内容高度动画。
  static const fold = Curves.easeOutCubic;

  /// §4 M09–M11：读数淡入、大内容查看器与状态条透明度。
  static const fade = Curves.easeOut;
}

/// §4 M01–M12 的缩放、拉伸与收起阈值。时长见 [MileafDurations]，曲线见
/// [MileafCurves]。
abstract final class MileafMotion {
  const MileafMotion._();

  /// M01：胶囊按钮与可点卡片按压缩放到 0.97（PD11 修订 ADR0012 R16 的
  /// 0.98）。组件迁移由持有票完成。
  static const pressScale = .97;

  /// M02：互斥选中起步横向拉伸——底栏镜片 1.06（与液态玻璃镜片拉伸同值）。
  static const navStretch = MileafMaterialMetrics.glassLensStretch;

  /// M02：分段选中底起步横向拉伸 1.04。
  static const segmentStretch = 1.04;

  /// M03：根页标题收起由滚动位置 0–16 驱动（非时间动画）。
  static const collapseScroll = 16.0;

  /// M10：大内容查看器出现时由 0.96 放大到 1。
  static const viewerScale = .96;
}

/// Former 180ms page-entry fade; ADR0011 / R07 replaced page-entry motion
/// with immediate full content, so this is a pure pass-through in every mode
/// (reduce motion or not, the child is complete from the first frame).
///
/// Kept only because two tab bodies still wrap themselves with it —
/// `overview_page.dart` (U04) and `drives_page.dart` (U05) delete the call
/// sites during their migrations; this widget must not come back.
class MileafPageEnter extends StatelessWidget {
  const MileafPageEnter({super.key, required this.child, this.offset = 4});

  final Widget child;

  /// Unused since the entry animation was removed; kept for call-site
  /// compatibility until U04/U05 migrate.
  final double offset;

  @override
  Widget build(BuildContext context) => child;
}
