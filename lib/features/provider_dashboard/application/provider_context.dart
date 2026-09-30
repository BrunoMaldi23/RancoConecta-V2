import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/debug/bootstrap_debug_logger.dart';
import '../../auth/application/auth_controller.dart';
import 'provider_dashboard_providers.dart';
import 'provider_context_state.dart';

final providerContextProvider =
    FutureProvider<ProviderContextState>((ref) async {
  logBootstrapEvent('PROVIDER_CONTEXT_START');

  final auth = ref.watch(authStateProvider);
  if (auth.hasError) {
    throw auth.error!;
  }

  if (auth.isLoading && !auth.hasValue) {
    return const ProviderContextState(
      status: ProviderContextStatus.loading,
    );
  }

  if (auth.valueOrNull == null) {
    return const ProviderContextState(
      status: ProviderContextStatus.unauthenticated,
    );
  }

  final businesses = await ref.watch(myProviderBusinessesProvider.future);
  logBootstrapEvent(
    'MANAGEABLE_BUSINESSES_COUNT',
    {'count': businesses.length},
  );

  if (businesses.isEmpty) {
    return const ProviderContextState(
      status: ProviderContextStatus.noBusiness,
    );
  }

  final activeId = ref.watch(activeProviderBusinessIdProvider);
  final activeBusiness = selectActiveProviderBusiness(
    businesses: businesses,
    activeBusinessId: activeId,
  );

  if (activeBusiness == null) {
    return const ProviderContextState(
      status: ProviderContextStatus.noBusiness,
    );
  }

  if (activeId != null && activeBusiness.id != activeId) {
    Future.microtask(() {
      ref.read(activeProviderBusinessIdProvider.notifier).state = null;
    });
    logBootstrapEvent(
      'ACTIVE_BUSINESS_RESET',
      {'businessId': activeId},
    );
  } else {
    logBootstrapEvent(
      'ACTIVE_BUSINESS_VALIDATED',
      {'businessId': activeBusiness.id},
    );
  }

  return ProviderContextState(
    status: providerContextStatusForPublication(
      activeBusiness.publicationStatus,
    ),
    business: activeBusiness,
  );
});
