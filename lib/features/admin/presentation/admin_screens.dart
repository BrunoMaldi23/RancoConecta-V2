import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../core/widgets/ranco_brand.dart';
import '../../../core/widgets/ranco_status_badge.dart';
import '../../../features/businesses/application/business_providers.dart';
import '../../../features/categories/application/category_providers.dart';
import '../../../features/provider_dashboard/data/business_media_repository.dart';
import '../../../shared/models/business.dart';
import '../../../shared/models/profile.dart';
import '../../../core/widgets/ranco_segmented_control.dart';
import '../../../theme/ranco_tokens.dart';
import '../../../theme/ranco_colors.dart';
import '../application/admin_review_policy.dart';
import '../application/admin_providers.dart';
import '../data/admin_business_review_repository.dart';
import 'admin_error_state.dart';
import 'admin_ui.dart';
import 'admin_audit_view.dart';
import '../../../core/widgets/ranco_states.dart';

class AdminWorkspaceShell extends StatelessWidget {
  const AdminWorkspaceShell({
    required this.path,
    required this.child,
    super.key,
  });

  final String path;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: AdminScaffold(
        title: adminModuleTitle(path),
        child: _AdminWorkspaceScope(child: child),
      ),
    );
  }
}

String adminModuleTitle(String path) {
  if (path.startsWith('/admin/businesses/') &&
      path != '/admin/businesses/pending') {
    return 'Admin / Negocios / Revisión';
  }
  if (path.startsWith('/admin/businesses')) return 'Admin / Negocios';
  if (path.startsWith('/admin/users')) return 'Admin / Usuarios';
  if (path.startsWith('/admin/categories')) return 'Admin / Categorías';
  if (path.startsWith('/admin/settings')) return 'Admin / Configuración';
  if (path.startsWith('/admin/analytics')) return 'Admin / Estadísticas';
  if (path.startsWith('/admin/audit')) return 'Admin / Auditoría';
  return 'Admin / Resumen';
}

class _AdminWorkspaceScope extends InheritedWidget {
  const _AdminWorkspaceScope({required super.child});

  @override
  bool updateShouldNotify(_AdminWorkspaceScope oldWidget) => false;

  static bool isActive(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AdminWorkspaceScope>() !=
      null;
}

class AdminGate extends ConsumerWidget {
  const AdminGate({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_AdminWorkspaceScope.isActive(context)) return child;
    final role = ref.watch(currentAdminRoleProvider);

    return role.when(
      data: (role) {
        if (role == null || !role.canAccessAdmin) {
          return Scaffold(
            backgroundColor: RancoColors.canvas,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: RancoColors.forest,
                      size: 44,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No tienes acceso administrativo.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: () => context.go('/'),
                      child: const Text('Volver al inicio'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return child;
      },
      // Esqueleto en vez de spinner: misma superficie que el panel.
      loading: () => const Scaffold(
        backgroundColor: RancoColors.canvas,
        body: RancoLoadingState(rows: 4, rowHeight: 72, maxWidth: 1100),
      ),
      error: (_, __) => Scaffold(
        body: AdminErrorState(
          onRetry: () => ref.invalidate(currentAdminRoleProvider),
        ),
      ),
    );
  }
}

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminReviewStatsProvider);
    final users = ref.watch(adminUsersProvider(
        (page: 1, pageSize: 10, search: null, role: null, status: null)));
    final categories = ref.watch(categoriesProvider);
    final whatsapp = ref.watch(adminWhatsAppSettingsProvider);
    final activity = ref.watch(adminAnalyticsSummaryProvider);
    final pendingPage = ref.watch(adminBusinessReviewPageProvider((
      status: BusinessPublicationStatus.pendingReview,
      businessType: null,
      search: null,
      limit: 5,
      offset: 0,
    )));

    return AdminGate(
      child: AdminScaffold(
        title: 'Admin / Resumen',
        child: Builder(
          builder: (context) {
            // KPI: si el backend aún no responde o falla, se muestra "—"
            // (nunca un 0 que no es real). El resto del panel sigue usable.
            final items = stats.valueOrNull;
            int? stat(String key) => items == null ? null : items[key] ?? 0;
            final pending = stat('pending_review');
            final published = stat('published');
            final rejected = stat('rejected');
            final totalUsers = users.valueOrNull?.total;
            final kpiHint =
                stats.isLoading ? 'Cargando…' : 'No disponible temporalmente';
            final categoryCount = categories.valueOrNull?.length;
            final whatsappSettings = whatsapp.valueOrNull;
            final whatsappConfigured =
                whatsappSettings != null && whatsappSettings.number.isNotEmpty;
            final mobile = MediaQuery.sizeOf(context).width < 600;

            return ListView(
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                // Móvil: lo que requiere atención va primero.
                if (mobile) ...[
                  _PendingReviewsPanel(
                    page: pendingPage,
                    onRetry: () =>
                        ref.invalidate(adminBusinessReviewPageProvider),
                  ),
                  const SizedBox(height: 18),
                ],
                // Aviso solo si los avisos WhatsApp no están operativos:
                // requiere una decisión; si están bien, no ocupa espacio.
                if (whatsappSettings != null &&
                    (!whatsappConfigured || !whatsappSettings.enabled)) ...[
                  _DashboardAlert(
                    message: whatsappConfigured
                        ? 'Los avisos por WhatsApp están desactivados.'
                        : 'Falta configurar el número para avisos por '
                            'WhatsApp.',
                    actionLabel: 'Configurar',
                    onAction: () => context.push('/admin/settings'),
                  ),
                  const SizedBox(height: 16),
                ],
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Fila KPI: 4 en desktop, 2 en tablet/móvil.
                    final columns = constraints.maxWidth >= 860 ? 4 : 2;
                    final tileWidth =
                        (constraints.maxWidth - (columns - 1) * 12) / columns;
                    const tileHeight = 72.0;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                            width: tileWidth,
                            height: tileHeight,
                            child: _StatCard(
                              label: 'Pendientes',
                              unavailableHint: kpiHint,
                              count: pending,
                              detail: 'Negocios esperando revisión',
                              icon: Icons.hourglass_top_outlined,
                              tone: const Color(0xFF8A5B12),
                              onTap: () =>
                                  context.push('/admin/businesses/pending'),
                            )),
                        SizedBox(
                            width: tileWidth,
                            height: tileHeight,
                            child: _StatCard(
                              label: 'Publicados',
                              unavailableHint: kpiHint,
                              count: published,
                              detail: 'Visibles en la plataforma',
                              icon: Icons.public_outlined,
                              tone: RancoColors.forest,
                              onTap: () => context.push(
                                '/admin/businesses?status=published',
                              ),
                            )),
                        SizedBox(
                            width: tileWidth,
                            height: tileHeight,
                            child: _StatCard(
                              label: 'Rechazados',
                              unavailableHint: kpiHint,
                              count: rejected,
                              detail: 'Estado actual',
                              icon: Icons.block_outlined,
                              tone: const Color(0xFF9A3E36),
                              onTap: () => context.push(
                                '/admin/businesses?status=rejected',
                              ),
                            )),
                        SizedBox(
                            width: tileWidth,
                            height: tileHeight,
                            child: _StatCard(
                              label: 'Usuarios',
                              unavailableHint: users.isLoading
                                  ? 'Cargando…'
                                  : 'No disponible temporalmente',
                              count: totalUsers,
                              detail: 'Cuentas registradas',
                              icon: Icons.people_outline,
                              tone: RancoColors.forest,
                              onTap: () => context.push('/admin/users'),
                            )),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final pendingPanel = _PendingReviewsPanel(
                      page: pendingPage,
                      onRetry: () =>
                          ref.invalidate(adminBusinessReviewPageProvider),
                    );
                    final activityPanel = _RecentActivityPanel(
                      activity: activity,
                      onRetry: () =>
                          ref.invalidate(adminAnalyticsSummaryProvider),
                    );
                    if (mobile) return activityPanel;
                    if (constraints.maxWidth < 900) {
                      return Column(children: [
                        pendingPanel,
                        const SizedBox(height: 12),
                        activityPanel,
                      ]);
                    }
                    return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 8, child: pendingPanel),
                          const SizedBox(width: 12),
                          Expanded(flex: 5, child: activityPanel),
                        ]);
                  },
                ),
                const SizedBox(height: 24),
                _QuickAccessRow(categoryCount: categoryCount),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Aviso operativo compacto (ámbar suave) con una sola acción.
class _DashboardAlert extends StatelessWidget {
  const _DashboardAlert({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1DDB5)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded,
            size: 19, color: Color(0xFF7A4F0E)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  color: Color(0xFF5E3F0B),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600)),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ]),
    );
  }
}

