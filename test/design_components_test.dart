import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/icons.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';

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
    testWidgets('深色锚点带单个光晕且状态栏为浅色图标', (tester) async {
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
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
      );
      expect(region.value.statusBarIconBrightness, Brightness.light);
      expect(find.bySemanticsLabel(RegExp('车况')), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('浅色页仍使用深色 hero', (tester) async {
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
      expect(material.color, isNot(const MileafColors.light().canvas));
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
      expect(tester.getSize(find.byType(InkWell)).height, greaterThanOrEqualTo(44));
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
  });

  group('StatusChip / 按钮', () {
    testWidgets('chip 视觉 34、触控 44，选中与禁用状态可用', (tester) async {
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

    for (final kind in MileafButtonKind.values) {
      testWidgets('${kind.name} 按钮 44 高、禁用与 loading 可见', (tester) async {
        var taps = 0;
        await pumpComponent(
          tester,
          Column(
            children: [
              MileafButton(
                label: '验证并连接',
                kind: kind,
                onPressed: () => taps++,
              ),
              MileafButton(
                label: '不可用',
                kind: kind,
                onPressed: null,
              ),
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
      expect(text.style?.color, const MileafColors.dark().error);
    });

    testWidgets('加载骨架在 reduce motion 下停住', (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        () => tester.binding.platformDispatcher
            .clearAccessibilityFeaturesTestValue(),
      );
      await pumpComponent(
        tester,
        const StateView(kind: StateViewKind.loading),
      );
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

    test('stem 的零与 null 都留空', () {
      expect(chartStemIndices([1, 0, null, 2, 0.0, 3]), [0, 3, 5]);
    });

    final times = [
      for (var i = 0; i < 5; i++) DateTime(2026, 10, 1 + i),
    ];

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
      expect(tester.getSize(find.byType(CustomPaint).last).height,
          greaterThanOrEqualTo(44));
      final plot = tester.getRect(find.byType(CustomPaint).last);
      await tester.tapAt(Offset(plot.right - 2, plot.center.dy));
      await tester.pumpAndSettle();
      expect(selected.last, 4);
      expect(find.text('10/5 · 50.0 km'), findsOneWidget);
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
      expect(find.text('10/1 · — kWh'), findsOneWidget);
      expect(find.text('0 kWh'), findsNothing);
      final plot = tester.getRect(find.byType(CustomPaint).last);
      await tester.tapAt(Offset(plot.left + plot.width / 4, plot.center.dy));
      await tester.pumpAndSettle();
      expect(find.text('10/2 · 0 kWh'), findsOneWidget);
    });

    testWidgets('多系列显示图例，参照用虚线标签', (tester) async {
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
        ),
      );
      expect(find.text('本期'), findsOneWidget);
      expect(find.text('参照'), findsOneWidget);
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
      expect(find.text('10/5 · 60 km'), findsOneWidget);
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
        const MicroSpark(
          values: [1, null, 3, 0, 5],
          semanticsLabel: '能耗微趋势',
        ),
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
      expect(tester.getSize(find.byType(BatteryArc).first), const Size(88, 88));
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
      expect(
        find.bySemanticsLabel('电量区间 18% 至 82%，尺度0至100%'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('200% 弧为 72 且中心主数可见', (tester) async {
      await pumpComponent(tester, const BatteryArc(level: 68), scale: 2);
      expect(tester.getSize(find.byType(BatteryArc)), const Size(72, 72));
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
}
