import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/ranco_states.dart';
import '../../../core/widgets/ranco_app_bar.dart';
import '../../../core/layout/ranco_responsive.dart';
import '../../../core/widgets/ranco_error_state.dart';
import '../../../core/widgets/ranco_page_empty_state.dart';
import '../../../core/widgets/ranco_site_footer.dart';
import '../../../theme/ranco_colors.dart';
import '../../../theme/ranco_tokens.dart';
import '../../auth/application/auth_controller.dart';
import '../../businesses/presentation/business_card.dart';
import '../application/favorite_providers.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({
    this.showBack = false,
    super.key,
  });

  final bool showBack;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final auth = ref.watch(authStateProvider);

    final content = ColoredBox(
      color: RancoColors.canvas,
      child: auth.when(
        data: (user) {
          if (user == null) {
            return const _GuestSaved();
          }

          final favorites = ref.watch(
            favoriteBusinessesProvider,
          );

          return favorites.when(
            data: (items) {
              return CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(
                    child: SafeArea(
                      bottom: false,
                      child: _SavedHeader(),
                    ),
                  ),
                  if (items.isEmpty)
                    SliverToBoxAdapter(
                      child: _EmptySavedState(
                        onExplore: () {
                          context.go('/explore');
                        },
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: RancoContentContainer(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: RancoSpacing.md,
                            bottom: RancoSpacing.lg,
                          ),
                          child: _SavedToolbar(
                            count: items.length,
                            onExplore: () {
                              context.go('/explore');
                            },
                          ),
                        ),
                      ),
                    ),
                    // Grilla de tarjetas compartidas: 1 columna en móvil,
                    // 2–4 en tablet/desktop según el ancho real.
                    SliverToBoxAdapter(
                      child: RancoContentContainer(
                        child: RancoResponsiveGrid(
                          equalHeightRows: true,
                          minItemWidth: 260,
                          spacing: RancoSpacing.lg,
                          runSpacing: RancoSpacing.lg,
                          children: [
                            for (final business in items)
                              BusinessCard(
                                business: business,
                                variant: BusinessCardVariant.saved,
                                fillHeight: true,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const RancoFooterSliver(),
                ],
              );
            },
            loading: () => const _SavedSkeleton(),
            error: (error, stackTrace) {
              return RancoErrorState(
                message: favoritesFailureMessage(
                  error,
                ),
                onRetry: () {
                  ref.invalidate(
                    favoriteBusinessesProvider,
                  );
                },
              );
            },
          );
        },
        loading: () => const _SavedSkeleton(),
        error: (error, stackTrace) {
          return const RancoErrorState(
            message: 'No pudimos leer la sesión.',
          );
        },
      ),
    );

    if (!showBack) {
      return content;
    }

    return Scaffold(
      backgroundColor: RancoColors.canvas,
      appBar: const RancoAppBar(
        title: 'Guardados',
        fallbackRoute: '/account',
      ),
      body: content,
    );
  }
}

class _GuestSaved extends StatelessWidget {
  const _GuestSaved();

  @override
  Widget build(
    BuildContext context,
  ) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: SafeArea(
            bottom: false,
            child: _SavedHeader(),
          ),
        ),
        SliverToBoxAdapter(
          child: _GuestSavedState(
            onSignIn: () {
              context.go('/sign-in');
            },
            onExplore: () {
              context.go('/explore');
            },
          ),
        ),
        const RancoFooterSliver(),
      ],
    );
  }
}

class _SavedHeader extends StatelessWidget {
  const _SavedHeader();

  @override
  Widget build(BuildContext context) {
    return RancoContentContainer(
      child: Padding(
        padding: const EdgeInsets.only(top: 20, bottom: RancoSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE5F1EC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.bookmark_border_rounded,
                size: 21,
                color: RancoColors.forest,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Guardados',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: RancoColors.forest,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          height: 1.0,
                        ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Tus negocios y lugares favoritos, siempre a mano.',
                    style: TextStyle(
                      color: RancoColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestSavedState extends StatelessWidget {
  const _GuestSavedState({
    required this.onSignIn,
    required this.onExplore,
  });

  final VoidCallback onSignIn;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 520,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            24,
            40,
            24,
            40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF3E8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.favorite_border_rounded,
                  size: 25,
                  color: RancoColors.forest,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Inicia sesión para guardar favoritos',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: RancoColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Guarda negocios, alojamientos y servicios para encontrarlos fácilmente más tarde.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: RancoColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 220,
                child: FilledButton.icon(
                  onPressed: onSignIn,
                  icon: const Icon(
                    Icons.login_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'Iniciar sesión',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: RancoColors.forest,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: onExplore,
                icon: const Icon(
                  Icons.search_rounded,
                  size: 17,
                ),
                label: const Text(
                  'Seguir explorando',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySavedState extends StatelessWidget {
  const _EmptySavedState({
    required this.onExplore,
  });

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return RancoPageEmptyState(
      icon: Icons.favorite_border_rounded,
      title: 'Aún no tienes guardados',
      message: 'Guarda negocios, alojamientos o servicios para volver a '
          'encontrarlos rápidamente.',
      actionLabel: 'Explorar negocios',
      onAction: onExplore,
    );
  }
}

class _SavedToolbar extends StatelessWidget {
  const _SavedToolbar({
    required this.count,
    required this.onExplore,
  });

  final int count;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    // Contador a la izquierda, acción secundaria a la derecha y un divisor
    // que separa la barra de la grilla.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$count ${count == 1 ? 'guardado' : 'guardados'}',
                style: const TextStyle(
                  color: RancoColors.textSecondary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onExplore,
              icon: const Icon(
                Icons.add_rounded,
                size: 17,
              ),
              label: const Text(
                'Explorar más',
              ),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: RancoSpacing.md),
        const Divider(height: 1),
      ],
    );
  }
}

/// Carga: grilla de tarjetas esqueleto con la misma estructura del
/// resultado (sin spinner ni salto de layout).
class _SavedSkeleton extends StatelessWidget {
  const _SavedSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 88),
      children: [
        RancoContentContainer(
          child: RancoResponsiveGrid(
            minItemWidth: 260,
            spacing: RancoSpacing.lg,
            runSpacing: RancoSpacing.lg,
            children: [
              for (var i = 0; i < 4; i++) const RancoCardSkeleton(),
            ],
          ),
        ),
      ],
    );
  }
}
