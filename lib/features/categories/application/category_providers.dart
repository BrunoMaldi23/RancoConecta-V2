import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/models/category.dart';
import '../data/category_repository.dart';

final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final result =
      await ref.watch(categoryRepositoryProvider).listActiveCategories();
  return result.when(
    success: (categories) => categories,
    failure: (failure) => throw failure,
  );
});

final subcategoriesProvider =
    FutureProvider.family<List<Subcategory>, String?>((ref, categoryId) async {
  final result = await ref
      .watch(categoryRepositoryProvider)
      .listActiveSubcategories(categoryId: categoryId);
  return result.when(
    success: (subcategories) => subcategories,
    failure: (failure) => throw failure,
  );
});

String failureMessage(Object error, String fallback) {
  if (error is AppFailure) {
    return error.message;
  }
  return fallback;
}
