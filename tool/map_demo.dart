// 独立研发入口；不加入正式 App 导航，也不代表 Ticket #4 已通过。
import 'package:flutter/material.dart';
import 'package:mileaf/src/map_candidate.dart';

void main() {
  const url = String.fromEnvironment('MILEAF_MAP_TILE_URL');
  const attribution = String.fromEnvironment('MILEAF_MAP_ATTRIBUTION');
  const crs = String.fromEnvironment('MILEAF_MAP_CRS');
  runApp(
    MaterialApp(
      title: 'Mileaf 地图候选验证',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF426B54)),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF426B54),
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('地图候选 · 未通过验收')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('以下为合成测试点，不是实际行程，也不是坐标校准证据。'),
                const SizedBox(height: 16),
                CandidateMap(
                  sourceCrs: 'EPSG:4326',
                  provider: url.isEmpty
                      ? null
                      : const CandidateMapProvider(
                          urlTemplate: url,
                          attribution: attribution,
                          coordinateSystem: crs,
                        ),
                  coordinates: const [
                    MapCoordinate(31.2300, 121.4700),
                    MapCoordinate(31.2310, 121.4710),
                    null,
                    MapCoordinate(31.2330, 121.4730),
                    MapCoordinate(31.2340, 121.4740),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('尚缺发行授权、真实校准记录和中国大陆网络双端发布构建验收。'),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
