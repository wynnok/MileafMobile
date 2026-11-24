// 高精度合成数据夹具：能耗专题（P08）版式回归与渲染入口共用。
//
// 仓库口径（docs/implementation/render-archive.md）：被多个测试复用的夹具搬到
// test/support/，不要在 *_test.dart 之间互相 import。
//
// 为什么必须带 15 位有效数字：修复前的本页把 num 直接 toString() 上屏，读数把
// 行宽吃光——只有夹具保留足够的小数位，这些问题才会在断言与渲染里出现；四舍五入
// 过的夹具会让它们同时消失。
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../statistics_conditions_test.dart' show conditionsFixture;
import '../statistics_usage_test.dart' show usageClient;

/// 合成浮点复现长读数的宽度，覆盖舍入边界和缺失数据。
Map<String, dynamic> rawConditions({List<int> lowers = const [5, 10, 15]}) {
  final body = conditionsFixture();
  final bins = (body['temperature_bins'] as List).cast<Map<String, dynamic>>();
  const consumptions = <num?>[164.38290651723641, 155.70834162957324, null];
  // 使用三组正温区标签复现窄屏分段控件折行。
  for (var i = 0; i < bins.length; i++) {
    final lower = lowers[i % lowers.length];
    bins[i]
      ..['lower_c'] = lower
      ..['upper_c'] = lower + 5
      ..['consumption_wh_km'] = consumptions[i % consumptions.length]
      ..['drives'] = 18
      ..['distance_km'] = 342.683510792146
      ..['paired_distance_km'] = 87.2385073
      ..['paired_energy_kwh'] = 48.63150729
      ..['median_drive_distance_km'] = 62.87154029418361
      ..['mean_trip_speed_kmh'] = 47.26830451962731;
  }
  for (final bin
      in (body['distance_bins'] as List).cast<Map<String, dynamic>>()) {
    bin
      ..['drives'] = 18
      ..['distance_km'] = 342.683510792146
      ..['paired_distance_km'] = 87.2385073
      ..['paired_energy_kwh'] = 48.63150729
      ..['consumption_wh_km'] = 164.29051643870132;
  }
  (body['summary'] as Map<String, dynamic>)['driving_distance_km'] =
      342.683510792146;
  return body;
}

/// 合成 13 个温度组，复现分段控件需要多行排列的情况。
Map<String, dynamic> denseConditions({int bins = 13}) {
  final body = rawConditions();
  final base = ((body['temperature_bins'] as List).first as Map)
      .cast<String, dynamic>();
  body['temperature_bins'] = [
    for (var i = 0; i < bins; i++)
      {
        ...base,
        'lower_c': -10 + i * 5,
        'upper_c': -5 + i * 5,
        // 每组都带样本，读数标签才有机会互相挤压。
        'consumption_wh_km': 150.25 + i * 3.5,
        'sample_status': 'adequate',
        'evidence_filter': {
          ...(base['evidence_filter'] as Map).cast<String, dynamic>(),
          'outside_temp_min_c': -10 + i * 5,
          'outside_temp_max_c': -5 + i * 5,
        },
      },
  ];
  return body;
}

http.Client conditionsBodyClient(Map<String, dynamic> body) {
  final base = usageClient([]);
  return MockClient((request) async {
    if (request.url.path.endsWith('/driving-analysis') &&
        request.url.queryParameters['view'] == 'conditions') {
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    // 其它端点交给既有夹具；请求已被外层客户端 finalize，必须重建一份。
    final forwarded = http.Request(request.method, request.url)
      ..headers.addAll(request.headers)
      ..bodyBytes = request.bodyBytes;
    return http.Response.fromStream(await base.send(forwarded));
  });
}
