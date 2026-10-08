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
  testWidgets('provider sign-in stays mounted while the new profile resolves',
      (tester) async {
    final authEvents = StreamController<AuthUser?>();
    final profileGate = Completer<void>();
    addTearDown(authEvents.close);
    final container = ProviderContainer(overrides: [
      appConfigProvider.overrideWithValue(const AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: null,
        supabasePublishableKey: null,
      )),
      authStateProvider.overrideWith((ref) => authEvents.stream),
      currentProfileProvider.overrideWith((ref) async {
        await profileGate.future;
        return const Profile(
          id: 'provider-1',
          fullName: 'Prestador',
          phone: null,
          avatarUrl: null,
          role: ProfileRole.provider,
          accountStatus: 'active',
        );
      }),
    ]);
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    authEvents.add(null);
    await tester.pumpAndSettle();
    router.go('/provider/sign-in');
    await tester.pumpAndSettle();
    authEvents.add(const AuthUser(
      id: 'provider-1',
      email: 'provider@example.com',
      emailConfirmed: true,
    ));
    await tester.pump();
    expect(router.routeInformationProvider.value.uri.path, '/provider/sign-in');
    profileGate.complete();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/provider/sign-in');
  });

  testWidgets('logout hides admin route before auth stream finishes',
      (tester) async {
    final authEvents = StreamController<AuthUser?>.broadcast();
    addTearDown(authEvents.close);
    final container = ProviderContainer(overrides: [
      appConfigProvider.overrideWithValue(const AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: null,
        supabasePublishableKey: null,
      )),
      authStateProvider.overrideWith((ref) => authEvents.stream),
      currentProfileProvider.overrideWith((ref) async => const Profile(
            id: 'admin-1',
            fullName: 'Bruno',
            phone: null,
            avatarUrl: null,
            role: ProfileRole.superAdmin,
            accountStatus: 'active',
          )),
    ]);
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    authEvents.add(const AuthUser(
      id: 'admin-1',
      email: 'admin@example.test',
      emailConfirmed: true,
    ));
    await tester.pumpAndSettle();
    router.go('/admin');
    await tester.pumpAndSettle();
    container.read(signingOutProvider.notifier).state = true;
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/sign-in');
    expect(find.text('Administración'), findsNothing);

    authEvents.add(null);
    await tester.pumpAndSettle();
    container.read(signingOutProvider.notifier).state = false;
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/sign-in');
  });

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
    expect(find.text('Preparando tu cuenta…'), findsOneWidget);
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
            role: ProfileRole.superAdmin,
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
    expect(router.routeInformationProvider.value.uri.path, '/explore');

    router.go('/provider/join');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/provider/join');
  });
}
