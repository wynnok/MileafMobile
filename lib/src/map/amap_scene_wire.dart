import 'package:flutter/material.dart';

import 'geo.dart';
import 'map_scene.dart';

/// One encoding for both AMap platform views. Keeping the wire contract here
/// prevents the Android and iOS adapters from drifting apart.
class AmapSceneWire {
  const AmapSceneWire._();

  static const padding = 36.0;

  static Map<String, dynamic> creationParams(
    MapScene scene,
    ColorScheme colors,
  ) => {
    // MapPanel only builds after consent; native re-checks this so a future
    // caller cannot create a map view by bypassing the panel.
    'consent': true,
    'interactive': scene.interactive,
    'scene': encode(scene, colors),
  };

  static Map<String, dynamic> encode(MapScene scene, ColorScheme colors) => {
    'segments': [
      for (final part in scene.gcj02Segments)
        [
          for (final point in part) [point.lat, point.lon],
        ],
    ],
    'start': pair(scene.gcj02Start),
    'end': pair(scene.gcj02End),
    'selected': pair(scene.gcj02Selected),
    'night': scene.brightness == Brightness.dark,
    'interactive': scene.interactive,
    'padding': padding,
    'colors': {
      'line': colors.primary.toARGB32(),
      'start': colors.primary.toARGB32(),
      'end': colors.onSurface.toARGB32(),
      'selected': colors.tertiary.toARGB32(),
    },
  };

  static List<double>? pair(Gcj02Point? point) =>
      point == null ? null : [point.lat, point.lon];

  static String signature(MapScene scene) => [
    for (final part in scene.segments)
      [for (final point in part) '${point.lat},${point.lon}'].join(';'),
    scene.start?.lat,
    scene.start?.lon,
    scene.end?.lat,
    scene.end?.lon,
    scene.brightness,
    scene.interactive,
  ].join('|');

  static String? selectedSignature(MapScene scene) => scene.selected == null
      ? null
      : '${scene.selected!.lat},${scene.selected!.lon}';
}
