import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'map_platform.dart';
import 'map_scene.dart';

/// Interim iOS provider while no AMap iOS key is configured. It is labelled as
/// Apple Maps, never as AMap, and shares the same Dart scene contract.
class MapKitPlatform implements MapPlatform {
  const MapKitPlatform();
  @override
  String get providerName => 'Apple 地图';
  @override
  bool get supported => Platform.isIOS;
  @override
  Widget build(
    MapScene scene,
    MapCallbacks callbacks,
    MapViewController controller,
  ) => _MapKitView(scene: scene, callbacks: callbacks, controller: controller);
}

class _MapKitView extends StatefulWidget {
  const _MapKitView({
    required this.scene,
    required this.callbacks,
    required this.controller,
  });
  final MapScene scene;
  final MapCallbacks callbacks;
  final MapViewController controller;

  @override
  State<_MapKitView> createState() => _MapKitViewState();
}

class _MapKitViewState extends State<_MapKitView> {
  MethodChannel? _channel;
  int? _controllerToken;
  String? _sentSceneSignature;
  String? _sentSelected;

  Map<String, dynamic> get _sceneMap => {
    'segments': [
      for (final part in widget.scene.segments)
        [
          for (final point in part) [point.lat, point.lon],
        ],
    ],
    'start': _pair(widget.scene.start?.lat, widget.scene.start?.lon),
    'end': _pair(widget.scene.end?.lat, widget.scene.end?.lon),
    'selected': _pair(widget.scene.selected?.lat, widget.scene.selected?.lon),
    'night': widget.scene.brightness == Brightness.dark,
    'interactive': widget.scene.interactive,
    'padding': 36,
    'colors': {
      'line': Theme.of(context).colorScheme.primary.toARGB32(),
      'start': Theme.of(context).colorScheme.primary.toARGB32(),
      'end': Theme.of(context).colorScheme.onSurface.toARGB32(),
      'selected': Theme.of(context).colorScheme.tertiary.toARGB32(),
    },
  };

  List<double>? _pair(double? lat, double? lon) =>
      lat == null || lon == null ? null : [lat, lon];

  String _sceneSignature(MapScene scene) => [
    for (final part in scene.segments)
      [for (final point in part) '${point.lat},${point.lon}'].join(';'),
    scene.start?.lat,
    scene.start?.lon,
    scene.end?.lat,
    scene.end?.lon,
    scene.brightness,
    scene.interactive,
  ].join('|');

  String? _selectedSignature(MapScene scene) => scene.selected == null
      ? null
      : '${scene.selected!.lat},${scene.selected!.lon}';

  @override
  void didUpdateWidget(covariant _MapKitView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final channel = _channel;
    if (channel == null) return;
    final nextScene = _sceneSignature(widget.scene);
    final nextSelected = _selectedSignature(widget.scene);
    if (nextScene != _sentSceneSignature) {
      _sentSceneSignature = nextScene;
      _sentSelected = nextSelected;
      channel.invokeMethod<void>('setScene', _sceneMap);
    } else if (nextSelected != _sentSelected) {
      _sentSelected = nextSelected;
      channel.invokeMethod<void>(
        'setSelected',
        _pair(widget.scene.selected?.lat, widget.scene.selected?.lon),
      );
    }
  }

  Future<void> _onPlatformViewCreated(int id) async {
    final channel = MethodChannel('mileaf/mapkit_$id');
    if (!mounted) {
      channel.setMethodCallHandler(null);
      return;
    }
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'onMapLoaded') {
        widget.callbacks.onApprovalNumber(null);
        widget.callbacks.onLoaded();
      } else if (call.method == 'onMapFailed') {
        widget.callbacks.onFailed(MapFailure.initFailed);
      }
    });
    _controllerToken = widget.controller.attach(
      fit: () => channel.invokeMethod<void>('fitBounds'),
      zoomIn: () => channel.invokeMethod<void>('zoomIn'),
      zoomOut: () => channel.invokeMethod<void>('zoomOut'),
    );
    try {
      final status = await channel.invokeMethod<Map>('getStatus');
      if (!mounted) return;
      if (status?['status'] == 'loaded') {
        widget.callbacks.onLoaded();
      } else if (status?['status'] == 'failed') {
        widget.callbacks.onFailed(MapFailure.initFailed);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    widget.controller.detach(_controllerToken);
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final creation = _sceneMap;
    _sentSceneSignature = _sceneSignature(widget.scene);
    _sentSelected = _selectedSignature(widget.scene);
    return UiKitView(
      viewType: 'app.mileaf/mapkit',
      creationParams: {'consent': true, 'scene': creation},
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }
}
