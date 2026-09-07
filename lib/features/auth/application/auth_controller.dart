import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supabase_auth_repository.dart';
import '../domain/auth_user.dart';

final authStateProvider = StreamProvider<AuthUser?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.observeAuthState();
});
