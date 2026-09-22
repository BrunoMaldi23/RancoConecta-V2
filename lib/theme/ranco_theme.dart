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
      tertiary: RancoColors.info,
      surface: RancoColors.canvas,
    );
    return _theme(colorScheme);
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: RancoColors.forest,
      brightness: Brightness.dark,
      primary: const Color(0xFF8CCBAB),
      secondary: const Color(0xFF8BC6E0),
      tertiary: const Color(0xFF8FCFC6),
      surface: RancoColors.night,
    );
    return _theme(colorScheme);
  }

  static ThemeData _theme(ColorScheme colorScheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      fontFamilyFallback: const [
        'Inter',
        'Roboto',
        'Segoe UI',
      ],
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          color: RancoColors.textPrimary,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: RancoColors.textPrimary,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          letterSpacing: 0,
          height: 1.35,
        ),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          letterSpacing: 0,
          height: 1.35,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RancoRadius.md),
          side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: .8)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: .7),
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 42),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          backgroundColor: RancoColors.primaryDark,
          foregroundColor: Colors.white,
          disabledBackgroundColor: RancoColors.border,
          disabledForegroundColor: RancoColors.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RancoRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 42),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          foregroundColor: RancoColors.primaryDark,
          side: const BorderSide(color: RancoColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RancoRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        fillColor: Colors.white,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RancoRadius.md),
          borderSide: const BorderSide(color: RancoColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RancoRadius.md),
          borderSide: const BorderSide(color: RancoColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RancoRadius.md),
          borderSide:
              const BorderSide(color: RancoColors.primaryDark, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RancoRadius.md),
          borderSide: const BorderSide(color: RancoColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RancoRadius.md),
          borderSide: const BorderSide(color: RancoColors.error, width: 1.4),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RancoRadius.sm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        labelStyle: base.textTheme.labelMedium,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        elevation: 0,
        backgroundColor: Colors.white,
        indicatorColor: RancoColors.primarySoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color:
                selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 22,
            color:
                selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
          );
        }),
      ),
    );
  }
}
