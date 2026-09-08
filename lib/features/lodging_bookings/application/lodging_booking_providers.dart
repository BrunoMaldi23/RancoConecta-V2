import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/lodging_booking_repository.dart';

final lodgingBookingsForBusinessProvider =
    FutureProvider.family<List<LodgingBooking>, String>(
  (
    ref,
    businessId,
  ) {
    return ref
        .watch(
          lodgingBookingRepositoryProvider,
        )
        .listForBusiness(
          businessId,
        );
  },
);

final myLodgingBookingsProvider = FutureProvider<List<LodgingBooking>>(
  (ref) {
    return ref
        .watch(
          lodgingBookingRepositoryProvider,
        )
        .listMine();
  },
);
