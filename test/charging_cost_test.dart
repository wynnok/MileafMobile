import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'charging_detail_test.dart' as detail;
import 'charging_test.dart' show MemoryCurrency;

class CostSite {
  String version = '0.4.0';
  num? cost;
  num? added = 20, used = 22;
  bool active = false, failRead = false;
  bool failStats = false;
  bool twoPages = false;
  bool missing = false;
  final reads = <http.Request>[];
  int detailVehicle = 1;
  String place = '湖畔超级充电站';
  final writes = <http.Request>[];
  Future<http.Response> Function(http.Request)? patch;
  late final client = MockClient(handle);

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (request.method == 'GET') reads.add(request);
    if (path.endsWith('/stats') &&
        request.url.queryParameters['kind'] == 'charging') {
      return failStats
          ? http.Response('', 503)
          : detail.response(detail.fixture('charging-stats'));
    }
    if (path.endsWith('/meta')) {
      return detail.response({'version': version});
    }
    if (path.endsWith('/vehicles/1/charging-sessions')) {
      final second = request.url.queryParameters['cursor'] == 'page2';
      return detail.response({
        'items': [
          if (!missing)
            {
              ...detail.fixture('charging-detail'),
              'id': second ? 2 : 1,
              'cost': second ? 0 : cost,
              'energy_added_kwh': added,
              'energy_used_kwh': used,
              'is_active': active,
              'ended_at': active ? null : '2026-01-05T09:00:00Z',
            },
        ],
        'next_cursor': twoPages && !second ? 'page2' : null,
      });
    }
    if (path.endsWith('/charging-sessions/1/cost')) {
      writes.add(request);
      if (patch != null) return patch!(request);
      cost = 27.5;
      return detail.response({
        'session_id': 1,
        'unit_price': '1.25',
        'billing_energy_kwh': '22',
        'cost': '27.50',
      });
    }
    if (path.endsWith('/charging-sessions/1')) {
      if (missing) return http.Response('', 404);
      if (failRead) return http.Response('', 503);
      return detail.response({
        ...detail.fixture('charging-detail'),
        'cost': cost,
        'energy_added_kwh': added,
        'energy_used_kwh': used,
        'vehicle_id': detailVehicle,
        'is_active': active,
        'ended_at': active ? null : '2026-01-05T09:00:00Z',
        'location': {
          ...detail.fixture('charging-detail')['location'],
          'display_name': place,
        },
      });
    }
    if (path.endsWith('/charging-sessions/1/series')) {
      return detail.response(detail.fixture('charging-series'));
    }
    return detail.initial(request);
  }
}

Future<void> openCostDetail(WidgetTester tester, CostSite site) async {
  await pumpCostApp(tester, site);
  await tester.scrollUntilVisible(find.text('最近充电').hitTestable(), 250);
  await tester.tap(find.text('最近充电').hitTestable());
  await tester.pumpAndSettle();
}

Future<void> pumpCostApp(
  WidgetTester tester,
  CostSite site, {
  Size size = const Size(360, 800),
  String? currencyCode = 'CNY',
  GlobalKey? boundary,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final currency = MemoryCurrency();
  if (currencyCode != null) {
    currency.values['https://example.com/prefix'] = currencyCode;
  }
  final root = detail.app(site.client, currency: currency);
  await tester.pumpWidget(
    boundary == null ? root : RepaintBoundary(key: boundary, child: root),
  );
  await tester.pumpAndSettle();
}

Future<void> openCostSheet(WidgetTester tester) async {
  // 账目/记录页可能同时存在横向可编辑滚动区（金额输入框）；只沿纵向页面滚动，
  // 否则滚错轴会始终找不到行内“补录费用”动作。
  final pageScrollable = find
      .byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      )
      .first;
  // 列表页行内动作写「补录费用」；P05 充电详情把同一动作收成费用格里的
  // 小胶囊「补录」，两个入口共用同一个底部表单。
  final action = find.text('补录').hitTestable().evaluate().isNotEmpty
      ? find.text('补录')
      : find.text('补录费用');
  await tester.scrollUntilVisible(
    action.hitTestable(),
    150,
    scrollable: pageScrollable,
  );
  await tester.tap(action.hitTestable());
  await tester.pumpAndSettle();
}

