import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../core/widgets/ranco_brand.dart';
import '../features/admin/application/admin_providers.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/visitor_contact_validation.dart';
import '../features/businesses/application/business_providers.dart';
import '../features/messaging/application/messaging_providers.dart';
import '../features/locations/application/location_providers.dart';
import '../features/locations/presentation/location_selector.dart';
import '../features/notifications/application/notification_providers.dart';
import '../features/provider_dashboard/application/provider_dashboard_providers.dart';
import '../features/profile/application/profile_providers.dart';
import '../shared/models/profile.dart';
import '../theme/ranco_colors.dart';
import '../theme/ranco_tokens.dart';
import 'ranco_navigation_drawer.dart';
import 'session_actions.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    _Destination('Inicio', Icons.home_outlined, Icons.home_rounded),
    _Destination('Explorar', Icons.search_rounded, Icons.search_rounded),
    _Destination(
        'Solicitudes', Icons.assignment_outlined, Icons.assignment_rounded),
    _Destination(
        'Guardados', Icons.bookmark_border_rounded, Icons.bookmark_rounded),
    _Destination('Cuenta', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (GoRouterState.of(context).uri.path == '/' &&
        (ref.read(businessSearchQueryProvider).isNotEmpty ||
            ref.read(selectedCategoryIdProvider) != null ||
            ref.read(selectedLocationProvider) != null ||
            ref.read(verifiedOnlyProvider) ||
            ref.read(featuredOnlyProvider) ||
            ref.read(openNowOnlyProvider))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && GoRouterState.of(context).uri.path == '/') {
          ref.read(businessSearchQueryProvider.notifier).state = '';
          clearBusinessFilters(ref);
        }
      });
    }
    ref.watch(messagingRealtimeProvider);
    ref.watch(notificationsRealtimeProvider);

    final unreadMessages =
        ref.watch(unreadMessagesCountProvider).valueOrNull ?? 0;
    final unreadNotifications =
        ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
    final unreadAccount = unreadMessages + unreadNotifications;
    final chatEnabled = ref.watch(appConfigProvider).featureFlags.chatEnabled;
    // Fuente de verdad: estado real de Supabase. Mientras la sesión está en
    // loading no se renderiza ninguna acción de sesión.
    final auth = ref.watch(authStateProvider);
    final user = auth.valueOrNull;
    final isSignedIn = user != null;
    final isVisitor = user?.isAnonymous == true;
    final selectedLocation = ref.watch(selectedLocationProvider);
    final profile =
        user == null ? null : ref.watch(currentProfileProvider).valueOrNull;
    final activeBusiness =
        !isVisitor && profile != null && !profile.role.canAccessAdmin
            ? ref.watch(activeProviderBusinessProvider).valueOrNull
            : null;
    final adminRole =
        user == null ? null : ref.watch(currentAdminRoleProvider).valueOrNull;
    final visitorHasProfile = isVisitor &&
        (profile?.fullName?.trim().length ?? 0) >= 3 &&
        isValidChileanWhatsapp(profile?.phone);
    final publicVisitor = !isSignedIn || (isVisitor && !visitorHasProfile);
    final showLoginAction = publicVisitor && !auth.isLoading;

    final rawProfileName = profile?.fullName?.trim() ?? '';
    final userDisplayName = rawProfileName.isNotEmpty
        ? rawProfileName
        : (user?.email?.split('@').first ?? 'Usuario');

    final userInitial = userDisplayName.isNotEmpty
        ? userDisplayName.substring(0, 1).toUpperCase()
        : 'U';
    final visibleBranches =
        publicVisitor ? const [0, 1] : const [0, 1, 2, 3, 4];
    final isProvider = !isVisitor &&
        (profile?.role == ProfileRole.provider || activeBusiness != null);

    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktopSidebar =
            constraints.maxWidth >= RancoBreakpoints.expanded;
        final sidebarWidth =
            constraints.maxWidth >= RancoBreakpoints.large ? 256.0 : 244.0;
        return Scaffold(
          drawer: useDesktopSidebar ? null : const RancoNavigationDrawer(),
          drawerScrimColor: Colors.black.withValues(alpha: .44),
          body: Row(
            children: [
              if (useDesktopSidebar)
                _DesktopSidebar(
                  width: sidebarWidth,
                  currentIndex: navigationShell.currentIndex,
                  currentPath: GoRouterState.of(context).uri.path,
                  destinations: _destinations,
                  visibleBranches: visibleBranches,
                  visitor: isVisitor,
                  unreadAccount: unreadAccount,
                  unreadMessages: chatEnabled ? unreadMessages : 0,
                  unreadNotifications: unreadNotifications,
                  showMessages: chatEnabled && !isVisitor,
                  showProvider: isProvider,
                  showAdmin: adminRole != null,
                  isSignedIn: !publicVisitor,
                  showLoginAction: showLoginAction,
                  onBranchSelected: (index) => _goBranch(index, ref),
                  onSignOut: () async {
                    await signOutAndGoToSignIn(context, ref);
                  },
                ),
              Expanded(
                child: Column(
                  children: [
                    if (useDesktopSidebar)
                      _DesktopTopBar(
                        locationName:
                            selectedLocation?.name ?? 'Todas las localidades',
                        isSignedIn: !publicVisitor,
                        unreadNotifications: unreadNotifications,
                        userName: userDisplayName,
                        userInitial: userInitial,
                        onLocationTap: () => showLocationPicker(context, ref),
                      ),
                    // El footer público vive dentro del scroll de cada
                    // página (RancoFooterSliver) para no tapar contenido.
                    Expanded(child: navigationShell),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: useDesktopSidebar
              ? null
              : SafeArea(
                  top: false,
                  child: isProvider
                      ? NavigationBar(
                          selectedIndex:
                              navigationShell.currentIndex == 2 ? 1 : 2,
                          onDestinationSelected: (index) {
                            if (index == 0) {
                              context.go('/provider/dashboard');
                            } else if (index == 1) {
                              context.go('/provider/requests');
                            } else {
                              _goBranch(4, ref);
                            }
                          },
                          destinations: const [
                            NavigationDestination(
                                icon: Icon(Icons.storefront_outlined),
                                label: 'Mi negocio'),
                            NavigationDestination(
                                icon: Icon(Icons.assignment_outlined),
                                label: 'Solicitudes'),
                            NavigationDestination(
                                icon: Icon(Icons.settings_outlined),
                                label: 'Configuración'),
                          ],
                        )
                      : NavigationBar(
                          selectedIndex: visibleBranches
                                  .contains(navigationShell.currentIndex)
                              ? visibleBranches
                                  .indexOf(navigationShell.currentIndex)
                              : 0,
                          onDestinationSelected: (index) {
                            if (publicVisitor &&
                                index == visibleBranches.length) {
                              context.go(
                                  isVisitor ? '/sign-in?choose=1' : '/sign-in');
                            } else {
                              _goBranch(visibleBranches[index], ref);
                            }
                          },
                          destinations: [
                            for (final branch in visibleBranches)
                              NavigationDestination(
                                icon: _BadgedIcon(
                                  icon: _destinations[branch].icon,
                                  count: branch == 4 ? unreadAccount : 0,
                                ),
                                selectedIcon: _BadgedIcon(
                                  icon: _destinations[branch].selectedIcon,
                                  count: branch == 4 ? unreadAccount : 0,
                                ),
                                label: _destinations[branch].label,
                              ),
                            if (showLoginAction)
                              const NavigationDestination(
                                icon: Icon(Icons.login_rounded),
                                label: 'Ingresar',
                              ),
                          ],
                        ),
                ),
        );
      },
    );
  }

  void _goBranch(int index, WidgetRef ref) {
    if (index == 0) {
      ref.read(businessSearchQueryProvider.notifier).state = '';
      clearBusinessFilters(ref);
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

/// Barra superior desktop. Solo contiene lo que no está en el sidebar:
/// localidad, acceso para prestadores y, con sesión, notificaciones y cuenta.
class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.locationName,
    required this.isSignedIn,
    required this.unreadNotifications,
    required this.userName,
    required this.userInitial,
    required this.onLocationTap,
  });

  final String locationName;
  final bool isSignedIn;
  final int unreadNotifications;
  final String userName;
  final String userInitial;
  final VoidCallback onLocationTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: RancoSpacing.xl),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE3ECE7),
          ),
        ),
      ),
      child: Row(
        children: [
          Tooltip(
            message: 'Cambiar localidad',
            child: _TopBarPill(
              icon: Icons.location_on_outlined,
              label: locationName,
              trailing: Icons.keyboard_arrow_down_rounded,
              onTap: onLocationTap,
            ),
          ),
          const Spacer(),
          if (!isSignedIn)
            _TopBarTextAction(
              label: 'Para prestadores',
              onTap: () {
                context.go('/provider/join');
              },
            )
          else ...[
            _TopBarNotificationButton(
              count: unreadNotifications,
              onTap: () {
                context.go('/notifications');
              },
            ),
            const SizedBox(width: RancoSpacing.sm),
            _TopBarUserButton(
              name: userName,
              initial: userInitial,
              onTap: () {
                context.go('/account');
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _TopBarPill extends StatelessWidget {
  const _TopBarPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    const background = Colors.white;
    const border = Color(0xFFDDE7E2);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 17,
                color: RancoColors.forest,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: RancoColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                Icon(
                  trailing,
                  size: 16,
                  color: const Color(0xFF63756D),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBarTextAction extends StatelessWidget {
  const _TopBarTextAction({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: RancoColors.forest,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Text(label),
    );
  }
}

class _TopBarNotificationButton extends StatelessWidget {
  const _TopBarNotificationButton({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Notificaciones',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  size: 21,
                  color: Color(0xFF506159),
                ),
                if (count > 0)
                  Positioned(
                    right: 7,
                    top: 6,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB63C49),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBarUserButton extends StatelessWidget {
  const _TopBarUserButton({
    required this.name,
    required this.initial,
    required this.onTap,
  });

  final String name;
  final String initial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final compactName =
        name.trim().isEmpty ? 'Usuario' : name.trim().split(' ').first;

    return Tooltip(
      message: 'Mi cuenta',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 42,
            padding: const EdgeInsets.fromLTRB(
              5,
              4,
              9,
              4,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFDDE7E2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDDEFE7),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: RancoColors.forest,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    compactName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RancoColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({
    required this.icon,
    required this.count,
  });

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Icon(icon);
    }

    return Badge.count(
      count: count > 99 ? 99 : count,
      child: Icon(icon),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.width,
    required this.currentIndex,
    required this.currentPath,
    required this.destinations,
    required this.visibleBranches,
    required this.visitor,
    required this.unreadAccount,
    required this.unreadMessages,
    required this.unreadNotifications,
    required this.showMessages,
    required this.showProvider,
    required this.showAdmin,
    required this.isSignedIn,
    required this.showLoginAction,
    required this.onBranchSelected,
    required this.onSignOut,
  });

  final double width;
  final int currentIndex;
  final String currentPath;
  final List<_Destination> destinations;
  final List<int> visibleBranches;
  final bool visitor;
  final int unreadAccount;
  final int unreadMessages;
  final int unreadNotifications;
  final bool showMessages;
  final bool showProvider;
  final bool showAdmin;
  final bool isSignedIn;
  final bool showLoginAction;
  final ValueChanged<int> onBranchSelected;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    Widget branchItem(int branch) => _SidebarItem(
          icon: destinations[branch].icon,
          selectedIcon: destinations[branch].selectedIcon,
          label: destinations[branch].label,
          selected: currentIndex == branch,
          badgeCount: branch == 4 ? unreadAccount : 0,
          onTap: () => onBranchSelected(branch),
        );

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFDDE9E3)),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SidebarBrand(),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  children: [
                    // Agrupación: Descubrir / Tu actividad / Cuenta / Gestión.
                    if (isSignedIn) const _SidebarSectionLabel('Descubrir'),
                    for (final branch in visibleBranches.where((b) => b <= 1))
                      branchItem(branch),
                    if (isSignedIn) ...[
                      const SizedBox(height: RancoSpacing.sm),
                      const _SidebarSectionLabel('Tu actividad'),
                      for (final branch
                          in visibleBranches.where((b) => b == 2 || b == 3))
                        branchItem(branch),
                      if (showMessages)
                        _SidebarItem(
                          icon: Icons.chat_bubble_outline_rounded,
                          selectedIcon: Icons.chat_bubble_rounded,
                          label: 'Mensajes',
                          selected: currentPath.startsWith('/messages'),
                          badgeCount: unreadMessages,
                          onTap: () => context.go('/messages'),
                        ),
                      _SidebarItem(
                        icon: Icons.notifications_none_rounded,
                        selectedIcon: Icons.notifications_rounded,
                        label: 'Notificaciones',
                        selected: currentPath.startsWith('/notifications'),
                        badgeCount: unreadNotifications,
                        onTap: () => context.go('/notifications'),
                      ),
                      const SizedBox(height: RancoSpacing.sm),
                      const _SidebarSectionLabel('Cuenta'),
                      for (final branch in visibleBranches.where((b) => b == 4))
                        branchItem(branch),
                    ],
                    if (showProvider) ...[
                      const SizedBox(height: RancoSpacing.sm),
                      const _SidebarSectionLabel('Gestión'),
                      _SidebarItem(
                        icon: Icons.storefront_outlined,
                        selectedIcon: Icons.storefront_rounded,
                        label: 'Mi negocio',
                        selected: currentPath.startsWith('/provider'),
                        onTap: () => context.go('/provider/dashboard'),
                      ),
                    ],
                    if (showAdmin) ...[
                      const SizedBox(height: RancoSpacing.sm),
                      const _SidebarSectionLabel('Administración'),
                      _SidebarItem(
                        icon: Icons.admin_panel_settings_outlined,
                        selectedIcon: Icons.admin_panel_settings_rounded,
                        label: 'Panel admin',
                        selected: currentPath.startsWith('/admin'),
                        onTap: () => context.go('/admin'),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSignedIn)
                _SidebarItem(
                  icon: Icons.logout_rounded,
                  selectedIcon: Icons.logout_rounded,
                  label: 'Cerrar sesión',
                  selected: false,
                  danger: true,
                  onTap: onSignOut,
                )
              else if (showLoginAction)
                _SidebarItem(
                  icon: Icons.login_rounded,
                  selectedIcon: Icons.login_rounded,
                  label: 'Ingresar',
                  selected: false,
                  onTap: () =>
                      context.go(visitor ? '/sign-in?choose=1' : '/sign-in'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand();

  @override
  Widget build(BuildContext context) {
    // Bloque de marca de ~60 px: emblema real legible + logotipo tipográfico.
    return Semantics(
      button: true,
      label: 'Ranco Conecta, ir al inicio',
      child: InkWell(
        onTap: () => context.go('/'),
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: RancoBrandLockup(subtitle: 'Lago Ranco'),
        ),
      ),
    );
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  const _SidebarSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF7A8B83),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: .6,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
    this.danger = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    const dangerColor = Color(0xFF9A3A44);

    final foreground = danger
        ? dangerColor
        : selected
            ? RancoColors.primaryDark
            : RancoColors.textPrimary;

    final iconColor = danger
        ? dangerColor
        : selected
            ? RancoColors.forest
            : RancoColors.slate;

    // Activo: fondo suave + texto verde + indicador lateral (sin borde).
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? const Color(0xFFEAF4F0) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            mouseCursor: SystemMouseCursors.click,
            hoverColor:
                danger ? const Color(0xFFFBEFF1) : const Color(0xFFF2F8F5),
            focusColor: const Color(0x332F7D57),
            child: SizedBox(
              height: danger ? 38 : 40,
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: RancoDurations.fast,
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: selected ? RancoColors.forest : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Icon(
                    selected ? selectedIcon : icon,
                    size: danger ? 18 : 20,
                    color: iconColor,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: danger ? 13 : 13.5,
                        fontWeight: selected
                            ? FontWeight.w800
                            : danger
                                ? FontWeight.w600
                                : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (badgeCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Badge.count(
                        count: badgeCount > 99 ? 99 : badgeCount,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
