import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/ranco_error_state.dart';
import '../../../core/widgets/ranco_skeleton.dart';
import '../../../features/businesses/application/business_providers.dart';
import '../../../features/businesses/presentation/business_card.dart';
import '../../../features/categories/application/category_providers.dart';
import '../../../features/locations/application/location_providers.dart';
import '../../../shared/models/location.dart';
import '../../../theme/ranco_colors.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  late final TextEditingController _searchController;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController(
      text: ref.read(businessSearchQueryProvider),
    );
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
    final businesses = ref.watch(publishedBusinessesProvider);

    final selectedCategoryId = ref.watch(selectedCategoryIdProvider);
    final selectedLocation = ref.watch(selectedLocationProvider);

    final verified = ref.watch(verifiedOnlyProvider);
    final featured = ref.watch(featuredOnlyProvider);
    final openNow = ref.watch(openNowOnlyProvider);

    final searchQuery = ref.watch(businessSearchQueryProvider);

    ref.listen<String>(
      businessSearchQueryProvider,
      (previous, next) {
        if (_searchController.text == next) {
          return;
        }

        _searchController.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(
            offset: next.length,
          ),
        );
      },
    );

    final selectedCategoryName = categories.maybeWhen(
      data: (items) {
        for (final category in items) {
          if (category.id == selectedCategoryId) {
            return category.name;
          }
        }

        return null;
      },
      orElse: () => null,
    );

    final advancedFilterCount = [
      verified,
      featured,
      openNow,
    ].where((value) => value).length;

    final hasAnyFilter = selectedLocation != null ||
        selectedCategoryId != null ||
        advancedFilterCount > 0 ||
        searchQuery.trim().isNotEmpty;

    return ColoredBox(
      color: RancoColors.canvas,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 780,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      14,
                      18,
                      6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Explorar',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: RancoColors.forest,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                height: 1.02,
                              ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Encuentra negocios y servicios cerca de ti.',
                          style: TextStyle(
                            color: RancoColors.textSecondary,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _CompactSearchBar(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: (value) {
                            ref
                                .read(
                                  businessSearchQueryProvider.notifier,
                                )
                                .state = value.trimLeft();

                            setState(() {});
                          },
                          onSearch: _submitSearch,
                          onClear: _clearSearch,
                        ),
                        const SizedBox(height: 10),
                        _FilterStrip(
                          location: selectedLocation,
                          categoryName: selectedCategoryName,
                          advancedFilterCount: advancedFilterCount,
                          onLocationTap: () {
                            _showLocationPicker(context);
                          },
                          onLocationClear: selectedLocation == null
                              ? null
                              : () {
                                  ref
                                      .read(
                                        selectedLocationProvider.notifier,
                                      )
                                      .state = null;
                                },
                          onCategoryTap: () {
                            context.push('/categories');
                          },
                          onCategoryClear: selectedCategoryId == null
                              ? null
                              : () {
                                  ref
                                      .read(
                                        selectedCategoryIdProvider.notifier,
                                      )
                                      .state = null;
                                },
                          onFiltersTap: () {
                            _showFilters(context);
                          },
                        ),
                        const SizedBox(height: 10),
                        businesses.maybeWhen(
                          data: (items) {
                            return _ResultsHeader(
                              count: items.length,
                              locationName: selectedLocation?.name,
                            );
                          },
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          businesses.when(
            data: (items) {
              if (items.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 780,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          32,
                          20,
                          90,
                        ),
                        child: _CompactEmptyState(
                          query: searchQuery,
                          hasFilters: hasAnyFilter,
                          onClear: _clearAll,
                          onCategories: () {
                            context.push('/categories');
                          },
                        ),
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  2,
                  18,
                  30,
                ),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;

                    if (width < 980) {
                      return SliverList.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) {
                          return const SizedBox(height: 10);
                        },
                        itemBuilder: (context, index) {
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 740,
                              ),
                              child: BusinessCard(
                                business: items[index],
                              ),
                            ),
                          );
                        },
                      );
                    }

                    return SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.84,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return BusinessCard(
                            business: items[index],
                          );
                        },
                        childCount: items.length,
                      ),
                    );
                  },
                ),
              );
            },
            loading: () {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    6,
                    18,
                    0,
                  ),
                  child: Column(
                    children: [
                      RancoSkeleton(
                        height: 190,
                      ),
                      SizedBox(height: 10),
                      RancoSkeleton(
                        height: 190,
                      ),
                    ],
                  ),
                ),
              );
            },
            error: (error, stackTrace) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: RancoErrorState(
                  message: businessFailureMessage(error),
                  onRetry: () {
                    ref.invalidate(
                      publishedBusinessesProvider,
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _submitSearch() {
    final query = _searchController.text.trim();

    ref.read(businessSearchQueryProvider.notifier).state = query;

    _searchFocusNode.unfocus();

    setState(() {});
  }

  void _clearSearch() {
    _searchController.clear();

    ref.read(businessSearchQueryProvider.notifier).state = '';

    _searchFocusNode.unfocus();

    setState(() {});
  }

  Future<void> _showLocationPicker(
    BuildContext context,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return const _LocationPickerSheet();
      },
    );
  }

  Future<void> _showFilters(
    BuildContext context,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return const _FiltersSheet();
      },
    );
  }

  void _clearAll() {
    _searchController.clear();

    ref.read(businessSearchQueryProvider.notifier).state = '';

    clearBusinessFilters(ref);

    _searchFocusNode.unfocus();

    setState(() {});
  }
}

