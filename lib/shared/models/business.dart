import 'category.dart';
import 'location.dart';

enum BusinessType {
  service,
  commerce,
  gastronomy,
  lodging,
  tourism,
  emergency;

  String get label {
    return switch (this) {
      BusinessType.service => 'Servicio',
      BusinessType.commerce => 'Comercio',
      BusinessType.gastronomy => 'Gastronomía',
      BusinessType.lodging => 'Alojamiento',
      BusinessType.tourism => 'Turismo',
      BusinessType.emergency => 'Emergencia',
    };
  }

  String get value => name;

  static BusinessType parse(String value) {
    final type = tryParse(value);

    if (type == null) {
      throw ArgumentError.value(
        value,
        'value',
        'Unknown business type',
      );
    }

    return type;
  }

  static BusinessType? tryParse(String? value) {
    if (value == null) {
      return null;
    }

    for (final type in BusinessType.values) {
      if (type.name == value) {
        return type;
      }
    }

    return null;
  }

  static BusinessType parseOrDefault(
    String? value, {
    BusinessType defaultValue = BusinessType.service,
  }) {
    return tryParse(value) ?? defaultValue;
  }
}

enum BusinessPublicationStatus {
  draft,
  pendingReview,
  changesRequested,
  published,
  paused,
  rejected,
  suspended,
  archived;

  String get value {
    return switch (this) {
      BusinessPublicationStatus.pendingReview => 'pending_review',
      BusinessPublicationStatus.changesRequested => 'changes_requested',
      _ => name,
    };
  }

  String get label {
    return switch (this) {
      BusinessPublicationStatus.draft => 'Borrador',
      BusinessPublicationStatus.pendingReview => 'En revisión',
      BusinessPublicationStatus.changesRequested => 'Cambios solicitados',
      BusinessPublicationStatus.published => 'Publicado',
      BusinessPublicationStatus.paused => 'Pausado',
      BusinessPublicationStatus.rejected => 'Rechazado',
      BusinessPublicationStatus.suspended => 'Suspendido',
      BusinessPublicationStatus.archived => 'Archivado',
    };
  }

  bool get isPubliclyVisible {
    return this == BusinessPublicationStatus.published;
  }

  static BusinessPublicationStatus parseOrDefault(String? value) {
    return switch (value) {
      'pending_review' => BusinessPublicationStatus.pendingReview,
      'changes_requested' => BusinessPublicationStatus.changesRequested,
      'published' => BusinessPublicationStatus.published,
      'paused' => BusinessPublicationStatus.paused,
      'rejected' => BusinessPublicationStatus.rejected,
      'suspended' => BusinessPublicationStatus.suspended,
      'archived' => BusinessPublicationStatus.archived,
      _ => BusinessPublicationStatus.draft,
    };
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
