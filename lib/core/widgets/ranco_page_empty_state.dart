import 'package:flutter/material.dart';

import '../../theme/ranco_colors.dart';

/// Estado vacío de página (Solicitudes, Guardados, Notificaciones): ícono,
/// título, microcopy y CTA opcional, con la misma escala en todas.
class RancoPageEmptyState extends StatelessWidget {
  const RancoPageEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon = Icons.search_rounded,
    this.onAction,
    this.secondaryLabel,
    this.onSecondaryAction,
    this.topSpacing = 40,
    super.key,
  });

  /// Distancia desde el encabezado de la página (no se centra en la ventana).
  final double topSpacing;

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, topSpacing, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF3E8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 25, color: RancoColors.forest),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RancoColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RancoColors.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon, size: 18),
                  label: Text(actionLabel!),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(190, 46),
                    backgroundColor: RancoColors.forest,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ],
              if (secondaryLabel != null && onSecondaryAction != null) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: onSecondaryAction,
                  child: Text(secondaryLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
