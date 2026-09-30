import '../../config/app_config.dart';
import 'business.dart';

enum BusinessCapability {
  profile,
  photos,
  location,
  contact,
  services,
  coverage,
  hours,
  quotes,
  bookings,
  calendar,
  rates,
  menu,
  catalog,
  experiences,
  tableReservations,
  advancedAvailability,
  multipleLocations,
  featuredVisibility,
  payments,
  chat,
  reviews,
  promotions,
  analytics,
  team,
  emergencyAvailability;

  String get value {
    return switch (this) {
      BusinessCapability.emergencyAvailability => 'emergency_availability',
      BusinessCapability.tableReservations => 'table_reservations',
      BusinessCapability.advancedAvailability => 'advanced_availability',
      BusinessCapability.multipleLocations => 'multiple_locations',
      BusinessCapability.featuredVisibility => 'featured_visibility',
      _ => name,
    };
  }
}

enum BusinessPlanTier {
  basic,
  pro;

  String get label {
    return switch (this) {
      BusinessPlanTier.basic => 'Básico',
      BusinessPlanTier.pro => 'Pro',
    };
  }

  static BusinessPlanTier parseOrDefault(String? value) {
    final normalized = value?.trim().toLowerCase();

    if (normalized == 'pro' || normalized?.endsWith('_pro') == true) {
      return BusinessPlanTier.pro;
    }

    return BusinessPlanTier.basic;
  }
}

enum BusinessLimit {
  maxPhotos,
  maxServices,
  maxMenuItems,
  maxProducts,
  maxExperiences,
  maxLocations;

  String get value {
    return switch (this) {
      BusinessLimit.maxPhotos => 'max_photos',
      BusinessLimit.maxServices => 'max_services',
      BusinessLimit.maxMenuItems => 'max_menu_items',
      BusinessLimit.maxProducts => 'max_products',
      BusinessLimit.maxExperiences => 'max_experiences',
      BusinessLimit.maxLocations => 'max_locations',
    };
  }
}

class BusinessCapabilitySet {
  const BusinessCapabilitySet(
    this._capabilities, {
    this.access = const {},
    this.limits = const {},
    this.planTier = BusinessPlanTier.basic,
  });

  final Set<BusinessCapability> _capabilities;
  final Map<BusinessCapability, CapabilityAccess> access;
  final Map<BusinessLimit, int> limits;
  final BusinessPlanTier planTier;

  bool can(BusinessCapability capability) {
    return resolve(capability).enabled;
  }

  CapabilityAccess resolve(BusinessCapability capability) {
    return access[capability] ??
        CapabilityAccess(
          capability: capability,
          supported: _capabilities.contains(capability),
          entitled: _capabilities.contains(capability),
          globallyEnabled: true,
        );
  }

  Set<BusinessCapability> get values => Set.unmodifiable(_capabilities);

  int? limit(BusinessLimit limit) => limits[limit];
}

class CapabilityAccess {
  const CapabilityAccess({
    required this.capability,
    required this.supported,
    required this.entitled,
    required this.globallyEnabled,
    this.limitValue,
    this.reason,
  });

  final BusinessCapability capability;
  final bool supported;
  final bool entitled;
  final bool globallyEnabled;
  final int? limitValue;
  final String? reason;

  bool get enabled => supported && entitled && globallyEnabled;
}

class PlanFeature {
  const PlanFeature({
    required this.key,
    required this.enabled,
    this.limitValue,
    this.metadata = const {},
  });

  final String key;
  final bool enabled;
  final int? limitValue;
  final Map<String, Object?> metadata;
}

class BusinessCapabilityResolver {
  const BusinessCapabilityResolver({
    required this.featureFlags,
  });

  final FeatureFlags featureFlags;

  BusinessCapabilitySet resolve({
    required BusinessType businessType,
    BusinessPlanTier planTier = BusinessPlanTier.basic,
    Iterable<PlanFeature> planFeatures = const [],
    Iterable<BusinessCapability> backendRestrictions = const [],
  }) {
    final baseCapabilities = baseCapabilitiesFor(
      businessType,
      planTier: planTier,
    );
    final baseLimits = limitsFor(
      businessType,
      planTier: planTier,
    );
    final planAccess = {
      for (final feature in planFeatures) feature.key: feature,
    };
    final limitAccess = {
      for (final feature in planFeatures) feature.key: feature,
    };
    final resolvedLimits = <BusinessLimit, int>{
      ...baseLimits,
    };

    for (final limit in BusinessLimit.values) {
      final planFeature = limitAccess[limit.value];

      if (planFeature?.limitValue != null) {
        resolvedLimits[limit] = planFeature!.limitValue!;
      }
    }

    final access = <BusinessCapability, CapabilityAccess>{};

    for (final capability in BusinessCapability.values) {
      final planFeature = planAccess[capability.value];
      final supported = baseCapabilities.contains(capability) ||
          (planFeature != null && planFeature.enabled);
      final entitled = supported || (planFeature?.enabled ?? false);
      final globallyEnabled = _isGloballyEnabled(capability);
      final restricted = backendRestrictions.contains(capability);

      access[capability] = CapabilityAccess(
        capability: capability,
        supported: supported,
        entitled: entitled && !restricted,
        globallyEnabled: globallyEnabled,
        limitValue: planFeature?.limitValue,
        reason: _reason(
          supported: supported,
          entitled: entitled,
          globallyEnabled: globallyEnabled,
          restricted: restricted,
        ),
      );
    }

    return BusinessCapabilitySet(
      access.entries
          .where((entry) => entry.value.enabled)
          .map((entry) => entry.key)
          .toSet(),
      access: access,
      limits: resolvedLimits,
      planTier: planTier,
    );
  }

