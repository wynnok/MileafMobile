import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'drive_detail_test.dart' show openDetail, fixture;
import 'drive_map_test.dart' show scrollPageTo;
import 'drives_test.dart' show jsonResponse;

void main() {
  testWidgets('C地图开场不虚报默认速度曲线ready，滚到绘图区后才发候选', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    late WebSocket socket;
    final pending = <int, Completer<Map<String, dynamic>>>{};
    var id = 0;
    Future<Map<String, dynamic>> rpc(
      String method, [
      Map<String, dynamic>? params,
    ]) async {
      final n = ++id;
      final c = pending[n] = Completer<Map<String, dynamic>>();
      socket.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': n,
          'method': method,
          'params': ?params,
        }),
      );
      return c.future;
    }

    await tester.runAsync(() async {
      final info = await developer.Service.controlWebServer(enable: true);
      final uri = info.serverUri!;
      socket = await WebSocket.connect(
        uri.replace(scheme: 'ws', path: '${uri.path}ws').toString(),
      );
      addTearDown(() => socket.close());
      socket.listen((data) {
        final body = jsonDecode(data as String) as Map<String, dynamic>;
        pending.remove(body['id'])?.complete(body);
      });
      await rpc('setVMTimelineFlags', {
        'recordedStreams': ['Dart'],
      });
      await rpc('clearVMTimeline');
    });
    Future<int> ready() async {
      final data = await rpc('getVMTimeline');
      return ((data['result'] as Map)['traceEvents'] as List)
          .where((e) => e['name'] == 'mileaf.driveFrameworkReady')
          .length;
    }

    await openDetail(
      tester,
      (r) async => jsonResponse(
        jsonEncode(
          fixture(
            r.url.path.endsWith('/series') ? 'drive-series' : 'drive-detail',
          ),
        ),
      ),
    );
    expect(await tester.runAsync(ready), 0);
    await scrollPageTo(tester, find.byKey(const ValueKey('sample-chart')), 160);
    await tester.ensureVisible(find.byKey(const ValueKey('sample-chart')));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(ready), 1);
    await tester.runAsync(() async {
      await socket.close();
    });
  }, skip: !const bool.fromEnvironment('MILEAF_PERFORMANCE_TRACE'));
}
