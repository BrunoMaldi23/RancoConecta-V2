import '../../config/app_config.dart';
import 'business.dart';

enum BusinessCapability {
  profile,
  photos,
  services,
  coverage,
  hours,
  quotes,
  bookings,
  calendar,
  rates,
  menu,
  catalog,
  orders,
  delivery,
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
      _ => name,
    };
  }
}

class BusinessCapabilitySet {
  const BusinessCapabilitySet(
    this._capabilities, {
    this.access = const {},
  });

  final Set<BusinessCapability> _capabilities;
  final Map<BusinessCapability, CapabilityAccess> access;

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
    Iterable<PlanFeature> planFeatures = const [],
    Iterable<BusinessCapability> backendRestrictions = const [],
  }) {
    final baseCapabilities = baseCapabilitiesFor(businessType);
    final planAccess = {
      for (final feature in planFeatures) feature.key: feature,
    };
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
    );
  }

  static Set<BusinessCapability> baseCapabilitiesFor(BusinessType type) {
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
        },
      BusinessType.commerce => {
          ...shared,
          BusinessCapability.photos,
          BusinessCapability.hours,
          BusinessCapability.catalog,
          BusinessCapability.orders,
          BusinessCapability.delivery,
        },
      BusinessType.gastronomy => {
          ...shared,
          BusinessCapability.photos,
          BusinessCapability.hours,
          BusinessCapability.menu,
          BusinessCapability.delivery,
          BusinessCapability.orders,
        },
      BusinessType.lodging => {
          ...shared,
          BusinessCapability.photos,
          BusinessCapability.bookings,
          BusinessCapability.calendar,
          BusinessCapability.rates,
        },
      BusinessType.tourism => {
          ...shared,
          BusinessCapability.photos,
          BusinessCapability.services,
          BusinessCapability.coverage,
          BusinessCapability.hours,
        },
      BusinessType.emergency => {
          ...shared,
          BusinessCapability.photos,
          BusinessCapability.coverage,
          BusinessCapability.hours,
          BusinessCapability.emergencyAvailability,
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
