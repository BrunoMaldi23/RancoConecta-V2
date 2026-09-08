import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/ranco_error_state.dart';
import '../../../theme/ranco_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../businesses/presentation/business_card.dart';
import '../application/favorite_providers.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final auth = ref.watch(authStateProvider);

    return ColoredBox(
      color: const Color(
        0xFFEAF4F0,
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
                const Text(
                  'Guardados',
                  style: TextStyle(
                    color: RancoColors.forest,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                const Text(
                  'Tus prestadores favoritos, siempre a mano.',
                  style: TextStyle(
                    color: Color(
                      0xFF71827A,
                    ),
                  ),
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
                      backgroundColor: RancoColors.forest,
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
          message: 'No pudimos leer la sesiÃ³n.',
        ),
      ),
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
        const Text(
          'Guardados',
          style: TextStyle(
            color: RancoColors.forest,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(
          height: 4,
        ),
        const Text(
          'Guarda tus prestadores favoritos y vuelve a encontrarlos rÃ¡pidamente.',
          style: TextStyle(
            color: Color(
              0xFF71827A,
            ),
          ),
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
            backgroundColor: RancoColors.forest,
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: const Color(
            0xFFD5E2DC,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(
                0xFFE4F1EB,
              ),
              borderRadius: BorderRadius.circular(
                14,
              ),
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              color: RancoColors.forest,
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
                  'Tus favoritos vivirÃ¡n aquÃ­',
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
                  'Pulsa el corazÃ³n de un prestador para guardarlo y acceder rÃ¡pidamente desde esta secciÃ³n.',
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
