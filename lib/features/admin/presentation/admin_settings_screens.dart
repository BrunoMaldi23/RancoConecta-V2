import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/profile.dart';
import '../../profile/application/profile_providers.dart';
import '../../categories/presentation/categories_screen.dart'
    show categoryIconFor;
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
import '../../../core/widgets/ranco_states.dart';
import '../../../theme/ranco_tokens.dart';

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

  /// Sección activa de Configuración (1 = WhatsApp, la única con backend).
  int _section = 1;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(adminWhatsAppSettingsProvider);
    return AdminGate(
      child: AdminScaffold(
        title: 'Configuración',
        child: ListView(
          padding: const EdgeInsets.only(bottom: 48),
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SettingsSectionNav(
                      selected: _section,
                      onSelected: (index) => setState(() => _section = index),
                    ),
                    const SizedBox(height: 20),
                    AnimatedSwitcher(
                      duration: RancoDurations.quick,
                      switchInCurve: Curves.easeOut,
                      child: KeyedSubtree(
                        key: ValueKey(_section),
                        child: switch (_section) {
                          0 => const _GeneralSettings(),
                          1 => _whatsApp(settings),
                          2 => const _NotificationSettingsPreview(),
                          _ => const _IntegrationsEmpty(),
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _whatsApp(AsyncValue<AdminWhatsAppSettings> settings) {
    return settings.when(
      loading: () => const _SettingsSkeleton(),
      error: (error, _) => AdminErrorState(
        error: error,
        title: 'No pudimos cargar la configuración de WhatsApp.',
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Avisos administrativos por WhatsApp',
                style: TextStyle(
                  color: RancoColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                )),
            const SizedBox(height: 4),
            const Text(
              'Recibe un mensaje preparado cuando ocurra un evento que '
              'requiere revisión.',
              style:
                  TextStyle(color: RancoColors.textSecondary, fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            // A. Estado (descriptivo).
            _WhatsAppStatusCard(settings: current),
            const SizedBox(height: 16),
            // B–D. Configuración editable en un único bloque.
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFDCE8E0)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Activar avisos',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: const Text(
                          'Prepara enlaces para enviar avisos manualmente.'),
                      value: _enabled,
                      onChanged: (value) => setState(() => _enabled = value),
                    ),
                    const Divider(height: 16),
                    const SizedBox(height: 6),
                    const _SettingsLabel('Número administrador'),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: TextField(
                        controller: _number,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: '569XXXXXXXX',
                          helperText: 'Incluye código de país.',
                          prefixIcon: Icon(Icons.phone_outlined, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SettingsLabel('Eventos'),
                    LayoutBuilder(builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 560 ? 2 : 1;
                      final width = columns == 1
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 10) / 2;
                      Widget option(
                        String title,
                        String subtitle,
                        bool value,
                        ValueChanged<bool> onChanged,
                      ) =>
                          SizedBox(
                            width: width,
                            child: _EventOption(
                              title: title,
                              subtitle: subtitle,
                              value: value,
                              onChanged: onChanged,
                            ),
                          );
                      return Wrap(spacing: 10, runSpacing: 10, children: [
                        option(
                          'Nuevo negocio pendiente de revisión',
                          'Cuando un prestador envía su publicación.',
                          _newBusiness,
                          (value) => setState(() => _newBusiness = value),
                        ),
                        option(
                          'Solicitud de modificación',
                          'Cuando un negocio pide revisar cambios.',
                          _businessChanges,
                          (value) => setState(() => _businessChanges = value),
                        ),
                        option(
                          'Reportes de usuarios',
                          'Cuando alguien reporta una publicación.',
                          _userReports,
                          (value) => setState(() => _userReports = value),
                        ),
                      ]);
                    }),
                    const SizedBox(height: 16),
                    const _InfoCallout(
                      text: 'Ranco Conecta prepara el mensaje y el envío se '
                          'confirma manualmente en WhatsApp.',
                    ),
                    AnimatedSize(
                      duration: RancoDurations.quick,
                      alignment: Alignment.topCenter,
                      child: _error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Row(children: [
                                const Icon(Icons.error_outline_rounded,
                                    size: 18, color: RancoColors.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_error!,
                                      style: const TextStyle(
                                          color: RancoColors.error,
                                          fontSize: 13.5)),
                                ),
                              ]),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text(
                            _saving ? 'Guardando…' : 'Guardar configuración'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 46),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // E. Información secundaria, plegada por defecto.
            Material(
              color: const Color(0xFFF7F9F8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: const ExpansionTile(
                shape: Border(),
                collapsedShape: Border(),
                dense: true,
                expansionAnimationStyle: AnimationStyle(
                  duration: RancoDurations.quick,
                ),
                tilePadding: EdgeInsets.symmetric(horizontal: 18),
                childrenPadding: EdgeInsets.fromLTRB(18, 0, 18, 10),
                title: Text('Otros eventos (2)',
                    style: TextStyle(
                        color: RancoColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                children: [
                  _UnavailableEvent('Negocio rechazado'),
                  _UnavailableEvent('Nuevo registro'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _save() async {
    final number = _number.text.trim();
    final validNumber = RegExp(r'^\+?[1-9][0-9]{7,14}$').hasMatch(number);
    if ((number.isNotEmpty && !validNumber) || (_enabled && !validNumber)) {
      setState(() =>
          _error = 'Ingresa un número con código de país (8 a 15 dígitos).');
      return;
    }
    final digits = number.replaceFirst('+', '');
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

/// Estado actual en una franja: activo/inactivo + número configurado.
class _WhatsAppStatusCard extends StatelessWidget {
  const _WhatsAppStatusCard({required this.settings});

  final AdminWhatsAppSettings settings;

  @override
  Widget build(BuildContext context) {
    final configured = settings.number.isNotEmpty;
    final active = configured && settings.enabled;
    final number = !configured
        ? 'Sin número configurado'
        : settings.number.startsWith('+')
            ? settings.number
            : '+${settings.number}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFF1F8F4) : const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? const Color(0xFFD3E7DC) : const Color(0xFFE3EAE6),
        ),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('Estado',
                style:
                    TextStyle(color: RancoColors.textSecondary, fontSize: 13)),
            const SizedBox(width: 8),
            RancoStatusBadge(
              label: active ? 'Activo' : 'Inactivo',
              tone: active ? RancoStatusTone.success : RancoStatusTone.muted,
              dot: true,
            ),
          ]),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.phone_outlined,
                size: 16, color: RancoColors.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(number,
                  style: TextStyle(
                      color: configured
                          ? RancoColors.textPrimary
                          : RancoColors.textSecondary,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.touch_app_outlined,
                size: 16, color: RancoColors.textSecondary),
            SizedBox(width: 6),
            Text('Modo: ',
                style:
                    TextStyle(color: RancoColors.textSecondary, fontSize: 13)),
            Text('Envío manual',
                style: TextStyle(
                    color: RancoColors.textPrimary,
                    fontWeight: FontWeight.w700)),
          ]),
        ],
      ),
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
          loading: () => const _UsersSkeleton(),
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
                    Text(
                        '${items.length} '
                        '${items.length == 1 ? 'categoría' : 'categorías'}',
                        style: const TextStyle(
                          color: RancoColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        )),
                    FilledButton.icon(
                      onPressed: () => _openForm(context, null),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nueva categoría'),
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
                    // Mensaje humano; el detalle técnico no se muestra.
                    content: Text(error.toString().contains('CATEGORY_IN_USE')
                        ? 'No se puede eliminar: hay negocios usando esta '
                            'categoría. Puedes desactivarla.'
                        : 'No se pudo completar la operación. Intenta '
                            'nuevamente.'),
                  ));
                }
              }
            },
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF9A3E36),
                  )
                : null,
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
    final inactive = !category.active;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      decoration: BoxDecoration(
        color: inactive ? const Color(0xFFF7F9F8) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE8E0)),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: inactive ? const Color(0xFFEDF0EE) : const Color(0xFFE9F3EE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(categoryIconFor(category),
              color: inactive ? RancoColors.textSecondary : RancoColors.forest,
              size: 19),
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
        // Solo se marca la excepción (inactiva); activa es el estado normal.
        if (inactive) ...[
          const SizedBox(width: 8),
          const RancoStatusBadge(
              label: 'Inactiva', tone: RancoStatusTone.muted, dot: true),
        ],
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
      title: Text(editing ? 'Editar categoría' : 'Crear categoría'),
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
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_error!,
                      style: const TextStyle(color: Color(0xFF9A3E36))),
                ),
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
                      final text = error.toString().toLowerCase();
                      setState(() {
                        _saving = false;
                        // Mensaje humano; el detalle técnico queda fuera.
                        _error = text.contains('duplicate') ||
                                text.contains('unique')
                            ? 'Ya existe una categoría con ese slug.'
                            : 'No se pudo guardar la categoría. Revisa los '
                                'datos e intenta nuevamente.';
                      });
                    }
                  }
                },
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
    final users = ref.watch(adminUsersProvider(
        (page: 1, pageSize: 10, search: null, role: null, status: null)));
    return AdminGate(
      child: AdminScaffold(
        title: 'Estadísticas',
        child: summary.when(
          loading: () => const _UsersSkeleton(),
          error: (_, __) => AdminErrorState(
            onRetry: () => ref.invalidate(adminAnalyticsSummaryProvider),
          ),
          // Ancho acotado: en monitores amplios las filas no se estiran.
          data: (counts) => ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Actividad últimos 30 días',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
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
                            (constraints.maxWidth - (columns - 1) * 10) /
                                columns;
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
                      // Sin gráfico inventado: estado compacto hasta tener serie real.
                      const _InfoCallout(
                        icon: Icons.show_chart_rounded,
                        text: 'Aún no hay suficiente actividad para mostrar '
                            'tendencias.',
                      ),
                      const SizedBox(height: 22),
                      Text('Interacciones y plataforma',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  )),
                      const SizedBox(height: 10),
                      // Una lista compacta en vez de tarjetas de anchos mixtos.
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFDCE8E0)),
                        ),
                        child: Column(children: [
                          _MetricLine(
                            icon: Icons.call_outlined,
                            label: 'Clics en teléfono',
                            value: '${counts['CLICK_PHONE'] ?? 0}',
                          ),
                          const Divider(height: 1, indent: 60),
                          _MetricLine(
                            icon: Icons.storefront_outlined,
                            label: 'Negocios publicados',
                            value:
                                stats.valueOrNull?['published']?.toString() ??
                                    '—',
                          ),
                          const Divider(height: 1, indent: 60),
                          _MetricLine(
                            icon: Icons.people_outline,
                            label: 'Usuarios registrados',
                            value: users.valueOrNull?.total.toString() ?? '—',
                          ),
                          const Divider(height: 1, indent: 60),
                          const _MetricLine(
                            icon: Icons.inbox_outlined,
                            label: 'Solicitudes y reservas',
                            value: '—',
                            hint:
                                'Aún no hay una métrica consolidada disponible.',
                          ),
                        ]),
                      ),
                    ],
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

