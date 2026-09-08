import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/supabase_auth_repository.dart';

final lodgingBookingRepositoryProvider =
    Provider<LodgingBookingRepository>((ref) {
  return LodgingBookingRepository(
    ref.watch(supabaseClientProvider),
  );
});

class LodgingBooking {
  const LodgingBooking({
    required this.id,
    required this.businessId,
    required this.guestUserId,
    required this.guestName,
    required this.guestEmail,
    required this.checkIn,
    required this.checkOut,
    required this.guests,
    required this.nights,
    required this.baseAmount,
    required this.extraGuestAmount,
    required this.totalAmount,
    required this.status,
    required this.guestMessage,
    required this.createdAt,
  });

  factory LodgingBooking.fromJson(
    Map<String, dynamic> json,
  ) {
    return LodgingBooking(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      guestUserId: json['guest_user_id'] as String,
      guestName: json['guest_name'] as String? ?? 'Huésped',
      guestEmail: json['guest_email'] as String?,
      checkIn: DateTime.parse(
        json['check_in'] as String,
      ),
      checkOut: DateTime.parse(
        json['check_out'] as String,
      ),
      guests: (json['guests'] as num).toInt(),
      nights: (json['nights'] as num).toInt(),
      baseAmount: (json['base_amount'] as num).toInt(),
      extraGuestAmount: (json['extra_guest_amount'] as num).toInt(),
      totalAmount: (json['total_amount'] as num).toInt(),
      status: json['status'] as String? ?? 'pending',
      guestMessage: json['guest_message'] as String?,
      createdAt: DateTime.parse(
        json['created_at'] as String,
      ),
    );
  }

  final String id;
  final String businessId;
  final String guestUserId;
  final String guestName;
  final String? guestEmail;

  final DateTime checkIn;
  final DateTime checkOut;

  final int guests;
  final int nights;

  final int baseAmount;
  final int extraGuestAmount;
  final int totalAmount;

  final String status;
  final String? guestMessage;

  final DateTime createdAt;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
}

class LodgingBookingRepository {
  const LodgingBookingRepository(
    this._client,
  );

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;

    if (client == null) {
      throw StateError(
        'Supabase no está configurado.',
      );
    }

    return client;
  }

  Future<String> create({
    required String businessId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guests,
    String? message,
  }) async {
    final result = await _requireClient.rpc(
      'create_lodging_booking',
      params: {
        'p_business_id': businessId,
        'p_check_in': _date(checkIn),
        'p_check_out': _date(checkOut),
        'p_guests': guests,
        'p_message': message,
      },
    );

    return result.toString();
  }

  Future<List<LodgingBooking>> listForBusiness(
    String businessId,
  ) async {
    final rows = await _requireClient
        .from('lodging_bookings')
        .select()
        .eq(
          'business_id',
          businessId,
        )
        .order(
          'created_at',
          ascending: false,
        );

    return rows
        .map(
          (row) => LodgingBooking.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  Future<List<LodgingBooking>> listMine() async {
    final userId = _requireClient.auth.currentUser?.id;

    if (userId == null) {
      return const [];
    }

    final rows = await _requireClient
        .from('lodging_bookings')
        .select()
        .eq(
          'guest_user_id',
          userId,
        )
        .order(
          'created_at',
          ascending: false,
        );

    return rows
        .map(
          (row) => LodgingBooking.fromJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  Future<void> accept(
    String bookingId,
  ) async {
    await _requireClient.rpc(
      'accept_lodging_booking',
      params: {
        'p_booking_id': bookingId,
      },
    );
  }

  Future<void> reject(
    String bookingId,
  ) async {
    await _requireClient.rpc(
      'reject_lodging_booking',
      params: {
        'p_booking_id': bookingId,
      },
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
