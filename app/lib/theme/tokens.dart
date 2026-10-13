import 'package:flutter/material.dart';

/// Design tokens. Swap brand colours/fonts here only.
abstract final class ColorTokens {
  // Light
  static const lightPrimary = Color(0xFF3D3A8C);
  static const lightOnPrimary = Color(0xFFFFFFFF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBackground = Color(0xFFF7F7FA);
  static const lightOnSurface = Color(0xFF1B1B22);
  static const lightMuted = Color(0xFF5B5B6B);
  static const lightError = Color(0xFFB3261E);
  static const lightOutline = Color(0xFF767686);
  // Dark
  static const darkPrimary = Color(0xFFB9B6FF);
  static const darkOnPrimary = Color(0xFF1C1A5C);
  static const darkSurface = Color(0xFF1B1B22);
  static const darkBackground = Color(0xFF121218);
  static const darkOnSurface = Color(0xFFEDEDF4);
  static const darkMuted = Color(0xFFB4B4C4);
  static const darkError = Color(0xFFFFB4AB);
  static const darkOutline = Color(0xFF9A9AAC);
}

abstract final class TypeTokens {
  /// Set to a bundled font family to rebrand; null uses the platform font.
  static const String? fontFamily = null;
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

  /// Minimum interactive target (WCAG / Material: 48dp).
  static const double minTouchTarget = 48;
}

abstract final class RadiusTokens {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double pill = 999;
}

abstract final class MotionTokens {
  static const fast = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 500);
  static const Curve curve = Curves.easeOutCubic;
}