/// Fila métrica: ícono, etiqueta, valor real (o "—" con explicación).
class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE9F3EE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: RancoColors.forest, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: RancoColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                if (hint != null)
                  Text(hint!,
                      style: const TextStyle(
                          color: RancoColors.textSecondary, fontSize: 12.5)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(value,
              style: const TextStyle(
                color: RancoColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              )),
        ]),
      );
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
  const AdminUsersScreen({
    this.actions = const AdminUserActions(),
    super.key,
  });

  /// Acciones sobre cuentas (Codex): sin callbacks quedan deshabilitadas.
  final AdminUserActions actions;

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  int _pageSize = 20;
  int _offset = 0;
  final _search = TextEditingController();
  Timer? _searchDebounce;
  String _committedSearch = '';
  String? _role;
  String? _status;

  Future<void> _changeRole(Map<String, dynamic> user) async {
    if (user['is_anonymous'] == true ||
        !['admin', 'provider'].contains(user['role']?.toString())) {
      return;
    }
    final oldRole = user['role']?.toString();
    final role = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Cambiar rol'),
        children: [
          for (final option in const ['provider', 'admin'])
            if (option != oldRole)
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(option),
                child: Text(adminRoleLabel(option)),
              ),
        ],
      ),
    );
    if (role == null || !mounted) return;
    final confirmed = await _confirmUserAction(
      context,
      title: 'Confirmar cambio de rol',
      message: 'Cambiar el rol de ${user['email'] ?? user['full_name']} a '
          '${adminRoleLabel(role)}?',
      confirmLabel: 'Cambiar rol',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(adminSettingsRepositoryProvider).changeUserRole(
            userId: user['id'].toString(),
            role: role,
          );
      ref.invalidate(adminUsersProvider);
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rol actualizado.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos cambiar el rol.')),
        );
      }
    }
  }

  Future<void> _toggleSuspension(Map<String, dynamic> user) async {
    try {
      await ref.read(adminSettingsRepositoryProvider).setAccountSuspension(
            userId: user['id'].toString(),
            suspended: !_isSuspended(user),
          );
      ref.invalidate(adminUsersProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isSuspended(user)
                ? 'Cuenta reactivada.'
                : 'Cuenta suspendida.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pudimos actualizar la cuenta.')),
        );
      }
    }
  }

  Future<void> _createAdmin(String name, String email) async {
    await ref
        .read(adminSettingsRepositoryProvider)
        .inviteAdministrator(name: name, email: email);
    ref.invalidate(adminUsersProvider);
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    await ref
        .read(adminSettingsRepositoryProvider)
        .deleteUser(user['id'].toString());
    ref.invalidate(adminUsersProvider);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Última página recibida: se mantiene visible (atenuada) mientras llega la
  /// siguiente, para que buscar o cambiar de filtro no haga saltar la vista.
  AdminUsersPage? _lastPage;

  static String _countLabel(int total, String? role) {
    final one = total == 1;
    final noun = switch (role) {
      'CUSTOMER' => one ? 'usuario' : 'usuarios',
      'VISITOR' => one ? 'visitante' : 'visitantes',
      'PROVIDER' => one ? 'prestador' : 'prestadores',
      'ADMIN' => one ? 'administrador' : 'administradores',
      _ => one ? 'cuenta' : 'cuentas',
    };
    return '$total $noun';
  }

  @override
  Widget build(BuildContext context) {
    final query = (
      page: _offset ~/ _pageSize + 1,
      pageSize: _pageSize,
      search: _committedSearch,
      role: _role,
      status: _status
    );
    final users = ref.watch(adminUsersProvider(query));
    if (users.hasValue) _lastPage = users.value;
    final page = users.hasError && !users.isLoading
        ? null
        : users.valueOrNull ?? (users.isLoading ? _lastPage : null);
    final reloading = users.isLoading && page != null;
    final selfId = ref.watch(currentProfileProvider).valueOrNull?.id;
    final mutationsReady =
        ref.watch(adminUserMutationsReadyProvider).valueOrNull == true;
    final actions = !mutationsReady
        ? widget.actions
        : widget.actions.onChangeRole == null ||
                widget.actions.onToggleSuspension == null ||
                widget.actions.onDelete == null
            ? AdminUserActions(
                onChangeRole: widget.actions.onChangeRole ?? _changeRole,
                onToggleSuspension:
                    widget.actions.onToggleSuspension ?? _toggleSuspension,
                onDelete: widget.actions.onDelete ?? _deleteUser,
              )
            : widget.actions;

    final search = AdminSearchField(
      controller: _search,
      hint: 'Buscar por nombre o correo',
      onChanged: (value) {
        _searchDebounce?.cancel();
        _searchDebounce = Timer(
          const Duration(milliseconds: 350),
          () {
            if (!mounted) return;
            setState(() {
              _committedSearch = value.trim();
              _offset = 0;
            });
          },
        );
      },
    );
    final segments = AdminSegmentFilter<String?>(
      options: const [
        (null, 'Todos', null),
        ('PROVIDER', 'Proveedores', null),
        ('ADMIN', 'Administradores', null),
      ],
      selected: _role,
      onSelected: (value) => setState(() {
        _role = value;
        _offset = 0;
      }),
    );

    Widget results() {
      if (page == null) {
        return users.hasError
            ? AdminErrorState(
                key: const ValueKey('error'),
                error: users.error,
                title: 'No pudimos cargar las cuentas.',
                onRetry: () => ref.invalidate(adminUsersProvider(query)),
              )
            : const _UsersSkeleton(key: ValueKey('loading'));
      }
      final items = page.rows;
      final total = page.total;
      return Column(
        key: const ValueKey('data'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isEmpty)
            _UsersEmpty(
              text: _committedSearch.isNotEmpty
                  ? 'Ninguna cuenta coincide con “$_committedSearch”.'
                  : 'No hay cuentas en este filtro.',
            )
          else
            // Escritorio: tabla. Tablet: tabla compacta. Móvil: tarjetas.
            AnimatedOpacity(
              duration: RancoDurations.quick,
              opacity: reloading ? .55 : 1,
              child: LayoutBuilder(builder: (context, constraints) {
                if (constraints.maxWidth < 720) {
                  return Column(children: [
                    for (final user in items)
                      _AdminUserTile(
                        user: user,
                        actions: actions,
                        selfId: selfId,
                      ),
                  ]);
                }
                return _AdminUsersTable(
                  users: items,
                  actions: actions,
                  selfId: selfId,
                  showCreated: constraints.maxWidth >= 980,
                );
              }),
            ),
          // Paginación y filtros resueltos por la RPC administrativa.
          AdminPaginator(
            offset: _offset,
            visibleCount: items.length,
            total: total,
            pageSize: _pageSize,
            onFirst: _offset == 0 ? null : () => setState(() => _offset = 0),
            onLast: _offset + items.length >= total
                ? null
                : () => setState(
                    () => _offset = ((total - 1) ~/ _pageSize) * _pageSize),
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
    }

    return AdminGate(
      child: AdminScaffold(
        title: 'Usuarios',
        // Buscador y filtros fuera del estado de carga: no se reconstruyen ni
        // pierden el foco mientras llega la página.
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            LayoutBuilder(builder: (context, constraints) {
              // Filtro por estado (Codex): mismo valor y efecto, con el
              // estilo de los filtros del panel.
              final status = mutationsReady
                  ? _UserStatusMenu(
                      value: _status,
                      onChanged: (value) => setState(() {
                        _status = value;
                        _offset = 0;
                      }),
                    )
                  : null;
              final create = FilledButton.icon(
                onPressed: () =>
                    showCreateAdminDialog(context, onCreate: _createAdmin),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Crear administrador'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              );
              if (constraints.maxWidth < 900) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(child: search),
                      if (constraints.maxWidth >= 560) ...[
                        const SizedBox(width: 12),
                        create,
                      ],
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: segments),
                      if (status != null) ...[
                        const SizedBox(width: 8),
                        status,
                      ],
                    ]),
                    if (constraints.maxWidth < 560) ...[
                      const SizedBox(height: 10),
                      create,
                    ],
                  ],
                );
              }
              return Row(children: [
                SizedBox(width: 300, child: search),
                const SizedBox(width: 14),
                Expanded(child: segments),
                if (status != null) ...[
                  const SizedBox(width: 10),
                  status,
                ],
                const SizedBox(width: 10),
                create,
              ]);
            }),
            const SizedBox(height: 14),
            SizedBox(
              height: 20,
              child: Row(children: [
                Text(
                  page == null ? '' : _countLabel(page.total, _role),
                  style: const TextStyle(
                    color: RancoColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_committedSearch.isNotEmpty && page != null)
                  Flexible(
                    child: Text(
                      ' · “$_committedSearch”',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: RancoColors.textSecondary, fontSize: 13),
                    ),
                  ),
                const Spacer(),
                // Indicador discreto de recarga (sin spinner de pantalla).
                // Solo existe durante la recarga: un indicador indeterminado
                // oculto seguiría animando.
                AnimatedSwitcher(
                  duration: RancoDurations.quick,
                  child: reloading
                      ? const SizedBox(
                          width: 72,
                          child: LinearProgressIndicator(minHeight: 2),
                        )
                      : const SizedBox(width: 72),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: RancoDurations.quick,
              child: results(),
            ),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDCE8E0)),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: RancoColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_search_outlined,
                color: RancoColors.forest, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: const TextStyle(
                        color: RancoColors.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                const Text('Prueba con otro nombre, correo o filtro.',
                    style: TextStyle(
                        color: RancoColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ]),
      );
}

String _userDisplayName(Map<String, dynamic> user) {
  final name = user['full_name']?.toString().trim();
  return name == null || name.isEmpty ? 'Sin nombre público' : name;
}

String _userRoleLabel(Map<String, dynamic> user) =>
    user['is_anonymous'] == true ? 'Visitante' : adminRoleLabel(user['role']);

/// Avatar con inicial (o ícono si no hay nombre).
class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user, this.size = 34});

  final Map<String, dynamic> user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = user['full_name']?.toString().trim() ?? '';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFE5F1EC),
        shape: BoxShape.circle,
      ),
      child: name.isEmpty
          ? Icon(Icons.person_outline_rounded,
              color: RancoColors.forest, size: size * .55)
          : Text(
              name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                color: RancoColors.primaryDark,
                fontSize: size * .42,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

/// Móvil: tarjeta por cuenta (nombre, correo, rol, estado y menú).
class _AdminUserTile extends StatelessWidget {
  const _AdminUserTile({
    required this.user,
    required this.actions,
    this.selfId,
  });

  final Map<String, dynamic> user;
  final AdminUserActions actions;
  final String? selfId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFDCE8E0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showAdminUserDetail(context, user, actions, selfId),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _UserAvatar(user: user, size: 38),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_userDisplayName(user),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: RancoColors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 1),
                  Text(user['email']?.toString() ?? 'Sin correo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: RancoColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    _AdminTag(label: _userRoleLabel(user)),
                    _AdminTag(
                      label: adminAccountStatusLabel(user['account_status']),
                      color: _accountStatusColor(user['account_status']),
                    ),
                  ]),
                ],
              )),
              _AdminUserMenu(user: user, actions: actions, selfId: selfId),
            ]),
          ),
        ),
      ),
    );
  }
}

