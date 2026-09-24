import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/business.dart';
import '../../../theme/ranco_colors.dart';
import '../../provider_dashboard/application/provider_dashboard_providers.dart';
import '../../provider_dashboard/data/provider_business_repository.dart';

class ProviderBusinessStatusScreen extends ConsumerWidget {
  const ProviderBusinessStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businesses = ref.watch(myProviderBusinessesProvider);
    final activeBusinessId = ref.watch(activeProviderBusinessIdProvider);

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

          final business = selectProviderStatusBusiness(
            items,
            activeBusinessId,
          );
          final status = BusinessPublicationStatus.parseOrDefault(
            business.publicationStatus,
          );

          return _StatusPanel(
            businesses: items,
            selectedBusiness: business,
            onBusinessChanged: (businessId) {
              ref.read(activeProviderBusinessIdProvider.notifier).state =
                  businessId;
            },
            icon: _iconFor(status),
            title: _titleFor(
              business,
              status,
            ),
            message: _messageFor(
              business,
              status,
            ),
            detail: _detailFor(
              business,
              status,
            ),
            actionLabel: _actionLabelFor(status),
            onAction: _actionFor(
              context,
              ref,
              business,
              status,
            ),
            secondaryActionLabel: _secondaryActionLabelFor(status),
            onSecondaryAction: _secondaryActionFor(
              context,
              ref,
              business,
              status,
            ),
            statusLabel: status.label,
            submittedAt: business.submittedAt,
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

  String _titleFor(
    ProviderBusinessSummary business,
    BusinessPublicationStatus status,
  ) {
    return switch (status) {
      BusinessPublicationStatus.published => 'Tu negocio está publicado',
      BusinessPublicationStatus.pendingReview => 'Estamos revisando tu negocio',
      BusinessPublicationStatus.changesRequested => 'Hay cambios solicitados',
      BusinessPublicationStatus.rejected => 'Solicitud rechazada',
      BusinessPublicationStatus.suspended => 'Negocio suspendido',
      _ => business.name,
    };
  }

  String _messageFor(
    ProviderBusinessSummary business,
    BusinessPublicationStatus status,
  ) {
    return switch (status) {
      BusinessPublicationStatus.draft =>
        'Tu negocio está como borrador. Puedes continuar la publicación y enviarla a revisión.',
      BusinessPublicationStatus.pendingReview =>
        'Recibimos la publicación de ${business.name}. Te avisaremos cuando sea aprobada o si requiere cambios.',
      BusinessPublicationStatus.changesRequested =>
        'Revisa la observación del equipo y corrige la publicación. Tus datos anteriores se conservan.',
      BusinessPublicationStatus.rejected =>
        'La publicación no puede avanzar con la información enviada. Revisa el motivo indicado por administración.',
      BusinessPublicationStatus.suspended =>
        'El negocio no está visible públicamente mientras se resuelve la suspensión.',
      BusinessPublicationStatus.archived =>
        'El negocio está archivado y no aparece públicamente.',
      BusinessPublicationStatus.paused =>
        'El negocio está pausado y no aparece públicamente.',
      BusinessPublicationStatus.published => 'Tu negocio está publicado.',
    };
  }

  String? _detailFor(
    ProviderBusinessSummary business,
    BusinessPublicationStatus status,
  ) {
    final note = business.changesRequestedNote?.trim();

    if (note == null || note.isEmpty) {
      return null;
    }

    return switch (status) {
      BusinessPublicationStatus.changesRequested ||
      BusinessPublicationStatus.rejected ||
      BusinessPublicationStatus.suspended =>
        note,
      _ => null,
    };
  }

  String? _actionLabelFor(BusinessPublicationStatus status) {
    return switch (status) {
      BusinessPublicationStatus.draft => 'Continuar publicación',
      BusinessPublicationStatus.changesRequested => 'Corregir publicación',
      BusinessPublicationStatus.published => 'Administrar negocio',
      _ => null,
    };
  }

  String? _secondaryActionLabelFor(BusinessPublicationStatus status) {
    return switch (status) {
      BusinessPublicationStatus.published => 'Ver publicación pública',
      BusinessPublicationStatus.pendingReview => 'Volver al inicio',
      BusinessPublicationStatus.suspended => 'Volver al inicio',
      _ => null,
    };
  }

  VoidCallback? _actionFor(
    BuildContext context,
    WidgetRef ref,
    ProviderBusinessSummary business,
    BusinessPublicationStatus status,
  ) {
    return switch (status) {
      BusinessPublicationStatus.draft ||
      BusinessPublicationStatus.changesRequested =>
        () {
          ref.read(activeProviderBusinessIdProvider.notifier).state =
              business.id;
          context.go('/provider/register');
        },
      BusinessPublicationStatus.published => () {
          ref.read(activeProviderBusinessIdProvider.notifier).state =
              business.id;
          context.go('/provider/dashboard');
        },
      _ => null,
    };
  }

  VoidCallback? _secondaryActionFor(
    BuildContext context,
    WidgetRef ref,
    ProviderBusinessSummary business,
    BusinessPublicationStatus status,
  ) {
    return switch (status) {
      BusinessPublicationStatus.published => () {
          ref.read(activeProviderBusinessIdProvider.notifier).state =
              business.id;
          context.go('/business/${business.id}');
        },
      BusinessPublicationStatus.pendingReview ||
      BusinessPublicationStatus.suspended =>
        () => context.go('/'),
      _ => null,
    };
  }
}

ProviderBusinessSummary selectProviderStatusBusiness(
  List<ProviderBusinessSummary> items,
  String? activeBusinessId,
) {
  if (items.isEmpty) {
    throw ArgumentError.value(items, 'items', 'must not be empty');
  }

  if (activeBusinessId != null) {
    for (final item in items) {
      if (item.id == activeBusinessId) {
        return item;
      }
    }
  }

  return items.firstWhere(
    (item) {
      final status = BusinessPublicationStatus.parseOrDefault(
        item.publicationStatus,
      );
      return status != BusinessPublicationStatus.published;
    },
    orElse: () => items.first,
  );
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.businesses = const [],
    this.selectedBusiness,
    this.onBusinessChanged,
    this.statusLabel,
    this.detail,
    this.submittedAt,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final List<ProviderBusinessSummary> businesses;
  final ProviderBusinessSummary? selectedBusiness;
  final ValueChanged<String>? onBusinessChanged;
  final String? statusLabel;
  final String? detail;
  final DateTime? submittedAt;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (businesses.length > 1 &&
                  selectedBusiness != null &&
                  onBusinessChanged != null) ...[
                _StatusBusinessSwitcher(
                  businesses: businesses,
                  selectedBusiness: selectedBusiness!,
                  onBusinessChanged: onBusinessChanged!,
                ),
                const SizedBox(height: 14),
              ],
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFD7E4DE),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE4F3EC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            color: RancoColors.forest,
                            size: 23,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedBusiness?.name ?? title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: RancoColors.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (selectedBusiness != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  selectedBusiness!.businessType.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: RancoColors.textSecondary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (statusLabel != null)
                      Chip(
                        label: Text(statusLabel!),
                        backgroundColor: const Color(0xFFDDEFE7),
                      ),
                    if (submittedAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Enviado el ${_formatDate(submittedAt!)}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF6D7E76),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      title,
                      textAlign: TextAlign.left,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: RancoColors.forest,
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.left,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF587069),
                          ),
                    ),
                    if (detail != null && detail!.trim().isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FBF8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFD7E4DE),
                          ),
                        ),
                        child: Text(
                          detail!,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: RancoColors.night,
                                    height: 1.35,
                                  ),
                        ),
                      ),
                    ],
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: onAction,
                        style: FilledButton.styleFrom(
                          backgroundColor: RancoColors.forest,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: Text(actionLabel!),
                      ),
                    ],
                    if (secondaryActionLabel != null &&
                        onSecondaryAction != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: onSecondaryAction,
                        child: Text(secondaryActionLabel!),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }
}

class _StatusBusinessSwitcher extends StatelessWidget {
  const _StatusBusinessSwitcher({
    required this.businesses,
    required this.selectedBusiness,
    required this.onBusinessChanged,
  });

  final List<ProviderBusinessSummary> businesses;
  final ProviderBusinessSummary selectedBusiness;
  final ValueChanged<String> onBusinessChanged;

  @override
  Widget build(BuildContext context) {
    final selectedStatus = BusinessPublicationStatus.parseOrDefault(
      selectedBusiness.publicationStatus,
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: () => _showSwitcher(context),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFD7E4DE)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.storefront_outlined,
                color: RancoColors.forest,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      selectedBusiness.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RancoColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${selectedBusiness.businessType.label} · ${selectedStatus.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RancoColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: RancoColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSwitcher(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Text(
                'Cambiar negocio',
                style: TextStyle(
                  color: RancoColors.forest,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              for (final business in businesses)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(
                    Icons.storefront_outlined,
                    color: RancoColors.forest,
                  ),
                  title: Text(
                    business.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${business.businessType.label} · ${BusinessPublicationStatus.parseOrDefault(business.publicationStatus).label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: business.id == selectedBusiness.id
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () {
                    onBusinessChanged(business.id);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
