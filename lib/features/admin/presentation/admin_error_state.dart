import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../theme/ranco_colors.dart';

class AdminErrorState extends StatelessWidget {
  const AdminErrorState({
    required this.onRetry,
    this.error,
    this.compact = false,
    this.title,
    super.key,
  });

  final VoidCallback onRetry;
  final Object? error;
  final bool compact;

  /// Título específico (p. ej. "No pudimos cargar las revisiones.").
  final String? title;

  @override
  Widget build(BuildContext context) {
    final failure = error is AppFailure ? error! as AppFailure : null;
    final permissionError = failure?.type == AppFailureType.permission;
    // El detalle técnico (RPC, HTTP, Postgrest) solo va a logs de debug.
    if (error != null) {
      final cause = failure?.cause;
      debugPrint('AdminErrorState: ${failure?.message ?? error}'
          '${cause is PostgrestException ? ' [${cause.code}] ${cause.message}' : ''}');
    }
    final heading = permissionError
        ? 'Acceso administrativo denegado.'
        : title ?? 'No pudimos cargar la información.';
    final subtitle = permissionError
        ? 'Esta cuenta no tiene permiso para ver estos datos.'
        : 'Intenta nuevamente en unos momentos.';
    final retry = permissionError
        ? null
        : OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reintentar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: RancoColors.forest,
              side: const BorderSide(color: Color(0xFFCFE0D7)),
              visualDensity: VisualDensity.compact,
            ),
          );

    if (compact) {
      // Variante en línea para paneles: ícono discreto, sin tarjeta propia.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.cloud_off_outlined,
              color: RancoColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(heading,
                    style: const TextStyle(
                        color: RancoColors.textPrimary,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: RancoColors.textSecondary, fontSize: 13)),
                if (retry != null) ...[
                  const SizedBox(height: 8),
                  retry,
                ],
              ],
            ),
          ),
        ]),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCE8E0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined,
                  color: RancoColors.textSecondary, size: 28),
              const SizedBox(height: 10),
              Text(heading,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: RancoColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      )),
              const SizedBox(height: 4),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: RancoColors.textSecondary)),
              if (retry != null) ...[
                const SizedBox(height: 14),
                retry,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: const BoxDecoration(
              color: Color(0xFFE9F3EE),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: RancoColors.forest, size: 28),
          ),
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: RancoColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  )),
          const SizedBox(height: 4),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: RancoColors.textSecondary)),
        ]),
      );
}
