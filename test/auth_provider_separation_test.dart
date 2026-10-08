import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ranco_conecta_2/core/widgets/ranco_states.dart';
import 'package:go_router/go_router.dart';
import 'package:ranco_conecta_2/config/app_config.dart';
import 'package:ranco_conecta_2/core/result/result.dart';
import 'package:ranco_conecta_2/features/auth/application/auth_controller.dart';
import 'package:ranco_conecta_2/features/auth/domain/auth_user.dart';
import 'package:ranco_conecta_2/features/profile/application/profile_providers.dart';
import 'package:ranco_conecta_2/features/profile/data/profile_repository.dart';
import 'package:ranco_conecta_2/features/profile/presentation/account_screen.dart';
import 'package:ranco_conecta_2/features/provider_dashboard/application/provider_dashboard_providers.dart';
import 'package:ranco_conecta_2/features/provider_dashboard/data/provider_business_repository.dart';
import 'package:ranco_conecta_2/shared/models/business.dart';
import 'package:ranco_conecta_2/shared/models/profile.dart';

const _admin = Profile(
  id: 'admin-1',
  fullName: 'Bruno',
  phone: null,
  avatarUrl: null,
  role: ProfileRole.admin,
  accountStatus: 'active',
);
const _provider = Profile(
  id: 'provider-1',
  fullName: 'Prestador',
  phone: null,
  avatarUrl: null,
  role: ProfileRole.provider,
  accountStatus: 'active',
);
const _adminUser = AuthUser(
  id: 'admin-1',
  email: 'admin@example.com',
  emailConfirmed: true,
);

