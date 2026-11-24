import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/icons.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/tokens.dart';

Future<void> pumpComponent(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.dark,
  double width = 360,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
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

void main() {
  group('MileafHero', () {
    testWidgets('深色车况为同调实色卡片、无光晕且语义可达', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpComponent(
        tester,
        const MileafHero(
          semanticLabel: '车况',
          child: SizedBox(height: 220, child: Text('320 km')),
        ),
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(MileafHero),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, const MileafColors.dark().hero);
      // R04/ADR0011：光晕由实色锚点替代，hero 子树不得再出现渐变装饰。
      expect(
        find.descendant(
          of: find.byType(MileafHero),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                (widget.decoration as BoxDecoration?)?.gradient != null,
          ),
        ),
        findsNothing,
      );
      expect(material.borderRadius, BorderRadius.circular(MileafRadius.lg));
      expect(find.bySemanticsLabel(RegExp('车况')), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('浅色页使用普通内容表面 hero', (tester) async {
      await pumpComponent(
        tester,
        const MileafHero(child: SizedBox(height: 180, child: Text('286 km'))),
        brightness: Brightness.light,
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(MileafHero),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, const MileafColors.light().hero);
      expect(material.color, const MileafColors.light().surface);
    });

    testWidgets('浅色 hero 是 12 外边距、20 圆角、无描边无阴影的卡片', (tester) async {
      await pumpComponent(
        tester,
        const MileafHero(child: SizedBox(height: 180, child: Text('286 km'))),
        brightness: Brightness.light,
      );
      final hero = tester.getRect(find.byType(MileafHero));
      final cardFinder = find
          .descendant(
            of: find.byType(MileafHero),
            matching: find.byType(Material),
          )
          .first;
      final card = tester.getRect(cardFinder);
      final material = tester.widget<Material>(cardFinder);
      expect(card.left - hero.left, MileafSpace.cardInset);
      expect(hero.right - card.right, MileafSpace.cardInset);
      expect(material.borderRadius, BorderRadius.circular(MileafRadius.lg));
      expect(material.shape, isNull);
      expect(material.elevation, 0, reason: '卡片 hero 只有底色，不加阴影');
      expect(material.color, const MileafColors.light().hero);
    });

    testWidgets('浅色卡片 hero 不接管状态栏（页面级 AnnotatedRegion 负责）', (tester) async {
      await pumpComponent(
        tester,
        const MileafHero(child: SizedBox(height: 180, child: Text('286 km'))),
        brightness: Brightness.light,
      );
      expect(
        find.descendant(
          of: find.byType(MileafHero),
          matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        ),
        findsNothing,
        reason: '卡片上方是纸面，状态栏前景由 main.dart 的页面级 region 决定',
      );
    });

    testWidgets('深色 hero 同样采用 12 外边距和 20 圆角', (tester) async {
      await pumpComponent(
        tester,
        const MileafHero(child: SizedBox(height: 200, child: Text('320 km'))),
      );
      final hero = tester.getRect(find.byType(MileafHero));
      final cardFinder = find
          .descendant(
            of: find.byType(MileafHero),
            matching: find.byType(Material),
          )
          .first;
      final card = tester.getRect(cardFinder);
      expect(card.left - hero.left, MileafSpace.cardInset);
      expect(hero.right - card.right, MileafSpace.cardInset);
      expect(
        tester.widget<Material>(cardFinder).borderRadius,
        BorderRadius.circular(MileafRadius.lg),
      );
    });

    testWidgets('浅色卡片 hero 在 320 宽与 200% 下不横向溢出', (tester) async {
      await pumpComponent(
        tester,
        const MileafHero(
          child: Padding(
            padding: EdgeInsets.all(MileafSpace.cardPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('续航估算 320 km · 电量 68%'),
                Text('在线 · 3 分钟前'),
                SizedBox(height: 40),
              ],
            ),
          ),
        ),
        brightness: Brightness.light,
        width: 320,
        scale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('SectionHeader 200% 时标题与范围分行', (tester) async {
    await pumpComponent(
      tester,
      const SectionHeader(title: '每日里程', range: '10.01 — 10.26'),
      scale: 2,
    );
    final title = tester.getRect(find.text('每日里程'));
    final range = tester.getRect(find.text('10.01 — 10.26'));
    expect(range.top, greaterThanOrEqualTo(title.bottom));
    expect(tester.takeException(), isNull);
  });

  group('MileafPeriodHeader', () {
    // R21.4：期间名 + 区间。排法按实际宽度：一行放得下就一行（区间靠右），
    // 放不下时区间整段落到下一行左对齐，两个文本框都不会被挤成两截。
    testWidgets('一行放得下时区间与期间名同线、右端贴内容右沿', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpComponent(
        tester,
        const MileafPeriodHeader(
          label: '近 30 天',
          range: (text: '9月10日\u201310月9日', reading: '9月10日至10月9日'),
        ),
        brightness: Brightness.light,
        width: 500,
      );
      final labelBox = tester.getRect(find.text('近 30 天'));
      final rangeBox = tester.getRect(find.text('9月10日\u201310月9日'));
      expect(rangeBox.top, labelBox.top);
      expect(rangeBox.right, closeTo(480, 0.01), reason: '右端贴内容右沿');
      expect(find.byType(Wrap), findsOneWidget);
      // DF3：读屏读作「至」，不念连接号。
      expect(find.bySemanticsLabel('9月10日至10月9日'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('放不下时区间落到下一行、单行完整、左端贴内容左沿', (tester) async {
      await pumpComponent(
        tester,
        const MileafPeriodHeader(
          label: '近 30 天',
          range: (text: '9月10日\u201310月9日', reading: '9月10日至10月9日'),
        ),
        brightness: Brightness.light,
        width: 220,
      );
      final labelBox = tester.getRect(find.text('近 30 天'));
      final rangeBox = tester.getRect(find.text('9月10日\u201310月9日'));
      expect(rangeBox.top, greaterThan(labelBox.bottom), reason: '整段落到下一行');
      expect(rangeBox.left, labelBox.left);
      expect(
        rangeBox.height,
        lessThan(labelBox.height * 1.2),
        reason: '区间本身不折行',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('整段放不下一行时只在连接号后换行，读屏仍读整段区间', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpComponent(
        tester,
        const MileafPeriodHeader(
          label: '近 30 天',
          range: (text: '9月10日\u201310月9日', reading: '9月10日至10月9日'),
        ),
        brightness: Brightness.light,
        width: 320,
        scale: 2,
      );
      final head = tester.getRect(find.text('9月10日\u2013'));
      final tail = tester.getRect(find.text('10月9日'));
      expect(tail.top, greaterThanOrEqualTo(head.bottom), reason: '在连接号后换行');
      expect(tail.top, isNot(head.top), reason: '不在同一行');
      expect(head.left, tail.left, reason: '两行同左缘');
      expect(head.height, tail.height, reason: '每截日期本身都是一行');
      expect(find.text('9月10日\u201310月9日'), findsNothing);
      expect(
        find.bySemanticsLabel('9月10日至10月9日'),
        findsOneWidget,
        reason: 'DF3 读屏仍读整段区间（连接号读作「至」）',
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('没有区间时只留期间名，不占位', (tester) async {
      await pumpComponent(
        tester,
        const MileafPeriodHeader(label: '近 30 天'),
        brightness: Brightness.light,
      );
      expect(find.text('近 30 天'), findsOneWidget);
      expect(find.textContaining('\u2013'), findsNothing, reason: '读值未到时不造区间');
    });
  });

  group('MetricBlock', () {
    testWidgets('缺失显示破折号，不补零', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpComponent(
        tester,
        const MetricBlock(
          label: '已知充电费用',
          value: null,
          unit: '元',
          scale: MetricValueScale.metricLg,
          semanticLabel: '已知充电费用 —',
        ),
      );
      expect(find.textContaining('—'), findsOneWidget);
      expect(find.textContaining('0'), findsNothing);
      expect(find.bySemanticsLabel('已知充电费用 —'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('数值与单位分开排版，200% 不溢出', (tester) async {
      await pumpComponent(
        tester,
        const MetricBlock(
          label: '本月 · 驾驶里程',
          value: '1,198.6',
          unit: 'km',
          note: '净电耗 158 Wh/km',
          scale: MetricValueScale.metricLg,
        ),
        scale: 2,
      );
      expect(find.textContaining('1,198.6'), findsOneWidget);
      expect(find.textContaining('km'), findsWidgets);
      expect(find.text('净电耗 158 Wh/km'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('可点 metric 维持 44 触控并提供 selected 语义', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pumpComponent(
        tester,
        MetricBlock(
          label: '净电耗',
          value: '158',
          unit: 'Wh/km',
          onTap: () => taps++,
          selected: true,
        ),
      );
      expect(
        tester.getSize(find.byType(InkWell)).height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(find.byType(MetricBlock));
      expect(taps, 1);
      expect(
        tester.getSemantics(find.byType(MetricBlock)),
        matchesSemantics(
          label: '净电耗 158 Wh/km',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('参照变化用箭头与文字，不用红绿', (tester) async {
      await pumpComponent(
        tester,
        const MetricDelta(text: '8.2%', label: '较上月同期', up: true),
      );
      expect(find.text('↑'), findsOneWidget);
      expect(find.text('较上月同期'), findsOneWidget);
    });
  });

  group('MileafDataRow', () {
    testWidgets('行高、chevron 与按压回调', (tester) async {
      var taps = 0;
      await pumpComponent(
        tester,
        MileafDataRow(
          title: '松岚小区 → 云栖中心',
          meta: '10/26 · 46 分钟 · 154 Wh/km',
          value: '32.9',
          unit: 'km',
          icon: MileafIconName.route,
          showChevron: true,
          topLine: true,
          onTap: () => taps++,
        ),
      );
      expect(
        tester.getSize(find.byType(MileafDataRow)).height,
        greaterThanOrEqualTo(56),
      );
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      await tester.tap(find.byType(MileafDataRow));
      expect(taps, 1);
    });

    testWidgets('仅标题的导航行仍显示 chevron', (tester) async {
      await pumpComponent(
        tester,
        MileafDataRow(title: '地图', showChevron: true, onTap: () {}),
      );
      expect(find.byType(MileafIcon), findsOneWidget);
      expect(
        tester.widget<MileafIcon>(find.byType(MileafIcon)).name,
        MileafIconName.chevron,
      );
    });

    testWidgets('不可导航行不加 chevron，禁用行不响应', (tester) async {
      var taps = 0;
      await pumpComponent(
        tester,
        MileafDataRow(
          title: '数据说明',
          enabled: false,
          onTap: () => taps++,
          showChevron: true,
        ),
      );
      await tester.tap(find.byType(MileafDataRow));
      expect(taps, 0);
      expect(find.byType(MileafIcon), findsNothing);
    });

    testWidgets('200% 时 title/meta/value 分行且不溢出', (tester) async {
      await pumpComponent(
        tester,
        MileafDataRow(
          title: '湖畔超级充电站',
          meta: '10/25 · 18→82% · 34 分钟',
          value: '46.8',
          unit: 'kWh',
          icon: MileafIconName.bolt,
          showChevron: true,
          onTap: () {},
        ),
        scale: 2,
      );
      expect(find.text('湖畔超级充电站'), findsOneWidget);
      expect(find.textContaining('46.8'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('destructive 只改标题色，语义标签仍含标题', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpComponent(
        tester,
        MileafDataRow(title: '清除已保存的 Key', destructive: true, onTap: () {}),
      );
      expect(
        tester.widget<Text>(find.text('清除已保存的 Key')).style?.color,
        const MileafColors.dark().error,
      );
      expect(find.bySemanticsLabel(RegExp('清除已保存的 Key')), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('默认非 destructive 行标题仍是正文色', (tester) async {
      await pumpComponent(tester, MileafDataRow(title: '底图授权', onTap: () {}));
      expect(
        tester.widget<Text>(find.text('底图授权')).style?.color,
        const MileafColors.dark().text,
      );
    });
  });

  group('MileafCopyRow', () {
    testWidgets('默认态：标签、可选择值与平台命中区复制按钮', (tester) async {
      var copies = 0;
      String? payload;
      await pumpComponent(
        tester,
        MileafCopyRow(
          label: '高德控制台链接',
          value: 'console.amap.com/dev/key/app',
          copyText: 'https://console.amap.com/dev/key/app',
          onCopy: (text) {
            copies++;
            payload = text;
          },
        ),
      );
      expect(find.text('高德控制台链接'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.text('console.amap.com/dev/key/app'), findsOneWidget);
      expect(
        tester.getSize(find.byType(MileafCopyRow)).height,
        greaterThanOrEqualTo(MileafSpace.rowMin),
      );
      final button = find.byTooltip('复制高德控制台链接');
      expect(button, findsOneWidget);
      expect(
        tester.getSize(button),
        const Size.square(MileafSpace.touchAndroid),
      );
      await tester.tap(button);
      expect(copies, 1);
      // copyText 可以不同于显示值：显示短域名，复制完整 URL。
      expect(payload, 'https://console.amap.com/dev/key/app');
      expect(tester.takeException(), isNull);
    });

    testWidgets('按压态用 accentSoft 覆盖层，常态图标是 textMuted', (tester) async {
      await pumpComponent(
        tester,
        MileafCopyRow(label: '包名', value: 'app.mileaf.example', onCopy: (_) {}),
      );
      const colors = MileafColors.dark();
      // AP03（R27/§4 M01）：按压不再用 InkWell 水波，改由 MileafPressOverlay
      // 即时出现、松手 120ms 消退；颜色仍是 accentSoft。
      expect(
        tester
            .widget<MileafPressOverlay>(
              find
                  .descendant(
                    of: find.byType(MileafIconButton),
                    matching: find.byType(MileafPressOverlay),
                  )
                  .first,
            )
            .color,
        colors.accentSoft,
      );
      expect(
        tester
            .widget<MileafIcon>(
              find
                  .descendant(
                    of: find.byType(MileafIconButton),
                    matching: find.byType(MileafIcon),
                  )
                  .first,
            )
            .color,
        colors.textMuted,
      );
    });

    testWidgets('禁用态不可复制，图标退到 38% textFaint', (tester) async {
      var copies = 0;
      await pumpComponent(
        tester,
        MileafCopyRow(
          label: '高德控制台链接',
          value: 'console.amap.com/dev/key/app',
          enabled: false,
          onCopy: (_) => copies++,
        ),
      );
      await tester.tap(find.byTooltip('复制高德控制台链接'));
      expect(copies, 0);
      expect(
        tester
            .widget<MileafIcon>(
              find
                  .descendant(
                    of: find.byType(MileafIconButton),
                    matching: find.byType(MileafIcon),
                  )
                  .first,
            )
            .color,
        const MileafColors.dark().textFaint.withValues(alpha: .38),
      );
      expect(find.text('console.amap.com/dev/key/app'), findsOneWidget);
    });

    testWidgets('键盘焦点落在复制按钮并出现 2px focusRing', (tester) async {
      await pumpComponent(
        tester,
        MileafCopyRow(label: '包名', value: 'app.mileaf.example', onCopy: (_) {}),
      );
      const colors = MileafColors.dark();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final border =
          (tester
                          .widget<DecoratedBox>(
                            find
                                .descendant(
                                  of: find.byType(MileafIconButton),
                                  matching: find.byType(DecoratedBox),
                                )
                                .first,
                          )
                          .decoration
                      as BoxDecoration)
                  .border
              as Border;
      expect(border.top.color, colors.focusRing);
      expect(border.top.width, 2);
    });

    testWidgets('200% 时标签、值、按钮竖向堆叠且不溢出', (tester) async {
      await pumpComponent(
        tester,
        MileafCopyRow(
          label: '签名 SHA-1',
          value: List.filled(20, 'AB').join(':'),
          onCopy: (_) {},
        ),
        width: 320,
        scale: 2,
      );
      final value = find.text(List.filled(20, 'AB').join(':'));
      final button = find.byTooltip('复制签名 SHA-1');
      expect(
        tester.getTopLeft(button).dy,
        greaterThan(tester.getBottomLeft(value).dy),
      );
      expect(tester.getTopLeft(button).dx, lessThan(80));
      expect(tester.takeException(), isNull);
    });
  });

  group('StatusChip / 按钮', () {
    testWidgets('共享轨道切换保留选中语义，四指标窄屏大字重排且可点', (tester) async {
      final semantics = tester.ensureSemantics();

      for (final scale in [1.0, 2.0]) {
        var selected = 0;
        await pumpComponent(
          tester,
          StatefulBuilder(
            builder: (context, update) => ChipRow(
              equalWidth: true,
              children: [
                for (final (index, label) in ['里程', '电耗', '补能', '费用'].indexed)
                  StatusChip(
                    label: label,
                    selected: selected == index,
                    onTap: () => update(() => selected = index),
                  ),
              ],
            ),
          ),
          width: 320,
          scale: scale,
        );
        expect(tester.takeException(), isNull);
        final first = tester.getRect(find.widgetWithText(StatusChip, '里程'));
        final third = tester.getRect(find.widgetWithText(StatusChip, '补能'));
        expect(first.height, greaterThanOrEqualTo(44));
        expect(third.top, greaterThanOrEqualTo(first.bottom));
        await tester.tap(find.text('费用'));
        await tester.pumpAndSettle();
        expect(selected, 3);
        expect(
          tester.getSemantics(find.byType(StatusChip).last),
          matchesSemantics(
            label: '费用',
            isButton: true,
            hasEnabledState: true,
            isEnabled: true,
            hasSelectedState: true,
            isSelected: true,
          ),
        );
        expect(tester.takeException(), isNull);
      }
      semantics.dispose();
    });

    testWidgets('chip 触控 44、选中过渡 160ms，选中与禁用状态可用', (tester) async {
      var taps = 0;
      await pumpComponent(
        tester,
        Wrap(
          children: [
            StatusChip(label: '里程', selected: true, onTap: () => taps++),
            StatusChip(label: '费用'),
            StatusChip(label: '禁用', enabled: false, onTap: () => taps += 10),
          ],
        ),
      );
      await tester.tap(find.text('里程'));
      expect(taps, 1);
      await tester.tap(find.text('禁用'));
      expect(taps, 1);
      expect(
        tester.getSize(find.text('里程').first).height,
        lessThanOrEqualTo(44),
      );
      expect(find.text('费用'), findsOneWidget);
    });

    testWidgets('长日期与短标签在窄屏大字下保留触控和完整语义', (tester) async {
      var taps = 0;
      const date = '2026-03-01 至 2026-03-30';
      await pumpComponent(
        tester,
        ChipRow(
          children: [
            for (final label in [date, '查看期间补能记录', '里程', 'DC记录'])
              StatusChip(label: label, onTap: () => taps++),
          ],
        ),
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      for (final label in [date, '查看期间补能记录', '里程', 'DC记录']) {
        final chip = find.widgetWithText(StatusChip, label);
        expect(tester.getSize(chip).height, greaterThanOrEqualTo(44));
        expect(tester.getSize(chip).width, lessThanOrEqualTo(320));
        await tester.tap(chip);
      }
      expect(taps, 4);
    });

    for (final kind in MileafButtonKind.values) {
      testWidgets('${kind.name} 按钮 44 高、禁用与 loading 可见', (tester) async {
        var taps = 0;
        await pumpComponent(
          tester,
          Column(
            children: [
              MileafButton(label: '验证并连接', kind: kind, onPressed: () => taps++),
              MileafButton(label: '不可用', kind: kind, onPressed: null),
              MileafButton(
                label: '保存中',
                kind: kind,
                loading: true,
                onPressed: () => taps += 10,
              ),
            ],
          ),
        );
        expect(
          tester.getSize(find.text('验证并连接').first).height,
          lessThanOrEqualTo(44),
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.tap(find.text('验证并连接'));
        expect(taps, 1);
        await tester.tap(find.text('不可用'));
        await tester.tap(find.text('保存中'));
        expect(taps, 1);
      });
    }
  });

  group('StateView', () {
    testWidgets('空态给标题、说明和动作', (tester) async {
      var retry = 0;
      await pumpComponent(
        tester,
        StateView(
          kind: StateViewKind.empty,
          title: '这段时间还没有行程',
          message: '换一个区间或下拉刷新',
          actionLabel: '重试',
          onAction: () => retry++,
        ),
      );
      await tester.tap(find.text('重试'));
      expect(retry, 1);
      expect(find.text('这段时间还没有行程'), findsOneWidget);
    });

    testWidgets('错误态使用 error 色标题', (tester) async {
      await pumpComponent(
        tester,
        const StateView(
          kind: StateViewKind.error,
          title: '数据读取失败',
          message: '保留上次快照',
        ),
      );
      final text = tester.widget<Text>(find.text('数据读取失败'));
      expect(text.style?.color, const MileafColors.dark().text);
    });

    testWidgets('加载骨架在 reduce motion 下停住', (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        () => tester.binding.platformDispatcher
            .clearAccessibilityFeaturesTestValue(),
      );
      await pumpComponent(tester, const StateView(kind: StateViewKind.loading));
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonBlock), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  });

  group('图表', () {
    test('null 断线：连续已知值各自成段', () {
      expect(chartRuns([1, null, 2, 3, null, null, 4]), [
        [0],
        [2, 3],
        [6],
      ]);
      expect(chartRuns([null, null]), isEmpty);
    });

    test('stem 真实零画基线标记，null留空', () {
      expect(chartStemIndices([1, 0, null, 2, 0.0, 3]), [0, 1, 3, 4, 5]);
    });

    final times = [for (var i = 0; i < 5; i++) DateTime(2026, 10, 1 + i)];

    testWidgets('点按按时间定位，读数与语义同步', (tester) async {
      final semantics = tester.ensureSemantics();
      final selected = <int>[];
      await pumpComponent(
        tester,
        TimeSeriesChart(
          title: '每日里程',
          unit: 'km',
          times: times,
          series: const [
            ChartSeries(label: '里程', values: [10, 20, 30, 40, 50]),
          ],
          semanticsLabel: '10月1日至5日每日里程',
          subtitle: '10.01 — 10.05',
          onSelected: selected.add,
          readout: (index) =>
              '${times[index].month}/${times[index].day} · '
              '${[10, 20, 30, 40, 50][index]}.0 km',
          trailing: const Text('点按读值'),
        ),
      );
      expect(find.bySemanticsLabel(RegExp('10月1日至5日每日里程')), findsOneWidget);
      expect(
        tester.getSize(find.byType(CustomPaint).last).height,
        greaterThanOrEqualTo(44),
      );
      final plot = tester.getRect(find.byType(CustomPaint).last);
      await tester.tapAt(Offset(plot.right - 2, plot.center.dy));
      await tester.pumpAndSettle();
      expect(selected.last, 4);
      // R29：读数头把日期与数值分行，readout 句子只作朗读。
      expect(find.text('10月5日'), findsOneWidget);
      expect(find.text('50 km'), findsOneWidget);
      expect(find.text('点按读值'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('null 读数为缺失，真实 0 保留', (tester) async {
      await pumpComponent(
        tester,
        TimeSeriesChart(
          title: '每日补能',
          unit: 'kWh',
          times: times,
          series: const [
            ChartSeries(
              label: '补能',
              values: [null, 0, 2, null, 4],
              style: ChartSeriesStyle.bars,
            ),
          ],
          semanticsLabel: '每日补能图表',
          selectedIndex: 0,
          readout: (index) =>
              '${times[index].month}/${times[index].day} · '
              '${const ['—', '0', '2', '—', '4'][index]} kWh',
        ),
      );
      expect(find.text('10月1日'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('0 kWh'), findsNothing);
      final plot = tester.getRect(find.byType(CustomPaint).last);
      await tester.tapAt(Offset(plot.left + plot.width / 4, plot.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('10月2日'), findsOneWidget);
      expect(find.text('0 kWh'), findsOneWidget);
    });

    testWidgets('单测量 + 参照：图例只标注位置指认不出的虚线', (tester) async {
      await pumpComponent(
        tester,
        TimeSeriesChart(
          title: '里程走势',
          unit: 'km',
          times: times,
          series: const [
            ChartSeries(
              label: '本期',
              values: [10, 20, 30, 40, 50],
              style: ChartSeriesStyle.area,
            ),
            ChartSeries(
              label: '参照',
              values: [8, 18, 28, 38, 48],
              style: ChartSeriesStyle.reference,
            ),
          ],
          semanticsLabel: '里程走势图表',
          controls: const ChipRow(children: [StatusChip(label: '里程')]),
          readout: (index) => '第${index + 1}天',
        ),
      );
      // 实心系列已由标题和指标控件命名两次，图例只留虚线那一条。
      expect(find.text('参照'), findsOneWidget);
      expect(find.text('本期'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('多测量时图例只列名字，不画同色色块', (tester) async {
      await pumpComponent(
        tester,
        TimeSeriesChart(
          title: '净 / 毛电耗',
          unit: 'Wh/km',
          times: times,
          series: const [
            ChartSeries(label: '净电耗', values: [10, 20, 30, 40, 50]),
            ChartSeries(label: '毛电耗', values: [12, 22, 32, 42, 52]),
          ],
          semanticsLabel: '净电耗与毛电耗图表',
        ),
      );
      expect(find.text('净电耗'), findsOneWidget);
      expect(find.text('毛电耗'), findsOneWidget);
      // 绘图区只拿得到一个主色，两条线同色；同色色块等于宣称它们相同。
      expect(find.byKey(const ValueKey('chart-legend-mark-净电耗')), findsNothing);
      expect(find.byKey(const ValueKey('chart-legend-mark-毛电耗')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('图例排在指标控件之下、绘图区之上', (tester) async {
      await pumpComponent(
        tester,
        TimeSeriesChart(
          title: '每日里程',
          unit: 'km',
          subtitle: '10.01 — 10.05',
          times: times,
          series: const [
            ChartSeries(label: '里程', values: [10, 20, 30, 40, 50]),
            ChartSeries(
              label: '上月同期',
              values: [8, 18, 28, 38, 48],
              style: ChartSeriesStyle.reference,
            ),
          ],
          semanticsLabel: '每日里程图表',
          controls: const ChipRow(children: [StatusChip(label: '里程')]),
          readout: (index) => '第${index + 1}天',
        ),
      );
      final controls = tester.getRect(find.byType(ChipRow));
      final legend = tester.getRect(
        find.byKey(const ValueKey('chart-legend-mark-上月同期')),
      );
      final plot = tester.getRect(find.byType(CustomPaint).last);
      expect(legend.top, greaterThanOrEqualTo(controls.bottom));
      // R29：图例移到 X 轴之下（原「绘图区之上」的旧规则被取代）。
      expect(legend.top, greaterThanOrEqualTo(plot.bottom));
      expect(find.text('里程'), findsOneWidget, reason: '实心系列不再重复命名');
      expect(tester.takeException(), isNull);
    });

    testWidgets('320 宽 130% 长区间不横向溢出', (tester) async {
      await pumpComponent(
        tester,
        TimeSeriesChart(
          title: '速度过程',
          unit: 'km/h',
          subtitle: '2025/12/28—2026/1/3',
          times: times,
          series: const [
            ChartSeries(label: '速度', values: [10, 20, 30, 40, 50]),
          ],
          semanticsLabel: '速度过程图表',
          readout: (index) => '第${index + 1}天',
        ),
        width: 320,
        scale: 1.3,
      );
      expect(tester.takeException(), isNull);
      final chart = tester.getRect(find.byType(TimeSeriesChart));
      final range = tester.getRect(find.text('2025/12/28—2026/1/3'));
      expect(range.right, lessThanOrEqualTo(chart.right));
      expect(find.text('km/h'), findsOneWidget);
    });

    testWidgets('标题、单位、区间同排且各归其位', (tester) async {
      await pumpComponent(
        tester,
        TimeSeriesChart(
          title: '每日里程',
          unit: 'km',
          subtitle: '10.01 — 10.26',
          times: times,
          series: const [
            ChartSeries(label: '里程', values: [10, 20, 30, 40, 50]),
          ],
          semanticsLabel: '每日里程图表',
          readout: (index) => '第${index + 1}天',
        ),
      );
      final title = tester.getRect(find.text('每日里程'));
      final unit = tester.getRect(find.text('km'));
      final range = tester.getRect(find.text('10.01 — 10.26'));
      // 同一行：单位贴着标题，区间落在右端，三者不各自折行。
      expect(unit.center.dy, closeTo(title.center.dy, 2));
      expect(range.center.dy, closeTo(title.center.dy, 2));
      expect(unit.left, greaterThan(title.right));
      expect(range.left, greaterThan(unit.right));
      expect(
        range.right,
        closeTo(tester.getRect(find.byType(TimeSeriesChart)).right, .5),
        reason: '区间右端与绘图区右沿同线',
      );
    });

    testWidgets('200% 字号：区间落到标题下一行并与标题同一左缘', (tester) async {
      await pumpComponent(
        tester,
        TimeSeriesChart(
          title: '每日里程',
          unit: 'km',
          subtitle: '10.01 — 10.26',
          times: times,
          series: const [
            ChartSeries(label: '里程', values: [10, 20, 30, 40, 50]),
          ],
          semanticsLabel: '每日里程图表',
          readout: (index) => '第${index + 1}天',
        ),
        scale: 2,
      );
      final title = tester.getRect(find.text('每日里程'));
      final range = tester.getRect(find.text('10.01 — 10.26'));
      expect(range.top, greaterThanOrEqualTo(title.bottom));
      expect(range.left, closeTo(title.left, .5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('headerTrailing 控件排在标题之下，不与标题挤同一行', (tester) async {
      await pumpComponent(
        tester,
        TimeSeriesChart(
          title: '每日补能',
          unit: 'kWh',
          times: times,
          series: const [
            ChartSeries(label: '补能', values: [10, 20, 30, 40, 50]),
          ],
          semanticsLabel: '每日补能图表',
          headerTrailing: const Text('控件行'),
          readout: (index) => '第${index + 1}天',
        ),
      );
      final title = tester.getRect(find.text('每日补能'));
      final trailing = tester.getRect(find.text('控件行'));
      expect(trailing.top, greaterThanOrEqualTo(title.bottom));
      expect(trailing.left, closeTo(title.left, .5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('空采样不画全零图', (tester) async {
      await pumpComponent(
        tester,
        const TimeSeriesChart(
          title: '每日里程',
          unit: 'km',
          times: [],
          series: [],
          semanticsLabel: '每日里程图表',
        ),
      );
      expect(find.text('还没有采样点'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('stem 离散图保留零值为空槽', (tester) async {
      await pumpComponent(
        tester,
        StemChart(
          title: '每日补能',
          unit: 'kWh',
          times: times,
          values: const [10, 0, null, 4, 0.0],
          semanticsLabel: '每日补能图表',
          selectedIndex: 0,
          readout: (index) => '${times[index].month}/${times[index].day}',
        ),
      );
      expect(find.text('每日补能'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('200% 隐藏 Y 轴但保留当前读数', (tester) async {
      await pumpComponent(
        tester,
        TimeSeriesChart(
          title: '里程走势',
          unit: 'km',
          times: times,
          series: const [
            ChartSeries(label: '本期', values: [10, 20, 30, 40, 60]),
          ],
          semanticsLabel: '里程走势图表',
          showYAxis: true,
          selectedIndex: 4,
          readout: (index) => '10/5 · 60 km',
        ),
        scale: 2,
      );
      expect(find.text('10月5日'), findsOneWidget);
      expect(find.text('60 km'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduce motion 时图表演绎直接完成', (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        () => tester.binding.platformDispatcher
            .clearAccessibilityFeaturesTestValue(),
      );
      await pumpComponent(
        tester,
        TimeSeriesChart(
          title: '每日里程',
          unit: 'km',
          times: times,
          series: const [
            ChartSeries(label: '里程', values: [10, 20, 30, 40, 50]),
          ],
          semanticsLabel: '每日里程图表',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('MicroSpark 缺失断线且有语义摘要', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpComponent(
        tester,
        const MicroSpark(values: [1, null, 3, 0, 5], semanticsLabel: '能耗微趋势'),
      );
      expect(find.bySemanticsLabel('能耗微趋势'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  group('BatteryArc', () {
    testWidgets('88px 电量弧、未知为破折号', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpComponent(
        tester,
        const Row(
          children: [
            BatteryArc(level: 68),
            SizedBox(width: 12),
            BatteryArc(level: null),
          ],
        ),
      );
      // R29：环内只放数值，「电量」标签移到环外，组件因此比 88 高一行；
      // 88 是电量弧本身的尺寸。
      expect(
        tester.getSize(
          find
              .descendant(
                of: find.byType(BatteryArc),
                matching: find.byType(CustomPaint),
              )
              .first,
        ),
        const Size(88, 88),
      );
      expect(find.bySemanticsLabel('电池电量 68%'), findsOneWidget);
      expect(find.bySemanticsLabel('电池电量 未知'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('充电区间 18→82 用同一 0–100 尺度', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpComponent(
        tester,
        const BatteryArc(level: 82, start: 18, label: '到达电量'),
      );
      expect(find.bySemanticsLabel('电量区间 18% 至 82%，尺度0至100%'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('200% 弧为 72 且中心主数可见', (tester) async {
      await pumpComponent(tester, const BatteryArc(level: 68), scale: 2);
      expect(
        tester.getSize(
          find
              .descendant(
                of: find.byType(BatteryArc),
                matching: find.byType(CustomPaint),
              )
              .first,
        ),
        const Size(72, 72),
      );
      // R29/CP03：数值与百分号紧贴，环内拆成两个 Text。
      expect(find.text('68'), findsOneWidget);
      expect(find.text('%'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('68'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('MapFrame 固定高度并承载说明带', (tester) async {
    await pumpComponent(
      tester,
      const MapFrame(
        height: 300,
        overlay: Text('松岚小区 → 云栖中心'),
        fallback: Center(child: Text('地图暂不可用')),
        semanticsLabel: '行程地图',
      ),
    );
    expect(tester.getSize(find.byType(MapFrame)), const Size(320, 300));
    expect(find.text('地图暂不可用'), findsOneWidget);
    expect(find.text('松岚小区 → 云栖中心'), findsOneWidget);
  });

  testWidgets('MileafSheetFrame 标题、关闭与内容可达', (tester) async {
    await pumpComponent(
      tester,
      Builder(
        builder: (context) => MileafButton(
          label: '打开',
          onPressed: () => showMileafSheet<void>(
            context: context,
            title: '选择车辆',
            builder: (_) => const Text('白露'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('选择车辆'), findsOneWidget);
    expect(find.text('白露'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.text('选择车辆'), findsNothing);
  });

  testWidgets('共享组件在 360×200% 下无横向溢出', (tester) async {
    await pumpComponent(
      tester,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: '本月 · 驾驶里程', range: 'OCT 2026'),
          const SizedBox(height: 12),
          const MetricBlock(
            label: '本月 · 驾驶里程',
            value: '1,198.6',
            unit: 'km',
            note: '↑ 8.2% 较上月同期',
            scale: MetricValueScale.metricLg,
          ),
          const SizedBox(height: 12),
          MileafDataRow(
            title: '湖畔超级充电站',
            meta: '10/25 · 18→82% · 46.8 kWh',
            value: '82',
            unit: '%',
            icon: MileafIconName.bolt,
            showChevron: true,
            onTap: () {},
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusChip(label: '近30天', selected: true),
              StatusChip(label: '近7天'),
            ],
          ),
          const SizedBox(height: 12),
          MileafButton(label: '验证并替换连接', onPressed: () {}),
        ],
      ),
      scale: 2,
    );
    expect(tester.takeException(), isNull);
  });

  group('强调色分层：文字 accentStrong、图形 accent（Spec §1 R3、§7.2、§13）', () {
    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}：正文动作取 accentStrong，底栏保留独立前景', (
        tester,
      ) async {
        final colors = brightness == Brightness.dark
            ? const MileafColors.dark()
            : const MileafColors.light();
        await pumpComponent(
          tester,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MileafNavBar(index: 0, onSelected: (_) {}),
              const SizedBox(height: 12),
              StatusChip(label: '本月', selected: true, onTap: () {}),
              const SizedBox(height: 12),
              MileafButton(
                label: '全部指标',
                kind: MileafButtonKind.ghost,
                onPressed: () {},
              ),
              const SizedBox(height: 12),
              MileafButton(
                label: '取消',
                kind: MileafButtonKind.secondary,
                onPressed: () {},
              ),
              const SizedBox(height: 12),
              MileafButton(label: '保存', onPressed: () {}),
            ],
          ),
          brightness: brightness,
        );

        Color? textColor(String label) =>
            tester.widget<Text>(find.text(label)).style?.color;
        expect(textColor('概览'), colors.navigationActive, reason: '选中导航保持原色');
        expect(
          textColor('行程'),
          colors.navigationLabel,
          reason: '未选导航标签：玻璃变薄后用底栏专属色（ADR 0013 L03/L10）',
        );
        expect(textColor('本月'), colors.text, reason: '选中 chip 标签是文字');
        expect(textColor('全部指标'), colors.accentStrong, reason: 'ghost 是文字按钮');
        // AP03（R27）：次按钮改 accentSoft 填充 + accentStrong 文字。
        expect(
          textColor('取消'),
          colors.accentStrong,
          reason: 'secondary 用 accentStrong',
        );
        expect(textColor('保存'), colors.onPrimaryAction, reason: '主按钮墨色文字');

        // AP03（§4 M01）：按压覆盖层由 MileafPressOverlay 承担，
        // 实心及次按钮用中性 pressOverlay，ghost 用 accentSoft。
        Color? overlay(String label) => tester
            .widget<MileafPressOverlay>(
              find
                  .descendant(
                    of: find.ancestor(
                      of: find.text(label),
                      matching: find.byWidgetPredicate(
                        (widget) =>
                            widget is MileafButton || widget is StatusChip,
                      ),
                    ),
                    matching: find.byType(MileafPressOverlay),
                  )
                  .first,
            )
            .color;
        expect(overlay('全部指标'), colors.accentSoft);
        expect(overlay('保存'), colors.pressOverlay);
        expect(overlay('取消'), colors.pressOverlay);
        expect(overlay('本月'), colors.accentSoft, reason: '§7.4 未选行高亮');
      });
    }

    test('深色把两层强调色合并（§1 R3）', () {
      const dark = MileafColors.dark();
      const light = MileafColors.light();
      expect(dark.accentStrong, dark.accent);
      expect(light.accentStrong, isNot(light.accent));
    });
  });
}
