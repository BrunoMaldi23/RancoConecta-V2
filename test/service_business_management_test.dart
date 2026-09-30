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

  test('controlled panel migration adds categories and lodging max nights', () {
    final sql = File(
      'supabase/migrations/20260928223000_provider_panel_controlled_evolution.sql',
    ).readAsStringSync();

    expect(sql, contains('Retiro de escombros'));
    expect(sql, contains('Retiro de chatarra'));
    expect(sql, contains('Servicios de fosas'));
    expect(sql, contains('Hogar y mantenimiento'));
    expect(sql, contains('Inspección visual'));
    expect(sql, contains('add column if not exists max_nights integer'));
    expect(sql, contains('lodging_details_max_nights_valid'));
    expect(sql, contains('max_nights is null'));
    expect(sql, contains('max_nights >= min_nights'));
    expect(sql, contains('v_nights < v_min_nights'));
    expect(sql, contains('v_max_nights is not null'));
    expect(sql, contains('v_nights > v_max_nights'));
    expect(sql, contains('p_message text default null'));
    expect(sql, isNot(contains('drop table')));
    expect(sql, isNot(contains('delete from public.lodging_bookings')));
  });

  test('gastronomy migration adds menu and table reservations only', () {
    final sql = File(
      'supabase/migrations/20260928233000_gastronomy_menu_table_reservations.sql',
    ).readAsStringSync();
    final normalized = sql.toLowerCase();

    expect(
        sql,
        contains(
            'create table if not exists public.gastronomy_menu_categories'));
    expect(sql,
        contains('create table if not exists public.gastronomy_menu_items'));
    expect(
      sql,
      contains(
          'create table if not exists public.gastronomy_table_reservations'),
    );
    expect(sql, contains('create_gastronomy_table_reservation'));
    expect(sql, contains('confirm_gastronomy_table_reservation'));
    expect(sql, contains('reject_gastronomy_table_reservation'));
    expect(
        sql,
        contains(
            "status in ('pending', 'confirmed', 'rejected', 'cancelled')"));
    expect(sql, contains('business_type = \'gastronomy\''));
    expect(sql, contains('publication_status = \'published\''));
    expect(normalized, isNot(contains('delivery')));
    expect(normalized, isNot(contains('stock')));
    expect(normalized, isNot(contains('checkout')));
    expect(normalized, isNot(contains('payment')));
    expect(normalized, isNot(contains('cart')));
    expect(normalized, isNot(contains('orders')));
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

  test('commerce capabilities expose real management modules only', () {
    const resolver = BusinessCapabilityResolver(
      featureFlags: FeatureFlags(lodgingEnabled: true, quotesEnabled: true),
    );

    final capabilities = resolver.resolve(businessType: BusinessType.commerce);

    expect(capabilities.can(BusinessCapability.profile), isTrue);
    expect(capabilities.can(BusinessCapability.photos), isTrue);
    expect(capabilities.can(BusinessCapability.hours), isTrue);
    expect(capabilities.can(BusinessCapability.location), isTrue);
    expect(capabilities.can(BusinessCapability.contact), isTrue);
    expect(capabilities.can(BusinessCapability.reviews), isTrue);
    expect(capabilities.can(BusinessCapability.services), isFalse);
    expect(capabilities.can(BusinessCapability.coverage), isFalse);
    expect(capabilities.can(BusinessCapability.quotes), isFalse);
    expect(capabilities.can(BusinessCapability.bookings), isFalse);
    expect(capabilities.can(BusinessCapability.calendar), isFalse);
    expect(capabilities.can(BusinessCapability.rates), isFalse);
    expect(capabilities.can(BusinessCapability.catalog), isTrue);
  });
}