/// Accesos rápidos: enlaces compactos a los módulos (el sidebar ya los
/// lista; aquí solo se ofrece un atajo liviano, sin tarjetas grandes).
class _QuickAccessRow extends StatelessWidget {
  const _QuickAccessRow({required this.categoryCount});

  final int? categoryCount;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      (Icons.storefront_outlined, 'Negocios', '/admin/businesses'),
      (Icons.people_outline, 'Usuarios', '/admin/users'),
      (
        Icons.category_outlined,
        categoryCount == null ? 'Categorías' : 'Categorías · $categoryCount',
        '/admin/categories'
      ),
      (Icons.insights_outlined, 'Estadísticas', '/admin/analytics'),
      (Icons.history_rounded, 'Auditoría', '/admin/audit'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Accesos rápidos',
          style: TextStyle(
            color: RancoColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (icon, label, route) in items)
              OutlinedButton.icon(
                onPressed: () => context.go(route),
                icon: Icon(icon, size: 18),
                label: Text(label),
                style: OutlinedButton.styleFrom(
                  foregroundColor: RancoColors.textPrimary,
                  backgroundColor: Colors.white,
                  minimumSize: const Size(0, 40),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDCE8E0)),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A173E2E), blurRadius: 12, offset: Offset(0, 3)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: RancoColors.textPrimary,
                                  )),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: RancoColors.textSecondary)),
                    ]),
              ),
              if (action != null) ...[
                const SizedBox(width: 10),
                action!,
              ],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ]),
      );
}

class _PendingReviewsPanel extends StatelessWidget {
  const _PendingReviewsPanel({required this.page, required this.onRetry});

  final AsyncValue<AdminBusinessReviewPage> page;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _DashboardPanel(
        title: 'Revisiones pendientes',
        subtitle: 'Últimas solicitudes recibidas',
        action: TextButton(
          onPressed: () => context.push('/admin/businesses/pending'),
          child: const Text('Ver todas'),
        ),
        child: page.when(
          loading: () => const _PendingReviewsSkeleton(),
          error: (error, __) => AdminErrorState(
              onRetry: onRetry,
              error: error,
              compact: true,
              title: 'No pudimos cargar las revisiones.'),
          data: (value) {
            if (value.items.isEmpty) {
              return const AdminEmptyState(
                icon: Icons.task_alt_outlined,
                title: 'Todo está al día',
                message: 'No existen negocios pendientes de revisión',
              );
            }
            return Column(children: [
              for (var index = 0; index < value.items.length; index++) ...[
                if (index > 0) const Divider(height: 20),
                _PendingReviewRow(item: value.items[index]),
              ],
            ]);
          },
        ),
      );
}

class _PendingReviewsSkeleton extends StatelessWidget {
  const _PendingReviewsSkeleton();

  @override
  Widget build(BuildContext context) => Column(children: [
        for (var index = 0; index < 3; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0EC),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 12, color: const Color(0xFFEAF0EC)),
                      const SizedBox(height: 8),
                      FractionallySizedBox(
                        widthFactor: .55,
                        child: Container(
                            height: 10, color: const Color(0xFFF1F4F1)),
                      ),
                    ]),
              ),
            ]),
          ),
      ]);
}

class _PendingReviewRow extends StatelessWidget {
  const _PendingReviewRow({required this.item});

  final AdminBusinessReviewSummary item;

  @override
  Widget build(BuildContext context) {
    final date = item.submittedAt ?? item.createdAt;
    final details =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(item.categoryName ?? item.businessType.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              const TextStyle(color: RancoColors.textSecondary, fontSize: 12)),
      if (item.ownerName != null || item.ownerEmail != null)
        Text(item.ownerName ?? item.ownerEmail!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: RancoColors.textSecondary, fontSize: 12)),
    ]);
    final status =
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _StatusPill(
        status: item.publicationStatus.label,
        color: _statusColor(item.publicationStatus),
      ),
      if (date != null)
        Text(_shortDate(date.toIso8601String()),
            style: const TextStyle(
                color: RancoColors.textSecondary, fontSize: 11)),
    ]);
    final action = TextButton(
      onPressed: () => context.push('/admin/businesses/${item.id}'),
      child: const Text('Revisar'),
    );
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 500) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          details,
          const SizedBox(height: 6),
          Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [status, action]),
        ]);
      }
      return Row(children: [
        Expanded(child: details),
        const SizedBox(width: 12),
        status,
        const SizedBox(width: 8),
        action,
      ]);
    });
  }
}

class _RecentActivityPanel extends StatelessWidget {
  const _RecentActivityPanel({required this.activity, required this.onRetry});

  final AsyncValue<Map<String, int>> activity;
  final VoidCallback onRetry;

  static const labels = <String, String>{
    'PROFILE_VIEW': 'Visitas a perfiles',
    'CLICK_WHATSAPP': 'Clics en WhatsApp',
    'REQUEST_CONTACT': 'Contactos',
    'CLICK_PHONE': 'Clics en teléfono',
    'SAVE_BUSINESS': 'Negocios guardados',
  };