class _AdminUsersTable extends StatelessWidget {
  const _AdminUsersTable({
    required this.users,
    required this.actions,
    this.selfId,
    this.showCreated = true,
  });

  final List<Map<String, dynamic>> users;
  final AdminUserActions actions;
  final String? selfId;

  /// Columna "Registro" solo en escritorio amplio (tablet: tabla compacta).
  final bool showCreated;

  @override
  Widget build(BuildContext context) {
    const header = TextStyle(
      color: RancoColors.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: .2,
    );
    Widget row(List<Widget> cells, {double height = 56}) => Container(
          constraints: BoxConstraints(minHeight: height),
          padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
          child: Row(children: [
            Expanded(child: cells[0]),
            SizedBox(width: 136, child: cells[1]),
            SizedBox(width: 118, child: cells[2]),
            if (showCreated) SizedBox(width: 104, child: cells[3]),
            SizedBox(width: 52, child: cells[4]),
          ]),
        );
    // Material propio: el hover y el foco de cada fila se pintan sobre el
    // blanco de la tabla.
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFD6E3DD)),
      ),
      child: Column(children: [
        ColoredBox(
          color: const Color(0xFFF4F8F6),
          child: row(const [
            Text('Usuario', style: header),
            Text('Rol', style: header),
            Text('Estado', style: header),
            Text('Registro', style: header),
            Text('Acciones', style: header, textAlign: TextAlign.center),
          ], height: 40),
        ),
        for (var index = 0; index < users.length; index++) ...[
          const Divider(height: 1, color: Color(0xFFE5EEE9)),
          () {
            final user = users[index];
            final displayName = _userDisplayName(user);
            final email = user['email']?.toString() ?? 'Sin correo';
            final created =
                DateTime.tryParse(user['created_at']?.toString() ?? '');
            return InkWell(
              onTap: () => _showAdminUserDetail(context, user, actions, selfId),
              hoverColor: RancoColors.primary.withValues(alpha: .04),
              child: row([
                Row(children: [
                  _UserAvatar(user: user),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Tooltip(
                      message: '$displayName\n$email',
                      waitDuration: const Duration(milliseconds: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: RancoColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          Text(email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: RancoColors.textSecondary,
                                  fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ]),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _AdminTag(label: _userRoleLabel(user)),
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
                    color: RancoColors.textSecondary,
                    fontSize: 12.5,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Center(
                  child: _AdminUserMenu(
                    user: user,
                    actions: actions,
                    selfId: selfId,
                  ),
                ),
              ]),
            );
          }(),
        ],
      ]),
    );
  }
}

