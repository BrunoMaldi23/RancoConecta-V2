import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/models/business.dart';
import '../data/favorites_repository.dart';

final favoriteBusinessesProvider = FutureProvider<List<Business>>((ref) async {
  final result = await ref.watch(favoritesRepositoryProvider).listFavorites();
  return result.when(
    success: (businesses) => businesses,
    failure: (failure) => throw failure,
  );
});

final isFavoriteProvider =
    FutureProvider.family<bool, String>((ref, businessId) async {
  final result =
      await ref.watch(favoritesRepositoryProvider).isFavorite(businessId);
  return result.when(
    success: (isFavorite) => isFavorite,
    failure: (failure) => throw failure,
  );
});

String favoritesFailureMessage(Object error) {
  if (error is AppFailure) {
    return error.message;
  }
  return 'No pudimos cargar tus favoritos.';
}
