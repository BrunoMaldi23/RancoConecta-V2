import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/profile.dart';
import '../../../theme/ranco_colors.dart';
import '../../categories/application/category_providers.dart';
import '../../categories/presentation/category_editorial_order.dart';
import '../application/admin_providers.dart';
import '../data/admin_settings_repository.dart';
import '../../../core/widgets/ranco_status_badge.dart';
import '../../../shared/models/category.dart';
import 'admin_error_state.dart';
import 'admin_screens.dart';
import 'admin_ui.dart';

class AdminWhatsAppSettingsScreen extends ConsumerStatefulWidget {
  const AdminWhatsAppSettingsScreen({super.key});

  @override
  ConsumerState<AdminWhatsAppSettingsScreen> createState() =>
      _AdminWhatsAppSettingsScreenState();
}

class _AdminWhatsAppSettingsScreenState
    extends ConsumerState<AdminWhatsAppSettingsScreen> {
  final _number = TextEditingController();
  bool _initialized = false;
  bool _enabled = false;
  bool _newBusiness = true;
  bool _businessChanges = true;
  bool _userReports = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(adminWhatsAppSettingsProvider);
    return AdminGate(
      child: AdminScaffold(
        title: 'Configuración',
        child: settings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => AdminErrorState(
            onRetry: () => ref.invalidate(adminWhatsAppSettingsProvider),
          ),
          data: (current) {
            if (!_initialized) {
              _number.text = current.number;
              _enabled = current.enabled;
              _newBusiness = current.newBusiness;
              _businessChanges = current.businessChanges;
              _userReports = current.userReports;
              _initialized = true;
            }
            // Un único scroll, sin alturas fijas y con margen inferior para
            // que el último evento quede siempre accesible.
            return ListView(
              padding: const EdgeInsets.only(bottom: 48),
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('WhatsApp administrativo',
                            style: TextStyle(
                              color: RancoColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            )),
                        const SizedBox(height: 12),
                        _WhatsAppStatusCard(settings: current),
                        const SizedBox(height: 12),
                        const _InfoCallout(
                          text: 'Ranco Conecta prepara el aviso; el envío se '
                              'confirma manualmente en WhatsApp.',
                        ),
                        const SizedBox(height: 20),
                        // Material propio: los ListTile pintan su feedback.
                        Material(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFFDCE8E0)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Avisos por WhatsApp',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  subtitle: const Text(
                                      'Prepara enlaces para enviar avisos '
                                      'manualmente.'),
                                  value: _enabled,
                                  onChanged: (value) =>
                                      setState(() => _enabled = value),
                                ),
                                const Divider(height: 20),
                                const _SettingsLabel('Número administrador'),
                                TextField(
                                  controller: _number,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    hintText: '569XXXXXXXX',
                                    helperText: 'Incluye código de país.',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const _SettingsLabel('Eventos activos'),
                                CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: const Text(
                                      'Nuevo negocio pendiente de revisión'),
                                  value: _newBusiness,
                                  onChanged: (value) => setState(
                                      () => _newBusiness = value ?? false),
                                ),
                                CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title:
                                      const Text('Solicitud de modificación'),
                                  value: _businessChanges,
                                  onChanged: (value) => setState(
                                      () => _businessChanges = value ?? false),
                                ),
                                CheckboxListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: const Text('Reportes de usuarios'),
                                  value: _userReports,
                                  onChanged: (value) => setState(
                                      () => _userReports = value ?? false),
                                ),
                                const SizedBox(height: 16),
                                const _SettingsLabel('Eventos no disponibles'),
                                const _UnavailableEvent('Negocio rechazado'),
                                const _UnavailableEvent('Nuevo registro'),
                                if (_error != null) ...[
                                  const SizedBox(height: 12),
                                  Text(_error!,
                                      style: const TextStyle(
                                          color: RancoColors.error)),
                                ],
                                const SizedBox(height: 18),
                                Wrap(children: [
                                  FilledButton.icon(
                                    onPressed: _saving ? null : _save,
                                    icon: const Icon(Icons.save_outlined),
                                    label: Text(_saving
                                        ? 'Guardando…'
                                        : 'Guardar configuración'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: RancoColors.forest,
                                      minimumSize: const Size(0, 46),
                                    ),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    final digits = _number.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (_enabled && (digits.length < 8 || digits.length > 15)) {
      setState(() =>
          _error = 'Ingresa un número con código de país (8 a 15 dígitos).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(adminSettingsRepositoryProvider).saveWhatsAppSettings(
            AdminWhatsAppSettings(
              number: digits,
              enabled: _enabled,
              newBusiness: _newBusiness,
              businessChanges: _businessChanges,
              userReports: _userReports,
            ),
          );
      ref.invalidate(adminWhatsAppSettingsProvider);
      if (mounted) {
        // Éxito discreto: snackbar breve.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
            content: Row(children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Cambios guardados'),
            ]),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No pudimos guardar. Intenta nuevamente.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SettingsLabel extends StatelessWidget {
  const _SettingsLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: RancoColors.textSecondary,
                fontSize: 12,
                letterSpacing: .6,
                fontWeight: FontWeight.w800)),
      );
}

class _WhatsAppStatusCard extends StatelessWidget {
  const _WhatsAppStatusCard({required this.settings});

  final AdminWhatsAppSettings settings;

  @override
  Widget build(BuildContext context) {
    final configured = settings.number.isNotEmpty;
    final selectedEvents = <String>[
      if (settings.newBusiness) 'Nuevo negocio pendiente de revisión',
      if (settings.businessChanges) 'Solicitud de modificación',
      if (settings.userReports) 'Reportes de usuarios',
    ];
    final active = configured && settings.enabled;
    final number = !configured
        ? 'No configurado'
        : settings.number.startsWith('+')
            ? settings.number
            : '+${settings.number}';
    Widget field(String label, Widget value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            SizedBox(
              width: 160,
              child: Text(label,
                  style: const TextStyle(
                      color: RancoColors.textSecondary, fontSize: 13)),
            ),
            Expanded(child: value),
          ]),
        );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE8E0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        field(
          'Estado',
          Align(
            alignment: Alignment.centerLeft,
            child: RancoStatusBadge(
              label: active ? 'Activo' : 'Inactivo',
              tone: active ? RancoStatusTone.success : RancoStatusTone.muted,
              dot: true,
            ),
          ),
        ),
        field(
          'Número administrador',
          Text(number,
              style: TextStyle(
                  color: configured
                      ? RancoColors.textPrimary
                      : RancoColors.textSecondary,
                  fontWeight: FontWeight.w700)),
        ),
        field(
          'Eventos activos',
          Text(
              selectedEvents.isEmpty
                  ? 'Ninguno'
                  : '${selectedEvents.length} '
                      '${selectedEvents.length == 1 ? 'seleccionado' : 'seleccionados'}',
              style: const TextStyle(
                  color: RancoColors.textPrimary, fontWeight: FontWeight.w700)),
        ),
        if (selectedEvents.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final event in selectedEvents)
              RancoStatusBadge(label: event, tone: RancoStatusTone.neutral),
          ]),
        ],
      ]),
    );
  }
}

