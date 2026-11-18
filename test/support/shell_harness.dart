import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/appearance.dart';
import 'package:mileaf/src/map/map_key.dart';
import 'package:mileaf/src/workspace.dart';

import 'session_store.dart';
import 'test_trust_store.dart';
import 'vehicle_preferences.dart';

/// AP13 归拢（AP14 落地）：外壳泵装与假数据夹具从 appearance_shell_test.dart
/// 迁入 test/support/，供多个测试文件复用；行为与原实现一致。

/// 外观偏好内存存储：可注入失败写。
class MemoryAppearanceStore implements AppearancePreferenceStore {
  String? value;
  bool failWrites = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? next) async {
    if (failWrites) throw StateError('disk full');
    value = next;
  }
}

/// 读取 test/fixtures 下的 JSON 夹具。
dynamic fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync());

http.Response _ok(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// 覆盖外壳启动所需端点的 MockClient；传入 [calls] 时记录全部请求 URL。
MockClient shellClient({List<Uri>? calls}) => MockClient((request) async {
  calls?.add(request.url);
  final path = request.url.path;
  if (path.endsWith('/vehicles')) return _ok(fixture('vehicles'));
  if (path.endsWith('/meta')) return _ok(fixture('meta'));
  if (path.endsWith('/summary')) return _ok(fixture('summary'));
  if (path.endsWith('/stats')) {
    return _ok(
      fixture(
        request.url.queryParameters['kind'] == 'charging'
            ? 'charging-stats'
            : 'driving-stats',
      ),
    );
  }
  if (path.endsWith('/drives')) return _ok(fixture('drives'));
  if (path.endsWith('/charging-sessions')) {
    return _ok({'items': [], 'next_cursor': null});
  }
  return http.Response('{}', 404);
});

/// 泵装完整外壳（固定站点/会话/信任库/车辆偏好/日历），返回外观控制器。
Future<AppearanceController> pumpShell(
  WidgetTester tester, {
  AppearanceController? appearance,
  List<Uri>? calls,
  double textScale = 1,
  MapKeyController? mapKeys,
}) async {
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() => tester.platformDispatcher.clearTextScaleFactorTestValue());
  final controller =
      appearance ?? AppearanceController(MemoryAppearanceStore());
  final store = MemorySessionStore()
    ..value = jsonEncode({
      'site': 'https://example.com/prefix',
      'token': 'test',
      'expires_at': '2099-01-01T00:00:00Z',
    });
  await tester.pumpWidget(
    MileafApp(
      client: shellClient(calls: calls),
      mapKeys: mapKeys,
      appearance: controller,
      sessionStore: store,
      trustStore: MemoryTrustStore(),
      vehiclePreferences: MemoryVehiclePreferences(),
      now: () => DateTime.utc(2026, 10, 26, 10, 40),
      calendar: () async => CalendarContext('Asia/Shanghai'),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}
