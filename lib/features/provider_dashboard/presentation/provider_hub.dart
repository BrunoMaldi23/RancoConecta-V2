import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/ranco_responsive.dart';
import '../../../core/widgets/ranco_status_badge.dart';
import '../../../shared/models/business.dart';
import '../../../shared/models/business_capability.dart';
import '../../../theme/ranco_colors.dart';
import '../../../theme/ranco_tokens.dart';
import '../application/provider_dashboard_providers.dart';
import '../data/provider_business_repository.dart';
import '../data/service_business_management_repository.dart';

/// Hub "Mi negocio" (FASE 3.21): encabezado del negocio + pestañas que unen
/// Resumen y las pantallas de gestión existentes, para no saltar de pantalla
/// aislada en pantalla aislada. Las rutas y permisos no cambian: cada pestaña
/// abre la misma ruta que antes y el router mantiene sus redirecciones.

/// Ruta del resumen del hub.
const providerHubHomeRoute = '/provider/business';

/// Sección de gestión del negocio. Con [route] nula se muestra como
/// "próximamente" (sin pestaña).
class ProviderHubSection {
  const ProviderHubSection({
    required this.tab,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.route,
    this.locked = false,
  });

  /// Etiqueta corta de la pestaña.
  final String tab;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? route;
  final bool locked;
}

