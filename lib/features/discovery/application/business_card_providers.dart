import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../features/categories/application/category_providers.dart';
import '../../../features/provider_dashboard/data/lodging_details_repository.dart';
import '../../../shared/models/business.dart';
import '../../../shared/models/category.dart';
import 'business_card_data.dart';
import 'explore_businesses_provider.dart';

final exploreBusinessCardDataProvider = FutureProvider.autoDispose
    .family<Map<String, BusinessCardData>, ExploreFilters>(
        (ref, filters) async {
  final categories =
      ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
  final selectedCategoryId = filters.categoryId;
  final businesses = ref.watch(
        exploreBusinessesProvider(filters)
            .select((value) => value.valueOrNull?.items),
      ) ??
      const <Business>[];
  final lodgingIds = businesses
      .where((business) => business.type == BusinessType.lodging)
      .map((business) => business.id);

  var lodgingDetails = <String, LodgingDetails>{};
  try {
    lodgingDetails = await ref
        .watch(lodgingDetailsRepositoryProvider)
        .getDetailsForBusinesses(lodgingIds);
  } catch (error) {
    AppLogger.dataQueryFailure(
      feature: 'discovery',
      endpoint: 'lodging_details:exploreCards',
      error: error,
    );
  }

  return {
    for (final business in businesses)
      business.id: BusinessCardData.fromBusiness(
        business,
        categories: categories,
        selectedCategoryId: selectedCategoryId,
        lodgingDetails: lodgingDetails[business.id],
      ),
  };
});
