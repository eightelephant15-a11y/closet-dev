import 'package:flutter/material.dart';
import 'package:stylist/theme/atelier_schemes.dart';
import 'package:stylist/theme/tokens.dart';

/// "Warm Editorial & Atelier": warm paper surfaces, terracotta accent, serif headlines (Playfair Display)
/// over a humanist sans (Plus Jakarta Sans). Light and dark ("Velvet Atelier").
abstract final class AppTheme {
  static ThemeData get light => _build(AtelierSchemes.light);
  static ThemeData get dark => _build(AtelierSchemes.dark);

  static TextStyle _serif(
    double size,
    FontWeight weight,
    double height, {
    double spacingEm = 0,
    FontStyle style = FontStyle.normal,
  }) => TextStyle(
    fontFamily: TypeTokens.serif,
    fontSize: size,
    fontWeight: weight,
    height: height / size,
    letterSpacing: size * spacingEm,
    fontStyle: style,
  );

  static TextStyle _sans(
    double size,
    FontWeight weight,
    double height, {
    double spacingEm = 0,
  }) => TextStyle(
    fontFamily: TypeTokens.sans,
    fontSize: size,
    fontWeight: weight,
    height: height / size,
    letterSpacing: size * spacingEm,
  );

  /// The type scale from the design's DESIGN.md. Serif for headings and big numbers, sans for the rest.
  static TextTheme get textTheme => TextTheme(
    displayLarge: _serif(40, FontWeight.w600, 48, spacingEm: -0.02),
    displayMedium: _serif(36, FontWeight.w600, 44, spacingEm: -0.02),
    displaySmall: _serif(32, FontWeight.w600, 38, spacingEm: -0.02),
    headlineLarge: _serif(28, FontWeight.w600, 34, spacingEm: -0.015),
    headlineMedium: _serif(22, FontWeight.w500, 28, spacingEm: -0.01),
    headlineSmall: _serif(18, FontWeight.w500, 24),
    titleLarge: _serif(22, FontWeight.w500, 28, spacingEm: -0.01),
    titleMedium: _serif(18, FontWeight.w500, 24),
    titleSmall: _sans(14, FontWeight.w600, 18, spacingEm: 0.01),
    bodyLarge: _sans(16, FontWeight.w400, 24),
    bodyMedium: _sans(14, FontWeight.w400, 20),
    bodySmall: _sans(12, FontWeight.w400, 16),
    labelLarge: _sans(14, FontWeight.w600, 18, spacingEm: 0.01),
    labelMedium: _sans(12, FontWeight.w600, 16, spacingEm: 0.04),
    labelSmall: _sans(10, FontWeight.w700, 14, spacingEm: 0.08),
  );

  static ThemeData _build(ColorScheme scheme) {
    const minSize = Size(Spacing.minTouchTarget, Spacing.minTouchTarget);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(RadiusTokens.md),
    );
    final text = textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final hairline = BorderSide(color: scheme.outlineVariant);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      fontFamily: TypeTokens.sans,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.lg),
          side: hairline,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minSize,
          shape: shape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minSize,
          shape: shape,
          side: hairline,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: minSize,
          shape: shape,
          textStyle: text.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        extendedTextStyle: text.labelLarge,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
        highlightElevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.lg),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.md),
          borderSide: hairline,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.md),
          borderSide: hairline,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(minSize),
          side: WidgetStatePropertyAll(hairline),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? scheme.primary.withValues(alpha: 0.10)
                : scheme.surfaceContainerLowest,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurface,
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: scheme.surfaceContainerHigh,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStatePropertyAll(scheme.outline),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.md),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(RadiusTokens.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.headlineMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.xl),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelSmall?.copyWith(
            color: s.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