void main() {
  testWidgets('account waits for auth, then loads the active admin profile',
      (tester) async {
    final authEvents = StreamController<AuthUser?>();
    addTearDown(authEvents.close);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const AccountScreen()),
    ]);
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig(
          environment: AppEnvironment.development,
          supabaseUrl: null,
          supabasePublishableKey: null,
        )),
        authStateProvider.overrideWith((ref) => authEvents.stream),
        currentProfileProvider.overrideWith((ref) async => _admin),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));

    // FASE 3.21: esqueleto con la forma de Cuenta (perfil + negocio).
    expect(find.byType(RancoSkeletonCard), findsWidgets);
    expect(find.text('Debes ingresar para ver tu perfil.'), findsNothing);
    expect(find.text('Inicia sesión en tu cuenta'), findsNothing);

    authEvents.add(_adminUser);
    await tester.pumpAndSettle();
    expect(find.text('Bruno'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Abrir panel'), findsOneWidget);
    expect(find.text('Mi negocio'), findsNothing);
  });

  testWidgets('account shows guest only after initial auth resolves empty',
      (tester) async {
    final authEvents = StreamController<AuthUser?>();
    addTearDown(authEvents.close);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const AccountScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [authStateProvider.overrideWith((ref) => authEvents.stream)],
      child: MaterialApp.router(routerConfig: router),
    ));
    expect(find.text('Inicia sesión en tu cuenta'), findsNothing);
    authEvents.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Inicia sesión en tu cuenta'), findsOneWidget);
  });

  test('profile fetch waits for auth and follows account changes', () async {
    final authEvents = StreamController<AuthUser?>();
    final repository = _FakeProfileRepository();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => authEvents.stream),
      profileRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(() async {
      container.dispose();
      await authEvents.close();
    });

    final first = container.read(currentProfileProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(repository.calls, 0);
    authEvents.add(_adminUser);
    expect((await first).role, ProfileRole.admin);
    expect(repository.calls, 1);

    authEvents.add(const AuthUser(
      id: 'provider-1',
      email: 'provider@example.com',
      emailConfirmed: true,
    ));
    await Future<void>.delayed(Duration.zero);
    expect((await container.read(currentProfileProvider.future)).role,
        ProfileRole.provider);
    expect(repository.calls, 2);
  });

  test('admin historical ownership never creates provider active business',
      () async {
    final container = ProviderContainer(overrides: [
      currentProfileProvider.overrideWith((ref) async => _admin),
      providerBusinessRepositoryProvider.overrideWithValue(
        _FakeBusinessRepository(),
      ),
      activeProviderBusinessIdProvider.overrideWith((ref) => 'business-1'),
    ]);
    addTearDown(container.dispose);

    expect(await container.read(myProviderBusinessesProvider.future), isEmpty);
    expect(await container.read(activeProviderBusinessProvider.future), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(activeProviderBusinessIdProvider), isNull);
  });

  test('provider only sees owned businesses and rejects foreign active id',
      () async {
    final repository = _FakeBusinessRepository();
    final container = ProviderContainer(overrides: [
      currentProfileProvider.overrideWith((ref) async => _provider),
      providerBusinessRepositoryProvider.overrideWithValue(repository),
      activeProviderBusinessIdProvider.overrideWith((ref) => 'foreign-id'),
    ]);
    addTearDown(container.dispose);
    final items = await container.read(myProviderBusinessesProvider.future);
    final active = await container.read(activeProviderBusinessProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(items.map((item) => item.id), ['business-1']);
    expect(active?.id, 'business-1');
    expect(container.read(activeProviderBusinessIdProvider), isNull);
    expect(repository.calls, 1);
  });

  test('customer with an existing owned business keeps provider capability',
      () async {
    final container = ProviderContainer(overrides: [
      currentProfileProvider.overrideWith((ref) async => const Profile(
            id: 'customer-owner-1',
            fullName: 'Dueño',
            phone: null,
            avatarUrl: null,
            role: ProfileRole.customer,
            accountStatus: 'active',
          )),
      providerBusinessRepositoryProvider.overrideWithValue(
        _FakeBusinessRepository(),
      ),
    ]);
    addTearDown(container.dispose);
    expect((await container.read(activeProviderBusinessProvider.future))?.id,
        'business-1');
  });

  test('provider to admin identity change drops provider business context',
      () async {
    final authEvents = StreamController<AuthUser?>();
    final repository = _FakeBusinessRepository();
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => authEvents.stream),
      currentProfileProvider.overrideWith((ref) async {
        final user = await ref.watch(authStateProvider.future);
        return user?.id == _adminUser.id ? _admin : _provider;
      }),
      providerBusinessRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(() async {
      container.dispose();
      await authEvents.close();
    });

    authEvents.add(const AuthUser(
      id: 'provider-1',
      email: 'provider@example.com',
      emailConfirmed: true,
    ));
    expect((await container.read(activeProviderBusinessProvider.future))?.id,
        'business-1');
    container.read(activeProviderBusinessIdProvider.notifier).state =
        'business-1';

    authEvents.add(_adminUser);
    await Future<void>.delayed(Duration.zero);
    expect(await container.read(activeProviderBusinessProvider.future), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(activeProviderBusinessIdProvider), isNull);
    expect(repository.calls, 1);
  });
}

class _FakeProfileRepository implements ProfileRepository {
  int calls = 0;

  @override
  Future<Result<Profile>> getCurrentProfile(String userId) async {
    calls++;
    return Success(calls == 1 ? _admin : _provider);
  }

  @override
  Future<Result<Profile>> updateCurrentProfile({
    required String fullName,
    required String? phone,
  }) async =>
      const Success(_admin);
}

class _FakeBusinessRepository extends ProviderBusinessRepository {
  _FakeBusinessRepository() : super(null);
  int calls = 0;

  @override
  Future<List<ProviderBusinessSummary>> getMyBusinesses() async {
    calls++;
    return const [
      ProviderBusinessSummary(
        id: 'business-1',
        name: 'Gasfitería Lago Ranco',
        businessType: BusinessType.service,
        publicationStatus: 'published',
      )
    ];
  }
}
