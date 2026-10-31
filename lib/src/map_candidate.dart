import 'performance_trace.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:latlong2/latlong.dart';

/// 原始采样坐标；不修改源值、不推断参考系。
class MapCoordinate {
  const MapCoordinate(this.latitude, this.longitude);
  final double? latitude;
  final double? longitude;
}

/// 发布方提供的已授权底图配置；该类型本身不代表授权或校准已通过。
class CandidateMapProvider {
  const CandidateMapProvider({
    required this.urlTemplate,
    required this.attribution,
    required this.coordinateSystem,
  });
  final String urlTemplate;
  final String attribution;
  final String coordinateSystem;

  bool get isUsable {
    var template = urlTemplate;
    for (final token in ['{z}', '{x}', '{y}']) {
      if (!template.contains(token)) return false;
      template = template.replaceAll(token, '0');
    }
    final uri = Uri.tryParse(template);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.hasAuthority &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasFragment &&
        !template.contains('{') &&
        !template.contains('}') &&
        attribution.trim().isNotEmpty &&
        // 该候选未实现公共 OSM 要求的持久缓存，不可借配置绕过政策。
        uri.host != 'tile.openstreetmap.org' &&
        !uri.host.endsWith('.tile.openstreetmap.org');
  }
}

/// Release-only configuration. Source CRS must be verified by the publisher;
/// an absent value deliberately disables the map without guessing from lat/lon.
class MapConfiguration {
  const MapConfiguration({this.provider, this.sourceCrs, this.tileClient});
  final CandidateMapProvider? provider;
  final String? sourceCrs;
  final http.Client? tileClient;
  static MapConfiguration fromEnvironment() {
    const url = String.fromEnvironment('MILEAF_MAP_TILE_URL');
    const attribution = String.fromEnvironment('MILEAF_MAP_ATTRIBUTION');
    const crs = String.fromEnvironment('MILEAF_MAP_CRS');
    const source = String.fromEnvironment('MILEAF_MAP_SOURCE_CRS');
    return MapConfiguration(
      provider: url.isEmpty
          ? null
          : const CandidateMapProvider(
              urlTemplate: url,
              attribution: attribution,
              coordinateSystem: crs,
            ),
      sourceCrs: source.isEmpty ? null : source,
    );
  }
}

/// Isolated renderer; a configuration value is not proof of provider approval.
class CandidateMap extends StatefulWidget {
  const CandidateMap({
    super.key,
    required this.coordinates,
    required this.sourceCrs,
    this.start,
    this.end,
    this.provider,
    this.tileClient,
    this.selected,
    this.selectedLabel,
    this.heroHeight,
    this.overlay,
  });
  final List<MapCoordinate?> coordinates;
  final MapCoordinate? start, end;
  final MapCoordinate? selected;
  final String? selectedLabel;

  /// Optional fixed map height; with [overlay] this lets a caller draw a C
  /// route caption over the map while keeping attribution/controls below.
  final double? heroHeight;

  /// Caption drawn at the bottom edge of the map area.
  final Widget? overlay;
  final String? sourceCrs;
  final CandidateMapProvider? provider;

  /// 专用底图网络边界；不得传入带有站点认证的客户端。
  final http.Client? tileClient;

  @override
  State<CandidateMap> createState() => _CandidateMapState();
}

