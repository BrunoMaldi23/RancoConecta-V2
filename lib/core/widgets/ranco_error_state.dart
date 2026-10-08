import 'package:flutter/material.dart';

import '../../theme/ranco_colors.dart';

/// Error de carga compartido (FASE 3.21): ícono suave, título humano, texto
/// corto opcional y "Reintentar". Compacto y alineado arriba; nunca muestra
/// el error técnico.
class RancoErrorState extends StatelessWidget {
  const RancoErrorState({
    required this.message,
    this.detail,
    this.onRetry,
    this.compact = false,
    super.key,
  });

  /// Título visible (p. ej. "No pudimos cargar tus solicitudes.").
  final String message;

  /// Texto secundario breve. Si es nulo y hay [onRetry], se sugiere
  /// reintentar.
  final String? detail;
  final VoidCallback? onRetry;

  /// Versión en línea para secciones dentro de una página (sin margen
  /// superior amplio).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final secondary = detail ??
        (onRetry == null ? null : 'Inténtalo nuevamente en unos segundos.');
    return Semantics(
      liveRegion: true,
      child: Align(
        alignment: compact ? Alignment.centerLeft : Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: compact
                ? const EdgeInsets.symmetric(vertical: 12)
                : const EdgeInsets.fromLTRB(24, 56, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: compact
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBEDEA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.cloud_off_outlined,
                    color: Color(0xFF9A3B33),
                    size: 22,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: compact ? TextAlign.start : TextAlign.center,
                  style: const TextStyle(
                    color: RancoColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                if (secondary != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    secondary,
                    textAlign: compact ? TextAlign.start : TextAlign.center,
                    style: const TextStyle(
                      color: RancoColors.textSecondary,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                ],
                if (onRetry != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Reintentar'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
