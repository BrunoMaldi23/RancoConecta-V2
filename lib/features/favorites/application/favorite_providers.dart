import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/models/business.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/supabase_auth_repository.dart';
import '../data/favorites_repository.dart';

final favoriteBusinessesProvider = FutureProvider<List<Business>>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return const [];
  final result = await ref.watch(favoritesRepositoryProvider).listFavorites();
  return result.when(
    success: (businesses) => businesses,
    failure: (failure) => throw failure,
  );
});

final favoriteIdsProvider = FutureProvider<Set<String>>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  final client = ref.watch(supabaseClientProvider);
  if (user == null || client == null) return const {};
  final rows = await client
      .from('favorites')
      .select('business_id')
      .eq('user_id', user.id);
  return {for (final row in rows) row['business_id'] as String};
});

final isFavoriteProvider =
    FutureProvider.family<bool, String>((ref, businessId) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return false;
  return (await ref.watch(favoriteIdsProvider.future)).contains(businessId);
});

String favoritesFailureMessage(Object error) {
  if (error is AppFailure) {
    return error.message;
  }
  return 'No pudimos cargar tus favoritos.';
}