  @override
  Widget build(BuildContext context) => _DashboardPanel(
        title: 'Actividad reciente',
        subtitle: 'Últimos 30 días',
        child: activity.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => AdminErrorState(
              onRetry: onRetry,
              compact: true,
              title: 'No pudimos cargar la actividad.'),
          data: (counts) {
            final available = labels.entries
                .where((entry) => (counts[entry.key] ?? 0) > 0)
                .toList();
            if (available.isEmpty) {
              return const _DashboardEmpty(
                icon: Icons.insights_outlined,
                text: 'Sin actividad reciente.',
              );
            }
            return Column(children: [
              for (var index = 0; index < available.length; index++) ...[
                if (index > 0) const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(children: [
                    Expanded(
                        child: Text(available[index].value,
                            style: const TextStyle(
                                color: RancoColors.textPrimary,
                                fontSize: 13.5))),
                    Text('${counts[available[index].key]}',
                        style: const TextStyle(
                            color: RancoColors.forest,
                            fontSize: 15,
                            fontFeatures: [FontFeature.tabularFigures()],
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
              ],
            ]);
          },
        ),
      );
}

class _DashboardEmpty extends StatelessWidget {
  const _DashboardEmpty({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(children: [
          Icon(icon, color: RancoColors.forest, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(color: RancoColors.textSecondary))),
        ]),
      );
}

class AdminBusinessesScreen extends ConsumerStatefulWidget {
  const AdminBusinessesScreen({
    this.initialStatus,
    super.key,
  });

  final BusinessPublicationStatus? initialStatus;

  @override
  ConsumerState<AdminBusinessesScreen> createState() =>
      _AdminBusinessesScreenState();
}

class _AdminBusinessesScreenState extends ConsumerState<AdminBusinessesScreen> {
  final _searchController = TextEditingController();
  BusinessType? _businessType;
  BusinessPublicationStatus? _status;
  int _offset = 0;

  /// Filas por página: el RPC existente ya recibe `limit`.
  int _limit = 20;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
  }

  @override
  void didUpdateWidget(covariant AdminBusinessesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStatus != widget.initialStatus) {
      _status = widget.initialStatus;
      _offset = 0;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = (
      status: _status,
      businessType: _businessType,
      search: _searchController.text,
      limit: _limit,
      offset: _offset,
    );
    final page = ref.watch(adminBusinessReviewPageProvider(query));

    return AdminGate(
      child: AdminScaffold(
        title: 'Negocios',
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminSegmentFilter<BusinessPublicationStatus?>(
                    options: [
                      for (final status in const <BusinessPublicationStatus?>[
                        null,
                        BusinessPublicationStatus.pendingReview,
                        BusinessPublicationStatus.published,
                        BusinessPublicationStatus.rejected,
                        BusinessPublicationStatus.suspended,
                        BusinessPublicationStatus.changesRequested,
                      ])
                        (status, status?.label ?? 'Todos', null),
                    ],
                    selected: _status,
                    onSelected: (status) => setState(() {
                      _status = status;
                      _offset = 0;
                    }),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(builder: (context, constraints) {
                    final search = AdminSearchField(
                      controller: _searchController,
                      hint: 'Buscar negocio, dueño o contacto',
                      onSubmitted: (_) => setState(() => _offset = 0),
                    );
                    final type = DropdownButtonFormField<BusinessType?>(
                      isExpanded: true,
                      initialValue: _businessType,
                      decoration: InputDecoration(
                        labelText: 'Tipo',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon:
                            const Icon(Icons.storefront_outlined, size: 20),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFD6E3DD)),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<BusinessType?>(
                          value: null,
                          child: Text('Todos los tipos'),
                        ),
                        ...BusinessType.values.map(
                          (type) => DropdownMenuItem<BusinessType?>(
                            value: type,
                            child: Text(type.label),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _businessType = value;
                          _offset = 0;
                        });
                      },
                    );
                    final apply = FilledButton.icon(
                      onPressed: () => setState(() => _offset = 0),
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text('Buscar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: RancoColors.forest,
                        minimumSize: const Size(0, 46),
                      ),
                    );
                    if (constraints.maxWidth < 640) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          search,
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: type),
                            const SizedBox(width: 10),
                            apply,
                          ]),
                        ],
                      );
                    }
                    return Row(children: [
                      Expanded(flex: 3, child: search),
                      const SizedBox(width: 10),
                      SizedBox(width: 230, child: type),
                      const SizedBox(width: 10),
                      apply,
                    ]);
                  }),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            page.when(
              data: (page) {
                if (page.items.isEmpty) {
                  return SliverToBoxAdapter(
                      child: _AdminEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Sin negocios para este filtro',
                    message:
                        'Cambia estado, tipo o búsqueda para ampliar la cola.',
                    actionLabel: 'Limpiar búsqueda',
                    onAction: () {
                      _searchController.clear();
                      setState(() {
                        _businessType = null;
                        _status = null;
                        _offset = 0;
                      });
                    },
                  ));
                }

                return SliverLayoutBuilder(builder: (context, constraints) {
                  // Tabla administrativa cuando hay ancho real para sus
                  // columnas; tarjetas en pantallas angostas.
                  final table = constraints.crossAxisExtent >= 860;
                  final rows = [
                    for (var index = 0; index < page.items.length; index++) ...[
                      if (index > 0)
                        table
                            ? const Divider(height: 1, color: Color(0xFFE5EEE9))
                            : const SizedBox(height: 8),
                      _BusinessReviewCard(
                        item: page.items[index],
                        tableRow: table,
                        onTap: () => context.push(
                          '/admin/businesses/${page.items[index].id}',
                        ),
                      ),
                    ],
                  ];
                  final paginator = AdminPaginator(
                    offset: _offset,
                    visibleCount: page.items.length,
                    total: page.totalCount,
                    pageSize: _limit,
                    onFirst:
                        _offset == 0 ? null : () => setState(() => _offset = 0),
                    onLast: _offset + page.items.length >= page.totalCount
                        ? null
                        : () => setState(() => _offset =
                            ((page.totalCount - 1) ~/ _limit) * _limit),
                    onPageSizeChanged: (size) => setState(() {
                      _limit = size;
                      _offset = 0;
                    }),
                    onPrevious: _offset == 0
                        ? null
                        : () => setState(() {
                              _offset =
                                  _offset - _limit < 0 ? 0 : _offset - _limit;
                            }),
                    onNext: _offset + page.items.length >= page.totalCount
                        ? null
                        : () => setState(() {
                              _offset += _limit;
                            }),
                  );
                  if (!table) {
                    return SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [...rows, paginator],
                      ),
                    );
                  }
                  // Cabecera fija mientras la tabla está visible.
                  return SliverMainAxisGroup(slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _TableHeaderDelegate(),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(14),
                          ),
                          border: Border(
                            left: BorderSide(color: Color(0xFFD6E3DD)),
                            right: BorderSide(color: Color(0xFFD6E3DD)),
                            bottom: BorderSide(color: Color(0xFFD6E3DD)),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: rows,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: paginator),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ]);
                });
              },
              loading: () => const SliverToBoxAdapter(child: _TableSkeleton()),
              error: (error, __) => SliverToBoxAdapter(
                child: AdminErrorState(
                  error: error,
                  onRetry: () =>
                      ref.invalidate(adminBusinessReviewPageProvider(query)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminBusinessDetailScreen extends ConsumerWidget {
  const AdminBusinessDetailScreen({
    required this.businessId,
    super.key,
  });

  final String businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(adminBusinessReviewDetailProvider(businessId));

    return AdminGate(
      child: AdminScaffold(
        title: 'Revisión de negocio',
        child: detail.when(
          data: (detail) => _BusinessDetailContent(detail: detail),
          loading: () => const _TableSkeleton(),
          error: (_, __) => AdminErrorState(
            onRetry: () =>
                ref.invalidate(adminBusinessReviewDetailProvider(businessId)),
          ),
        ),
      ),
    );
  }
}

class AdminAuditScreen extends StatelessWidget {
  const AdminAuditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // FASE 3.22A: resumen, filtros, tabla/línea de tiempo y paginación en
    // `AdminAuditView` (filas reales de `audit_logs`).
    return const AdminGate(
      child: AdminScaffold(
        title: 'Auditoría',
        child: AdminAuditView(),
      ),
    );
  }
}

class _BusinessDetailContent extends ConsumerStatefulWidget {
  const _BusinessDetailContent({required this.detail});

  final AdminBusinessReviewDetail detail;

  @override
  ConsumerState<_BusinessDetailContent> createState() =>
      _BusinessDetailContentState();
}

class _BusinessDetailContentState
    extends ConsumerState<_BusinessDetailContent> {
  bool _loading = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final business = detail.business;
    final role = ref.watch(currentAdminRoleProvider).valueOrNull;
    final policy = const AdminReviewPolicy();
    final status = detail.publicationStatus;
    final canRequestChanges = _can(
      role,
      policy,
      status,
      AdminReviewAction.requestChanges,
    );
    final canReject = _can(
      role,
      policy,
      status,
      AdminReviewAction.reject,
    );
    final canPublish = _can(
      role,
      policy,
      status,
      AdminReviewAction.publish,
    );
    final canSuspend = _can(
      role,
      policy,
      status,
      AdminReviewAction.suspend,
    );
    final canRestore = _can(
      role,
      policy,
      status,
      AdminReviewAction.restore,
    );

    final header = _ReviewHeader(
      title: detail.name,
      type: detail.businessType.label,
      typeIcon: _typeIcon(detail.businessType),
      status: detail.publicationStatus.label,
      owner: detail.owner['full_name']?.toString().trim().isNotEmpty == true
          ? detail.owner['full_name'].toString()
          : detail.owner['email']?.toString() ?? 'Sin propietario',
      category: detail.category['name']?.toString() ?? 'Sin categoría',
    );
    final actions = _ReviewActionsPanel(
      loading: _loading,
      status: detail.publicationStatus.label,
      canPublish: canPublish,
      canRequestChanges: canRequestChanges,
      canReject: canReject,
      canSuspend: canSuspend,
      canRestore: canRestore,
      onPublish: () => _publish(context),
      onRequestChanges: () => _requestChanges(context),
      onReject: () => _reject(context),
      onSuspend: () => _suspend(context),
      onRestore: () => _restore(context),
    );
    final sections = _reviewSections(detail, business);
    final notice = _message == null
        ? null
        : _AdminNotice(
            icon: Icons.info_outline_rounded,
            title: 'Resultado',
            message: _message!,
          );

    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 940;
      if (!wide) {
        // Móvil/tablet: decisión primero y secciones en acordeones (solo
        // Resumen abierto).
        return ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (notice != null) ...[notice, const SizedBox(height: 12)],
            header,
            const SizedBox(height: 12),
            actions,
            const SizedBox(height: 16),
            for (var i = 0; i < sections.length; i++)
              _Section(
                title: sections[i].$1,
                initiallyExpanded: i == 0,
                children: sections[i].$2,
              ),
          ],
        );
      }
      // Desktop: navegación por secciones (una visible a la vez) y riel de
      // decisión fijo a la derecha. Sin scroll anidado: cada columna tiene
      // su propio scroll y el riel es corto.
      final selected = _section.clamp(0, sections.length - 1);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (notice != null) ...[notice, const SizedBox(height: 12)],
          header,
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: RancoSegmentedControl<int>(
                          segments: [
                            for (var i = 0; i < sections.length; i++)
                              RancoSegment(
                                value: i,
                                label: sections[i].$1,
                                count: sections[i].$3,
                              ),
                          ],
                          selected: selected,
                          onChanged: (value) =>
                              setState(() => _section = value),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: RancoDurations.quick,
                          child: ListView(
                            key: ValueKey(selected),
                            padding: const EdgeInsets.only(bottom: 32),
                            children: [
                              _Section(
                                title: sections[selected].$1,
                                collapsible: false,
                                children: sections[selected].$2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                SizedBox(
                  width: 300,
                  child: SingleChildScrollView(child: actions),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  int _section = 0;

  /// (título, contenido, contador opcional) de cada sección de revisión.
  List<(String, List<Widget>, int?)> _reviewSections(
    AdminBusinessReviewDetail detail,
    Map<String, dynamic> business,
  ) {
    final pendingRequirements =
        detail.requirements.where((item) => item['satisfied'] != true).length;
    return [
      (
        'Resumen',
        [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: _InfoPair(
              children: [
                _InfoCard(
                  title: 'Información general',
                  rows: [
                    _InfoRow('Nombre', business['name']?.toString() ?? ''),
                    _InfoRow('Tipo', detail.businessType.label),
                    _InfoRow('Estado', detail.publicationStatus.label),
                    _InfoRow(
                      'Verificación',
                      business['verification_status']?.toString() ?? '',
                    ),
                    _InfoRow(
                      'Categoría',
                      detail.category['name']?.toString() ?? 'Sin categoría',
                    ),
                    _InfoRow(
                      'Descripción',
                      business['description']?.toString() ?? '',
                    ),
                  ],
                ),
                _InfoCard(
                  title: 'Propietario y contacto',
                  rows: [
                    _InfoRow(
                      'Propietario',
                      detail.owner['full_name']?.toString() ?? '',
                    ),
                    _InfoRow(
                      'Email usuario',
                      detail.owner['email']?.toString() ?? '',
                    ),
                    _InfoRow('Teléfono', business['phone']?.toString() ?? ''),
                    _InfoRow(
                        'WhatsApp', business['whatsapp']?.toString() ?? ''),
                    _InfoRow(
                        'Email negocio', business['email']?.toString() ?? ''),
                    _InfoRow(
                      'Dirección',
                      business['address_text']?.toString() ?? '',
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (detail.businessType == BusinessType.lodging)
            ListTile(
              leading: const Icon(Icons.bed_outlined),
              title: const Text('Detalle alojamiento'),
              subtitle: Text(detail.lodgingDetails.isEmpty
                  ? 'Sin detalles.'
                  : detail.lodgingDetails.entries
                      .map((entry) => '${entry.key}: ${entry.value}')
                      .join('\n')),
            ),
        ],
        null,
      ),
      (
        'Requisitos',
        detail.requirements.isEmpty
            ? [const ListTile(title: Text('Sin requisitos informados.'))]
            : detail.requirements.map((item) {
                final ok = item['satisfied'] == true;
                return ListTile(
                  leading: Icon(
                    ok ? Icons.check_circle_outline : Icons.error_outline,
                    color: ok ? RancoColors.forest : const Color(0xFFB4543F),
                  ),
                  title: Text(item['message']?.toString() ?? ''),
                );
              }).toList(),
        pendingRequirements == 0 ? null : pendingRequirements,
      ),
      (
        'Servicios',
        detail.services.isEmpty
            ? [const ListTile(title: Text('Sin servicios registrados.'))]
            : detail.services
                .map(
                  (item) => ListTile(
                    leading: const Icon(Icons.home_repair_service_outlined),
                    title: Text(item['subcategory_name']?.toString() ?? ''),
                    subtitle: Text(
                      item['description']?.toString().isNotEmpty == true
                          ? item['description'].toString()
                          : 'Sin descripción específica.',
                    ),
                  ),
                )
                .toList(),
        detail.services.isEmpty ? null : detail.services.length,
      ),
      (
        'Cobertura',
        detail.coverage.isEmpty
            ? [const ListTile(title: Text('Sin cobertura registrada.'))]
            : detail.coverage
                .map(
                  (item) => ListTile(
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(item['location_name']?.toString() ?? ''),
                    subtitle: Text(item['commune_name']?.toString() ?? ''),
                  ),
                )
                .toList(),
        detail.coverage.isEmpty ? null : detail.coverage.length,
      ),
      (
        'Archivos',
        detail.media.isEmpty
            ? [const ListTile(title: Text('Sin archivos cargados.'))]
            : detail.media.map((item) {
                final path = item['storage_path']?.toString() ?? '';
                final name = path.split('/').last;
                return ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: Text(
                    name.isEmpty ? 'Archivo' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle:
                      Text(_mediaTypeLabel(item['media_type']?.toString())),
                );
              }).toList(),
        detail.media.isEmpty ? null : detail.media.length,
      ),
      (
        'Historial',
        detail.events.isEmpty
            ? [const ListTile(title: Text('Sin eventos.'))]
            : detail.events
                .map(
                  (event) => ListTile(
                    leading: const Icon(Icons.history_rounded),
                    title: Text(
                      _eventLabel(event['event_type']?.toString() ?? ''),
                    ),
                    subtitle: Text(
                      event['message']?.toString().isNotEmpty == true
                          ? event['message'].toString()
                          : 'Sin comentario.',
                    ),
                    trailing: Text(
                      _shortDate(event['created_at']?.toString()),
                      textAlign: TextAlign.end,
                    ),
                  ),
                )
                .toList(),
        null,
      ),
    ];
  }

  bool _can(
    ProfileRole? role,
    AdminReviewPolicy policy,
    BusinessPublicationStatus status,
    AdminReviewAction action,
  ) {
    if (role == null || _loading) {
      return false;
    }

    return policy.canPerform(
      role: role,
      status: status,
      action: action,
    );
  }

  Future<void> _publish(BuildContext context) async {
    final confirmed = await _confirm(context, 'Publicar negocio');
    if (!confirmed) return;
    await _run(
      ref.read(adminBusinessReviewRepositoryProvider).publish(widget.detail.id),
    );
  }

  Future<void> _restore(BuildContext context) async {
    final confirmed = await _confirm(context, 'Restaurar negocio');
    if (!confirmed) return;
    await _run(
      ref.read(adminBusinessReviewRepositoryProvider).restore(widget.detail.id),
    );
  }

  Future<void> _requestChanges(BuildContext context) async {
    final message = await _askText(context, 'Solicitar cambios');
    if (message == null) return;
    await _run(
      ref.read(adminBusinessReviewRepositoryProvider).requestChanges(
            businessId: widget.detail.id,
            message: message,
          ),
    );
  }

  Future<void> _reject(BuildContext context) async {
    final reason = await _askText(context, 'Rechazar negocio');
    if (reason == null) return;
    await _run(
      ref.read(adminBusinessReviewRepositoryProvider).reject(
            businessId: widget.detail.id,
            reason: reason,
          ),
    );
  }

  Future<void> _suspend(BuildContext context) async {
    final reason = await _askText(context, 'Suspender negocio');
    if (reason == null) return;
    await _run(
      ref.read(adminBusinessReviewRepositoryProvider).suspend(
            businessId: widget.detail.id,
            reason: reason,
          ),
    );
  }

  Future<void> _run(Future<Result<void>> action) async {
    setState(() {
      _loading = true;
      _message = null;
    });

    final result = await action;

    if (!mounted) return;

    result.when(
      success: (_) {
        ref.invalidate(adminBusinessReviewDetailProvider(widget.detail.id));
        ref.invalidate(adminReviewStatsProvider);
        ref.invalidate(adminBusinessReviewPageProvider);
        ref.invalidate(publishedBusinessesProvider);
        ref.invalidate(businessDetailProvider(widget.detail.id));
        setState(() {
          _loading = false;
          _message = 'Acción realizada.';
        });
      },
      failure: (failure) {
        setState(() {
          _loading = false;
          _message = failure.message;
        });
      },
    );
  }

  Future<bool> _confirm(BuildContext context, String title) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: const Text('Confirma esta acción administrativa.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _askText(BuildContext context, String title) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Motivo o comentario obligatorio',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(context, text);
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}

class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    required this.title,
    required this.child,
    super.key,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (_AdminWorkspaceScope.isActive(context)) return child;
    return Scaffold(
      backgroundColor: RancoColors.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final content = Padding(
            padding: EdgeInsets.all(compact ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminHeader(
                  breadcrumb: title,
                  overview: GoRouterState.of(context).uri.path == '/admin',
                ),
                if (compact) ...[
                  const SizedBox(height: 10),
                  _AdminTopNav(
                    selectedIndex: _selectedIndex(context),
                    onSelected: (index) => _goToIndex(context, index),
                  ),
                ],
                const SizedBox(height: 18),
                Expanded(child: child),
              ],
            ),
          );

          if (compact) {
            return SafeArea(child: content);
          }

          return Row(
            children: [
              _AdminSidebar(
                selectedIndex: _selectedIndex(context),
                onSelected: (index) => _goToIndex(context, index),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: content,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _goToIndex(BuildContext context, int index) {
    switch (index) {
      case 0:
        _openModule(context, '/admin');
        break;
      case 1:
        _openModule(context, '/admin/businesses');
        break;
      case 2:
        _openModule(context, '/admin/users');
        break;
      case 3:
        _openModule(context, '/admin/categories');
        break;
      case 4:
        _openModule(context, '/admin/settings');
        break;
      case 5:
        _openModule(context, '/admin/analytics');
        break;
      case 6:
        _openModule(context, '/admin/audit');
        break;
    }
  }

  void _openModule(BuildContext context, String path) {
    if (GoRouterState.of(context).uri.path == path) return;
    context.go(path);
  }

  int _selectedIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/admin/businesses')) return 1;
    if (path.startsWith('/admin/users')) return 2;
    if (path.startsWith('/admin/categories')) return 3;
    if (path.startsWith('/admin/settings')) return 4;
    if (path.startsWith('/admin/analytics')) return 5;
    if (path.startsWith('/admin/audit')) return 6;
    return 0;
  }
}

/// Navegación lateral del panel: compacta, con etiqueta visible y estado
/// activo claro. Sin footer público: el panel se siente como app interna.
class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const items = <(IconData, IconData, String)>[
    (Icons.dashboard_outlined, Icons.dashboard_rounded, 'Resumen'),
    (Icons.storefront_outlined, Icons.storefront_rounded, 'Negocios'),
    (Icons.people_outline, Icons.people_rounded, 'Usuarios'),
    (Icons.category_outlined, Icons.category_rounded, 'Categorías'),
    (Icons.settings_outlined, Icons.settings_rounded, 'Configuración'),
    (Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Estadísticas'),
    (Icons.fact_check_outlined, Icons.fact_check_rounded, 'Auditoría'),
  ];

  /// Índice del primer módulo de cada grupo → etiqueta del grupo.
  static const _groupStarts = <int, String>{
    0: 'Operación',
    3: 'Catálogo',
    4: 'Plataforma',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 216,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFDDE9E3))),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Misma familia de marca que el sidebar público.
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 18, 14, 16),
              // Misma escala que el sidebar público (42 / 18).
              child: RancoBrandLockup(
                subtitle: 'Administración',
                markSize: 42,
                fontSize: 18,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      // Misma lógica de grupos que el sidebar público.
                      if (_groupStarts.containsKey(index))
                        _AdminNavGroupLabel(_groupStarts[index]!),
                      _AdminNavItem(
                        icon: items[index].$1,
                        selectedIcon: items[index].$2,
                        label: items[index].$3,
                        selected: selectedIndex == index,
                        onTap: () => onSelected(index),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: _AdminNavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'Ir al sitio',
                selected: false,
                onTap: () => context.go('/'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminNavGroupLabel extends StatelessWidget {
  const _AdminNavGroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF7A8B83),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .6,
          ),
        ),
      );
}

class _AdminNavItem extends StatelessWidget {
  const _AdminNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? RancoColors.forest : RancoColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? const Color(0xFFEAF4F0) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            hoverColor: const Color(0xFFF2F8F5),
            focusColor: const Color(0x332F7D57),
            child: SizedBox(
              height: 40,
              child: Row(children: [
                Container(
                  width: 3,
                  height: 20,
                  decoration: BoxDecoration(
                    color: selected ? RancoColors.forest : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 9),
                Icon(selected ? selectedIcon : icon,
                    size: 20,
                    color: selected ? RancoColors.forest : RancoColors.slate),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 13.5,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      )),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminHeader extends StatelessWidget {
  const AdminHeader(
      {required this.breadcrumb, required this.overview, super.key});

  final String breadcrumb;
  final bool overview;

  @override
  Widget build(BuildContext context) {
    final sectionPath = breadcrumb.replaceAll(' · ', ' / ');
    final path = sectionPath.startsWith('Admin /')
        ? sectionPath
        : 'Admin / $sectionPath';
    // Título = módulo (segundo nivel del breadcrumb). La descripción nunca
    // repite el título.
    final segments = path.split('/').map((part) => part.trim()).toList();
    final title = overview
        ? 'Panel administrativo'
        : segments.last == 'Revisión'
            ? 'Revisión de negocio'
            : segments.length > 1
                ? segments[1]
                : segments.last;
    final details =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(path,
          style: const TextStyle(
              color: RancoColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 3),
      Text(title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: RancoColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              )),
      if (overview) ...[
        const SizedBox(height: 3),
        const Text('Gestiona la operación de Ranco Conecta.',
            style: TextStyle(color: RancoColors.textSecondary, fontSize: 13)),
      ] else ...[
        const SizedBox(height: 3),
        Text(
          switch (title) {
            'Negocios' =>
              'Revisa publicaciones, estados y solicitudes de revisión.',
            'Usuarios' => 'Consulta y segmenta las cuentas registradas.',
            'Categorías' => 'Catálogo de rubros visible en la plataforma.',
            'Configuración' =>
              'Gestiona los avisos administrativos de la plataforma.',
            'Estadísticas' => 'Actividad real registrada en la plataforma.',
            'Auditoría' => 'Historial de acciones administrativas.',
            'Revisión de negocio' =>
              'Revisa la información enviada antes de decidir.',
            _ => 'Información y acciones de administración.',
          },
          style:
              const TextStyle(color: RancoColors.textSecondary, fontSize: 13),
        ),
      ],
    ]);
    final actions = Wrap(
        spacing: 7,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (overview) ...[
            FilledButton.icon(
              onPressed: () => context.push('/admin/businesses/pending'),
              icon: const Icon(Icons.fact_check_outlined, size: 17),
              label: const Text('Revisar pendientes'),
              style:
                  FilledButton.styleFrom(backgroundColor: RancoColors.forest),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/admin/settings'),
              icon: const Icon(Icons.settings_outlined, size: 17),
              label: const Text('Configuración'),
            ),
          ],
          TextButton.icon(
            onPressed: () => context.go('/account'),
            icon: const Icon(Icons.account_circle_outlined, size: 18),
            label: const Text('Cuenta'),
          ),
        ]);
    // En desktop el sidebar y el breadcrumb ya ubican al usuario; el "volver"
    // solo se muestra en móvil, donde no hay sidebar.
    final compact = MediaQuery.sizeOf(context).width < 760;
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 900;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!overview && compact)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go('/admin'),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Volver al panel'),
            ),
          ),
        if (narrow) ...[
          details,
          const SizedBox(height: 8),
          actions,
        ] else
          Row(children: [
            Expanded(child: details),
            const SizedBox(width: 18),
            actions,
          ]),
      ]);
    });
  }
}

class _AdminTopNav extends StatelessWidget {
  const _AdminTopNav({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(
            value: 0,
            icon: Icon(Icons.dashboard_outlined),
            label: Text('Resumen'),
          ),
          ButtonSegment(
            value: 1,
            icon: Icon(Icons.storefront_outlined),
            label: Text('Negocios'),
          ),
          ButtonSegment(
            value: 2,
            icon: Icon(Icons.people_outline),
            label: Text('Usuarios'),
          ),
          ButtonSegment(
            value: 3,
            icon: Icon(Icons.category_outlined),
            label: Text('Categorías'),
          ),
          ButtonSegment(
            value: 4,
            icon: Icon(Icons.settings_outlined),
            label: Text('Configuración'),
          ),
          ButtonSegment(
            value: 5,
            icon: Icon(Icons.bar_chart_outlined),
            label: Text('Estadísticas'),
          ),
          ButtonSegment(
            value: 6,
            icon: Icon(Icons.fact_check_outlined),
            label: Text('Auditoría'),
          ),
        ],
        selected: {selectedIndex},
        onSelectionChanged: (values) => onSelected(values.first),
      ),
    );
  }
}

