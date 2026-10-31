import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'geo.dart';
import 'map_platform.dart';
import 'map_scene.dart';

class AmapAndroidPlatform implements MapPlatform {
  const AmapAndroidPlatform();
  @override
  String get providerName => '高德地图';
  @override
  bool get supported => Platform.isAndroid;
  @override
  Widget build(
    MapScene scene,
    MapCallbacks callbacks,
    MapViewController controller,
  ) => _AmapAndroidView(
    scene: scene,
    callbacks: callbacks,
    controller: controller,
  );
}

class _AmapAndroidView extends StatefulWidget {
  const _AmapAndroidView({
    required this.scene,
    required this.callbacks,
    required this.controller,
  });
  final MapScene scene;
  final MapCallbacks callbacks;
  final MapViewController controller;

  @override
  State<_AmapAndroidView> createState() => _AmapAndroidViewState();
}

class _AmapAndroidViewState extends State<_AmapAndroidView> {
  MethodChannel? _channel;
  int? _controllerToken;
  String? _sentSceneSignature;
  String? _sentSelected;

  Map<String, dynamic> _sceneMap(ColorScheme colors) => {
    'segments': [
      for (final part in widget.scene.gcj02Segments)
        [
          for (final point in part) [point.lat, point.lon],
        ],
    ],
    'start': _pair(widget.scene.gcj02Start),
    'end': _pair(widget.scene.gcj02End),
    'selected': _pair(widget.scene.gcj02Selected),
    'night': widget.scene.brightness == Brightness.dark,
    'interactive': widget.scene.interactive,
    'padding': 36,
    'colors': {
      'line': colors.primary.toARGB32(),
      'start': colors.primary.toARGB32(),
      'end': colors.onSurface.toARGB32(),
      'selected': colors.tertiary.toARGB32(),
    },
  };

  List<double>? _pair(Gcj02Point? point) =>
      point == null ? null : [point.lat, point.lon];

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
  void didUpdateWidget(covariant _AmapAndroidView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final channel = _channel;
    if (channel == null) return;
    final nextScene = _sceneSignature(widget.scene);
    final nextSelected = _selectedSignature(widget.scene);
    if (nextScene != _sentSceneSignature) {
      _sentSceneSignature = nextScene;
      _sentSelected = nextSelected;
      channel.invokeMethod<void>(
        'setScene',
        _sceneMap(Theme.of(context).colorScheme),
      );
    } else if (nextSelected != _sentSelected) {
      _sentSelected = nextSelected;
      channel.invokeMethod<void>(
        'setSelected',
        _pair(widget.scene.gcj02Selected),
      );
    }
  }

  Future<void> _onPlatformViewCreated(int id) async {
    final channel = MethodChannel('mileaf/amap_$id');
    if (!mounted) {
      channel.setMethodCallHandler(null);
      return;
    }
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onMapLoaded':
          final args = call.arguments;
          final approval = args is Map
              ? args['approvalNumber'] as String?
              : null;
          widget.callbacks.onApprovalNumber(approval);
          widget.callbacks.onLoaded();
        case 'onMapFailed':
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
      final value = status?['status'];
      if (value == 'loaded') {
        widget.callbacks.onApprovalNumber(status?['approvalNumber'] as String?);
        widget.callbacks.onLoaded();
      } else if (value == 'failed') {
        widget.callbacks.onFailed(MapFailure.initFailed);
      }
    } catch (_) {
      // Native side may still be creating; the MapPanel timer is the backstop.
    }
  }

  @override
  void dispose() {
    widget.controller.detach(_controllerToken);
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final creation = _sceneMap(colors);
    _sentSceneSignature = _sceneSignature(widget.scene);
    _sentSelected = _selectedSignature(widget.scene);
    return AndroidView(
      viewType: 'app.mileaf/amap',
      creationParams: {
        'consent': true,
        'interactive': widget.scene.interactive,
        'scene': creation,
      },
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }
}