/// Secciones según tipo de negocio y capacidades (mismas reglas que el
/// tablero anterior). Orden: operación → contenido → perfil.
List<ProviderHubSection> providerHubSections(
  BusinessCapabilitySet capabilities,
  BusinessType type,
) {
  ProviderHubSection photos() => ProviderHubSection(
        tab: 'Fotos',
        icon: Icons.photo_library_outlined,
        title: 'Fotos',
        subtitle:
            'Hasta ${capabilities.limit(BusinessLimit.maxPhotos) ?? 5} fotos de galería',
        route: '/provider/photos',
      );

  return switch (type) {
    BusinessType.service => [
        if (capabilities.can(BusinessCapability.services))
          const ProviderHubSection(
            tab: 'Solicitudes',
            icon: Icons.assignment_outlined,
            title: 'Solicitudes',
            subtitle: 'Nuevas, cotizadas, en curso y finalizadas',
            route: '/provider/requests',
          ),
        if (capabilities.can(BusinessCapability.services))
          ProviderHubSection(
            tab: 'Servicios',
            icon: Icons.home_repair_service_outlined,
            title: 'Servicios',
            subtitle:
                'Hasta ${capabilities.limit(BusinessLimit.maxServices) ?? 5} servicios publicados',
            route: '/provider/services',
          ),
        if (capabilities.can(BusinessCapability.coverage))
          ProviderHubSection(
            tab: 'Cobertura',
            icon: Icons.map_outlined,
            title: 'Cobertura',
            subtitle:
                'Hasta ${capabilities.limit(BusinessLimit.maxLocations) ?? 1} localidades',
            route: '/provider/coverage',
          ),
        if (capabilities.can(BusinessCapability.photos)) photos(),
        if (capabilities.can(BusinessCapability.profile))
          const ProviderHubSection(
            tab: 'Perfil',
            icon: Icons.storefront_outlined,
            title: 'Perfil',
            subtitle: 'Nombre, descripción, contacto y dirección',
            route: '/provider/profile',
          ),
      ],
    BusinessType.lodging => [
        if (capabilities.can(BusinessCapability.bookings))
          const ProviderHubSection(
            tab: 'Reservas',
            icon: Icons.event_available_outlined,
            title: 'Reservas',
            subtitle: 'Pendientes, confirmadas e historial',
            route: '/provider/bookings',
          ),
        if (capabilities.can(BusinessCapability.calendar))
          const ProviderHubSection(
            tab: 'Calendario',
            icon: Icons.calendar_month_outlined,
            title: 'Calendario',
            subtitle: 'Disponibilidad y bloqueos',
            route: '/provider/calendar',
          ),
        if (capabilities.can(BusinessCapability.rates))
          const ProviderHubSection(
            tab: 'Tarifas',
            icon: Icons.payments_outlined,
            title: 'Tarifas',
            subtitle: 'Precio por noche y huéspedes adicionales',
            route: '/provider/rates',
          ),
        if (capabilities.can(BusinessCapability.photos)) photos(),
        if (capabilities.can(BusinessCapability.rates))
          const ProviderHubSection(
            tab: 'Alojamiento',
            icon: Icons.tune_outlined,
            title: 'Alojamiento',
            subtitle: 'Capacidad, horarios y políticas de estadía',
            route: '/provider/lodging',
          ),
      ],
    BusinessType.gastronomy => [
        ProviderHubSection(
          tab: 'Reservas',
          icon: Icons.event_seat_outlined,
          title: 'Reservas de mesa',
          subtitle: capabilities.can(BusinessCapability.tableReservations)
              ? 'Solicitudes pendientes y confirmadas'
              : 'Disponible en Plan Pro',
          locked: !capabilities.can(BusinessCapability.tableReservations),
          route: capabilities.can(BusinessCapability.tableReservations)
              ? '/provider/table-reservations'
              : null,
        ),
        if (capabilities.can(BusinessCapability.menu))
          ProviderHubSection(
            tab: 'Menú',
            icon: Icons.restaurant_menu_outlined,
            title: 'Menú',
            subtitle:
                'Hasta ${capabilities.limit(BusinessLimit.maxMenuItems) ?? 15} elementos',
            route: '/provider/menu',
          ),
        if (capabilities.can(BusinessCapability.photos)) photos(),
        if (capabilities.can(BusinessCapability.profile))
          const ProviderHubSection(
            tab: 'Perfil',
            icon: Icons.restaurant_outlined,
            title: 'Perfil',
            subtitle: 'Descripción, ubicación, horarios y contacto',
            route: '/provider/profile',
          ),
      ],
    BusinessType.commerce => [
        if (capabilities.can(BusinessCapability.catalog))
          ProviderHubSection(
            tab: 'Productos',
            icon: Icons.inventory_2_outlined,
            title: 'Productos',
            subtitle:
                'Hasta ${capabilities.limit(BusinessLimit.maxProducts) ?? 15} productos referenciales',
          ),
        if (capabilities.can(BusinessCapability.hours))
          const ProviderHubSection(
            tab: 'Horarios',
            icon: Icons.schedule_outlined,
            title: 'Horarios',
            subtitle: 'Días y horas de atención',
            route: '/provider/hours',
          ),
        if (capabilities.can(BusinessCapability.location))
          const ProviderHubSection(
            tab: 'Ubicación',
            icon: Icons.location_on_outlined,
            title: 'Ubicación',
            subtitle: 'Dirección y localidad del comercio',
            route: '/provider/location',
          ),
        if (capabilities.can(BusinessCapability.photos)) photos(),
        if (capabilities.can(BusinessCapability.profile) ||
            capabilities.can(BusinessCapability.contact))
          const ProviderHubSection(
            tab: 'Perfil',
            icon: Icons.storefront_outlined,
            title: 'Perfil y contacto',
            subtitle: 'Nombre, descripción, teléfono y redes',
            route: '/provider/profile',
          ),
      ],
    BusinessType.tourism => [
        if (capabilities.can(BusinessCapability.experiences))
          ProviderHubSection(
            tab: 'Experiencias',
            icon: Icons.hiking_outlined,
            title: 'Experiencias',
            subtitle:
                'Hasta ${capabilities.limit(BusinessLimit.maxExperiences) ?? 3} experiencias',
          ),
        ProviderHubSection(
          tab: 'Reservas',
          icon: Icons.event_available_outlined,
          title: 'Reservas',
          subtitle: capabilities.can(BusinessCapability.bookings)
              ? 'Solicitudes simples de experiencias'
              : 'Disponible en Plan Pro',
          locked: !capabilities.can(BusinessCapability.bookings),
        ),
        if (capabilities.can(BusinessCapability.photos)) photos(),
        if (capabilities.can(BusinessCapability.profile))
          const ProviderHubSection(
            tab: 'Perfil',
            icon: Icons.terrain_outlined,
            title: 'Perfil',
            subtitle: 'Descripción, contacto y ubicación',
            route: '/provider/profile',
          ),
      ],
    BusinessType.emergency => [
        if (capabilities.can(BusinessCapability.emergencyAvailability))
          const ProviderHubSection(
            tab: 'Disponibilidad',
            icon: Icons.emergency_outlined,
            title: 'Disponibilidad',
            subtitle: 'Base operacional para atención prioritaria',
          ),
        if (capabilities.can(BusinessCapability.coverage))
          ProviderHubSection(
            tab: 'Cobertura',
            icon: Icons.map_outlined,
            title: 'Cobertura',
            subtitle:
                'Hasta ${capabilities.limit(BusinessLimit.maxLocations) ?? 1} zonas',
            route: '/provider/coverage',
          ),
        if (capabilities.can(BusinessCapability.photos)) photos(),
        if (capabilities.can(BusinessCapability.profile))
          const ProviderHubSection(
            tab: 'Perfil',
            icon: Icons.local_hospital_outlined,
            title: 'Perfil',
            subtitle: 'Información pública del prestador de salud',
            route: '/provider/profile',
          ),
      ],
  };
}

