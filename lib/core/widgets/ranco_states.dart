import 'package:flutter/material.dart';

import '../../theme/ranco_colors.dart';
import 'ranco_skeleton.dart';

/// Estados compartidos (FASE 3.20). Junto a [RancoPageEmptyState],
/// [RancoEmptyState] y [RancoErrorState] cubren loading / empty / error /
/// success con la misma escala en toda la app.

/// Carga de página: filas esqueleto con la altura aproximada del contenido
/// real, alineadas arriba (sin spinner aislado ni salto de layout).
class RancoLoadingState extends StatelessWidget {
  const RancoLoadingState({
    this.rows = 4,
    this.rowHeight = 84,
    this.maxWidth = 760,
    this.padding = const EdgeInsets.fromLTRB(16, 20, 16, 16),
    super.key,
  });

  final int rows;
  final double rowHeight;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      liveRegion: true,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: ListView(
            padding: padding,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children: [
              for (var i = 0; i < rows; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RancoSkeleton(height: rowHeight),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Esqueleto con forma de tarjeta de negocio (imagen + textos), para
/// grillas como Guardados o Explorar. Su alto sigue al ancho (16:9 +
/// textos), igual que la tarjeta real.
class RancoCardSkeleton extends StatelessWidget {
  const RancoCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    const fill = Color(0xFFEDF2EF);
    Widget bar(double widthFactor, double h) => FractionallySizedBox(
          widthFactor: widthFactor,
          alignment: Alignment.centerLeft,
          child: Container(
            height: h,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3ECE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(color: fill),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(.8, 14),
                const SizedBox(height: 10),
                bar(.45, 10),
                const SizedBox(height: 14),
                bar(.6, 10),
                const SizedBox(height: 18),
                bar(1, 36),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Confirmación en página (p. ej. tras enviar una solicitud): ícono,
/// título, frase útil y acción opcional. Mismo tamaño que los empty states.
class RancoSuccessState extends StatelessWidget {
  const RancoSuccessState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2F2E9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.check_rounded,
                    size: 26, color: Color(0xFF1F6B47)),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: RancoColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
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
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Éxito breve tras una acción (guardar, enviar): snackbar con check.
void showRancoSuccess(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]),
    ),
  );
}

/// Bloque esqueleto simple (FASE 3.21) para componer cargas con la forma
/// real de la vista (tarjeta de perfil, KPI, filas de tabla).
class RancoSkeletonBox extends StatelessWidget {
  const RancoSkeletonBox({
    this.width,
    this.height = 14,
    this.radius = 8,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0EC),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Superficie esqueleto con borde suave: contenedor blanco con los bloques
/// [children] dentro, igual que la tarjeta real que reemplaza.
class RancoSkeletonCard extends StatelessWidget {
  const RancoSkeletonCard({
    required this.children,
    this.padding = const EdgeInsets.all(18),
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3ECE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
