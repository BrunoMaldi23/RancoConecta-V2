import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/layout/ranco_responsive.dart';
import '../../../core/widgets/ranco_app_bar.dart';
import '../../../core/widgets/ranco_error_state.dart';
import '../../../core/widgets/ranco_states.dart';
import '../../../core/widgets/ranco_status_badge.dart';
import '../../../shared/models/business.dart';
import '../../../shared/models/business_capability.dart';
import '../../../shared/models/quote.dart';
import '../../../theme/ranco_colors.dart';
import '../../service_requests/application/service_request_providers.dart';
import '../application/provider_dashboard_providers.dart';
import 'provider_hub.dart';

/// Resumen del hub "Mi negocio" para un negocio publicado. Los estados
/// previos (borrador, revisión, cambios) los muestra
/// `ProviderBusinessStatusScreen`; ambos cuelgan de `/provider/business`.
class ProviderDashboardScreen extends ConsumerWidget {
  const ProviderDashboardScreen({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final businesses = ref.watch(
      myProviderBusinessesProvider,
    );
    final activeBusiness = ref.watch(
      activeProviderBusinessProvider,
    );
    final capabilities = ref.watch(
      activeProviderCapabilitiesProvider,
    );

    return Scaffold(
      backgroundColor: RancoColors.canvas,
      appBar: const RancoAppBar(
        title: 'Mi negocio',
        fallbackRoute: '/account',
        bottom: ProviderHubTabBar(current: providerHubHomeRoute),
      ),
      body: activeBusiness.when(
        data: (business) {
          if (business == null) {
            return RancoErrorState(
              message: 'No encontramos tu negocio.',
              detail: 'Vuelve a Cuenta para revisar tu acceso.',
              onRetry: () => ref.invalidate(myProviderBusinessesProvider),
            );
          }

          final publicationStatus = BusinessPublicationStatus.parseOrDefault(
            business.publicationStatus,
          );

          if (publicationStatus != BusinessPublicationStatus.published) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RancoStatusBadge(
                      label: publicationStatus.label,
                      tone: providerPublicationTone(publicationStatus),
                      dot: true,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Este negocio aún no está publicado.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        context.go(providerHubHomeRoute);
                      },
                      child: const Text('Ver estado'),
                    ),
                  ],
                ),
              ),
            );
          }

          final capabilitySet = capabilities.valueOrNull ??
              const BusinessCapabilitySet(
                {},
              );
          final sections = providerHubSections(
            capabilitySet,
            business.businessType,
          );
          final isService = business.businessType == BusinessType.service &&
              capabilitySet.can(BusinessCapability.services);
          final management = business.businessType == BusinessType.service
              ? ref.watch(serviceBusinessManagementProvider).valueOrNull
              : null;
          final requests =
              isService ? ref.watch(providerRequestQueueProvider) : null;

          void go(String route) => context.go(route);

          final quickActions = ProviderHubPanel(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                ProviderHubActionRow(
                  icon: Icons.open_in_new_rounded,
                  title: 'Ver perfil público',
                  subtitle: 'Así te ven los visitantes',
                  onTap: () => go('/business/${business.id}'),
                ),
                if (capabilitySet.can(BusinessCapability.profile) ||
                    capabilitySet.can(BusinessCapability.contact))
                  ProviderHubActionRow(
                    icon: Icons.edit_outlined,
                    title: 'Editar negocio',
                    subtitle: 'Descripción, contacto y dirección',
                    onTap: () => go('/provider/profile'),
                  ),
                if (capabilitySet.can(BusinessCapability.photos))
                  ProviderHubActionRow(
                    icon: Icons.photo_library_outlined,
                    title: 'Gestionar fotos',
                    subtitle: 'Perfil, portada y galería',
                    onTap: () => go('/provider/photos'),
                  ),
              ],
            ),
          );

          final upcoming = [
            for (final section in sections)
              if (section.route == null) section,
          ];

          final primary = <Widget>[
            if (isService && requests != null)
              _RecentRequests(
                requests: requests,
                onOpenAll: () => go('/provider/requests'),
                onRetry: () => ref.invalidate(providerRequestQueueProvider),
              )
            else
              _ManageSections(
                sections: [
                  for (final section in sections)
                    if (section.route != null) section,
                ],
                onOpen: go,
              ),
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 40),
            children: [
              RancoContentContainer(
                width: RancoContainerWidth.standard,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ProviderHubHeader(
                      business: business,
                      businesses: businesses.valueOrNull ?? const [],
                      onViewPublic: () => go('/business/${business.id}'),
                      onBusinessChanged: (value) {
                        ref
                            .read(activeProviderBusinessIdProvider.notifier)
                            .state = value;
                        ref.invalidate(activeProviderBusinessProvider);
                        ref.invalidate(activeProviderCapabilitiesProvider);
                        ref.invalidate(serviceBusinessManagementProvider);
                      },
                    ),
                    if (management != null) ...[
                      const SizedBox(height: 14),
                      RancoResponsiveGrid(
                        minItemWidth: 180,
                        maxColumns: 4,
                        minColumns: 2,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final (value, label, icon)
                              in serviceHubMetrics(management))
                            ProviderHubMetric(
                              value: value,
                              label: label,
                              icon: icon,
                            ),
                          if (requests?.valueOrNull case final items?)
                            ProviderHubMetric(
                              value: items
                                  .where((item) => item.stateLabel == 'Nueva')
                                  .length
                                  .toString(),
                              label: 'solicitudes nuevas',
                              icon: Icons.mark_email_unread_outlined,
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 22),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final side = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const ProviderHubSectionTitle('Acciones rápidas'),
                            quickActions,
                            if (upcoming.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              const ProviderHubSectionTitle(
                                  'Próximamente en tu plan'),
                              ProviderHubPanel(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  children: [
                                    for (final section in upcoming)
                                      ProviderHubActionRow(
                                        icon: section.icon,
                                        title: section.title,
                                        subtitle: section.subtitle,
                                        locked: section.locked,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                        if (constraints.maxWidth >= 860) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: primary,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(flex: 2, child: side),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ...primary,
                            const SizedBox(height: 22),
                            side,
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const _DashboardSkeleton(),
        error: (
          error,
          stackTrace,
        ) =>
            RancoErrorState(
          message: 'No pudimos cargar tu negocio.',
          onRetry: () => ref.invalidate(myProviderBusinessesProvider),
        ),
      ),
    );
  }
}

class _ManageSections extends StatelessWidget {
  const _ManageSections({
    required this.sections,
    required this.onOpen,
  });

  final List<ProviderHubSection> sections;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ProviderHubSectionTitle('Gestión'),
        ProviderHubPanel(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              for (final section in sections)
                ProviderHubActionRow(
                  icon: section.icon,
                  title: section.title,
                  subtitle: section.subtitle,
                  onTap: () => onOpen(section.route!),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentRequests extends StatelessWidget {
  const _RecentRequests({
    required this.requests,
    required this.onOpenAll,
    required this.onRetry,
  });

  final AsyncValue<List<ProviderRequestItem>> requests;
  final VoidCallback onOpenAll;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProviderHubSectionTitle(
          'Solicitudes recientes',
          trailing: TextButton(
            onPressed: onOpenAll,
            style: TextButton.styleFrom(minimumSize: const Size(0, 40)),
            child: const Text('Ver todas'),
          ),
        ),
        ProviderHubPanel(
          padding: const EdgeInsets.all(8),
          child: requests.when(
            data: (items) {
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(10, 14, 10, 14),
                  child: Text(
                    'Aún no recibes solicitudes. Cuando un visitante te '
                    'escriba, aparecerá aquí.',
                    style: TextStyle(
                      color: RancoColors.textSecondary,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                );
              }
              final recent = items.take(4).toList();
              return Column(
                children: [
                  for (var i = 0; i < recent.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 54, endIndent: 6),
                    _RequestRow(item: recent[i], onTap: onOpenAll),
                  ],
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                children: [
                  RancoSkeletonBox(height: 40),
                  SizedBox(height: 10),
                  RancoSkeletonBox(height: 40),
                ],
              ),
            ),
            error: (_, __) => RancoErrorState(
              message: 'No pudimos cargar tus solicitudes.',
              onRetry: onRetry,
              compact: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.item, required this.onTap});

  final ProviderRequestItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat.MMMd('es').format(item.createdAt.toLocal());
    final where = item.locationName;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: RancoColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.assignment_outlined,
                  size: 18, color: RancoColors.forest),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.subcategoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RancoColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (where != null && where.isNotEmpty) where,
                      date,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RancoColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            RancoStatusBadge(
              label: item.stateLabel,
              tone: item.stateLabel == 'Nueva'
                  ? RancoStatusTone.info
                  : rancoToneForStatusLabel(item.stateLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
        children: const [
          RancoContentContainer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RancoSkeletonCard(
                  children: [
                    Row(
                      children: [
                        RancoSkeletonBox(width: 48, height: 48, radius: 14),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RancoSkeletonBox(width: 220, height: 16),
                              SizedBox(height: 10),
                              RancoSkeletonBox(width: 140, height: 12),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 14),
                RancoSkeletonBox(height: 64, radius: 16),
                SizedBox(height: 22),
                RancoSkeletonBox(height: 180, radius: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
