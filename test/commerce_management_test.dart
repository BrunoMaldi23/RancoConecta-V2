import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('commerce dashboard exposes only real commerce management modules', () {
    final source = File(
      'lib/features/provider_dashboard/presentation/provider_dashboard_screen.dart',
    ).readAsStringSync();

    expect(source, contains('type == BusinessType.commerce'));
    expect(source, contains('Perfil comercial'));
    expect(source, contains("route: '/provider/location'"));
    expect(source, contains('Contacto'));
    expect(source, isNot(contains("title: 'Catálogo'")));
    expect(source, isNot(contains("title: 'Operaciones'")));
  });

  test('provider location route is registered', () {
    final router = File('lib/router/app_router.dart').readAsStringSync();

    expect(router, contains("path: '/provider/location'"));
    expect(router, contains('ProviderLocationScreen'));
  });

  test('commerce location management uses secure scoped rpc', () {
    final sql = File(
      'supabase/migrations/20260923223000_commerce_location_management.sql',
    ).readAsStringSync();
    final repository = File(
      'lib/features/provider_dashboard/data/service_business_management_repository.dart',
    ).readAsStringSync();

    expect(sql, contains('update_manageable_business_location'));
    expect(sql, contains('public.user_can_manage_business(p_business_id)'));
    expect(sql, contains('grant execute'));
    expect(sql, isNot(contains('p_user_id')));
    expect(repository, contains('updateLocation'));
    expect(repository, contains('update_manageable_business_location'));
  });

  test('provider location screen is scoped to active business state', () {
    final source = File(
      'lib/features/provider_dashboard/presentation/service_management_screens.dart',
    ).readAsStringSync();

    expect(source, contains('class ProviderLocationScreen'));
    expect(source, contains('serviceBusinessManagementProvider'));
    expect(source, contains('state.draft.id'));
    expect(
        source, contains('ref.invalidate(serviceBusinessManagementProvider)'));
  });

  test('commerce provider flow keeps photos and hours on active business', () {
    final providers = File(
      'lib/features/provider_dashboard/application/provider_dashboard_providers.dart',
    ).readAsStringSync();
    final dashboard = File(
      'lib/features/provider_dashboard/presentation/provider_dashboard_screen.dart',
    ).readAsStringSync();

    expect(providers, contains('activeProviderBusinessProvider'));
    expect(providers, contains('lodgingDetailsProvider'));
    expect(dashboard,
        contains('ref.invalidate(serviceBusinessManagementProvider)'));
  });
}
