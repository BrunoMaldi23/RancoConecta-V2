import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/layout/ranco_responsive.dart';
import '../../../core/widgets/ranco_app_bar.dart';
import '../../../core/widgets/ranco_error_state.dart';
import '../../../core/widgets/ranco_page_empty_state.dart';
import '../../../core/widgets/ranco_states.dart';
import '../../../shared/models/business.dart';
import '../../../theme/ranco_colors.dart';
import '../../admin/application/admin_providers.dart';
import '../../admin/data/admin_settings_repository.dart';
import '../../provider_dashboard/application/provider_dashboard_providers.dart';
import '../../provider_dashboard/data/provider_business_repository.dart';
import '../../provider_dashboard/presentation/provider_hub.dart';
import '../application/business_onboarding_providers.dart';
import '../data/business_onboarding_repository.dart';

/// Resumen del hub "Mi negocio" mientras el negocio no está publicado
/// (borrador, en revisión, cambios solicitados, rechazado, suspendido).
/// Mismas acciones y destinos que antes; cambia la presentación.
class ProviderBusinessStatusScreen extends ConsumerWidget {
  const ProviderBusinessStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businesses = ref.watch(myProviderBusinessesProvider);
    final activeBusinessId = ref.watch(activeProviderBusinessIdProvider);

