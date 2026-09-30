import '../../../shared/models/business.dart';
import 'business_hours.dart';

enum BusinessProfileSection {
  about,
  services,
  coverage,
  hours,
  photos,
  reviews,
  lodgingDetails,
  location,
  menu,
}

class BusinessProfilePresentation {
  const BusinessProfilePresentation({
    required this.subtitle,
    required this.sections,
    required this.showRequestCta,
    required this.showAvailableBadge,
  });

  final String subtitle;
  final List<BusinessProfileSection> sections;
  final bool showRequestCta;
  final bool showAvailableBadge;
}

BusinessProfilePresentation businessProfilePresentation(Business business) {
  final sections = <BusinessProfileSection>[
    if (_hasText(business.description)) BusinessProfileSection.about,
    if (_showsServices(business) && business.services.isNotEmpty)
      BusinessProfileSection.services,
    if (_showsCoverage(business) && business.coverage.isNotEmpty)
      BusinessProfileSection.coverage,
    if (_showsHours(business) && business.hours.isNotEmpty)
      BusinessProfileSection.hours,
    if (business.type == BusinessType.gastronomy) BusinessProfileSection.menu,
    if (_showsLocation(business)) BusinessProfileSection.location,
    if (business.type == BusinessType.lodging)
      BusinessProfileSection.lodgingDetails,
    if (business.media.isNotEmpty) BusinessProfileSection.photos,
    BusinessProfileSection.reviews,
  ];

  return BusinessProfilePresentation(
    subtitle: businessProfileSubtitle(business),
    sections: sections,
    showRequestCta:
        business.type == BusinessType.service && business.acceptsRequests,
    showAvailableBadge:
        business.hours.isNotEmpty && business.type != BusinessType.lodging,
  );
}

String businessProfileSubtitle(Business business) {
  final realService = business.services
      .where((service) => !_isGenericService(service.subcategory.name))
      .firstOrNull;

  if (realService != null) {
    return realService.subcategory.name;
  }

  return business.type.label;
}

bool businessIsAvailableNow(Business business, DateTime now) {
  if (business.hours.isEmpty) {
    return false;
  }

  return isOpenNow(business.hours, now);
}

bool _showsServices(Business business) {
  return business.type == BusinessType.service ||
      business.type == BusinessType.tourism;
}

bool _showsCoverage(Business business) {
  return business.type == BusinessType.service ||
      business.type == BusinessType.tourism ||
      business.type == BusinessType.emergency;
}

bool _showsHours(Business business) {
  return business.type == BusinessType.service ||
      business.type == BusinessType.commerce ||
      business.type == BusinessType.gastronomy ||
      business.type == BusinessType.tourism ||
      business.type == BusinessType.emergency;
}

bool _showsLocation(Business business) {
  return business.type == BusinessType.commerce &&
      (_hasText(business.addressText) || business.primaryLocation != null);
}

bool _hasText(String? value) {
  return value?.trim().isNotEmpty == true;
}

bool _isGenericService(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized == 'general' || normalized == 'servicio';
}
