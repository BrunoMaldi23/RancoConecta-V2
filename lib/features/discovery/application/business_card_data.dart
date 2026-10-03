import '../../../features/businesses/application/business_hours.dart' as hours;
import '../../../features/provider_dashboard/data/lodging_details_repository.dart';
import '../../../shared/models/business.dart';
import '../../../shared/models/category.dart';

/// Only the public information needed to present a business in Explore.
class BusinessCardData {
  const BusinessCardData({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.name,
    required this.serviceName,
    required this.serviceSlug,
    required this.categoryName,
    required this.categoryIconKey,
    required this.categoryThemeKey,
    required this.coverImagePath,
    required this.logoImagePath,
    required this.providerAvatarUrl,
    required this.providerPublicName,
    required this.location,
    required this.coverage,
    required this.isVerified,
    required this.isFeatured,
    required this.rating,
    required this.reviewsCount,
    required this.businessHours,
    required this.lodging,
  });

  factory BusinessCardData.fromBusiness(
    Business business, {
    List<Category> categories = const [],
    String? selectedCategoryId,
    LodgingDetails? lodgingDetails,
    String? providerAvatarUrl,
    String? providerPublicName,
  }) {
    final service = business.services
            .where((item) =>
                selectedCategoryId != null &&
                item.subcategory.categoryId == selectedCategoryId)
            .firstOrNull ??
        business.services.firstOrNull;
    final category = categories
        .where((item) => item.id == service?.subcategory.categoryId)
        .firstOrNull;
    final address = business.addressText?.trim();

    return BusinessCardData(
      id: business.id,
      ownerId: business.ownerId,
      type: business.type,
      name: business.name,
      serviceName: service?.subcategory.name ??
          (business.type == BusinessType.tourism
              ? 'Turismo y Aventura'
              : business.type.label),
      serviceSlug: service?.subcategory.slug,
      categoryName: category?.name,
      categoryIconKey: category?.iconKey,
      categoryThemeKey: category?.themeKey,
      coverImagePath: business.coverPath ??
          business.media
              .where((item) => item.type != 'logo')
              .firstOrNull
              ?.storagePath,
      logoImagePath: business.logoPath,
      providerAvatarUrl: providerAvatarUrl,
      providerPublicName: providerPublicName,
      location: address == null || address.isEmpty
          ? business.primaryLocation?.name
          : address,
      coverage: business.coverage.map((item) => item.name).take(2).join(' · '),
      isVerified: business.isVerified,
      isFeatured: business.isFeatured,
      rating: business.ratingAvg,
      reviewsCount: business.reviewCount,
      businessHours: business.hours,
      lodging: lodgingDetails == null
          ? null
          : LodgingCardSummary.fromDetails(lodgingDetails),
    );
  }

  final String id;
  final String ownerId;
  final BusinessType type;
  final String name;
  final String serviceName;
  final String? serviceSlug;
  final String? categoryName;
  final String? categoryIconKey;
  final String? categoryThemeKey;
  final String? coverImagePath;
  final String? logoImagePath;

  // Public profile data is not readable under the current profiles RLS policy.
  // Keep these nullable so a future public profile source can supply them.
  final String? providerAvatarUrl;
  final String? providerPublicName;

  final String? location;
  final String coverage;
  final bool isVerified;
  final bool isFeatured;
  final double rating;
  final int reviewsCount;
  final List<BusinessHour> businessHours;
  final LodgingCardSummary? lodging;

  bool isOpenNow(DateTime now) => hours.isOpenNow(businessHours, now);
}

class LodgingCardSummary {
  const LodgingCardSummary({
    required this.pricePerNight,
    required this.maxGuests,
    required this.beds,
    required this.bedrooms,
    required this.bathrooms,
    required this.minNights,
    required this.maxNights,
  });

  factory LodgingCardSummary.fromDetails(LodgingDetails details) {
    return LodgingCardSummary(
      pricePerNight: details.pricePerNight > 0 ? details.pricePerNight : null,
      maxGuests: details.maxGuests > 0 ? details.maxGuests : null,
      beds: details.beds > 0 ? details.beds : null,
      bedrooms: details.bedrooms > 0 ? details.bedrooms : null,
      bathrooms: details.bathrooms > 0 ? details.bathrooms : null,
      minNights: details.minNights > 0 ? details.minNights : null,
      maxNights: details.maxNights,
    );
  }

  final int? pricePerNight;
  final int? maxGuests;
  final int? beds;
  final int? bedrooms;
  final double? bathrooms;
  final int? minNights;
  final int? maxNights;
}
