enum QuoteStatus {
  pending,
  accepted,
  rejected,
  expired,
  cancelled;

  String get value => name;

  String get label {
    return switch (this) {
      QuoteStatus.pending => 'Pendiente',
      QuoteStatus.accepted => 'Aceptada',
      QuoteStatus.rejected => 'Rechazada',
      QuoteStatus.expired => 'Expirada',
      QuoteStatus.cancelled => 'Cancelada',
    };
  }

  bool get canRespond => this == QuoteStatus.pending;

  static QuoteStatus parse(String? value) {
    return switch (value) {
      'accepted' => QuoteStatus.accepted,
      'rejected' => QuoteStatus.rejected,
      'expired' => QuoteStatus.expired,
      'cancelled' => QuoteStatus.cancelled,
      _ => QuoteStatus.pending,
    };
  }
}

class Quote {
  const Quote({
    required this.id,
    required this.requestId,
    required this.businessId,
    required this.businessName,
    required this.totalAmount,
    required this.description,
    required this.expiresAt,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String requestId;
  final String businessId;
  final String businessName;
  final int totalAmount;
  final String? description;
  final DateTime? expiresAt;
  final QuoteStatus status;
  final DateTime createdAt;

  String get formattedTotal {
    return '\$${totalAmount.toString().replaceAllMapped(
          RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => '.',
        )}';
  }
}

class ProviderRequestItem {
  const ProviderRequestItem({
    required this.requestId,
    required this.publicCode,
    required this.businessId,
    required this.subcategoryId,
    required this.subcategoryName,
    required this.locationId,
    required this.locationName,
    required this.description,
    required this.addressText,
    required this.urgency,
    required this.desiredDate,
    required this.requestStatus,
    required this.attachmentCount,
    required this.quoteId,
    required this.quoteStatus,
    required this.quoteTotal,
    required this.operationId,
    required this.operationStatus,
    required this.createdAt,
  });

  final String requestId;
  final String publicCode;
  final String businessId;
  final String subcategoryId;
  final String subcategoryName;
  final String? locationId;
  final String? locationName;
  final String description;
  final String? addressText;
  final String urgency;
  final DateTime? desiredDate;
  final String requestStatus;
  final int attachmentCount;
  final String? quoteId;
  final QuoteStatus? quoteStatus;
  final int? quoteTotal;
  final String? operationId;
  final String? operationStatus;
  final DateTime createdAt;

  String get stateLabel {
    if (operationStatus != null) {
      return switch (operationStatus) {
        'accepted' => 'Aceptada',
        'in_progress' => 'En curso',
        'completed' => 'Finalizada',
        _ => 'Operación',
      };
    }

    if (quoteStatus != null) {
      return quoteStatus!.label;
    }

    return switch (requestStatus) {
      'quoted' => 'Cotizada',
      'accepted' => 'Aceptada',
      'in_progress' => 'En curso',
      'completed' => 'Finalizada',
      _ => 'Nueva',
    };
  }
}
