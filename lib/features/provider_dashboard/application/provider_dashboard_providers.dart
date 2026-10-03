import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../shared/models/business_capability.dart';
import '../../profile/application/profile_providers.dart';
import '../data/business_media_repository.dart';
import '../data/lodging_calendar_repository.dart';
import '../data/lodging_details_repository.dart';
import '../data/provider_business_repository.dart';
import '../data/service_business_management_repository.dart';
import 'provider_context_state.dart';

final myProviderBusinessProvider =
    FutureProvider<ProviderBusinessSummary?>((ref) async {
  return ref.watch(activeProviderBusinessProvider.future);
});

final activeProviderBusinessIdProvider = StateProvider<String?>((ref) {
  return null;
});

final myProviderBusinessesProvider =
    FutureProvider<List<ProviderBusinessSummary>>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile.role.canAccessAdmin) {
    return const [];
  }
  return ref
      .watch(
        providerBusinessRepositoryProvider,
      )
      .getMyBusinesses();
});

final activeProviderBusinessProvider =
    FutureProvider<ProviderBusinessSummary?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);
  if (profile.role.canAccessAdmin) {
    if (ref.read(activeProviderBusinessIdProvider) != null) {
      Future.microtask(() {
        ref.read(activeProviderBusinessIdProvider.notifier).state = null;
      });
    }
    return null;
  }
  final businesses = await ref.watch(
    myProviderBusinessesProvider.future,
  );

  if (businesses.isEmpty) {
    return null;
  }

  final activeId = ref.watch(activeProviderBusinessIdProvider);
  final business = selectActiveProviderBusiness(
    businesses: businesses,
    activeBusinessId: activeId,
  );

  if (activeId != null && business?.id != activeId) {
    Future.microtask(() {
      ref.read(activeProviderBusinessIdProvider.notifier).state = null;
    });
  }

  return business;
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

final serviceBusinessManagementProvider =
    FutureProvider<ServiceBusinessManagementState?>((ref) async {
  final business = await ref.watch(activeProviderBusinessProvider.future);

  if (business == null) {
    return null;
  }

  final result = await ref
      .watch(serviceBusinessManagementRepositoryProvider)
      .load(business.id);

  return result.when(
    success: (state) => state,
    failure: (failure) => throw failure,
  );
});

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
