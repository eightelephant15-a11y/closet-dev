import 'package:flutter/material.dart';

/// Design tokens. Swap brand colours/fonts here only.
abstract final class ColorTokens {
  // Light (values mirror AtelierSchemes.light; kept as constants for the contrast tests)
  static const lightPrimary = Color(0xFF893623);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFFFF8F5);
  static const lightBackground = Color(0xFFFFF8F5);
  static const lightOnSurface = Color(0xFF1F1B19);
  static const lightMuted = Color(0xFF55423E);
  static const lightError = Color(0xFFBA1A1A);
  static const lightOutline = Color(0xFF88726D);
  // Dark ("Velvet Atelier")
  static const darkPrimary = Color(0xFFFFB4A3);
  static const darkOnPrimary = Color(0xFF5E1607);
  static const darkSurface = Color(0xFF151312);
  static const darkBackground = Color(0xFF151312);
  static const darkOnSurface = Color(0xFFE7E1DF);
  static const darkMuted = Color(0xFFDCC1BB);
  static const darkError = Color(0xFFFFB4AB);
  static const darkOutline = Color(0xFFA38B86);
}

abstract final class TypeTokens {
  /// Headlines and big numbers (bundled, assets/fonts, SIL Open Font License).
  static const String serif = 'Playfair Display';

  /// Body text, labels, anything tappable (bundled, assets/fonts, SIL Open Font License).
  static const String sans = 'Plus Jakarta Sans';
  static const double displaySize = 32;
  static const double titleSize = 22;
  static const double bodySize = 16;
  static const double labelSize = 14;
}

abstract final class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Gap between grid tiles and page side margin in the Atelier design.
  static const double gutter = 12;
  static const double margin = 20;

  /// Minimum interactive target (WCAG / Material: 48dp).
  static const double minTouchTarget = 48;
}

abstract final class RadiusTokens {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 999;
}

abstract final class MotionTokens {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 500);
  static const Curve curve = Curves.easeOutCubic;
}
