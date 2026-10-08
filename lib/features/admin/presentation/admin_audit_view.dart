import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/ranco_segmented_control.dart';
import '../../../core/widgets/ranco_states.dart';
import '../../../core/widgets/ranco_status_badge.dart';
import '../../../theme/ranco_colors.dart';
import '../../../theme/ranco_tokens.dart';
import '../application/admin_providers.dart';
import 'admin_error_state.dart';
import 'admin_ui.dart';

/// Historial de auditoría (FASE 3.22A). Presenta las filas reales de
/// `audit_logs` que entrega `adminAuditEventsProvider` (las 50 más recientes).
/// Búsqueda, filtros y paginación operan sobre esas filas en el cliente; no
/// hay consultas nuevas.

/// Etiqueta humana de una acción registrada. Códigos desconocidos se
/// muestran legibles (sin guiones bajos) en vez de ocultarse.
String adminAuditActionLabel(String? action) {
  final code = (action ?? '').trim().toLowerCase();
  return switch (code) {
    'business_created' => 'Negocio creado',
    'business_submitted' => 'Enviado a revisión',
    'business_published' => 'Negocio publicado',
    'business_changes_requested' => 'Cambios solicitados',
    'business_rejected' => 'Negocio rechazado',
    'business_suspended' => 'Negocio suspendido',
    'business_restored' => 'Negocio restaurado',
    'user_role_changed' => 'Rol actualizado',
    'user_suspended' => 'Cuenta suspendida',
    'user_reactivated' => 'Cuenta reactivada',
    'provider_identity_registered' => 'Alta como prestador',
    'category_created' => 'Categoría creada',
    'category_updated' => 'Categoría editada',
    'category_deactivated' => 'Categoría desactivada',
    'category_reactivated' => 'Categoría reactivada',
    'category_deleted' => 'Categoría eliminada',
    'admin_settings_updated' => 'Configuración actualizada',
    '' => 'Acción',
    _ => _humanize(code),
  };
}

/// Recurso afectado según `entity_type`.
String adminAuditResourceLabel(String? entityType) {
  return switch ((entityType ?? '').toLowerCase()) {
    'business' => 'Negocio',
    'profile' => 'Cuenta',
    'category' => 'Categoría',
    'system_settings' => 'Configuración',
    '' => 'Recurso',
    final other => _humanize(other),
  };
}

/// Resultado visible derivado de la acción (el registro solo existe cuando
/// la acción se completó).
(String, RancoStatusTone) adminAuditResult(String? action) {
  final code = (action ?? '').toLowerCase();
  if (code.endsWith('_rejected') ||
      code.endsWith('_suspended') ||
      code.endsWith('_deleted') ||
      code.endsWith('_deactivated')) {
    return ('Restringido', RancoStatusTone.danger);
  }
  if (code.endsWith('_changes_requested') || code.endsWith('_submitted')) {
    return ('Pendiente', RancoStatusTone.warning);
  }
  if (code.endsWith('_published') ||
      code.endsWith('_restored') ||
      code.endsWith('_reactivated')) {
    return ('Activo', RancoStatusTone.success);
  }
  return ('Registrado', RancoStatusTone.neutral);
}

String _humanize(String code) {
  final text = code.replaceAll(RegExp(r'[_.]+'), ' ').trim();
  if (text.isEmpty) return 'Acción';
  return text[0].toUpperCase() + text.substring(1);
}

String _shortId(Object? id) {
  final value = id?.toString() ?? '';
  if (value.isEmpty) return '—';
  return value.length <= 8 ? value : value.substring(0, 8);
}

/// "Negocio · 1a2b3c4d"; sin ID (p. ej. configuración) solo el recurso.
String _resourceText(Map<String, dynamic> row) {
  final label = adminAuditResourceLabel(row['entity_type']?.toString());
  final id = row['entity_id']?.toString() ?? '';
  return id.isEmpty ? label : '$label · ${_shortId(id)}';
}

String _actorLabel(Object? actorId) =>
    actorId == null ? 'Sistema' : 'Usuario ${_shortId(actorId)}';

