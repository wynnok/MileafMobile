import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Source coordinate from TeslaMate. Kept in WGS84 until the map boundary.
@immutable
class Wgs84Point {
  const Wgs84Point(this.lat, this.lon);
  final double lat;
  final double lon;

  bool get isValid =>
      lat.isFinite &&
      lon.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lon >= -180 &&
      lon <= 180;
}

/// A point converted for AMap. Never exposed to the page layer.
@immutable
class Gcj02Point {
  const Gcj02Point(this.lat, this.lon);
  final double lat;
  final double lon;
}

const _a = 6378245.0;
const _ee = 0.00669342162296594323;

bool _outOfChina(double lat, double lon) {
  // A tighter mainland China envelope than the common coarse box. It keeps
  // Singapore/Malaysia/Indonesia and Taipei from being shifted; it is still an
  // approximation and is calibrated in #4 before being treated as survey data.
  if (lon < 73.0 || lon > 135.1 || lat < 18.0 || lat > 53.6) return true;
  return lon > 120.5 && lat < 26.0;
}

double _transformLat(double x, double y) {
  var ret =
      -100.0 +
      2.0 * x +
      3.0 * y +
      0.2 * y * y +
      0.1 * x * y +
      0.2 * math.sqrt(x.abs());
  ret +=
      (20.0 * math.sin(6.0 * x * math.pi) +
          20.0 * math.sin(2.0 * x * math.pi)) *
      2.0 /
      3.0;
  ret +=
      (20.0 * math.sin(y * math.pi) + 40.0 * math.sin(y / 3.0 * math.pi)) *
      2.0 /
      3.0;
  ret +=
      (160.0 * math.sin(y / 12.0 * math.pi) +
          320.0 * math.sin(y * math.pi / 30.0)) *
      2.0 /
      3.0;
  return ret;
}

double _transformLon(double x, double y) {
  var ret =
      300.0 +
      x +
      2.0 * y +
      0.1 * x * x +
      0.1 * x * y +
      0.1 * math.sqrt(x.abs());
  ret +=
      (20.0 * math.sin(6.0 * x * math.pi) +
          20.0 * math.sin(2.0 * x * math.pi)) *
      2.0 /
      3.0;
  ret +=
      (20.0 * math.sin(x * math.pi) + 40.0 * math.sin(x / 3.0 * math.pi)) *
      2.0 /
      3.0;
  ret +=
      (150.0 * math.sin(x / 12.0 * math.pi) +
          300.0 * math.sin(x / 30.0 * math.pi)) *
      2.0 /
      3.0;
  return ret;
}

/// Standard WGS84 -> GCJ-02 conversion used only for the map boundary.
///
/// Points outside mainland China are returned unchanged; the caller still owns
/// the original [Wgs84Point]. This is not a survey-grade datum transformation.
Gcj02Point gcj02FromWgs84(Wgs84Point point) {
  if (!point.isValid || _outOfChina(point.lat, point.lon)) {
    return Gcj02Point(point.lat, point.lon);
  }
  final dLat0 = _transformLat(point.lon - 105.0, point.lat - 35.0);
  final dLon0 = _transformLon(point.lon - 105.0, point.lat - 35.0);
  final radLat = point.lat / 180.0 * math.pi;
  var magic = math.sin(radLat);
  magic = 1 - _ee * magic * magic;
  final sqrtMagic = math.sqrt(magic);
  final dLat =
      (dLat0 * 180.0) / ((_a * (1 - _ee)) / (magic * sqrtMagic) * math.pi);
  final dLon = (dLon0 * 180.0) / (_a / sqrtMagic * math.cos(radLat) * math.pi);
  return Gcj02Point(point.lat + dLat, point.lon + dLon);
}