void _showAdminUserDetail(
  BuildContext context,
  Map<String, dynamic> user, [
  AdminUserActions actions = const AdminUserActions(),
  String? selfId,
]) {
  final displayName = _userDisplayName(user);
  final created = DateTime.tryParse(user['created_at']?.toString() ?? '');
  final suspended = _isSuspended(user);
  final role = user['is_anonymous'] == true
      ? 'Visitante anónimo'
      : adminRoleLabel(user['role']);
  final roleBlocked = adminRoleChangeBlockedReason(user, actions);
  final suspensionBlocked = adminSuspensionBlockedReason(user, actions);
  String two(int value) => value.toString().padLeft(2, '0');

  Widget field(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 104,
            child: Text(label,
                style: const TextStyle(
                    color: RancoColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: SelectableText(value,
                style: const TextStyle(
                    color: RancoColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
        ]),
      );
  Widget section(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title.toUpperCase(),
                style: const TextStyle(
                    color: RancoColors.textSecondary,
                    fontSize: 11.5,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ...children,
          ],
        ),
      );

  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 16, 0),
      title: Row(children: [
        _UserAvatar(user: user, size: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Detalle de usuario',
                  style: TextStyle(
                      color: RancoColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: RancoColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _AdminTag(label: role),
                _AdminTag(
                  label: adminAccountStatusLabel(user['account_status']),
                  color: _accountStatusColor(user['account_status']),
                ),
              ]),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Cerrar',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ]),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, minWidth: 320),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              section('Información de cuenta', [
                field('Correo', user['email']?.toString() ?? 'Sin correo'),
                if (created != null)
                  field('Registro',
                      '${two(created.toLocal().day)}/${two(created.toLocal().month)}/${created.toLocal().year}'),
              ]),
              section('Rol y permisos', [
                field('Rol', role),
                field(
                    'Estado', adminAccountStatusLabel(user['account_status'])),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(
                    onPressed: roleBlocked != null
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            actions.onChangeRole!(user);
                          },
                    icon: const Icon(Icons.badge_outlined, size: 18),
                    label: const Text('Cambiar rol'),
                  ),
                  OutlinedButton.icon(
                    onPressed: suspensionBlocked != null
                        ? null
                        : () async {
                            Navigator.of(context).pop();
                            await _runToggleSuspension(context, actions, user);
                          },
                    icon: Icon(
                        suspended
                            ? Icons.lock_open_rounded
                            : Icons.block_outlined,
                        size: 18),
                    label: Text(suspended ? 'Reactivar' : 'Suspender'),
                  ),
                ]),
                for (final reason in {roleBlocked, suspensionBlocked}
                    .whereType<String>()) ...[
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 16, color: RancoColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(reason,
                          style: const TextStyle(
                              color: RancoColors.textSecondary,
                              fontSize: 12.5)),
                    ),
                  ]),
                ],
              ]),
              // Solo datos que el panel recibe hoy: sin última actividad
              // ni negocios inventados.
              section('Actividad', [
                const Text(
                  'La última actividad y los negocios asociados se mostrarán '
                  'cuando estén disponibles para administración.',
                  style: TextStyle(
                      color: RancoColors.textSecondary,
                      fontSize: 13,
                      height: 1.4),
                ),
              ]),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      actions: [
        TextButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            showDeleteUserDialog(context, user,
                onDelete:
                    adminDeletionBlockedReason(user, actions, selfId: selfId) ==
                            null
                        ? actions.onDelete
                        : null);
          },
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF9A3E36),
          ),
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Eliminar usuario'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

