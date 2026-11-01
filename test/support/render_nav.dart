import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/collage.dart';

/// 打开统计页并点进 C 的 2×2 章节卡专题。
///
/// 专题入口是 `InkWell + CollageTile` 的章节卡；`chapters()` 的 busy/error 分支
/// 仍用 TextButton，不能作为稳定定位器。集中在这里，页面改版时只改一处。
Future<void> openStatisticsTopic(
  WidgetTester tester,
  String title, {
  double delta = 160,
  Finder? scrollable,
}) async {
  await tester.tap(find.text('统计').last);
  await tester.pumpAndSettle();
  final card = find.widgetWithText(CollageTile, title);
  await tester.scrollUntilVisible(
    card.hitTestable(),
    delta,
    scrollable: scrollable ?? find.byType(Scrollable).first,
  );
  await tester.tap(card);
  await tester.pumpAndSettle();
}

/// 展开折叠层（如「过程数据说明」「数据说明与更多」）并滚到可见处。
Future<void> expandCollapsible(
  WidgetTester tester,
  String title, {
  double delta = 180,
  Finder? scrollable,
}) async {
  final header = find.text(title).hitTestable();
  await tester.scrollUntilVisible(
    header,
    delta,
    scrollable: scrollable ?? find.byType(Scrollable).first,
  );
  await tester.tap(header);
  await tester.pumpAndSettle();
}
