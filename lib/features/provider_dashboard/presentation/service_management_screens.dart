import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/ranco_app_bar.dart';
import '../../../core/widgets/ranco_error_state.dart';
import '../../../features/categories/application/category_providers.dart';
import '../../../features/locations/application/location_providers.dart';
import '../../../features/provider_registration/data/business_onboarding_repository.dart';
import '../../../shared/models/category.dart';
import '../../../theme/ranco_colors.dart';
import '../application/provider_dashboard_providers.dart';
import '../data/service_business_management_repository.dart';

class ProviderProfileScreen extends ConsumerStatefulWidget {
  const ProviderProfileScreen({super.key});

  @override
  ConsumerState<ProviderProfileScreen> createState() =>
      _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends ConsumerState<ProviderProfileScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _address = TextEditingController();
  String? _loadedBusinessId;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _email.dispose();
    _website.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serviceBusinessManagementProvider);

    return _ManagementScaffold(
      title: 'Perfil',
      body: state.when(
        data: (state) {
          if (state == null) return const _MissingBusiness();
          _sync(state);

          return _FormShell(
            title: 'Perfil del negocio',
            subtitle: 'Actualiza los datos públicos de contacto.',
            children: [
              _TextField(controller: _name, label: 'Nombre comercial'),
              _TextField(
                controller: _description,
                label: 'Descripción',
                minLines: 3,
                maxLines: 5,
              ),
              _TextField(controller: _phone, label: 'Teléfono'),
              _TextField(controller: _whatsapp, label: 'WhatsApp'),
              _TextField(controller: _email, label: 'Email'),
              _TextField(controller: _website, label: 'Sitio web'),
              _TextField(controller: _address, label: 'Dirección'),
              _SaveButton(
                saving: _saving,
                label: 'Guardar perfil',
                onPressed: () => _save(state),
              ),
            ],
          );
        },
        loading: () => const _LocalLoader(),
        error: (error, stackTrace) => _ErrorBox(message: _message(error)),
      ),
    );
  }

  void _sync(ServiceBusinessManagementState state) {
    if (_loadedBusinessId == state.draft.id) return;
    _loadedBusinessId = state.draft.id;
    _name.text = state.draft.name;
    _description.text = state.draft.description ?? '';
    _phone.text = state.draft.phone ?? '';
    _whatsapp.text = state.draft.whatsapp ?? '';
    _email.text = state.draft.email ?? '';
    _website.text = state.draft.website ?? '';
    _address.text = state.draft.addressText ?? '';
  }

  Future<void> _save(ServiceBusinessManagementState state) async {
    setState(() => _saving = true);
    final result = await ref
        .read(serviceBusinessManagementRepositoryProvider)
        .updateProfile(
          businessId: state.draft.id,
          name: _name.text,
          description: _description.text,
          phone: _phone.text,
          whatsapp: _whatsapp.text,
          email: _email.text,
          website: _website.text,
          addressText: _address.text,
        );

    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (_) {
        ref.invalidate(serviceBusinessManagementProvider);
        ref.invalidate(activeProviderBusinessProvider);
        _snack('Perfil guardado.');
      },
      failure: (failure) => _snack(failure.message),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class ProviderServicesScreen extends ConsumerStatefulWidget {
  const ProviderServicesScreen({super.key});

  @override
  ConsumerState<ProviderServicesScreen> createState() =>
      _ProviderServicesScreenState();
}

class _ProviderServicesScreenState
    extends ConsumerState<ProviderServicesScreen> {
  List<_EditableService> _items = [];
  String? _loadedBusinessId;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serviceBusinessManagementProvider);

    return _ManagementScaffold(
      title: 'Servicios',
      body: state.when(
        data: (state) {
          if (state == null) return const _MissingBusiness();
          if (!state.isService) {
            return const _ErrorBox(
              message:
                  'Esta sección está disponible para negocios de servicio.',
            );
          }
          _sync(state);
          final subcategories =
              ref.watch(subcategoriesProvider(state.draft.primaryCategoryId));

          return subcategories.when(
            data: (subcategories) => _FormShell(
              title: 'Servicios activos',
              subtitle: 'Gestiona los servicios que ofrece este negocio.',
              children: [
                if (_items.isEmpty)
                  const _EmptyBox('Aún no has definido servicios.'),
                for (var index = 0; index < _items.length; index++)
                  _ServiceEditor(
                    key: ValueKey(_items[index].localKey),
                    item: _items[index],
                    options: subcategories,
                    onRemove: () => setState(() => _items.removeAt(index)),
                  ),
                OutlinedButton.icon(
                  onPressed: subcategories.isEmpty
                      ? null
                      : () {
                          setState(() {
                            _items.add(
                              _EditableService(
                                subcategoryId: subcategories.first.id,
                              ),
                            );
                          });
                        },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar servicio'),
                ),
                _SaveButton(
                  saving: _saving,
                  label: 'Guardar servicios',
                  onPressed: () => _save(state),
                ),
              ],
            ),
            loading: () => const _LocalLoader(),
            error: (error, stackTrace) => _ErrorBox(message: _message(error)),
          );
        },
        loading: () => const _LocalLoader(),
        error: (error, stackTrace) => _ErrorBox(message: _message(error)),
      ),
    );
  }

  void _sync(ServiceBusinessManagementState state) {
    if (_loadedBusinessId == state.draft.id) return;
    _loadedBusinessId = state.draft.id;
    _items = state.draft.services
        .map(
          (service) => _EditableService(
            subcategoryId: service.subcategory.id,
            description: service.description ?? '',
            priceFrom: service.priceFrom?.toString() ?? '',
          ),
        )
        .toList();
  }

  Future<void> _save(ServiceBusinessManagementState state) async {
    setState(() => _saving = true);
    final result = await ref
        .read(serviceBusinessManagementRepositoryProvider)
        .replaceServices(
          businessId: state.draft.id,
          services: _items
              .map(
                (item) => ServiceDraftInput(
                  subcategoryId: item.subcategoryId,
                  description: item.description.text.trim(),
                  priceFrom: int.tryParse(item.priceFrom.text.trim()),
                ),
              )
              .toList(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (_) {
        ref.invalidate(serviceBusinessManagementProvider);
        _snack('Servicios guardados.');
      },
      failure: (failure) => _snack(failure.message),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class ProviderCoverageScreen extends ConsumerStatefulWidget {
  const ProviderCoverageScreen({super.key});

  @override
  ConsumerState<ProviderCoverageScreen> createState() =>
      _ProviderCoverageScreenState();
}

class _ProviderCoverageScreenState
    extends ConsumerState<ProviderCoverageScreen> {
  final _search = TextEditingController();
  final Set<String> _selected = {};
  String? _loadedBusinessId;
  bool _saving = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serviceBusinessManagementProvider);
    final locations = ref.watch(locationsProvider);

    return _ManagementScaffold(
      title: 'Cobertura',
      body: state.when(
        data: (state) {
          if (state == null) return const _MissingBusiness();
          _sync(state);
          return locations.when(
            data: (items) {
              final query = _search.text.trim().toLowerCase();
              final filtered = items.where((item) {
                return query.isEmpty ||
                    item.name.toLowerCase().contains(query) ||
                    (item.communeName?.toLowerCase().contains(query) ?? false);
              }).toList();

              return _FormShell(
                title: 'Localidades cubiertas',
                subtitle:
                    'Selecciona las localidades donde atiende el negocio.',
                children: [
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Buscar localidad',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  if (filtered.isEmpty)
                    const _EmptyBox(
                        'No encontramos localidades con ese texto.'),
                  for (final location in filtered)
                    CheckboxListTile(
                      value: _selected.contains(location.id),
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selected.add(location.id);
                          } else {
                            _selected.remove(location.id);
                          }
                        });
                      },
                      title: Text(location.name),
                      subtitle: location.communeName == null
                          ? null
                          : Text(location.communeName!),
                    ),
                  _SaveButton(
                    saving: _saving,
                    label: 'Guardar cobertura',
                    onPressed: () => _save(state),
                  ),
                ],
              );
            },
            loading: () => const _LocalLoader(),
            error: (error, stackTrace) => _ErrorBox(message: _message(error)),
          );
        },
        loading: () => const _LocalLoader(),
        error: (error, stackTrace) => _ErrorBox(message: _message(error)),
      ),
    );
  }

  void _sync(ServiceBusinessManagementState state) {
    if (_loadedBusinessId == state.draft.id) return;
    _loadedBusinessId = state.draft.id;
    _selected
      ..clear()
      ..addAll(state.draft.coverage.map((location) => location.id));
  }

  Future<void> _save(ServiceBusinessManagementState state) async {
    setState(() => _saving = true);
    final result = await ref
        .read(serviceBusinessManagementRepositoryProvider)
        .replaceCoverage(
          businessId: state.draft.id,
          locationIds: _selected.toList(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (_) {
        ref.invalidate(serviceBusinessManagementProvider);
        _snack('Cobertura guardada.');
      },
      failure: (failure) => _snack(failure.message),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class ProviderHoursScreen extends ConsumerStatefulWidget {
  const ProviderHoursScreen({super.key});

  @override
  ConsumerState<ProviderHoursScreen> createState() =>
      _ProviderHoursScreenState();
}

class _ProviderHoursScreenState extends ConsumerState<ProviderHoursScreen> {
  late List<_EditableHour> _hours;
  String? _loadedBusinessId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _hours = List.generate(
      7,
      (index) => _EditableHour(dayOfWeek: index + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serviceBusinessManagementProvider);

    return _ManagementScaffold(
      title: 'Horarios',
      body: state.when(
        data: (state) {
          if (state == null) return const _MissingBusiness();
          _sync(state);
          return _FormShell(
            title: 'Horario de atención',
            subtitle: 'Define un rango diario de apertura y cierre.',
            children: [
              for (final hour in _hours) _HourEditor(hour: hour),
              _SaveButton(
                saving: _saving,
                label: 'Guardar horarios',
                onPressed: () => _save(state),
              ),
            ],
          );
        },
        loading: () => const _LocalLoader(),
        error: (error, stackTrace) => _ErrorBox(message: _message(error)),
      ),
    );
  }

  void _sync(ServiceBusinessManagementState state) {
    if (_loadedBusinessId == state.draft.id) return;
    _loadedBusinessId = state.draft.id;
    final byDay = {for (final hour in state.draft.hours) hour.dayOfWeek: hour};
    _hours = List.generate(7, (index) {
      final day = index + 1;
      final existing = byDay[day];
      return _EditableHour(
        dayOfWeek: day,
        isClosed: existing?.isClosed ?? true,
        openTime: _shortTime(existing?.openTime ?? '09:00'),
        closeTime: _shortTime(existing?.closeTime ?? '18:00'),
      );
    });
  }

  Future<void> _save(ServiceBusinessManagementState state) async {
    setState(() => _saving = true);
    final result = await ref
        .read(serviceBusinessManagementRepositoryProvider)
        .replaceHours(
          businessId: state.draft.id,
          hours: _hours
              .map(
                (hour) => BusinessHourInput(
                  dayOfWeek: hour.dayOfWeek,
                  isClosed: hour.isClosed,
                  openTime: hour.openTime.text,
                  closeTime: hour.closeTime.text,
                ),
              )
              .toList(),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (_) {
        ref.invalidate(serviceBusinessManagementProvider);
        _snack('Horarios guardados.');
      },
      failure: (failure) => _snack(failure.message),
    );
  }

  String _shortTime(String value) {
    return value.length >= 5 ? value.substring(0, 5) : value;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _ManagementScaffold extends StatelessWidget {
  const _ManagementScaffold({
    required this.title,
    required this.body,
  });

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RancoColors.canvas,
      appBar: RancoAppBar(title: title, fallbackRoute: '/provider/dashboard'),
      body: body,
    );
  }
}

class _FormShell extends StatelessWidget {
  const _FormShell({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD4E0DA)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: RancoColors.forest,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: RancoColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...children
                      .expand((child) => [child, const SizedBox(height: 10)]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.saving,
    required this.label,
    required this.onPressed,
  });

  final bool saving;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: saving ? null : onPressed,
      icon: saving
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_outlined),
      label: Text(label),
    );
  }
}