class _CandidateMapState extends State<CandidateMap>
    with AutomaticKeepAliveClientMixin<CandidateMap> {
  @override
  bool get wantKeepAlive => true;
  final _controller = MapController();
  late final http.Client _client;
  late final bool _ownsClient;

  @override
  void initState() {
    super.initState();
    _ownsClient = widget.tileClient == null;
    _client =
        widget.tileClient ??
        IOClient(HttpClient()..connectionTimeout = const Duration(seconds: 5));
  }

  bool _consented = false;
  bool _mapReady = false;
  bool _failed = false;
  int? _decodedGeneration;
  int _generation = 0;
  int _geometry = 0;
  int? _traceGeneration;
  int? _performanceTrial;

  void _revealSelected() {
    if (!_consented || !_mapReady) return;
    final lat = widget.selected?.latitude, lon = widget.selected?.longitude;
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lon < -180 ||
        lon > 180) {
      return;
    }
    final point = LatLng(lat, lon), camera = _controller.camera;
    if (!camera.visibleBounds.contains(point)) {
      _controller.move(point, camera.zoom);
    }
  }

  void _decodedTile(int generation) {
    if (!mounted ||
        generation != _generation ||
        _decodedGeneration == generation) {
      return;
    }
    _decodedGeneration = generation;
    PerformanceTrace.mark(
      PerformancePoint.mapFirstTileDecoded,
      trial: _performanceTrial,
    );
  }

  void _failedTile(int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation && !_failed) {
        setState(() => _failed = true);
        PerformanceTrace.mark(
          PerformancePoint.mapFailed,
          trial: _performanceTrial,
        );
      }
    });
  }

  @override
  void didUpdateWidget(CandidateMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool same(MapCoordinate? a, MapCoordinate? b) =>
        a?.latitude == b?.latitude && a?.longitude == b?.longitude;
    final samePoints =
        oldWidget.coordinates.length == widget.coordinates.length &&
        List.generate(
          widget.coordinates.length,
          (i) => same(oldWidget.coordinates[i], widget.coordinates[i]),
        ).every((value) => value);
    if (!samePoints ||
        !same(oldWidget.start, widget.start) ||
        !same(oldWidget.end, widget.end)) {
      _geometry++;
      _mapReady = false;
      _generation++;
      _failed = false;
    }
    if (oldWidget.provider?.urlTemplate != widget.provider?.urlTemplate ||
        oldWidget.provider?.attribution != widget.provider?.attribution ||
        oldWidget.provider?.coordinateSystem !=
            widget.provider?.coordinateSystem ||
        oldWidget.sourceCrs != widget.sourceCrs) {
      _consented = false;
      _mapReady = false;
      _failed = false;
      _generation++;
    }
    if (!same(oldWidget.selected, widget.selected) ||
        oldWidget.selectedLabel != widget.selectedLabel) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _revealSelected();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_ownsClient) _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = widget.provider;
    if (provider == null) return const Text('地图暂不可用：此版本尚未配置底图服务，其他记录仍可阅读');
    if (!provider.isUsable) {
      return const Text('地图暂不可用：底图服务配置无效，其他记录仍可阅读');
    }
    if (widget.sourceCrs != 'EPSG:4326' ||
        provider.coordinateSystem != widget.sourceCrs) {
      return const Text('地图暂不可用：坐标参考系尚未核准，其他记录仍可阅读');
    }
    final segments = <List<LatLng>>[];
    var segment = <LatLng>[];
    for (final point in widget.coordinates) {
      final lat = point?.latitude;
      final lon = point?.longitude;
      if (lat == null ||
          lon == null ||
          !lat.isFinite ||
          !lon.isFinite ||
          lat < -90 ||
          lat > 90 ||
          lon < -180 ||
          lon > 180) {
        segment = <LatLng>[];
        continue;
      }
      if (segment.isEmpty) segments.add(segment);
      segment.add(LatLng(lat, lon));
    }
    final points = segments.expand((part) => part).toList();
    LatLng? endpoint(MapCoordinate? coordinate) {
      final lat = coordinate?.latitude, lon = coordinate?.longitude;
      if (lat == null ||
          lon == null ||
          !lat.isFinite ||
          !lon.isFinite ||
          lat < -90 ||
          lat > 90 ||
          lon < -180 ||
          lon > 180) {
        return null;
      }
      return LatLng(lat, lon);
    }

    final start = endpoint(widget.start);
    final end = endpoint(widget.end);
    final selected = endpoint(widget.selected);
    final visible = [...points, ?start, ?end];
    if (visible.isEmpty) return const Text('没有有效轨迹坐标');

    final fit = CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(visible),
      padding: const EdgeInsets.all(36),
      maxZoom: 16,
    );
    if (!_consented) {
      return Column(
        children: [
          Text(provider.attribution),
          const Text('第三方将收到 IP 和可见区域；不发送站点凭据，也不读取手机定位。'),
          FilledButton(
            onPressed: () => setState(() => _consented = true),
            child: const Text('允许加载底图'),
          ),
        ],
      );
    }
    final generation = _generation;
    if (_traceGeneration != generation) {
      _traceGeneration = generation;
      _performanceTrial = PerformanceTrace.start(PerformancePoint.mapRequest);
    }
    final location = visible.first;
    return Column(
      children: [
        SizedBox(
          height: widget.heroHeight ?? 280,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FlutterMap(
                key: ValueKey(_geometry),
                mapController: _controller,
                options: MapOptions(
                  onMapReady: () {
                    _mapReady = true;
                    _revealSelected();
                  },
                  initialCenter: location,
                  initialZoom: 14,
                  minZoom: 1,
                  maxZoom: 18,
                  initialCameraFit: visible.length > 1 ? fit : null,
                ),
                children: [
                  TileLayer(
                    key: ValueKey(generation),
                    urlTemplate: provider.urlTemplate,
                    errorTileCallback: (_, error, stack) =>
                        _failedTile(generation),
                    tileProvider: _SafeTileProvider(
                      _client,
                      () => _failedTile(generation),
                      () => _decodedTile(generation),
                    ),
                  ),
                  PolylineLayer(
                    polylines: [
                      for (final part in segments)
                        if (part.length > 1)
                          Polyline(
                            points: part,
                            color: Theme.of(context).colorScheme.primary
                                .withValues(alpha: 0.6),
                            strokeWidth: 3,
                          ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: start ?? visible.first,
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.location_on,
                          semanticLabel: start != null
                              ? '行程起点'
                              : points.length == 1
                              ? '单个采样点'
                              : '首个采样点',
                        ),
                      ),
                      if (end != null || points.length > 1)
                        Marker(
                          point: end ?? visible.last,
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.flag,
                            semanticLabel: end != null ? '行程终点' : '末个采样点',
                          ),
                        ),
                      if (selected != null)
                        Marker(
                          point: selected,
                          width: 32,
                          height: 32,
                          child: Icon(
                            Icons.my_location,
                            key: const ValueKey('selected-drive-sample'),
                            color: Theme.of(context).colorScheme.tertiary,
                            semanticLabel: widget.selectedLabel ?? '选中采样位置',
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (widget.overlay != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: widget.overlay!,
                ),
            ],
          ),
        ),
        Text(provider.attribution),
        if (_failed) ...[
          const Text('底图加载失败，其他记录仍可阅读'),
          TextButton(
            onPressed: () => setState(() {
              _failed = false;
              _generation++;
            }),
            child: const Text('重试底图'),
          ),
        ],
        if (points.length < 2)
          Text(points.isEmpty ? '没有有效轨迹坐标，已显示可用起终点' : '单个采样点'),
        ExpansionTile(
          title: const Text('地图数据说明'),
          children: [
            Text('${points.length} 个有效采样点 · ${segments.length} 段轨迹'),
            if (points.length > 1) const Text('采样连线仅为示意；缺失坐标处已断开。'),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: '适配轨迹',
              onPressed: () => _controller.fitCamera(fit),
              icon: const Icon(Icons.fit_screen),
            ),
            IconButton(
              tooltip: '放大地图',
              onPressed: () => _controller.move(
                _controller.camera.center,
                _controller.camera.zoom + 1,
              ),
              icon: const Icon(Icons.add),
            ),
            IconButton(
              tooltip: '缩小地图',
              onPressed: () => _controller.move(
                _controller.camera.center,
                _controller.camera.zoom - 1,
              ),
              icon: const Icon(Icons.remove),
            ),
          ],
        ),
      ],
    );
  }
}

