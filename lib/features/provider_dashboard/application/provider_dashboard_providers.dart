import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../shared/models/business_capability.dart';
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

final activeProviderBusinessIdProvider = StateProvider<String?>((ref) {
  return null;
});

final myProviderBusinessesProvider =
    FutureProvider<List<ProviderBusinessSummary>>((ref) {
  return ref
      .watch(
        providerBusinessRepositoryProvider,
      )
      .getMyBusinesses();
});

final activeProviderBusinessProvider =
    FutureProvider<ProviderBusinessSummary?>((ref) async {
  final businesses = await ref.watch(
    myProviderBusinessesProvider.future,
  );

  if (businesses.isEmpty) {
    return null;
  }

  final activeId = ref.watch(activeProviderBusinessIdProvider);

  if (activeId == null) {
    return businesses.first;
  }

  return businesses.firstWhere(
    (business) => business.id == activeId,
    orElse: () => businesses.first,
  );
});

final businessCapabilityResolverProvider =
    Provider<BusinessCapabilityResolver>((ref) {
  return BusinessCapabilityResolver(
    featureFlags: ref.watch(appConfigProvider).featureFlags,
  );
});

final activeProviderCapabilitiesProvider =
    FutureProvider<BusinessCapabilitySet>((ref) async {
  final business = await ref.watch(activeProviderBusinessProvider.future);
  final resolver = ref.watch(businessCapabilityResolverProvider);

  if (business == null) {
    return const BusinessCapabilitySet({});
  }

  return resolver.resolve(
    businessType: business.businessType,
  );
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
