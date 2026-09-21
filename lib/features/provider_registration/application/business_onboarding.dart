import '../../../shared/models/business.dart';
import '../../../shared/models/business_capability.dart';

enum BusinessOnboardingSection {
  account,
  commonProfile,
  contact,
  location,
  services,
  coverage,
  lodging,
  gastronomy,
  commerce,
  tourism,
  emergency,
  terms,
  review;

  String get label {
    return switch (this) {
      BusinessOnboardingSection.account => 'Cuenta',
      BusinessOnboardingSection.commonProfile => 'Perfil',
      BusinessOnboardingSection.contact => 'Contacto',
      BusinessOnboardingSection.location => 'Ubicación',
      BusinessOnboardingSection.services => 'Servicios',
      BusinessOnboardingSection.coverage => 'Cobertura',
      BusinessOnboardingSection.lodging => 'Alojamiento',
      BusinessOnboardingSection.gastronomy => 'Gastronomía',
      BusinessOnboardingSection.commerce => 'Comercio',
      BusinessOnboardingSection.tourism => 'Turismo',
      BusinessOnboardingSection.emergency => 'Emergencia',
      BusinessOnboardingSection.terms => 'Términos',
      BusinessOnboardingSection.review => 'Revisión',
    };
  }
}

class BusinessOnboardingResolver {
  const BusinessOnboardingResolver();

  List<BusinessOnboardingSection> sectionsFor(BusinessType type) {
    final base = [
      BusinessOnboardingSection.account,
      BusinessOnboardingSection.commonProfile,
      BusinessOnboardingSection.contact,
      BusinessOnboardingSection.location,
    ];

    final specific = switch (type) {
      BusinessType.service => [
          BusinessOnboardingSection.services,
          BusinessOnboardingSection.coverage,
        ],
      BusinessType.commerce => [
          BusinessOnboardingSection.commerce,
        ],
      BusinessType.gastronomy => [
          BusinessOnboardingSection.gastronomy,
        ],
      BusinessType.lodging => [
          BusinessOnboardingSection.lodging,
        ],
      BusinessType.tourism => [
          BusinessOnboardingSection.tourism,
        ],
      BusinessType.emergency => [
          BusinessOnboardingSection.emergency,
          BusinessOnboardingSection.coverage,
        ],
    };

    return [
      ...base,
      ...specific,
      BusinessOnboardingSection.terms,
      BusinessOnboardingSection.review,
    ];
  }

  bool requiresSection({
    required BusinessCapabilitySet capabilities,
    required BusinessOnboardingSection section,
  }) {
    return switch (section) {
      BusinessOnboardingSection.services =>
        capabilities.can(BusinessCapability.services),
      BusinessOnboardingSection.coverage =>
        capabilities.can(BusinessCapability.coverage),
      BusinessOnboardingSection.lodging =>
        capabilities.can(BusinessCapability.bookings) ||
            capabilities.can(BusinessCapability.rates),
      BusinessOnboardingSection.gastronomy =>
        capabilities.can(BusinessCapability.menu),
      BusinessOnboardingSection.commerce =>
        capabilities.can(BusinessCapability.catalog),
      BusinessOnboardingSection.tourism =>
        capabilities.can(BusinessCapability.bookings) ||
            capabilities.can(BusinessCapability.services),
      BusinessOnboardingSection.emergency =>
        capabilities.can(BusinessCapability.emergencyAvailability),
      _ => true,
    };
  }
}
