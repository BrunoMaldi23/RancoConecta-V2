import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/ranco_error_state.dart';
import '../../../theme/ranco_decoration.dart';
import '../../../theme/ranco_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../businesses/presentation/business_card.dart';
import '../application/favorite_providers.dart';
import '../../../core/widgets/ranco_app_bar.dart';

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

    final content = Container(
      decoration: const BoxDecoration(
        gradient: RancoDecoration.pageGlow,
      ),
      child: auth.when(
        data: (user) {
          if (user == null) {
            return const _GuestSaved();
          }

          final favorites = ref.watch(
            favoriteBusinessesProvider,
          );

          return favorites.when(
            data: (items) => ListView(
              padding: const EdgeInsets.fromLTRB(
                18,
                22,
                18,
                30,
              ),
              children: [
                const _SavedHeader(
                  title: 'Guardados',
                  subtitle: 'Tus prestadores favoritos, siempre a mano.',
                  icon: Icons.bookmark_border_rounded,
                ),
                const SizedBox(
                  height: 18,
                ),
                if (items.isEmpty) ...[
                  const _SavedInfoPanel(),
                  const SizedBox(
                    height: 14,
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      context.go(
                        '/explore',
                      );
                    },
                    icon: const Icon(
                      Icons.search_rounded,
                    ),
                    label: const Text(
                      'Explorar servicios',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: RancoColors.pine,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else ...[
                  Text(
                    '${items.length} ${items.length == 1 ? 'guardado' : 'guardados'}',
                    style: const TextStyle(
                      color: Color(
                        0xFF53675E,
                      ),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(
                    height: 12,
                  ),
                  for (var index = 0; index < items.length; index++) ...[
                    BusinessCard(
                      business: items[index],
                    ),
                    if (index != items.length - 1)
                      const SizedBox(
                        height: 14,
                      ),
                  ],
                ],
              ],
            ),
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (
              error,
              stackTrace,
            ) =>
                RancoErrorState(
              message: favoritesFailureMessage(
                error,
              ),
              onRetry: () {
                ref.invalidate(
                  favoriteBusinessesProvider,
                );
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (
          error,
          stackTrace,
        ) =>
            const RancoErrorState(
          message: 'No pudimos leer la sesión.',
        ),
      ),
    );

    if (!showBack) {
      return content;
    }

    return Scaffold(
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        18,
        22,
        18,
        30,
      ),
      children: [
        const _SavedHeader(
          title: 'Guardados',
          subtitle:
              'Guarda tus prestadores favoritos y vuelve a encontrarlos rápidamente.',
          icon: Icons.favorite_border_rounded,
        ),
        const SizedBox(
          height: 18,
        ),
        const _SavedInfoPanel(),
        const SizedBox(
          height: 14,
        ),
        FilledButton.icon(
          onPressed: () {
            context.go(
              '/sign-in',
            );
          },
          icon: const Icon(
            Icons.login_rounded,
          ),
          label: const Text(
            'Ingresar',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: RancoColors.pine,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(
          height: 8,
        ),
        TextButton.icon(
          onPressed: () {
            context.go(
              '/explore',
            );
          },
          icon: const Icon(
            Icons.search_rounded,
          ),
          label: const Text(
            'Seguir explorando',
          ),
        ),
      ],
    );
  }
}

class _SavedHeader extends StatelessWidget {
  const _SavedHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: RancoDecoration.warmGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5D8C7)),
        boxShadow: RancoDecoration.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .78),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: RancoColors.clay,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: RancoColors.pine,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: RancoColors.slate,
                    height: 1.35,
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

class _SavedInfoPanel extends StatelessWidget {
  const _SavedInfoPanel();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.all(
        18,
      ),
      decoration: RancoDecoration.card(radius: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEFE3),
              borderRadius: BorderRadius.circular(
                14,
              ),
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              color: RancoColors.ember,
            ),
          ),
          const SizedBox(
            width: 12,
          ),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tus favoritos vivirán aquí',
                  style: TextStyle(
                    color: Color(
                      0xFF30443B,
                    ),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                SizedBox(
                  height: 5,
                ),
                Text(
                  'Pulsa el corazón de un prestador para guardarlo y acceder rápidamente desde esta sección.',
                  style: TextStyle(
                    color: Color(
                      0xFF71827A,
                    ),
                    height: 1.4,
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
