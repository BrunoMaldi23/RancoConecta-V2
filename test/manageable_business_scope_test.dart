import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ranco_conecta_2/config/app_config.dart';
import 'package:ranco_conecta_2/features/provider_dashboard/application/provider_dashboard_providers.dart';
import 'package:ranco_conecta_2/features/provider_dashboard/data/provider_business_repository.dart';
import 'package:ranco_conecta_2/shared/models/business.dart';
import 'package:ranco_conecta_2/shared/models/business_capability.dart';

void main() {
  test('manageable business SQL scopes administration by auth.uid membership',
      () {
    final sql = File(
      'supabase/migrations/20260923203000_manageable_business_scope.sql',
    ).readAsStringSync();

    expect(sql, contains('function public.my_manageable_businesses()'));
    expect(sql, contains('auth.uid()'));
    expect(sql, contains("bm.status = 'active'"));
    expect(sql, contains("bm.role in ('owner', 'manager')"));
    expect(sql, isNot(contains('p_user_id')));
  });

  test('provider repository uses canonical rpc and not public catalog fallback',
      () {
    final source = File(
      'lib/features/provider_dashboard/data/provider_business_repository.dart',
    ).readAsStringSync();

    expect(source, contains('my_manageable_businesses'));
    expect(source, contains('my_manageable_business'));
    expect(source, isNot(contains('_getLegacyOwnerBusiness')));
    expect(source, isNot(contains(".from('businesses')")));
  });

  test('invalid active business id is reset to current manageable business',
      () async {
    final container = ProviderContainer(
      overrides: [
        myProviderBusinessesProvider.overrideWith(
          (ref) async => [_business('own-1', BusinessType.service)],
        ),
        activeProviderBusinessIdProvider.overrideWith((ref) => 'foreign-1'),
      ],
    );
    addTearDown(container.dispose);

    final selected =
        await container.read(activeProviderBusinessProvider.future);

    expect(selected?.id, 'own-1');
    expect(container.read(activeProviderBusinessIdProvider), isNull);
  });

  test('capabilities separate lodging from service dashboard features', () {
    const resolver = BusinessCapabilityResolver(
      featureFlags: FeatureFlags(
        lodgingEnabled: true,
        quotesEnabled: true,
      ),
    );

    final service = resolver.resolve(businessType: BusinessType.service);
    final lodging = resolver.resolve(businessType: BusinessType.lodging);

    expect(service.can(BusinessCapability.services), isTrue);
    expect(service.can(BusinessCapability.coverage), isTrue);
    expect(service.can(BusinessCapability.rates), isFalse);
    expect(service.can(BusinessCapability.calendar), isFalse);
    expect(service.can(BusinessCapability.bookings), isFalse);
    expect(lodging.can(BusinessCapability.rates), isTrue);
    expect(lodging.can(BusinessCapability.calendar), isTrue);
    expect(lodging.can(BusinessCapability.bookings), isTrue);
  });

  test('non lodging verticals do not reuse lodging booking/calendar modules',
      () {
    const resolver = BusinessCapabilityResolver(
      featureFlags: FeatureFlags(lodgingEnabled: true),
    );

    for (final type in [
      BusinessType.commerce,
      BusinessType.gastronomy,
      BusinessType.tourism,
      BusinessType.emergency,
    ]) {
      final capabilities = resolver.resolve(businessType: type);
      expect(capabilities.can(BusinessCapability.rates), isFalse);
      expect(capabilities.can(BusinessCapability.calendar), isFalse);
      expect(capabilities.can(BusinessCapability.bookings), isFalse);
    }
  });
}

ProviderBusinessSummary _business(String id, BusinessType type) {
  return ProviderBusinessSummary(
    id: id,
    name: 'Negocio $id',
    businessType: type,
    publicationStatus: 'published',
  );
}
