import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/result/result.dart';
import '../../../features/auth/data/supabase_auth_repository.dart';
import '../../../shared/models/business.dart';
import 'business_dto.dart';

final businessRepositoryProvider = Provider<BusinessRepository>((ref) {
  return SupabaseBusinessRepository(
    ref.watch(supabaseClientProvider),
  );
});

class BusinessQuery {
  const BusinessQuery({
    this.categoryId,
    this.subcategoryId,
    this.locationId,
    this.searchQuery,
    this.verifiedOnly = false,
    this.featuredOnly = false,
    this.limit = 50,
  });

  final String? categoryId;
  final String? subcategoryId;
  final String? locationId;
  final String? searchQuery;

  final bool verifiedOnly;
  final bool featuredOnly;

  final int limit;
}

abstract interface class BusinessRepository {
  Future<Result<List<Business>>> listPublishedBusinesses(
    BusinessQuery query,
  );

  Future<Result<Business>> getBusinessById(
    String id,
  );
}

class SupabaseBusinessRepository implements BusinessRepository {
  const SupabaseBusinessRepository(this._client);

  final SupabaseClient? _client;

  static const _select = '''
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
''';

  @override
  Future<Result<List<Business>>> listPublishedBusinesses(
    BusinessQuery query,
  ) async {
    final client = _client;

    if (client == null) {
      return const Success([]);
    }

    try {
      var request = client
          .from('businesses')
          .select(_select)
          .eq('publication_status', 'published');

      if (query.verifiedOnly) {
        request = request.eq(
          'verification_status',
          'verified',
        );
      }

      if (query.featuredOnly) {
        request = request.eq(
          'is_featured',
          true,
        );
      }

      final search = query.searchQuery?.trim();

      if (search != null && search.isNotEmpty) {
        request = request.or(
          'name.ilike.%$search%,description.ilike.%$search%',
        );
      }

      final rows = await request
          .order(
            'created_at',
            ascending: false,
          )
          .limit(query.limit);

      var businesses = rows
          .map(
            (row) => BusinessDto.fromJson(row).toDomain(),
          )
          .toList();

      if (query.subcategoryId != null) {
        businesses = businesses
            .where(
              (business) => business.services.any(
                (service) => service.subcategory.id == query.subcategoryId,
              ),
            )
            .toList();
      }

      if (query.categoryId != null) {
        businesses = businesses
            .where(
              (business) => business.services.any(
                (service) => service.subcategory.categoryId == query.categoryId,
              ),
            )
            .toList();
      }

      if (query.locationId != null) {
        businesses = businesses
            .where(
              (business) => business.coverage.any(
                (location) => location.id == query.locationId,
              ),
            )
            .toList();
      }

      return Success(businesses);
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos cargar los negocios publicados.',
        ),
      );
    }
  }

  @override
  Future<Result<Business>> getBusinessById(
    String id,
  ) async {
    final client = _client;

    if (client == null) {
      return const Failure(
        AppFailure(
          type: AppFailureType.offline,
          message: 'Supabase no está configurado.',
        ),
      );
    }

    try {
      final row =
          await client.from('businesses').select(_select).eq('id', id).single();

      return Success(
        BusinessDto.fromJson(row).toDomain(),
      );
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos cargar el negocio.',
        ),
      );
    }
  }
}
