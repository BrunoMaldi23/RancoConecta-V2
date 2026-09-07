import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/location.dart';
import '../../../theme/ranco_colors.dart';
import '../application/location_providers.dart';

class LocationSelector extends ConsumerWidget {
  const LocationSelector({
    this.compact = false,
    this.label = 'Localidad',
    super.key,
  });

  final bool compact;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(locationsProvider);
    final selected = ref.watch(selectedLocationProvider);

    return locations.when(
      data: (items) {
        final effectiveSelected = selected;

        final selectedLabel = selected?.name ?? 'Todas las localidades';

        return Material(
          color: compact ? const Color(0xFFF4F8F6) : Colors.white,
          borderRadius: BorderRadius.circular(
            compact ? 16 : 18,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(
              compact ? 16 : 18,
            ),
            onTap: () {
              _showLocationSheet(
                context: context,
                ref: ref,
                items: items,
                selected: selected,
              );
            },
            child: Container(
              constraints: BoxConstraints(
                minHeight: compact ? 52 : 58,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 14 : 16,
                vertical: compact ? 10 : 12,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  compact ? 16 : 18,
                ),
                border: compact
                    ? null
                    : Border.all(
                        color: const Color(0xFFD6E3DD),
                      ),
              ),
              child: Row(
                children: [
                  Container(
                    width: compact ? 36 : 40,
                    height: compact ? 36 : 40,
                    decoration: BoxDecoration(
                      color: compact
                          ? Colors.transparent
                          : const Color(0xFFE3F0EA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: RancoColors.forest,
                      size: 21,
                    ),
                  ),
                  SizedBox(
                    width: compact ? 2 : 10,
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!compact) ...[
                          Text(
                            label,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: const Color(0xFF73847C),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          selectedLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: compact
                                ? const Color(0xFF31423A)
                                : RancoColors.forest,
                            fontWeight: FontWeight.w700,
                            fontSize: compact ? 14 : 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF65766E),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => Container(
        height: compact ? 52 : 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: compact ? const Color(0xFFF4F8F6) : Colors.white,
          borderRadius: BorderRadius.circular(
            compact ? 16 : 18,
          ),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
          ),
          child: LinearProgressIndicator(
            minHeight: 2,
          ),
        ),
      ),
      error: (error, stackTrace) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0ED),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            locationFailureMessage(error),
            style: const TextStyle(
              color: Color(0xFF8C4034),
              fontSize: 13,
            ),
          ),
        );
      },
    );
  }

  Location? _defaultLocation(
    List<Location> locations,
  ) {
    if (locations.isEmpty) {
      return null;
    }

    return locations.firstWhere(
      (location) => location.slug == 'lago-ranco',
      orElse: () => locations.first,
    );
  }

  Future<void> _showLocationSheet({
    required BuildContext context,
    required WidgetRef ref,
    required List<Location> items,
    required Location? selected,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _LocationBottomSheet(
          items: items,
          selected: selected,
          onSelected: (location) {
            ref
                .read(
                  selectedLocationProvider.notifier,
                )
                .state = location;

            Navigator.of(sheetContext).pop();
          },
        );
      },
    );
  }
}

class _LocationBottomSheet extends StatefulWidget {
  const _LocationBottomSheet({
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final List<Location> items;
  final Location? selected;
  final ValueChanged<Location?> onSelected;

  @override
  State<_LocationBottomSheet> createState() => _LocationBottomSheetState();
}

class _LocationBottomSheetState extends State<_LocationBottomSheet> {
  final _searchController = TextEditingController();

  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();

    final filtered = widget.items.where(
      (location) {
        if (query.isEmpty) {
          return true;
        }

        final name = location.name.toLowerCase();

        final commune = location.communeName?.toLowerCase() ?? '';

        return name.contains(query) || commune.contains(query);
      },
    ).toList();

    final screenHeight = MediaQuery.sizeOf(context).height;

    final sheetHeight = screenHeight * 0.82;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: sheetHeight,
        constraints: const BoxConstraints(
          maxWidth: 520,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
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
                18,
                12,
                12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Elige una localidad',
                          style: TextStyle(
                            color: RancoColors.forest,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mostraremos los servicios disponibles en ese sector.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(
                                      0xFF71827A,
                                    ),
                                    height: 1.35,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(
                        0xFFEAF3EF,
                      ),
                      foregroundColor: const Color(
                        0xFF30443B,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar localidad',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();

                            setState(() {
                              _query = '';
                            });
                          },
                          icon: const Icon(
                            Icons.close_rounded,
                          ),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      18,
                    ),
                    borderSide: const BorderSide(
                      color: Color(
                        0xFFD6E3DD,
                      ),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      18,
                    ),
                    borderSide: const BorderSide(
                      color: Color(
                        0xFFD6E3DD,
                      ),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      18,
                    ),
                    borderSide: const BorderSide(
                      color: RancoColors.forest,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  28,
                ),
                children: [
                  _LocationTile(
                    title: 'Todas las localidades',
                    subtitle: 'Ver servicios de todas las zonas',
                    selected: widget.selected == null,
                    emphasized: true,
                    onTap: () {
                      widget.onSelected(null);
                    },
                  ),
                  const SizedBox(height: 10),
                  for (final location in filtered) ...[
                    _LocationTile(
                      title: location.name,
                      subtitle: _locationSubtitle(
                        location,
                      ),
                      selected: widget.selected?.id == location.id,
                      onTap: () {
                        widget.onSelected(
                          location,
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (filtered.isEmpty) const _EmptySearch(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _locationSubtitle(
    Location location,
  ) {
    final commune = location.communeName?.trim().isNotEmpty == true
        ? location.communeName!
        : location.name;

    final count = location.providerCount;

    final providerText = count == 1 ? '1 prestador' : '$count prestadores';

    return '$commune \u00B7 $providerText';
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.emphasized = false,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool emphasized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFE3F1EA) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? const Color(
                      0xFF99CDB6,
                    )
                  : const Color(
                      0xFFD5E2DC,
                    ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected
                      ? RancoColors.forest
                      : const Color(
                          0xFFE6F1EC,
                        ),
                  borderRadius: BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  color: selected ? Colors.white : RancoColors.forest,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected || emphasized
                            ? RancoColors.forest
                            : const Color(
                                0xFF34453D,
                              ),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(
                          0xFF74857D,
                        ),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (selected)
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: RancoColors.forest,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(
                    0xFF9DAAA4,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 42,
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(
                0xFFE7F2ED,
              ),
              borderRadius: BorderRadius.circular(
                18,
              ),
            ),
            child: const Icon(
              Icons.location_off_outlined,
              color: RancoColors.forest,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No encontramos esa localidad',
            style: TextStyle(
              color: Color(0xFF34453D),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Prueba escribiendo otro nombre.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF74857D),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