class _ServiceEditor extends StatelessWidget {
  const _ServiceEditor({
    required this.item,
    required this.options,
    required this.onRemove,
    super.key,
  });

  final _EditableService item;
  final List<Subcategory> options;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4E0DA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: item.subcategoryId,
              decoration: const InputDecoration(labelText: 'Servicio'),
              items: options
                  .map(
                    (option) => DropdownMenuItem(
                      value: option.id,
                      child: Text(
                        _subcategoryLabel(option, options),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) item.subcategoryId = value;
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: item.description,
              decoration: const InputDecoration(labelText: 'Descripción'),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: item.priceFrom,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Precio desde'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Quitar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _subcategoryLabel(Subcategory option, List<Subcategory> all) {
  if (all.length == 1 && option.slug == 'general') {
    return 'Actividad definida';
  }
  return option.name;
}

class _HourEditor extends StatefulWidget {
  const _HourEditor({required this.hour});

  final _EditableHour hour;

  @override
  State<_HourEditor> createState() => _HourEditorState();
}

class _HourEditorState extends State<_HourEditor> {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4E0DA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: !widget.hour.isClosed,
              onChanged: (value) {
                setState(() => widget.hour.isClosed = !value);
              },
              title: Text(_dayName(widget.hour.dayOfWeek)),
              subtitle: Text(widget.hour.isClosed ? 'Cerrado' : 'Abierto'),
            ),
            if (!widget.hour.isClosed)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.hour.openTime,
                      decoration: const InputDecoration(labelText: 'Abre'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: widget.hour.closeTime,
                      decoration: const InputDecoration(labelText: 'Cierra'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _EditableService {
  _EditableService({
    required this.subcategoryId,
    String description = '',
    String priceFrom = '',
  })  : description = TextEditingController(text: description),
        priceFrom = TextEditingController(text: priceFrom);

  final String localKey = UniqueKey().toString();
  String subcategoryId;
  final TextEditingController description;
  final TextEditingController priceFrom;
}

class _EditableHour {
  _EditableHour({
    required this.dayOfWeek,
    this.isClosed = true,
    String openTime = '09:00',
    String closeTime = '18:00',
  })  : openTime = TextEditingController(text: openTime),
        closeTime = TextEditingController(text: closeTime);

  final int dayOfWeek;
  bool isClosed;
  final TextEditingController openTime;
  final TextEditingController closeTime;
}

class _LocalLoader extends StatelessWidget {
  const _LocalLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _MissingBusiness extends StatelessWidget {
  const _MissingBusiness();

  @override
  Widget build(BuildContext context) {
    return const RancoErrorState(
      message: 'No encontramos un negocio activo para administrar.',
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return RancoErrorState(message: message);
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD4E0DA)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: RancoColors.textSecondary),
      ),
    );
  }
}

String _dayName(int day) {
  return switch (day) {
    1 => 'Lunes',
    2 => 'Martes',
    3 => 'Miércoles',
    4 => 'Jueves',
    5 => 'Viernes',
    6 => 'Sábado',
    _ => 'Domingo',
  };
}

String _message(Object error) {
  if (error is AppFailure) return error.message;
  return 'No pudimos cargar la información.';
}
