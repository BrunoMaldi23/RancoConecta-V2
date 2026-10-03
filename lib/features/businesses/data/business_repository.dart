import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/logging/app_logger.dart';
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
    this.offset = 0,
  });

  final String? categoryId;
  final String? subcategoryId;
  final String? locationId;
  final String? searchQuery;

  final bool verifiedOnly;
  final bool featuredOnly;

  final int limit;
  final int offset;
}

class BusinessPage {
  const BusinessPage(
      {required this.items, required this.nextOffset, required this.hasMore});

  final List<Business> items;
  final int nextOffset;
  final bool hasMore;
}

abstract interface class BusinessRepository {
  Future<Result<List<Business>>> listPublishedBusinesses(
    BusinessQuery query,
  );

  Future<Result<BusinessPage>> listPublishedBusinessesPage(BusinessQuery query);

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
address_text,
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
    final result = await listPublishedBusinessesPage(query);
    return result.when(
      success: (page) => Success(page.items),
      failure: (failure) => Failure(failure),
    );
  }

  @override
  Future<Result<BusinessPage>> listPublishedBusinessesPage(
    BusinessQuery query,
  ) async {
    final client = _client;

    if (client == null) {
      return const Success(
          BusinessPage(items: [], nextOffset: 0, hasMore: false));
    }

    try {
      // Coverage uses a separate alias so the card still receives all its
      // locations. Category uses the existing primary category association,
      // which also covers verticals without business_services rows.
      final filterJoins = [
        if (query.locationId != null)
          'location_match:business_coverage!inner(location_id)',
      ];
      final select =
          filterJoins.isEmpty ? _select : '$_select,${filterJoins.join(',')}';
      var request = client
          .from('businesses')
          .select(select)
          .eq('publication_status', 'published');

      if (query.categoryId != null) {
        request = request.eq(
          'primary_category_id',
          query.categoryId!,
        );
      }

      if (query.locationId != null) {
        request = request.eq(
          'location_match.location_id',
          query.locationId!,
        );
      }

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
          .order('id', ascending: false)
          .range(query.offset, query.offset + query.limit);

      final pageRows = rows.take(query.limit).toList();

      var businesses = pageRows
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

      return Success(BusinessPage(
        items: businesses,
        nextOffset: query.offset + pageRows.length,
        hasMore: rows.length > query.limit,
      ));
    } catch (error) {
      AppLogger.dataQueryFailure(
        feature: 'businesses',
        endpoint: 'businesses:listPublishedBusinesses',
        error: error,
      );
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
      final row = await client
          .from('businesses')
          .select(_select)
          .eq('id', id)
          .eq('publication_status', 'published')
          .single();

      return Success(
        BusinessDto.fromJson(row).toDomain(),
      );
    } catch (error) {
      AppLogger.dataQueryFailure(
        feature: 'businesses',
        endpoint: 'businesses:getBusinessById',
        error: error,
      );
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos cargar el negocio.',
        ),
      );
    }
  }
}
