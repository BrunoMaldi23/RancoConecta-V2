import '../../../shared/models/business.dart';
import '../../../shared/models/category.dart';
import '../../../shared/models/location.dart';

class BusinessDto {
  const BusinessDto({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.name,
    required this.slug,
    required this.description,
    required this.phone,
    required this.whatsapp,
    required this.email,
    required this.website,
    required this.verificationStatus,
    required this.isFeatured,
    required this.acceptsRequests,
    required this.ratingAvg,
    required this.reviewCount,
    required this.services,
    required this.coverage,
    required this.hours,
    required this.media,
  });

  factory BusinessDto.fromJson(Map<String, dynamic> json) {
    final ratingValue = json['rating_avg'];

    return BusinessDto(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      type: json['business_type'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      phone: json['phone'] as String?,
      whatsapp: json['whatsapp'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      verificationStatus:
          json['verification_status'] as String? ?? 'unverified',
      isFeatured: json['is_featured'] as bool? ?? false,
      acceptsRequests: json['accepts_requests'] as bool? ?? true,
      ratingAvg: ratingValue is num ? ratingValue.toDouble() : 0,
      reviewCount: json['review_count'] as int? ?? 0,
      services: _list(json['business_services'])
          .map(BusinessServiceDto.fromJson)
          .toList(),
      coverage: _list(json['business_coverage'])
          .map(BusinessCoverageDto.fromJson)
          .toList(),
      hours:
          _list(json['business_hours']).map(BusinessHourDto.fromJson).toList(),
      media:
          _list(json['business_media']).map(BusinessMediaDto.fromJson).toList(),
    );
  }

  final String id;
  final String ownerId;
  final String type;

  final String name;
  final String slug;

  final String? description;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? website;

  final String verificationStatus;

  final bool isFeatured;
  final bool acceptsRequests;

  final double ratingAvg;
  final int reviewCount;

  final List<BusinessServiceDto> services;
  final List<BusinessCoverageDto> coverage;
  final List<BusinessHourDto> hours;
  final List<BusinessMediaDto> media;

  Business toDomain() {
    return Business(
      id: id,
      ownerId: ownerId,
      type: BusinessType.parse(type),
      name: name,
      slug: slug,
      description: description,
      phone: phone,
      whatsapp: whatsapp,
      email: email,
      website: website,
      verificationStatus: verificationStatus,
      isFeatured: isFeatured,
      acceptsRequests: acceptsRequests,
      ratingAvg: ratingAvg,
      reviewCount: reviewCount,
      services: services.map((service) => service.toDomain()).toList(),
      coverage: coverage.map((item) => item.location).toList(),
      hours: hours.map((hour) => hour.toDomain()).toList(),
      media: media.map((item) => item.toDomain()).toList(),
    );
  }
}

class BusinessServiceDto {
  const BusinessServiceDto({
    required this.description,
    required this.priceFrom,
    required this.subcategory,
  });

  factory BusinessServiceDto.fromJson(Map<String, dynamic> json) {
    final subcategory = json['subcategories'] as Map<String, dynamic>?;

    return BusinessServiceDto(
      description: json['description'] as String?,
      priceFrom: json['price_from'] as int?,
      subcategory: Subcategory(
        id: subcategory?['id'] as String? ?? json['subcategory_id'] as String,
        categoryId: subcategory?['category_id'] as String? ?? '',
        name: subcategory?['name'] as String? ?? 'Servicio',
        slug: subcategory?['slug'] as String? ?? '',
        description: subcategory?['description'] as String?,
        iconKey: subcategory?['icon_key'] as String? ?? 'tools',
      ),
    );
  }

  final String? description;
  final int? priceFrom;
  final Subcategory subcategory;

  BusinessService toDomain() {
    return BusinessService(
      subcategory: subcategory,
      description: description,
      priceFrom: priceFrom,
    );
  }
}

class BusinessCoverageDto {
  const BusinessCoverageDto({
    required this.location,
  });

  factory BusinessCoverageDto.fromJson(Map<String, dynamic> json) {
    final location = json['locations'] as Map<String, dynamic>?;

    return BusinessCoverageDto(
      location: Location(
        id: location?['id'] as String? ?? json['location_id'] as String,
        communeId: location?['commune_id'] as String? ?? '',
        name: location?['name'] as String? ?? 'Localidad',
        slug: location?['slug'] as String? ?? '',
      ),
    );
  }

  final Location location;
}

class BusinessHourDto {
  const BusinessHourDto({
    required this.dayOfWeek,
    required this.openTime,
    required this.closeTime,
    required this.isClosed,
  });

  factory BusinessHourDto.fromJson(Map<String, dynamic> json) {
    return BusinessHourDto(
      dayOfWeek: json['day_of_week'] as int,
      openTime: json['open_time'] as String?,
      closeTime: json['close_time'] as String?,
      isClosed: json['is_closed'] as bool? ?? false,
    );
  }

  final int dayOfWeek;
  final String? openTime;
  final String? closeTime;
  final bool isClosed;

  BusinessHour toDomain() {
    return BusinessHour(
      dayOfWeek: dayOfWeek,
      openTime: openTime,
      closeTime: closeTime,
      isClosed: isClosed,
    );
  }
}

class BusinessMediaDto {
  const BusinessMediaDto({
    required this.type,
    required this.storagePath,
  });

  factory BusinessMediaDto.fromJson(Map<String, dynamic> json) {
    return BusinessMediaDto(
      type: json['media_type'] as String,
      storagePath: json['storage_path'] as String,
    );
  }

  final String type;
  final String storagePath;

  BusinessMedia toDomain() {
    return BusinessMedia(
      type: type,
      storagePath: storagePath,
    );
  }
}

List<Map<String, dynamic>> _list(Object? value) {
  if (value is List) {
    return value.whereType<Map<String, dynamic>>().toList();
  }

  return const [];
}
