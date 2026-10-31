import 'package:flutter/material.dart';
import 'package:mileaf/src/map/map_platform.dart';
import 'package:mileaf/src/map/map_scene.dart';

class FakeMapPlatform implements MapPlatform {
  FakeMapPlatform({this.supported = true, this.providerName = '高德地图'});
  @override
  final String providerName;
  @override
  final bool supported;

  MapScene? scene;
  MapCallbacks? callbacks;
  MapViewController? controller;
  int builds = 0;

  @override
  Widget build(
    MapScene scene,
    MapCallbacks callbacks,
    MapViewController controller,
  ) {
    this.scene = scene;
    this.callbacks = callbacks;
    this.controller = controller;
    builds++;
    return const ColoredBox(color: Color(0xFF2F7D58));
  }

  void completeLoad([String? approval]) {
    callbacks?.onApprovalNumber(approval);
    callbacks?.onLoaded();
  }

  void fail([MapFailure failure = MapFailure.initFailed]) {
    callbacks?.onFailed(failure);
  }
}
