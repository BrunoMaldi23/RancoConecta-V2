import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/supabase_auth_repository.dart';

final lodgingCalendarRepositoryProvider =
    Provider<LodgingCalendarRepository>((ref) {
  return LodgingCalendarRepository(
    ref.watch(supabaseClientProvider),
  );
});

enum LodgingDayStatus {
  available,
  blocked,
}

class LodgingCalendarDay {
  const LodgingCalendarDay({
    required this.id,
    required this.businessId,
    required this.date,
    required this.status,
    required this.priceOverride,
    required this.note,
  });

  factory LodgingCalendarDay.fromJson(
    Map<String, dynamic> json,
  ) {
    return LodgingCalendarDay(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      date: DateTime.parse(
        json['date'] as String,
      ),
      status: switch (json['status']) {
        'blocked' => LodgingDayStatus.blocked,
        _ => LodgingDayStatus.available,
      },
      priceOverride: (json['price_override'] as num?)?.toInt(),
      note: json['note'] as String?,
    );
  }

  final String id;
  final String businessId;
  final DateTime date;
  final LodgingDayStatus status;
  final int? priceOverride;
  final String? note;

  bool get isBlocked => status == LodgingDayStatus.blocked;
}

class LodgingCalendarRepository {
  const LodgingCalendarRepository(
    this._client,
  );

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;

    if (client == null) {
      throw StateError(
        'Supabase no esta configurado.',
      );
    }

    return client;
  }

  Future<List<LodgingCalendarDay>> listMonth({
    required String businessId,
    required DateTime month,
  }) async {
    final first = DateTime(
      month.year,
      month.month,
      1,
    );

    final last = DateTime(
      month.year,
      month.month + 1,
      0,
    );

    final rows = await _requireClient
        .from('lodging_calendar')
        .select(
          'id,business_id,date,status,price_override,note',
        )
        .eq(
          'business_id',
          businessId,
        )
        .gte(
          'date',
          _date(first),
        )
        .lte(
          'date',
          _date(last),
        )
        .order(
          'date',
          ascending: true,
        );

    return rows
        .map(
          (row) => LodgingCalendarDay.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  Future<List<LodgingCalendarDay>> listRange({
    required String businessId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _requireClient
        .from('lodging_calendar')
        .select(
          'id,business_id,date,status,price_override,note',
        )
        .eq(
          'business_id',
          businessId,
        )
        .gte(
          'date',
          _date(from),
        )
        .lte(
          'date',
          _date(to),
        )
        .order(
          'date',
          ascending: true,
        );

    return rows
        .map(
          (row) => LodgingCalendarDay.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  Future<void> saveDay({
    required String businessId,
    required DateTime date,
    required LodgingDayStatus status,
    int? priceOverride,
    String? note,
  }) async {
    await _requireClient.from('lodging_calendar').upsert(
      {
        'business_id': businessId,
        'date': _date(date),
        'status': switch (status) {
          LodgingDayStatus.available => 'available',
          LodgingDayStatus.blocked => 'blocked',
        },
        'price_override': priceOverride,
        'note': note?.trim().isEmpty == true ? null : note?.trim(),
      },
      onConflict: 'business_id,date',
    );
  }

  Future<void> resetDay({
    required String businessId,
    required DateTime date,
  }) async {
    await _requireClient
        .from('lodging_calendar')
        .delete()
        .eq(
          'business_id',
          businessId,
        )
        .eq(
          'date',
          _date(date),
        );
  }

  static String _date(
    DateTime value,
  ) {
    final year = value.year.toString().padLeft(4, '0');

    final month = value.month.toString().padLeft(2, '0');

    final day = value.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
