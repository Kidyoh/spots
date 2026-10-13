import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

ThemeData buildTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Palette.green,
    onPrimary: Palette.card,
    primaryContainer: Palette.lineSoft,
    onPrimaryContainer: Palette.greenDeep,
    secondary: Palette.terracotta,
    onSecondary: Palette.card,
    tertiary: Palette.amber,
    onTertiary: Palette.ink,
    error: Palette.accentText,
    onError: Palette.card,
    surface: Palette.bg,
    onSurface: Palette.ink,
    onSurfaceVariant: Palette.inkSoft,
    surfaceContainerLowest: Palette.card,
    surfaceContainerLow: Palette.card,
    surfaceContainer: Palette.card,
    surfaceContainerHigh: Palette.card,
    surfaceContainerHighest: Palette.lineSoft,
    outline: Palette.line,
    outlineVariant: Palette.lineSoft,
    shadow: Palette.shadow,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Quicksand',
    scaffoldBackgroundColor: Palette.bg,
    splashFactory: InkSparkle.splashFactory,
  );

  final text = base.textTheme.apply(bodyColor: Palette.ink, displayColor: Palette.ink, fontFamily: 'Quicksand');

  return base.copyWith(
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5),
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3),
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.5, color: Palette.inkSoft),
      bodyLarge: text.bodyLarge?.copyWith(height: 1.55),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.bg,
      foregroundColor: Palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.bg,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Palette.line,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.greenDeep,
      contentTextStyle: const TextStyle(fontFamily: 'Quicksand', color: Palette.bg, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.card,
      hintStyle: const TextStyle(color: Palette.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: const BorderSide(color: Palette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: const BorderSide(color: Palette.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: const BorderSide(color: Palette.green, width: 1.6),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: Palette.green,
      inactiveTrackColor: Palette.lineSoft,
      thumbColor: Palette.green,
      overlayColor: Palette.press,
      trackHeight: 5,
    ),
    dividerTheme: const DividerThemeData(color: Palette.lineSoft, thickness: 1),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
