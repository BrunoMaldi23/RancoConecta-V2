import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/models/profile.dart';
import '../data/profile_repository.dart';

final currentProfileProvider = FutureProvider<Profile>((ref) async {
  final result = await ref.watch(profileRepositoryProvider).getCurrentProfile();
  return result.when(
    success: (profile) => profile,
    failure: (failure) => throw failure,
  );
});

String profileFailureMessage(Object error) {
  if (error is AppFailure) {
    return error.message;
  }
  return 'No pudimos cargar tu perfil.';
}
