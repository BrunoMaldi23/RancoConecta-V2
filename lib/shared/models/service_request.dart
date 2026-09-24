import 'service_request_status.dart';

enum RequestUrgency {
  low,
  normal,
  high,
  urgent;

  String get label {
    return switch (this) {
      RequestUrgency.low => 'Baja',
      RequestUrgency.normal => 'Normal',
      RequestUrgency.high => 'Alta',
      RequestUrgency.urgent => 'Urgente',
    };
  }
}

class ServiceRequest {
  const ServiceRequest({
    required this.id,
    required this.publicCode,
    required this.businessId,
    required this.businessName,
    required this.categoryId,
    required this.categoryName,
    required this.subcategoryId,
    required this.subcategoryName,
    required this.locationId,
    required this.locationName,
    required this.description,
    required this.addressText,
    required this.urgency,
    required this.desiredDate,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String publicCode;
  final String? businessId;
  final String? businessName;
  final String categoryId;
  final String categoryName;
  final String subcategoryId;
  final String subcategoryName;
  final String? locationId;
  final String? locationName;
  final String description;
  final String? addressText;
  final RequestUrgency urgency;
  final DateTime? desiredDate;
  final ServiceRequestStatus status;
  final DateTime createdAt;
}
