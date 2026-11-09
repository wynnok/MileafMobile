import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'amap_scene_wire.dart';
import 'map_platform.dart';
import 'map_key.dart';
import 'map_scene.dart';

class AmapIosPlatform implements MapPlatform {
  const AmapIosPlatform();
  @override
  String get providerName => '高德地图';
  @override
  bool get supported => Platform.isIOS;
  @override
  Widget build(
    MapScene scene,
    MapCallbacks callbacks,
    MapViewController controller,
  ) => _AmapIosView(scene: scene, callbacks: callbacks, controller: controller);
}

class _AmapIosView extends StatefulWidget {
  const _AmapIosView({
    required this.scene,
    required this.callbacks,
    required this.controller,
  });
  final MapScene scene;
  final MapCallbacks callbacks;
  final MapViewController controller;

  @override
  State<_AmapIosView> createState() => _AmapIosViewState();
}

class _AmapIosViewState extends State<_AmapIosView> {
  MethodChannel? _channel;
  int? _controllerToken;
  String? _sentSceneSignature;
  String? _sentSelected;

  @override
  void didUpdateWidget(covariant _AmapIosView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final channel = _channel;
    if (channel == null) return;
    final nextScene = AmapSceneWire.signature(widget.scene);
    final nextSelected = AmapSceneWire.selectedSignature(widget.scene);
    if (nextScene != _sentSceneSignature) {
      _sentSceneSignature = nextScene;
      _sentSelected = nextSelected;
      channel.invokeMethod<void>(
        'setScene',
        AmapSceneWire.encode(widget.scene, Theme.of(context).colorScheme),
      );
    } else if (nextSelected != _sentSelected) {
      _sentSelected = nextSelected;
      channel.invokeMethod<void>(
        'setSelected',
        AmapSceneWire.pair(widget.scene.gcj02Selected),
      );
    }
  }

  Future<void> _onPlatformViewCreated(int id) async {
    final channel = MethodChannel('mileaf/amap_ios_$id');
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
    final creation = AmapSceneWire.creationParams(widget.scene, colors);
    creation['apiKey'] = MapKeyScope.maybeOf(context)?.keyForMap();
    _sentSceneSignature = AmapSceneWire.signature(widget.scene);
    _sentSelected = AmapSceneWire.selectedSignature(widget.scene);
    return UiKitView(
      viewType: 'app.mileaf/amap_ios',
      creationParams: creation,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }
}
