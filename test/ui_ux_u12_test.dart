import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/workspace.dart';

import 'reading_continuity_test.dart' show workspaceClient;
import 'drives_test.dart' show jsonResponse;
import 'support/session_store.dart';
import 'support/vehicle_preferences.dart';
import 'support/test_trust_store.dart' show MemoryTrustStore;

void main() {
  testWidgets('U12 减动效初始化等待时只显示静态加载文字', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final calendar = Completer<CalendarContext>();
    final store = MemorySessionStore()
      ..value = jsonEncode({
        'site': 'https://example.com/prefix',
        'token': 'test',
        'expires_at': '2099-01-01T00:00:00Z',
      });
    await tester.pumpWidget(
      MileafApp(
        client: workspaceClient([], (request) async => jsonResponse('{}')),
        sessionStore: store,
        trustStore: MemoryTrustStore(),
        vehiclePreferences: MemoryVehiclePreferences(),
        calendar: () => calendar.future,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('正在加载车辆…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
    calendar.complete(CalendarContext('Asia/Shanghai'));
    await tester.pump();
  });
  for (final brightness in Brightness.values) {
    testWidgets('U12 $brightness 图表Tab焦点首帧可见且边界对比达标', (tester) async {
      final colors = brightness == Brightness.light
          ? const MileafColors.light()
          : const MileafColors.dark();
      for (final background in [colors.canvas, colors.surface]) {
        final luminances = [
          colors.focusRing.computeLuminance(),
          background.computeLuminance(),
        ]..sort();
        expect(
          (luminances.last + 0.05) / (luminances.first + 0.05),
          greaterThanOrEqualTo(3),
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(brightness),
          home: Scaffold(
            body: TimeSeriesChart(
              title: '每日里程',
              unit: 'km',
              semanticsLabel: '每日里程图',
              times: [DateTime.utc(2026, 11, 1), DateTime.utc(2026, 11, 2)],
              series: const [
                ChartSeries(label: '里程', values: [0, 12]),
              ],
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final ring = find
          .descendant(
            of: find.byType(MileafFocusRing),
            matching: find.byType(DecoratedBox),
          )
          .first;
      final decoration =
          tester.widget<DecoratedBox>(ring).decoration as BoxDecoration;
      expect(decoration.border!.top.color, colors.focusRing);
      expect(decoration.border!.top.width, 2);
    });
    testWidgets('R12→R22 $brightness 浮动标签实际字号保持15且跟随大字', (tester) async {
      for (final scale in [1.0, 2.0]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: mileafTheme(brightness),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Scaffold(
                body: TextField(
                  autofocus: true,
                  decoration: InputDecoration(labelText: '服务地址'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final label = find.text('服务地址');
        final paragraph = tester.renderObject<RenderParagraph>(label);
        final transform = paragraph.getTransformTo(null);
        final verticalScale = transform.entry(1, 1).abs();
        final text = paragraph.text as TextSpan;
        // R22 收口（AP14）：浮动标签随字段名角色迁到 subheadline（15/21）。
        expect(text.style!.fontSize! * verticalScale, closeTo(15, 0.01));
        expect(paragraph.textScaler.scale(15), closeTo(15 * scale, 0.01));
      }
    });

    testWidgets('U12 $brightness 禁用按钮每帧同步文字和背景', (tester) async {
      final enabled = ValueNotifier(true);
      addTearDown(enabled.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(brightness),
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: enabled,
              builder: (context, value, child) => FilledButton(
                onPressed: value ? () {} : null,
                child: const Text('验证并替换连接'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final style = Theme.of(tester.element(find.byType(FilledButton)))
          .filledButtonTheme
          .style!;
      expect(tester.getSize(find.byWidget(button)).height, 48);
      expect(
        style.padding!.resolve({}),
        const EdgeInsets.symmetric(horizontal: 16),
      );
      expect(style.textStyle!.resolve({})!.fontWeight, FontWeight.w500);
      expect(
        (style.shape!.resolve({}) as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(12),
      );
      final colors = brightness == Brightness.light
          ? const MileafColors.light()
          : const MileafColors.dark();
      for (final value in [false, true, false]) {
        enabled.value = value;
        await tester.pump();
        for (var frame = 0; frame < 14; frame++) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text('验证并替换连接'),
          );
          expect(
            (paragraph.text as TextSpan).style!.color,
            value ? colors.textOnAccent : colors.textFaint,
          );
          await tester.pump(const Duration(milliseconds: 16));
        }
      }
    });
  }
}