class _CompactSearchBar extends StatelessWidget {
  const _CompactSearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSearch,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            enableSuggestions: true,
            onChanged: onChanged,
            onSubmitted: (_) {
              onSearch();
            },
            decoration: InputDecoration(
              hintText: 'Buscar negocio o servicio',
              hintStyle: const TextStyle(
                fontSize: 13.5,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 19,
                color: RancoColors.primary,
              ),
              suffixIcon: controller.text.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      onPressed: onClear,
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                      ),
                    ),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: Color(0xFFD1E0D9),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: RancoColors.primary,
                  width: 1.3,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 46,
          height: 46,
          child: FilledButton(
            onPressed: onSearch,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: RancoColors.forest,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: const Icon(
              Icons.search_rounded,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.location,
    required this.categoryName,
    required this.advancedFilterCount,
    required this.onLocationTap,
    required this.onLocationClear,
    required this.onCategoryTap,
    required this.onCategoryClear,
    required this.onFiltersTap,
  });

  final Location? location;
  final String? categoryName;
  final int advancedFilterCount;

  final VoidCallback onLocationTap;
  final VoidCallback? onLocationClear;

  final VoidCallback onCategoryTap;
  final VoidCallback? onCategoryClear;

  final VoidCallback onFiltersTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterPill(
            icon: Icons.location_on_outlined,
            label: location?.name ?? 'Ubicación',
            selected: location != null,
            onTap: onLocationTap,
            onClear: onLocationClear,
          ),
          const SizedBox(width: 7),
          _FilterPill(
            icon: Icons.category_outlined,
            label: categoryName ?? 'Categoría',
            selected: categoryName != null,
            onTap: onCategoryTap,
            onClear: onCategoryClear,
          ),
          const SizedBox(width: 7),
          _FilterPill(
            icon: Icons.tune_rounded,
            label: advancedFilterCount == 0
                ? 'Filtros'
                : 'Filtros · $advancedFilterCount',
            selected: advancedFilterCount > 0,
            onTap: onFiltersTap,
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE7F2ED) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 84,
          ),
          padding: EdgeInsets.only(
            left: 11,
            right: onClear == null ? 11 : 5,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  selected ? const Color(0xFFBDD8CB) : const Color(0xFFD4E2DC),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: RancoColors.forest,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 120,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        selected ? RancoColors.forest : RancoColors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onClear != null) ...[
                const SizedBox(width: 2),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClear,
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: RancoColors.forest,
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

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.count,
    this.locationName,
  });

  final int count;
  final String? locationName;

  @override
  Widget build(BuildContext context) {
    final location = locationName?.trim();

    return Row(
      children: [
        Text(
          '$count ${count == 1 ? 'resultado' : 'resultados'}',
          style: const TextStyle(
            color: RancoColors.forest,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (location != null && location.isNotEmpty) ...[
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              'en $location',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: RancoColors.textSecondary,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CompactEmptyState extends StatelessWidget {
  const _CompactEmptyState({
    required this.query,
    required this.hasFilters,
    required this.onClear,
    required this.onCategories,
  });

  final String query;
  final bool hasFilters;

  final VoidCallback onClear;
  final VoidCallback onCategories;

  @override
  Widget build(BuildContext context) {
    final cleaned = query.trim();

    final message = cleaned.isNotEmpty
        ? 'No encontramos resultados para “$cleaned”. '
            'Prueba con otra búsqueda o amplía los filtros.'
        : hasFilters
            ? 'No hay coincidencias con los filtros actuales.'
            : 'Todavía no hay negocios disponibles en esta zona.';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFE2F1EB),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.search_off_rounded,
            size: 22,
            color: RancoColors.forest,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'No encontramos resultados',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: RancoColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: RancoColors.textSecondary,
            fontSize: 13,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(
                Icons.restart_alt_rounded,
                size: 17,
              ),
              label: const Text(
                'Limpiar',
              ),
            ),
            TextButton.icon(
              onPressed: onCategories,
              icon: const Icon(
                Icons.category_outlined,
                size: 17,
              ),
              label: const Text(
                'Categorías',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LocationPickerSheet extends ConsumerWidget {
  const _LocationPickerSheet();

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final locations = ref.watch(locationsProvider);
    final selected = ref.watch(selectedLocationProvider);

    return _BottomSheetFrame(
      title: 'Ubicación',
      subtitle: 'Elige dónde quieres buscar.',
      child: locations.when(
        data: (items) {
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              16,
              4,
              16,
              18,
            ),
            children: [
              _LocationOption(
                label: 'Todas las localidades',
                selected: selected == null,
                onTap: () {
                  ref
                      .read(
                        selectedLocationProvider.notifier,
                      )
                      .state = null;

                  Navigator.of(context).pop();
                },
              ),
              for (final location in items)
                _LocationOption(
                  label: location.name,
                  selected: selected?.id == location.id,
                  onTap: () {
                    ref
                        .read(
                          selectedLocationProvider.notifier,
                        )
                        .state = location;

                    Navigator.of(context).pop();
                  },
                ),
            ],
          );
        },
        loading: () {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
        error: (_, __) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No pudimos cargar las localidades.',
            ),
          );
        },
      ),
    );
  }
}

class _LocationOption extends StatelessWidget {
  const _LocationOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 6,
      ),
      child: Material(
        color: selected ? const Color(0xFFE7F2ED) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: 46,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFD5E3DD),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: RancoColors.forest,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: RancoColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_rounded,
                    size: 19,
                    color: RancoColors.forest,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FiltersSheet extends ConsumerStatefulWidget {
  const _FiltersSheet();

  @override
  ConsumerState<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<_FiltersSheet> {
  bool _verified = false;
  bool _featured = false;
  bool _openNow = false;

  @override
  void initState() {
    super.initState();

    _verified = ref.read(verifiedOnlyProvider);
    _featured = ref.read(featuredOnlyProvider);
    _openNow = ref.read(openNowOnlyProvider);
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheetFrame(
      title: 'Filtros',
      subtitle: 'Ajusta rápidamente los resultados.',
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          18,
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _reset,
                child: const Text(
                  'Limpiar',
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _apply,
                style: FilledButton.styleFrom(
                  backgroundColor: RancoColors.forest,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Aplicar',
                ),
              ),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          4,
          16,
          6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PreferenceRow(
              icon: Icons.verified_outlined,
              title: 'Verificados',
              subtitle: 'Negocios y prestadores verificados.',
              value: _verified,
              onChanged: (value) {
                setState(() {
                  _verified = value;
                });
              },
            ),
            const SizedBox(height: 7),
            _PreferenceRow(
              icon: Icons.star_outline_rounded,
              title: 'Destacados',
              subtitle: 'Perfiles con mayor visibilidad.',
              value: _featured,
              onChanged: (value) {
                setState(() {
                  _featured = value;
                });
              },
            ),
            const SizedBox(height: 7),
            _PreferenceRow(
              icon: Icons.access_time_rounded,
              title: 'Disponibles ahora',
              subtitle: 'Según el horario informado.',
              value: _openNow,
              onChanged: (value) {
                setState(() {
                  _openNow = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _reset() {
    setState(() {
      _verified = false;
      _featured = false;
      _openNow = false;
    });
  }

  void _apply() {
    ref.read(verifiedOnlyProvider.notifier).state = _verified;
    ref.read(featuredOnlyProvider.notifier).state = _featured;
    ref.read(openNowOnlyProvider.notifier).state = _openNow;

    Navigator.of(context).pop();
  }
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: () {
          onChanged(!value);
        },
        borderRadius: BorderRadius.circular(13),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 60,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: const Color(0xFFD4E2DC),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F2ED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: RancoColors.forest,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: RancoColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RancoColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: value,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomSheetFrame extends StatelessWidget {
  const _BottomSheetFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 520,
            maxHeight: 650,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 9),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD6E2DD),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  14,
                  8,
                  8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: RancoColors.forest,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: RancoColors.textSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: child,
              ),
              if (footer != null) footer!,
            ],
          ),
        ),
      ),
    );
  }
}