class _StatCard extends StatefulWidget {
  const _StatCard({
    required this.label,
    required this.count,
    required this.detail,
    required this.icon,
    required this.tone,
    required this.onTap,
    this.unavailableHint = 'No disponible temporalmente',
  });

  final String label;
  final int? count;
  final String detail;

  /// Tooltip cuando [count] es null (métrica sin cargar o con error).
  final String unavailableHint;
  final IconData icon;
  final Color tone;
  final VoidCallback onTap;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color:
                  _hovered ? widget.tone.withValues(alpha: .06) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _hovered
                      ? widget.tone.withValues(alpha: .35)
                      : const Color(0xFFDCE8E0)),
              boxShadow: _hovered
                  ? const [
                      BoxShadow(
                          color: Color(0x18173E2E),
                          blurRadius: 14,
                          offset: Offset(0, 4))
                    ]
                  : const [
                      BoxShadow(
                          color: Color(0x08173E2E),
                          blurRadius: 7,
                          offset: Offset(0, 2))
                    ],
            ),
            child: Tooltip(
              message:
                  widget.count == null ? widget.unavailableHint : widget.detail,
              waitDuration: const Duration(milliseconds: 400),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.tone.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, color: widget.tone, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.count?.toString() ?? '—',
                          maxLines: 1,
                          style: TextStyle(
                            color: widget.tone,
                            fontSize: 22,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          )),
                      Text(widget.label,
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
          ),
        ),
      ),
    );
  }
}

