import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/ranco_empty_state.dart';
import '../../../core/widgets/ranco_error_state.dart';
import '../../../core/widgets/ranco_skeleton.dart';
import '../../../features/businesses/application/business_providers.dart';
import '../../../shared/models/category.dart';
import '../../../theme/ranco_colors.dart';
import '../../../theme/ranco_decoration.dart';
import '../application/category_providers.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  String _query = '';

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return ColoredBox(
      color: RancoColors.canvas,
      child: SafeArea(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                query: _query,
                onBack: _goBack,
                onQueryChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
                onClearSearch: _clearSearch,
              ),
            ),
            categories.when(
              data: (items) {
                final filtered = _filterCategories(
                  items,
                  _query,
                );

                if (items.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        24,
                        20,
                        90,
                      ),
                      child: Center(
                        child: RancoEmptyState(
                          icon: Icons.grid_view_rounded,
                          title: 'Aún no hay categorías',
                          message:
                              'Cuando las categorías estén activas aparecerán aquí.',
                        ),
                      ),
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        24,
                        20,
                        90,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const RancoEmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'No encontramos esa categoría',
                              message:
                                  'Prueba escribiendo otro nombre o limpia la búsqueda.',
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _clearSearch,
                              icon: const Icon(
                                Icons.restart_alt_rounded,
                              ),
                              label: const Text(
                                'Ver todas las categorías',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _ResultCount(
                        total: items.length,
                        filtered: filtered.length,
                        query: _query,
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        8,
                        20,
                        28,
                      ),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.crossAxisExtent;

                          final columns = _columnCount(width);

                          return SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              mainAxisExtent: 64,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final category = filtered[index];

                                return _CategoryTile(
                                  category: category,
                                  onTap: () {
                                    _openCategory(category);
                                  },
                                );
                              },
                              childCount: filtered.length,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      0,
                    ),
                    child: Column(
                      children: [
                        RancoSkeleton(
                          height: 64,
                        ),
                        SizedBox(height: 8),
                        RancoSkeleton(
                          height: 64,
                        ),
                        SizedBox(height: 8),
                        RancoSkeleton(
                          height: 64,
                        ),
                        SizedBox(height: 8),
                        RancoSkeleton(
                          height: 64,
                        ),
                      ],
                    ),
                  ),
                );
              },
              error: (error, stackTrace) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      20,
                      20,
                      90,
                    ),
                    child: Center(
                      child: RancoErrorState(
                        message: failureMessage(
                          error,
                          'No pudimos cargar las categorías.',
                        ),
                        onRetry: () {
                          ref.invalidate(categoriesProvider);
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  int _columnCount(double width) {
    if (width >= 1180) {
      return 4;
    }

    if (width >= 860) {
      return 3;
    }

    if (width >= 600) {
      return 2;
    }

    // En móvil usamos una sola columna.
    // Evita partir nombres como:
    // Computación, Electricidad, Carpintería, etc.
    return 1;
  }

  List<Category> _filterCategories(
    List<Category> categories,
    String query,
  ) {
    final normalizedQuery = _normalize(query);

    if (normalizedQuery.isEmpty) {
      return categories;
    }

    return categories.where((category) {
      final haystack = _normalize(
        '${category.name} '
        '${category.slug} '
        '${category.iconKey}',
      );

      return haystack.contains(normalizedQuery);
    }).toList();
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();

    setState(() {
      _query = '';
    });
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }

    context.go('/');
  }

  void _openCategory(Category category) {
    // Abrir una categoría desde esta pantalla representa
    // una nueva exploración.
    //
    // Conservamos selectedLocationProvider.
    ref.read(businessSearchQueryProvider.notifier).state = '';

    ref.read(selectedCategoryIdProvider.notifier).state = category.id;

    ref.read(verifiedOnlyProvider.notifier).state = false;
    ref.read(featuredOnlyProvider.notifier).state = false;
    ref.read(openNowOnlyProvider.notifier).state = false;

    context.go('/explore');
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.searchController,
    required this.searchFocusNode,
    required this.query,
    required this.onBack,
    required this.onQueryChanged,
    required this.onClearSearch,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final String query;

  final VoidCallback onBack;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        14,
        20,
        4,
      ),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 920,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _BackButton(
                    onTap: onBack,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Todas las categorías',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: RancoColors.pine,
                                fontWeight: FontWeight.w800,
                                height: 1.05,
                              ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Elige una categoría para explorar negocios y servicios.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: RancoColors.textSecondary,
                            height: 1.3,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: searchController,
                focusNode: searchFocusNode,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                enableSuggestions: true,
                onChanged: onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Buscar una categoría',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: RancoColors.primary,
                  ),
                  suffixIcon: query.trim().isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          onPressed: onClearSearch,
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 19,
                          ),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: RancoDecoration.softBorder,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: RancoColors.primary,
                      width: 1.4,
                    ),
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

