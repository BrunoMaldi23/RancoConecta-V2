import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/ranco_error_state.dart';
import '../../../core/widgets/ranco_skeleton.dart';
import '../../../features/auth/data/supabase_auth_repository.dart';
import '../../../features/businesses/application/business_providers.dart';
import '../../../features/categories/application/category_providers.dart';
import '../../../features/locations/application/location_providers.dart';
import '../../../features/locations/presentation/location_selector.dart';
import '../../../shared/models/category.dart';
import '../../../theme/ranco_colors.dart';
import '../../../theme/ranco_decoration.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final businesses = ref.watch(publishedBusinessesProvider);

    final authRepository = ref.watch(authRepositoryProvider);
    final user = authRepository.currentUser();
    final isSignedIn = user != null;

    return Scaffold(
      backgroundColor: RancoColors.canvas,
      drawer: _RancoDrawer(
        isSignedIn: isSignedIn,
        userEmail: user?.email,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Builder(
                builder: (headerContext) {
                  return _HomeHeader(
                    isSignedIn: isSignedIn,
                    onMenu: () {
                      Scaffold.of(headerContext).openDrawer();
                    },
                    onAccount: () {
                      if (isSignedIn) {
                        context.go('/account');
                      } else {
                        context.go('/sign-in');
                      }
                    },
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: _HomeSearchPanel(
                businesses: businesses,
                onSearch: () {
                  context.go('/explore');
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
                child: _SectionTitle(
                  title: 'Explora por categoría',
                  subtitle: 'Servicios, comercios y experiencias locales.',
                  actionLabel: 'Ver todos',
                  onAction: () {
                    context.go('/explore');
                  },
                ),
              ),
            ),
            categories.when(
              data: (items) {
                if (items.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      child: _EmptySectionCard(
                        icon: Icons.grid_view_rounded,
                        title: 'Aún no hay rubros disponibles',
                        message:
                            'Cuando las categorías estén activas aparecerán aquí.',
                      ),
                    ),
                  );
                }

                return SliverToBoxAdapter(
                  child: _CategoryGrid(
                    categories: items,
                  ),
                );
              },
              loading: () {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20,
                    ),
                    child: RancoSkeleton(
                      height: 260,
                    ),
                  ),
                );
              },
              error: (error, stackTrace) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                    ),
                    child: RancoErrorState(
                      message: failureMessage(
                        error,
                        'No pudimos cargar los rubros.',
                      ),
                      onRetry: () {
                        ref.invalidate(categoriesProvider);
                      },
                    ),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _HomeActionPanel(
                  businesses: businesses,
                  onExplore: () {
                    context.go('/explore');
                  },
                  onPublish: () {
                    context.go('/provider/join');
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.onMenu,
    required this.onAccount,
    required this.isSignedIn,
  });

  final VoidCallback onMenu;
  final VoidCallback onAccount;
  final bool isSignedIn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        10,
        20,
        0,
      ),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _HeaderButton(
                icon: Icons.menu_rounded,
                onTap: onMenu,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDECE6),
                        borderRadius: BorderRadius.circular(19),
                        border: Border.all(
                          color: const Color(0xFFC5D9D0),
                        ),
                      ),
                      child: const Icon(
                        Icons.landscape_outlined,
                        size: 21,
                        color: RancoColors.forest,
                      ),
                    ),
                    const SizedBox(width: 8),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                        children: [
                          TextSpan(
                            text: 'Ranco',
                            style: TextStyle(
                              color: RancoColors.forest,
                            ),
                          ),
                          TextSpan(
                            text: 'Conecta',
                            style: TextStyle(
                              color: Color(0xFFD06A42),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Tooltip(
                message: isSignedIn ? 'Mi cuenta' : 'Ingresar',
                child: _HeaderButton(
                  icon: isSignedIn ? Icons.person_rounded : Icons.login_rounded,
                  onTap: onAccount,
                  accent: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent ? RancoColors.primaryDark : Colors.white,
      borderRadius: BorderRadius.circular(13),
      elevation: 0,
      shadowColor: RancoColors.ink.withValues(alpha: .10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: accent
                ? null
                : Border.all(
                    color: RancoDecoration.softBorder,
                  ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: accent ? Colors.white : RancoColors.forest,
          ),
        ),
      ),
    );
  }
}

class _HomeSearchPanel extends StatelessWidget {
  const _HomeSearchPanel({
    required this.businesses,
    required this.onSearch,
  });

  final AsyncValue businesses;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= 600;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Container(
            padding: EdgeInsets.fromLTRB(
              isWide ? 24 : 20,
              isWide ? 20 : 18,
              isWide ? 24 : 20,
              isWide ? 20 : 18,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFBFEFC),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: RancoDecoration.softBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: RancoColors.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: RancoDecoration.softBorder),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_city_outlined,
                        size: 14,
                        color: RancoColors.primary,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Lago Ranco',
                        style: TextStyle(
                          color: RancoColors.pine,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '¿Qué necesitas hoy?',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: RancoColors.pine,
                        fontWeight: FontWeight.w800,
                        height: 1.08,
                      ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Text(
                    'Encuentra servicios, comercios, gastronomía, alojamientos y experiencias cerca de ti.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: RancoColors.textSecondary,
                          height: 1.42,
                        ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  child: InkWell(
                    onTap: onSearch,
                    borderRadius: BorderRadius.circular(15),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: RancoDecoration.softBorder),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 21,
                            color: RancoColors.primary,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Buscar en Ranco Conecta',
                              style: TextStyle(
                                color: RancoColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const LocationSelector(compact: true),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onSearch,
                        icon: const Icon(
                          Icons.travel_explore_rounded,
                          size: 18,
                        ),
                        label: const Text('Buscar'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: RancoColors.pine,
                          foregroundColor: Colors.white,
                          textStyle: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Quiero ofrecer servicios',
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: RancoColors.primarySoft,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: RancoDecoration.softBorder,
                          ),
                        ),
                        child: const Icon(
                          Icons.handshake_outlined,
                          size: 22,
                          color: RancoColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _LocalSummary(businesses: businesses),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RancoDrawer extends StatelessWidget {
  const _RancoDrawer({
    required this.isSignedIn,
    required this.userEmail,
  });

  final bool isSignedIn;
  final String? userEmail;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 340,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(26),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  20,
                ),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE1F0EA),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.near_me_outlined,
                          color: RancoColors.forest,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                            children: [
                              TextSpan(
                                text: 'Ranco',
                                style: TextStyle(
                                  color: RancoColors.forest,
                                ),
                              ),
                              TextSpan(
                                text: 'Conecta',
                                style: TextStyle(
                                  color: Color(0xFFD06A42),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Consumer(
                    builder: (context, ref, _) {
                      final selectedLocation = ref.watch(
                        selectedLocationProvider,
                      );

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F7F4),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              color: RancoColors.forest,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ubicación',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF72837B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    selectedLocation?.name ??
                                        'Todas las localidades',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: RancoColors.forest,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();

                      if (isSignedIn) {
                        context.go('/account');
                      } else {
                        context.go('/sign-in');
                      }
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFD7E4DE),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE1F0EA),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              isSignedIn
                                  ? Icons.person_outline_rounded
                                  : Icons.person_add_alt_1_outlined,
                              color: RancoColors.forest,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isSignedIn ? 'Mi cuenta' : 'Modo visitante',
                                  style: const TextStyle(
                                    color: RancoColors.forest,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isSignedIn
                                      ? (userEmail ?? 'Cuenta activa')
                                      : 'Explora servicios sin iniciar sesión.',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF72837B),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 15,
                            color: Color(0xFF9AA8A2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DrawerNavigationCard(
                    children: [
                      _DrawerItem(
                        icon: Icons.home_outlined,
                        label: 'Inicio',
                        selected: true,
                        onTap: () {
                          _goDrawer(
                            context,
                            '/',
                          );
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.explore_outlined,
                        label: 'Explorar',
                        onTap: () {
                          _goDrawer(
                            context,
                            '/explore',
                          );
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.favorite_border_rounded,
                        label: 'Guardados',
                        onTap: () {
                          _goDrawer(
                            context,
                            '/saved',
                          );
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.assignment_outlined,
                        label: 'Mis solicitudes',
                        onTap: () {
                          _goDrawer(
                            context,
                            '/requests',
                          );
                        },
                      ),
                      _DrawerItem(
                        icon: Icons.storefront_outlined,
                        label: isSignedIn ? 'Mi negocio' : 'Publicar negocio',
                        onTap: () {
                          _goDrawer(
                            context,
                            isSignedIn ? '/provider/status' : '/provider/join',
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: const Color(0xFFE1F0EA),
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        _goDrawer(
                          context,
                          '/provider/join',
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(15),
                        child: Row(
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              color: RancoColors.forest,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '¿Ofreces un servicio?',
                                    style: TextStyle(
                                      color: RancoColors.forest,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Publica en Ranco Conecta',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF6D7E76),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: RancoColors.forest,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  static void _goDrawer(
    BuildContext context,
    String route,
  ) {
    Navigator.of(context).pop();
    context.go(route);
  }
}

class _DrawerNavigationCard extends StatelessWidget {
  const _DrawerNavigationCard({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: RancoDecoration.card(radius: 20),
      child: Column(
        children: children,
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tone = selected ? RancoColors.pine : RancoColors.slate;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 2,
      ),
      child: Material(
        color: selected ? const Color(0xFFE9F3EF) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 13,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 21,
                  color: tone,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color:
                          selected ? RancoColors.pine : const Color(0xFF405249),
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color:
                      selected ? RancoColors.primary : const Color(0xFFA1ADA8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalSummary extends StatelessWidget {
  const _LocalSummary({
    required this.businesses,
  });

  final AsyncValue businesses;

  @override
  Widget build(BuildContext context) {
    final count = businesses.maybeWhen(
      data: (items) {
        return (items as List).length;
      },
      orElse: () => 0,
    );

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              const Icon(
                Icons.near_me_outlined,
                size: 14,
                color: RancoColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Lago Ranco y sectores cercanos',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: RancoColors.textSecondary,
                        fontSize: 12,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          children: [
            const Icon(
              Icons.groups_outlined,
              size: 14,
              color: RancoColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              '$count prestadores',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: RancoColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: RancoColors.forest,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF71827A),
                    ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onAction,
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

class _CategoryGrid extends ConsumerWidget {
  const _CategoryGrid({
    required this.categories,
  });

  final List<Category> categories;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final visible = categories.take(6).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 700 ? 3 : 2;

          const spacing = 10.0;

          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final category in visible)
                SizedBox(
                  width: width,
                  child: _CategoryCard(
                    category: category,
                    onTap: () {
                      ref
                          .read(
                            selectedCategoryIdProvider.notifier,
                          )
                          .state = category.id;

                      context.go('/explore');
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.onTap,
  });

  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tone = _categoryTone(category);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      shadowColor: RancoColors.ink.withValues(alpha: .08),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: tone.withValues(alpha: .22),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: tone.withValues(alpha: .12),
                  ),
                ),
                child: Icon(
                  _categoryIcon(category),
                  color: tone,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                category.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF31443B),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Ver opciones disponibles',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF71827A),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Explorar',
                    style: TextStyle(
                      color: tone,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: tone,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _categoryIcon(Category category) {
  final key =
      '${category.iconKey} ${category.slug} ${category.name}'.toLowerCase();

  if (key.contains('emerg')) return Icons.emergency_outlined;
  if (key.contains('mecan') || key.contains('auto')) {
    return Icons.build_outlined;
  }
  if (key.contains('flete') || key.contains('trans')) {
    return Icons.local_shipping_outlined;
  }
  if (key.contains('jardin')) return Icons.yard_outlined;
  if (key.contains('aseo') || key.contains('limp')) {
    return Icons.cleaning_services_outlined;
  }
  if (key.contains('comput') || key.contains('tech')) {
    return Icons.computer_outlined;
  }
  if (key.contains('comerc')) return Icons.storefront_outlined;
  if (key.contains('gastr') || key.contains('comida')) {
    return Icons.restaurant_outlined;
  }
  if (key.contains('aloj') || key.contains('caban')) {
    return Icons.bed_outlined;
  }
  if (key.contains('turis')) return Icons.terrain_outlined;

  return Icons.home_repair_service_outlined;
}

Color _categoryTone(Category category) {
  final key = '${category.themeKey} ${category.slug}'.toLowerCase();

  if (key.contains('food') || key.contains('gastr')) {
    return RancoColors.primary;
  }
  if (key.contains('lake') || key.contains('tour')) {
    return RancoColors.lake;
  }
  if (key.contains('moss') || key.contains('garden')) {
    return RancoColors.moss;
  }
  if (key.contains('danger') || key.contains('emerg')) {
    return const Color(0xFFB4543F);
  }

  return RancoColors.forest;
}

class _HomeActionPanel extends StatelessWidget {
  const _HomeActionPanel({
    required this.businesses,
    required this.onExplore,
    required this.onPublish,
  });

  final AsyncValue businesses;
  final VoidCallback onExplore;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final count = businesses.maybeWhen(
      data: (items) => (items as List).length,
      orElse: () => 0,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: RancoDecoration.brandGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: RancoDecoration.liftShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .18),
                  ),
                ),
                child: const Icon(
                  Icons.explore_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Directorio local',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      count == 1
                          ? '1 prestador publicado'
                          : '$count prestadores publicados',
                      style: const TextStyle(
                        color: Color(0xFFDDEFE7),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onExplore,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Ver prestadores'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: RancoColors.pine,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: onPublish,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: .72),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Icon(Icons.add_business_outlined),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD7E4DE),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE4F1EB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: RancoColors.forest,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF31443B),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF71827A),
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
