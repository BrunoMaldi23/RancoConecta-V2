import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/idempotency_key.dart';

import '../../auth/data/supabase_auth_repository.dart';

final gastronomyRepositoryProvider = Provider<GastronomyRepository>((ref) {
  return GastronomyRepository(ref.watch(supabaseClientProvider));
});

class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.businessId,
    required this.name,
    required this.sortOrder,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      name: json['name'] as String? ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String businessId;
  final String name;
  final int sortOrder;
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.businessId,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    required this.imagePath,
    required this.isAvailable,
    required this.sortOrder,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      categoryId: json['category_id'] as String?,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toInt() ?? 0,
      imagePath: json['image_path'] as String?,
      isAvailable: json['is_available'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String businessId;
  final String? categoryId;
  final String name;
  final String? description;
  final int price;
  final String? imagePath;
  final bool isAvailable;
  final int sortOrder;
}

class TableReservation {
  const TableReservation({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.customerName,
    required this.customerPhone,
    required this.reservationDate,
    required this.reservationTime,
    required this.guests,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory TableReservation.fromJson(Map<String, dynamic> json) {
    return TableReservation(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      userId: json['user_id'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      reservationDate: DateTime.parse(json['reservation_date'] as String),
      reservationTime: _shortTime(json['reservation_time'] as String?),
      guests: (json['guests'] as num?)?.toInt() ?? 1,
      message: json['message'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String businessId;
  final String? userId;
  final String? customerName;
  final String? customerPhone;
  final DateTime reservationDate;
  final String reservationTime;
  final int guests;
  final String? message;
  final String status;
  final DateTime createdAt;

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';

  static String _shortTime(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }

    final parts = value.split(':');
    if (parts.length < 2) {
      return value;
    }

    return '${parts[0]}:${parts[1]}';
  }
}

class MenuDraftCategory {
  const MenuDraftCategory({
    this.id,
    required this.name,
    required this.sortOrder,
  });

  final String? id;
  final String name;
  final int sortOrder;
}

class MenuDraftItem {
  const MenuDraftItem({
    this.id,
    this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    required this.isAvailable,
    required this.sortOrder,
  });

  final String? id;
  final String? categoryId;
  final String name;
  final String description;
  final int price;
  final bool isAvailable;
  final int sortOrder;
}

class GastronomyMenu {
  const GastronomyMenu({
    required this.categories,
    required this.items,
  });

  final List<MenuCategory> categories;
  final List<MenuItem> items;
}

class GastronomyRepository {
  const GastronomyRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase no está configurado.');
    }

    return client;
  }

  Future<GastronomyMenu> getMenu(String businessId) async {
    final categories = await _requireClient
        .from('gastronomy_menu_categories')
        .select()
        .eq('business_id', businessId)
        .order('sort_order');

    final items = await _requireClient
        .from('gastronomy_menu_items')
        .select()
        .eq('business_id', businessId)
        .order('sort_order');

    return GastronomyMenu(
      categories: categories
          .map((row) => MenuCategory.fromJson(Map<String, dynamic>.from(row)))
          .toList(),
      items: items
          .map((row) => MenuItem.fromJson(Map<String, dynamic>.from(row)))
          .toList(),
    );
  }

  Future<void> replaceMenu({
    required String businessId,
    required List<MenuDraftCategory> categories,
    required List<MenuDraftItem> items,
  }) async {
    final client = _requireClient;

    await client
        .from('gastronomy_menu_items')
        .delete()
        .eq('business_id', businessId);
    await client
        .from('gastronomy_menu_categories')
        .delete()
        .eq('business_id', businessId);

    final categoryIdByLocalIndex = <int, String>{};

    for (var index = 0; index < categories.length; index++) {
      final category = categories[index];
      final row = await client
          .from('gastronomy_menu_categories')
          .insert({
            'business_id': businessId,
            'name': category.name.trim(),
            'sort_order': category.sortOrder,
          })
          .select('id')
          .single();

      categoryIdByLocalIndex[index] = row['id'] as String;
    }

    for (final item in items) {
      final categoryIndex = int.tryParse(item.categoryId ?? '');
      await client.from('gastronomy_menu_items').insert({
        'business_id': businessId,
        'category_id': categoryIndex == null
            ? null
            : categoryIdByLocalIndex[categoryIndex],
        'name': item.name.trim(),
        'description':
            item.description.trim().isEmpty ? null : item.description.trim(),
        'price': item.price,
        'is_available': item.isAvailable,
        'sort_order': item.sortOrder,
      });
    }
  }

  Future<List<TableReservation>> listReservations(String businessId) async {
    final rows = await _requireClient
        .from('gastronomy_table_reservations')
        .select()
        .eq('business_id', businessId)
        .order('reservation_date', ascending: true)
        .order('reservation_time', ascending: true);

    return rows
        .map(
          (row) => TableReservation.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<String> createReservation({
    required String businessId,
    required DateTime date,
    required String time,
    required int guests,
    required String customerName,
    required String customerPhone,
    required String consentVersion,
    String? message,
  }) async {
    await _requireClient.functions.invoke(
      'submit-request',
      headers: {'Idempotency-Key': newIdempotencyKey()},
      body: {
        'kind': 'table_reservation',
        'business_id': businessId,
        'reservation_date': _date(date),
        'reservation_time': time,
        'guests': guests,
        'message': message,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'consent_version': consentVersion,
        'consent_accepted': true,
      },
    );
    return 'created';
  }

  Future<void> confirmReservation(String reservationId) async {
    await _requireClient.rpc(
      'confirm_gastronomy_table_reservation',
      params: {'p_reservation_id': reservationId},
    );
  }

  Future<void> rejectReservation(String reservationId) async {
    await _requireClient.rpc(
      'reject_gastronomy_table_reservation',
      params: {'p_reservation_id': reservationId},
    );
  }

  static String _date(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