/// Motivo visible mientras la creación segura de administradores no exista.
const adminCreationUnavailableHint =
    'Disponible cuando se habilite la creación segura de administradores.';

/// Motivo visible mientras la eliminación segura no exista.
const adminDeletionUnavailableHint =
    'La eliminación de cuentas aún no está habilitada.';

/// Modal "Crear administrador" (FASE 3.25: solo UI). El envío queda
/// deshabilitado hasta que exista la operación segura.
Future<void> showCreateAdminDialog(
  BuildContext context, {
  Future<void> Function(String name, String email)? onCreate,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _CreateAdminDialog(onCreate: onCreate),
  );
}

class _CreateAdminDialog extends StatefulWidget {
  const _CreateAdminDialog({this.onCreate});

  final Future<void> Function(String name, String email)? onCreate;

  @override
  State<_CreateAdminDialog> createState() => _CreateAdminDialogState();
}

class _CreateAdminDialogState extends State<_CreateAdminDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    if (_saving || widget.onCreate == null) return;
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.length < 3 ||
        name.length > 120 ||
        email.length > 254 ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Revisa el nombre y el correo.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onCreate!(name, email);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(
        content: Text('Invitación administrativa enviada.'),
      ));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'No pudimos enviar la invitación. Revisa el correo e inténtalo nuevamente.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Crear administrador'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, minWidth: 300),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'La persona recibirá acceso al panel administrativo.',
                style: TextStyle(
                    color: RancoColors.textSecondary,
                    fontSize: 13.5,
                    height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              // Hoy existe un único rol administrativo asignable.
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                ),
                child: Text(adminRoleLabel('admin')),
              ),
              const SizedBox(height: 14),
              if (widget.onCreate == null)
                const _InfoCallout(text: adminCreationUnavailableHint),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Color(0xFF9A3E36))),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Enviando…' : 'Crear administrador'),
        ),
      ],
    );
  }
}

/// Confirmación destructiva. El servidor conserva las referencias vinculadas.
Future<void> showDeleteUserDialog(
  BuildContext context,
  Map<String, dynamic> user, {
  Future<void> Function(Map<String, dynamic> user)? onDelete,
}) {
  const danger = Color(0xFF9A3E36);
  var saving = false;
  String? error;
  return showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: danger, size: 28),
              title: const Text('Eliminar usuario'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Vas a desactivar la cuenta de '),
                        TextSpan(
                          text: _userDisplayName(user),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const TextSpan(
                            text:
                                '. Se conservarán los registros relacionados para proteger el historial.'),
                      ]),
                      style: const TextStyle(
                          color: RancoColors.textPrimary,
                          fontSize: 14.5,
                          height: 1.45),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBE7E5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 18, color: danger),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                onDelete == null
                                    ? adminDeletionUnavailableHint
                                    : 'La cuenta dejará de tener acceso. Esta acción no se puede deshacer.',
                                style: const TextStyle(
                                    color: danger, fontSize: 13))),
                      ]),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      Text(error!, style: const TextStyle(color: danger)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: onDelete == null || saving
                      ? null
                      : () async {
                          setDialogState(() {
                            saving = true;
                            error = null;
                          });
                          try {
                            await onDelete(user);
                            if (!context.mounted) return;
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.of(context).pop();
                            messenger.showSnackBar(const SnackBar(
                              content: Text(
                                  'Cuenta desactivada y conservada en el historial.'),
                            ));
                          } catch (_) {
                            if (context.mounted) {
                              setDialogState(() => error =
                                  'No pudimos eliminar esta cuenta. Revisa sus permisos e inténtalo nuevamente.');
                            }
                          } finally {
                            if (context.mounted) {
                              setDialogState(() => saving = false);
                            }
                          }
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: danger,
                    disabledBackgroundColor: danger.withValues(alpha: .35),
                    disabledForegroundColor: Colors.white,
                  ),
                  child: Text(saving ? 'Eliminando…' : 'Eliminar usuario'),
                ),
              ],
            )),
  );
}