class _ResultCount extends StatelessWidget {
  const _ResultCount({
    required this.total,
    required this.filtered,
    required this.query,
  });

  final int total;
  final int filtered;
  final String query;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.trim().isNotEmpty;

    final text = hasQuery
        ? '$filtered ${filtered == 1 ? 'resultado' : 'resultados'}'
        : '$total ${total == 1 ? 'categoría' : 'categorías'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        14,
        20,
        4,
      ),
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 920,
          ),
          child: Row(
            children: [
              Text(
                text,
                style: const TextStyle(
                  color: RancoColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (hasQuery) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'para “${query.trim()}”',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RancoColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: RancoDecoration.softBorder,
            ),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 21,
            color: RancoColors.forest,
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
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
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: RancoDecoration.softBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tone.withValues(
                    alpha: .10,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  _categoryIcon(category),
                  size: 20,
                  color: tone,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RancoColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFF9AA8A2),
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

  if (key.contains('emerg')) {
    return Icons.emergency_outlined;
  }

  if (key.contains('mecan') || key.contains('auto')) {
    return Icons.build_outlined;
  }

  if (key.contains('flete') || key.contains('trans')) {
    return Icons.local_shipping_outlined;
  }

  if (key.contains('jardin')) {
    return Icons.yard_outlined;
  }

  if (key.contains('aseo') || key.contains('limp')) {
    return Icons.cleaning_services_outlined;
  }

  if (key.contains('comput') || key.contains('tech')) {
    return Icons.computer_outlined;
  }

  if (key.contains('comerc')) {
    return Icons.storefront_outlined;
  }

  if (key.contains('gastr') || key.contains('comida')) {
    return Icons.restaurant_outlined;
  }

  if (key.contains('aloj') || key.contains('caban')) {
    return Icons.bed_outlined;
  }

  if (key.contains('turis')) {
    return Icons.terrain_outlined;
  }

  if (key.contains('electric')) {
    return Icons.electrical_services_outlined;
  }

  if (key.contains('gasfit')) {
    return Icons.plumbing_outlined;
  }

  if (key.contains('carpint')) {
    return Icons.carpenter_outlined;
  }

  if (key.contains('pintur')) {
    return Icons.format_paint_outlined;
  }

  if (key.contains('sold')) {
    return Icons.hardware_outlined;
  }

  if (key.contains('calef')) {
    return Icons.local_fire_department_outlined;
  }

  if (key.contains('techumbr') || key.contains('techo')) {
    return Icons.roofing_outlined;
  }

  if (key.contains('alban') || key.contains('constr')) {
    return Icons.construction_outlined;
  }

  if (key.contains('cerraj')) {
    return Icons.key_outlined;
  }

  if (key.contains('solar')) {
    return Icons.solar_power_outlined;
  }

  return Icons.home_repair_service_outlined;
}

Color _categoryTone(Category category) {
  final key =
      '${category.themeKey} ${category.slug} ${category.name}'.toLowerCase();

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
