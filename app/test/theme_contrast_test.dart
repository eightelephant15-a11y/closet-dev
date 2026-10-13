import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylist/theme/app_theme.dart';
import 'package:stylist/theme/tokens.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final l1 = _lum(a);
  final l2 = _lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  // WCAG 2.1 AA: 4.5:1 for text, 3:1 for UI component boundaries.
  const textPairs = {
    'light onSurface/surface': (
      ColorTokens.lightOnSurface,
      ColorTokens.lightSurface,
    ),
    'light onSurface/background': (
      ColorTokens.lightOnSurface,
      ColorTokens.lightBackground,
    ),
    'light muted/surface': (ColorTokens.lightMuted, ColorTokens.lightSurface),
    'light muted/background': (
      ColorTokens.lightMuted,
      ColorTokens.lightBackground,
    ),
    'light onPrimary/primary': (
      ColorTokens.lightOnPrimary,
      ColorTokens.lightPrimary,
    ),
    'light primary/background': (
      ColorTokens.lightPrimary,
      ColorTokens.lightBackground,
    ),
    'light error/background': (
      ColorTokens.lightError,
      ColorTokens.lightBackground,
    ),
    'dark onSurface/surface': (
      ColorTokens.darkOnSurface,
      ColorTokens.darkSurface,
    ),
    'dark onSurface/background': (
      ColorTokens.darkOnSurface,
      ColorTokens.darkBackground,
    ),
    'dark muted/surface': (ColorTokens.darkMuted, ColorTokens.darkSurface),
    'dark muted/background': (
      ColorTokens.darkMuted,
      ColorTokens.darkBackground,
    ),
    'dark onPrimary/primary': (
      ColorTokens.darkOnPrimary,
      ColorTokens.darkPrimary,
    ),
    'dark primary/background': (
      ColorTokens.darkPrimary,
      ColorTokens.darkBackground,
    ),
    'dark error/background': (
      ColorTokens.darkError,
      ColorTokens.darkBackground,
    ),
  };

  for (final e in textPairs.entries) {
    test('text contrast >= 4.5:1: ${e.key}', () {
      expect(contrast(e.value.$1, e.value.$2), greaterThanOrEqualTo(4.5));
    });
  }

  test('component outlines >= 3:1 against their surface', () {
    expect(
      contrast(ColorTokens.lightOutline, ColorTokens.lightSurface),
      greaterThanOrEqualTo(3),
    );
    expect(
      contrast(ColorTokens.darkOutline, ColorTokens.darkSurface),
      greaterThanOrEqualTo(3),
    );
  });

  test('buttons and tap targets are at least 48dp', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      expect(
        theme.filledButtonTheme.style!.minimumSize!.resolve({})!.height,
        greaterThanOrEqualTo(48),
      );
      expect(
        theme.outlinedButtonTheme.style!.minimumSize!.resolve({})!.height,
        greaterThanOrEqualTo(48),
      );
      expect(
        theme.textButtonTheme.style!.minimumSize!.resolve({})!.height,
        greaterThanOrEqualTo(48),
      );
      expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
    }
    expect(Spacing.minTouchTarget, 48);
  });
}