String _formatDate(DateTime? date) {
  if (date == null) return '—';
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

enum _AuditResource { all, business, profile, category, settings }

enum _AuditPeriod { all, today, week, month }

class AdminAuditView extends ConsumerStatefulWidget {
  const AdminAuditView({super.key});

  @override
  ConsumerState<AdminAuditView> createState() => _AdminAuditViewState();
}

class _AdminAuditViewState extends ConsumerState<AdminAuditView> {
  final _search = TextEditingController();
  String _query = '';
  _AuditResource _resource = _AuditResource.all;
  _AuditPeriod _period = _AuditPeriod.all;
  int _offset = 0;
  int _pageSize = 20;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _resource = _AuditResource.all;
      _period = _AuditPeriod.all;
      _offset = 0;
    });
  }

  List<Map<String, dynamic>> _apply(List<Map<String, dynamic>> rows) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final since = switch (_period) {
      _AuditPeriod.all => null,
      _AuditPeriod.today => today,
      _AuditPeriod.week => today.subtract(const Duration(days: 6)),
      _AuditPeriod.month => today.subtract(const Duration(days: 29)),
    };
    final query = _query.toLowerCase();
    return [
      for (final row in rows)
        if (_matchesResource(row) &&
            _matchesPeriod(row, since) &&
            (query.isEmpty || _haystack(row).contains(query)))
          row,
    ];
  }

  bool _matchesResource(Map<String, dynamic> row) {
    final type = row['entity_type']?.toString().toLowerCase();
    return switch (_resource) {
      _AuditResource.all => true,
      _AuditResource.business => type == 'business',
      _AuditResource.profile => type == 'profile',
      _AuditResource.category => type == 'category',
      _AuditResource.settings => type == 'system_settings',
    };
  }

  bool _matchesPeriod(Map<String, dynamic> row, DateTime? since) {
    if (since == null) return true;
    final date = DateTime.tryParse(row['created_at']?.toString() ?? '');
    return date != null && !date.toLocal().isBefore(since);
  }

  String _haystack(Map<String, dynamic> row) => [
        adminAuditActionLabel(row['action']?.toString()),
        row['action'],
        adminAuditResourceLabel(row['entity_type']?.toString()),
        row['entity_id'],
        row['actor_id'],
      ].whereType<Object>().join(' ').toLowerCase();

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(adminAuditEventsProvider);
    final rows = events.valueOrNull ?? const <Map<String, dynamic>>[];
    final visible = _apply(rows);
    final page = visible.skip(_offset).take(_pageSize).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        _AuditSummary(loaded: events.hasValue, count: rows.length),
        const SizedBox(height: 16),
        _filters(),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: RancoDurations.quick,
          child: events.when(
            loading: () => const _AuditSkeleton(key: ValueKey('loading')),
            error: (error, _) => AdminErrorState(
              key: const ValueKey('error'),
              error: error,
              title: 'No pudimos cargar el historial.',
              onRetry: () => ref.invalidate(adminAuditEventsProvider),
            ),
            data: (_) {
              if (rows.isEmpty) {
                return const _AuditEmpty(
                  key: ValueKey('empty'),
                  title: 'No hay acciones registradas todavía.',
                  message: 'Aprobaciones, rechazos, cambios de configuración '
                      'y gestión de usuarios aparecerán aquí.',
                );
              }
              if (visible.isEmpty) {
                return _AuditEmpty(
                  key: const ValueKey('no-match'),
                  title: 'Ninguna acción coincide con los filtros.',
                  message: 'Prueba con otro término o amplía el período.',
                  actionLabel: 'Limpiar filtros',
                  onAction: _clearFilters,
                );
              }
              return Column(
                key: ValueKey('data-$_offset-$_pageSize-${visible.length}'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth >= 760
                            ? _AuditTable(rows: page)
                            : _AuditTimeline(rows: page),
                  ),
                  AdminPaginator(
                    offset: _offset,
                    visibleCount: page.length,
                    total: visible.length,
                    pageSize: _pageSize,
                    onPageSizeChanged: (size) => setState(() {
                      _pageSize = size;
                      _offset = 0;
                    }),
                    onPrevious: _offset == 0
                        ? null
                        : () => setState(() => _offset -= _pageSize),
                    onNext: _offset + page.length >= visible.length
                        ? null
                        : () => setState(() => _offset += _pageSize),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filters() {
    final search = AdminSearchField(
      controller: _search,
      hint: 'Buscar acción, recurso o ID',
      onChanged: (value) => setState(() {
        _query = value.trim();
        _offset = 0;
      }),
    );
    final resource = RancoSegmentedControl<_AuditResource>(
      segments: const [
        RancoSegment(value: _AuditResource.all, label: 'Todo'),
        RancoSegment(value: _AuditResource.business, label: 'Negocios'),
        RancoSegment(value: _AuditResource.profile, label: 'Cuentas'),
        RancoSegment(value: _AuditResource.category, label: 'Categorías'),
        RancoSegment(value: _AuditResource.settings, label: 'Configuración'),
      ],
      selected: _resource,
      onChanged: (value) => setState(() {
        _resource = value;
        _offset = 0;
      }),
    );
    final period = _PeriodMenu(
      value: _period,
      onChanged: (value) => setState(() {
        _period = value;
        _offset = 0;
      }),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 980) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child:
                        Align(alignment: Alignment.centerLeft, child: resource),
                  ),
                  const SizedBox(width: 8),
                  period,
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: search,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Se desplaza en horizontal si no cabe completo.
            Flexible(
              flex: 2,
              child: Align(alignment: Alignment.centerLeft, child: resource),
            ),
            const SizedBox(width: 12),
            period,
          ],
        );
      },
    );
  }
}

