import 'package:flutter/material.dart';

import 'ranco_colors.dart';

abstract final class RancoDecoration {
  static const softBorder = Color(0xFFD8E6DF);
  static const strongBorder = Color(0xFFC0D8CD);

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
      Color(0xFFF6FBF7),
      Color(0xFFEAF4F0),
      Color(0xFFFFF7EA),
    ],
    stops: [0, .58, 1],
  );

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      RancoColors.forest,
      RancoColors.lake,
    ],
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFF3E3),
      Color(0xFFE6F4ED),
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
