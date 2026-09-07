import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/ranco_tokens.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    _Destination('Inicio', Icons.home_outlined, Icons.home),
    _Destination('Explorar', Icons.search_outlined, Icons.search),
    _Destination('Solicitudes', Icons.assignment_outlined, Icons.assignment),
    _Destination('Guardados', Icons.bookmark_border, Icons.bookmark),
    _Destination('Cuenta', Icons.person_outline, Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= RancoBreakpoints.medium;
        return Scaffold(
          body: Row(
            children: [
              if (useRail)
                NavigationRail(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _goBranch,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final destination in _destinations)
                      NavigationRailDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: Text(destination.label),
                      ),
                  ],
                ),
              Expanded(child: navigationShell),
            ],
          ),
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _goBranch,
                  destinations: [
                    for (final destination in _destinations)
                      NavigationDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: destination.label,
                      ),
                  ],
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
