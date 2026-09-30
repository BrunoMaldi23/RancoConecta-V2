import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../features/admin/application/admin_providers.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/messaging/application/messaging_providers.dart';
import '../features/locations/application/location_providers.dart';
import '../features/notifications/application/notification_providers.dart';
import '../features/provider_dashboard/application/provider_dashboard_providers.dart';
import '../features/profile/application/profile_providers.dart';
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
    final showLoginAction = !isSignedIn && !auth.isLoading;
    final selectedLocation = ref.watch(selectedLocationProvider);
    final activeBusiness = user == null
        ? null
        : ref.watch(activeProviderBusinessProvider).valueOrNull;
    final adminRole =
        user == null ? null : ref.watch(currentAdminRoleProvider).valueOrNull;

    final profile =
        user == null ? null : ref.watch(currentProfileProvider).valueOrNull;

    final rawProfileName = profile?.fullName?.trim() ?? '';
    final userDisplayName = rawProfileName.isNotEmpty
        ? rawProfileName
        : (user?.email?.split('@').first ?? 'Usuario');

    final userInitial = userDisplayName.isNotEmpty
        ? userDisplayName.substring(0, 1).toUpperCase()
        : 'U';

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
                  unreadAccount: unreadAccount,
                  unreadMessages: chatEnabled ? unreadMessages : 0,
                  unreadNotifications: unreadNotifications,
                  showMessages: chatEnabled,
                  showProvider: activeBusiness != null,
                  showAdmin: adminRole != null,
                  isSignedIn: isSignedIn,
                  showLoginAction: showLoginAction,
                  onBranchSelected: _goBranch,
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
                        isSignedIn: user != null,
                        hasProviderBusiness: activeBusiness != null,
                        unreadNotifications: unreadNotifications,
                        userName: userDisplayName,
                        userInitial: userInitial,
                        currentPath: GoRouterState.of(context).uri.path,
                      ),
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
                  child: NavigationBar(
                    selectedIndex: navigationShell.currentIndex,
                    onDestinationSelected: _goBranch,
                    destinations: [
                      for (final indexed in _destinations.indexed)
                        NavigationDestination(
                          icon: _BadgedIcon(
                            icon: indexed.$2.icon,
                            count: indexed.$1 == 4 ? unreadAccount : 0,
                          ),
                          selectedIcon: _BadgedIcon(
                            icon: indexed.$2.selectedIcon,
                            count: indexed.$1 == 4 ? unreadAccount : 0,
                          ),
                          label: indexed.$2.label,
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.locationName,
    required this.isSignedIn,
    required this.hasProviderBusiness,
    required this.unreadNotifications,
    required this.userName,
    required this.userInitial,
    required this.currentPath,
  });

  final String locationName;
  final bool isSignedIn;
  final bool hasProviderBusiness;
  final int unreadNotifications;
  final String userName;
  final String userInitial;
  final String currentPath;

  @override
  Widget build(BuildContext context) {
    final exploreSelected = currentPath.startsWith('/explore');

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(
        horizontal: 28,
      ),
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
          _TopBarPill(
            icon: Icons.location_on_outlined,
            label: locationName,
            trailing: Icons.keyboard_arrow_down_rounded,
            onTap: () {
              context.go('/explore');
            },
          ),
          const Spacer(),
          if (hasProviderBusiness)
            _TopBarPill(
              icon: Icons.storefront_outlined,
              label: 'Mi negocio',
              onTap: () {
                context.go('/provider/dashboard');
              },
            )
          else if (!isSignedIn)
            _TopBarTextAction(
              label: 'Para prestadores',
              onTap: () {
                context.go('/provider/join');
              },
            ),
          const SizedBox(width: 8),
          _TopBarPill(
            icon: Icons.search_rounded,
            label: 'Explorar',
            selected: exploreSelected,
            onTap: () {
              context.go('/explore');
            },
          ),
          const SizedBox(width: 8),
          _TopBarNotificationButton(
            count: unreadNotifications,
            onTap: () {
              if (isSignedIn) {
                context.go('/notifications');
              } else {
                context.go('/sign-in');
              }
            },
          ),
          const SizedBox(width: 8),
          if (isSignedIn)
            _TopBarUserButton(
              name: userName,
              initial: userInitial,
              onTap: () {
                context.go('/account');
              },
            )
          else
            _TopBarPill(
              icon: Icons.login_rounded,
              label: 'Ingresar',
              selected: true,
              onTap: () {
                context.go('/sign-in');
              },
            ),
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
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final IconData? trailing;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final background = selected ? const Color(0xFFE8F4EF) : Colors.white;

    final border = selected ? const Color(0xFFD4E8DF) : const Color(0xFFDDE7E2);

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

    return Material(
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
              Text(
                compactName,
                style: const TextStyle(
                  color: RancoColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 17,
                color: Color(0xFF6D7E76),
              ),
            ],
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
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SidebarBrand(),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    for (final indexed in destinations.indexed)
                      _SidebarItem(
                        icon: indexed.$2.icon,
                        selectedIcon: indexed.$2.selectedIcon,
                        label: indexed.$2.label,
                        selected: currentIndex == indexed.$1,
                        badgeCount: indexed.$1 == 4 ? unreadAccount : 0,
                        onTap: () => onBranchSelected(indexed.$1),
                      ),
                    const SizedBox(height: 10),
                    const _SidebarSectionLabel('Actividad'),
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
                    if (showProvider) ...[
                      const SizedBox(height: 10),
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
                      const SizedBox(height: 10),
                      const _SidebarSectionLabel('Admin'),
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
                  onTap: () => context.go('/sign-in'),
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
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/branding/ranco_logo_login.png',
            width: 38,
            height: 38,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE5F1EC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.landscape_outlined,
                color: RancoColors.forest,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Ranco Conecta',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: RancoColors.forest,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  const _SidebarSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: RancoColors.textSecondary,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: .45,
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
    const dangerColor = Color(0xFF8F2D3A);
    const dangerBorder = Color(0xFFE8C9D0);
    const dangerBackground = Color(0xFFFFF7F8);

    final foreground = danger
        ? dangerColor
        : selected
            ? RancoColors.forest
            : RancoColors.textPrimary;

    final iconColor = danger
        ? dangerColor
        : selected
            ? RancoColors.forest
            : RancoColors.slate;

    final background = danger
        ? dangerBackground
        : selected
            ? const Color(0xFFEAF4F0)
            : Colors.transparent;

    final borderColor = danger
        ? dangerBorder
        : selected
            ? RancoColors.forest.withValues(
                alpha: .18,
              )
            : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 2,
      ),
      child: Tooltip(
        message: label,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(13),
            mouseCursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: RancoDurations.fast,
              constraints: const BoxConstraints(
                minHeight: 46,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  13,
                ),
                border: Border.all(
                  color: borderColor,
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: RancoDurations.fast,
                    width: 3,
                    height: 24,
                    decoration: BoxDecoration(
                      color: danger
                          ? dangerColor
                          : selected
                              ? RancoColors.forest
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(
                    width: 9,
                  ),
                  Icon(
                    selected ? selectedIcon : icon,
                    size: 20,
                    color: iconColor,
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13.5,
                        fontWeight: danger
                            ? FontWeight.w700
                            : selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (badgeCount > 0)
                    Badge.count(
                      count: badgeCount > 99 ? 99 : badgeCount,
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
