enum OperationType {
  service,
  booking,
  quote,
  order;

  String get value => name;

  static OperationType parse(String value) {
    return OperationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => OperationType.service,
    );
  }
}

enum OperationStatus {
  draft,
  submitted,
  pending,
  reviewing,
  accepted,
  scheduled,
  inProgress,
  completed,
  confirmed,
  closed,
  cancelled,
  rejected,
  expired,
  disputed;

  String get value {
    return switch (this) {
      OperationStatus.inProgress => 'in_progress',
      _ => name,
    };
  }

  static OperationStatus parse(String value) {
    return switch (value) {
      'submitted' => OperationStatus.submitted,
      'pending' => OperationStatus.pending,
      'reviewing' => OperationStatus.reviewing,
      'accepted' => OperationStatus.accepted,
      'scheduled' => OperationStatus.scheduled,
      'in_progress' => OperationStatus.inProgress,
      'completed' => OperationStatus.completed,
      'confirmed' => OperationStatus.confirmed,
      'closed' => OperationStatus.closed,
      'cancelled' => OperationStatus.cancelled,
      'rejected' => OperationStatus.rejected,
      'expired' => OperationStatus.expired,
      'disputed' => OperationStatus.disputed,
      _ => OperationStatus.draft,
    };
  }
}

enum OperationPaymentStatus {
  notRequired,
  pending,
  processing,
  authorized,
  paid,
  failed,
  cancelled,
  refunded,
  disputed;

  String get value {
    return switch (this) {
      OperationPaymentStatus.notRequired => 'not_required',
      _ => name,
    };
  }

  static OperationPaymentStatus parse(String value) {
    return switch (value) {
      'pending' => OperationPaymentStatus.pending,
      'processing' => OperationPaymentStatus.processing,
      'authorized' => OperationPaymentStatus.authorized,
      'paid' => OperationPaymentStatus.paid,
      'failed' => OperationPaymentStatus.failed,
      'cancelled' => OperationPaymentStatus.cancelled,
      'refunded' => OperationPaymentStatus.refunded,
      'disputed' => OperationPaymentStatus.disputed,
      _ => OperationPaymentStatus.notRequired,
    };
  }
}

class Operation {
  const Operation({
    required this.id,
    required this.type,
    required this.customerId,
    required this.businessId,
    required this.status,
    required this.currency,
    required this.subtotal,
    required this.platformFee,
    required this.discount,
    required this.total,
    required this.paymentStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final OperationType type;
  final String customerId;
  final String? businessId;
  final OperationStatus status;
  final String currency;
  final int subtotal;
  final int platformFee;
  final int discount;
  final int total;
  final OperationPaymentStatus paymentStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class OperationEvent {
  const OperationEvent({
    required this.id,
    required this.operationId,
    required this.eventType,
    required this.actorId,
    required this.previousStatus,
    required this.newStatus,
    required this.metadata,
    required this.createdAt,
  });

  final String id;
  final String operationId;
  final String eventType;
  final String? actorId;
  final OperationStatus? previousStatus;
  final OperationStatus? newStatus;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
}
