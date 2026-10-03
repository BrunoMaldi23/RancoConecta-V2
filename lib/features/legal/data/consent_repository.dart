import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/supabase_auth_repository.dart';
import '../presentation/consent_fields.dart';

final consentRepositoryProvider = Provider<ConsentRepository>((ref) {
  return ConsentRepository(ref.watch(supabaseClientProvider));
});

class ConsentRepository {
  const ConsentRepository(this._client);

  final SupabaseClient? _client;

  Future<void> record({required String context}) async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      throw StateError('No hay una sesión para guardar el consentimiento.');
    }
    await client.from('user_consents').insert({
      'user_id': user.id,
      'terms_version': termsVersion,
      'privacy_version': privacyVersion,
      'data_processing_authorized': true,
      'consent_context': context,
    });
  }
}
