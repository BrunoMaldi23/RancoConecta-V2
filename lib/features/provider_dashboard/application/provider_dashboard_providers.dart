import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/business_media_repository.dart';
import '../data/lodging_calendar_repository.dart';
import '../data/lodging_details_repository.dart';
import '../data/provider_business_repository.dart';

final myProviderBusinessProvider =
    FutureProvider<ProviderBusinessSummary?>((ref) {
  return ref
      .watch(
        providerBusinessRepositoryProvider,
      )
      .getMyBusiness();
});

final lodgingDetailsProvider = FutureProvider.family<LodgingDetails, String>(
  (ref, businessId) {
    return ref
        .watch(
          lodgingDetailsRepositoryProvider,
        )
        .getDetails(
          businessId,
        );
  },
);

final providerBusinessMediaProvider =
    FutureProvider.family<List<ProviderMediaItem>, String>(
  (ref, businessId) {
    return ref
        .watch(
          businessMediaRepositoryProvider,
        )
        .list(
          businessId,
        );
  },
);

final lodgingCalendarMonthProvider = FutureProvider.family<
    List<LodgingCalendarDay>, ({String businessId, int year, int month})>(
  (
    ref,
    request,
  ) {
    return ref
        .watch(
          lodgingCalendarRepositoryProvider,
        )
        .listMonth(
          businessId: request.businessId,
          month: DateTime(
            request.year,
            request.month,
          ),
        );
  },
);
