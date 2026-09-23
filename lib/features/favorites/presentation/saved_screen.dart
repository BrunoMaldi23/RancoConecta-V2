import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/ranco_app_bar.dart';
import '../../../core/widgets/ranco_error_state.dart';
import '../../../theme/ranco_colors.dart';
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
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptySavedState(
                        onExplore: () {
                          context.go('/explore');
                        },
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          18,
                          8,
                          18,
                          10,
                        ),
                        child: _SavedToolbar(
                          count: items.length,
                          onExplore: () {
                            context.go('/explore');
                          },
                        ),
                      ),
                    ),

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        18,
                        0,
                        18,
                        28,
                      ),
                      sliver: SliverList.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) {
                          return const SizedBox(height: 10);
                        },
                        itemBuilder: (context, index) {
                          return BusinessCard(
                            business: items[index],
                          );
                        },
                      ),
                    ),
                  ],
                ],
              );
            },

            loading: () {
              return const Center(
                child: CircularProgressIndicator(),
              );
            },

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

        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },

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

        SliverFillRemaining(
          hasScrollBody: false,
          child: _GuestSavedState(
            onSignIn: () {
              context.go('/sign-in');
            },
            onExplore: () {
              context.go('/explore');
            },
          ),
        ),
      ],
    );
  }
}

class _SavedHeader extends StatelessWidget {
  const _SavedHeader();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 760,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            18,
            16,
            18,
            8,
          ),
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
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
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
            42,
            24,
            90,
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
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 520,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            24,
            38,
            24,
            90,
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
                'Aún no tienes guardados',
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
                'Guarda negocios, alojamientos o servicios para volver a encontrarlos rápidamente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: RancoColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 20),

              FilledButton.icon(
                onPressed: onExplore,
                icon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                ),
                label: const Text(
                  'Explorar negocios',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(
                    190,
                    46,
                  ),
                  backgroundColor: RancoColors.forest,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    return Row(
      children: [
        Expanded(
          child: Text(
            '$count ${count == 1 ? 'guardado' : 'guardados'}',
            style: const TextStyle(
              color: RancoColors.forest,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        TextButton.icon(
          onPressed: onExplore,
          icon: const Icon(
            Icons.add_rounded,
            size: 17,
          ),
          label: const Text(
            'Explorar más',
          ),
          style: TextButton.styleFrom(
            foregroundColor: RancoColors.forest,
          ),
        ),
      ],
    );
  }
}