/// Filtro por estado de cuenta con el estilo de los filtros del panel.
class _UserStatusMenu extends StatelessWidget {
  const _UserStatusMenu({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  static const _options = <(String?, String)>[
    (null, 'Estado: todos'),
    ('active', 'Activos'),
    ('pending', 'Pendientes'),
    ('suspended', 'Suspendidos'),
    ('blocked', 'Bloqueados'),
  ];

  @override
  Widget build(BuildContext context) {
    final label = _options.firstWhere((option) => option.$1 == value).$2;
    return PopupMenuButton<String?>(
      tooltip: 'Filtrar por estado',
      position: PopupMenuPosition.under,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final (option, text) in _options)
          CheckedPopupMenuItem<String?>(
            value: option,
            checked: option == value,
            child: Text(text),
          ),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD6E3DD)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.filter_list_rounded,
              size: 17, color: RancoColors.textSecondary),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: RancoColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600)),
          const Icon(Icons.expand_more_rounded,
              size: 18, color: RancoColors.textSecondary),
        ]),
      ),
    );
  }
}

/// Acciones administrativas sobre una cuenta. La UI queda lista; Codex
/// conecta los callbacks cuando exista la RPC segura (suspensión real,
/// roles, auditoría). Con callback null la acción se muestra deshabilitada
/// con su motivo, nunca como una acción que no hace nada.
class AdminUserActions {
  const AdminUserActions({
    this.onToggleSuspension,
    this.onChangeRole,
    this.onDelete,
  });

  /// Suspender (si está activa) o reactivar (si está suspendida).
  final Future<void> Function(Map<String, dynamic> user)? onToggleSuspension;
  final Future<void> Function(Map<String, dynamic> user)? onChangeRole;
  final Future<void> Function(Map<String, dynamic> user)? onDelete;

  static const unavailableHint =
      'Disponible cuando se habilite la gestión segura de cuentas.';
}

bool _isSuspended(Map<String, dynamic> user) =>
    user['account_status']?.toString().toLowerCase() == 'suspended';

String? adminDeletionBlockedReason(
    Map<String, dynamic> user, AdminUserActions actions,
    {String? selfId}) {
  if (actions.onDelete == null) return AdminUserActions.unavailableHint;
  if (user['id']?.toString() == selfId) {
    return 'No puedes eliminar tu propia cuenta.';
  }
  if (!['admin', 'provider'].contains(user['role']?.toString())) {
    return 'Las cuentas hist?ricas no est?n habilitadas para administraci?n.';
  }
  if (user['account_status']?.toString() == 'deleted') {
    return 'Esta cuenta ya está eliminada.';
  }
  return null;
}

/// Confirmación obligatoria antes de cualquier acción sobre una cuenta.
Future<bool> _confirmUserAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF9A3E36),
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> _runToggleSuspension(
  BuildContext context,
  AdminUserActions actions,
  Map<String, dynamic> user,
) async {
  final callback = actions.onToggleSuspension;
  if (callback == null) return;
  final suspended = _isSuspended(user);
  final confirmed = await _confirmUserAction(
    context,
    title: suspended ? 'Reactivar cuenta' : 'Suspender cuenta',
    message: suspended
        ? 'La cuenta podrá volver a usar Ranco Conecta.'
        : 'La cuenta no podrá usar Ranco Conecta mientras esté suspendida.',
    confirmLabel: suspended ? 'Reactivar' : 'Suspender',
    destructive: !suspended,
  );
  if (confirmed) await callback(user);
}

/// Motivo por el que no se puede cambiar el rol (null = permitido). Refleja
/// las mismas guardas que la pantalla ya aplica; no agrega reglas.
String? adminRoleChangeBlockedReason(
  Map<String, dynamic> user,
  AdminUserActions actions,
) {
  if (actions.onChangeRole == null) return AdminUserActions.unavailableHint;
  if (user['is_anonymous'] == true) {
    return 'Las cuentas de visitante no tienen un rol editable.';
  }
  if (!['admin', 'provider'].contains(user['role']?.toString().toLowerCase())) {
    return 'Las cuentas hist?ricas no tienen un rol de producto editable.';
  }
  return null;
}

/// Motivo por el que no se puede suspender/reactivar (null = permitido).
String? adminSuspensionBlockedReason(
  Map<String, dynamic> user,
  AdminUserActions actions, {
  String? selfId,
}) {
  if (actions.onToggleSuspension == null) {
    return AdminUserActions.unavailableHint;
  }
  if (selfId != null && user['id']?.toString() == selfId) {
    return 'No puedes suspender tu propia cuenta.';
  }
  return null;
}

/// Menú "⋯" de una cuenta: acciones secundarias, siempre con confirmación.
/// Las acciones bloqueadas se muestran deshabilitadas con su motivo.
class _AdminUserMenu extends StatelessWidget {
  const _AdminUserMenu({
    required this.user,
    required this.actions,
    this.selfId,
  });

  final Map<String, dynamic> user;
  final AdminUserActions actions;
  final String? selfId;

  @override
  Widget build(BuildContext context) {
    final suspended = _isSuspended(user);
    final roleBlocked = adminRoleChangeBlockedReason(user, actions);
    final suspensionBlocked =
        adminSuspensionBlockedReason(user, actions, selfId: selfId);
    return PopupMenuButton<String>(
      tooltip: 'Acciones de la cuenta',
      icon: const Icon(Icons.more_horiz_rounded, size: 20),
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      onSelected: (value) async {
        switch (value) {
          case 'view':
            _showAdminUserDetail(context, user, actions, selfId);
          case 'toggle':
            await _runToggleSuspension(context, actions, user);
          case 'role':
            await actions.onChangeRole?.call(user);
          case 'delete':
            await showDeleteUserDialog(context, user,
                onDelete:
                    adminDeletionBlockedReason(user, actions, selfId: selfId) ==
                            null
                        ? actions.onDelete
                        : null);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'view',
          child: _MenuEntry(
            icon: Icons.visibility_outlined,
            label: 'Ver detalle',
          ),
        ),
        PopupMenuItem(
          value: 'role',
          enabled: roleBlocked == null,
          child: _MenuEntry(
            icon: Icons.badge_outlined,
            label: 'Cambiar rol',
            reason: roleBlocked,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'toggle',
          enabled: suspensionBlocked == null,
          child: _MenuEntry(
            icon: suspended ? Icons.lock_open_rounded : Icons.block_outlined,
            label: suspended ? 'Reactivar cuenta' : 'Suspender cuenta',
            reason: suspensionBlocked,
          ),
        ),
        const PopupMenuDivider(),
        // Rojo solo para la acción destructiva.
        PopupMenuItem(
          value: 'delete',
          enabled:
              adminDeletionBlockedReason(user, actions, selfId: selfId) == null,
          child: const _MenuEntry(
            icon: Icons.delete_outline_rounded,
            label: 'Eliminar usuario',
            color: Color(0xFF9A3E36),
          ),
        ),
      ],
    );
  }
}

class _MenuEntry extends StatelessWidget {
  const _MenuEntry({
    required this.icon,
    required this.label,
    this.reason,
    this.color,
  });

