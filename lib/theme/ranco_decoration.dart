import 'package:flutter/material.dart';

import 'ranco_colors.dart';

abstract final class RancoDecoration {
  static const softBorder = RancoColors.border;
  static const strongBorder = Color(0xFFBFD8CD);

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: RancoColors.ink.withValues(alpha: .07),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get liftShadow => [
        BoxShadow(
          color: RancoColors.ink.withValues(alpha: .10),
          blurRadius: 28,
          offset: const Offset(0, 14),
        ),
      ];

  static const LinearGradient pageGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      RancoColors.surface,
      Color(0xFFF0F8F4),
      RancoColors.primarySoft,
    ],
    stops: [0, .58, 1],
  );

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      RancoColors.forest,
      RancoColors.primaryDark,
    ],
  );

  static const LinearGradient softGreenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white,
      RancoColors.primarySoft,
    ],
  );

  static BoxDecoration card({
    Color color = Colors.white,
    double radius = 22,
    bool elevated = true,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: softBorder),
      boxShadow: elevated ? softShadow : null,
    );
  }
}
