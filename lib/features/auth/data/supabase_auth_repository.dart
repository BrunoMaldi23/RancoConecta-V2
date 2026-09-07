import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
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
  Future<Result<AuthUser?>> signUp({
    required String fullName,
    required String email,
    required String password,
  });
  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  });
  Future<Result<void>> sendPasswordResetEmail(String email);
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
      return _mapUser(user);
    });
  }

  @override
  AuthUser? currentUser() {
    final user = _client?.auth.currentUser;
    if (user == null) {
      return null;
    }
    return _mapUser(user);
  }

  @override
  Future<Result<AuthUser?>> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      return const Failure(
        AppFailure(
          type: AppFailureType.auth,
          message: 'Configura Supabase para crear cuentas.',
        ),
      );
    }

    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim()},
      );
      final user = response.user;
      return Success(user == null ? null : _mapUser(user));
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos crear la cuenta.',
        ),
      );
    }
  }

  @override
  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      return const Failure(
        AppFailure(
          type: AppFailureType.auth,
          message: 'Configura Supabase para ingresar.',
        ),
      );
    }

    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        return const Failure(
          AppFailure(
            type: AppFailureType.auth,
            message: 'No pudimos iniciar sesión.',
          ),
        );
      }
      return Success(_mapUser(user));
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos iniciar sesión.',
        ),
      );
    }
  }

  @override
  Future<Result<void>> sendPasswordResetEmail(String email) async {
    final client = _client;
    if (client == null) {
      return const Failure(
        AppFailure(
          type: AppFailureType.auth,
          message: 'Configura Supabase para recuperar contraseña.',
        ),
      );
    }

    try {
      await client.auth.resetPasswordForEmail(email.trim());
      return const Success(null);
    } catch (error) {
      return Failure(
        mapSupabaseFailure(
          error,
          fallbackMessage: 'No pudimos enviar el email de recuperación.',
        ),
      );
    }
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

  AuthUser _mapUser(User user) {
    return AuthUser(
      id: user.id,
      email: user.email,
      emailConfirmed: user.emailConfirmedAt != null,
    );
  }
}