IconData providerBusinessTypeIcon(BusinessType type) {
  return switch (type) {
    BusinessType.commerce => Icons.storefront_outlined,
    BusinessType.gastronomy => Icons.restaurant_outlined,
    BusinessType.lodging => Icons.holiday_village_outlined,
    BusinessType.tourism => Icons.terrain_outlined,
    BusinessType.emergency => Icons.emergency_outlined,
    BusinessType.service => Icons.handyman_outlined,
  };
}

/// Tono del badge de publicación: verde publicado, ámbar en revisión o con
/// cambios, rojo rechazado/suspendido, gris borrador/pausado/archivado.
RancoStatusTone providerPublicationTone(BusinessPublicationStatus status) {
  return switch (status) {
    BusinessPublicationStatus.published => RancoStatusTone.success,
    BusinessPublicationStatus.pendingReview ||
    BusinessPublicationStatus.changesRequested =>
      RancoStatusTone.warning,
    BusinessPublicationStatus.rejected ||
    BusinessPublicationStatus.suspended =>
      RancoStatusTone.danger,
    BusinessPublicationStatus.draft => RancoStatusTone.info,
    BusinessPublicationStatus.paused ||
    BusinessPublicationStatus.archived =>
      RancoStatusTone.muted,
  };
}

/// Pestañas del hub. Va en `bottom` del AppBar del resumen y de cada
/// pantalla de gestión; [current] marca la pestaña activa. Solo aparece con
/// un negocio publicado (las demás rutas de gestión no son accesibles antes).
class ProviderHubTabBar extends ConsumerWidget implements PreferredSizeWidget {
  const ProviderHubTabBar({required this.current, super.key});

  final String current;

  static const height = 48.0;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(activeProviderBusinessProvider).valueOrNull;
    final capabilities = ref.watch(activeProviderCapabilitiesProvider);
    final published = business != null &&
        BusinessPublicationStatus.parseOrDefault(business.publicationStatus) ==
            BusinessPublicationStatus.published;

    final tabs = <(String, String)>[
      ('Resumen', providerHubHomeRoute),
      if (published)
        for (final section in providerHubSections(
          capabilities.valueOrNull ?? const BusinessCapabilitySet({}),
          business.businessType,
        ))
          if (section.route != null) (section.tab, section.route!),
    ];

