import 'package:flutter/material.dart';

import '../../theme/ranco_decoration.dart';

class RancoCard extends StatelessWidget {
  const RancoCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.radius = 20,
    this.elevated = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: padding,
      decoration: RancoDecoration.card(
        radius: radius,
        elevated: elevated,
      ),
      child: child,
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: card,
      ),
    );
  }
}
