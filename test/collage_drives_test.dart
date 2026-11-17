import 'package:mileaf/src/drive_detail_page.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'drives_test.dart' show openDrives, jsonResponse;

void main() {
  testWidgets('C行程首屏主数节奏与最近路线可直接下钻', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await openDrives(
      tester,
      (r) async => jsonResponse(
        File(
          r.url.path.endsWith('/17')
              ? 'test/fixtures/drive-detail.json'
              : r.url.path.endsWith('/series')
              ? 'test/fixtures/drive-series.json'
              : 'test/fixtures/drives.json',
        ).readAsStringSync(),
      ),
    );
    // P02：记录按天分组（分组标题 CP04 DF2），每趟仍可直接下钻。
    expect(find.text('今天'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('drive-17')).hitTestable(),
      findsOneWidget,
    );
    expect(find.textContaining('归期时区：').hitTestable(), findsNothing);
    // 节奏卡已移到记录之后：先到记录，再向下到「每日里程」。
    await tester.scrollUntilVisible(find.text('每日里程').hitTestable(), 200);
    expect(find.text('每日里程').hitTestable(), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('drive-17')).hitTestable(),
      -200,
    );
    await tester.tap(find.byKey(const ValueKey('drive-17')));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is DriveDetailPage && widget.id == 17,
      ),
      findsOneWidget,
    );
  });
}
