import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/ranco_app_bar.dart';
import '../../../theme/ranco_colors.dart';
import '../../provider_dashboard/application/provider_dashboard_providers.dart';
import '../application/gastronomy_providers.dart';
import '../data/gastronomy_repository.dart';

class ProviderMenuScreen extends ConsumerStatefulWidget {
  const ProviderMenuScreen({super.key});

  @override
  ConsumerState<ProviderMenuScreen> createState() => _ProviderMenuScreenState();
}

class _ProviderMenuScreenState extends ConsumerState<ProviderMenuScreen> {
  final List<_EditableMenuCategory> _categories = [];
  final List<_EditableMenuItem> _items = [];
  String? _loadedBusinessId;
  bool _saving = false;

  @override
  void dispose() {
    for (final category in _categories) {
      category.dispose();
    }
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final business = ref.watch(activeProviderBusinessProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4F0),
      appBar: const RancoAppBar(
        title: 'Menú',
        fallbackRoute: '/provider/dashboard',
      ),
      body: business.when(
        data: (business) {
          if (business == null) {
            return const _CenteredMessage('No encontramos tu negocio.');
          }

          final menu = ref.watch(gastronomyMenuProvider(business.id));
          return menu.when(
            data: (menu) {
              _sync(business.id, menu);

              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _Panel(
                    title: 'Categorías del menú',
                    subtitle: 'Ej: Entradas, platos, postres, bebidas.',
                    children: [
                      if (_categories.isEmpty)
                        const _EmptyBox('Aún no tienes categorías.'),
                      for (var index = 0; index < _categories.length; index++)
                        _CategoryEditor(
                          category: _categories[index],
                          onRemove: () {
                            setState(() {
                              _categories.removeAt(index).dispose();
                              for (final item in _items) {
                                if (item.categoryIndex == index) {
                                  item.categoryIndex = null;
                                } else if (item.categoryIndex != null &&
                                    item.categoryIndex! > index) {
                                  item.categoryIndex = item.categoryIndex! - 1;
                                }
                              }
                            });
                          },
                        ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _categories.add(_EditableMenuCategory());
                          });
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Agregar categoría'),
                      ),
                    ],
                  ),
                  _Panel(
                    title: 'Platos / elementos',
                    subtitle:
                        'Publica nombre, descripción, precio y disponibilidad.',
                    children: [
                      if (_items.isEmpty)
                        const _EmptyBox('Aún no tienes elementos en el menú.'),
                      for (var index = 0; index < _items.length; index++)
                        _MenuItemEditor(
                          item: _items[index],
                          categories: _categories,
                          onRemove: () {
                            setState(() {
                              _items.removeAt(index).dispose();
                            });
                          },
                        ),
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _items.add(_EditableMenuItem());
                          });
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Agregar elemento'),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _save(business.id),
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Guardar menú'),
                    style: FilledButton.styleFrom(
                      backgroundColor: RancoColors.forest,
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _CenteredMessage(
              'No pudimos cargar el menú: $error',
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            const _CenteredMessage('No pudimos cargar el negocio.'),
      ),
    );
  }

  void _sync(String businessId, GastronomyMenu menu) {
    if (_loadedBusinessId == businessId) {
      return;
    }

    _loadedBusinessId = businessId;
    for (final category in _categories) {
      category.dispose();
    }
    for (final item in _items) {
      item.dispose();
    }
    _categories
      ..clear()
      ..addAll(
        menu.categories.map((category) {
          return _EditableMenuCategory(name: category.name);
        }),
      );
    _items
      ..clear()
      ..addAll(
        menu.items.map((item) {
          final categoryIndex = menu.categories.indexWhere(
            (category) => category.id == item.categoryId,
          );
          return _EditableMenuItem(
            categoryIndex: categoryIndex < 0 ? null : categoryIndex,
            name: item.name,
            description: item.description ?? '',
            price: item.price.toString(),
            isAvailable: item.isAvailable,
          );
        }),
      );
  }

  Future<void> _save(String businessId) async {
    final categoryIndexMap = <int, int>{};
    final draftCategories = <MenuDraftCategory>[];
    for (var index = 0; index < _categories.length; index++) {
      final category = _categories[index];
      if (category.name.text.trim().isEmpty) {
        continue;
      }

      categoryIndexMap[index] = draftCategories.length;
      draftCategories.add(
        MenuDraftCategory(
          name: category.name.text,
          sortOrder: draftCategories.length,
        ),
      );
    }

    final items =
        _items.where((item) => item.name.text.trim().isNotEmpty).toList();

    if (items.any((item) => int.tryParse(item.price.text.trim()) == null)) {
      _snack('Revisa los precios del menú.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(gastronomyRepositoryProvider).replaceMenu(
        businessId: businessId,
        categories: draftCategories,
        items: [
          for (var index = 0; index < items.length; index++)
            MenuDraftItem(
              categoryId:
                  categoryIndexMap[items[index].categoryIndex]?.toString(),
              name: items[index].name.text,
              description: items[index].description.text,
              price: int.parse(items[index].price.text.trim()),
              isAvailable: items[index].isAvailable,
              sortOrder: index,
            ),
        ],
      );

      ref.invalidate(gastronomyMenuProvider(businessId));
      _loadedBusinessId = null;
      if (!mounted) {
        return;
      }
      _snack('Menú guardado.');
    } catch (error) {
      if (mounted) {
        _snack('No pudimos guardar: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class ProviderTableReservationsScreen extends ConsumerWidget {
  const ProviderTableReservationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(activeProviderBusinessProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4F0),
      appBar: const RancoAppBar(
        title: 'Reservas de mesa',
        fallbackRoute: '/provider/dashboard',
      ),
      body: business.when(
        data: (business) {
          if (business == null) {
            return const _CenteredMessage('No encontramos tu negocio.');
          }

          final reservations =
              ref.watch(gastronomyReservationsProvider(business.id));
          return reservations.when(
            data: (items) {
              final pending = items.where((item) => item.isPending).toList();
              final confirmed =
                  items.where((item) => item.isConfirmed).toList();
              final history = items
                  .where((item) => !item.isPending && !item.isConfirmed)
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _ReservationSummary(
                    pending: pending.length,
                    confirmed: confirmed.length,
                    history: history.length,
                  ),
                  const SizedBox(height: 16),
                  if (pending.isEmpty)
                    const _EmptyBox('No hay reservas pendientes.'),
                  for (final item in pending)
                    _ReservationCard(
                      reservation: item,
                      showActions: true,
                      onConfirm: () => _confirm(context, ref, item),
                      onReject: () => _reject(context, ref, item),
                    ),
                  if (confirmed.isNotEmpty) ...[
                    const _SectionTitle('CONFIRMADAS'),
                    for (final item in confirmed)
                      _ReservationCard(reservation: item),
                  ],
                  if (history.isNotEmpty) ...[
                    const _SectionTitle('HISTORIAL'),
                    for (final item in history)
                      _ReservationCard(reservation: item),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _CenteredMessage(
              'No pudimos cargar las reservas: $error',
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            const _CenteredMessage('No pudimos cargar el negocio.'),
      ),
    );
  }

  Future<void> _confirm(
    BuildContext context,
    WidgetRef ref,
    TableReservation reservation,
  ) async {
    try {
      await ref
          .read(gastronomyRepositoryProvider)
          .confirmReservation(reservation.id);
      ref.invalidate(gastronomyReservationsProvider(reservation.businessId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reserva confirmada.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No pudimos confirmar: $error')),
        );
      }
    }
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    TableReservation reservation,
  ) async {
    try {
      await ref
          .read(gastronomyRepositoryProvider)
          .rejectReservation(reservation.id);
      ref.invalidate(gastronomyReservationsProvider(reservation.businessId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reserva rechazada.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No pudimos rechazar: $error')),
        );
      }
    }
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD5E2DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF61736A), height: 1.35),
          ),
          const SizedBox(height: 14),
          for (final child in children) ...[
            child,
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CategoryEditor extends StatelessWidget {
  const _CategoryEditor({
    required this.category,
    required this.onRemove,
  });

  final _EditableMenuCategory category;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: category.name,
            decoration: const InputDecoration(labelText: 'Categoría'),
          ),
        ),
        IconButton(
          onPressed: onRemove,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    );
  }
}

class _MenuItemEditor extends StatefulWidget {
  const _MenuItemEditor({
    required this.item,
    required this.categories,
    required this.onRemove,
  });

  final _EditableMenuItem item;
  final List<_EditableMenuCategory> categories;
  final VoidCallback onRemove;

  @override
  State<_MenuItemEditor> createState() => _MenuItemEditorState();
}

class _MenuItemEditorState extends State<_MenuItemEditor> {
  @override
  Widget build(BuildContext context) {
    final selectedCategory = widget.item.categoryIndex != null &&
            widget.item.categoryIndex! < widget.categories.length
        ? widget.item.categoryIndex
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1EBE6)),
      ),
      child: Column(
        children: [
          TextField(
            controller: widget.item.name,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.item.description,
            decoration: const InputDecoration(labelText: 'Descripción'),
            minLines: 2,
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.item.price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Precio',
                    prefixText: r'$ ',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: [
                    for (var index = 0;
                        index < widget.categories.length;
                        index++)
                      DropdownMenuItem(
                        value: index,
                        child: Text(widget.categories[index].name.text),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() => widget.item.categoryIndex = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  value: widget.item.isAvailable,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Disponible'),
                  onChanged: (value) {
                    setState(() => widget.item.isAvailable = value);
                  },
                ),
              ),
              IconButton(
                onPressed: widget.onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReservationSummary extends StatelessWidget {
  const _ReservationSummary({
    required this.pending,
    required this.confirmed,
    required this.history,
  });

  final int pending;
  final int confirmed;
  final int history;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RancoColors.forest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '$pending pendientes · $confirmed confirmadas · $history historial',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.reservation,
    this.showActions = false,
    this.onConfirm,
    this.onReject,
  });

  final TableReservation reservation;
  final bool showActions;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5E2DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${reservation.reservationDate.day}/${reservation.reservationDate.month}/${reservation.reservationDate.year} · ${reservation.reservationTime}',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text('${reservation.guests} comensales · ${reservation.status}'),
          if (reservation.message?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(reservation.message!),
          ],
          if (showActions) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    child: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onConfirm,
                    child: const Text('Confirmar'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF718078),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _EditableMenuCategory {
  _EditableMenuCategory({String name = ''})
      : name = TextEditingController(text: name);

  final TextEditingController name;

  void dispose() => name.dispose();
}

class _EditableMenuItem {
  _EditableMenuItem({
    this.categoryIndex,
    String name = '',
    String description = '',
    String price = '0',
    this.isAvailable = true,
  })  : name = TextEditingController(text: name),
        description = TextEditingController(text: description),
        price = TextEditingController(text: price);

  int? categoryIndex;
  final TextEditingController name;
  final TextEditingController description;
  final TextEditingController price;
  bool isAvailable;

  void dispose() {
    name.dispose();
    description.dispose();
    price.dispose();
  }
}
