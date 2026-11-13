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
    expect(find.text('最近的路').hitTestable(), findsOneWidget);
    expect(find.text('出行节奏').hitTestable(), findsOneWidget);
    expect(find.textContaining('归期时区：').hitTestable(), findsNothing);
    expect(
      find.byKey(const ValueKey('drive-17')).hitTestable(),
      findsOneWidget,
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
