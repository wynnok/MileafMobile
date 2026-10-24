import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

/// Optional local diagnostics. Inputs cannot include business data or URLs.
/// A framework-frame event is a candidate, never an OS-present measurement.
enum PerformancePoint {
  dartEntry,
  overviewFrameworkReady,
  resume,
  warmOverviewFrameworkReady,
  driveClick,
  driveMetricsAvailable,
  driveSeriesAvailable,
  driveFrameworkReady,
  driveFailed,
  overviewFailed,
  mapRequest,
  mapFirstTileDecoded,
  mapFailed,
}

abstract final class PerformanceTrace {
  static const enabled = bool.fromEnvironment('MILEAF_PERFORMANCE_TRACE');
  static int _next = 0;
  static int? _resume;
  static bool _initialOverview = false;

  static void mark(PerformancePoint point, {int? trial}) {
    if (!enabled) return;
    developer.Timeline.instantSync(
      'mileaf.${point.name}',
      arguments: {'trial': ?trial},
    );
  }

  static int? start(PerformancePoint point) {
    if (!enabled) return null;
    final trial = ++_next;
    mark(point, trial: trial);
    return trial;
  }

  static void beginResume() {
    if (_initialOverview) _resume = start(PerformancePoint.resume);
  }

  static void overviewFrame(bool Function() stillReadable) {
    if (!enabled || _initialOverview) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_initialOverview || !stillReadable()) return;
      _initialOverview = true;
      mark(PerformancePoint.overviewFrameworkReady);
    });
  }

  static void warmOverviewFrame(bool Function() stillReadable) {
    final trial = _resume;
    if (!enabled || trial == null) return;
    _resume = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (stillReadable()) {
        mark(PerformancePoint.warmOverviewFrameworkReady, trial: trial);
      }
    });
    // A cache hit has no HTTP completion to trigger a new build on foreground.
    WidgetsBinding.instance.scheduleFrame();
  }

  static void driveFrame(int? trial, bool Function() stillReadable) {
    if (!enabled || trial == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (stillReadable()) {
        mark(PerformancePoint.driveFrameworkReady, trial: trial);
      }
    });
  }
}
