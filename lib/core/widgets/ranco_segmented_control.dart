import 'package:flutter/material.dart';

import '../../theme/ranco_colors.dart';
import '../../theme/ranco_tokens.dart';

/// Opción de [RancoSegmentedControl].
class RancoSegment<T> {
  const RancoSegment({required this.value, required this.label, this.count});

  final T value;
  final String label;

  /// Contador opcional junto a la etiqueta (p. ej. "Activas 3").
  final int? count;
}

/// Control segmentado liviano: pista gris suave y opción activa en blanco.
/// Reemplaza a las tabs pesadas en filtros de lista (Solicitudes, Usuarios,
/// Categorías). Se desplaza en horizontal si no cabe.
class RancoSegmentedControl<T> extends StatelessWidget {
  const RancoSegmentedControl({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<RancoSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFEDF2EF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final segment in segments)
              _SegmentButton(
                label: segment.label,
                count: segment.count,
                selected: segment.value == selected,
                onTap: () => onChanged(segment.value),
              ),
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: RancoDurations.quick,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: RancoColors.ink.withValues(alpha: .08),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? RancoColors.primaryDark
                            : RancoColors.textSecondary,
                        fontSize: 13.5,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '$count',
                        style: TextStyle(
                          color: selected
                              ? RancoColors.primary
                              : RancoColors.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
