import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/supabase_auth_repository.dart';

final businessAnalyticsRepositoryProvider =
    Provider<BusinessAnalyticsRepository>(
  (ref) => BusinessAnalyticsRepository(ref.watch(supabaseClientProvider)),
);

class BusinessAnalyticsRepository {
  const BusinessAnalyticsRepository(this._client);

  final SupabaseClient? _client;

  Future<void> track(String businessId, String eventType) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.rpc('record_business_analytics_event', params: {
        'p_business_id': businessId,
        'p_event_type': eventType,
      });
    } catch (_) {
      // Discovery and contact actions must remain usable if analytics fails.
    }
  }
}
