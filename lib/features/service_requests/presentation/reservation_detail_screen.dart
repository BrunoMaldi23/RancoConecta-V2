import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/service_request_providers.dart';
import '../domain/customer_activity_item.dart';

class ReservationDetailScreen extends ConsumerWidget {
  const ReservationDetailScreen({
    required this.reservationId,
    required this.type,
    super.key,
  });

  final String reservationId;
  final CustomerActivityType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(myCustomerActivityProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de reserva')),
      body: activity.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: TextButton.icon(
            onPressed: () => ref.invalidate(myCustomerActivityProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('No pudimos cargar la reserva. Reintentar'),
          ),
        ),
        data: (items) {
          CustomerActivityItem? reservation;
          for (final item in items) {
            if (item.id == reservationId && item.type == type) {
              reservation = item;
              break;
            }
          }
          if (reservation == null) {
            return const Center(child: Text('Reserva no encontrada.'));
          }
          final item = reservation;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(item.businessName,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              ListTile(
                  title: const Text('Estado'),
                  subtitle: Text(item.statusLabel)),
              for (final entry in item.details.entries)
                ListTile(title: Text(entry.key), subtitle: Text(entry.value)),
              if (item.businessId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () =>
                          context.push('/business/${item.businessId}'),
                      child: const Text('Ver negocio'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
