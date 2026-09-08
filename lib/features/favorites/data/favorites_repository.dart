import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/result/result.dart';
import '../../../features/auth/data/supabase_auth_repository.dart';
import '../../../shared/models/business.dart';
import '../../businesses/data/business_dto.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return SupabaseFavoritesRepository(
    ref.watch(supabaseClientProvider),
  );
});

abstract interface class FavoritesRepository {
  Future<Result<List<Business>>> listFavorites();

  Future<Result<bool>> isFavorite(
    String businessId,
  );

  Future<Result<void>> addFavorite(
    String businessId,
  );

  Future<Result<void>> removeFavorite(
    String businessId,
  );
}

class SupabaseFavoritesRepository implements FavoritesRepository {
  const SupabaseFavoritesRepository(
    this._client,
  );

  final SupabaseClient? _client;

  static const _businessSelect = '''
businesses(
  id,
  owner_id,
  business_type,
  name,
  slug,
  description,
  phone,
  whatsapp,
  email,
  website,
  verification_status,
  is_featured,
  accepts_requests,
  rating_avg,
  review_count,
  business_services(
    description,
    price_from,
    subcategory_id,
    subcategories(
      id,
      category_id,
      name,
      slug,
      description,
      icon_key
    )
  ),
  business_coverage(
    location_id,
    locations(
      id,
      commune_id,
      name,
      slug
    )
  ),
  business_hours(
    day_of_week,
    open_time,
    close_time,
    is_closed
  ),
  business_media(
    media_type,
    storage_path,
    sort_order
  )
)
''';

  String? get _userId => _client?.auth.currentUser?.id;

  @override
  Future<Result<List<Business>>> listFavorites() async {
    final client = _client;
    final userId = _userId;

    if (client == null || userId == null) {
      return const Success([]);
    }

    try {
      final rows = await client
          .from('favorites')
          .select(_businessSelect)
          .eq('user_id', userId)
          .order(
            'created_at',
            ascending: false,
          );

      final businesses = <Business>[];

      for (final row in rows) {
        final business = row['businesses'];

        if (business is Map<String, dynamic>) {
          businesses.add(
            BusinessDto.fromJson(
              business,
            ).toDomain(),
          );
        }
      }

      return Success(businesses);
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos cargar tus guardados.',
        ),
      );
    }
  }

  @override
  Future<Result<bool>> isFavorite(
    String businessId,
  ) async {
    final client = _client;
    final userId = _userId;

    if (client == null || userId == null) {
      return const Success(false);
    }

    try {
      final rows = await client
          .from('favorites')
          .select('business_id')
          .eq('user_id', userId)
          .eq(
            'business_id',
            businessId,
          );

      return Success(
        rows.isNotEmpty,
      );
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos revisar el favorito.',
        ),
      );
    }
  }

  @override
  Future<Result<void>> addFavorite(
    String businessId,
  ) async {
    final client = _client;
    final userId = _userId;

    if (client == null || userId == null) {
      return const Failure(
        AppFailure(
          type: AppFailureType.auth,
          message: 'Debes ingresar para guardar negocios.',
        ),
      );
    }

    try {
      await client.from('favorites').upsert({
        'user_id': userId,
        'business_id': businessId,
      });

      return const Success(null);
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos guardar este negocio.',
        ),
      );
    }
  }

  @override
  Future<Result<void>> removeFavorite(
    String businessId,
  ) async {
    final client = _client;
    final userId = _userId;

    if (client == null || userId == null) {
      return const Failure(
        AppFailure(
          type: AppFailureType.auth,
          message: 'Debes ingresar para modificar favoritos.',
        ),
      );
    }

    try {
      await client.from('favorites').delete().eq('user_id', userId).eq(
            'business_id',
            businessId,
          );

      return const Success(null);
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos quitar este negocio.',
        ),
      );
    }
  }
}
