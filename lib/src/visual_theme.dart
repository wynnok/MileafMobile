import 'package:flutter/material.dart';

ThemeData lakeTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF2F7D58),
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xFF8AD6AF) : const Color(0xFF2F7D58),
        primaryContainer: dark
            ? const Color(0xFF243E2E)
            : const Color(0xFFE4EEE3),
        onPrimaryContainer: dark
            ? const Color(0xFFEEF5ED)
            : const Color(0xFF142019),
        surface: dark ? const Color(0xFF09140F) : const Color(0xFFE9EFE6),
        surfaceContainerLow: dark
            ? const Color(0xFF12231A)
            : const Color(0xFFFBFDF9),
        onSurface: dark ? const Color(0xFFEEF5ED) : const Color(0xFF142019),
        onSurfaceVariant: dark
            ? const Color(0xFFABBEAE)
            : const Color(0xFF64776A),
        outlineVariant: dark
            ? const Color(0xFF2D4133)
            : const Color(0xFFE2EAE0),
        tertiary: dark ? const Color(0xFFE4B979) : const Color(0xFFA36F32),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 24),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      indicatorColor: scheme.primaryContainer,
      height: 66,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
