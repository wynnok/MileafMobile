import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mileaf/main.dart';
import 'package:mileaf/src/design/components/components.dart';
import 'package:mileaf/src/design/tokens.dart';
import 'package:mileaf/src/workspace.dart';

import 'support/session_store.dart';
import 'support/test_trust_store.dart' show MemoryTrustStore;
import 'support/vehicle_preferences.dart';

/// MG06/PD12：概览与行程焦点卡头 → 焦点值间距 s12（D1）。
///
/// 本文件依赖 overview/drives 两页的 PD12 接线与 `MileafPeriodHeader`
///（period-header 在途切片），与页面包一同落地提交——见
/// docs/implementation/days-matter-migration.md「工作区状态」。
void main() {
  group('MG06/PD12：焦点卡头 → 焦点值间距 s4 → s12', () {
    testWidgets('概览焦点卡间距为 12', (tester) async {
      await _pumpApp(tester); // 概览是首屏。
      expect(find.byType(MileafPeriodHeader), findsOneWidget);
      expect(_headerToValueGap(tester), MileafSpace.s12);
    });

    testWidgets('行程焦点卡间距为 12', (tester) async {
      await _pumpApp(tester);
      await tester.tap(find.text('行程').last);
      await tester.pumpAndSettle();
      expect(find.byType(MileafPeriodHeader), findsOneWidget);
      expect(_headerToValueGap(tester), MileafSpace.s12);
    });
  });
}

http.Response _jsonResponse(String body) => http.Response(
  body,
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

String _fixture(String name) => File('test/fixtures/$name').readAsStringSync();

MockClient _mockClient() => MockClient((r) async {
  if (r.url.path.endsWith('/meta')) return _jsonResponse(_fixture('meta.json'));
  if (r.url.path.endsWith('/vehicles')) {
    return _jsonResponse(_fixture('vehicles.json'));
  }
  if (r.url.path.endsWith('/stats')) {
    return _jsonResponse(_fixture('driving-stats.json'));
  }
  if (r.url.path.endsWith('/summary')) {
    return _jsonResponse(_fixture('summary.json'));
  }
  return _jsonResponse('{"items":[],"next_cursor":null}');
});

Future<void> _pumpApp(WidgetTester tester) async {
  final store = MemorySessionStore()
    ..value = jsonEncode({
      'site': 'https://example.com/prefix',
      'token': 'test',
      'expires_at': '2099-01-01T00:00:00Z',
    });
  await tester.pumpWidget(
    MileafApp(
      client: _mockClient(),
      sessionStore: store,
      trustStore: MemoryTrustStore(),
      vehiclePreferences: MemoryVehiclePreferences(),
      now: () => DateTime.utc(2026, 3, 30, 12),
      calendar: () async => CalendarContext('Asia/Shanghai'),
    ),
  );
  await tester.pumpAndSettle();
}

/// 焦点卡内：卡头底 → metricLg 主值顶的垂直间距。
double _headerToValueGap(WidgetTester tester) {
  final card = find
      .ancestor(
        of: find.byType(MileafPeriodHeader),
        matching: find.byType(MileafModuleCard),
      )
      .first;
  final headerBottom = tester
      .getRect(find.byType(MileafPeriodHeader).first)
      .bottom;
  final valueBlock = find
      .descendant(
        of: card,
        matching: find.byWidgetPredicate(
          (w) => w is MetricBlock && w.scale == MetricValueScale.metricLg,
        ),
      )
      .first;
  return tester.getRect(valueBlock).top - headerBottom;
}