class _UnavailableEvent extends StatelessWidget {
  const _UnavailableEvent(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          const Icon(Icons.notifications_off_outlined,
              size: 18, color: Color(0xFF9AA8A1)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Color(0xFF7D8C85), fontSize: 14)),
          ),
          const Text('No disponible',
              style: TextStyle(color: Color(0xFF9AA8A1), fontSize: 12)),
        ]),
      );
}

class AdminCategoriesScreen extends ConsumerStatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  ConsumerState<AdminCategoriesScreen> createState() =>
      _AdminCategoriesScreenState();
}

enum _CategoryFilter { all, active, inactive }

class _AdminCategoriesScreenState extends ConsumerState<AdminCategoriesScreen> {
  final _search = TextEditingController();
  _CategoryFilter _filter = _CategoryFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(adminCategoriesProvider);
    return AdminGate(
      child: AdminScaffold(
        title: 'Categorías',
        child: categories.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => AdminErrorState(
            onRetry: () => ref.invalidate(adminCategoriesProvider),
          ),
          data: (items) {
            final query = _search.text.trim().toLowerCase();
            final source = items
                .where((item) => switch (_filter) {
                      _CategoryFilter.all => true,
                      _CategoryFilter.active => item.active,
                      _CategoryFilter.inactive => !item.active,
                    })
                .toList();
            final visible = sortCategoriesForPresentation(source)
                .where((item) =>
                    item.name.toLowerCase().contains(query) ||
                    item.slug.toLowerCase().contains(query))
                .toList();
            return ListView(
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Text('${items.length} categorías',
                        style: const TextStyle(
                          color: RancoColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        )),
                    FilledButton.icon(
                      onPressed: () => _openForm(context, null),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nueva categoría'),
                      style: FilledButton.styleFrom(
                        backgroundColor: RancoColors.forest,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(builder: (context, constraints) {
                  final search = AdminSearchField(
                    controller: _search,
                    hint: 'Buscar por nombre o slug',
                    onChanged: (_) => setState(() {}),
                  );
                  final filters = AdminSegmentFilter<_CategoryFilter>(
                    options: [
                      (_CategoryFilter.all, 'Todas', items.length),
                      (
                        _CategoryFilter.active,
                        'Activas',
                        items.where((e) => e.active).length
                      ),
                      (
                        _CategoryFilter.inactive,
                        'Inactivas',
                        items.where((e) => !e.active).length
                      ),
                    ],
                    selected: _filter,
                    onSelected: (value) => setState(() => _filter = value),
                  );
                  if (constraints.maxWidth < 720) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [search, const SizedBox(height: 10), filters],
                    );
                  }
                  return Row(children: [
                    SizedBox(width: 340, child: search),
                    const SizedBox(width: 16),
                    Expanded(child: filters),
                  ]);
                }),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  const _CategoriesEmpty(
                    icon: Icons.category_outlined,
                    title: 'No hay categorías',
                    message: 'Cuando existan rubros aparecerán aquí.',
                  )
                else if (visible.isEmpty)
                  const _CategoriesEmpty(
                    icon: Icons.search_off_rounded,
                    title: 'Sin resultados',
                    message: 'No hay categorías para esta búsqueda.',
                  ),
                LayoutBuilder(builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 860
                      ? 3
                      : constraints.maxWidth >= 520
                          ? 2
                          : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 10) / columns;
                  return Wrap(spacing: 10, runSpacing: 10, children: [
                    for (final category in visible)
                      SizedBox(
                        width: width,
                        child: _CategoryItem(
                          category: category,
                          onEdit: () => _openForm(context, category),
                          onDeactivate: () => _confirm(
                            context,
                            title: category.active
                                ? 'Desactivar categoría'
                                : 'Reactivar categoría',
                            message:
                                '"${category.name}" dejará de mostrarse en '
                                'la plataforma. Los negocios asociados no se '
                                'eliminan.',
                            action:
                                category.active ? 'Desactivar' : 'Reactivar',
                            onConfirm: () => ref
                                .read(adminSettingsRepositoryProvider)
                                .saveCategory(
                                    id: category.id,
                                    name: category.name,
                                    slug: category.slug,
                                    active: !category.active),
                          ),
                          onDelete: () => _confirm(
                            context,
                            title: 'Eliminar categoría',
                            message: 'Se eliminará "${category.name}". Esta '
                                'acción no se puede deshacer.',
                            action: 'Eliminar',
                            destructive: true,
                            onConfirm: () => ref
                                .read(adminSettingsRepositoryProvider)
                                .deleteCategory(category.id),
                          ),
                        ),
                      ),
                  ]);
                }),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, Category? category) {
    return showDialog<void>(
      context: context,
      builder: (_) => _CategoryFormDialog(
          category: category,
          onSave: ({required name, required slug, required active}) async {
            await ref.read(adminSettingsRepositoryProvider).saveCategory(
                id: category?.id, name: name, slug: slug, active: active);
            ref.invalidate(adminCategoriesProvider);
            ref.invalidate(categoriesProvider);
          }),
    );
  }

  Future<void> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
    bool destructive = false,
    required Future<void> Function() onConfirm,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(message),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await onConfirm();
                ref.invalidate(adminCategoriesProvider);
                ref.invalidate(categoriesProvider);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(
                    content: Text(error.toString().contains('CATEGORY_IN_USE')
                        ? 'Categoría en uso. Puedes desactivarla.'
                        : 'No se pudo completar la operación: $error'),
                  ));
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor:
                  destructive ? const Color(0xFF9A3E36) : RancoColors.forest,
            ),
            child: Text(action),
          ),
        ],
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({
    required this.category,
    required this.onEdit,
    required this.onDeactivate,
    required this.onDelete,
  });

  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE8E0)),
      ),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE9F3EE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.category_outlined,
              color: RancoColors.forest, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: RancoColors.textPrimary,
                      fontWeight: FontWeight.w800)),
              Text(category.slug,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: RancoColors.textSecondary, fontSize: 12.5)),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Acciones de ${category.name}',
          icon: const Icon(Icons.more_horiz_rounded),
          onSelected: (value) => switch (value) {
            'edit' => onEdit(),
            'deactivate' => onDeactivate(),
            _ => onDelete(),
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.edit_outlined),
                title: Text('Editar'),
              ),
            ),
            PopupMenuItem(
              value: 'deactivate',
              child: ListTile(
                dense: true,
                leading: Icon(category.active
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
                title: Text(category.active ? 'Desactivar' : 'Reactivar'),
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                dense: true,
                leading: Icon(Icons.delete_outline, color: Color(0xFF9A3E36)),
                title: Text('Eliminar',
                    style: TextStyle(color: Color(0xFF9A3E36))),
              ),
            ),
          ],
        ),
      ]),
    );
  }
}

