import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/supabase_auth_repository.dart';
import '../../categories/data/category_dto.dart';
import '../../../shared/models/category.dart';

final adminSettingsRepositoryProvider =
    Provider<AdminSettingsRepository>((ref) {
  return AdminSettingsRepository(ref.watch(supabaseClientProvider));
});

class AdminWhatsAppSettings {
  const AdminWhatsAppSettings({
    required this.number,
    required this.enabled,
    required this.newBusiness,
    required this.businessChanges,
    required this.userReports,
  });

  final String number;
  final bool enabled;
  final bool newBusiness;
  final bool businessChanges;
  final bool userReports;

  factory AdminWhatsAppSettings.fromRows(List<Map<String, dynamic>> rows) {
    final values = {for (final row in rows) row['key'] as String: row['value']};
    return AdminWhatsAppSettings(
      number: values['admin_whatsapp_number'] as String? ?? '',
      enabled: values['whatsapp_notifications_enabled'] == true,
      newBusiness: values['whatsapp_notify_new_business'] == true,
      businessChanges: values['whatsapp_notify_business_changes'] == true,
      userReports: values['whatsapp_notify_user_reports'] == true,
    );
  }
}

class ReviewWhatsAppDetails {
  const ReviewWhatsAppDetails({
    required this.number,
    required this.businessName,
    required this.category,
    required this.location,
    required this.eventType,
  });

  final String number;
  final String businessName;
  final String category;
  final String location;
  final String eventType;

  Uri get link {
    final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
    final message = [
      '🟢 Ranco Conecta',
      '',
      eventType == 'resubmitted'
          ? 'Modificación de negocio pendiente de revisión'
          : 'Nuevo negocio pendiente de revisión',
      '',
      'Nombre: $businessName',
      'Categoría: $category',
      if (location.isNotEmpty) 'Localidad: $location',
      'Estado: Pendiente revisión',
      '',
      'Revisar: https://www.rancoconecta.cl/admin',
    ].join('\n');
    return Uri.https('wa.me', '/$digits', {'text': message});
  }

  static ReviewWhatsAppDetails? fromJson(Object? value) {
    if (value is! Map) return null;
    final number = value['number']?.toString() ?? '';
    if (number.replaceAll(RegExp(r'[^0-9]'), '').length < 8) return null;
    return ReviewWhatsAppDetails(
      number: number,
      businessName: value['business_name']?.toString() ?? 'Negocio',
      category: value['category']?.toString() ?? 'Sin categoría',
      location: value['location']?.toString() ?? '',
      eventType: value['event_type']?.toString() ?? 'submitted',
    );
  }
}

class AdminSettingsRepository {
  const AdminSettingsRepository(this._client);

  final SupabaseClient? _client;

  Future<List<Category>> listCategories() async {
    final client = _client;
    if (client == null) throw StateError('Supabase no está configurado.');
    final rows = await client.rpc<List<dynamic>>('admin_list_categories');
    return rows
        .map((row) =>
            CategoryDto.fromJson(Map<String, dynamic>.from(row as Map))
                .toDomain())
        .toList();
  }

  Future<void> saveCategory(
      {String? id,
      required String name,
      required String slug,
      required bool active}) async {
    final client = _client;
    if (client == null) throw StateError('Supabase no está configurado.');
    await client.rpc('admin_upsert_category', params: {
      'p_id': id,
      'p_name': name,
      'p_slug': slug,
      'p_active': active,
    });
  }

  Future<void> deleteCategory(String id) async {
    final client = _client;
    if (client == null) throw StateError('Supabase no está configurado.');
    await client.rpc('admin_delete_category', params: {'p_id': id});
  }

  Future<AdminWhatsAppSettings> getWhatsAppSettings() async {
    final client = _client;
    if (client == null) throw StateError('Supabase no está configurado.');
    final rows =
        await client.from('system_settings').select('key,value').inFilter(
      'key',
      [
        'admin_whatsapp_number',
        'whatsapp_notifications_enabled',
        'whatsapp_notify_new_business',
        'whatsapp_notify_business_changes',
        'whatsapp_notify_user_reports',
      ],
    );
    return AdminWhatsAppSettings.fromRows(rows);
  }

  Future<void> saveWhatsAppSettings(AdminWhatsAppSettings settings) async {
    final client = _client;
    if (client == null) throw StateError('Supabase no está configurado.');
    await client.rpc('admin_update_whatsapp_settings', params: {
      'p_number': settings.number,
      'p_enabled': settings.enabled,
      'p_new_business': settings.newBusiness,
      'p_changes': settings.businessChanges,
      'p_reports': settings.userReports,
    });
  }

  Future<ReviewWhatsAppDetails?> reviewWhatsAppDetails(
      String businessId) async {
    final client = _client;
    if (client == null) return null;
    final value = await client.rpc<Object?>(
      'review_whatsapp_details',
      params: {'p_business_id': businessId},
    );
    return ReviewWhatsAppDetails.fromJson(value);
  }

  Future<Map<String, int>> analyticsSummary() async {
    final client = _client;
    if (client == null) throw StateError('Supabase no está configurado.');
    final value =
        await client.rpc<Map<String, dynamic>>('admin_analytics_summary');
    return value.map((key, count) => MapEntry(key, (count as num).toInt()));
  }

  Future<AdminUsersPage> listUsers({
    int page = 1,
    int pageSize = 50,
    String? search,
    String? role,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase no está configurado.');
    final result =
        await client.rpc<Map<String, dynamic>>('admin_search_users', params: {
      'p_page': page,
      'p_page_size': pageSize,
      'p_search': search?.trim().isEmpty == true ? null : search?.trim(),
      'p_role': role,
    });
    return AdminUsersPage(
      rows: (result['rows'] as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList(),
      total: (result['total_count'] as num).toInt(),
    );
  }
}

class AdminUsersPage {
  const AdminUsersPage({required this.rows, required this.total});

  final List<Map<String, dynamic>> rows;
  final int total;
}
