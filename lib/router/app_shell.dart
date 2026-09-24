import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/messaging/application/messaging_providers.dart';
import '../features/notifications/application/notification_providers.dart';
import '../theme/ranco_colors.dart';
import '../theme/ranco_tokens.dart';
import 'ranco_navigation_drawer.dart';

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= RancoBreakpoints.expanded;
        return Scaffold(
          drawer: useRail ? null : const RancoNavigationDrawer(),
          drawerScrimColor: Colors.black.withValues(alpha: .44),
          body: Row(
            children: [
              if (useRail)
                NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _goBranch,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Colors.white,
                  indicatorColor: RancoColors.primarySoft,
                  selectedIconTheme: const IconThemeData(
                    color: RancoColors.primaryDark,
                  ),
                  unselectedIconTheme: const IconThemeData(
                    color: RancoColors.textSecondary,
                  ),
                  selectedLabelTextStyle: const TextStyle(
                    color: RancoColors.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    color: RancoColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  groupAlignment: -0.72,
                  destinations: [
                    for (final indexed in _destinations.indexed)
                      NavigationRailDestination(
                        icon: _BadgedIcon(
                          icon: indexed.$2.icon,
                          count: indexed.$1 == 4 ? unreadAccount : 0,
                        ),
                        selectedIcon: _BadgedIcon(
                          icon: indexed.$2.selectedIcon,
                          count: indexed.$1 == 4 ? unreadAccount : 0,
                        ),
                        label: Text(indexed.$2.label),
                      ),
                  ],
                ),
              Expanded(child: navigationShell),
            ],
          ),
          bottomNavigationBar: useRail
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
