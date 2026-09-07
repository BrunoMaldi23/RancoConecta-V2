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

  String get label {
    return switch (this) {
      ServiceRequestStatus.draft => 'Borrador',
      ServiceRequestStatus.submitted => 'Enviada',
      ServiceRequestStatus.viewed => 'Vista',
      ServiceRequestStatus.quoted => 'Cotizada',
      ServiceRequestStatus.accepted => 'Aceptada',
      ServiceRequestStatus.scheduled => 'Agendada',
      ServiceRequestStatus.inProgress => 'En progreso',
      ServiceRequestStatus.completed => 'Completada',
      ServiceRequestStatus.confirmed => 'Confirmada',
      ServiceRequestStatus.reviewed => 'Evaluada',
      ServiceRequestStatus.rejected => 'Rechazada',
      ServiceRequestStatus.cancelled => 'Cancelada',
      ServiceRequestStatus.expired => 'Expirada',
      ServiceRequestStatus.disputed => 'En disputa',
    };
  }

  bool canTransitionTo(ServiceRequestStatus next) {
    return switch (this) {
      ServiceRequestStatus.draft => next == ServiceRequestStatus.submitted ||
          next == ServiceRequestStatus.cancelled,
      ServiceRequestStatus.submitted => next == ServiceRequestStatus.viewed ||
          next == ServiceRequestStatus.cancelled ||
          next == ServiceRequestStatus.expired,
      ServiceRequestStatus.viewed => next == ServiceRequestStatus.quoted ||
          next == ServiceRequestStatus.rejected ||
          next == ServiceRequestStatus.cancelled,
      ServiceRequestStatus.quoted => next == ServiceRequestStatus.accepted ||
          next == ServiceRequestStatus.rejected ||
          next == ServiceRequestStatus.expired,
      ServiceRequestStatus.accepted => next == ServiceRequestStatus.scheduled ||
          next == ServiceRequestStatus.cancelled,
      ServiceRequestStatus.scheduled =>
        next == ServiceRequestStatus.inProgress ||
            next == ServiceRequestStatus.cancelled,
      ServiceRequestStatus.inProgress =>
        next == ServiceRequestStatus.completed ||
            next == ServiceRequestStatus.disputed,
      ServiceRequestStatus.completed =>
        next == ServiceRequestStatus.confirmed ||
            next == ServiceRequestStatus.disputed,
      ServiceRequestStatus.confirmed => next == ServiceRequestStatus.reviewed,
      _ => false,
    };
  }

  static ServiceRequestStatus parse(String value) {
    return switch (value) {
      'in_progress' => ServiceRequestStatus.inProgress,
      _ => ServiceRequestStatus.values.firstWhere(
          (status) => status.name == value,
          orElse: () => ServiceRequestStatus.submitted,
        ),
    };
  }
}