Future<void> tapCostAction(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('补录返回404会刷新列表，关闭后不保留已失效记录', (tester) async {
    final site = CostSite();
    site.patch = (_) async {
      site.missing = true;
      return http.Response('', 404);
    };
    await pumpCostApp(tester, site);
    await tester.tap(find.text('充电').last);
    await tester.pumpAndSettle();
    await openCostSheet(tester);
    await tester.enterText(find.byType(TextField), '1.25');
    await tapCostAction(tester, '确认补录');
    expect(find.text('该充电记录已不可用'), findsOneWidget);
    await tapCostAction(tester, '关闭');
    expect(find.byKey(const ValueKey('charge-1')), findsNothing);
    expect(find.text('补录费用'), findsNothing);
    expect(site.writes, hasLength(1));
  });
  testWidgets('补录后保留已加载的多页范围，并重新读取后续页', (tester) async {
    final site = CostSite()..twoPages = true;
    await pumpCostApp(tester, site);
    await tester.tap(find.text('充电').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('加载更多充电').hitTestable(), 200);
    await tester.tap(find.text('加载更多充电').hitTestable());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('补录费用').hitTestable(), -200);
    await openCostSheet(tester);
    await tester.enterText(find.byType(TextField), '1.25');
    await tapCostAction(tester, '确认补录');
    expect(
      site.reads.where((r) => r.url.queryParameters['cursor'] == 'page2'),
      hasLength(2),
    );
    expect(find.byKey(const ValueKey('charge-2')), findsOneWidget);
    expect(find.text('补录费用'), findsNothing);
  });
  testWidgets('写入成功后汇总读取失败仍保持成功，不能再次补录', (tester) async {
    final site = CostSite();
    await pumpCostApp(tester, site);
    await tester.tap(find.text('充电').last);
    await tester.pumpAndSettle();
    await openCostSheet(tester);
    await tester.enterText(find.byType(TextField), '1.25');
    site.failStats = true;
    await tapCostAction(tester, '确认补录');
    expect(find.textContaining('费用已补录'), findsOneWidget);
    expect(find.textContaining('部分汇总暂未更新'), findsOneWidget);
    expect(find.text('补录费用'), findsNothing);
    expect(site.writes, hasLength(1));
  });
  for (final status in [400, 422, 404]) {
    testWidgets('费用接口 $status 使用可恢复中文反馈并保留写入边界', (tester) async {
      final site = CostSite()
        ..patch = (_) async => http.Response('private upstream detail', status);
      await openCostDetail(tester, site);
      await openCostSheet(tester);
      await tester.enterText(find.byType(TextField), '1.25');
      await tapCostAction(tester, '确认补录');
      expect(
        find.text(status == 404 ? '该充电记录已不可用' : '单价未被服务接受，请检查范围和小数位后重试'),
        findsOneWidget,
      );
      expect(find.textContaining('private upstream detail'), findsNothing);
      expect(site.writes, hasLength(1));
    });
  }
  testWidgets('成功响应单价或记录不匹配时先查询，不显示成功', (tester) async {
    final site = CostSite()
      ..patch = (_) async => detail.response({
        'session_id': 99,
        'unit_price': '3',
        'billing_energy_kwh': '22',
        'cost': '66.00',
      });
    await openCostDetail(tester, site);
    await openCostSheet(tester);
    await tester.enterText(find.byType(TextField), '1.25');
    await tapCostAction(tester, '确认补录');
    expect(find.text('查询最新结果'), findsOneWidget);
    expect(find.textContaining('费用已补录'), findsNothing);
  });
  for (final version in ['0.3.0', 'unknown', '0.4.0-beta']) {
    testWidgets('旧或未确认版本 $version 保持只读', (tester) async {
      final site = CostSite()..version = version;
      await openCostDetail(tester, site);
      expect(find.text('补录费用'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == '费用 —',
        ),
        findsOneWidget,
      );
      expect(site.writes, isEmpty);
    });
  }
  for (final state in ['zero', 'active', 'energy']) {
    testWidgets('已有零费用、进行中或无效电量不出现入口 $state', (tester) async {
      final site = CostSite();
      if (state == 'zero') site.cost = 0;
      if (state == 'active') site.active = true;
      if (state == 'energy') {
        site.added = null;
        site.used = 0;
      }
      await openCostDetail(tester, site);
      expect(find.text('补录费用'), findsNothing);
      expect(site.writes, isEmpty);
    });
  }
  testWidgets('未知币种允许输入，按原账本口径预估且不默认人民币', (tester) async {
    final site = CostSite();
    await pumpCostApp(tester, site, currencyCode: null);
    await tester.tap(find.text('充电').last);
    await tester.pumpAndSettle();
    await openCostSheet(tester);
    expect(find.textContaining('请按 TeslaMate 原账本币种填写'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1.25');
    await tester.pumpAndSettle();
    expect(find.text('27.50'), findsOneWidget);
    expect(find.text('¥27.50'), findsNothing);
  });
  testWidgets('预检发现记录变成其他车辆，不允许提交', (tester) async {
    final site = CostSite();
    await openCostDetail(tester, site);
    site.detailVehicle = 2;
    await openCostSheet(tester);
    expect(find.text('暂时无法读取本次充电，请重试'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(site.writes, isEmpty);
  });
  testWidgets('并发409读取已有零费用，不误报本次成功', (tester) async {
    final site = CostSite();
    site.patch = (_) async {
      site.cost = 0;
      return http.Response('', 409);
    };
    await openCostDetail(tester, site);
    await openCostSheet(tester);
    await tester.enterText(find.byType(TextField), '1.25');
    await tapCostAction(tester, '确认补录');
    expect(find.text('该记录已有费用 ¥0.00'), findsOneWidget);
    expect(find.textContaining('费用已补录'), findsNothing);
    expect(site.writes, hasLength(1));
  });
  testWidgets('结果查询失败保持待确认，查询仍缺失后仅由用户显式重提', (tester) async {
    final site = CostSite()..patch = (_) async => http.Response('', 503);
    await openCostDetail(tester, site);
    await openCostSheet(tester);
    await tester.enterText(find.byType(TextField), '1.25');
    await tapCostAction(tester, '确认补录');
    site.failRead = true;
    await tapCostAction(tester, '查询最新结果');
    expect(find.text('仍无法确认补录结果，请稍后查询'), findsOneWidget);
    expect(find.text('确认补录'), findsNothing);
    site.failRead = false;
    await tapCostAction(tester, '查询最新结果');
    expect(find.textContaining('最新读取仍无费用'), findsOneWidget);
    expect(site.writes, hasLength(1));
    await tapCostAction(tester, '确认补录');
    expect(site.writes, hasLength(2));
  });
  testWidgets('写入401退出登录并移除旧表单', (tester) async {
    final site = CostSite()..patch = (_) async => http.Response('', 401);
    await openCostDetail(tester, site);
    await openCostSheet(tester);
    await tester.enterText(find.byType(TextField), '1.25');
    await tapCostAction(tester, '确认补录');
    expect(find.text('站点访问口令'), findsOneWidget);
    expect(find.text('充电单价'), findsNothing);
  });
  testWidgets('写入期间双击、遮罩、下拉和系统返回不造成重复或提前关闭', (tester) async {
    final pending = Completer<http.Response>();
    final site = CostSite()..patch = (_) => pending.future;
    await openCostDetail(tester, site);
    await openCostSheet(tester);
    await tester.enterText(find.byType(TextField), '1.25');
    await tester.ensureVisible(find.text('确认补录'));
    await tester.tap(find.text('确认补录'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('确认补录'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
    await tester.tapAt(const Offset(5, 5));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('正在补录费用…').hitTestable(), findsOneWidget);
    await tester.drag(find.text('补录费用').last, const Offset(0, 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('正在补录费用…'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('正在补录费用…'), findsOneWidget);
    expect(site.writes, hasLength(1));
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, false);
    pending.complete(http.Response('', 503));
    await tester.pumpAndSettle();
    expect(find.text('查询最新结果'), findsOneWidget);
  });
  testWidgets('列表补录成功立即显示新费用，原列表阅读上下文保留', (tester) async {
    final site = CostSite();
    await pumpCostApp(tester, site);
    await tester.tap(find.text('充电').last);
    await tester.pumpAndSettle();
    await openCostSheet(tester);
    await tester.enterText(find.byType(TextField), '1.25');
    await tapCostAction(tester, '确认补录');
    expect(find.textContaining('费用已补录'), findsOneWidget);
    expect(find.text('补录费用'), findsNothing);
    expect(find.textContaining('费用 ¥27.5'), findsOneWidget);
  });
  testWidgets('响应丢失后先查询，看到已有费用不再提交也不推断本次成功', (tester) async {
    final site = CostSite();
    site.patch = (_) async {
      site.cost = 27.5;
      throw TimeoutException('test');
    };
    await openCostDetail(tester, site);
    await openCostSheet(tester);
    await tester.enterText(find.byType(TextField), '1.25');
    await tapCostAction(tester, '确认补录');
    expect(find.text('补录结果尚未确认，请先查询最新结果'), findsOneWidget);
    await tapCostAction(tester, '查询最新结果');
    expect(find.text('该记录已有费用 ¥27.50'), findsOneWidget);
    expect(find.textContaining('费用已补录'), findsNothing);
    expect(site.writes, hasLength(1));
  });
  testWidgets('未开启补录保留单价，重新检查只读取记录', (tester) async {
    final site = CostSite()..patch = (_) async => http.Response('', 403);
    await openCostDetail(tester, site);
    await openCostSheet(tester);
    await tester.enterText(find.byType(TextField), '1.25');
    await tapCostAction(tester, '确认补录');
    expect(find.text('站点尚未开启费用补录，请联系管理员'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '1.25',
    );
    await tapCostAction(tester, '重新检查');
    expect(site.writes, hasLength(1));
  });
  testWidgets('列表补录直达同一表单，不触发行导航', (tester) async {
    final site = CostSite();
    await pumpCostApp(tester, site);
    await tester.tap(find.text('充电').last);
    await tester.pumpAndSettle();
    await openCostSheet(tester);
    expect(find.text('充电单价'), findsOneWidget);
    expect(find.text('充电详情 #1'), findsNothing);
    await tester.enterText(find.byType(TextField), '1.25');
    await tester.pumpAndSettle();
    expect(find.text('¥27.50'), findsOneWidget);
  });
  testWidgets('非法和未完成单价就近显示校验，不产生写请求', (tester) async {
    final site = CostSite();
    await openCostDetail(tester, site);
    await openCostSheet(tester);
    for (final example in [
      ('1,25', '请输入有效单价，使用小数点，不含币种或千位分隔符'),
      ('-1', '请输入有效单价，使用小数点，不含币种或千位分隔符'),
      ('1.', '请补全小数部分'),
      ('1000000', '单价须在 0–999999 之间'),
      ('0.0000001', '单价最多支持 6 位小数'),
    ]) {
      await tester.enterText(find.byType(TextField), example.$1);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text(example.$2), findsOneWidget);
      await tapCostAction(tester, '确认补录');
      expect(site.writes, isEmpty);
    }
  });
  testWidgets('明确免费与舍入为零不同，金额使用十进制四舍五入', (tester) async {
    final site = CostSite()
      ..added = 1
      ..used = 1;
    await openCostDetail(tester, site);
    await openCostSheet(tester);
    for (final example in [
      ('0', '¥0.00', '将记录为免费充电'),
      ('0.005', '¥0.01', null),
      ('0.000001', '¥0.00', '费用按两位小数四舍五入'),
    ]) {
      await tester.enterText(find.byType(TextField), example.$1);
      await tester.pumpAndSettle();
      expect(find.text(example.$2), findsOneWidget);
      if (example.$3 != null) expect(find.text(example.$3!), findsOneWidget);
      if (example.$1 != '0') expect(find.text('将记录为免费充电'), findsNothing);
    }
    expect(site.writes, isEmpty);
  });
  testWidgets('详情按较大电量预估费用，单次确认发送字符串单价并展示最终费用', (tester) async {
    final site = CostSite();
    await openCostDetail(tester, site);
    await openCostSheet(tester);
    expect(find.text('充电单价'), findsOneWidget);
    expect(find.textContaining('保存后无法在 App 中修改'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1.25');
    await tester.pumpAndSettle();
    expect(find.text('¥27.50'), findsOneWidget);
    expect(find.text('计费电量 22 kWh'), findsOneWidget);
    await tapCostAction(tester, '确认补录');
    expect(site.writes, hasLength(1));
    expect(site.writes.single.method, 'PATCH');
    expect(site.writes.single.headers['authorization'], 'Bearer test');
    expect(jsonDecode(site.writes.single.body), {'unit_price': '1.25'});
    expect(find.textContaining('费用已补录'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == '费用 ¥27.5',
      ),
      findsOneWidget,
    );
  });
}
