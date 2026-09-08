import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/supabase_auth_repository.dart';

final lodgingDetailsRepositoryProvider =
    Provider<LodgingDetailsRepository>((ref) {
  return LodgingDetailsRepository(
    ref.watch(supabaseClientProvider),
  );
});

class LodgingDetails {
  const LodgingDetails({
    required this.businessId,
    required this.pricePerNight,
    required this.maxGuests,
    required this.includedGuests,
    required this.extraGuestPrice,
    required this.bedrooms,
    required this.beds,
    required this.bathrooms,
    required this.checkInTime,
    required this.checkOutTime,
    required this.minNights,
    required this.cancellationPolicy,
    required this.houseRules,
  });

  factory LodgingDetails.fromJson(
    Map<String, dynamic> json,
  ) {
    return LodgingDetails(
      businessId: json['business_id'] as String,
      pricePerNight: (json['price_per_night'] as num?)?.toInt() ?? 0,
      maxGuests: (json['max_guests'] as num?)?.toInt() ?? 2,
      includedGuests: (json['included_guests'] as num?)?.toInt() ?? 2,
      extraGuestPrice: (json['extra_guest_price'] as num?)?.toInt() ?? 0,
      bedrooms: (json['bedrooms'] as num?)?.toInt() ?? 1,
      beds: (json['beds'] as num?)?.toInt() ?? 1,
      bathrooms: (json['bathrooms'] as num?)?.toDouble() ?? 1,
      checkInTime: _shortTime(
        json['check_in_time'] as String?,
      ),
      checkOutTime: _shortTime(
        json['check_out_time'] as String?,
      ),
      minNights: (json['min_nights'] as num?)?.toInt() ?? 1,
      cancellationPolicy: json['cancellation_policy'] as String? ?? '',
      houseRules: json['house_rules'] as String? ?? '',
    );
  }

  final String businessId;
  final int pricePerNight;
  final int maxGuests;
  final int includedGuests;
  final int extraGuestPrice;
  final int bedrooms;
  final int beds;
  final double bathrooms;
  final String checkInTime;
  final String checkOutTime;
  final int minNights;
  final String cancellationPolicy;
  final String houseRules;

  static String _shortTime(
    String? value,
  ) {
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

class LodgingDetailsRepository {
  const LodgingDetailsRepository(
    this._client,
  );

  final SupabaseClient? _client;

  Future<LodgingDetails> getDetails(
    String businessId,
  ) async {
    final client = _client;

    if (client == null) {
      throw StateError(
        'Supabase no esta configurado.',
      );
    }

    final row = await client
        .from('lodging_details')
        .select()
        .eq(
          'business_id',
          businessId,
        )
        .single();

    return LodgingDetails.fromJson(
      Map<String, dynamic>.from(row),
    );
  }

  Future<void> updateInformation({
    required String businessId,
    required int maxGuests,
    required int includedGuests,
    required int bedrooms,
    required int beds,
    required double bathrooms,
    required String checkInTime,
    required String checkOutTime,
    required int minNights,
    required String cancellationPolicy,
    required String houseRules,
  }) async {
    final client = _client;

    if (client == null) {
      throw StateError(
        'Supabase no esta configurado.',
      );
    }

    await client.from('lodging_details').update({
      'max_guests': maxGuests,
      'included_guests': includedGuests,
      'bedrooms': bedrooms,
      'beds': beds,
      'bathrooms': bathrooms,
      'check_in_time': checkInTime,
      'check_out_time': checkOutTime,
      'min_nights': minNights,
      'cancellation_policy':
          cancellationPolicy.trim().isEmpty ? null : cancellationPolicy.trim(),
      'house_rules': houseRules.trim().isEmpty ? null : houseRules.trim(),
    }).eq(
      'business_id',
      businessId,
    );
  }

  Future<void> updateRates({
    required String businessId,
    required int pricePerNight,
    required int includedGuests,
    required int extraGuestPrice,
  }) async {
    final client = _client;

    if (client == null) {
      throw StateError(
        'Supabase no esta configurado.',
      );
    }

    await client.from('lodging_details').update({
      'price_per_night': pricePerNight,
      'included_guests': includedGuests,
      'extra_guest_price': extraGuestPrice,
    }).eq(
      'business_id',
      businessId,
    );
  }
}