  static Set<BusinessCapability> baseCapabilitiesFor(
    BusinessType type, {
    BusinessPlanTier planTier = BusinessPlanTier.basic,
  }) {
    final shared = {
      BusinessCapability.profile,
      BusinessCapability.reviews,
    };

    return switch (type) {
      BusinessType.service => {
          ...shared,
          BusinessCapability.photos,
          BusinessCapability.services,
          BusinessCapability.coverage,
          BusinessCapability.hours,
          BusinessCapability.quotes,
          if (planTier == BusinessPlanTier.pro)
            BusinessCapability.multipleLocations,
          if (planTier == BusinessPlanTier.pro)
            BusinessCapability.featuredVisibility,
        },
      BusinessType.commerce => {
          ...shared,
          BusinessCapability.photos,
          BusinessCapability.location,
          BusinessCapability.contact,
          BusinessCapability.hours,
          BusinessCapability.catalog,
          if (planTier == BusinessPlanTier.pro)
            BusinessCapability.featuredVisibility,
        },
      BusinessType.gastronomy => {
          ...shared,
          BusinessCapability.photos,
          BusinessCapability.location,
          BusinessCapability.contact,
          BusinessCapability.hours,
          BusinessCapability.menu,
          if (planTier == BusinessPlanTier.pro)
            BusinessCapability.tableReservations,
          if (planTier == BusinessPlanTier.pro)
            BusinessCapability.featuredVisibility,
        },
      BusinessType.lodging => {
          ...shared,
          BusinessCapability.photos,
          BusinessCapability.location,
          BusinessCapability.contact,
          BusinessCapability.bookings,
          BusinessCapability.calendar,
          BusinessCapability.rates,
          if (planTier == BusinessPlanTier.pro)
            BusinessCapability.advancedAvailability,
          if (planTier == BusinessPlanTier.pro)
            BusinessCapability.featuredVisibility,
        },
      BusinessType.tourism => {
          ...shared,
          BusinessCapability.photos,
          BusinessCapability.experiences,
          BusinessCapability.coverage,
          BusinessCapability.hours,
          if (planTier == BusinessPlanTier.pro) BusinessCapability.bookings,
          if (planTier == BusinessPlanTier.pro)
            BusinessCapability.featuredVisibility,
        },
      BusinessType.emergency => {
          ...shared,
          BusinessCapability.photos,
          BusinessCapability.coverage,
          BusinessCapability.hours,
          BusinessCapability.emergencyAvailability,
          if (planTier == BusinessPlanTier.pro)
            BusinessCapability.multipleLocations,
          if (planTier == BusinessPlanTier.pro)
            BusinessCapability.featuredVisibility,
        },
    };
  }

  static Map<BusinessLimit, int> limitsFor(
    BusinessType type, {
    BusinessPlanTier planTier = BusinessPlanTier.basic,
  }) {
    final pro = planTier == BusinessPlanTier.pro;

    return switch (type) {
      BusinessType.service => {
          BusinessLimit.maxServices: pro ? 20 : 5,
          BusinessLimit.maxPhotos: pro ? 15 : 5,
          BusinessLimit.maxLocations: pro ? 10 : 1,
        },
      BusinessType.lodging => {
          BusinessLimit.maxPhotos: pro ? 15 : 5,
        },
      BusinessType.gastronomy => {
          BusinessLimit.maxMenuItems: pro ? 50 : 15,
          BusinessLimit.maxPhotos: pro ? 15 : 5,
        },
      BusinessType.commerce => {
          BusinessLimit.maxProducts: pro ? 50 : 15,
          BusinessLimit.maxPhotos: pro ? 15 : 5,
        },
      BusinessType.tourism => {
          BusinessLimit.maxExperiences: pro ? 15 : 3,
          BusinessLimit.maxPhotos: pro ? 15 : 5,
        },
      BusinessType.emergency => {
          BusinessLimit.maxPhotos: pro ? 15 : 5,
          BusinessLimit.maxLocations: pro ? 10 : 1,
        },
    };
  }

  bool _isGloballyEnabled(BusinessCapability capability) {
    return switch (capability) {
      BusinessCapability.quotes => featureFlags.quotesEnabled,
      BusinessCapability.payments => featureFlags.paymentsEnabled,
      BusinessCapability.chat => featureFlags.chatEnabled,
      BusinessCapability.bookings ||
      BusinessCapability.calendar ||
      BusinessCapability.rates =>
        featureFlags.lodgingEnabled,
      _ => true,
    };
  }

  String? _reason({
    required bool supported,
    required bool entitled,
    required bool globallyEnabled,
    required bool restricted,
  }) {
    if (!supported && !entitled) {
      return 'unsupported_by_business_type';
    }

    if (!entitled) {
      return 'not_included_in_plan';
    }

    if (!globallyEnabled) {
      return 'disabled_by_feature_flag';
    }

    if (restricted) {
      return 'restricted_by_backend';
    }

    return null;
  }
}
