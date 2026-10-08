import '../../../shared/models/service_request.dart';
import '../../../shared/models/service_request_status.dart';

enum CustomerActivityType { service, lodging, gastronomy, tourism }

enum CustomerActivityStage {
  pending,
  accepted,
  rejected,
  finished,
  cancelled,
  other
}

class CustomerActivityItem {
  const CustomerActivityItem({
    required this.id,
    required this.businessId,
    required this.businessName,
    required this.type,
    required this.createdAt,
    required this.stage,
    required this.statusLabel,
    required this.summary,
    required this.detailRoute,
    this.description,
    this.publicCode,
    this.isQuoted = false,
    this.details = const {},
  });

  final String id;
  final String? businessId;
  final String businessName;
  final CustomerActivityType type;
  final DateTime createdAt;
  final CustomerActivityStage stage;
  final String statusLabel;
  final String summary;
  final String detailRoute;
  final String? description;
  final String? publicCode;
  final bool isQuoted;
  final Map<String, String> details;

  factory CustomerActivityItem.fromService(ServiceRequest request) =>
      CustomerActivityItem(
        id: request.id,
        businessId: request.businessId,
        businessName: request.businessName ?? 'Solicitud abierta',
        type: CustomerActivityType.service,
        createdAt: request.createdAt,
        stage: serviceStage(request.status),
        statusLabel: request.status.label,
        summary: request.subcategoryName,
        detailRoute: '/requests/${request.id}',
        description: request.description,
        publicCode: request.publicCode,
        isQuoted: request.status == ServiceRequestStatus.quoted,
      );

  static CustomerActivityStage serviceStage(ServiceRequestStatus status) =>
      switch (status) {
        ServiceRequestStatus.submitted ||
        ServiceRequestStatus.viewed ||
        ServiceRequestStatus.draft =>
          CustomerActivityStage.pending,
        ServiceRequestStatus.accepted ||
        ServiceRequestStatus.scheduled ||
        ServiceRequestStatus.inProgress =>
          CustomerActivityStage.accepted,
        ServiceRequestStatus.completed ||
        ServiceRequestStatus.confirmed ||
        ServiceRequestStatus.reviewed =>
          CustomerActivityStage.finished,
        ServiceRequestStatus.rejected ||
        ServiceRequestStatus.expired =>
          CustomerActivityStage.rejected,
        ServiceRequestStatus.cancelled => CustomerActivityStage.cancelled,
        ServiceRequestStatus.quoted ||
        ServiceRequestStatus.disputed =>
          CustomerActivityStage.other,
      };

  static CustomerActivityStage lodgingStage(String status) => switch (status) {
        'pending' => CustomerActivityStage.pending,
        'accepted' => CustomerActivityStage.accepted,
        'rejected' => CustomerActivityStage.rejected,
        'cancelled' => CustomerActivityStage.cancelled,
        _ => CustomerActivityStage.other,
      };

  static CustomerActivityStage gastronomyStage(String status) =>
      switch (status) {
        'pending' => CustomerActivityStage.pending,
        'confirmed' => CustomerActivityStage.accepted,
        'rejected' => CustomerActivityStage.rejected,
        'cancelled' => CustomerActivityStage.cancelled,
        _ => CustomerActivityStage.other,
      };
}
