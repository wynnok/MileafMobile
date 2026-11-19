import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/src/api.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/components/icons.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/tokens.dart';
import 'package:mileaf/src/map/map_consent.dart';
import 'package:mileaf/src/map/map_key.dart';
import 'package:mileaf/src/map/map_privacy_page.dart';
import 'package:mileaf/src/session.dart';
import 'package:mileaf/src/session_pages.dart';

import 'support/map_key_fixture.dart';
import 'support/session_store.dart';
import 'support/shell_harness.dart';
import 'support/test_trust_store.dart';

/// MC10 票合同测试：工作区 / 设置 / 连接 / 地图的图标接线与「不上彩色」纪律。
///
/// 条款：CL05 + 映射表 #9（这三页不引入数据身份色相）、CL12/CL13/CL14（图标
/// 取色、尺寸、按钮图标在左且复述词义）、CL20（间距档位）。
void main() {
  group('工作区 / 车辆（CL12/CL13/CL14）', () {
    testWidgets('车辆弹层：车行 leading car，刷新车辆列表配 refresh', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.text('行笺测试车'));
      await tester.pumpAndSettle();
      expect(find.text('选择车辆'), findsOneWidget);
      final rows = tester
          .widgetList<MileafGroupRow>(
            find.descendant(
              of: find.byType(MileafSheetFrame),
              matching: find.byType(MileafGroupRow),
            ),
          )
          .toList();
      expect(rows.length, 2);
      for (final row in rows) {
        expect(row.leading, MileafIconName.car, reason: '车行身份图标 car');
        // 车行仍是中性行：没有数据身份色相。
        expect(row.hue, isNull, reason: 'CL05：本组不上语义色相');
      }
      final refreshFinder = find.widgetWithText(MileafButton, '刷新车辆列表');
      expect(
        tester.widget<MileafButton>(refreshFinder).icon,
        MileafActionIcon.refresh,
        reason: '刷新配 refresh（图标只复述词义）',
      );
      final icon = find.descendant(
        of: refreshFinder,
        matching: find.byType(MileafIcon),
      );
      expect(icon, findsOneWidget);
      expect(
        tester.getSize(icon),
        Size.square(MileafIconMetrics.inline),
        reason: 'CL13.1：按钮内图标 inline 16',
      );
      expect(
        tester.getCenter(icon).dx,
        lessThan(tester.getCenter(find.text('刷新车辆列表')).dx),
        reason: 'CL14：图标在左',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('车辆页：站点车辆行 leading car，重试车辆读取用同一 refresh 字形', (tester) async {
      final session = SessionController(
        MileafApi(
          MockClient((_) async => http.Response('[]', 200)),
          trustStore: MemoryTrustStore(),
        ),
        MemorySessionStore(),
      );
      addTearDown(session.dispose);
      session.message = '服务返回格式不兼容，请核对 Mileaf Server 版本';
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
      final rows = tester.widgetList<MileafGroupRow>(
        find.byType(MileafGroupRow),
      );
      expect(rows.length, 2);
      for (final row in rows) {
        expect(row.leading, MileafIconName.car);
        expect(row.hue, isNull);
      }
      expect(
        tester
            .widget<MileafButton>(find.widgetWithText(MileafButton, '重试车辆读取'))
            .icon,
        MileafActionIcon.retry,
        reason: '重试与刷新是同一动作、同一字形',
      );
    });
  });

  group('地图设置页（CL12/CL14）', () {
    testWidgets('保存 Key 配 save，清除 Key 弹层动作配 close', (tester) async {
      final keys = await configuredMapKeys();
      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(Brightness.light),
          home: MapPrivacyPage(
            consent: MapConsentController(),
            providerName: '高德地图',
            keys: keys,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Android 地图 Key'));
      await tester.pumpAndSettle();
      final saveFinder = find.widgetWithText(MileafButton, '保存 Key');
      expect(
        tester.widget<MileafButton>(saveFinder).icon,
        MileafActionIcon.save,
      );
      final saveIcon = find.descendant(
        of: saveFinder,
        matching: find.byType(MileafIcon),
      );
      expect(tester.getSize(saveIcon), Size.square(MileafIconMetrics.inline));
      expect(
        tester.getCenter(saveIcon).dx,
        lessThan(tester.getCenter(find.text('保存 Key')).dx),
        reason: 'CL14：图标在左',
      );
      await tester.tap(find.text('取消更换'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('清除已保存的 Key'));
      await tester.pumpAndSettle();
      final clearIcon = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is MileafIcon && widget.name == MileafActionIcon.clear,
        ),
      );
      expect(clearIcon, findsOneWidget, reason: '清除配 close');
      expect(
        tester.widget<MileafIcon>(clearIcon).color,
        const MileafColors.light().accentStrong,
        reason: 'CL12：动作图标取该控件前景色',
      );
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('读取失败：重试行 leading refresh，标题与状态句同一起始线', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final keys = MapKeyController(TestKeyStore()..failRead = true);
      await keys.restore();
      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(Brightness.light),
          home: MapPrivacyPage(
            consent: MapConsentController(),
            providerName: '高德地图',
            keys: keys,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final retryRow = find.widgetWithText(MileafGroupRow, '重试读取配置');
      expect(retryRow, findsOneWidget);
      expect(
        tester.widget<MileafGroupRow>(retryRow).leading,
        MileafActionIcon.retry,
      );
      // R24：行首图标 20 落在卡片内边距，于是行标题与状态句同为「图标 + 间距」线。
      final icon = find.descendant(
        of: retryRow,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is MileafIcon && widget.name == MileafActionIcon.retry,
        ),
      );
      expect(tester.getSize(icon), Size.square(MileafIconMetrics.nav));
      expect(
        tester.widget<MileafIcon>(icon).color,
        const MileafColors.light().textSecondary,
        reason: '行首图标中性（不用数据身份色）',
      );
      expect(
        tester.getTopLeft(find.text('重试读取配置')).dx,
        tester.getTopLeft(find.text('地图配置读取失败')).dx,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('不上彩色与间距档位（源级守卫）', () {
    const held = <String>[
      'lib/src/workspace_page.dart',
      'lib/src/session_pages.dart',
      'lib/src/connection_page.dart',
      'lib/src/map/map_privacy_page.dart',
    ];

    test('本组四页不引入数据身份色相与裸色值', () {
      for (final path in held) {
        final source = File(path).readAsStringSync();
        expect(source.contains('MileafHue'), isFalse, reason: '$path 用色相');
        expect(
          source.contains('MileafDataDomain'),
          isFalse,
          reason: '$path 绑定数据域',
        );
        expect(
          RegExp(r'Color\(0x|0x[0-9A-Fa-f]{8}').hasMatch(source),
          isFalse,
          reason: '$path 出现裸色值',
        );
      }
    });

    test('本组四页的间距只用 CL20 档位', () {
      const tiers = {
        'inline2',
        's4',
        's8',
        's12',
        's16',
        's20',
        's24',
        's32',
        'section',
        'cardPad',
        'cardInset',
      };
      for (final path in held) {
        final source = File(path).readAsStringSync();
        for (final match in RegExp(
          r'MileafSpace\.([A-Za-z0-9]+)',
        ).allMatches(source)) {
          expect(
            tiers,
            contains(match.group(1)),
            reason: '$path 用了非档位间距 ${match.group(0)}',
          );
        }
        expect(
          RegExp(r'(?:height|width):\s*[1-9][0-9]*(?:\.[0-9]+)?')
              .hasMatch(source),
          isFalse,
          reason: '$path 出现裸间距字面量',
        );
      }
    });
  });
}
