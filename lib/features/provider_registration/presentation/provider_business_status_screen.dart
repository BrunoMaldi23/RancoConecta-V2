import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/business.dart';
import '../../../theme/ranco_colors.dart';
import '../../provider_dashboard/application/provider_dashboard_providers.dart';

class ProviderBusinessStatusScreen extends ConsumerWidget {
  const ProviderBusinessStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businesses = ref.watch(myProviderBusinessesProvider);

    return Scaffold(
      backgroundColor: RancoColors.canvas,
      appBar: AppBar(
        backgroundColor: RancoColors.canvas,
        surfaceTintColor: Colors.transparent,
        title: const Text('Estado del negocio'),
      ),
      body: businesses.when(
        data: (items) {
          if (items.isEmpty) {
            return _StatusPanel(
              icon: Icons.add_business_outlined,
              title: 'Aún no tienes un negocio',
              message: 'Crea un borrador para enviarlo a revisión.',
              actionLabel: 'Crear negocio',
              onAction: () => context.go('/provider/register'),
            );
          }

          final business = items.firstWhere(
            (item) => item.publicationStatus != 'published',
            orElse: () => items.first,
          );
          final status = BusinessPublicationStatus.parseOrDefault(
            business.publicationStatus,
          );

          if (status == BusinessPublicationStatus.published) {
            return _StatusPanel(
              icon: Icons.check_circle_outline,
              title: 'Tu negocio está publicado',
              message: 'Puedes administrar su operación desde el dashboard.',
              actionLabel: 'Ir al dashboard',
              onAction: () => context.go('/provider/dashboard'),
            );
          }

          return _StatusPanel(
            icon: _iconFor(status),
            title: business.name,
            message: _messageFor(status),
            detail: business.changesRequestedNote,
            actionLabel: _actionLabelFor(status),
            onAction: _actionFor(context, status),
            statusLabel: status.label,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => const Center(
          child: Text('No pudimos cargar el estado del negocio.'),
        ),
      ),
    );
  }

  IconData _iconFor(BusinessPublicationStatus status) {
    return switch (status) {
      BusinessPublicationStatus.draft => Icons.edit_note_outlined,
      BusinessPublicationStatus.pendingReview => Icons.hourglass_top_outlined,
      BusinessPublicationStatus.changesRequested => Icons.rate_review_outlined,
      BusinessPublicationStatus.rejected => Icons.block_outlined,
      BusinessPublicationStatus.suspended => Icons.gpp_bad_outlined,
      BusinessPublicationStatus.archived => Icons.archive_outlined,
      BusinessPublicationStatus.paused => Icons.pause_circle_outline,
      BusinessPublicationStatus.published => Icons.check_circle_outline,
    };
  }

  String _messageFor(BusinessPublicationStatus status) {
    return switch (status) {
      BusinessPublicationStatus.draft =>
        'Tu negocio está como borrador. Puedes continuar el onboarding y enviarlo a revisión.',
      BusinessPublicationStatus.pendingReview =>
        'Tu negocio está siendo revisado. Te avisaremos cuando sea aprobado o si requiere cambios.',
      BusinessPublicationStatus.changesRequested =>
        'Hay cambios solicitados. Revisa el onboarding y vuelve a enviar el negocio.',
      BusinessPublicationStatus.rejected =>
        'La solicitud fue rechazada. Más adelante se habilitará soporte desde esta pantalla.',
      BusinessPublicationStatus.suspended =>
        'El negocio está suspendido. La gestión sensible queda bloqueada hasta revisión administrativa.',
      BusinessPublicationStatus.archived =>
        'El negocio está archivado y no aparece públicamente.',
      BusinessPublicationStatus.paused =>
        'El negocio está pausado y no aparece públicamente.',
      BusinessPublicationStatus.published => 'Tu negocio está publicado.',
    };
  }

  String? _actionLabelFor(BusinessPublicationStatus status) {
    return switch (status) {
      BusinessPublicationStatus.draft ||
      BusinessPublicationStatus.changesRequested =>
        'Continuar onboarding',
      BusinessPublicationStatus.published => 'Ir al dashboard',
      _ => null,
    };
  }

  VoidCallback? _actionFor(
    BuildContext context,
    BusinessPublicationStatus status,
  ) {
    return switch (status) {
      BusinessPublicationStatus.draft ||
      BusinessPublicationStatus.changesRequested =>
        () => context.go('/provider/register'),
      BusinessPublicationStatus.published => () =>
          context.go('/provider/dashboard'),
      _ => null,
    };
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.statusLabel,
    this.detail,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? statusLabel;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: RancoColors.forest, size: 48),
              const SizedBox(height: 18),
              if (statusLabel != null)
                Chip(
                  label: Text(statusLabel!),
                  backgroundColor: const Color(0xFFDDEFE7),
                ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: RancoColors.forest,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF587069),
                    ),
              ),
              if (detail != null && detail!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(detail!),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: RancoColors.forest,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
