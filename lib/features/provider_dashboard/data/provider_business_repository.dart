import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/supabase_auth_repository.dart';

final providerBusinessRepositoryProvider =
    Provider<ProviderBusinessRepository>((ref) {
  return ProviderBusinessRepository(
    ref.watch(supabaseClientProvider),
  );
});

class ProviderBusinessSummary {
  const ProviderBusinessSummary({
    required this.id,
    required this.name,
    required this.businessType,
    required this.publicationStatus,
  });

  factory ProviderBusinessSummary.fromJson(
    Map<String, dynamic> json,
  ) {
    return ProviderBusinessSummary(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Mi negocio',
      businessType: json['business_type'] as String? ?? 'service',
      publicationStatus: json['publication_status'] as String? ?? 'draft',
    );
  }

  final String id;
  final String name;
  final String businessType;
  final String publicationStatus;

  bool get isLodging => businessType == 'lodging';
}

class ProviderBusinessRepository {
  const ProviderBusinessRepository(
    this._client,
  );

  final SupabaseClient? _client;

  Future<ProviderBusinessSummary?> getMyBusiness() async {
    final client = _client;
    final userId = client?.auth.currentUser?.id;

    if (client == null || userId == null) {
      return null;
    }

    final row = await client
        .from('businesses')
        .select(
          'id,name,business_type,publication_status,created_at',
        )
        .eq('owner_id', userId)
        .order(
          'created_at',
          ascending: false,
        )
        .limit(1)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return ProviderBusinessSummary.fromJson(
      Map<String, dynamic>.from(row),
    );
  }
}
