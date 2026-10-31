import 'package:flutter/widgets.dart';

import 'map_scene.dart';

enum MapFailure { initFailed, timeout }

class MapCallbacks {
  const MapCallbacks({
    required this.onLoaded,
    required this.onFailed,
    required this.onApprovalNumber,
  });
  final VoidCallback onLoaded;
  final ValueChanged<MapFailure> onFailed;
  final ValueChanged<String?> onApprovalNumber;
}

/// Small platform boundary; pages never import native map SDK types.
abstract interface class MapPlatform {
  String get providerName;
  bool get supported;
  Widget build(
    MapScene scene,
    MapCallbacks callbacks,
    MapViewController controller,
  );
}

class MapViewController {
  VoidCallback? _fit;
  VoidCallback? _zoomIn;
  VoidCallback? _zoomOut;
  int _generation = 0;

  int attach({
    required VoidCallback fit,
    required VoidCallback zoomIn,
    required VoidCallback zoomOut,
  }) {
    _generation++;
    _fit = fit;
    _zoomIn = zoomIn;
    _zoomOut = zoomOut;
    return _generation;
  }

  void detach([int? token]) {
    if (token != null && token != _generation) return;
    _fit = null;
    _zoomIn = null;
    _zoomOut = null;
  }

  void fit() => _fit?.call();
  void zoomIn() => _zoomIn?.call();
  void zoomOut() => _zoomOut?.call();
}