  final IconData icon;
  final String label;

  /// Motivo visible bajo la etiqueta cuando la acción está deshabilitada.
  final String? reason;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final disabled = reason != null;
    final tone =
        disabled ? const Color(0xFF9AA8A1) : (color ?? RancoColors.textPrimary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: tone),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: tone,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (disabled) ...[
                  const SizedBox(height: 2),
                  Text(
                    reason!,
                    style: const TextStyle(
                      color: RancoColors.textSecondary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carga: cabecera + filas esqueleto con la altura real de la tabla.
class _UsersSkeleton extends StatelessWidget {
  const _UsersSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Cargando',
        child: Column(
          children: [
            const RancoSkeletonBox(height: 40, radius: 12),
            const SizedBox(height: 6),
            for (var i = 0; i < 6; i++) ...const [
              RancoSkeletonBox(height: 56, radius: 12),
              SizedBox(height: 6),
            ],
          ],
        ),
      );
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
      'blocked' => 'Bloqueado',
      'disabled' || 'inactive' => 'Inactivo',
      'deleted' => 'Eliminado',
      null || '' => 'Sin estado',
      final other => other,
    };

Color _accountStatusColor(Object? status) =>
    switch (status?.toString().toLowerCase()) {
      'active' => RancoColors.forest,
      'pending' => const Color(0xFF8A5B12),
      'suspended' || 'blocked' || 'deleted' => const Color(0xFF9A3E36),
      _ => RancoColors.textSecondary,
    };

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

/// Sección de Configuración. Solo las [available] tienen backend; las demás
/// explican qué incluirán, sin opciones simuladas.
class _SettingsSection {
  const _SettingsSection({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

const _settingsSections = [
  _SettingsSection(label: 'General', icon: Icons.tune_rounded),
  _SettingsSection(label: 'WhatsApp', icon: Icons.chat_outlined),
  _SettingsSection(
      label: 'Notificaciones', icon: Icons.notifications_none_rounded),
  _SettingsSection(label: 'Integraciones', icon: Icons.extension_outlined),
];

/// Pestañas de Configuración con indicador verde (FASE 3.25: todas tienen
/// contenido o un estado honesto; sin badges "Pronto").
class _SettingsSectionNav extends StatelessWidget {
  const _SettingsSectionNav({
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFDFE9E4))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var index = 0; index < _settingsSections.length; index++)
              _SettingsTab(
                section: _settingsSections[index],
                selected: index == selected,
                onTap: () => onSelected(index),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final _SettingsSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? RancoColors.primaryDark : RancoColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: section.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: selected ? null : onTap,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        child: AnimatedContainer(
          duration: RancoDurations.quick,
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? RancoColors.forest : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(section.icon, size: 17, color: color),
              const SizedBox(width: 7),
              Text(
                section.label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Evento seleccionable: casilla + título + descripción breve.
class _EventOption extends StatelessWidget {
  const _EventOption({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: value ? const Color(0xFFF2F8F5) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: value
              ? RancoColors.forest.withValues(alpha: .45)
              : const Color(0xFFDCE8E0),
        ),
      ),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: value,
                onChanged: (next) => onChanged(next ?? false),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: RancoColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              color: RancoColors.textSecondary,
                              fontSize: 12.5,
                              height: 1.3)),
                    ],
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

/// Carga de Configuración con la forma real (estado + bloque editable).
class _SettingsSkeleton extends StatelessWidget {
  const _SettingsSkeleton();

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Cargando',
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RancoSkeletonBox(width: 300, height: 18),
            SizedBox(height: 8),
            RancoSkeletonBox(width: 380, height: 12),
            SizedBox(height: 16),
            RancoSkeletonBox(height: 64, radius: 14),
            SizedBox(height: 16),
            RancoSkeletonBox(height: 320, radius: 16),
          ],
        ),
      );
}

/// Bloque de Configuración: título, descripción y filas.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.children,
    this.description,
  });

  final String title;
  final String? description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // Material propio: los SwitchListTile pintan su feedback sobre él.
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFDCE8E0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: RancoColors.textPrimary,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800)),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(description!,
                        style: const TextStyle(
                            color: RancoColors.textSecondary, fontSize: 13)),
                  ],
                ],
              ),
            ),
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                const Divider(height: 1, indent: 18, color: Color(0xFFE8EFEB)),
              children[i],
            ],
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

/// Fila informativa: etiqueta, ayuda opcional y valor (o "No configurado").
class _SettingsValueRow extends StatelessWidget {
  const _SettingsValueRow({
    required this.label,
    this.value,
    this.hint,
    this.onTap,
  });

  final String label;

  /// `null` → "No configurado".
  final String? value;
  final String? hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final configured = value != null && value!.trim().isNotEmpty;
    return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: RancoColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    if (hint != null)
                      Text(hint!,
                          style: const TextStyle(
                              color: RancoColors.textSecondary,
                              fontSize: 12.5)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: configured
                    ? Text(value!,
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: RancoColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700))
                    : const RancoStatusBadge(
                        label: 'No configurado',
                        tone: RancoStatusTone.muted,
                      ),
              ),
            ],
          ),
        ));
  }
}

/// General: solo valores que ya existen en la app; el resto, "No
/// configurado" (sin inventar funciones ni datos).
class _GeneralSettings extends ConsumerStatefulWidget {
  const _GeneralSettings();

