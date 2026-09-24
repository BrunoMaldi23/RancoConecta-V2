import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../features/admin/application/admin_providers.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/supabase_auth_repository.dart';
import '../features/locations/presentation/location_selector.dart';
import '../features/messaging/application/messaging_providers.dart';
import '../features/notifications/application/notification_providers.dart';
import '../features/profile/application/profile_providers.dart';
import '../features/provider_dashboard/application/provider_dashboard_providers.dart';
import '../features/provider_dashboard/data/provider_business_repository.dart';
import '../theme/ranco_colors.dart';

class RancoNavigationDrawer extends ConsumerWidget {
  const RancoNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final user = ref.watch(authStateProvider).valueOrNull;
    final isSignedIn = user != null;
    final profile = isSignedIn ? ref.watch(currentProfileProvider) : null;
    final businesses =
        isSignedIn ? ref.watch(myProviderBusinessesProvider) : null;
    final activeBusiness =
        isSignedIn ? ref.watch(activeProviderBusinessProvider) : null;
    final adminRole = isSignedIn ? ref.watch(currentAdminRoleProvider) : null;
    final chatEnabled = ref.watch(appConfigProvider).featureFlags.chatEnabled;
    final unreadMessages = chatEnabled
        ? ref.watch(unreadMessagesCountProvider).valueOrNull ?? 0
        : 0;
    final unreadNotifications =
        ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;

