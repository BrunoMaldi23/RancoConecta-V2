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
  const CategoriesScreen({
    super.key,
  });

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  late final TextEditingController _searchController;

  String _query = '';

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return ColoredBox(
      color: RancoColors.canvas,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  18,
                  24,
                  8,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 1240,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _BackButton(
                              onTap: () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go(
                                    '/explore',
                                  );
                                }
                              },
                            ),
                            const SizedBox(
                              width: 12,
                            ),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Todas las categor\u00edas',
                                    style: TextStyle(
                                      color: RancoColors.forest,
                                      fontSize: 27,
                                      height: 1.05,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -.4,
                                    ),
                                  ),
                                  SizedBox(
                                    height: 4,
                                  ),
                                  Text(
                                    'Explora servicios y negocios por categor\u00eda.',
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
                        const SizedBox(
                          height: 18,
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 760,
                            ),
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(
                                  14,
                                ),
                                border: Border.all(
                                  color: RancoDecoration.softBorder,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: .018,
                                    ),
                                    blurRadius: 14,
                                    offset: const Offset(
                                      0,
                                      5,
                                    ),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (value) {
                                  setState(() {
                                    _query = value;
                                  });
                                },
                                decoration: InputDecoration(
                                  hintText: 'Buscar una categor\u00eda...',
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    color: RancoColors.primary,
                                    size: 19,
                                  ),
                                  suffixIcon: _query.trim().isNotEmpty
                                      ? IconButton(
                                          tooltip: 'Limpiar',
                                          onPressed: () {
                                            _searchController.clear();

                                            setState(() {
                                              _query = '';
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            size: 18,
                                          ),
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 15,
                                  ),
                                  hintStyle: const TextStyle(
                                    color: Color(
                                      0xFF83928B,
                                    ),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            categories.when(
              data: (items) {
                final filtered = _filterCategories(
                  items,
                  _query,
                );

                if (items.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        24,
                        16,
                        24,
                        0,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 1240,
                          ),
                          child: const RancoEmptyState(
                            icon: Icons.grid_view_rounded,
                            title: 'A\u00fan no hay categor\u00edas',
                            message:
                                'Cuando los rubros est\u00e9n activos aparecer\u00e1n aqu\u00ed.',
                          ),
                        ),
                      ),
                    ),
                  );
                }

                if (filtered.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        24,
                        18,
                        24,
                        0,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 1240,
                          ),
                          child: const RancoEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'Sin resultados',
                            message:
                                'No encontramos categor\u00edas para esa b\u00fasqueda.',
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      24,
                      10,
                      24,
                      32,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 1240,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Explora por categor\u00eda',
                                    style: TextStyle(
                                      color: RancoColors.forest,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Container(
                                  height: 30,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFEAF4EF,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      99,
                                    ),
                                  ),
                                  child: Text(
                                    '${filtered.length} '
                                    '${filtered.length == 1 ? 'categor\u00eda' : 'categor\u00edas'}',
                                    style: const TextStyle(
                                      color: RancoColors.forest,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 12,
                            ),
                            LayoutBuilder(
                              builder: (
                                context,
                                constraints,
                              ) {
                                final width = constraints.maxWidth;

                                final columns = width >= 1120
                                    ? 4
                                    : width >= 820
                                        ? 3
                                        : width >= 540
                                            ? 2
                                            : 1;

                                const gap = 12.0;

                                final itemWidth =
                                    (width - gap * (columns - 1)) / columns;

                                return Wrap(
                                  spacing: gap,
                                  runSpacing: gap,
                                  children: [
                                    for (final category in filtered)
                                      SizedBox(
                                        width: itemWidth,
                                        child: _CategoryTile(
                                          category: category,
                                          onTap: () {
                                            _openCategory(
                                              category,
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              loading: () {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      24,
                      18,
                      24,
                      0,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 1240,
                        ),
                        child: const RancoSkeleton(
                          height: 320,
                        ),
                      ),
                    ),
                  ),
                );
              },
              error: (
                error,
                stackTrace,
              ) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      24,
                      18,
                      24,
                      0,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 1240,
                        ),
                        child: RancoErrorState(
                          message: failureMessage(
                            error,
                            'No pudimos cargar las categor\u00edas.',
                          ),
                          onRetry: () {
                            ref.invalidate(
                              categoriesProvider,
                            );
                          },
                        ),
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

  List<Category> _filterCategories(
    List<Category> categories,
    String query,
  ) {
    final normalized = query.trim().toLowerCase();

    if (normalized.isEmpty) {
      return categories;
    }

    return categories.where(
      (category) {
        final haystack = '${category.name} ${category.slug} ${category.iconKey}'
            .toLowerCase();

        return haystack.contains(
          normalized,
        );
      },
    ).toList();
  }

  void _openCategory(
    Category category,
  ) {
    ref
        .read(
          businessSearchQueryProvider.notifier,
        )
        .state = '';

    ref
        .read(
          selectedCategoryIdProvider.notifier,
        )
        .state = category.id;

    ref
        .read(
          verifiedOnlyProvider.notifier,
        )
        .state = false;

    ref
        .read(
          featuredOnlyProvider.notifier,
        )
        .state = false;

    ref
        .read(
          openNowOnlyProvider.notifier,
        )
        .state = false;

    context.go('/explore');
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

class _CategoryTile extends StatefulWidget {
  const _CategoryTile({
    required this.category,
    required this.onTap,
  });

  final Category category;
  final VoidCallback onTap;

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final category = widget.category;

    final tone = _categoryTone(category);

    final isEmergency = category.name.toLowerCase().contains('emerg');

    final accent = isEmergency
        ? const Color(
            0xFFD76B4F,
          )
        : tone;

    final iconBackground = isEmergency
        ? const Color(
            0xFFFFEEE8,
          )
        : tone.withValues(
            alpha: .10,
          );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 160,
        ),
        transform: Matrix4.translationValues(
          0,
          _hovered ? -2 : 0,
          0,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            16,
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: .055,
                    ),
                    blurRadius: 18,
                    offset: const Offset(
                      0,
                      7,
                    ),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            16,
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(
              16,
            ),
            child: Container(
              height: 108,
              padding: const EdgeInsets.all(
                14,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  16,
                ),
                border: Border.all(
                  color: _hovered
                      ? accent.withValues(
                          alpha: .52,
                        )
                      : RancoDecoration.softBorder,
                  width: _hovered ? 1.2 : 1,
                ),
                gradient: isEmergency
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(
                            0xFFFFFCFA,
                          ),
                          Color(
                            0xFFFFF6F2,
                          ),
                        ],
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: iconBackground,
                          borderRadius: BorderRadius.circular(
                            11,
                          ),
                        ),
                        child: Icon(
                          _categoryIcon(
                            category,
                          ),
                          size: 20,
                          color: accent,
                        ),
                      ),
                      const Spacer(),
                      AnimatedContainer(
                        duration: const Duration(
                          milliseconds: 160,
                        ),
                        transform: Matrix4.translationValues(
                          _hovered ? 2 : 0,
                          0,
                          0,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: _hovered
                              ? accent
                              : const Color(
                                  0xFF8A9A92,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RancoColors.textPrimary,
                      fontSize: 14,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Row(
                    children: [
                      Text(
                        'Ver servicios',
                        style: TextStyle(
                          color: _hovered ? accent : RancoColors.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(
                        width: 4,
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: _hovered ? accent : RancoColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
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

  if (key.contains('escombro') || key.contains('delete_sweep')) {
    return Icons.delete_sweep_outlined;
  }

  if (key.contains('chatarra') || key.contains('recycling')) {
    return Icons.recycling_outlined;
  }

  if (key.contains('fosa') || key.contains('water_drop')) {
    return Icons.water_drop_outlined;
  }

  if (key.contains('mantenimiento') || key.contains('home_repair')) {
    return Icons.home_repair_service_outlined;
  }

  if (key.contains('inspeccion') ||
      key.contains('inspección') ||
      key.contains('visual') ||
      key.contains('visibility')) {
    return Icons.visibility_outlined;
  }

  if (key.contains('carpin')) {
    return Icons.carpenter_outlined;
  }

  if (key.contains('pint')) {
    return Icons.format_paint_outlined;
  }

  if (key.contains('sold')) {
    return Icons.hardware_outlined;
  }

  if (key.contains('calef')) {
    return Icons.local_fire_department_outlined;
  }

  if (key.contains('solar')) {
    return Icons.solar_power_outlined;
  }

  return Icons.home_repair_service_outlined;
}

Color _categoryTone(Category category) {
  final key = '${category.themeKey} ${category.slug}'.toLowerCase();

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