  @override
  ConsumerState<_GeneralSettings> createState() => _GeneralSettingsState();
}

class _GeneralSettingsState extends ConsumerState<_GeneralSettings> {
  String _email = '';
  String _whatsapp = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values =
          await ref.read(adminSettingsRepositoryProvider).getContactChannels();
      if (!mounted) return;
      setState(() {
        _email = values['email'] ?? '';
        _whatsapp = values['whatsapp'] ?? '';
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'No se pudo cargar la configuración de contacto.');
      }
    }
  }

  Future<void> _editChannels() async {
    final email = TextEditingController(text: _email);
    final whatsapp = TextEditingController(text: _whatsapp);
    final form = GlobalKey<FormState>();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Canales de contacto'),
        content: Form(
            key: form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                  controller: email,
                  decoration:
                      const InputDecoration(labelText: 'Correo de contacto'),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    return text.length <= 254 &&
                            RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)
                        ? null
                        : 'Correo no válido.';
                  }),
              TextFormField(
                  controller: whatsapp,
                  decoration:
                      const InputDecoration(labelText: 'WhatsApp de contacto'),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return null;
                    return RegExp(r'^\+?[1-9][0-9]{7,14}$').hasMatch(text)
                        ? null
                        : 'Número internacional no válido.';
                  }),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(
                      context, (email.text.trim(), whatsapp.text.trim()));
                }
              },
              child: const Text('Guardar'))
        ],
      ),
    );
    // The dialog remains mounted during its reverse route animation.
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      email.dispose();
      whatsapp.dispose();
    });
    if (result == null || !mounted) return;
    try {
      await ref
          .read(adminSettingsRepositoryProvider)
          .saveContactChannels(result.$1, result.$2);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudieron guardar los canales.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SettingsGroup(
          title: 'Información de la plataforma',
          description: 'Datos con los que se presenta Ranco Conecta.',
          children: [
            _SettingsValueRow(
                label: 'Nombre de la plataforma', value: 'Ranco Conecta'),
            _SettingsValueRow(
                label: 'Zona principal', value: 'Lago Ranco, Chile'),
            _SettingsValueRow(
              label: 'Estado de la plataforma',
              hint: 'Mensaje de mantenimiento o aviso general.',
            ),
          ],
        ),
        _SettingsGroup(
          title: 'Contacto y soporte',
          description: 'Canales que se muestran en Contacto.',
          children: [
            _SettingsValueRow(
                label: 'Correo de contacto',
                value: _email.isEmpty ? null : _email,
                onTap: _editChannels),
            _SettingsValueRow(
                label: 'WhatsApp de contacto',
                value: _whatsapp.isEmpty ? null : '+$_whatsapp',
                onTap: _editChannels),
          ],
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        const _SettingsGroup(
          title: 'Operación',
          description: 'Cómo se incorporan nuevos negocios.',
          children: [
            _SettingsValueRow(
              label: 'Revisión de negocios',
              hint: 'Cada publicación pasa por revisión antes de aparecer.',
              value: 'Manual por administración',
            ),
            _SettingsValueRow(
              label: 'Recepción de nuevas publicaciones',
              hint: 'Pausar temporalmente el registro de negocios.',
            ),
          ],
        ),
      ],
    );
  }
}

/// Notificaciones administrativas: vista previa de las opciones. Los
/// cambios aún no se guardan (se indica de forma explícita).
class _NotificationSettingsPreview extends ConsumerStatefulWidget {
  const _NotificationSettingsPreview();

  @override
  ConsumerState<_NotificationSettingsPreview> createState() =>
      _NotificationSettingsPreviewState();
}

class _NotificationSettingsPreviewState
    extends ConsumerState<_NotificationSettingsPreview> {
  static const _groups = <(String, List<(String, String)>)>[
    (
      'Negocios',
      [
        ('Nuevo negocio pendiente', 'Una publicación espera revisión.'),
        ('Solicitud de modificación', 'Un negocio pide revisar cambios.'),
        ('Negocio reportado', 'Alguien reportó una publicación.'),
      ],
    ),
    (
      'Usuarios',
      [
        ('Nuevo prestador registrado', 'Se creó un acceso de prestador.'),
        ('Cuenta suspendida', 'Un administrador suspendió una cuenta.'),
      ],
    ),
    (
      'Plataforma',
      [
        ('Mensaje de contacto recibido', 'Llegó un mensaje desde Contacto.'),
      ],
    ),
  ];

  static const _keys = <String, String>{
    'Nuevo negocio pendiente': 'notify_new_business',
    'Solicitud de modificación': 'notify_business_changes',
    'Mensaje de contacto recibido': 'notify_contact_message',
  };
  Map<String, bool> _values = {};
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await ref
          .read(adminSettingsRepositoryProvider)
          .getNotificationSettings();
      if (mounted) {
        setState(() {
          _values = values;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudieron cargar las preferencias.');
      }
    }
  }

  Future<void> _change(String key, bool value) async {
    if (_saving) return;
    final previous = Map<String, bool>.from(_values);
    setState(() {
      _values[key] = value;
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(adminSettingsRepositoryProvider)
          .saveNotificationSettings(_values);
    } catch (_) {
      if (mounted) {
        setState(() {
          _values = previous;
          _error = 'No se pudo guardar la preferencia.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _InfoCallout(
          icon: Icons.notifications_outlined,
          text: 'Elige qué eventos generan avisos administrativos. '
              'Los eventos sin generación activa aún no se pueden configurar.',
        ),
        const SizedBox(height: 14),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.red)),
        for (final (title, options) in _groups)
          _SettingsGroup(
            title: title,
            children: [
              for (final (label, description) in options)
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                  title: Text(label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(description),
                  value: _values[_keys[label]] ?? false,
                  onChanged: _keys[label] == null || _saving
                      ? null
                      : (value) => _change(_keys[label]!, value),
                ),
            ],
          ),
      ],
    );
  }
}

/// Integraciones: no hay ninguna real configurada; estado vacío honesto,
/// sin botones de "conectar".
class _IntegrationsEmpty extends StatelessWidget {
  const _IntegrationsEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE8E0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: RancoColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.extension_outlined,
                color: RancoColors.forest, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No hay integraciones configuradas.',
                    style: TextStyle(
                        color: RancoColors.textPrimary,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text(
                  'Cuando se conecte un servicio externo, aparecerá aquí con '
                  'su estado.',
                  style: TextStyle(
                      color: RancoColors.textSecondary,
                      fontSize: 13.5,
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