class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({this.category, required this.onSave});

  final Category? category;
  final Future<void> Function(
      {required String name,
      required String slug,
      required bool active}) onSave;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  late final _name = TextEditingController(text: widget.category?.name);
  late final _slug = TextEditingController(text: widget.category?.slug);
  late bool _active = widget.category?.active ?? true;
  bool _slugEdited = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    super.dispose();
  }

  static String _slugify(String value) {
    const accents = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    final lower = value.trim().toLowerCase();
    final plain = lower.split('').map((c) => accents[c] ?? c).join();
    return plain
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.category != null;
    return AlertDialog(
      title: Text(editing ? 'Editar categoría' : 'Nueva categoría'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, minWidth: 320),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Nombre'),
                onChanged: (value) {
                  if (!_slugEdited) _slug.text = _slugify(value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _slug,
                decoration: const InputDecoration(
                  labelText: 'Slug',
                  helperText:
                      'Identificador en la URL. Ej: hogar-y-mantenimiento',
                ),
                onChanged: (_) => _slugEdited = true,
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Estado'),
                subtitle: Text(_active ? 'Activa' : 'Inactiva'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  setState(() {
                    _saving = true;
                    _error = null;
                  });
                  try {
                    await widget.onSave(
                        name: _name.text, slug: _slug.text, active: _active);
                    if (context.mounted) Navigator.pop(context);
                  } catch (error) {
                    if (mounted) {
                      setState(() {
                        _saving = false;
                        _error = error.toString();
                      });
                    }
                  }
                },
          style: FilledButton.styleFrom(backgroundColor: RancoColors.forest),
          child: Text(editing ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }
}

class _CategoriesEmpty extends StatelessWidget {
  const _CategoriesEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDCE8E0)),
        ),
        child: Row(children: [
          Icon(icon, color: RancoColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: RancoColors.textPrimary,
                        fontWeight: FontWeight.w800)),
                Text(message,
                    style: const TextStyle(
                        color: RancoColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ]),
      );
}