class _AdminNotice extends StatelessWidget {
  const _AdminNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6E3DD)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: RancoColors.forest),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF30443B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF61736A),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminEmptyState extends StatelessWidget {
  const _AdminEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: RancoColors.forest),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: RancoColors.forest,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF61736A)),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.restart_alt_rounded),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableHeaderDelegate extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 42;

  @override
  double get maxExtent => 42;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(
        // Fondo del lienzo detrás de las esquinas para que la fila fija no
        // muestre el contenido que pasa por debajo.
        color: RancoColors.canvas,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(14),
            ),
            border: Border.fromBorderSide(
              BorderSide(color: Color(0xFFD6E3DD)),
            ),
          ),
          child: const _BusinessReviewTableHeader(),
        ),
      );

  @override
  bool shouldRebuild(covariant _TableHeaderDelegate oldDelegate) => false;
}

/// Esqueleto de tabla: filas con la altura real (sin spinner aislado).
class _TableSkeleton extends StatelessWidget {
  const _TableSkeleton();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var i = 0; i < 6; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4F1),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      );
}

class _BusinessReviewTableHeader extends StatelessWidget {
  const _BusinessReviewTableHeader();

  @override
  Widget build(BuildContext context) => Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        color: const Color(0xFFF4F8F6),
        child: const DefaultTextStyle(
          style: TextStyle(
            color: RancoColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          child: Row(children: [
            SizedBox(width: 56, child: Text('Imagen')),
            Expanded(flex: 3, child: Text('Negocio')),
            Expanded(flex: 2, child: Text('Categoría / Tipo')),
            Expanded(flex: 2, child: Text('Propietario')),
            SizedBox(width: 150, child: Text('Estado')),
            SizedBox(width: 96, child: Text('Fecha')),
            SizedBox(
                width: 208, child: Text('Acciones', textAlign: TextAlign.end)),
          ]),
        ),
      );
}

