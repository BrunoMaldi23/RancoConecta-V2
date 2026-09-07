import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/models/business.dart';
import '../../locations/application/location_providers.dart';
import '../data/business_repository.dart';
import 'business_hours.dart';

final businessSearchQueryProvider = StateProvider<String>((ref) => '');

final selectedCategoryIdProvider = StateProvider<String?>((ref) => null);

final verifiedOnlyProvider = StateProvider<bool>((ref) => false);

final featuredOnlyProvider = StateProvider<bool>((ref) => false);

final openNowOnlyProvider = StateProvider<bool>((ref) => false);

final publishedBusinessesProvider = FutureProvider<List<Business>>((ref) async {
  final selectedLocation = ref.watch(selectedLocationProvider);

  final categoryId = ref.watch(selectedCategoryIdProvider);

  final search = ref.watch(businessSearchQueryProvider);

  final verifiedOnly = ref.watch(verifiedOnlyProvider);

  final featuredOnly = ref.watch(featuredOnlyProvider);

  final openNowOnly = ref.watch(openNowOnlyProvider);

  final result =
      await ref.watch(businessRepositoryProvider).listPublishedBusinesses(
            BusinessQuery(
              categoryId: categoryId,
              locationId: selectedLocation?.id,
              searchQuery: search,
              verifiedOnly: verifiedOnly,
              featuredOnly: featuredOnly,
            ),
          );

  return result.when(
    success: (businesses) {
      if (!openNowOnly) {
        return businesses;
      }

      final now = DateTime.now();

      return businesses
          .where(
            (business) => isOpenNow(
              business.hours,
              now,
            ),
          )
          .toList();
    },
    failure: (failure) => throw failure,
  );
});

final businessDetailProvider =
    FutureProvider.family<Business, String>((ref, id) async {
  final result =
      await ref.watch(businessRepositoryProvider).getBusinessById(id);

  return result.when(
    success: (business) => business,
    failure: (failure) => throw failure,
  );
});

void clearBusinessFilters(
  WidgetRef ref,
) {
  ref.read(selectedLocationProvider.notifier).state = null;

  ref.read(selectedCategoryIdProvider.notifier).state = null;

  ref.read(verifiedOnlyProvider.notifier).state = false;

  ref.read(featuredOnlyProvider.notifier).state = false;

  ref.read(openNowOnlyProvider.notifier).state = false;
}

String businessFailureMessage(
  Object error,
) {
  if (error is AppFailure) {
    return error.message;
  }

  return 'No pudimos cargar los negocios.';
}
