import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/profile/application/profile_providers.dart';
import '../../../shared/models/business.dart';
import '../../../shared/models/profile.dart';
import '../data/admin_business_review_repository.dart';

final currentAdminRoleProvider = FutureProvider<ProfileRole?>((ref) async {
  final profile = await ref.watch(currentProfileProvider.future);

  return profile.role.canAccessAdmin ? profile.role : null;
});

final adminReviewStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final result = await ref.watch(adminBusinessReviewRepositoryProvider).stats();

  return result.when(
    success: (stats) => stats,
    failure: (failure) => throw failure,
  );
});

final adminBusinessReviewPageProvider = FutureProvider.family<
    AdminBusinessReviewPage,
    ({
      BusinessPublicationStatus status,
      BusinessType? businessType,
      String? search,
      int limit,
      int offset,
    })>((ref, query) async {
  final result = await ref.watch(adminBusinessReviewRepositoryProvider).list(
        status: query.status,
        businessType: query.businessType,
        search: query.search,
        limit: query.limit,
        offset: query.offset,
      );

  return result.when(
    success: (page) => page,
    failure: (failure) => throw failure,
  );
});

final adminBusinessReviewDetailProvider =
    FutureProvider.family<AdminBusinessReviewDetail, String>(
        (ref, businessId) async {
  final result =
      await ref.watch(adminBusinessReviewRepositoryProvider).detail(businessId);

  return result.when(
    success: (detail) => detail,
    failure: (failure) => throw failure,
  );
});
