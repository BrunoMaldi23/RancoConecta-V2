import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure_mapper.dart';
import '../../../core/result/result.dart';
import '../../../features/auth/data/supabase_auth_repository.dart';
import '../../../shared/models/location.dart';
import 'location_dto.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return SupabaseLocationRepository(
    ref.watch(supabaseClientProvider),
  );
});

abstract interface class LocationRepository {
  Future<Result<List<Location>>> listActiveLocations();
}

class SupabaseLocationRepository implements LocationRepository {
  const SupabaseLocationRepository(this._client);

  final SupabaseClient? _client;

  @override
  Future<Result<List<Location>>> listActiveLocations() async {
    final client = _client;

    if (client == null) {
      return const Success([]);
    }

    try {
      final rows = await client
          .from('locations')
          .select('''
id,
commune_id,
name,
slug,
sort_order,
communes(name),
business_coverage(
  business_id,
  businesses(publication_status)
)
''')
          .eq('active', true)
          .order('sort_order', ascending: true);

      final locations = rows.map<Location>((row) {
        final base =
            LocationDto.fromJson(row).toDomain();

        final commune = row['communes'];

        final communeName =
            commune is Map<String, dynamic>
                ? commune['name'] as String?
                : commune is Map
                    ? commune['name']?.toString()
                    : null;

        final coverageRows =
            (row['business_coverage'] as List?)
                    ?.cast<dynamic>() ??
                const [];

        var providerCount = 0;

        for (final coverage in coverageRows) {
          if (coverage is! Map) {
            continue;
          }

          final business = coverage['businesses'];

          if (business is Map &&
              business['publication_status'] == 'published') {
            providerCount++;
          }
        }

        return base.copyWith(
          communeName: communeName,
          providerCount: providerCount,
        );
      }).toList();

      return Success(locations);
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage:
              'No pudimos cargar las localidades.',
        ),
      );
    }
  }
}