class _BusinessReviewCard extends ConsumerWidget {
  const _BusinessReviewCard({
    required this.item,
    required this.onTap,
    this.tableRow = false,
  });

  final AdminBusinessReviewSummary item;
  final VoidCallback onTap;
  final bool tableRow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail =
        ref.watch(adminBusinessReviewDetailProvider(item.id)).valueOrNull;
    final cover = detail?.media
        .where((media) => media['media_type'] == 'cover')
        .firstOrNull;
    final storagePath = cover?['storage_path']?.toString();
    final imageUrl = storagePath == null
        ? null
        : ref.read(businessMediaRepositoryProvider).publicUrl(storagePath);
    final location = detail?.coverage.firstOrNull?['location_name']?.toString();
    final role = ref.watch(currentAdminRoleProvider).valueOrNull;
    final canReview = role != null &&
        const AdminReviewPolicy().canPerform(
          role: role,
          status: item.publicationStatus,
          action: AdminReviewAction.publish,
        );
    final thumbSize = tableRow ? 40.0 : 52.0;
    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(tableRow ? 9 : 12),
      child: SizedBox(
        width: thumbSize,
        height: thumbSize,
        child: imageUrl == null
            ? ColoredBox(
                color:
                    _statusColor(item.publicationStatus).withValues(alpha: .12),
                child: Icon(_typeIcon(item.businessType),
                    color: RancoColors.forest),
              )
            : Image.network(imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.storefront_outlined)),
      ),
    );
    final statusColor = _statusColor(item.publicationStatus);
    final reviewButtons = [
      if (canReview) ...[
        IconButton(
          tooltip: 'Aprobar y publicar',
          visualDensity: VisualDensity.compact,
          onPressed: () => _review(context, ref, approve: true),
          color: RancoColors.forest,
          icon: const Icon(Icons.check_circle_outline),
        ),
        IconButton(
          tooltip: 'Rechazar',
          visualDensity: VisualDensity.compact,
          onPressed: () => _review(context, ref, approve: false),
          color: const Color(0xFF9A3E36),
          icon: const Icon(Icons.cancel_outlined),
        ),
      ],
    ];
    final actions = Wrap(spacing: 4, runSpacing: 2, children: [
      TextButton(
          onPressed: onTap,
          child: Text(tableRow ? 'Ver detalle' : 'Ver negocio')),
      ...reviewButtons,
    ]);
    if (tableRow) {
      const cell = TextStyle(color: RancoColors.textPrimary, fontSize: 13);
      final owner = item.ownerName ?? item.ownerEmail ?? 'Sin propietario';
      final category = item.categoryName ?? item.businessType.label;
      return Material(
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(children: [
              SizedBox(
                  width: 56,
                  child:
                      Align(alignment: Alignment.centerLeft, child: thumbnail)),
              Expanded(
                  flex: 3,
                  child: Tooltip(
                    message: item.name,
                    waitDuration: const Duration(milliseconds: 500),
                    child: Text(item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: cell.copyWith(fontWeight: FontWeight.w800)),
                  )),
              Expanded(
                  flex: 2,
                  child: Text(category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: cell)),
              Expanded(
                  flex: 2,
                  child: Tooltip(
                    message: owner,
                    waitDuration: const Duration(milliseconds: 500),
                    child: Text(owner,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: cell),
                  )),
              SizedBox(
                  width: 150,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _StatusPill(
                      status: item.publicationStatus.label,
                      color: statusColor,
                    ),
                  )),
              SizedBox(
                  width: 96,
                  child: Text(
                    _shortDate((item.submittedAt ?? item.createdAt)
                        ?.toIso8601String()),
                    style: const TextStyle(
                        fontSize: 12.5, color: RancoColors.textSecondary),
                  )),
              SizedBox(
                width: 208,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: TextButton(
                        onPressed: onTap,
                        child: const Text(
                          'Ver detalle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    ...reviewButtons,
                  ],
                ),
              ),
            ]),
          ),
        ),
      );
    }
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD6E3DD)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              thumbnail,
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF30443B),
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(item.categoryName ?? item.businessType.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF61736A))),
                    if (location != null && location.isNotEmpty)
                      Text(location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF7A8A83), fontSize: 12)),
                  ])),
              _StatusPill(
                status: item.publicationStatus.label,
                color: statusColor,
              ),
            ]),
            const SizedBox(height: 10),
            Wrap(
                spacing: 10,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                      'Solicitud: ${_shortDate((item.submittedAt ?? item.createdAt)?.toIso8601String())}',
                      style: const TextStyle(
                          color: Color(0xFF7A8A83), fontSize: 12)),
                  Text(item.ownerName ?? item.ownerEmail ?? 'Sin propietario',
                      style: const TextStyle(
                          color: Color(0xFF7A8A83), fontSize: 12)),
                ]),
            const SizedBox(height: 8),
            actions,
          ],
        ),
      ),
    );
  }

  Future<void> _review(BuildContext context, WidgetRef ref,
      {required bool approve}) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
                  title: Text(approve ? 'Aprobar negocio' : 'Rechazar negocio'),
                  content: approve
                      ? Text('¿Publicar ${item.name}?')
                      : TextField(
                          controller: reason,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              labelText: 'Motivo obligatorio')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: () {
                          if (!approve && reason.text.trim().isEmpty) return;
                          Navigator.pop(dialogContext, true);
                        },
                        child: const Text('Confirmar')),
                  ],
                )) ??
        false;
    final rejectionReason = reason.text.trim();
    reason.dispose();
    if (!confirmed) return;
    final repository = ref.read(adminBusinessReviewRepositoryProvider);
    final result = await (approve
        ? repository.publish(item.id)
        : repository.reject(businessId: item.id, reason: rejectionReason));
    if (!context.mounted) return;
    result.when(success: (_) {
      ref.invalidate(adminBusinessReviewPageProvider);
      ref.invalidate(adminBusinessReviewDetailProvider(item.id));
      ref.invalidate(adminReviewStatsProvider);
      ref.invalidate(publishedBusinessesProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Acción realizada.')));
    }, failure: (failure) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
    });
  }
}