class AdminAnalyticsScreen extends ConsumerWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(adminAnalyticsSummaryProvider);
    final stats = ref.watch(adminReviewStatsProvider);
    final users = ref.watch(
        adminUsersProvider((page: 1, pageSize: 10, search: null, role: null)));
    return AdminGate(
      child: AdminScaffold(
        title: 'Estadísticas',
        child: summary.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => AdminErrorState(
            onRetry: () => ref.invalidate(adminAnalyticsSummaryProvider),
          ),
          data: (counts) => ListView(
            children: [
              Text('Actividad últimos 30 días',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: RancoColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      )),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, constraints) {
                final columns = constraints.maxWidth >= 760
                    ? 4
                    : constraints.maxWidth >= 360
                        ? 2
                        : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 10) / columns;
                return Wrap(spacing: 10, runSpacing: 10, children: [
                  // Solo métricas reales registradas por la plataforma.
                  _AnalyticsMetric(
                      label: 'Visitas',
                      icon: Icons.visibility_outlined,
                      value: counts['PROFILE_VIEW'] ?? 0,
                      width: width),
                  _AnalyticsMetric(
                      label: 'Contactos',
                      icon: Icons.contact_support_outlined,
                      value: counts['REQUEST_CONTACT'] ?? 0,
                      width: width),
                  _AnalyticsMetric(
                      label: 'WhatsApp',
                      icon: Icons.chat_outlined,
                      value: counts['CLICK_WHATSAPP'] ?? 0,
                      width: width),
                  _AnalyticsMetric(
                      label: 'Guardados',
                      icon: Icons.bookmark_outline,
                      value: counts['SAVE_BUSINESS'] ?? 0,
                      width: width),
                ]);
              }),
              const SizedBox(height: 12),
              _AdminRow(
                icon: Icons.call_outlined,
                title: 'Clics en teléfono',
                trailing: '${counts['CLICK_PHONE'] ?? 0}',
              ),
              const SizedBox(height: 8),
              // Sin gráfico inventado: estado compacto hasta tener serie real.
              const _InfoCallout(
                icon: Icons.show_chart_rounded,
                text: 'Aún no hay suficiente actividad para mostrar una '
                    'evolución temporal.',
              ),
              const SizedBox(height: 16),
              Text('Estado de la plataforma',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      )),
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _AnalyticsMetric(
                    label: 'Negocios publicados',
                    icon: Icons.storefront_outlined,
                    value: stats.valueOrNull?['published'],
                    width: 205),
                _AnalyticsMetric(
                    label: 'Usuarios registrados',
                    icon: Icons.people_outline,
                    value: users.valueOrNull?.total,
                    width: 205),
              ]),
              const SizedBox(height: 10),
              const _AdminRow(
                icon: Icons.inbox_outlined,
                title: 'Solicitudes y reservas',
                subtitle: 'Aún no hay una métrica consolidada disponible.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyticsMetric extends StatelessWidget {
  const _AnalyticsMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.width,
  });

  final String label;
  final int? value;
  final IconData icon;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDCE8E0)),
          ),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFE9F3EE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: RancoColors.forest, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value?.toString() ?? '—',
                      style: const TextStyle(
                        color: RancoColors.forest,
                        fontSize: 22,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      )),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: RancoColors.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ]),
        ),
      );
}

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  int _pageSize = 20;
  int _offset = 0;
  final _search = TextEditingController();
  String? _role;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = (
      page: _offset ~/ _pageSize + 1,
      pageSize: _pageSize,
      search: _search.text.trim(),
      role: _role
    );
    final users = ref.watch(adminUsersProvider(query));
    return AdminGate(
      child: AdminScaffold(
        title: 'Usuarios',
        child: users.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => AdminErrorState(
            onRetry: () => ref.invalidate(adminUsersProvider(query)),
          ),
          data: (page) {
            final items = page.rows;
            final visible = items;
            final total = page.total;
            return ListView(
              children: [
                LayoutBuilder(builder: (context, constraints) {
                  final search = AdminSearchField(
                    controller: _search,
                    hint: 'Buscar por nombre o correo',
                    onChanged: (_) => setState(() => _offset = 0),
                  );
                  final segments = AdminSegmentFilter<String?>(
                    options: const [
                      (null, 'Todos', null),
                      ('CUSTOMER', 'Usuarios', null),
                      ('VISITOR', 'Visitantes', null),
                      ('PROVIDER', 'Prestadores', null),
                      ('ADMIN', 'Administradores', null),
                    ],
                    selected: _role,
                    onSelected: (value) => setState(() {
                      _role = value;
                      _offset = 0;
                    }),
                  );
                  if (constraints.maxWidth < 760) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [search, const SizedBox(height: 10), segments],
                    );
                  }
                  return Row(children: [
                    SizedBox(width: 340, child: search),
                    const SizedBox(width: 16),
                    Expanded(child: segments),
                  ]);
                }),
                const SizedBox(height: 12),
                Text(
                  '$total ${total == 1 ? 'cuenta' : 'cuentas'} para este filtro',
                  style: const TextStyle(
                    color: RancoColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const _UsersEmpty(text: 'No hay usuarios en esta página.'),
                // Desktop: tabla compacta. Móvil: tarjetas.
                LayoutBuilder(builder: (context, constraints) {
                  if (constraints.maxWidth < 720 || visible.isEmpty) {
                    return Column(children: [
                      for (final user in visible) _AdminUserTile(user: user),
                    ]);
                  }
                  return _AdminUsersTable(users: visible);
                }),
                // Paginación y filtros resueltos por la RPC administrativa.
                AdminPaginator(
                  offset: _offset,
                  visibleCount: items.length,
                  total: total,
                  pageSize: _pageSize,
                  onFirst:
                      _offset == 0 ? null : () => setState(() => _offset = 0),
                  onLast: _offset + items.length >= total
                      ? null
                      : () => setState(() =>
                          _offset = ((total - 1) ~/ _pageSize) * _pageSize),
                  onPageSizeChanged: (size) => setState(() {
                    _pageSize = size;
                    _offset = 0;
                  }),
                  onPrevious: _offset == 0
                      ? null
                      : () => setState(() => _offset -= _pageSize),
                  onNext: _offset + items.length >= total
                      ? null
                      : () => setState(() => _offset += _pageSize),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UsersEmpty extends StatelessWidget {
  const _UsersEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDCE8E0)),
        ),
        child: Row(children: [
          const Icon(Icons.person_search_outlined,
              color: RancoColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(color: RancoColors.textSecondary)),
          ),
        ]),
      );
}

class _AdminUserTile extends StatelessWidget {
  const _AdminUserTile({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final name = user['full_name']?.toString().trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE8E0)),
      ),
      child: Row(children: [
        const CircleAvatar(
          radius: 18,
          backgroundColor: Color(0xFFE5F1EC),
          child:
              Icon(Icons.person_outline, color: RancoColors.forest, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name == null || name.isEmpty ? 'Sin nombre público' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(user['email']?.toString() ?? 'Sin correo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: RancoColors.textSecondary)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (user['is_anonymous'] == true)
                const _AdminTag(label: 'Visitante'),
              _AdminTag(label: adminRoleLabel(user['role'])),
              _AdminTag(
                label: adminAccountStatusLabel(user['account_status']),
                color: _accountStatusColor(user['account_status']),
              ),
            ]),
          ],
        )),
      ]),
    );
  }
}

