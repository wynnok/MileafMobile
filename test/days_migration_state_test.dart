import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/copy/state_feedback.dart';
import 'package:mileaf/src/design/components/state_view.dart';
import 'package:mileaf/src/design/icons.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';

/// MG09 状态诚实三要素（DM04）：
/// StateView / InlineBanner 的现状句 + 时间或原因行 + 下一步动作槽，
/// 以及空态四档文案构造（CP07 语气）与受限色彩映射。
void main() {
  final dark = const MileafColors.dark();

  Future<void> pumpComponent(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.dark,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: mileafTheme(brightness),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('StateView 三要素（MG09）', () {
    testWidgets('整页态：时间或原因行位于说明与主按钮之间', (tester) async {
      final semantics = tester.ensureSemantics();
      var retry = 0;
      await pumpComponent(
        tester,
        StateView(
          kind: StateViewKind.empty,
          title: '这段时间没有行程',
          message: '换一个区间或下拉刷新',
          statusLine: '数据截至 14:02',
          actionLabel: '重试',
          onAction: () => retry++,
        ),
      );
      expect(find.text('数据截至 14:02'), findsOneWidget);
      // 朗读顺序：说明 -> 时间行 -> 主按钮（按渲染几何自上而下）。
      final messageTop = tester.getTopLeft(find.text('换一个区间或下拉刷新')).dy;
      final statusTop = tester.getTopLeft(find.text('数据截至 14:02')).dy;
      final actionTop = tester.getTopLeft(find.text('重试')).dy;
      expect(messageTop, lessThan(statusTop));
      expect(statusTop, lessThan(actionTop));
      await tester.tap(find.text('重试'));
      expect(retry, 1);
      semantics.dispose();
    });

    testWidgets('整页态：不传时间行时既有渲染零变化', (tester) async {
      await pumpComponent(
        tester,
        const StateView(
          kind: StateViewKind.empty,
          title: '这段时间没有行程',
          message: '换一个区间或下拉刷新',
        ),
      );
      expect(find.text('数据截至 14:02'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('compact 态：文字动作槽 accentStrong 且命中 ≥44', (tester) async {
      var taps = 0;
      await pumpComponent(
        tester,
        StateView(
          kind: StateViewKind.empty,
          compact: true,
          title: '这段时间没有充电记录',
          textActionLabel: '重试',
          onTextAction: () => taps++,
        ),
      );
      final buttonFinder = find.ancestor(
        of: find.text('重试'),
        matching: find.byType(TextButton),
      );
      final button = tester.widget<TextButton>(buttonFinder);
      expect(button.style?.foregroundColor?.resolve({}), dark.accentStrong);
      final size = tester.getSize(buttonFinder);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      await tester.tap(find.text('重试'));
      expect(taps, 1);
    });

    testWidgets('compact 态：时间或原因行为 footnote 档', (tester) async {
      await pumpComponent(
        tester,
        const StateView(
          kind: StateViewKind.empty,
          compact: true,
          title: '这段时间没有充电记录',
          statusLine: '数据截至 14:02',
        ),
      );
      final status = tester.widget<Text>(find.text('数据截至 14:02'));
      expect(status.style?.fontSize, isNotNull);
      // footnote 档小于 compact 标题的 headline 档。
      final title = tester.widget<Text>(find.text('这段时间没有充电记录'));
      expect(status.style!.fontSize!, lessThan(title.style!.fontSize!));
    });
  });

  group('InlineBanner 三要素（MG09）', () {
    testWidgets('正文 + 时间行 + 动作可点，朗读顺序正文在前', (tester) async {
      final semantics = tester.ensureSemantics();
      var retry = 0;
      await pumpComponent(
        tester,
        InlineBanner(
          message: '没能更新，显示的是 10:02 的数据',
          statusLine: '数据截至 14:02',
          actionLabel: '重试',
          onAction: () => retry++,
        ),
      );
      expect(find.text('数据截至 14:02'), findsOneWidget);
      // 朗读顺序按深度优先遍历（语义树同序）：正文 -> 时间行 -> 动作。
      int indexOfText(String data) => tester.allElements.toList().indexWhere(
        (e) => e.widget is Text && (e.widget as Text).data == data,
      );
      final message = indexOfText('没能更新，显示的是 10:02 的数据');
      final status = indexOfText('数据截至 14:02');
      final action = indexOfText('重试');
      expect(message, lessThan(status));
      expect(status, lessThan(action));
      await tester.tap(find.text('重试'));
      expect(retry, 1);
      semantics.dispose();
    });

    testWidgets('不传时间行时正文流零变化', (tester) async {
      await pumpComponent(
        tester,
        const InlineBanner(message: '没能更新，显示的是 10:02 的数据'),
      );
      expect(find.text('数据截至 14:02'), findsNothing);
    });

    testWidgets('neutral 不产生彩色（图标与正文同为 textSecondary）', (tester) async {
      await pumpComponent(tester, const InlineBanner(message: '扩展能力暂未确认'));
      final icon = tester.widget<MileafIcon>(find.byType(MileafIcon));
      expect(icon.color, dark.textSecondary);
      final text = tester.widget<Text>(find.text('扩展能力暂未确认'));
      expect(text.style?.color, dark.textSecondary);
    });

    testWidgets('受限四档映射到固定语义色（转发 DM01 解析器）', (tester) async {
      final expected = {
        BannerTone.neutral: dark.textSecondary,
        BannerTone.warning: dark.warning,
        BannerTone.error: dark.error,
        BannerTone.accent: dark.accentStrong,
      };
      for (final entry in expected.entries) {
        await pumpComponent(
          tester,
          InlineBanner(message: '扩展能力暂未确认', tone: entry.key),
        );
        final icon = tester.widget<MileafIcon>(find.byType(MileafIcon));
        expect(icon.color, entry.value, reason: 'tone \${entry.key.name}');
      }
    });

    test('BannerTone 四档与 DM01 MileafStatusTone 解析结果一致', () {
      final forward = {
        BannerTone.neutral: MileafStatusTone.neutral,
        BannerTone.warning: MileafStatusTone.warning,
        BannerTone.error: MileafStatusTone.error,
        BannerTone.accent: MileafStatusTone.accent,
      };
      for (final entry in forward.entries) {
        expect(
          entry.key.statusTone,
          entry.value,
          reason: 'BannerTone.\${entry.key.name} 转发到 MileafStatusTone',
        );
        // 转发后取色走 DM01 全站唯一映射表，不再有本地映射。
        expect(
          entry.key.statusTone.resolveColor(dark),
          entry.value.resolveColor(dark),
        );
      }
      // MG02 守卫口径：neutral 不产生彩色。
      expect(
        MileafStatusTone.neutral.resolveColor(dark),
        isNot(anyOf(dark.accent, dark.accentStrong, dark.warning, dark.error)),
      );
    });
  });

  group('空态分档文案构造（CP07 语气）', () {
    test('离线：现状句 + 重试', () {
      final copy = emptyStateCopy(EmptyStateTier.offline);
      expect(copy.status, '网络不可用，显示的是缓存数据');
      expect(copy.action, '重试');
    });

    test('加载失败：复用 readFailedMessage + 重试', () {
      final copy = emptyStateCopy(EmptyStateTier.loadFailed, object: '行程');
      expect(copy.status, '没能读取行程');
      expect(copy.action, '重试');
    });

    test('无数据：复用 emptyMessage + 刷新', () {
      final copy = emptyStateCopy(EmptyStateTier.noData, object: '充电记录');
      expect(copy.status, '这段时间没有充电记录');
      expect(copy.action, '刷新');
    });

    test('筛选无结果：现状句 + 调整筛选', () {
      final copy = emptyStateCopy(EmptyStateTier.filterNoMatch, object: '行程');
      expect(copy.status, '筛选后没有行程');
      expect(copy.action, '调整筛选');
    });

    test('对象名缺省为「数据」', () {
      expect(emptyStateCopy(EmptyStateTier.loadFailed).status, '没能读取数据');
      expect(emptyStateCopy(EmptyStateTier.noData).status, '这段时间没有数据');
      expect(emptyStateCopy(EmptyStateTier.filterNoMatch).status, '筛选后没有数据');
    });

    test('时间句：数据截至 HH:mm', () {
      expect(dataAsOfLine(DateTime(2026, 11, 19, 14, 2)), '数据截至 14:02');
      expect(dataAsOfLine(DateTime(2026, 11, 19, 9, 5)), '数据截至 09:05');
    });
  });

  group('减动效（本组件无时间动画）', () {
    testWidgets('StateView 不持有 AnimationController，减动效下无任何 ticker', (
      tester,
    ) async {
      expect(StateView(kind: StateViewKind.empty), isA<StatelessWidget>());
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        () => tester.binding.platformDispatcher
            .clearAccessibilityFeaturesTestValue(),
      );
      await pumpComponent(
        tester,
        StateView(
          kind: StateViewKind.empty,
          title: '这段时间没有行程',
          message: '换一个区间或下拉刷新',
          statusLine: '数据截至 14:02',
          actionLabel: '重试',
          textActionLabel: '调整筛选',
          onTextAction: () {},
        ),
      );
      // 首帧即完整内容：没有时间动画，就没有活动的 ticker。
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    });
  });
}
