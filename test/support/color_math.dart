import 'dart:math' as math;

import 'package:flutter/material.dart';

/// WCAG relative luminance / contrast maths plus the sRGB source-over blend
/// used to predict what a translucent paint looks like on a given background.
///
/// Tests that judge a rendered mark compare the pixels actually painted, not
/// the token; these helpers keep the maths in one place for that comparison.
double _linear(double channel) => channel <= 0.04045
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

double luminance(Color color) =>
    0.2126 * _linear(color.r) +
    0.7152 * _linear(color.g) +
    0.0722 * _linear(color.b);

/// 1–21; 3.0 is the graphics floor, 4.5 the text floor (Spec §1 R3).
double contrastRatio(Color foreground, Color background) {
  final a = luminance(foreground), b = luminance(background);
  final high = a > b ? a : b, low = a > b ? b : a;
  return (high + .05) / (low + .05);
}

int _byte(double channel) => (channel * 255).round().clamp(0, 255);

/// Opaque result of painting [color] at [alpha] over [background].
Color compositeOver(Color color, double alpha, Color background) => Color.fromARGB(
  255,
  _byte(color.r * alpha + background.r * (1 - alpha)),
  _byte(color.g * alpha + background.g * (1 - alpha)),
  _byte(color.b * alpha + background.b * (1 - alpha)),
);
