import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/ranco_error_state.dart';
import '../../auth/application/auth_controller.dart';
import '../../businesses/presentation/business_card.dart';
import '../application/favorite_providers.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      data: (user) {
        if (user == null) {
          return const _GuestSaved();
        }

        final favorites = ref.watch(favoriteBusinessesProvider);
        return favorites.when(
          data: (items) => ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: [
              Text('Guardados', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Tus prestadores y negocios favoritos, siempre a mano.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 18),
              if (items.isEmpty) ...[
                const _SavedInfoPanel(),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => context.go('/explore'),
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('Explorar servicios'),
                ),
              ] else ...[
                for (var index = 0; index < items.length; index++) ...[
                  BusinessCard(business: items[index]),
                  if (index != items.length - 1) const SizedBox(height: 10),
                ],
              ],
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => RancoErrorState(
            message: favoritesFailureMessage(error),
            onRetry: () => ref.invalidate(favoriteBusinessesProvider),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          const RancoErrorState(message: 'No pudimos leer la sesión.'),
    );
  }
}

class _GuestSaved extends StatelessWidget {
  const _GuestSaved();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Text('Guardados', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Guarda tus prestadores favoritos y vuelve a encontrarlos rápidamente.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 18),
        const _SavedInfoPanel(),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => context.go('/sign-in'),
          icon: const Icon(Icons.login_rounded),
          label: const Text('Ingresar'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.go('/sign-up'),
          child: const Text('Crear cuenta'),
        ),
        const SizedBox(height: 18),
        TextButton.icon(
          onPressed: () => context.go('/explore'),
          icon: const Icon(Icons.search_rounded),
          label: const Text('Seguir explorando'),
        ),
      ],
    );
  }
}

class _SavedInfoPanel extends StatelessWidget {
  const _SavedInfoPanel();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.bookmark_border_rounded, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tus favoritos vivirán aquí',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 5),
                Text(
                  'Usa el botón de guardar en los perfiles que te interesen y tendrás acceso rápido desde esta sección.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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
