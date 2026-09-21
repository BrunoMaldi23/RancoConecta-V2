import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/ranco_colors.dart';
import '../../../shared/models/business.dart';
import '../../../shared/models/business_capability.dart';
import '../application/provider_dashboard_providers.dart';
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
                    padding: const EdgeInsets.only(
                      bottom: 14,
                    ),
                    child: DropdownButtonFormField<String>(
                      initialValue: business.id,
                      decoration: const InputDecoration(
                        labelText: 'Negocio activo',
                        prefixIcon: Icon(
                          Icons.storefront_outlined,
                        ),
                      ),
                      items: items
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                '${item.name} · ${item.businessType.label}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;

                        ref
                            .read(activeProviderBusinessIdProvider.notifier)
                            .state = value;
                      },
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
              Container(
                padding: const EdgeInsets.all(
                  18,
                ),
                decoration: BoxDecoration(
                  color: RancoColors.forest,
                  borderRadius: BorderRadius.circular(
                    22,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _typeIcon(
                        business.businessType,
                      ),
                      color: Colors.white,
                      size: 34,
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    Text(
                      business.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      '${business.businessType.label} · publicación ${business.publicationStatus}',
                      style: const TextStyle(
                        color: Color(
                          0xFFD8EBE3,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 14,
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        context.go(
                          '/business/${business.id}',
                        );
                      },
                      icon: const Icon(
                        Icons.visibility_outlined,
                      ),
                      label: const Text(
                        'Ver publicación',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 22,
              ),
              const Text(
                'GESTIÓN',
                style: TextStyle(
                  color: Color(
                    0xFF718078,
                  ),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                ),
              ),
              const SizedBox(
                height: 8,
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
            'No pudimos cargar el alojamiento.',
          ),
        ),
      ),
    );
  }
}

List<_ProviderDashboardItem> _dashboardItems(
  BusinessCapabilitySet capabilities,
) {
  return [
    if (capabilities.can(BusinessCapability.profile))
      const _ProviderDashboardItem(
        icon: Icons.storefront_outlined,
        title: 'Perfil público',
        subtitle: 'Nombre, descripción, contacto, horarios e imágenes',
        route: '/provider/photos',
      ),
    if (capabilities.can(BusinessCapability.services))
      const _ProviderDashboardItem(
        icon: Icons.home_repair_service_outlined,
        title: 'Servicios',
        subtitle: 'Servicios, precios orientativos y disponibilidad',
      ),
    if (capabilities.can(BusinessCapability.coverage))
      const _ProviderDashboardItem(
        icon: Icons.map_outlined,
        title: 'Cobertura',
        subtitle: 'Localidades, radio y zonas atendidas',
      ),
    if (capabilities.can(BusinessCapability.menu))
      const _ProviderDashboardItem(
        icon: Icons.restaurant_menu_outlined,
        title: 'Menú',
        subtitle: 'Carta, horarios y opciones futuras',
      ),
    if (capabilities.can(BusinessCapability.catalog))
      const _ProviderDashboardItem(
        icon: Icons.inventory_2_outlined,
        title: 'Catálogo',
        subtitle: 'Productos, categorías y ofertas futuras',
      ),
    if (capabilities.can(BusinessCapability.rates))
      const _ProviderDashboardItem(
        icon: Icons.payments_outlined,
        title: 'Tarifas',
        subtitle: 'Precio por noche, actividad o persona adicional',
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
        subtitle: 'Solicitudes recibidas',
        route: '/provider/bookings',
      ),
    if (capabilities.can(BusinessCapability.emergencyAvailability))
      const _ProviderDashboardItem(
        icon: Icons.emergency_outlined,
        title: 'Disponibilidad de emergencia',
        subtitle: 'Contacto, cobertura y estado operativo',
      ),
    if (capabilities.can(BusinessCapability.promotions))
      const _ProviderDashboardItem(
        icon: Icons.campaign_outlined,
        title: 'Promociones',
        subtitle: 'Ofertas y destacados comerciales',
      ),
  ];
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
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          17,
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
          horizontal: 15,
          vertical: 5,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(
              0xFFE4F3EC,
            ),
            borderRadius: BorderRadius.circular(
              13,
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
        ),
        trailing: Icon(
          onTap == null
              ? Icons.lock_clock_outlined
              : Icons.chevron_right_rounded,
        ),
      ),
    );
  }
}