    return Drawer(
      width: _drawerWidth(context),
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(22)),
      ),
      child: SafeArea(
        child: Semantics(
          label: 'Menú principal de Ranco Conecta',
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  children: [
                    _DrawerHeader(
                      isSignedIn: isSignedIn,
                      name: profile?.valueOrNull?.fullName,
                      email: user?.email,
                      onAccount: () {
                        _go(context, isSignedIn ? '/account' : '/sign-in');
                      },
                    ),
                    const SizedBox(height: 12),
                    const _LocationRow(),
                    const SizedBox(height: 14),
                    _DrawerSection(
                      children: [
                        _NavigationItem(
                          icon: Icons.home_outlined,
                          selectedIcon: Icons.home_rounded,
                          label: 'Inicio',
                          route: '/',
                          currentPath: path,
                        ),
                        _NavigationItem(
                          icon: Icons.search_rounded,
                          selectedIcon: Icons.search_rounded,
                          label: 'Explorar',
                          route: '/explore',
                          currentPath: path,
                        ),
                        _NavigationItem(
                          icon: Icons.bookmark_border_rounded,
                          selectedIcon: Icons.bookmark_rounded,
                          label: 'Guardados',
                          route: '/saved',
                          currentPath: path,
                        ),
                        _NavigationItem(
                          icon: Icons.assignment_outlined,
                          selectedIcon: Icons.assignment_rounded,
                          label: 'Mis solicitudes',
                          route: '/requests',
                          currentPath: path,
                        ),
                        if (chatEnabled)
                          _NavigationItem(
                            icon: Icons.chat_bubble_outline_rounded,
                            selectedIcon: Icons.chat_bubble_rounded,
                            label: 'Mensajes',
                            route: '/messages',
                            currentPath: path,
                            badgeCount: unreadMessages,
                          ),
                        _NavigationItem(
                          icon: Icons.notifications_none_rounded,
                          selectedIcon: Icons.notifications_rounded,
                          label: 'Notificaciones',
                          route: '/notifications',
                          currentPath: path,
                          badgeCount: unreadNotifications,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _ProviderSection(
                      businesses: businesses,
                      activeBusiness: activeBusiness,
                      isSignedIn: isSignedIn,
                    ),
                    if (adminRole?.valueOrNull != null) ...[
                      const SizedBox(height: 16),
                      const _SectionLabel('Administración'),
                      const SizedBox(height: 6),
                      _DrawerSection(
                        children: [
                          _NavigationItem(
                            icon: Icons.admin_panel_settings_outlined,
                            selectedIcon: Icons.admin_panel_settings_rounded,
                            label: 'Panel administrativo',
                            route: '/admin',
                            currentPath: path,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (isSignedIn)
                _LogoutAction(
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    ref.invalidate(currentProfileProvider);
                    ref.invalidate(myProviderBusinessProvider);
                    ref.invalidate(myProviderBusinessesProvider);
                    ref.invalidate(activeProviderBusinessProvider);
                    ref.read(activeProviderBusinessIdProvider.notifier).state =
                        null;
                    if (context.mounted) {
                      _go(context, '/sign-in');
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  double _drawerWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 900) {
      return 360;
    }
    if (width >= 600) {
      return 340;
    }
    return width.clamp(304, 334).toDouble();
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.isSignedIn,
    required this.onAccount,
    this.name,
    this.email,
  });

  final bool isSignedIn;
  final String? name;
  final String? email;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final display = (name?.trim().isNotEmpty == true ? name!.trim() : email) ??
        'Modo visitante';
    final subtitle = isSignedIn ? email ?? 'Cuenta activa' : 'Iniciar sesión';
    final initial = display.substring(0, 1).toUpperCase();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAccount,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/branding/ranco_logo_login.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5F1EC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.near_me_outlined,
                        color: RancoColors.forest,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ranco Conecta',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: RancoColors.forest,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      display,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RancoColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RancoColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: isSignedIn ? 'Abrir cuenta' : 'Iniciar sesión',
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: const Color(0xFFE5F1EC),
                  child: Text(
                    isSignedIn ? initial : '?',
                    style: const TextStyle(
                      color: RancoColors.forest,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Cerrar menú',
                child: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                  color: RancoColors.textSecondary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Seleccionar ubicación',
      child: const LocationSelector(
        compact: true,
        label: 'Ubicación',
      ),
    );
  }
}

class _ProviderSection extends ConsumerWidget {
  const _ProviderSection({
    required this.businesses,
    required this.activeBusiness,
    required this.isSignedIn,
  });

  final AsyncValue<List<ProviderBusinessSummary>>? businesses;
  final AsyncValue<ProviderBusinessSummary?>? activeBusiness;
  final bool isSignedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = businesses?.valueOrNull ?? const <ProviderBusinessSummary>[];
    final active = activeBusiness?.valueOrNull;

    if (!isSignedIn || items.isEmpty) {
      return _ProviderCallToAction(
        title: '¿Ofreces un servicio?',
        subtitle: 'Publica en Ranco Conecta',
        route: isSignedIn ? '/provider/register' : '/provider/join',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Mi negocio'),
        const SizedBox(height: 6),
        _ProviderTile(
          business: active ?? items.first,
          count: items.length,
          onChange: items.length > 1
              ? () => _showBusinessSwitcher(context, ref, items, active)
              : null,
        ),
      ],
    );
  }

  Future<void> _showBusinessSwitcher(
    BuildContext context,
    WidgetRef ref,
    List<ProviderBusinessSummary> items,
    ProviderBusinessSummary? active,
  ) {
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
              for (final business in items)
                ListTile(
                  leading: Icon(
                    business.isLodging
                        ? Icons.holiday_village_outlined
                        : Icons.storefront_outlined,
                  ),
                  title: Text(business.name),
                  subtitle: Text(_businessStateLabel(business)),
                  trailing: active?.id == business.id
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () {
                    ref.read(activeProviderBusinessIdProvider.notifier).state =
                        business.id;
                    ref.invalidate(activeProviderBusinessProvider);
                    ref.invalidate(serviceBusinessManagementProvider);
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

class _ProviderCallToAction extends StatelessWidget {
  const _ProviderCallToAction({
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFEAF4F0),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: () => _go(context, route),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.storefront_outlined, color: RancoColors.forest),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: RancoColors.forest,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: RancoColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded,
                  color: RancoColors.forest),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({
    required this.business,
    required this.count,
    this.onChange,
  });

  final ProviderBusinessSummary business;
  final int count;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final route = _businessRoute(business);

    return _DrawerSection(
      children: [
        _NavigationItem(
          icon: business.isLodging
              ? Icons.holiday_village_outlined
              : Icons.storefront_outlined,
          selectedIcon: business.isLodging
              ? Icons.holiday_village_rounded
              : Icons.storefront_rounded,
          label: _businessTitle(business),
          subtitle:
              '${business.businessType.label} · ${_businessStateLabel(business)}',
          route: route,
          currentPath: GoRouterState.of(context).uri.path,
          trailing: onChange == null
              ? null
              : Tooltip(
                  message: 'Cambiar negocio',
                  child: IconButton(
                    onPressed: onChange,
                    icon: const Icon(Icons.swap_horiz_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
        ),
      ],
    );
  }
}

class _DrawerSection extends StatelessWidget {
  const _DrawerSection({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD8E5DF)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: children),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
    required this.currentPath,
    this.subtitle,
    this.badgeCount = 0,
    this.trailing,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? subtitle;
  final String route;
  final String currentPath;
  final int badgeCount;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final selected = _isSelected(currentPath, route);
    final color = selected ? RancoColors.forest : RancoColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Tooltip(
          message: label,
          child: Material(
            color: selected ? const Color(0xFFEAF4F0) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _go(context, route),
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 46),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      width: 3,
                      height: 26,
                      decoration: BoxDecoration(
                        color:
                            selected ? RancoColors.forest : Colors.transparent,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      selected ? selectedIcon : icon,
                      size: 20,
                      color: selected ? RancoColors.forest : RancoColors.slate,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontWeight:
                                  selected ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: RancoColors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (badgeCount > 0) ...[
                      _UnreadBadge(count: badgeCount),
                      const SizedBox(width: 8),
                    ],
                    trailing ??
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: selected
                              ? RancoColors.forest
                              : RancoColors.textSecondary,
                        ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isSelected(String path, String route) {
    if (route == '/') {
      return path == '/';
    }
    return path == route || path.startsWith('$route/');
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: RancoColors.forest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LogoutAction extends StatelessWidget {
  const _LogoutAction({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Cerrar sesión'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(44),
          foregroundColor: RancoColors.forest,
          side: const BorderSide(color: Color(0xFFC7D8D0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: RancoColors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: .4,
      ),
    );
  }
}

String _businessTitle(ProviderBusinessSummary business) {
  return switch (business.publicationStatus.toLowerCase()) {
    'draft' => 'Continuar publicación',
    'pending_review' || 'pending' => 'Negocio en revisión',
    'changes_requested' => 'Corregir publicación',
    'published' => business.name,
    'suspended' => 'Negocio suspendido',
    'rejected' => 'Publicación rechazada',
    _ => 'Administrar negocio',
  };
}

String _businessStateLabel(ProviderBusinessSummary business) {
  return switch (business.publicationStatus.toLowerCase()) {
    'draft' => 'Borrador',
    'pending_review' || 'pending' => 'Pendiente de revisión',
    'changes_requested' => 'Cambios solicitados',
    'published' => 'Publicado',
    'suspended' => 'Suspendido',
    'rejected' => 'Rechazado',
    _ => business.publicationStatus,
  };
}

String _businessRoute(ProviderBusinessSummary business) {
  return switch (business.publicationStatus.toLowerCase()) {
    'draft' || 'changes_requested' || 'rejected' => '/provider/register',
    'pending_review' || 'pending' || 'suspended' => '/provider/status',
    'published' => '/provider/dashboard',
    _ => '/provider/status',
  };
}

void _go(BuildContext context, String route) {
  Navigator.of(context).maybePop();
  context.go(route);
}
