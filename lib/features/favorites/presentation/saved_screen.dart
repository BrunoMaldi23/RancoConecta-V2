import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/ranco_empty_state.dart';
import '../../../core/widgets/ranco_error_state.dart';
import '../../../theme/ranco_colors.dart';
import '../../../theme/ranco_decoration.dart';
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
                  RancoEmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: 'Todavía no tienes guardados',
                    message:
                        'Pulsa el corazón de un prestador para volver a encontrarlo rápidamente.',
                    actionLabel: 'Explorar prestadores',
                    onAction: () {
                      context.go('/explore');
                    },
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
        RancoEmptyState(
          icon: Icons.favorite_border_rounded,
          title: 'Tus favoritos vivirán aquí',
          message:
              'Inicia sesión para guardar prestadores y acceder a ellos desde cualquier dispositivo.',
          actionLabel: 'Ingresar',
          onAction: () {
            context.go('/sign-in');
          },
          secondaryLabel: 'Seguir explorando',
          onSecondaryAction: () {
            context.go('/explore');
          },
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
        gradient: RancoDecoration.softGreenGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: RancoDecoration.softBorder),
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
              color: RancoColors.primaryDark,
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