/// flutter_map 会输出加载异常；只传递不含 URL、凭据或坐标的错误。
class _SafeTileProvider extends TileProvider {
  _SafeTileProvider(this.client, this.onFailure, this.onDecoded);
  final http.Client client;
  final VoidCallback onFailure, onDecoded;
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _SafeTileImage(
        getTileUrl(coordinates, options),
        client,
        onFailure,
        onDecoded,
      );
}

class _SafeTileImage extends ImageProvider<_SafeTileImage> {
  const _SafeTileImage(this.url, this.client, this.onFailure, this.onDecoded);
  final String url;
  final http.Client client;
  final VoidCallback onFailure, onDecoded;

  @override
  Future<_SafeTileImage> obtainKey(ImageConfiguration configuration) async =>
      this;

  @override
  ImageStreamCompleter loadImage(
    _SafeTileImage key,
    ImageDecoderCallback decode,
  ) => MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1);

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final abort = Completer<void>();
    try {
      final request =
          http.AbortableRequest(
              'GET',
              Uri.parse(url),
              abortTrigger: abort.future,
            )
            ..followRedirects = false
            ..headers['User-Agent'] = 'Mileaf/0.1 (map)';
      final response =
          await (() async {
            final stream = await client.send(request);
            return http.Response.fromStream(stream);
          })().timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              abort.complete();
              throw const _MapTileFailure();
            },
          );
      if (response.statusCode != 200) throw const _MapTileFailure();
      final codec = await decode(
        await ui.ImmutableBuffer.fromUint8List(response.bodyBytes),
      );
      onDecoded();
      return codec;
    } on Exception {
      // An off-screen tile can lose its stream listener before a failure arrives.
      // Report through the map state, never through Flutter's global image error.
      onFailure();
      return decode(
        await ui.ImmutableBuffer.fromUint8List(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
          ),
        ),
      );
    }
  }
}

class _MapTileFailure implements Exception {
  const _MapTileFailure();
  @override
  String toString() => '底图暂不可用';
}
