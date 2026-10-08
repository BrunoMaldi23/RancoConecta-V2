import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/business_onboarding_repository.dart';

/// Borrador completo de un negocio (lectura existente del repositorio), para
/// mostrar el progreso de configuración en el hub "Mi negocio".
final providerBusinessDraftProvider =
    FutureProvider.autoDispose.family<BusinessDraft, String>(
  (ref, businessId) async {
    final result = await ref
        .watch(businessOnboardingRepositoryProvider)
        .getBusinessDraft(businessId);
    return result.when(
      success: (draft) => draft,
      failure: (failure) => throw failure,
    );
  },
);
