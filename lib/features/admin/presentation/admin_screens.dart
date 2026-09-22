import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/models/business.dart';
import '../../../shared/models/profile.dart';
import '../../../theme/ranco_colors.dart';
import '../application/admin_review_policy.dart';
import '../application/admin_providers.dart';
import '../data/admin_business_review_repository.dart';

class AdminGate extends ConsumerWidget {
  const AdminGate({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentAdminRoleProvider);

    return role.when(
      data: (role) {
        if (role == null) {
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
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Text('No pudimos validar permisos admin: $error'),
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

    return AdminGate(
      child: _AdminScaffold(
        title: 'Resumen admin',
        child: stats.when(
          data: (items) {
            final pending = items['pending_review'] ?? 0;
            final changes = items['changes_requested'] ?? 0;
            final published = items['published'] ?? 0;
            final rejected = items['rejected'] ?? 0;
            final suspended = items['suspended'] ?? 0;
            final needsWork = pending + changes;

            return ListView(
              children: [
                _AdminHeroPanel(
                  title: needsWork == 0
                      ? 'No hay revisiones pendientes'
                      : '$needsWork revisiones requieren atención',
                  message:
                      'La revisión de negocios usa datos reales de Supabase y acciones administrativas con RPCs protegidas.',
                  actionLabel: pending > 0 ? 'Revisar pendientes' : 'Ver cola',
                  onAction: () => context.go('/admin/businesses/pending'),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth > 980
                        ? 5
                        : constraints.maxWidth > 620
                            ? 3
                            : 2;

                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.25,
                      children: [
                        _StatCard(
                          label: 'Pendientes',
                          count: pending,
                          icon: Icons.hourglass_top_outlined,
                          tone: const Color(0xFF8A5B12),
                          onTap: () => context.go('/admin/businesses/pending'),
                        ),
                        _StatCard(
                          label: 'Cambios',
                          count: changes,
                          icon: Icons.rate_review_outlined,
                          tone: const Color(0xFF9A563C),
                          onTap: () => context.go(
                            '/admin/businesses?status=changes_requested',
                          ),
                        ),
                        _StatCard(
                          label: 'Publicados',
                          count: published,
                          icon: Icons.public_outlined,
                          tone: RancoColors.forest,
                          onTap: () => context.go(
                            '/admin/businesses?status=published',
                          ),
                        ),
                        _StatCard(
                          label: 'Rechazados',
                          count: rejected,
                          icon: Icons.block_outlined,
                          tone: const Color(0xFF9A3E36),
                          onTap: () => context.go(
                            '/admin/businesses?status=rejected',
                          ),
                        ),
                        _StatCard(
                          label: 'Suspendidos',
                          count: suspended,
                          icon: Icons.gpp_bad_outlined,
                          tone: const Color(0xFF6750A4),
                          onTap: () => context.go(
                            '/admin/businesses?status=suspended',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                const _AdminNotice(
                  icon: Icons.verified_user_outlined,
                  title: 'Alcance administrativo actual',
                  message:
                      'Negocios, requisitos, historial y acciones de revisión están conectados. Usuarios y auditoría muestran estados informativos hasta exponer RPCs admin dedicadas.',
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Text('No pudimos cargar resumen: $error'),
        ),
      ),
    );
  }
}

class AdminBusinessesScreen extends ConsumerStatefulWidget {
  const AdminBusinessesScreen({
    required this.initialStatus,
    super.key,
  });

  final BusinessPublicationStatus initialStatus;

  @override
  ConsumerState<AdminBusinessesScreen> createState() =>
      _AdminBusinessesScreenState();
}

class _AdminBusinessesScreenState extends ConsumerState<AdminBusinessesScreen> {
  final _searchController = TextEditingController();
  BusinessType? _businessType;
  late BusinessPublicationStatus _status;
  int _offset = 0;

  static const _limit = 20;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
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
      child: _AdminScaffold(
        title: 'Negocios',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilterPanel(
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Buscar negocio, dueño o contacto',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => setState(() => _offset = 0),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<BusinessPublicationStatus>(
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'Estado',
                      prefixIcon: Icon(Icons.fact_check_outlined),
                    ),
                    items: const [
                      BusinessPublicationStatus.pendingReview,
                      BusinessPublicationStatus.changesRequested,
                      BusinessPublicationStatus.published,
                      BusinessPublicationStatus.rejected,
                      BusinessPublicationStatus.suspended,
                    ]
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status.label),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _status = value;
                        _offset = 0;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<BusinessType?>(
                    initialValue: _businessType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<BusinessType?>(
                        value: null,
                        child: Text('Todos'),
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
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => setState(() => _offset = 0),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Aplicar'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: page.when(
                data: (page) {
                  if (page.items.isEmpty) {
                    return _AdminEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Sin negocios para este filtro',
                      message:
                          'Cambia estado, tipo o búsqueda para ampliar la cola.',
                      actionLabel: 'Limpiar búsqueda',
                      onAction: () {
                        _searchController.clear();
                        setState(() {
                          _businessType = null;
                          _offset = 0;
                        });
                      },
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          itemCount: page.items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = page.items[index];
                            return _BusinessReviewCard(
                              item: item,
                              onTap: () {
                                context.go('/admin/businesses/${item.id}');
                              },
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _PaginationBar(
                          from: _offset + 1,
                          to: _offset + page.items.length,
                          total: page.totalCount,
                          onPrevious: _offset == 0
                              ? null
                              : () => setState(() {
                                    _offset = _offset - _limit < 0
                                        ? 0
                                        : _offset - _limit;
                                  }),
                          onNext: _offset + page.items.length >= page.totalCount
                              ? null
                              : () => setState(() {
                                    _offset += _limit;
                                  }),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Text('No pudimos cargar: $error'),
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
      child: _AdminScaffold(
        title: 'Revisión de negocio',
        child: detail.when(
          data: (detail) => _BusinessDetailContent(detail: detail),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Text('No pudimos cargar: $error'),
        ),
      ),
    );
  }
}

class AdminPlaceholderScreen extends StatelessWidget {
  const AdminPlaceholderScreen({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AdminGate(
      child: _AdminScaffold(
        title: title,
        child: Center(
          child: _AdminNotice(
            icon: Icons.lock_outline_rounded,
            title: 'Backend pendiente',
            message: message,
          ),
        ),
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

    return ListView(
      children: [
        if (_message != null)
          _AdminNotice(
            icon: Icons.info_outline_rounded,
            title: 'Resultado',
            message: _message!,
          ),
        const SizedBox(height: 12),
        _ReviewHeader(
          title: detail.name,
          type: detail.businessType.label,
          status: detail.publicationStatus.label,
          owner: detail.owner['full_name']?.toString().trim().isNotEmpty == true
              ? detail.owner['full_name'].toString()
              : detail.owner['email']?.toString() ?? 'Sin propietario',
          category: detail.category['name']?.toString() ?? 'Sin categoría',
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 940;
            final main = Column(
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
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
                          detail.category['name']?.toString() ??
                              'Sin categoría',
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
                        _InfoRow(
                          'Teléfono',
                          business['phone']?.toString() ?? '',
                        ),
                        _InfoRow(
                          'WhatsApp',
                          business['whatsapp']?.toString() ?? '',
                        ),
                        _InfoRow(
                          'Email negocio',
                          business['email']?.toString() ?? '',
                        ),
                        _InfoRow(
                          'Dirección',
                          business['address_text']?.toString() ?? '',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Requisitos',
                  children: detail.requirements.map((item) {
                    final ok = item['satisfied'] == true;
                    return ListTile(
                      leading: Icon(
                        ok ? Icons.check_circle_outline : Icons.error_outline,
                        color:
                            ok ? RancoColors.forest : const Color(0xFFB4543F),
                      ),
                      title: Text(item['message']?.toString() ?? ''),
                    );
                  }).toList(),
                ),
                _Section(
                  title: 'Servicios',
                  children: detail.services.isEmpty
                      ? [
                          const ListTile(
                            title: Text('Sin servicios registrados.'),
                          ),
                        ]
                      : detail.services
                          .map(
                            (item) => ListTile(
                              leading: const Icon(
                                Icons.home_repair_service_outlined,
                              ),
                              title: Text(
                                item['subcategory_name']?.toString() ?? '',
                              ),
                              subtitle: Text(
                                item['description']?.toString().isNotEmpty ==
                                        true
                                    ? item['description'].toString()
                                    : 'Sin descripción específica.',
                              ),
                            ),
                          )
                          .toList(),
                ),
                _Section(
                  title: 'Cobertura',
                  children: detail.coverage.isEmpty
                      ? [
                          const ListTile(
                            title: Text('Sin cobertura registrada.'),
                          ),
                        ]
                      : detail.coverage
                          .map(
                            (item) => ListTile(
                              leading: const Icon(Icons.location_on_outlined),
                              title: Text(
                                item['location_name']?.toString() ?? '',
                              ),
                              subtitle: Text(
                                item['commune_name']?.toString() ?? '',
                              ),
                            ),
                          )
                          .toList(),
                ),
                if (detail.businessType == BusinessType.lodging)
                  _Section(
                    title: 'Alojamiento',
                    children: [
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
                  ),
                _Section(
                  title: 'Historial',
                  children: detail.events.isEmpty
                      ? [const ListTile(title: Text('Sin eventos.'))]
                      : detail.events
                          .map(
                            (event) => ListTile(
                              leading: const Icon(Icons.history_rounded),
                              title: Text(
                                _eventLabel(
                                  event['event_type']?.toString() ?? '',
                                ),
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
                ),
              ],
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

            if (!wide) {
              return Column(
                children: [
                  actions,
                  const SizedBox(height: 16),
                  main,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: main),
                const SizedBox(width: 16),
                SizedBox(width: 300, child: actions),
              ],
            );
          },
        ),
      ],
    );
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

class _AdminScaffold extends StatelessWidget {
  const _AdminScaffold({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: RancoColors.forest,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => context.go('/'),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Salir'),
                    ),
                  ],
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
              NavigationRail(
                selectedIndex: _selectedIndex(context),
                labelType: NavigationRailLabelType.all,
                backgroundColor: Colors.white,
                onDestinationSelected: (index) => _goToIndex(context, index),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    label: Text('Resumen'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.storefront_outlined),
                    label: Text('Negocios'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.people_outline),
                    label: Text('Usuarios'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.fact_check_outlined),
                    label: Text('Auditoría'),
                  ),
                ],
              ),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }

  void _goToIndex(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/admin');
        break;
      case 1:
        context.go('/admin/businesses/pending');
        break;
      case 2:
        context.go('/admin/users');
        break;
      case 3:
        context.go('/admin/audit');
        break;
    }
  }

  int _selectedIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/admin/businesses')) return 1;
    if (path.startsWith('/admin/users')) return 2;
    if (path.startsWith('/admin/audit')) return 3;
    return 0;
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.count,
    required this.icon,
    required this.tone,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: tone, size: 20),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: Color(0xFF9AA8A2),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                count.toString(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: tone,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF53675E),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminHeroPanel extends StatelessWidget {
  const _AdminHeroPanel({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RancoColors.forest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.admin_panel_settings_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFDDEFE7),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.fact_check_outlined),
            label: Text(actionLabel),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: RancoColors.forest,
            ),
          ),
        ],
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

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6E3DD)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
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

class _BusinessReviewCard extends StatelessWidget {
  const _BusinessReviewCard({
    required this.item,
    required this.onTap,
  });

  final AdminBusinessReviewSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD6E3DD)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _statusColor(item.publicationStatus)
                      .withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _typeIcon(item.businessType),
                  color: _statusColor(item.publicationStatus),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF30443B),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.businessType.label} · ${item.categoryName ?? 'Sin categoría'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF61736A)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.ownerName ?? item.ownerEmail ?? 'Sin propietario',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF7A8A83),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusPill(status: item.publicationStatus.label),
                  const SizedBox(height: 8),
                  Text(
                    _shortDate(
                      (item.submittedAt ?? item.createdAt)?.toIso8601String(),
                    ),
                    style: const TextStyle(
                      color: Color(0xFF7A8A83),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.from,
    required this.to,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final int from;
  final int to;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$from-$to de $total',
          style: const TextStyle(
            color: Color(0xFF53675E),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        IconButton.outlined(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        const SizedBox(width: 6),
        IconButton.outlined(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader({
    required this.title,
    required this.type,
    required this.status,
    required this.owner,
    required this.category,
  });

  final String title;
  final String type;
  final String status;
  final String owner;
  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RancoColors.forest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$type · $category · $owner',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFDDEFE7)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StatusPill(status: status, light: true),
        ],
      ),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6E3DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Decisión',
            style: TextStyle(
              color: Color(0xFF30443B),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Estado actual: $status',
            style: const TextStyle(color: Color(0xFF61736A)),
          ),
          if (loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: canPublish ? onPublish : null,
            icon: const Icon(Icons.public_outlined),
            label: const Text('Publicar'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: canRequestChanges ? onRequestChanges : null,
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('Solicitar cambios'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: canReject ? onReject : null,
            icon: const Icon(Icons.block_outlined),
            label: const Text('Rechazar'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: canSuspend ? onSuspend : null,
            icon: const Icon(Icons.gpp_bad_outlined),
            label: const Text('Suspender'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: canRestore ? onRestore : null,
            icon: const Icon(Icons.restore_outlined),
            label: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.status,
    this.light = false,
  });

  final String status;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: light ? Colors.white : const Color(0xFFE4F1EB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: light ? RancoColors.forest : const Color(0xFF30443B),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
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
    return SizedBox(
      width: 420,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              ...rows.map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${row.label}: ${row.value}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        children: children,
      ),
    );
  }
}

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
