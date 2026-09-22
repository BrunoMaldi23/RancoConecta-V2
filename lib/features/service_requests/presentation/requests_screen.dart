import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/ranco_error_state.dart';
import '../../../theme/ranco_colors.dart';
import '../../../theme/ranco_decoration.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/models/service_request.dart';
import '../application/service_request_providers.dart';
import '../../../core/widgets/ranco_app_bar.dart';

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({
    this.showBack = false,
    super.key,
  });

  final bool showBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      data: (user) {
        if (user == null) {
          return const _GuestRequests();
        }
        final requests = ref.watch(myRequestsProvider);
        return requests.when(
          data: (items) => Container(
            decoration: const BoxDecoration(gradient: RancoDecoration.pageGlow),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              children: [
                _RequestsHeader(count: items.length),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.go('/explore'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Buscar un prestador'),
                  style: FilledButton.styleFrom(
                    backgroundColor: RancoColors.pine,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 18),
                if (items.isEmpty)
                  const _InfoPanel(
                    icon: Icons.assignment_outlined,
                    title: 'Aún no tienes solicitudes',
                    message:
                        'Cuando envíes una solicitud desde el perfil de un prestador aparecerá aquí.',
                  )
                else
                  for (var index = 0; index < items.length; index++) ...[
                    _RequestCard(
                      request: items[index],
                      onTap: () => context.go('/requests/${items[index].id}'),
                    ),
                    if (index != items.length - 1) const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => RancoErrorState(
            message: requestFailureMessage(error),
            onRetry: () => ref.invalidate(myRequestsProvider),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          const RancoErrorState(message: 'No pudimos leer la sesión.'),
    );
  }
}

class _GuestRequests extends StatelessWidget {
  const _GuestRequests();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        const _RequestsHeader(
          count: 0,
          guest: true,
        ),
        const SizedBox(height: 18),
        const _InfoPanel(
          icon: Icons.assignment_outlined,
          title: 'Tus solicitudes aparecerán aquí',
          message:
              'Inicia sesión para solicitar servicios, revisar estados y volver a contactar a tus prestadores.',
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => context.go('/sign-in'),
          icon: const Icon(Icons.login_rounded),
          label: const Text('Ingresar'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.go('/sign-up'),
          child: const Text('Crear cuenta'),
        ),
      ],
    );
  }
}

class _RequestsHeader extends StatelessWidget {
  const _RequestsHeader({
    required this.count,
    this.guest = false,
  });

  final int count;
  final bool guest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: RancoDecoration.warmGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5D8C7)),
        boxShadow: RancoDecoration.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .78),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: RancoColors.lake,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Solicitudes',
                  style: TextStyle(
                    color: RancoColors.pine,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  guest
                      ? 'Pide servicios y mantén cada solicitud organizada en un solo lugar.'
                      : count == 0
                          ? 'Aún no hay actividad. Empieza contactando a un prestador.'
                          : '$count ${count == 1 ? 'solicitud activa' : 'solicitudes registradas'} en tu cuenta.',
                  style: const TextStyle(
                    color: RancoColors.slate,
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

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onTap});

  final ServiceRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: RancoDecoration.card(radius: 18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.assignment_outlined,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.publicCode,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${request.businessName ?? 'Solicitud abierta'} · ${request.subcategoryName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  request.status.label,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: RancoDecoration.card(radius: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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

class RequestDetailScreen extends ConsumerWidget {
  const RequestDetailScreen({required this.requestId, super.key});

  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = ref.watch(requestDetailProvider(requestId));
    final dateFormat = DateFormat.yMMMd('es');
    return Scaffold(
      appBar: const RancoAppBar(
        title: 'Solicitud',
        fallbackRoute: '/requests',
      ),
      body: request.when(
        data: (request) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(request.publicCode,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(request.status.label),
            const SizedBox(height: 20),
            _DetailRow(
                label: 'Negocio',
                value: request.businessName ?? 'Solicitud abierta'),
            _DetailRow(label: 'Servicio', value: request.subcategoryName),
            _DetailRow(label: 'Urgencia', value: request.urgency.label),
            _DetailRow(
              label: 'Fecha deseada',
              value: request.desiredDate == null
                  ? 'No definida'
                  : dateFormat.format(request.desiredDate!),
            ),
            _DetailRow(
                label: 'Dirección',
                value: request.addressText ?? 'No informada'),
            const SizedBox(height: 20),
            Text('Descripción', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(request.description),
            const SizedBox(height: 24),
            Text('Timeline', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Solicitud enviada'),
              subtitle: Text(
                request.status.label,
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => RancoErrorState(
          message: requestFailureMessage(error),
          onRetry: () => ref.invalidate(requestDetailProvider(requestId)),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
