import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

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
      // Foco de teclado visible (web): halo verde suave en InkWell/ListTile.
      focusColor: RancoColors.primary.withValues(alpha: .16),
      hoverColor: RancoColors.primary.withValues(alpha: .05),
      fontFamilyFallback: const [
        'Inter',
        'Roboto',
        'Segoe UI',
      ],
    );
    final text = base.textTheme;

    return base.copyWith(
      // Roles tipográficos (FASE 3.20). Evitar tamaños locales arbitrarios:
      // displaySmall = hero · headlineSmall = título de página ·
      // titleLarge = sección · titleMedium = tarjeta · bodyMedium = cuerpo ·
      // bodySmall = caption · labelLarge/Medium = etiquetas y botones.
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.copyWith(
          fontSize: 34,
          height: 1.12,
          fontWeight: FontWeight.w800,
          letterSpacing: -.5,
          color: RancoColors.textPrimary,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -.3,
          color: RancoColors.textPrimary,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -.2,
          height: 1.2,
          color: RancoColors.textPrimary,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontSize: 20,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        titleSmall: text.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        bodyLarge: text.bodyLarge?.copyWith(
          letterSpacing: 0,
          height: 1.5,
        ),
        bodyMedium: text.bodyMedium?.copyWith(
          letterSpacing: 0,
          height: 1.4,
        ),
        bodySmall: text.bodySmall?.copyWith(
          fontSize: 12.5,
          letterSpacing: 0,
          height: 1.35,
        ),
        labelLarge: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        labelMedium: text.labelMedium?.copyWith(
          letterSpacing: 0,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          // Transición discreta de contenido (fade + desplazamiento mínimo);
          // iOS conserva el gesto nativo de volver.
          TargetPlatform.android: _RancoFadeThroughBuilder(),
          TargetPlatform.windows: _RancoFadeThroughBuilder(),
          TargetPlatform.linux: _RancoFadeThroughBuilder(),
          TargetPlatform.macOS: _RancoFadeThroughBuilder(),
          TargetPlatform.fuchsia: _RancoFadeThroughBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
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
      // Jerarquía de botones: primario = verde lleno; secundario = outline
      // neutro con texto verde; terciario = texto. Todos con anillo de foco.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          backgroundColor: RancoColors.primaryDark,
          foregroundColor: Colors.white,
          disabledBackgroundColor: RancoColors.border,
          disabledForegroundColor: RancoColors.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RancoRadius.md),
          ),
        ).copyWith(side: _focusRing()),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          foregroundColor: RancoColors.primaryDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RancoRadius.md),
          ),
        ).copyWith(
          side: _focusRing(
            fallback: const BorderSide(color: Color(0xFFBFD8CD)),
            hovered: const BorderSide(color: RancoColors.primary),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: RancoColors.primaryDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RancoRadius.sm),
          ),
        ).copyWith(side: _focusRing()),
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
              const BorderSide(color: RancoColors.primaryDark, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RancoRadius.md),
          borderSide: const BorderSide(color: RancoColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RancoRadius.md),
          borderSide: const BorderSide(color: RancoColors.error, width: 1.6),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: const BorderSide(color: Color(0xFF8FA89C), width: 1.5),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RancoRadius.sm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        labelStyle: base.textTheme.labelMedium,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: RancoColors.primaryDark,
        unselectedLabelColor: RancoColors.textSecondary,
        indicatorColor: RancoColors.primaryDark,
        dividerColor: RancoColors.border,
        labelStyle: TextStyle(fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RancoRadius.xl - 4),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RancoRadius.md),
          side: const BorderSide(color: RancoColors.border),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12.5),
        decoration: BoxDecoration(
          color: RancoColors.ink.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(RancoRadius.xs),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: RancoColors.primary,
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

  /// Anillo de foco de teclado (2 px) sobre el borde propio del botón.
  static WidgetStateProperty<BorderSide?> _focusRing({
    BorderSide? fallback,
    BorderSide? hovered,
  }) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return fallback?.copyWith(color: RancoColors.border);
      }
      if (states.contains(WidgetState.focused)) {
        return const BorderSide(color: RancoColors.ink, width: 2);
      }
      if (hovered != null && states.contains(WidgetState.hovered)) {
        return hovered;
      }
      return fallback;
    });
  }
}

/// Fade + desplazamiento vertical mínimo para el cambio de ruta.
class _RancoFadeThroughBuilder extends PageTransitionsBuilder {
  const _RancoFadeThroughBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // La ruta dura 300 ms; el contenido completa su entrada en ~210 ms.
    final curved = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, .7, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .012),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