    return Scaffold(
      backgroundColor: RancoColors.canvas,
      appBar: const RancoAppBar(
        title: 'Mi negocio',
        fallbackRoute: '/account',
      ),
      body: businesses.when(
        data: (items) {
          if (items.isEmpty) {
            return SingleChildScrollView(
              child: RancoPageEmptyState(
                icon: Icons.add_business_outlined,
                title: 'Aún no tienes un negocio',
                message: 'Crea un borrador, complétalo a tu ritmo y envíalo '
                    'a revisión cuando esté listo.',
                actionLabel: 'Crear negocio',
                actionIcon: Icons.add_rounded,
                onAction: () => context.go('/provider/register'),
              ),
            );
          }

          final business = selectProviderStatusBusiness(
            items,
            activeBusinessId,
          );
          final status = BusinessPublicationStatus.parseOrDefault(
            business.publicationStatus,
          );
          final reviewWhatsApp =
              status == BusinessPublicationStatus.pendingReview
                  ? ref
                      .watch(reviewWhatsAppDetailsProvider(business.id))
                      .valueOrNull
                  : null;
          final editable = status == BusinessPublicationStatus.draft ||
              status == BusinessPublicationStatus.changesRequested;
          final draft = editable
              ? ref.watch(providerBusinessDraftProvider(business.id))
              : null;

          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 40),
            children: [
              RancoContentContainer(
                width: RancoContainerWidth.form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ProviderHubHeader(
                      business: business,
                      businesses: items,
                      onBusinessChanged: (businessId) {
                        ref
                            .read(activeProviderBusinessIdProvider.notifier)
                            .state = businessId;
                      },
                      onViewPublic:
                          status == BusinessPublicationStatus.published
                              ? () => context.go('/business/${business.id}')
                              : null,
                    ),
                    const SizedBox(height: 16),
                    _StatusPanel(
                      status: status,
                      business: business,
                      draft: draft,
                      reviewWhatsApp: reviewWhatsApp,
                      onContinue: editable
                          ? () {
                              ref
                                  .read(
                                      activeProviderBusinessIdProvider.notifier)
                                  .state = business.id;
                              context.go('/provider/register');
                            }
                          : null,
                      onManage: status == BusinessPublicationStatus.published
                          ? () {
                              ref
                                  .read(
                                      activeProviderBusinessIdProvider.notifier)
                                  .state = business.id;
                              context.go(providerHubHomeRoute);
                            }
                          : null,
                      onAccount: () => context.go('/account'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const RancoLoadingState(rows: 2, rowHeight: 120),
        error: (error, stackTrace) => RancoErrorState(
          message: 'No pudimos cargar el estado del negocio.',
          onRetry: () => ref.invalidate(myProviderBusinessesProvider),
        ),
      ),
    );
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

/// Paso de configuración del negocio y si ya está completo.
typedef OnboardingProgressStep = ({String label, bool done});

/// Progreso del borrador con los mismos pasos del asistente. "Revisión"
/// queda completo solo cuando el negocio ya fue enviado.
List<OnboardingProgressStep> onboardingProgressSteps(BusinessDraft draft) {
  final hasContact = [draft.phone, draft.whatsapp, draft.email]
      .any((value) => (value ?? '').trim().isNotEmpty);
  final info = draft.name.trim().length >= 3 &&
      (draft.description ?? '').trim().length >= 20 &&
      hasContact;
  final category = draft.primaryCategoryId != null &&
      (draft.businessType != BusinessType.service || draft.services.isNotEmpty);
  return [
    (label: 'Tipo de negocio', done: true),
    (label: 'Información', done: info),
    (label: 'Categoría', done: category),
    (label: 'Cobertura', done: draft.coverage.isNotEmpty),
    (
      label: 'Revisión',
      done: draft.submittedAt != null && !draft.canContinueOnboarding
    ),
  ];
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.status,
    required this.business,
    required this.draft,
    required this.reviewWhatsApp,
    required this.onContinue,
    required this.onManage,
    required this.onAccount,
  });

  final BusinessPublicationStatus status;
  final ProviderBusinessSummary business;
  final AsyncValue<BusinessDraft>? draft;
  final ReviewWhatsAppDetails? reviewWhatsApp;
  final VoidCallback? onContinue;
  final VoidCallback? onManage;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final note = business.changesRequestedNote?.trim();
    final showNote = note != null &&
        note.isNotEmpty &&
        (status == BusinessPublicationStatus.changesRequested ||
            status == BusinessPublicationStatus.rejected ||
            status == BusinessPublicationStatus.suspended);

    final primaryLabel = switch (status) {
      BusinessPublicationStatus.draft => 'Continuar configuración',
      BusinessPublicationStatus.changesRequested => 'Corregir publicación',
      BusinessPublicationStatus.published => 'Administrar negocio',
      _ => null,
    };
    final primaryAction = onContinue ?? onManage;

    return ProviderHubPanel(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_iconFor(status), color: RancoColors.forest, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleFor(status),
                      style: const TextStyle(
                        color: RancoColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _messageFor(status),
                      style: const TextStyle(
                        color: RancoColors.textSecondary,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (status == BusinessPublicationStatus.pendingReview &&
              business.submittedAt != null) ...[
            const SizedBox(height: 14),
            _MetaLine(
              icon: Icons.event_outlined,
              text: 'Enviado el ${_formatDate(business.submittedAt!)}',
            ),
          ],
          if (showNote) ...[
            const SizedBox(height: 16),
            _AdminNote(note: note),
          ],
          if (draft != null) ...[
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 16),
            draft!.when(
              data: (value) => _ProgressChecklist(
                steps: onboardingProgressSteps(value),
              ),
              loading: () => const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RancoSkeletonBox(width: 160, height: 12),
                  SizedBox(height: 12),
                  RancoSkeletonBox(height: 6),
                  SizedBox(height: 14),
                  RancoSkeletonBox(height: 90),
                ],
              ),
              // El progreso es informativo: si falla, el CTA sigue
              // disponible.
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
          if (status == BusinessPublicationStatus.pendingReview) ...[
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 16),
            const _NextSteps(),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (primaryLabel != null && primaryAction != null)
                FilledButton.icon(
                  onPressed: primaryAction,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(primaryLabel),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 46),
                  ),
                ),
              if (reviewWhatsApp != null)
                OutlinedButton.icon(
                  onPressed: () => launchUrl(
                    reviewWhatsApp!.link,
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.chat_outlined, size: 18),
                  label: const Text('Avisar al administrador por WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                  ),
                ),
              TextButton.icon(
                onPressed: onAccount,
                icon: const Icon(Icons.person_outline_rounded, size: 18),
                label: const Text('Volver a Cuenta'),
                style: TextButton.styleFrom(minimumSize: const Size(0, 46)),
              ),
            ],
          ),
          if (reviewWhatsApp != null) ...[
            const SizedBox(height: 6),
            const Text(
              'Revisa el mensaje y confirma el envío en WhatsApp.',
              style: TextStyle(
                color: RancoColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static IconData _iconFor(BusinessPublicationStatus status) {
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

  static String _titleFor(BusinessPublicationStatus status) {
    return switch (status) {
      BusinessPublicationStatus.draft => 'Tu publicación aún no está visible.',
      BusinessPublicationStatus.pendingReview =>
        'Estamos revisando tu publicación.',
      BusinessPublicationStatus.changesRequested => 'Hay cambios solicitados',
      BusinessPublicationStatus.rejected => 'Solicitud rechazada',
      BusinessPublicationStatus.suspended => 'Negocio suspendido',
      BusinessPublicationStatus.archived => 'Negocio archivado',
      BusinessPublicationStatus.paused => 'Negocio pausado',
      BusinessPublicationStatus.published => 'Tu negocio está publicado',
    };
  }

  static String _messageFor(BusinessPublicationStatus status) {
    return switch (status) {
      BusinessPublicationStatus.draft =>
        'Completa la configuración y envíala a revisión. Puedes guardar y '
            'continuar más tarde.',
      BusinessPublicationStatus.pendingReview =>
        'Te avisaremos cuando sea aprobada o si requiere cambios.',
      BusinessPublicationStatus.changesRequested =>
        'Revisa la observación del equipo y corrige la publicación. Tus '
            'datos anteriores se conservan.',
      BusinessPublicationStatus.rejected =>
        'La publicación no puede avanzar con la información enviada. Revisa '
            'el motivo indicado por administración.',
      BusinessPublicationStatus.suspended =>
        'El negocio no está visible públicamente mientras se resuelve la '
            'suspensión.',
      BusinessPublicationStatus.archived =>
        'El negocio está archivado y no aparece públicamente.',
      BusinessPublicationStatus.paused =>
        'El negocio está pausado y no aparece públicamente.',
      BusinessPublicationStatus.published =>
        'Gestiona tus solicitudes, fotos y datos desde el resumen.',
    };
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: RancoColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: RancoColors.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AdminNote extends StatelessWidget {
  const _AdminNote({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFFD9A441), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Observación del equipo',
            style: TextStyle(
              color: Color(0xFF7A4F0E),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            note,
            style: const TextStyle(
              color: RancoColors.textPrimary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressChecklist extends StatelessWidget {
  const _ProgressChecklist({required this.steps});

  final List<OnboardingProgressStep> steps;

  @override
  Widget build(BuildContext context) {
    final done = steps.where((step) => step.done).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Progreso de configuración',
                style: TextStyle(
                  color: RancoColors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$done de ${steps.length}',
              style: const TextStyle(
                color: RancoColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: done / steps.length,
            minHeight: 6,
            backgroundColor: const Color(0xFFE5EEEA),
            color: RancoColors.forest,
            semanticsLabel: 'Progreso de configuración',
            semanticsValue: '${(done * 100 / steps.length).round()}%',
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 520 ? 2 : 1;
            final width = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - 16) / 2;
            return Wrap(
              spacing: 16,
              runSpacing: 2,
              children: [
                for (final step in steps)
                  SizedBox(
                    width: width,
                    child: _StepLine(step: step),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.step});

  final OnboardingProgressStep step;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${step.label}: ${step.done ? 'completo' : 'pendiente'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              step.done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 19,
              color: step.done ? RancoColors.forest : const Color(0xFFA9B8B1),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                step.label,
                style: TextStyle(
                  color: step.done
                      ? RancoColors.textPrimary
                      : RancoColors.textSecondary,
                  fontSize: 14,
                  fontWeight: step.done ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (!step.done)
              const Text(
                'Pendiente',
                style: TextStyle(
                  color: RancoColors.textSecondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NextSteps extends StatelessWidget {
  const _NextSteps();

  static const _items = [
    'Revisamos que la información esté completa y sea clara.',
    'Te avisaremos en Notificaciones si se publica o si requiere cambios.',
    'Una vez publicado, gestionarás solicitudes, fotos y datos desde aquí.',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Qué sigue',
          style: TextStyle(
            color: RancoColors.textPrimary,
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < _items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: RancoColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: RancoColors.primaryDark,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _items[i],
                      style: const TextStyle(
                        color: RancoColors.textSecondary,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
