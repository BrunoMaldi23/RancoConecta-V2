import '../../../shared/models/service_request.dart';
import '../../../shared/models/service_request_status.dart';

class ServiceRequestDto {
  const ServiceRequestDto({
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

  factory ServiceRequestDto.fromJson(Map<String, dynamic> json) {
    final business = json['businesses'] as Map<String, dynamic>?;
    final category = json['categories'] as Map<String, dynamic>?;
    final subcategory = json['subcategories'] as Map<String, dynamic>?;
    final location = json['locations'] as Map<String, dynamic>?;
    return ServiceRequestDto(
      id: json['id'] as String,
      publicCode: json['public_code'] as String,
      businessId: json['business_id'] as String?,
      businessName: business?['name'] as String?,
      categoryId: json['category_id'] as String,
      categoryName: category?['name'] as String? ?? 'Categoría',
      subcategoryId: json['subcategory_id'] as String,
      subcategoryName: subcategory?['name'] as String? ?? 'Servicio',
      locationId: json['location_id'] as String?,
      locationName: location?['name'] as String?,
      description: json['description'] as String,
      addressText: json['address_text'] as String?,
      urgency: json['urgency'] as String? ?? 'normal',
      desiredDate: json['desired_date'] as String?,
      status: json['status'] as String? ?? 'submitted',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

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
  final String urgency;
  final String? desiredDate;
  final String status;
  final DateTime createdAt;

  ServiceRequest toDomain() {
    return ServiceRequest(
      id: id,
      publicCode: publicCode,
      businessId: businessId,
      businessName: businessName,
      categoryId: categoryId,
      categoryName: categoryName,
      subcategoryId: subcategoryId,
      subcategoryName: subcategoryName,
      locationId: locationId,
      locationName: locationName,
      description: description,
      addressText: addressText,
      urgency: RequestUrgency.values.firstWhere(
        (item) => item.name == urgency,
        orElse: () => RequestUrgency.normal,
      ),
      desiredDate: desiredDate == null ? null : DateTime.parse(desiredDate!),
      status: ServiceRequestStatus.parse(status),
      createdAt: createdAt,
    );
  }
}