class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader({
    required this.title,
    required this.type,
    required this.typeIcon,
    required this.status,
    required this.owner,
    required this.category,
  });

  final String title;
  final String type;
  final IconData typeIcon;
  final String status;
  final String owner;
  final String category;

  @override
  Widget build(BuildContext context) {
    // Superficie clara: el estado (badge semántico) aporta el color, no el
    // fondo completo.
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE8E2)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: RancoColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(typeIcon, color: RancoColors.primaryDark),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: RancoColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$type · $category · $owner',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RancoColors.textSecondary,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _StatusPill(status: status),
        ],
      ),
    );
  }
}

/// Riel de decisión: una acción primaria (Publicar), secundarias en outline
/// y las destructivas (Rechazar, Suspender) separadas en rojo suave. Solo se
/// muestran las acciones permitidas para el estado actual.
class _ReviewActionsPanel extends StatelessWidget {
  const _ReviewActionsPanel({
    required this.loading,
    required this.status,
    required this.canPublish,
    required this.canRequestChanges,
    required this.canReject,
    required this.canSuspend,
    required this.canRestore,
    required this.onPublish,
    required this.onRequestChanges,
    required this.onReject,
    required this.onSuspend,
    required this.onRestore,
  });

  final bool loading;
  final String status;
  final bool canPublish;
  final bool canRequestChanges;
  final bool canReject;
  final bool canSuspend;
  final bool canRestore;
  final VoidCallback onPublish;
  final VoidCallback onRequestChanges;
  final VoidCallback onReject;
  final VoidCallback onSuspend;
  final VoidCallback onRestore;

