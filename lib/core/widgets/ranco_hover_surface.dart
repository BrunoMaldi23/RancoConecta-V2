import 'package:flutter/material.dart';

import '../../theme/ranco_colors.dart';
import '../../theme/ranco_tokens.dart';

/// Superficie interactiva con respuesta discreta al mouse (borde más
/// marcado + sombra leve) y foco de teclado visible. Para tarjetas y filas
/// clicables en escritorio; en táctil se comporta como un InkWell normal.
class RancoHoverSurface extends StatefulWidget {
  const RancoHoverSurface({
    required this.onTap,
    required this.child,
    this.color = Colors.white,
    this.borderColor = const Color(0xFFD8E4DC),
    this.hoverBorderColor = const Color(0xFFBFD8CD),
    this.radius = 16,
    this.semanticLabel,
    super.key,
  });

  final VoidCallback? onTap;
  final Widget child;
  final Color color;
  final Color borderColor;
  final Color hoverBorderColor;
  final double radius;
  final String? semanticLabel;

  @override
  State<RancoHoverSurface> createState() => _RancoHoverSurfaceState();
}

class _RancoHoverSurfaceState extends State<RancoHoverSurface> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.radius);
    final border = _focused
        ? const BorderSide(color: RancoColors.primaryDark, width: 2)
        : BorderSide(
            color: _hovered ? widget.hoverBorderColor : widget.borderColor,
          );
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: AnimatedContainer(
        duration: RancoDurations.quick,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            if (_hovered)
              BoxShadow(
                color: RancoColors.ink.withValues(alpha: .07),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
          ],
        ),
        child: Material(
          color: widget.color,
          shape: RoundedRectangleBorder(borderRadius: radius, side: border),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onHover: (value) => setState(() => _hovered = value),
            onFocusChange: (value) => setState(() => _focused = value),
            hoverColor: Colors.transparent,
            focusColor: Colors.transparent,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
