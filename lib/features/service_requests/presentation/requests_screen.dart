import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/ranco_error_state.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/models/service_request.dart';
import '../application/service_request_providers.dart';

class RequestsScreen extends ConsumerWidget {
  const RequestsScreen({super.key});

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
          data: (items) => ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: [
              Text('Solicitudes', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Revisa aquí los servicios que has solicitado.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.go('/explore'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Buscar un prestador'),
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
        Text('Solicitudes', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Pide servicios y mantén cada solicitud organizada en un solo lugar.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.onTap});

  final ServiceRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
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
                child: Icon(Icons.assignment_outlined, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.publicCode,
                        style: Theme.of(context).textTheme.titleMedium),
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
              Text(request.status.label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded),
            ],
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
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
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
      appBar: AppBar(title: const Text('Solicitud')),
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
            const ListTile(
              leading: Icon(Icons.check_circle_outline),
              title: Text('Solicitud enviada'),
              subtitle: Text(
                  'Las siguientes etapas se habilitarán en próximos sprints.'),
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
