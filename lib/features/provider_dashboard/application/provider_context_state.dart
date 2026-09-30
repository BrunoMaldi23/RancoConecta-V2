import '../data/provider_business_repository.dart';

enum ProviderContextStatus {
  loading,
  unauthenticated,
  noBusiness,
  hasDraft,
  pendingReview,
  changesRequested,
  published,
  suspended,
  rejected,
  error,
}

class ProviderContextState {
  const ProviderContextState({
    required this.status,
    this.business,
  });

  final ProviderContextStatus status;
  final ProviderBusinessSummary? business;

  bool get canUseManagement =>
      status == ProviderContextStatus.published && business != null;
}

ProviderBusinessSummary? selectActiveProviderBusiness({
  required List<ProviderBusinessSummary> businesses,
  required String? activeBusinessId,
}) {
  if (businesses.isEmpty) {
    return null;
  }

  if (activeBusinessId == null) {
    return businesses.first;
  }

  for (final business in businesses) {
    if (business.id == activeBusinessId) {
      return business;
    }
  }

  return businesses.first;
}

ProviderContextStatus providerContextStatusForPublication(String status) {
  return switch (status) {
    'published' => ProviderContextStatus.published,
    'pending_review' => ProviderContextStatus.pendingReview,
    'changes_requested' => ProviderContextStatus.changesRequested,
    'suspended' => ProviderContextStatus.suspended,
    'rejected' => ProviderContextStatus.rejected,
    _ => ProviderContextStatus.hasDraft,
  };
}
