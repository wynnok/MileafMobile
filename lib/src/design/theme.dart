import 'package:flutter/material.dart';

import 'semantic.dart';
import 'tokens.dart';
import 'typography.dart';

/// Builds the A「夜航」theme for one brightness.
///
/// Dark is the product default; light is an equal partner that keeps the dark
/// car hero. Pages never build colours or text styles themselves.
ThemeData mileafTheme(Brightness brightness) {
  final colors = brightness == Brightness.dark
      ? const MileafColors.dark()
      : const MileafColors.light();
  final type = MileafTextStyles.resolve(colors);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: colors.accent,
    onPrimary: colors.textOnAccent,
    primaryContainer: colors.accentSoft,
    onPrimaryContainer: colors.text,
    secondary: colors.reference,
    onSecondary: colors.canvas,
    secondaryContainer: colors.accentSoft,
    onSecondaryContainer: colors.text,
    tertiary: colors.reference,
    onTertiary: colors.canvas,
    error: colors.error,
    onError: colors.textOnAccent,
    surface: colors.canvas,
    onSurface: colors.text,
    surfaceContainerLowest: colors.canvas,
    surfaceContainerLow: colors.surface,
    surfaceContainer: colors.surface,
    surfaceContainerHigh: colors.surfaceRaised,
    surfaceContainerHighest: colors.surfaceRaised,
    onSurfaceVariant: colors.textMuted,
    outline: colors.lineStrong,
    outlineVariant: colors.line,
    shadow: Colors.black,
    scrim: colors.scrim,
    inverseSurface: colors.text,
    onInverseSurface: colors.canvas,
  ).copyWith(surfaceTint: Colors.transparent);

  final inputBorder = OutlineInputBorder(
    borderRadius: MileafRadius.mdAll,
    borderSide: BorderSide(color: colors.lineStrong),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: colors.canvas,
    canvasColor: colors.canvas,
    cardColor: colors.surface,
    dividerColor: colors.line,
    shadowColor: Colors.black,
    fontFamily: MileafType.family,
    fontFamilyFallback: MileafType.fallback,
    textTheme: type.materialTheme(colors),
    extensions: [colors, type],
    iconTheme: IconThemeData(color: colors.textMuted, size: MileafIconMetrics.header),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.canvas,
      foregroundColor: colors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: type.title,
      iconTheme: IconThemeData(color: colors.textMuted, size: 20),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: MileafRadius.noneAll,
        side: BorderSide(color: colors.line),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colors.line,
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MileafSpace.s16,
        vertical: MileafSpace.s12,
      ),
      labelStyle: type.label,
      floatingLabelStyle: type.label.copyWith(color: colors.accent),
      hintStyle: type.body.copyWith(color: colors.textFaint),
      errorStyle: type.body.copyWith(
        fontSize: MileafType.detailSize,
        color: colors.error,
      ),
      border: inputBorder,
      enabledBorder: inputBorder,
      disabledBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colors.line),
      ),
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colors.focusRing, width: 2),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colors.error),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colors.error, width: 2),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      modalBackgroundColor: colors.surface,
      modalBarrierColor: colors.scrim,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: MileafRadius.lgTop),
      clipBehavior: Clip.antiAlias,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: MileafRadius.mdAll),
      titleTextStyle: type.title,
      contentTextStyle: type.body,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.nav,
      indicatorColor: colors.accentSoft,
      elevation: 0,
      height: MileafSpace.navHeight,
      labelTextStyle: WidgetStatePropertyAll(type.micro),
      iconTheme: WidgetStatePropertyAll(
        IconThemeData(color: colors.textFaint, size: MileafIconMetrics.nav),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.surfaceRaised,
      contentTextStyle: type.body,
      actionTextColor: colors.accent,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: MileafRadius.mdAll,
        side: BorderSide(color: Colors.transparent),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: MileafRadius.mdAll,
        border: Border.all(color: colors.line),
      ),
      textStyle: type.micro.copyWith(color: colors.text),
      waitDuration: const Duration(milliseconds: 500),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.accent,
      linearTrackColor: colors.line,
      circularTrackColor: colors.line,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.accent,
      selectionColor: colors.accentSoft,
      selectionHandleColor: colors.accent,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colors.textMuted,
      textColor: colors.text,
      titleTextStyle: type.body.copyWith(fontWeight: MileafType.weightSemiBold),
      subtitleTextStyle: type.micro.copyWith(color: colors.textMuted),
      minVerticalPadding: MileafSpace.s12,
      contentPadding: EdgeInsets.zero,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.textOnAccent
            : colors.textMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? colors.accent : colors.line,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? colors.accent
            : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(colors.textOnAccent),
      side: BorderSide(color: colors.lineStrong),
      shape: const RoundedRectangleBorder(borderRadius: MileafRadius.xsAll),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? colors.accent : colors.textFaint,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.accent,
        textStyle: type.label.copyWith(
          fontSize: MileafType.bodySize,
          letterSpacing: 0,
        ),
        minimumSize: const Size(MileafSpace.touch, MileafSpace.touch),
        padding: const EdgeInsets.symmetric(horizontal: MileafSpace.s12),
        shape: const RoundedRectangleBorder(borderRadius: MileafRadius.smAll),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: colors.textMuted,
        minimumSize: const Size(MileafSpace.touch, MileafSpace.touch),
        shape: const RoundedRectangleBorder(borderRadius: MileafRadius.fullAll),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.accent,
        foregroundColor: colors.textOnAccent,
        disabledBackgroundColor: colors.line,
        disabledForegroundColor: colors.textFaint,
        textStyle: type.body.copyWith(
          fontWeight: MileafType.weightSemiBold,
          letterSpacing: 0,
        ),
        minimumSize: const Size(0, MileafSpace.touch),
        padding: const EdgeInsets.symmetric(horizontal: MileafSpace.s20),
        shape: const RoundedRectangleBorder(borderRadius: MileafRadius.smAll),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.text,
        side: BorderSide(color: colors.lineStrong),
        textStyle: type.body.copyWith(
          fontWeight: MileafType.weightSemiBold,
          letterSpacing: 0,
        ),
        minimumSize: const Size(0, MileafSpace.touch),
        padding: const EdgeInsets.symmetric(horizontal: MileafSpace.s20),
        shape: const RoundedRectangleBorder(borderRadius: MileafRadius.smAll),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: colors.accentSoft,
      disabledColor: Colors.transparent,
      side: BorderSide(color: colors.line),
      shape: const StadiumBorder(),
      labelStyle: type.label,
      secondaryLabelStyle: type.label.copyWith(color: colors.accent),
      padding: const EdgeInsets.symmetric(horizontal: MileafSpace.s12),
      showCheckmark: false,
    ),
    expansionTileTheme: ExpansionTileThemeData(
      iconColor: colors.textMuted,
      collapsedIconColor: colors.textFaint,
      textColor: colors.text,
      collapsedTextColor: colors.text,
      shape: const Border(),
      collapsedShape: const Border(),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: MileafSpace.s8),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: colors.accent,
      inactiveTrackColor: colors.line,
      thumbColor: colors.accent,
    ),
  );
}
