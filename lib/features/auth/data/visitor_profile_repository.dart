import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/result/result.dart';
import 'supabase_auth_repository.dart';

final visitorProfileRepositoryProvider =
    Provider<VisitorProfileRepository>((ref) {
  return VisitorProfileRepository(ref.watch(supabaseClientProvider));
});

class VisitorProfileRepository {
  const VisitorProfileRepository(this._client);

  final SupabaseClient? _client;

  Future<Result<void>> save({
    required String fullName,
    required String phone,
    String? email,
    String? locationId,
  }) async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null || !user.isAnonymous) {
      return const Failure(AppFailure(
        type: AppFailureType.auth,
        message: 'Inicia una sesión visitante para guardar tus datos.',
      ));
    }

    try {
      await client
          .from('profiles')
          .update({'full_name': fullName.trim(), 'phone': phone.trim()})
          .eq('id', user.id)
          .select('id')
          .single();
      await client.auth.updateUser(UserAttributes(data: {
        'visitor_email': email?.trim() ?? '',
        'visitor_location_id': locationId ?? '',
      }));
      return const Success(null);
    } catch (error) {
      return Failure(mapSupabaseFailure(error,
          fallbackMessage: 'No pudimos guardar los datos del visitante.'));
    }
  }
}
