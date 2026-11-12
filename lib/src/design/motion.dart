import 'package:flutter/material.dart';

abstract final class MileafCurves {
  const MileafCurves._();

  /// 自绘折叠 chevron（map_privacy_page）仍消费；R07 折叠指示箭头为
  /// 160ms easeOutCubic，U10 在 P12 迁移时改用 [MileafDurations.tab] 后
  /// 随 [MileafDurations.enter] 一并删除。
  static const enter = Curves.easeOutCubic;

  /// R07 弹层 240ms easeOutCubic（showMileafSheet 的框架路由转场）。
  static const sheet = Curves.easeOutCubic;
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
