import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ranco_conecta_2/config/app_config.dart';
import 'package:ranco_conecta_2/shared/models/business.dart';
import 'package:ranco_conecta_2/shared/models/business_capability.dart';

void main() {
  test('service management migration exposes secure provider RPCs', () {
    final sql = File(
      'supabase/migrations/20260923213000_service_business_management.sql',
    ).readAsStringSync();

    expect(sql, contains('update_manageable_business_profile'));
    expect(sql, contains('replace_manageable_business_services'));
    expect(sql, contains('replace_manageable_business_coverage'));
    expect(sql, contains('replace_manageable_business_hours'));
    expect(sql, contains('public.user_can_manage_business(p_business_id)'));
    expect(sql, isNot(contains('p_user_id')));
  });

  test('service capabilities include service management but exclude lodging',
      () {
    const resolver = BusinessCapabilityResolver(
      featureFlags: FeatureFlags(
        quotesEnabled: true,
        lodgingEnabled: true,
      ),
    );

    final capabilities = resolver.resolve(businessType: BusinessType.service);

    expect(capabilities.can(BusinessCapability.profile), isTrue);
    expect(capabilities.can(BusinessCapability.photos), isTrue);
    expect(capabilities.can(BusinessCapability.services), isTrue);
    expect(capabilities.can(BusinessCapability.coverage), isTrue);
    expect(capabilities.can(BusinessCapability.hours), isTrue);
    expect(capabilities.can(BusinessCapability.quotes), isTrue);
    expect(capabilities.can(BusinessCapability.rates), isFalse);
    expect(capabilities.can(BusinessCapability.calendar), isFalse);
    expect(capabilities.can(BusinessCapability.bookings), isFalse);
  });

  test('lodging keeps lodging capabilities', () {
    const resolver = BusinessCapabilityResolver(
      featureFlags: FeatureFlags(lodgingEnabled: true),
    );

    final capabilities = resolver.resolve(businessType: BusinessType.lodging);

    expect(capabilities.can(BusinessCapability.photos), isTrue);
    expect(capabilities.can(BusinessCapability.rates), isTrue);
    expect(capabilities.can(BusinessCapability.calendar), isTrue);
    expect(capabilities.can(BusinessCapability.bookings), isTrue);
    expect(capabilities.can(BusinessCapability.services), isFalse);
  });
}