class _AuditSummary extends StatelessWidget {
  const _AuditSummary({required this.loaded, required this.count});

  final bool loaded;
  final int count;

  static const _covered = [
    'Aprobaciones',
    'Rechazos',
    'Cambios de configuración',
    'Gestión de usuarios',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const RancoStatusBadge(
          label: 'Registro activo',
          tone: RancoStatusTone.success,
          dot: true,
        ),
        if (loaded)
          Text(
            count == 0
                ? 'Sin acciones aún'
                : 'Últimas $count ${count == 1 ? 'acción' : 'acciones'}',
            style: const TextStyle(
              color: RancoColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        const Text(
          '·',
          style: TextStyle(color: RancoColors.textSecondary),
        ),
        const Text(
          'Cubre:',
          style: TextStyle(color: RancoColors.textSecondary, fontSize: 13),
        ),
        for (final item in _covered)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              item,
              style: const TextStyle(
                color: RancoColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _PeriodMenu extends StatelessWidget {
  const _PeriodMenu({required this.value, required this.onChanged});

  final _AuditPeriod value;
  final ValueChanged<_AuditPeriod> onChanged;

  static String label(_AuditPeriod period) => switch (period) {
        _AuditPeriod.all => 'Todo el período',
        _AuditPeriod.today => 'Hoy',
        _AuditPeriod.week => 'Últimos 7 días',
        _AuditPeriod.month => 'Últimos 30 días',
      };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AuditPeriod>(
      tooltip: 'Filtrar por fecha',
      initialValue: value,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        for (final option in _AuditPeriod.values)
          CheckedPopupMenuItem(
            value: option,
            checked: option == value,
            child: Text(label(option)),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: RancoColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label(value),
              style: const TextStyle(
                color: RancoColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded,
                size: 18, color: RancoColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

const _columns = [
  ('Fecha', 2),
  ('Actor', 2),
  ('Acción', 3),
  ('Recurso', 3),
  ('Resultado', 2),
];

class _AuditTable extends StatelessWidget {
  const _AuditTable({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    const header = TextStyle(
      color: RancoColors.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w700,
    );
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFD6E3DD)),
      ),
      child: Column(
        children: [
          Container(
            color: const Color(0xFFF4F8F6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                for (final (label, flex) in _columns)
                  Expanded(flex: flex, child: Text(label, style: header)),
              ],
            ),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFE8EFEB)),
            _AuditRow(row: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final action = row['action']?.toString();
    final (result, tone) = adminAuditResult(action);
    const cell = TextStyle(color: RancoColors.textPrimary, fontSize: 13);
    const muted = TextStyle(color: RancoColors.textSecondary, fontSize: 12.5);
    return InkWell(
      onTap: () {},
      mouseCursor: SystemMouseCursors.basic,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  _formatDate(
                      DateTime.tryParse(row['created_at']?.toString() ?? '')),
                  style: muted.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Tooltip(
                  message: row['actor_id']?.toString() ?? 'Acción del sistema',
                  child: Text(_actorLabel(row['actor_id']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: cell),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  adminAuditActionLabel(action),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: cell.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                flex: 3,
                child: Tooltip(
                  message: row['entity_id']?.toString() ?? '',
                  child: Text(
                    _resourceText(row),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: cell,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: RancoStatusBadge(label: result, tone: tone),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Móvil: línea de tiempo compacta (acción, recurso, actor y fecha).
class _AuditTimeline extends StatelessWidget {
  const _AuditTimeline({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 20,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: RancoColors.forest,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (i < rows.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.only(top: 4),
                            color: const Color(0xFFDCE8E1),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TimelineCard(row: rows[i]),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final action = row['action']?.toString();
    final (result, tone) = adminAuditResult(action);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE8E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  adminAuditActionLabel(action),
                  style: const TextStyle(
                    color: RancoColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RancoStatusBadge(label: result, tone: tone),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_resourceText(row)} · ${_actorLabel(row['actor_id'])}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: RancoColors.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 2),
          Text(
            _formatDate(DateTime.tryParse(row['created_at']?.toString() ?? '')),
            style:
                const TextStyle(color: RancoColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AuditEmpty extends StatelessWidget {
  const _AuditEmpty({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE8E0)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: RancoColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.history_rounded,
                color: RancoColors.forest, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: RancoColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                      color: RancoColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _AuditSkeleton extends StatelessWidget {
  const _AuditSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: const Column(
        children: [
          RancoSkeletonBox(height: 42, radius: 12),
          SizedBox(height: 8),
          RancoSkeletonBox(height: 52, radius: 12),
          SizedBox(height: 8),
          RancoSkeletonBox(height: 52, radius: 12),
          SizedBox(height: 8),
          RancoSkeletonBox(height: 52, radius: 12),
          SizedBox(height: 8),
          RancoSkeletonBox(height: 52, radius: 12),
        ],
      ),
    );
  }
}
