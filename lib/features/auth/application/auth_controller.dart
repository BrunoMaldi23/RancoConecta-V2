import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_auth_repository.dart';
import '../domain/auth_user.dart';

final authStateProvider = StreamProvider<AuthUser?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.observeAuthState();
});

final signingOutProvider = StateProvider<bool>((ref) => false);

enum AuthPhase {
  initializing,
  authenticated,
  anonymous,
  unauthenticated,
  error
}

final authPhaseProvider = Provider<AuthPhase>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.hasError) return AuthPhase.error;
  if (!auth.hasValue) return AuthPhase.initializing;
  final user = auth.valueOrNull;
  if (user == null) return AuthPhase.unauthenticated;
  return user.isAnonymous ? AuthPhase.anonymous : AuthPhase.authenticated;
});
