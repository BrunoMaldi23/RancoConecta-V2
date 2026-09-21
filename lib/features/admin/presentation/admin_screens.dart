import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../shared/models/business.dart';
import '../../../theme/ranco_colors.dart';
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
            backgroundColor: const Color(0xFFEAF4F0),
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
            return GridView.count(
              shrinkWrap: true,
              crossAxisCount: MediaQuery.sizeOf(context).width > 900 ? 5 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _StatCard(
                  label: 'Pendientes',
                  count: items['pending_review'] ?? 0,
                  onTap: () => context.go('/admin/businesses/pending'),
                ),
                _StatCard(
                  label: 'Cambios',
                  count: items['changes_requested'] ?? 0,
                  onTap: () => context.go(
                    '/admin/businesses?status=changes_requested',
                  ),
                ),
                _StatCard(
                  label: 'Publicados',
                  count: items['published'] ?? 0,
                  onTap: () => context.go('/admin/businesses?status=published'),
                ),
                _StatCard(
                  label: 'Rechazados',
                  count: items['rejected'] ?? 0,
                  onTap: () => context.go('/admin/businesses?status=rejected'),
                ),
                _StatCard(
                  label: 'Suspendidos',
                  count: items['suspended'] ?? 0,
                  onTap: () => context.go('/admin/businesses?status=suspended'),
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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Buscar negocio, dueño o contacto',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => setState(() => _offset = 0),
                  ),
                ),
                DropdownButton<BusinessPublicationStatus>(
                  value: _status,
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
                DropdownButton<BusinessType?>(
                  value: _businessType,
                  hint: const Text('Tipo'),
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
                FilledButton.icon(
                  onPressed: () => setState(() => _offset = 0),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Aplicar'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: page.when(
                data: (page) {
                  if (page.items.isEmpty) {
                    return const Center(
                      child: Text('No hay negocios para este filtro.'),
                    );
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          itemCount: page.items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = page.items[index];
                            return ListTile(
                              title: Text(item.name),
                              subtitle: Text(
                                '${item.businessType.label} · ${item.categoryName ?? 'Sin categoría'} · ${item.ownerName ?? item.ownerEmail ?? 'Sin propietario'}',
                              ),
                              trailing: Text(item.publicationStatus.label),
                              onTap: () =>
                                  context.go('/admin/businesses/${item.id}'),
                            );
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                              '${_offset + 1}-${_offset + page.items.length} de ${page.totalCount}'),
                          IconButton(
                            onPressed: _offset == 0
                                ? null
                                : () => setState(() {
                                      _offset = _offset - _limit < 0
                                          ? 0
                                          : _offset - _limit;
                                    }),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          IconButton(
                            onPressed:
                                _offset + page.items.length >= page.totalCount
                                    ? null
                                    : () => setState(() {
                                          _offset += _limit;
                                        }),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
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
          child: Text(message),
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

    return ListView(
      children: [
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_message!),
          ),
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
                _InfoRow('Verificación',
                    business['verification_status']?.toString() ?? ''),
                _InfoRow('Categoría',
                    detail.category['name']?.toString() ?? 'Sin categoría'),
                _InfoRow(
                    'Descripción', business['description']?.toString() ?? ''),
              ],
            ),
            _InfoCard(
              title: 'Propietario y contacto',
              rows: [
                _InfoRow(
                    'Propietario', detail.owner['full_name']?.toString() ?? ''),
                _InfoRow(
                    'Email usuario', detail.owner['email']?.toString() ?? ''),
                _InfoRow('Teléfono', business['phone']?.toString() ?? ''),
                _InfoRow('WhatsApp', business['whatsapp']?.toString() ?? ''),
                _InfoRow('Email negocio', business['email']?.toString() ?? ''),
                _InfoRow(
                    'Dirección', business['address_text']?.toString() ?? ''),
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
                color: ok ? RancoColors.forest : const Color(0xFFB4543F),
              ),
              title: Text(item['message']?.toString() ?? ''),
            );
          }).toList(),
        ),
        _Section(
          title: 'Servicios',
          children: detail.services.isEmpty
              ? [const ListTile(title: Text('Sin servicios registrados.'))]
              : detail.services
                  .map(
                    (item) => ListTile(
                      title: Text(item['subcategory_name']?.toString() ?? ''),
                      subtitle: Text(item['description']?.toString() ?? ''),
                    ),
                  )
                  .toList(),
        ),
        _Section(
          title: 'Cobertura',
          children: detail.coverage.isEmpty
              ? [const ListTile(title: Text('Sin cobertura registrada.'))]
              : detail.coverage
                  .map(
                    (item) => ListTile(
                      title: Text(item['location_name']?.toString() ?? ''),
                      subtitle: Text(item['commune_name']?.toString() ?? ''),
                    ),
                  )
                  .toList(),
        ),
        if (detail.businessType == BusinessType.lodging)
          _Section(
            title: 'Alojamiento',
            children: [
              ListTile(
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
                      title: Text(event['event_type']?.toString() ?? ''),
                      subtitle: Text(event['message']?.toString() ?? ''),
                      trailing: Text(event['created_at']?.toString() ?? ''),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: _loading ? null : () => _publish(context),
              icon: const Icon(Icons.public_outlined),
              label: const Text('Publicar'),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : () => _requestChanges(context),
              icon: const Icon(Icons.rate_review_outlined),
              label: const Text('Solicitar cambios'),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : () => _reject(context),
              icon: const Icon(Icons.block_outlined),
              label: const Text('Rechazar'),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : () => _suspend(context),
              icon: const Icon(Icons.gpp_bad_outlined),
              label: const Text('Suspender'),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : () => _restore(context),
              icon: const Icon(Icons.restore_outlined),
              label: const Text('Restaurar'),
            ),
          ],
        ),
      ],
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
      backgroundColor: const Color(0xFFEAF4F0),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex(context),
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (index) {
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
            },
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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: RancoColors.forest,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.go('/'),
                        child: const Text('Salir admin'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _selectedIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    if (path.startsWith('/admin/businesses')) return 1;
    if (path.startsWith('/admin/users')) return 2;
    if (path.startsWith('/admin/audit')) return 3;
    return 0;
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.count,
    required this.onTap,
  });

  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count.toString(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: RancoColors.forest,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const Spacer(),
              Text(label),
            ],
          ),
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