class _AdminUsersTable extends StatelessWidget {
  const _AdminUsersTable({required this.users});

  final List<Map<String, dynamic>> users;

  @override
  Widget build(BuildContext context) {
    const header = TextStyle(
      color: RancoColors.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    );
    const cell = TextStyle(color: RancoColors.textPrimary, fontSize: 13);
    Widget row(List<Widget> cells, {double height = 52, Color? color}) =>
        Container(
          constraints: BoxConstraints(minHeight: height),
          color: color,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            Expanded(flex: 3, child: cells[0]),
            Expanded(flex: 3, child: cells[1]),
            SizedBox(width: 130, child: cells[2]),
            SizedBox(width: 110, child: cells[3]),
            SizedBox(width: 96, child: cells[4]),
          ]),
        );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E3DD)),
      ),
      child: Column(children: [
        row(const [
          Text('Usuario', style: header),
          Text('Correo', style: header),
          Text('Rol', style: header),
          Text('Estado', style: header),
          Text('Registro', style: header),
        ], height: 40, color: const Color(0xFFF4F8F6)),
        for (var index = 0; index < users.length; index++) ...[
          if (index > 0) const Divider(height: 1, color: Color(0xFFE5EEE9)),
          () {
            final user = users[index];
            final name = user['full_name']?.toString().trim();
            final email = user['email']?.toString() ?? 'Sin correo';
            final created =
                DateTime.tryParse(user['created_at']?.toString() ?? '');
            final displayName =
                name == null || name.isEmpty ? 'Sin nombre público' : name;
            return row([
              Tooltip(
                message: displayName,
                waitDuration: const Duration(milliseconds: 500),
                child: Text(displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: cell.copyWith(fontWeight: FontWeight.w700)),
              ),
              Tooltip(
                message: email,
                waitDuration: const Duration(milliseconds: 500),
                child: Text(email,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: cell),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: _AdminTag(
                    label: user['is_anonymous'] == true
                        ? 'Visitante'
                        : adminRoleLabel(user['role'])),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: _AdminTag(
                  label: adminAccountStatusLabel(user['account_status']),
                  color: _accountStatusColor(user['account_status']),
                ),
              ),
              Text(
                created == null
                    ? '—'
                    : '${created.toLocal().day.toString().padLeft(2, '0')}/'
                        '${created.toLocal().month.toString().padLeft(2, '0')}/'
                        '${created.toLocal().year}',
                style: const TextStyle(
                    color: RancoColors.textSecondary, fontSize: 12.5),
              ),
            ]);
          }(),
        ],
      ]),
    );
  }
}

