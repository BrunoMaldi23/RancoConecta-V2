import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/result/result.dart';
import '../../../features/auth/data/supabase_auth_repository.dart';
import '../../../shared/models/profile.dart';
import 'profile_dto.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return SupabaseProfileRepository(ref.watch(supabaseClientProvider));
});

abstract interface class ProfileRepository {
  Future<Result<Profile>> getCurrentProfile();
  Future<Result<Profile>> updateCurrentProfile({
    required String fullName,
    required String? phone,
  });
}

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository(this._client);

  final SupabaseClient? _client;

  @override
  Future<Result<Profile>> getCurrentProfile() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      return const Failure(
        AppFailure(
            type: AppFailureType.auth,
            message: 'Debes ingresar para ver tu perfil.'),
      );
    }
    try {
      final row =
          await client.from('profiles').select().eq('id', user.id).single();
      return Success(ProfileDto.fromJson(row).toDomain());
    } catch (error) {
      return Failure(mapSupabaseFailure(error,
          fallbackMessage: 'No pudimos cargar tu perfil.'));
    }
  }

  @override
  Future<Result<Profile>> updateCurrentProfile({
    required String fullName,
    required String? phone,
  }) async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      return const Failure(
        AppFailure(
            type: AppFailureType.auth,
            message: 'Debes ingresar para editar tu perfil.'),
      );
    }
    try {
      final row = await client
          .from('profiles')
          .update({'full_name': fullName.trim(), 'phone': phone?.trim()})
          .eq('id', user.id)
          .select()
          .single();
      return Success(ProfileDto.fromJson(row).toDomain());
    } catch (error) {
      return Failure(mapSupabaseFailure(error,
          fallbackMessage: 'No pudimos guardar tu perfil.'));
    }
  }
}
