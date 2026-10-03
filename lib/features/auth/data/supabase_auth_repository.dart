import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../config/app_config.dart';
import '../../../core/debug/bootstrap_debug_logger.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_mapper.dart';
import '../../../core/result/result.dart';
import '../domain/auth_user.dart';
import '../../legal/presentation/consent_fields.dart';

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
    bool consentAccepted = false,
  });
  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  });
  Future<Result<AuthUser>> signInAnonymously();
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

    logBootstrapEvent('AUTH_BOOTSTRAP_START');
    // Supabase emits INITIAL_SESSION after restoring local storage. A snapshot
    // of currentSession before that event can incorrectly look signed out.
    return client.auth.onAuthStateChange.map((event) {
      if (event.event == AuthChangeEvent.initialSession) {
        logBootstrapEvent('AUTH_INITIAL_SESSION_RESOLVED');
      }
      final user = event.session?.user;
      if (user != null) logBootstrapEvent('AUTH_SESSION_FOUND');
      return user == null ? null : _mapUser(user);
    }).distinct(
      (previous, next) =>
          previous?.id == next?.id &&
          previous?.isAnonymous == next?.isAnonymous &&
          previous?.email == next?.email &&
          previous?.emailConfirmed == next?.emailConfirmed,
    );
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
    bool consentAccepted = false,
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
        data: {
          'full_name': fullName.trim(),
          if (consentAccepted) ...{
            'consent_terms_version': termsVersion,
            'consent_privacy_version': privacyVersion,
            'consent_data_processing': true,
          },
        },
        emailRedirectTo: _webRedirect('/'),
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
  Future<Result<AuthUser>> signInAnonymously() async {
    final client = _client;
    if (client == null) {
      return const Failure(AppFailure(
        type: AppFailureType.auth,
        message: 'Configura Supabase para continuar como visitante.',
      ));
    }
    try {
      final response = await client.auth.signInAnonymously();
      final user = response.user;
      if (user == null) {
        return const Failure(AppFailure(
          type: AppFailureType.auth,
          message: 'No pudimos iniciar la sesión visitante.',
        ));
      }
      return Success(_mapUser(user));
    } catch (error) {
      return Failure(mapSupabaseFailure(error,
          fallbackMessage: 'No pudimos iniciar la sesión visitante.'));
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
      await client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: _webRedirect('/?recovery=1'),
      );
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
      isAnonymous: user.isAnonymous,
    );
  }
}

String? _webRedirect(String path) {
  if (!kIsWeb) return null;
  const environment = String.fromEnvironment('APP_ENVIRONMENT');
  const productionSite = String.fromEnvironment(
    'PUBLIC_SITE_URL',
    defaultValue: 'https://www.rancoconecta.cl',
  );
  final base =
      environment == 'production' ? Uri.parse(productionSite) : Uri.base;
  if (base.scheme != 'https' && base.scheme != 'http') return null;
  if (environment == 'production' &&
      (base.scheme != 'https' ||
          base.host.isEmpty ||
          base.host == 'localhost' ||
          base.host == '127.0.0.1')) {
    return null;
  }
  final target = Uri.parse(path);
  return base
      .replace(
        path: target.path,
        query: target.hasQuery ? target.query : null,
        fragment: null,
      )
      .toString();
}
