import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/debug/bootstrap_debug_logger.dart';
import '../../auth/application/auth_controller.dart';
import '../../../shared/models/profile.dart';
import '../data/profile_repository.dart';

final currentProfileProvider = FutureProvider<Profile>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) {
    throw const AppFailure(
      type: AppFailureType.auth,
      message: 'Debes ingresar para ver tu perfil.',
    );
  }
  final result =
      await ref.watch(profileRepositoryProvider).getCurrentProfile(user.id);
  return result.when(
    success: (profile) {
      logBootstrapEvent('AUTH_ROLE_RESOLVED', {'role': profile.role.name});
      return profile;
    },
    failure: (failure) => throw failure,
  );
});

String profileFailureMessage(Object error) {
  if (error is AppFailure) {
    return error.message;
  }
  return 'No pudimos cargar tu perfil.';
}
