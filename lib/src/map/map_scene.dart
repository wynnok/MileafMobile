import 'package:flutter/foundation.dart';

import 'geo.dart';

/// Raw coordinate input; null/invalid values break a route segment.
@immutable
class MapCoordinate {
  const MapCoordinate(this.latitude, this.longitude);
  final double? latitude;
  final double? longitude;

  Wgs84Point? get valid {
    final lat = latitude;
    final lon = longitude;
    if (lat == null || lon == null) return null;
    final point = Wgs84Point(lat, lon);
    return point.isValid ? point : null;
  }
}

@immutable
class MapScene {
  const MapScene({
    required this.segments,
    this.start,
    this.end,
    this.selected,
    this.selectedLabel,
    this.interactive = false,
    this.brightness = Brightness.light,
  });

  final List<List<Wgs84Point>> segments;
  final Wgs84Point? start;
  final Wgs84Point? end;
  final Wgs84Point? selected;
  final String? selectedLabel;
  final bool interactive;
  final Brightness brightness;

  int get pointCount => segments.fold(0, (sum, part) => sum + part.length);
  bool get isEmpty => pointCount == 0 && start == null && end == null;

  List<Wgs84Point> get visible => [
    ...segments.expand((part) => part),
    ?start,
    ?end,
  ];

  /// The only place the source scene is converted for AMap.
  List<List<Gcj02Point>> get gcj02Segments => [
    for (final part in segments)
      [for (final point in part) gcj02FromWgs84(point)],
  ];

  Gcj02Point? get gcj02Start => start == null ? null : gcj02FromWgs84(start!);
  Gcj02Point? get gcj02End => end == null ? null : gcj02FromWgs84(end!);
  Gcj02Point? get gcj02Selected =>
      selected == null ? null : gcj02FromWgs84(selected!);
}

MapScene driveScene({
  required List<MapCoordinate?> coordinates,
  required MapCoordinate? start,
  required MapCoordinate? end,
  required MapCoordinate? selected,
  required String? selectedLabel,
  required Brightness brightness,
  required bool interactive,
}) {
  final segments = <List<Wgs84Point>>[];
  var current = <Wgs84Point>[];
  for (final coordinate in coordinates) {
    final point = coordinate?.valid;
    if (point == null) {
      if (current.isNotEmpty) segments.add(current);
      current = <Wgs84Point>[];
      continue;
    }
    current.add(point);
  }
  if (current.isNotEmpty) segments.add(current);
  return MapScene(
    segments: segments,
    start: start?.valid,
    end: end?.valid,
    selected: selected?.valid,
    selectedLabel: selectedLabel,
    brightness: brightness,
    interactive: interactive,
  );
}

MapScene placeScene({
  required MapCoordinate? location,
  required Brightness brightness,
  required bool interactive,
}) => MapScene(
  segments: const [],
  start: location?.valid,
  brightness: brightness,
  interactive: interactive,
);
