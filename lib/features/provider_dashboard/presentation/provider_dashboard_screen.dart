import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/ranco_colors.dart';
import '../../../shared/models/business.dart';
import '../../../shared/models/business_capability.dart';
import '../application/provider_dashboard_providers.dart';
import '../data/provider_business_repository.dart';
import '../data/service_business_management_repository.dart';
import '../../../core/widgets/ranco_app_bar.dart';

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
      backgroundColor: const Color(
        0xFFEAF4F0,
      ),
      appBar: const RancoAppBar(
        title: 'Mi negocio',
        fallbackRoute: '/account',
      ),
      body: activeBusiness.when(
        data: (business) {
          if (business == null) {
            return const Center(
              child: Text(
                'No encontramos tu negocio.',
              ),
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
                    const Icon(
                      Icons.hourglass_top_outlined,
                      color: RancoColors.forest,
                      size: 42,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      publicationStatus.label,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: RancoColors.forest,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Este negocio aún no está publicado.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () {
                        context.go('/provider/status');
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
          final items = _dashboardItems(
            capabilitySet,
          );
          final management = ref.watch(serviceBusinessManagementProvider);

          return ListView(
            padding: const EdgeInsets.all(
              18,
            ),
            children: [
              businesses.maybeWhen(
                data: (items) {
                  if (items.length < 2) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _BusinessSwitcherButton(
                      business: business,
                      businesses: items,
                      onSelected: (value) {
                        ref
                            .read(activeProviderBusinessIdProvider.notifier)
                            .state = value;
                        ref.invalidate(activeProviderBusinessProvider);
                        ref.invalidate(activeProviderCapabilitiesProvider);
                        ref.invalidate(serviceBusinessManagementProvider);
                      },
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              _ProviderHero(
                business: business,
                onPreview: () {
                  context.go(
                    '/business/${business.id}',
                  );
                },
              ),
              if (business.businessType == BusinessType.service) ...[
                const SizedBox(height: 10),
                management.maybeWhen(
                  data: (state) => state == null
                      ? const SizedBox.shrink()
                      : _ServiceSummaryStrip(state: state),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
              const SizedBox(
                height: 18,
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _sectionTitleFor(business.businessType),
                      style: const TextStyle(
                        color: RancoColors.forest,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    '${items.where((item) => item.route != null).length} activos',
                    style: const TextStyle(
                      color: Color(0xFF61736A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              ...items.map(
                (item) => _DashboardTile(
                  icon: item.icon,
                  title: item.title,
                  subtitle: item.subtitle,
                  onTap: item.route == null
                      ? null
                      : () {
                          context.go(
                            item.route!,
                          );
                        },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (
          error,
          stackTrace,
        ) =>
            const Center(
          child: Text(
            'No pudimos cargar tu negocio.',
          ),
        ),
      ),
    );
  }
}

List<_ProviderDashboardItem> _dashboardItems(
    BusinessCapabilitySet capabilities) {
  return [
    if (capabilities.can(BusinessCapability.profile))
      const _ProviderDashboardItem(
        icon: Icons.storefront_outlined,
        title: 'Perfil',
        subtitle: 'Nombre, descripción, contacto y dirección',
        route: '/provider/profile',
      ),
    if (capabilities.can(BusinessCapability.photos))
      const _ProviderDashboardItem(
        icon: Icons.photo_library_outlined,
        title: 'Fotos',
        subtitle: 'Portada y galería pública',
        route: '/provider/photos',
      ),
    if (capabilities.can(BusinessCapability.services))
      const _ProviderDashboardItem(
        icon: Icons.home_repair_service_outlined,
        title: 'Servicios',
        subtitle: 'Subcategorías, descripción y precio desde',
        route: '/provider/services',
      ),
    if (capabilities.can(BusinessCapability.services))
      const _ProviderDashboardItem(
        icon: Icons.assignment_outlined,
        title: 'Solicitudes',
        subtitle: 'Solicitudes, cotizaciones y operaciones',
        route: '/provider/requests',
      ),
    if (capabilities.can(BusinessCapability.coverage))
      const _ProviderDashboardItem(
        icon: Icons.map_outlined,
        title: 'Cobertura',
        subtitle: 'Localidades donde atiende el negocio',
        route: '/provider/coverage',
      ),
    if (capabilities.can(BusinessCapability.hours))
      const _ProviderDashboardItem(
        icon: Icons.schedule_outlined,
        title: 'Horarios',
        subtitle: 'Días y horas de atención',
        route: '/provider/hours',
      ),
    if (capabilities.can(BusinessCapability.menu))
      const _ProviderDashboardItem(
        icon: Icons.restaurant_menu_outlined,
        title: 'Menú',
        subtitle: 'Base gastronómica; módulo de menú pendiente',
      ),
    if (capabilities.can(BusinessCapability.catalog))
      const _ProviderDashboardItem(
        icon: Icons.inventory_2_outlined,
        title: 'Catálogo',
        subtitle: 'Base comercial; catálogo dedicado pendiente',
      ),
    if (capabilities.can(BusinessCapability.rates))
      const _ProviderDashboardItem(
        icon: Icons.payments_outlined,
        title: 'Tarifas',
        subtitle: 'Precios y condiciones del alojamiento',
        route: '/provider/rates',
      ),
    if (capabilities.can(BusinessCapability.calendar))
      const _ProviderDashboardItem(
        icon: Icons.calendar_month_outlined,
        title: 'Calendario',
        subtitle: 'Disponibilidad y bloqueos',
        route: '/provider/calendar',
      ),
    if (capabilities.can(BusinessCapability.bookings))
      const _ProviderDashboardItem(
        icon: Icons.event_available_outlined,
        title: 'Reservas',
        subtitle: 'Reservas recibidas para el alojamiento',
        route: '/provider/bookings',
      ),
    if (capabilities.can(BusinessCapability.emergencyAvailability))
      const _ProviderDashboardItem(
        icon: Icons.emergency_outlined,
        title: 'Disponibilidad de emergencia',
        subtitle: 'Base operacional de atención prioritaria',
      ),
    if (capabilities.can(BusinessCapability.promotions))
      const _ProviderDashboardItem(
        icon: Icons.campaign_outlined,
        title: 'Promociones',
        subtitle: 'Requiere módulo de monetización visible',
      ),
  ];
}

String _sectionTitleFor(BusinessType type) {
  return switch (type) {
    BusinessType.lodging => 'Gestión de alojamiento',
    BusinessType.service => 'Gestión de servicios',
    BusinessType.commerce => 'Gestión comercial',
    BusinessType.gastronomy => 'Gestión gastronómica',
    BusinessType.tourism => 'Gestión turística',
    BusinessType.emergency => 'Gestión de emergencia',
  };
}

IconData _typeIcon(BusinessType type) {
  return switch (type) {
    BusinessType.commerce => Icons.storefront_outlined,
    BusinessType.gastronomy => Icons.restaurant_outlined,
    BusinessType.lodging => Icons.holiday_village_outlined,
    BusinessType.tourism => Icons.terrain_outlined,
    BusinessType.emergency => Icons.emergency_outlined,
    BusinessType.service => Icons.handyman_outlined,
  };
}

class _ProviderDashboardItem {
  const _ProviderDashboardItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? route;
}

class _BusinessSwitcherButton extends StatelessWidget {
  const _BusinessSwitcherButton({
    required this.business,
    required this.businesses,
    required this.onSelected,
  });

  final ProviderBusinessSummary business;
  final List<ProviderBusinessSummary> businesses;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
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
            border: Border.all(color: const Color(0xFFD4E0DA)),
          ),
          child: Row(
            children: [
              Icon(
                _typeIcon(business.businessType),
                color: RancoColors.forest,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      business.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RancoColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${business.businessType.label} · ${_statusText(business.publicationStatus)}',
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
              for (final item in businesses)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Icon(
                    _typeIcon(item.businessType),
                    color: RancoColors.forest,
                  ),
                  title: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item.businessType.label} · ${_statusText(item.publicationStatus)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: item.id == business.id
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () {
                    onSelected(item.id);
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

String _statusText(String rawStatus) {
  return BusinessPublicationStatus.parseOrDefault(rawStatus).label;
}

class _ServiceSummaryStrip extends StatelessWidget {
  const _ServiceSummaryStrip({
    required this.state,
  });

  final ServiceBusinessManagementState state;

  @override
  Widget build(BuildContext context) {
    final hours = state.draft.hours.where((hour) => !hour.isClosed).length;
    return Row(
      children: [
        Expanded(
          child: _SummaryChip(
            value: state.draft.services.length.toString(),
            label: 'servicios',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryChip(
            value: state.draft.coverage.length.toString(),
            label: 'localidades',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryChip(
            value: hours.toString(),
            label: 'días abiertos',
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4E0DA)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: RancoColors.forest,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: RancoColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderHero extends StatelessWidget {
  const _ProviderHero({
    required this.business,
    required this.onPreview,
  });

  final ProviderBusinessSummary business;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final status = BusinessPublicationStatus.parseOrDefault(
      business.publicationStatus,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD4E0DA)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE4F3EC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _typeIcon(business.businessType),
              color: RancoColors.forest,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  business.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RancoColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${business.businessType.label} · ${status.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RancoColors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            onPressed: onPreview,
            tooltip: 'Ver publicación',
            icon: const Icon(
              Icons.visibility_outlined,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          15,
        ),
        border: Border.all(
          color: const Color(
            0xFFD4E0DA,
          ),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 2,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(
              0xFFE4F3EC,
            ),
            borderRadius: BorderRadius.circular(
              12,
            ),
          ),
          child: Icon(
            icon,
            color: RancoColors.forest,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          onTap == null
              ? Icons.info_outline_rounded
              : Icons.chevron_right_rounded,
          color: onTap == null ? const Color(0xFF9AA8A2) : RancoColors.forest,
        ),
      ),
    );
  }
}
