import 'package:flutter/material.dart';

import 'ranco_colors.dart';
import 'ranco_tokens.dart';

abstract final class RancoTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: RancoColors.forest,
      brightness: Brightness.light,
      primary: RancoColors.forest,
      secondary: RancoColors.lake,
      tertiary: RancoColors.clay,
      surface: const Color(0xFFFBFEFC),
    );
    return _theme(colorScheme);
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: RancoColors.forest,
      brightness: Brightness.dark,
      primary: const Color(0xFF8CCBAB),
      secondary: const Color(0xFF8BC6E0),
      tertiary: const Color(0xFFE3A07B),
      surface: RancoColors.night,
    );
    return _theme(colorScheme);
  }

  static ThemeData _theme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RancoRadius.md),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RancoRadius.sm),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RancoRadius.sm),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
