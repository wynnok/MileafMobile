import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/api.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/currency.dart';
import 'package:mileaf/src/design/brand_mark.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/tokens.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/map/map_consent.dart';
import 'package:mileaf/src/map/map_consent_sheet.dart';
import 'package:mileaf/src/session.dart';
import 'package:mileaf/src/session_pages.dart';

import 'appearance_shell_test.dart' show pumpShell;
import 'charging_cost_test.dart' show CostSite, pumpCostApp, openCostSheet;
import 'support/session_store.dart' show MemorySessionStore;
import 'widget_test.dart' show MemoryTrustStore;

/// AP13 票合同测试（P12 设置子页、P13 接入页、P14 费用补录、P16 车辆弹层）。
///
/// 先于实现编写（TDD）。CP12 冻结文案逐字断言为源级守卫，防止本票或
/// 集成窗口无意改动冻结文本。
void main() {
  group('P12 设置子页', () {
    testWidgets('外观弹层是浮动样式，选中只显示勾选', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('外观'));
      await tester.pumpAndSettle();
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('sheet-surface')),
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color, const MileafColors.light().surfaceRaised);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(MileafRadius.sheet),
        reason: 'R28 浮动弹层四角 28',
      );
      expect(
        find.byType(MileafSelectionList<MileafAppearance>),
        findsOneWidget,
      );
      // R23.4：选中行只显示尾部勾选，不再用数据行徽标。
      expect(find.byType(MileafDataRow), findsNothing);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
    });

    testWidgets('外观弹层脚注用对照表新句，选择后关闭', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('外观'));
      await tester.pumpAndSettle();
      expect(find.text('切换后立即生效，只保存在这台设备上。'), findsOneWidget);
      expect(find.textContaining('默认跟随系统'), findsNothing);
      await tester.tap(find.text('深色'));
      await tester.pumpAndSettle();
      expect(find.text('切换后立即生效，只保存在这台设备上。'), findsNothing);
    });

    testWidgets('币种保持推入页面（路由不变）', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('币种').hitTestable(), 160);
      await tester.tap(find.text('币种').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(CurrencyPage), findsOneWidget);
    });
  });

  group('P13 接入页单任务排版', () {
    testWidgets('连接页：品牌 → title2 → 说明 → 输入 → 主按钮顺序，左对齐', (tester) async {
      await tester.pumpWidget(
        MileafApp(
          client: MockClient(
            (_) async => http.Response('{"status":"ok","version":"0.1"}', 200),
          ),
          trustStore: MemoryTrustStore(),
          sessionStore: MemorySessionStore(),
        ),
      );
      await tester.pumpAndSettle();
      final brand = tester.getTopLeft(find.byType(MileafWordmark));
      // 正文 title2：限定在内容区内，避开导航栏同名标题。
      final title = tester.getTopLeft(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data == '连接你的站点' &&
              w.style?.fontSize == MileafType.title2Size,
        ),
      );
      final hint = tester.getTopLeft(
        find.textContaining('输入自托管 Mileaf Server'),
      );
      final field = tester.getTopLeft(find.byType(TextFormField));
      final button = tester.getTopLeft(
        find.widgetWithText(MileafButton, '检查连接'),
      );
      expect(brand.dy, lessThan(title.dy));
      expect(title.dy, lessThan(hint.dy));
      expect(hint.dy, lessThan(field.dy));
      expect(field.dy, lessThan(button.dy));
      // 左对齐：品牌与 title2 同一起始线（允许字面基线的 1px 差）。
      expect((title.dx - brand.dx).abs(), lessThan(1));
      // HTTPS 帮助是输入的 footnote（R27）：输入框下方、主按钮上方。
      final https = tester.getTopLeft(
        find.text('推荐 HTTPS 安全连接。请保留端口和反向代理路径前缀。'),
      );
      expect(https.dy, greaterThan(field.dy));
      expect(https.dy, lessThan(button.dy));
    });

    testWidgets('登录页：title2 与主按钮胶囊，处理中保留文字', (tester) async {
      final login = Completer<http.Response>();
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/health')) {
          return http.Response('{"status":"ok","version":"0.1"}', 200);
        }
        if (request.url.path.endsWith('/auth/login')) return login.future;
        return http.Response('[]', 200);
      });
      await tester.pumpWidget(
        MileafApp(
          client: client,
          trustStore: MemoryTrustStore(),
          sessionStore: MemorySessionStore(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'https://example.com/prefix',
      );
      await tester.tap(find.text('检查连接'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('登录此站点'));
      await tester.pumpAndSettle();
      // P13：正文 title2 与导航标题并存（同一常量，文案一字不差）。
      expect(find.text('登录行笺'), findsNWidgets(2));
      expect(find.widgetWithText(MileafButton, '登录'), findsOneWidget);
      expect(find.widgetWithText(MileafButton, '首次设置站点口令'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'test-password');
      await tester.tap(find.text('登录'));
      await tester.pump();
      final button = tester.widget<MileafButton>(
        find.widgetWithText(MileafButton, '登录'),
      );
      expect(button.loading, isTrue, reason: 'R27 处理中保留文字并加指示器');
      expect(find.text('登录'), findsOneWidget);
      expect(find.text('正在登录…'), findsNothing);
      login.complete(
        http.Response('{"token":"t","expires_at":"2099-01-01T00:00:00Z"}', 200),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('初始化页：title2、主按钮与返回登录文字按钮', (tester) async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/health')) {
          return http.Response('{"status":"ok","version":"0.1"}', 200);
        }
        return http.Response('[]', 200);
      });
      await tester.pumpWidget(
        MileafApp(
          client: client,
          trustStore: MemoryTrustStore(),
          sessionStore: MemorySessionStore(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'https://example.com/prefix',
      );
      await tester.tap(find.text('检查连接'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('登录此站点'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('首次设置站点口令'));
      await tester.pumpAndSettle();
      expect(find.text('初始化站点'), findsNWidgets(2));
      final fieldTop = tester.getTopLeft(
        find.widgetWithText(TextFormField, '新站点口令'),
      );
      final button = tester.getTopLeft(
        find.widgetWithText(MileafButton, '设置口令并登录'),
      );
      final back = tester.getTopLeft(find.widgetWithText(MileafButton, '返回登录'));
      expect(fieldTop.dy, lessThan(button.dy));
      expect(button.dy, lessThan(back.dy));
    });

    testWidgets('连接管理：动作行收进分组卡，退出此设备为次按钮', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.byTooltip('设置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('站点连接'));
      await tester.pumpAndSettle();
      for (final label in ['更换连接', '重新登录当前站点']) {
        expect(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(MileafGroupCard),
          ),
          findsOneWidget,
          reason: label,
        );
      }
      expect(find.widgetWithText(MileafButton, '退出此设备'), findsOneWidget);
      expect(
        find.text('验证新连接和车辆成功后才替换；失败时保留当前连接。'),
        findsNothing,
        reason: '替换说明只在编辑态出现',
      );
      await tester.tap(find.text('更换连接'));
      await tester.pumpAndSettle();
      expect(find.text('验证新连接和车辆成功后才替换；失败时保留当前连接。'), findsOneWidget);
    });
  });

  group('P14 费用补录', () {
    testWidgets('贴边弹层：记录块 headline 与共享日期、单价标签、metricSm 预估', (tester) async {
      await pumpCostApp(tester, CostSite());
      await tester.tap(find.text('充电').last);
      await tester.pumpAndSettle();
      await openCostSheet(tester);
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('sheet-surface')),
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color, const MileafColors.light().surfaceRaised);
      expect(
        decoration.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(MileafRadius.sheet)),
        reason: 'R28 贴边弹层只顶部 28',
      );
      // 记录块：地点 headline、日期 subheadline（CP04 共享格式化器）。
      final location = tester.widget<Text>(
        find.descendant(
          of: find.byType(MileafSheetFrame),
          matching: find.text('湖畔超级充电站'),
        ),
      );
      expect(location.style?.fontSize, MileafType.headlineSize);
      expect(find.text('1月5日 08:00'), findsOneWidget);
      expect(find.textContaining('充电 #'), findsNothing);
      // 输入单价后预估费用出现（R27/R31：输入即预估）。
      await tester.enterText(find.byType(TextField), '1.25');
      await tester.pumpAndSettle();
      // P14：单价标签为「单价（CNY/kWh）」，不再有独立单位行。
      expect(find.text('单价（CNY/kWh）'), findsOneWidget);
      expect(find.text('CNY / kWh'), findsNothing);
      // 预估费用为 metricSm（R21.3）。
      final estimate = tester.widget<Text>(find.text('¥27.50'));
      expect(estimate.style?.fontSize, MileafType.metricSmSize);
      // CP12 冻结后果说明逐字保留。
      expect(find.text('仅补录本次充电。保存后无法在 App 中修改；单价不会设为默认值。'), findsOneWidget);
      expect(find.text('按两类电量的较大可用值计费，最终费用以服务端为准。'), findsOneWidget);
    });
  });

  group('P16 车辆弹层与车辆页', () {
    testWidgets('车辆弹层刷新动作语义与可见文字一致（D-AP07-10）', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.text('行笺测试车'));
      await tester.pumpAndSettle();
      expect(find.text('刷新车辆列表'), findsOneWidget);
      expect(find.byTooltip('刷新车辆列表'), findsOneWidget);
      expect(find.byTooltip('刷新车辆'), findsNothing);
    });

    testWidgets('车辆页行收进分组卡、区分信息不用车辆编号、无 Material 图标', (tester) async {
      final session = SessionController(
        MileafApi(
          MockClient((_) async => http.Response('[]', 200)),
          trustStore: MemoryTrustStore(),
        ),
        MemorySessionStore(),
      );
      addTearDown(session.dispose);
      session.vehicles = [
        Vehicle.fromJson(
          jsonDecode(
            '{"id":1,"name":"命名车辆","model":"3","vin_suffix":"VIN-SYNTH-1234",'
            '"state":null,"battery":null,'
            '"freshness":{"last_position_at":null,"last_state_at":null}}',
          ),
        ),
        Vehicle.fromJson(
          jsonDecode(
            '{"id":2,"name":null,"model":"Y","vin_suffix":"ABCD0002",'
            '"state":null,"battery":null,'
            '"freshness":{"last_position_at":null,"last_state_at":null}}',
          ),
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(Brightness.light),
          home: VehiclePage(session: session, onSettings: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MileafGroupCard), findsOneWidget);
      expect(find.text('命名车辆'), findsOneWidget);
      // CP09：区分信息「型号，尾号」；车辆编号不再作为行副文。
      expect(find.text('3，尾号 1234'), findsOneWidget);
      expect(find.text('Y，尾号 0002'), findsOneWidget);
      expect(find.textContaining('车辆 ID'), findsNothing);
      expect(find.byIcon(Icons.settings), findsNothing);
      expect(find.byIcon(Icons.refresh), findsNothing);
    });
  });

  group('R32 与 CP12 守卫', () {
    const heldFiles = [
      'lib/src/settings_page.dart',
      'lib/src/connection_page.dart',
      'lib/src/connection_management.dart',
      'lib/src/session_pages.dart',
      'lib/src/setup_page.dart',
      'lib/src/appearance_sheet.dart',
      'lib/src/charging_cost.dart',
      'lib/src/map/map_privacy_page.dart',
      'lib/src/map/map_consent_sheet.dart',
    ];

    test('持有源文件不再使用 Material Icons（R32）', () {
      for (final path in heldFiles) {
        final source = File(path).readAsStringSync();
        expect(source.contains('Icons.'), isFalse, reason: path);
      }
    });

    test('CP12 冻结文案逐字保留', () {
      final frozen = <String, List<String>>{
        'lib/src/connection_page.dart': [
          'HTTP 会明文传输口令、token 和车辆数据。仅在你信任的私网或 VPN 使用；App 无法验证 VPN 或网络是否安全。',
          '我确认此站点使用可信网络',
        ],
        'lib/src/connection_management.dart': [
          '此确切站点使用可信私网或 VPN；HTTP 会明文传输凭据',
          '验证新连接和车辆成功后才替换；失败时保留当前连接。',
          '退出后清除本机访问授权，保留站点地址以便重新连接。其他设备的登录状态不受影响。',
        ],
        'lib/src/map/map_privacy_page.dart': ['清除后立即使用路线速写。你可以随时重新填写 Key。'],
        'lib/src/map/map_consent_sheet.dart': [
          '行笺不会向地图发送站点凭据，也不会读取手机定位。',
          '高德隐私政策',
        ],
        'lib/src/charging_cost.dart': [
          '仅补录本次充电。保存后无法在 App 中修改；单价不会设为默认值。',
          '按两类电量的较大可用值计费，最终费用以服务端为准。',
        ],
      };
      frozen.forEach((path, texts) {
        final source = File(path).readAsStringSync();
        for (final text in texts) {
          expect(source.contains(text), isTrue, reason: '$path 缺少冻结文案：$text');
        }
      });
    });
  });

  group('地图同意弹层（AP13 持有，AP09 调用签名不变）', () {
    testWidgets('贴边样式与冻结文案，允许加载写入同意状态', (tester) async {
      final consent = MapConsentController();
      addTearDown(consent.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(Brightness.light),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: MileafButton(
                  label: '启用地图入口',
                  onPressed: () => showMapConsentSheet(
                    context,
                    consent,
                    providerName: '高德地图',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('启用地图入口'));
      await tester.pumpAndSettle();
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('sheet-surface')),
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color, const MileafColors.light().surfaceRaised);
      expect(
        decoration.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(MileafRadius.sheet)),
      );
      expect(find.text('地图由高德地图提供'), findsOneWidget);
      expect(find.textContaining('加载地图后'), findsOneWidget);
      expect(find.textContaining('行笺不会向地图发送站点凭据'), findsOneWidget);
      expect(find.text('高德隐私政策'), findsOneWidget);
      await tester.tap(find.text('允许加载'));
      await tester.pumpAndSettle();
      expect(consent.isGrantedFor('高德地图'), isTrue);
    });
  });
}
