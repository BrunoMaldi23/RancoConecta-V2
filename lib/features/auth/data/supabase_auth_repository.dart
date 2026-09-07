import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/result/result.dart';
import '../domain/auth_user.dart';

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.hasSupabaseConfig) {
    return null;
  }
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

abstract interface class AuthRepository {
  Stream<AuthUser?> observeAuthState();
  AuthUser? currentUser();
  Future<Result<void>> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final SupabaseClient? _client;

  @override
  Stream<AuthUser?> observeAuthState() {
    final client = _client;
    if (client == null) {
      return Stream<AuthUser?>.value(null);
    }

    return client.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      if (user == null) {
        return null;
      }
      return AuthUser(id: user.id, email: user.email);
    });
  }

  @override
  AuthUser? currentUser() {
    final user = _client?.auth.currentUser;
    if (user == null) {
      return null;
    }
    return AuthUser(id: user.id, email: user.email);
  }

  @override
  Future<Result<void>> signOut() async {
    final client = _client;
    if (client == null) {
      return const Failure(
        AppFailure(
          type: AppFailureType.auth,
          message: 'El backend no está configurado.',
        ),
      );
    }

    try {
      await client.auth.signOut();
      return const Success(null);
    } on AuthException catch (error) {
      return Failure(
        AppFailure(
          type: AppFailureType.auth,
          message: 'No se pudo cerrar sesión.',
          cause: error,
        ),
      );
    } catch (error) {
      return Failure(
        AppFailure(
          type: AppFailureType.unknown,
          message: 'Ocurrió un error inesperado.',
          cause: error,
        ),
      );
    }
  }
}
