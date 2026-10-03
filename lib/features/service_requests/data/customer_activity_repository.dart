import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/models/service_request_status.dart';
import '../../auth/data/supabase_auth_repository.dart';
import '../domain/customer_activity_item.dart';

final customerActivityRepositoryProvider = Provider<CustomerActivityRepository>(
  (ref) => CustomerActivityRepository(ref.watch(supabaseClientProvider)),
);

class CustomerActivityRepository {
  const CustomerActivityRepository(this._client);

  final SupabaseClient? _client;

  Future<List<CustomerActivityItem>> listMine(String userId) async {
    final client = _client;
    if (client == null || client.auth.currentUser?.id != userId) {
      return const [];
    }
    final groups = await Future.wait([
      _services(client, userId),
      _lodging(client, userId),
      _gastronomy(client, userId),
    ]);
    final items = groups.expand((group) => group).toList();
    items.sort((a, b) {
      final byDate = b.createdAt.compareTo(a.createdAt);
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });
    return items;
  }

  Future<List<CustomerActivityItem>> _services(
      SupabaseClient client, String userId) async {
    final rows = await client
        .from('service_requests')
        .select('id,business_id,public_code,description,status,created_at,'
            'businesses(name,business_type),subcategories(name)')
        .eq('customer_id', userId)
        .order('created_at', ascending: false);
    return rows.map((row) {
      final status = ServiceRequestStatus.parse(row['status'] as String);
      final businessId = row['business_id'] as String?;
      return CustomerActivityItem(
        id: row['id'] as String,
        businessId: businessId,
        businessName: _relatedName(row['businesses']) ?? 'Solicitud abierta',
        type: row['businesses'] is Map &&
                (row['businesses'] as Map)['business_type'] == 'tourism'
            ? CustomerActivityType.tourism
            : CustomerActivityType.service,
        createdAt: DateTime.parse(row['created_at'] as String),
        stage: CustomerActivityItem.serviceStage(status),
        statusLabel: status.label,
        summary: _relatedName(row['subcategories']) ?? 'Servicio',
        description: row['description'] as String?,
        publicCode: row['public_code'] as String?,
        isQuoted: status == ServiceRequestStatus.quoted,
        detailRoute: '/requests/${row['id']}',
      );
    }).toList();
  }

  Future<List<CustomerActivityItem>> _lodging(
      SupabaseClient client, String userId) async {
    final rows = await client
        .from('lodging_bookings')
        .select('id,business_id,check_in,check_out,status,created_at,'
            'businesses(name)')
        .eq('guest_user_id', userId)
        .order('created_at', ascending: false);
    return rows.map((row) {
      final businessId = row['business_id'] as String;
      final status = row['status'] as String;
      return CustomerActivityItem(
        id: row['id'] as String,
        businessId: businessId,
        businessName: _relatedName(row['businesses']) ?? 'Alojamiento',
        type: CustomerActivityType.lodging,
        createdAt: DateTime.parse(row['created_at'] as String),
        stage: CustomerActivityItem.lodgingStage(status),
        statusLabel: _lodgingLabel(status),
        summary: 'Alojamiento · ${row['check_in']} al ${row['check_out']}',
        detailRoute: '/business/$businessId',
      );
    }).toList();
  }

  Future<List<CustomerActivityItem>> _gastronomy(
      SupabaseClient client, String userId) async {
    final rows = await client
        .from('gastronomy_table_reservations')
        .select('id,business_id,reservation_date,reservation_time,status,'
            'created_at,businesses(name)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map((row) {
      final businessId = row['business_id'] as String;
      final status = row['status'] as String;
      final time = (row['reservation_time'] as String).substring(0, 5);
      return CustomerActivityItem(
        id: row['id'] as String,
        businessId: businessId,
        businessName: _relatedName(row['businesses']) ?? 'Gastronomía',
        type: CustomerActivityType.gastronomy,
        createdAt: DateTime.parse(row['created_at'] as String),
        stage: CustomerActivityItem.gastronomyStage(status),
        statusLabel: _gastronomyLabel(status),
        summary: 'Reserva de mesa · ${row['reservation_date']} $time',
        detailRoute: '/business/$businessId',
      );
    }).toList();
  }

  static String? _relatedName(Object? value) =>
      value is Map ? value['name'] as String? : null;

  static String _lodgingLabel(String status) => switch (status) {
        'pending' => 'Pendiente',
        'accepted' => 'Aceptada',
        'rejected' => 'Rechazada',
        'cancelled' => 'Cancelada',
        _ => status,
      };

  static String _gastronomyLabel(String status) => switch (status) {
        'pending' => 'Pendiente',
        'confirmed' => 'Confirmada',
        'rejected' => 'Rechazada',
        'cancelled' => 'Cancelada',
        _ => status,
      };
}