    return Container(
      height: height,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFDFE9E4))),
      ),
      child: RancoContentContainer(
        width: RancoContainerWidth.standard,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (label, route) in tabs)
                  _HubTab(
                    label: label,
                    selected: route == current,
                    onTap: route == current ? null : () => context.go(route),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HubTab extends StatelessWidget {
  const _HubTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        child: AnimatedContainer(
          duration: RancoDurations.quick,
          constraints: const BoxConstraints(minHeight: 46, minWidth: 48),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? RancoColors.forest : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? RancoColors.primaryDark
                  : RancoColors.textSecondary,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Encabezado del negocio en el hub: ícono del tipo, nombre, tipo, estado y
/// acciones (ver perfil público, cambiar negocio).
class ProviderHubHeader extends StatelessWidget {
  const ProviderHubHeader({
    required this.business,
    this.businesses = const [],
    this.onBusinessChanged,
    this.onViewPublic,
    super.key,
  });

  final ProviderBusinessSummary business;
  final List<ProviderBusinessSummary> businesses;
  final ValueChanged<String>? onBusinessChanged;
  final VoidCallback? onViewPublic;

  @override
  Widget build(BuildContext context) {
    final status =
        BusinessPublicationStatus.parseOrDefault(business.publicationStatus);
    final canSwitch = businesses.length > 1 && onBusinessChanged != null;

    final identity = Row(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: RancoColors.primarySoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            providerBusinessTypeIcon(business.businessType),
            color: RancoColors.primaryDark,
            size: 24,
          ),
        ),
        const SizedBox(width: 14),
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
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -.2,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    business.businessType.label,
                    style: const TextStyle(
                      color: RancoColors.textSecondary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  RancoStatusBadge(
                    label: status.label,
                    tone: providerPublicationTone(status),
                    dot: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final actions = <Widget>[
      if (canSwitch)
        TextButton.icon(
          onPressed: () => _showSwitcher(context),
          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
          label: const Text('Cambiar negocio'),
          style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
        ),
      if (onViewPublic != null)
        OutlinedButton.icon(
          onPressed: onViewPublic,
          icon: const Icon(Icons.open_in_new_rounded, size: 17),
          label: const Text('Ver perfil público'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0EAE5)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (actions.isEmpty) return identity;
          if (constraints.maxWidth >= 620) {
            return Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 16),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              identity,
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showSwitcher(BuildContext context) {
    return showRancoAdaptiveModal<void>(
      context: context,
      maxWidth: 520,
      builder: (sheetContext) {
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    'Cambiar negocio',
                    style: TextStyle(
                      color: RancoColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                for (final item in businesses)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: Icon(
                      providerBusinessTypeIcon(item.businessType),
                      color: RancoColors.forest,
                    ),
                    title: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${item.businessType.label} · ${BusinessPublicationStatus.parseOrDefault(item.publicationStatus).label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: item.id == business.id
                        ? const Icon(Icons.check_rounded,
                            color: RancoColors.forest)
                        : null,
                    onTap: () {
                      onBusinessChanged!(item.id);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Título de bloque dentro del hub.
class ProviderHubSectionTitle extends StatelessWidget {
  const ProviderHubSectionTitle(this.title, {this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: const TextStyle(
                  color: RancoColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Superficie blanca de bloque del hub.
class ProviderHubPanel extends StatelessWidget {
  const ProviderHubPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0EAE5)),
      ),
      child: child,
    );
  }
}

/// Métrica compacta del hub (valor + etiqueta).
class ProviderHubMetric extends StatelessWidget {
  const ProviderHubMetric({
    required this.value,
    required this.label,
    required this.icon,
    super.key,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ProviderHubPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: RancoColors.forest),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: RancoColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
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
        ],
      ),
    );
  }
}

/// Fila de acción/sección del hub (ícono, título, subtítulo, chevron).
class ProviderHubActionRow extends StatelessWidget {
  const ProviderHubActionRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.locked = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final muted = locked || onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      muted ? const Color(0xFFF0F3F1) : RancoColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color: muted ? const Color(0xFF7D8D85) : RancoColors.forest,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: muted
                            ? RancoColors.textSecondary
                            : RancoColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: RancoColors.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (locked)
                const Tooltip(
                  message: 'No incluido en tu plan actual',
                  child: Icon(Icons.lock_outline_rounded,
                      size: 18, color: Color(0xFF9AA8A2)),
                )
              else if (onTap != null)
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: RancoColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resumen numérico de un negocio de servicios (estado de gestión local).
List<(String, String, IconData)> serviceHubMetrics(
  ServiceBusinessManagementState state,
) {
  final openDays = state.draft.hours.where((hour) => !hour.isClosed).length;
  return [
    (
      state.draft.services.length.toString(),
      state.draft.services.length == 1 ? 'servicio' : 'servicios',
      Icons.home_repair_service_outlined,
    ),
    (
      state.draft.coverage.length.toString(),
      state.draft.coverage.length == 1 ? 'localidad' : 'localidades',
      Icons.map_outlined,
    ),
    (
      openDays.toString(),
      openDays == 1 ? 'día de atención' : 'días de atención',
      Icons.schedule_outlined,
    ),
  ];
}
