import 'dart:async';
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

/// 仅供技术验证入口使用，尚未选定发布底图服务。
class CandidateMap extends StatefulWidget {
  const CandidateMap({
    super.key,
    required this.coordinates,
    required this.sourceCrs,
    this.provider,
    this.tileClient,
  });
  final List<MapCoordinate?> coordinates;
  final String? sourceCrs;
  final CandidateMapProvider? provider;

  /// 专用底图网络边界；不得传入带有站点认证的客户端。
  final http.Client? tileClient;

  @override
  State<CandidateMap> createState() => _CandidateMapState();
}

class _CandidateMapState extends State<CandidateMap> {
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
  bool _failed = false;
  int _generation = 0;

  void _failedTile(int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && generation == _generation && !_failed) {
        setState(() => _failed = true);
      }
    });
  }

  @override
  void didUpdateWidget(CandidateMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider?.urlTemplate != widget.provider?.urlTemplate ||
        oldWidget.provider?.attribution != widget.provider?.attribution ||
        oldWidget.provider?.coordinateSystem !=
            widget.provider?.coordinateSystem ||
        oldWidget.sourceCrs != widget.sourceCrs) {
      _consented = false;
      _failed = false;
      _generation++;
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
    final provider = widget.provider;
    if (provider == null) return const Text('底图尚未配置，地图验证未通过');
    if (!provider.isUsable) {
      return const Text('底图配置不可用，请检查发布方授权、HTTPS XYZ 地址和署名');
    }
    if (widget.sourceCrs != 'EPSG:4326' ||
        provider.coordinateSystem != widget.sourceCrs) {
      return const Text('坐标参考系未核准，不能加载地图');
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
    if (points.isEmpty) return const Text('没有有效轨迹坐标');
    final fit = CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(points),
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
    final location = points.first;
    return Column(
      children: [
        SizedBox(
          height: 280,
          child: FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: location,
              initialZoom: 14,
              minZoom: 1,
              maxZoom: 18,
              initialCameraFit: points.length > 1 ? fit : null,
            ),
            children: [
              TileLayer(
                key: ValueKey(generation),
                urlTemplate: provider.urlTemplate,
                errorTileCallback: (_, error, stack) => _failedTile(generation),
                tileProvider: _SafeTileProvider(_client),
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
                    point: points.first,
                    width: 48,
                    height: 48,
                    child: Icon(
                      Icons.location_on,
                      semanticLabel: points.length == 1 ? '单个采样点' : '起点',
                    ),
                  ),
                  if (points.length > 1)
                    Marker(
                      point: points.last,
                      width: 48,
                      height: 48,
                      child: const Icon(Icons.flag, semanticLabel: '终点'),
                    ),
                ],
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
        Text(
          points.length == 1
              ? '单个采样点'
              : '${points.length} 个有效采样点 · ${segments.length} 段轨迹',
        ),
        if (points.length > 1) const Text('采样连线仅为示意；缺失坐标处已断开。'),
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
  _SafeTileProvider(this.client);
  final http.Client client;
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _SafeTileImage(getTileUrl(coordinates, options), client);
}

class _SafeTileImage extends ImageProvider<_SafeTileImage> {
  const _SafeTileImage(this.url, this.client);
  final String url;
  final http.Client client;

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
            ..headers['User-Agent'] = 'Mileaf-map-verification/0.1';
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
      return await decode(
        await ui.ImmutableBuffer.fromUint8List(response.bodyBytes),
      );
    } on Exception {
      throw const _MapTileFailure();
    }
  }
}

class _MapTileFailure implements Exception {
  const _MapTileFailure();
  @override
  String toString() => '底图暂不可用';
}
