import 'package:flutter_test/flutter_test.dart';
import 'package:ranco_conecta_2/config/app_config.dart';
import 'package:ranco_conecta_2/features/provider_registration/application/business_onboarding.dart';
import 'package:ranco_conecta_2/features/provider_registration/application/business_onboarding_requirements.dart';
import 'package:ranco_conecta_2/features/provider_registration/data/business_onboarding_repository.dart';
import 'package:ranco_conecta_2/shared/models/business.dart';
import 'package:ranco_conecta_2/shared/models/business_capability.dart';
import 'package:ranco_conecta_2/shared/models/business_membership.dart';
import 'package:ranco_conecta_2/shared/models/category.dart';
import 'package:ranco_conecta_2/shared/models/location.dart';
import 'package:ranco_conecta_2/shared/models/monetization.dart';
import 'package:ranco_conecta_2/shared/models/operation.dart';

void main() {
  test('parses supported business types without relying on UI labels', () {
    expect(BusinessType.parse('service'), BusinessType.service);
    expect(BusinessType.parse('commerce'), BusinessType.commerce);
    expect(BusinessType.parse('gastronomy'), BusinessType.gastronomy);
    expect(BusinessType.parse('lodging'), BusinessType.lodging);
    expect(BusinessType.parse('tourism'), BusinessType.tourism);
    expect(BusinessType.parse('emergency'), BusinessType.emergency);
    expect(BusinessType.tryParse('unknown'), isNull);
    expect(() => BusinessType.parse('unknown'), throwsArgumentError);
    expect(
      BusinessType.parseOrDefault('unknown'),
      BusinessType.service,
    );
  });

  test('resolves base capabilities per vertical and honors feature flags', () {
    const resolver = BusinessCapabilityResolver(
      featureFlags: FeatureFlags(
        quotesEnabled: false,
        paymentsEnabled: false,
        chatEnabled: false,
        lodgingEnabled: true,
      ),
    );

    final lodging = resolver.resolve(
      businessType: BusinessType.lodging,
    );
    final service = resolver.resolve(
      businessType: BusinessType.service,
    );
    final emergency = resolver.resolve(
      businessType: BusinessType.emergency,
    );

    expect(lodging.can(BusinessCapability.bookings), isTrue);
    expect(lodging.can(BusinessCapability.rates), isTrue);
    expect(service.can(BusinessCapability.services), isTrue);
    expect(service.can(BusinessCapability.quotes), isFalse);
    expect(
      service.resolve(BusinessCapability.quotes).reason,
      'disabled_by_feature_flag',
    );
    expect(emergency.can(BusinessCapability.emergencyAvailability), isTrue);
  });

  test('plan features extend base capabilities without controlling publication',
      () {
    const resolver = BusinessCapabilityResolver(
      featureFlags: FeatureFlags(),
    );

    final capabilities = resolver.resolve(
      businessType: BusinessType.commerce,
      planFeatures: const [
        PlanFeature(
          key: 'analytics',
          enabled: true,
        ),
        PlanFeature(
          key: 'team',
          enabled: true,
          limitValue: 3,
        ),
      ],
    );

    expect(capabilities.can(BusinessCapability.catalog), isTrue);
    expect(capabilities.can(BusinessCapability.analytics), isTrue);
    expect(capabilities.can(BusinessCapability.team), isTrue);
  });

  test('monetization policy keeps commission rules separate from plans', () {
    const resolver = BusinessCapabilityResolver(
      featureFlags: FeatureFlags(),
    );
    const service = MonetizationPolicyService(
      capabilityResolver: resolver,
    );

    final policy = service.resolve(
      businessType: BusinessType.lodging,
      operationType: OperationType.booking,
      commissionRules: const [
        CommissionRule(
          businessType: BusinessType.lodging,
          operationType: OperationType.booking,
          active: true,
          percentageBasisPoints: 0,
        ),
        CommissionRule(
          businessType: BusinessType.service,
          operationType: OperationType.quote,
          active: true,
          percentageBasisPoints: 0,
        ),
      ],
    );

    expect(policy.plan, isNull);
    expect(policy.commissionRule?.operationType, OperationType.booking);
    expect(policy.capabilities.can(BusinessCapability.bookings), isTrue);
  });

  test('onboarding resolver composes shared and type-specific sections', () {
    const resolver = BusinessOnboardingResolver();

    final lodgingSections = resolver.sectionsFor(BusinessType.lodging);
    final emergencySections = resolver.sectionsFor(BusinessType.emergency);

    expect(
      lodgingSections,
      contains(BusinessOnboardingSection.commonProfile),
    );
    expect(lodgingSections, contains(BusinessOnboardingSection.lodging));
    expect(emergencySections, contains(BusinessOnboardingSection.emergency));
    expect(emergencySections, contains(BusinessOnboardingSection.coverage));
  });

  test('centralizes business member permissions by role', () {
    expect(BusinessMemberRole.owner.canManageBusiness, isTrue);
    expect(BusinessMemberRole.owner.canSubmitForReview, isTrue);
    expect(BusinessMemberRole.owner.canManageSettings, isTrue);

    expect(BusinessMemberRole.manager.canManageBusiness, isTrue);
    expect(BusinessMemberRole.manager.canSubmitForReview, isTrue);
    expect(BusinessMemberRole.manager.canManageSettings, isFalse);

    expect(BusinessMemberRole.staff.canManageBusiness, isFalse);
    expect(BusinessMemberRole.staff.canSubmitForReview, isFalse);
  });

  test('uses pending review as the single submitted lifecycle state', () {
    expect(
      BusinessPublicationStatus.parseOrDefault('pending_review'),
      BusinessPublicationStatus.pendingReview,
    );
    expect(BusinessPublicationStatus.pendingReview.value, 'pending_review');
    expect(
      BusinessPublicationStatus.parseOrDefault('submitted'),
      BusinessPublicationStatus.draft,
    );
  });

  test('validates service onboarding requirements from saved content', () {
    const requirements = BusinessOnboardingRequirements();
    const incomplete = BusinessDraft(
      id: 'business-1',
      businessType: BusinessType.service,
      publicationStatus: BusinessPublicationStatus.draft,
      name: 'SR',
      description: null,
      phone: null,
      whatsapp: null,
      email: null,
      website: null,
      primaryCategoryId: null,
      addressText: null,
      coverage: [],
      services: [],
      onboardingMetadata: {},
      submittedAt: null,
      changesRequestedNote: null,
    );

    final missing = requirements.evaluate(incomplete);

    expect(requirements.canSubmit(incomplete), isFalse);
    expect(
      missing.where((item) => !item.satisfied).map((item) => item.key),
      containsAll(['name', 'description', 'category', 'contact', 'coverage']),
    );

    const complete = BusinessDraft(
      id: 'business-1',
      businessType: BusinessType.service,
      publicationStatus: BusinessPublicationStatus.draft,
      name: 'Servicios Ranco',
      description: 'Mantencion domiciliaria para vecinos del sector.',
      phone: '+56912345678',
      whatsapp: null,
      email: null,
      website: null,
      primaryCategoryId: 'category-1',
      addressText: null,
      coverage: [
        Location(
          id: 'location-1',
          communeId: 'commune-1',
          name: 'Lago Ranco',
          slug: 'lago-ranco',
        ),
      ],
      services: [
        BusinessDraftService(
          subcategory: Subcategory(
            id: 'subcategory-1',
            categoryId: 'category-1',
            name: 'Gasfiteria',
            slug: 'gasfiteria',
            description: null,
            iconKey: 'tools',
          ),
          description: null,
          priceFrom: null,
        ),
      ],
      onboardingMetadata: {},
      submittedAt: null,
      changesRequestedNote: null,
    );

    expect(requirements.canSubmit(complete), isTrue);
  });
}
