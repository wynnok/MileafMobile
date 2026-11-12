import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// [settle] 为 false 时跳过 pumpAndSettle：用于含无限循环（处理中转圈）
/// 的机位，由调用方自行推进固定帧数；默认行为不变。
Future<void> saveRenderPng(
  WidgetTester tester,
  Finder boundary,
  String path, {
  bool settle = true,
}) async {
  if (settle) await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: path);
  final render = tester.renderObject<RenderRepaintBoundary>(boundary);
  await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
