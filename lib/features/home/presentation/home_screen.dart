import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../shared/models/category_preview.dart';
import '../../../theme/ranco_tokens.dart';
import '../application/home_demo_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(homeCategoriesProvider);
    final config = ref.watch(appConfigProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lago Ranco y Futrono', style: textTheme.labelLarge),
                const SizedBox(height: 8),
                Text(
                  'Conecta con servicios, comercios y experiencias locales.',
                  style: textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                Semantics(
                  textField: true,
                  label: 'Buscar en Ranco Conecta',
                  child: TextField(
                    readOnly: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: '¿Qué necesitas encontrar?',
                      suffixIcon: IconButton(
                        tooltip: 'Filtros',
                        onPressed: () {},
                        icon: const Icon(Icons.tune),
                      ),
                    ),
                  ),
                ),
                if (!config.hasSupabaseConfig) ...[
                  const SizedBox(height: 16),
                  Material(
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(RancoRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: colorScheme.onTertiaryContainer),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Modo desarrollo: Supabase no está configurado.',
                              style: TextStyle(
                                  color: colorScheme.onTertiaryContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverGrid.builder(
            itemCount: categories.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemBuilder: (context, index) {
              return _CategoryTile(category: categories[index]);
            },
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fundación Sprint 0', style: textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text(
                      'Esta base deja navegación, diseño, configuración y seguridad de datos listas para crecer sin acoplar la UI al backend.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final CategoryPreview category;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(RancoRadius.md),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(_iconFor(category.iconKey), color: colorScheme.primary),
              Text(
                category.name,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String key) {
    return switch (key) {
      'tools' => Icons.handyman_outlined,
      'store' => Icons.storefront_outlined,
      'restaurant' => Icons.restaurant_outlined,
      'lodging' => Icons.bed_outlined,
      _ => Icons.place_outlined,
    };
  }
}
