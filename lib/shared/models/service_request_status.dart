enum ServiceRequestStatus {
  draft,
  submitted,
  viewed,
  quoted,
  accepted,
  scheduled,
  inProgress,
  completed,
  confirmed,
  reviewed,
  rejected,
  cancelled,
  expired,
  disputed;

  bool get canReceiveQuote {
    return switch (this) {
      ServiceRequestStatus.submitted || ServiceRequestStatus.viewed => true,
      _ => false,
    };
  }
}
