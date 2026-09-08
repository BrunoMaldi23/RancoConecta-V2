import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/business_review.dart';
import '../data/reviews_repository.dart';

final businessReviewsProvider =
    FutureProvider.family<List<BusinessReview>, String>(
  (ref, businessId) {
    return ref.watch(reviewsRepositoryProvider).listPublished(businessId);
  },
);

final myBusinessReviewProvider = FutureProvider.family<BusinessReview?, String>(
  (ref, businessId) {
    return ref.watch(reviewsRepositoryProvider).myReview(businessId);
  },
);
