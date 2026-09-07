import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/ranco_empty_state.dart';
import '../../../core/widgets/ranco_error_state.dart';
import '../../../core/widgets/ranco_search_field.dart';
import '../../../core/widgets/ranco_skeleton.dart';
import '../../../features/businesses/application/business_providers.dart';
import '../../../features/businesses/presentation/business_card.dart';
import '../../../features/categories/application/category_providers.dart';
import '../../../features/locations/application/location_providers.dart';
import '../../../features/locations/presentation/location_selector.dart';
import '../../../shared/models/location.dart';
import '../../../theme/ranco_colors.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({
    super.key,
  });

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    final businesses = ref.watch(publishedBusinessesProvider);

    final selectedCategory = ref.watch(selectedCategoryIdProvider);

    final selectedLocation = ref.watch(selectedLocationProvider);

    final verified = ref.watch(verifiedOnlyProvider);

    final featured = ref.watch(featuredOnlyProvider);

    final openNow = ref.watch(openNowOnlyProvider);

    final activeFilters = [
      selectedLocation != null,
      selectedCategory != null,
      verified,
      featured,
      openNow,
    ].where((value) => value).length;

    return ColoredBox(
      color: const Color(0xFFEAF4F0),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explorar',
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: RancoColors.forest,
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Encuentra servicios, comercios y prestadores de tu zona.',
                      style: TextStyle(
                        color: Color(0xFF71827A),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    RancoSearchField(
                      controller: _searchController,
                      hintText: '¿Qué estás buscando?',
                      onChanged: (value) {
                        ref
                            .read(
                              businessSearchQueryProvider.notifier,
                            )
                            .state = value;
                      },
                    ),
                    const SizedBox(height: 10),
                    const LocationSelector(
                      compact: true,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Rubros',
                            style: TextStyle(
                              color: RancoColors.forest,
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        _FilterButton(
                          count: activeFilters,
                          onTap: () {
                            _showFilters(context);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    categories.when(
                      data: (items) {
                        return SizedBox(
                          height: 42,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: items.length + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return _CategoryChip(
                                  label: 'Todos',
                                  selected: selectedCategory == null,
                                  onTap: () {
                                    ref
                                        .read(
                                          selectedCategoryIdProvider.notifier,
                                        )
                                        .state = null;
                                  },
                                );
                              }

                              final category = items[index - 1];

                              return _CategoryChip(
                                label: category.name,
                                selected: selectedCategory == category.id,
                                onTap: () {
                                  ref
                                      .read(
                                        selectedCategoryIdProvider.notifier,
                                      )
                                      .state = category.id;
                                },
                              );
                            },
                          ),
                        );
                      },
                      loading: () => const SizedBox(
                        height: 42,
                        child: Center(
                          child: LinearProgressIndicator(
                            minHeight: 2,
                          ),
                        ),
                      ),
                      error: (error, stackTrace) => Text(
                        failureMessage(
                          error,
                          'No pudimos cargar las categorías.',
                        ),
                      ),
                    ),
                    if (activeFilters > 0) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          if (selectedLocation != null)
                            _ActiveFilterChip(
                              label: selectedLocation.name,
                              onRemove: () {
                                ref
                                    .read(
                                      selectedLocationProvider.notifier,
                                    )
                                    .state = null;
                              },
                            ),
                          if (verified)
                            _ActiveFilterChip(
                              label: 'Verificados',
                              onRemove: () {
                                ref
                                    .read(
                                      verifiedOnlyProvider.notifier,
                                    )
                                    .state = false;
                              },
                            ),
                          if (featured)
                            _ActiveFilterChip(
                              label: 'Destacados',
                              onRemove: () {
                                ref
                                    .read(
                                      featuredOnlyProvider.notifier,
                                    )
                                    .state = false;
                              },
                            ),
                          if (openNow)
                            _ActiveFilterChip(
                              label: 'Disponibles',
                              onRemove: () {
                                ref
                                    .read(
                                      openNowOnlyProvider.notifier,
                                    )
                                    .state = false;
                              },
                            ),
                          TextButton(
                            onPressed: _clearAll,
                            child: const Text(
                              'Limpiar',
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    businesses.maybeWhen(
                      data: (items) => Text(
                        items.isEmpty
                            ? 'Sin resultados'
                            : '${items.length} ${items.length == 1 ? 'resultado' : 'resultados'}',
                        style: const TextStyle(
                          color: Color(0xFF596D64),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          businesses.when(
            data: (items) {
              if (items.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        child: RancoEmptyState(
                          compact: true,
                          icon: Icons.search_off_rounded,
                          title: 'No encontramos prestadores',
                          message:
                              'Prueba cambiando la localidad, el rubro o los filtros.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _clearAll,
                        icon: const Icon(
                          Icons.restart_alt_rounded,
                        ),
                        label: const Text(
                          'Limpiar filtros',
                        ),
                      ),
                      const SizedBox(height: 70),
                    ],
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  30,
                ),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => BusinessCard(
                    business: items[index],
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  0,
                ),
                child: Column(
                  children: [
                    RancoSkeleton(height: 190),
                    SizedBox(height: 12),
                    RancoSkeleton(height: 190),
                  ],
                ),
              ),
            ),
            error: (error, stackTrace) => SliverFillRemaining(
              hasScrollBody: false,
              child: RancoErrorState(
                message: businessFailureMessage(error),
                onRetry: () {
                  ref.invalidate(
                    publishedBusinessesProvider,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilters(
    BuildContext context,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FiltersSheet(),
    );
  }

  void _clearAll() {
    _searchController.clear();

    ref
        .read(
          businessSearchQueryProvider.notifier,
        )
        .state = '';

    clearBusinessFilters(ref);

    setState(() {});
  }
}

class _FiltersSheet extends ConsumerStatefulWidget {
  const _FiltersSheet();

  @override
  ConsumerState<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<_FiltersSheet> {
  String? _locationId;
  String? _categoryId;

  bool _verified = false;
  bool _featured = false;
  bool _openNow = false;

  @override
  void initState() {
    super.initState();

    _locationId = ref.read(selectedLocationProvider)?.id;

    _categoryId = ref.read(selectedCategoryIdProvider);

    _verified = ref.read(verifiedOnlyProvider);

    _featured = ref.read(featuredOnlyProvider);

    _openNow = ref.read(openNowOnlyProvider);
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(locationsProvider);

    final categories = ref.watch(categoriesProvider);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 520,
          maxHeight: 720,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD7E2DE),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                16,
                12,
                10,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filtros',
                          style: TextStyle(
                            color: RancoColors.forest,
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Ajusta los resultados a lo que necesitas.',
                          style: TextStyle(
                            color: Color(0xFF71827A),
                          ),
                        ),
                      ],
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
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FilterTitle(
                      title: 'Localidad',
                    ),
                    const SizedBox(height: 8),
                    locations.when(
                      data: (items) => DropdownButtonFormField<String>(
                        initialValue: _locationId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(
                            Icons.location_on_outlined,
                          ),
                          hintText: 'Todas las localidades',
                        ),
                        items: [
                          for (final location in items)
                            DropdownMenuItem<String>(
                              value: location.id,
                              child: Text(
                                location.name,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _locationId = value;
                          });
                        },
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text(
                        'No pudimos cargar localidades.',
                      ),
                    ),
                    if (_locationId != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _locationId = null;
                            });
                          },
                          child: const Text(
                            'Todas las localidades',
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    const _FilterTitle(
                      title: 'Rubro',
                    ),
                    const SizedBox(height: 8),
                    categories.when(
                      data: (items) => DropdownButtonFormField<String>(
                        initialValue: _categoryId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(
                            Icons.category_outlined,
                          ),
                          hintText: 'Todos los rubros',
                        ),
                        items: [
                          for (final category in items)
                            DropdownMenuItem<String>(
                              value: category.id,
                              child: Text(
                                category.name,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _categoryId = value;
                          });
                        },
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text(
                        'No pudimos cargar rubros.',
                      ),
                    ),
                    if (_categoryId != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _categoryId = null;
                            });
                          },
                          child: const Text(
                            'Todos los rubros',
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    const _FilterTitle(
                      title: 'Preferencias',
                    ),
                    const SizedBox(height: 8),
                    _FilterSwitch(
                      icon: Icons.verified_outlined,
                      title: 'Solo verificados',
                      subtitle: 'Prestadores verificados por Ranco Conecta.',
                      value: _verified,
                      onChanged: (value) {
                        setState(() {
                          _verified = value;
                        });
                      },
                    ),
                    _FilterSwitch(
                      icon: Icons.star_outline_rounded,
                      title: 'Solo destacados',
                      subtitle: 'Prestadores con mayor visibilidad.',
                      value: _featured,
                      onChanged: (value) {
                        setState(() {
                          _featured = value;
                        });
                      },
                    ),
                    _FilterSwitch(
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
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                10,
                20,
                20,
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
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _apply,
                      style: FilledButton.styleFrom(
                        backgroundColor: RancoColors.forest,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Aplicar filtros',
                      ),
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

  void _reset() {
    setState(() {
      _locationId = null;
      _categoryId = null;
      _verified = false;
      _featured = false;
      _openNow = false;
    });
  }

  void _apply() {
    final locations = ref.read(locationsProvider);

    Location? selectedLocation;

    locations.whenData((items) {
      if (_locationId != null) {
        for (final location in items) {
          if (location.id == _locationId) {
            selectedLocation = location;
            break;
          }
        }
      }
    });

    ref
        .read(
          selectedLocationProvider.notifier,
        )
        .state = selectedLocation;

    ref
        .read(
          selectedCategoryIdProvider.notifier,
        )
        .state = _categoryId;

    ref
        .read(
          verifiedOnlyProvider.notifier,
        )
        .state = _verified;

    ref
        .read(
          featuredOnlyProvider.notifier,
        )
        .state = _featured;

    ref
        .read(
          openNowOnlyProvider.notifier,
        )
        .state = _openNow;

    Navigator.of(context).pop();
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(
        Icons.tune_rounded,
        size: 18,
      ),
      label: Text(
        count == 0 ? 'Filtros' : 'Filtros ($count)',
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: RancoColors.forest,
        side: const BorderSide(
          color: Color(0xFFD0DFD8),
        ),
        backgroundColor: Colors.white,
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? RancoColors.forest : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? RancoColors.forest
                  : const Color(
                      0xFFD6E3DD,
                    ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : const Color(
                      0xFF53675E,
                    ),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      onDeleted: onRemove,
      deleteIcon: const Icon(
        Icons.close_rounded,
        size: 16,
      ),
      backgroundColor: const Color(0xFFE2F0EA),
      side: BorderSide.none,
      labelStyle: const TextStyle(
        color: RancoColors.forest,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    );
  }
}

class _FilterTitle extends StatelessWidget {
  const _FilterTitle({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF30443B),
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _FilterSwitch extends StatelessWidget {
  const _FilterSwitch({
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
    return Container(
      margin: const EdgeInsets.only(
        bottom: 9,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(
            0xFFD6E3DD,
          ),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        secondary: Icon(
          icon,
          color: RancoColors.forest,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