/// Etiqueta en español para el rol técnico (`admin`, `provider`, ...).
/// No cambia el enum ni el valor almacenado.
String adminRoleLabel(Object? role) =>
    ProfileRole.parse(role?.toString().toLowerCase() ?? 'customer').label;

/// Etiqueta en español para el estado técnico de la cuenta.
String adminAccountStatusLabel(Object? status) =>
    switch (status?.toString().toLowerCase()) {
      'active' => 'Activo',
      'pending' => 'Pendiente',
      'suspended' => 'Suspendido',
      'disabled' || 'inactive' => 'Inactivo',
      'deleted' => 'Eliminado',
      null || '' => 'Sin estado',
      final other => other,
    };

Color _accountStatusColor(Object? status) =>
    switch (status?.toString().toLowerCase()) {
      'active' => RancoColors.forest,
      'pending' => const Color(0xFF8A5B12),
      'suspended' || 'deleted' => const Color(0xFF9A3E36),
      _ => RancoColors.textSecondary,
    };

class _AdminRow extends StatelessWidget {
  const _AdminRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDCE8E0)),
        ),
        child: Row(children: [
          Icon(icon, color: RancoColors.forest, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: RancoColors.textPrimary,
                        fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(
                          color: RancoColors.textSecondary, fontSize: 12.5)),
              ],
            ),
          ),
          if (trailing != null)
            Text(trailing!,
                style: const TextStyle(
                    color: RancoColors.forest,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
        ]),
      );
}

class _InfoCallout extends StatelessWidget {
  const _InfoCallout({
    required this.text,
    this.icon = Icons.info_outline_rounded,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCFE3D8)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: RancoColors.forest, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: RancoColors.textPrimary, fontSize: 13, height: 1.4)),
          ),
        ]),
      );
}

class _AdminTag extends StatelessWidget {
  const _AdminTag({required this.label, this.color = RancoColors.forest});

  final String label;
  final Color color;

  // Misma pieza visual que el resto de estados de la app.
  @override
  Widget build(BuildContext context) => RancoStatusBadge(
        label: label,
        tone: rancoToneForStatusLabel(label),
      );
}