  static final _destructive = OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF8E3232),
    side: const BorderSide(color: Color(0xFFEBCFCB)),
    minimumSize: const Size.fromHeight(44),
  );

  @override
  Widget build(BuildContext context) {
    final constructive = [
      if (canPublish)
        FilledButton.icon(
          onPressed: onPublish,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          icon: const Icon(Icons.public_outlined, size: 19),
          label: const Text('Publicar'),
        ),
      if (canRestore)
        FilledButton.icon(
          onPressed: onRestore,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          icon: const Icon(Icons.restore_outlined, size: 19),
          label: const Text('Restaurar'),
        ),
      if (canRequestChanges)
        OutlinedButton.icon(
          onPressed: onRequestChanges,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
          ),
          icon: const Icon(Icons.rate_review_outlined, size: 19),
          label: const Text('Solicitar cambios'),
        ),
    ];
    final destructive = [
      if (canReject)
        OutlinedButton.icon(
          onPressed: onReject,
          style: _destructive,
          icon: const Icon(Icons.block_outlined, size: 19),
          label: const Text('Rechazar'),
        ),
      if (canSuspend)
        OutlinedButton.icon(
          onPressed: onSuspend,
          style: _destructive,
          icon: const Icon(Icons.gpp_bad_outlined, size: 19),
          label: const Text('Suspender'),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE8E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Decisión',
            style: TextStyle(
              color: RancoColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Estado actual',
                style: TextStyle(color: RancoColors.textSecondary),
              ),
              const SizedBox(width: 8),
              Flexible(child: _StatusPill(status: status)),
            ],
          ),
          if (loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: 16),
          if (constructive.isEmpty && destructive.isEmpty)
            Text(
              loading
                  ? 'Aplicando la decisión…'
                  : 'No hay acciones disponibles para este estado.',
              style: const TextStyle(
                color: RancoColors.textSecondary,
                fontSize: 13.5,
              ),
            ),
          for (var i = 0; i < constructive.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            constructive[i],
          ],
          if (destructive.isNotEmpty) ...[
            if (constructive.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
            ],
            for (var i = 0; i < destructive.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              destructive[i],
            ],
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.status,
    this.color,
  });

  final String status;

  /// Se conserva por compatibilidad de llamadas; el tono lo decide el badge
  /// compartido a partir de la etiqueta.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return RancoStatusBadge(
      label: status,
      tone: rancoToneForStatusLabel(status),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE8E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: RancoColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      row.label,
                      style: const TextStyle(
                        color: RancoColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      row.value.trim().isEmpty ? '—' : row.value,
                      style: TextStyle(
                        color: row.value.trim().isEmpty
                            ? RancoColors.textSecondary
                            : RancoColors.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Dos tarjetas de igual ancho lado a lado (o apiladas en angosto).
class _InfoPair extends StatelessWidget {
  const _InfoPair({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 680) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              children[i],
            ],
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: children[i]),
            ],
          ],
        ),
      );
    });
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.initiallyExpanded = true,
    this.collapsible = true,
  });

  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  /// Desktop (sección elegida en la navegación): sin acordeón.
  final bool collapsible;

  @override
  Widget build(BuildContext context) {
    final titleText = Text(
      title,
      style: const TextStyle(
        color: RancoColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFDDE8E2)),
        ),
        clipBehavior: Clip.antiAlias,
        child: collapsible
            ? ExpansionTile(
                initiallyExpanded: initiallyExpanded,
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding: const EdgeInsets.symmetric(horizontal: 18),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: titleText,
                children: children,
              )
            : Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                      child: titleText,
                    ),
                    ...children,
                  ],
                ),
              ),
      ),
    );
  }
}

String _mediaTypeLabel(String? type) => switch (type) {
      'logo' => 'Logo',
      'cover' => 'Portada',
      'gallery' => 'Galería',
      'portfolio' => 'Trabajos realizados',
      _ => 'Imagen',
    };

Color _statusColor(BusinessPublicationStatus status) {
  return switch (status) {
    BusinessPublicationStatus.pendingReview => const Color(0xFF8A5B12),
    BusinessPublicationStatus.changesRequested => const Color(0xFF9A563C),
    BusinessPublicationStatus.published => RancoColors.forest,
    BusinessPublicationStatus.rejected => const Color(0xFF9A3E36),
    BusinessPublicationStatus.suspended => const Color(0xFF6750A4),
    BusinessPublicationStatus.paused => const Color(0xFF6B7280),
    BusinessPublicationStatus.archived => const Color(0xFF6B7280),
    BusinessPublicationStatus.draft => const Color(0xFF53675E),
  };
}

IconData _typeIcon(BusinessType type) {
  return switch (type) {
    BusinessType.service => Icons.handyman_outlined,
    BusinessType.commerce => Icons.storefront_outlined,
    BusinessType.gastronomy => Icons.restaurant_outlined,
    BusinessType.lodging => Icons.bed_outlined,
    BusinessType.tourism => Icons.terrain_outlined,
    BusinessType.emergency => Icons.emergency_outlined,
  };
}

String _shortDate(String? value) {
  final date = DateTime.tryParse(value ?? '');

  if (date == null) {
    return '';
  }

  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');

  return '$day/$month/${local.year}';
}

String _eventLabel(String value) {
  return switch (value) {
    'submitted' => 'Enviado a revisión',
    'resubmitted' => 'Reenviado',
    'changes_requested' => 'Cambios solicitados',
    'rejected' => 'Rechazado',
    'published' => 'Publicado',
    'suspended' => 'Suspendido',
    'restored' => 'Restaurado',
    _ => value,
  };
}
