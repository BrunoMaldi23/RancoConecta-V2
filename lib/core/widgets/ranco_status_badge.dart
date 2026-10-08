import 'package:flutter/material.dart';

/// Tonos semánticos compartidos. Verde = éxito/activo, ámbar = pendiente,
/// rojo suave = rechazo/error, gris = inactivo/cancelado, neutro = dato.
enum RancoStatusTone { neutral, success, warning, danger, info, muted }

/// Colores (texto, fondo) por tono, con contraste AA sobre su fondo.
(Color, Color) rancoStatusColors(RancoStatusTone tone) => switch (tone) {
      RancoStatusTone.success => (
          const Color(0xFF1F6B47),
          const Color(0xFFE2F2E9)
        ),
      RancoStatusTone.warning => (
          const Color(0xFF7A4F0E),
          const Color(0xFFFFF0D6)
        ),
      RancoStatusTone.danger => (
          const Color(0xFF8E3232),
          const Color(0xFFFBE7E5)
        ),
      RancoStatusTone.info => (
          const Color(0xFF235F66),
          const Color(0xFFE2F1F2)
        ),
      RancoStatusTone.muted => (
          const Color(0xFF5B6862),
          const Color(0xFFEDF0EE)
        ),
      RancoStatusTone.neutral => (
          const Color(0xFF30443B),
          const Color(0xFFEFF5F2)
        ),
    };

/// Badge de estado único (Borrador, En revisión, Publicado, Pendiente,
/// Aceptada, Activo...): misma altura, radio y padding en toda la app.
class RancoStatusBadge extends StatelessWidget {
  const RancoStatusBadge({
    required this.label,
    this.tone = RancoStatusTone.neutral,
    this.dot = false,
    super.key,
  });

  final String label;
  final RancoStatusTone tone;

  /// Punto de color antes del texto (útil para estados on/off).
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = rancoStatusColors(tone);
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tono semántico para las etiquetas de estado existentes en la app.
RancoStatusTone rancoToneForStatusLabel(String label) =>
    switch (label.trim().toLowerCase()) {
      'en revisión' ||
      'pendiente' ||
      'cambios solicitados' ||
      'en revisión (cambios)' =>
        RancoStatusTone.warning,
      'publicado' ||
      'activo' ||
      'activa' ||
      'aceptada' ||
      'confirmada' ||
      'preparada' =>
        RancoStatusTone.success,
      'rechazado' ||
      'rechazada' ||
      'suspendido' ||
      'bloqueado' ||
      'eliminado' =>
        RancoStatusTone.danger,
      'borrador' ||
      'pausado' ||
      'archivado' ||
      'inactivo' ||
      'inactiva' ||
      'cancelada' ||
      'sin estado' =>
        RancoStatusTone.muted,
      _ => RancoStatusTone.neutral,
    };
