import 'package:flutter/material.dart';
import 'package:stylist/theme/tokens.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(
    const ColorScheme.light(
      primary: ColorTokens.lightPrimary,
      onSurface: ColorTokens.lightOnSurface,
      onSurfaceVariant: ColorTokens.lightMuted,
      error: ColorTokens.lightError,
      outline: ColorTokens.lightOutline,
    ),
    ColorTokens.lightBackground,
  );

  static ThemeData get dark => _build(
    const ColorScheme.dark(
      primary: ColorTokens.darkPrimary,
      onPrimary: ColorTokens.darkOnPrimary,
      surface: ColorTokens.darkSurface,
      onSurface: ColorTokens.darkOnSurface,
      onSurfaceVariant: ColorTokens.darkMuted,
      error: ColorTokens.darkError,
      outline: ColorTokens.darkOutline,
    ),
    ColorTokens.darkBackground,
  );

  static ThemeData _build(ColorScheme scheme, Color background) {
    const minSize = Size(Spacing.minTouchTarget, Spacing.minTouchTarget);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(RadiusTokens.md),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: TypeTokens.displaySize,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          fontSize: TypeTokens.titleSize,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(fontSize: TypeTokens.bodySize),
        labelLarge: TextStyle(
          fontSize: TypeTokens.labelSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: minSize, shape: shape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: minSize, shape: shape),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: minSize, shape: shape),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.md),
        ),
      ),
    );
  }
}
