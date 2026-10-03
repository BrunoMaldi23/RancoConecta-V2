import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ranco_conecta_2/config/app_config.dart';
import 'package:ranco_conecta_2/features/auth/application/auth_controller.dart';
import 'package:ranco_conecta_2/features/auth/domain/auth_user.dart';
import 'package:ranco_conecta_2/features/profile/application/profile_providers.dart';
import 'package:ranco_conecta_2/router/app_router.dart';
import 'package:ranco_conecta_2/shared/models/profile.dart';

void main() {
  testWidgets('router stays on bootstrap until initial auth event',
      (tester) async {
    final authEvents = StreamController<AuthUser?>();
    addTearDown(authEvents.close);
    final container = ProviderContainer(overrides: [
      appConfigProvider.overrideWithValue(const AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: null,
        supabasePublishableKey: null,
      )),
      authStateProvider.overrideWith((ref) => authEvents.stream),
    ]);
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, '/bootstrap');
    expect(find.text('Preparando Ranco Conecta...'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNothing);

    authEvents.add(null);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/sign-in');
  });

  testWidgets('admin opening provider dashboard is redirected to admin',
      (tester) async {
    final container = ProviderContainer(overrides: [
      appConfigProvider.overrideWithValue(const AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: null,
        supabasePublishableKey: null,
      )),
      authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(
            id: 'admin-1',
            email: 'admin@example.com',
            emailConfirmed: true,
          ))),
      currentProfileProvider.overrideWith((ref) async => const Profile(
            id: 'admin-1',
            fullName: 'Bruno',
            phone: null,
            avatarUrl: null,
            role: ProfileRole.admin,
            accountStatus: 'active',
          )),
    ]);
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    router.go('/provider/dashboard');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/admin');
    expect(find.text('Mi negocio'), findsNothing);
  });

  testWidgets('provider cannot open admin and may open provider onboarding',
      (tester) async {
    final container = ProviderContainer(overrides: [
      appConfigProvider.overrideWithValue(const AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: null,
        supabasePublishableKey: null,
      )),
      authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(
            id: 'provider-1',
            email: 'provider@example.com',
            emailConfirmed: true,
          ))),
      currentProfileProvider.overrideWith((ref) async => const Profile(
            id: 'provider-1',
            fullName: 'Prestador',
            phone: null,
            avatarUrl: null,
            role: ProfileRole.provider,
            accountStatus: 'active',
          )),
    ]);
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    router.go('/admin');
    await tester.pumpAndSettle();
    expect(find.text('No tienes acceso administrativo.'), findsOneWidget);

    router.go('/provider/join');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/provider/join');
    expect(find.text('No tienes acceso administrativo.'), findsNothing);
  });
}
