import 'category.dart';
import 'location.dart';

enum BusinessType {
  service,
  commerce,
  gastronomy,
  lodging;

  String get label {
    return switch (this) {
      BusinessType.service => 'Servicio',
      BusinessType.commerce => 'Comercio',
      BusinessType.gastronomy => 'Gastronomía',
      BusinessType.lodging => 'Alojamiento',
    };
  }

  static BusinessType parse(String value) {
    return BusinessType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => BusinessType.service,
    );
  }
}

class Business {
  const Business({
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

  final String id;
  final String ownerId;
  final BusinessType type;

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

  final List<BusinessService> services;
  final List<Location> coverage;
  final List<BusinessHour> hours;
  final List<BusinessMedia> media;

  bool get isVerified => verificationStatus == 'verified';

  String? get coverPath =>
      media.where((item) => item.type == 'cover').firstOrNull?.storagePath;

  String? get logoPath =>
      media.where((item) => item.type == 'logo').firstOrNull?.storagePath;
}

class BusinessService {
  const BusinessService({
    required this.subcategory,
    required this.description,
    required this.priceFrom,
  });

  final Subcategory subcategory;
  final String? description;
  final int? priceFrom;
}

class BusinessHour {
  const BusinessHour({
    required this.dayOfWeek,
    required this.openTime,
    required this.closeTime,
    required this.isClosed,
  });

  final int dayOfWeek;
  final String? openTime;
  final String? closeTime;
  final bool isClosed;
}

class BusinessMedia {
  const BusinessMedia({
    required this.type,
    required this.storagePath,
  });

  final String type;
  final String storagePath;
}
