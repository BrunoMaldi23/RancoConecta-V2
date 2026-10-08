import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ranco_conecta_2/config/app_config.dart';
import 'package:ranco_conecta_2/core/result/result.dart';
import 'package:ranco_conecta_2/features/admin/application/admin_providers.dart';
import 'package:ranco_conecta_2/features/auth/application/auth_controller.dart';
import 'package:ranco_conecta_2/features/auth/data/supabase_auth_repository.dart';
import 'package:ranco_conecta_2/features/auth/domain/auth_user.dart';
import 'package:ranco_conecta_2/features/locations/application/location_providers.dart';
import 'package:ranco_conecta_2/features/messaging/application/messaging_providers.dart';
import 'package:ranco_conecta_2/features/notifications/application/notification_providers.dart';
import 'package:ranco_conecta_2/features/profile/application/profile_providers.dart';
import 'package:ranco_conecta_2/features/provider_dashboard/application/provider_dashboard_providers.dart';
import 'package:ranco_conecta_2/features/provider_dashboard/data/provider_business_repository.dart';
import 'package:ranco_conecta_2/router/ranco_navigation_drawer.dart';
import 'package:ranco_conecta_2/shared/models/business.dart';
import 'package:ranco_conecta_2/shared/models/location.dart';
import 'package:ranco_conecta_2/shared/models/profile.dart';

void main() {
  testWidgets('drawer guest shows only public destinations', (tester) async {
    await _pumpDrawer(tester, user: null);

    expect(find.text('Modo visitante'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Explorar'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.text('Solicitudes'), findsNothing);
    expect(find.text('Guardados'), findsNothing);
    expect(find.text('¿Ofreces un servicio?'), findsNothing);
  });

  testWidgets('drawer authenticated shows account identity', (tester) async {
    await _pumpDrawer(tester);

    expect(find.text('Bruno'), findsOneWidget);
    expect(find.text('bruno@example.com'), findsOneWidget);
  });

  testWidgets('anonymous visitor with profile sees personal destinations',
      (tester) async {
    await _pumpDrawer(
      tester,
      completeVisitorProfile: true,
      user: const AuthUser(
        id: 'visitor-1',
        email: null,
        emailConfirmed: false,
        isAnonymous: true,
      ),
    );

    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Explorar'), findsOneWidget);
    expect(find.text('Solicitudes'), findsOneWidget);
    expect(find.text('Guardados'), findsOneWidget);
    expect(find.text('Cuenta'), findsOneWidget);
    expect(find.text('¿Ofreces un servicio?'), findsNothing);
    expect(find.text('Mi negocio'), findsNothing);
    expect(find.text('Panel administrativo'), findsNothing);
    expect(find.text('Notificaciones'), findsOneWidget);
  });

  testWidgets('anonymous visitor without profile keeps public navigation',
      (tester) async {
    await _pumpDrawer(
      tester,
      user: const AuthUser(
        id: 'visitor-1',
        email: null,
        emailConfirmed: false,
        isAnonymous: true,
      ),
    );
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Explorar'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.text('Solicitudes'), findsNothing);
    expect(find.text('Cuenta'), findsNothing);
  });

  testWidgets('provider without business sees publish action', (tester) async {
    await _pumpDrawer(tester, role: ProfileRole.provider, businesses: const []);

    expect(find.text('¿Ofreces un servicio?'), findsOneWidget);
    expect(find.text('Publica en Ranco Conecta'), findsOneWidget);
  });

  testWidgets('draft business prompts continuing publication', (tester) async {
    await _pumpDrawer(tester,
        role: ProfileRole.provider, businesses: [_business('draft')]);

    expect(find.text('Continuar publicación'), findsOneWidget);
  });

  testWidgets('pending review business shows review state', (tester) async {
    await _pumpDrawer(tester,
        role: ProfileRole.provider, businesses: [_business('pending_review')]);

    expect(find.text('Negocio en revisión'), findsOneWidget);
  });

  testWidgets('changes requested business prompts correction', (tester) async {
    await _pumpDrawer(tester,
        role: ProfileRole.provider,
        businesses: [_business('changes_requested')]);

    expect(find.text('Corregir publicación'), findsOneWidget);
  });

  testWidgets('published business shows active business name', (tester) async {
    await _pumpDrawer(tester,
        role: ProfileRole.provider, businesses: [_business('published')]);

    expect(find.text('Servicios Ranco'), findsOneWidget);
  });

  testWidgets('suspended business shows suspended state', (tester) async {
    await _pumpDrawer(tester,
        role: ProfileRole.provider, businesses: [_business('suspended')]);

    expect(find.text('Negocio suspendido'), findsOneWidget);
  });

  testWidgets('admin role sees administration section', (tester) async {
    await _pumpDrawer(tester, role: ProfileRole.superAdmin);

    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pumpAndSettle();

    expect(find.text('ADMINISTRACIÓN'), findsOneWidget);
    expect(find.text('Panel administrativo'), findsOneWidget);
    expect(find.text('¿Ofreces un servicio?'), findsNothing);
  });

  testWidgets('admin with historical ownership only sees admin destination',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpDrawer(
      tester,
      role: ProfileRole.superAdmin,
      businesses: [_business('published')],
    );

    expect(find.text('MI NEGOCIO'), findsNothing);
    expect(find.text('Servicios Ranco'), findsNothing);
    expect(find.text('Panel administrativo'), findsOneWidget);
  });

  testWidgets('chat option is hidden when CHAT_ENABLED is off', (tester) async {
    await _pumpDrawer(tester, chatEnabled: false);

    expect(find.text('Mensajes'), findsNothing);
  });

  testWidgets('chat option is shown when CHAT_ENABLED is on', (tester) async {
    await _pumpDrawer(tester, chatEnabled: true);

    expect(find.text('Mensajes'), findsOneWidget);
  });

  testWidgets('messages unread badge is rendered', (tester) async {
    await _pumpDrawer(tester, chatEnabled: true, unreadMessages: 7);

    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('notifications unread badge is rendered', (tester) async {
    await _pumpDrawer(tester, unreadNotifications: 5);

    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('active route keeps route item visible', (tester) async {
    await _pumpDrawer(tester, initialLocation: '/messages', chatEnabled: true);

    expect(find.text('Mensajes'), findsOneWidget);
  });

  testWidgets('provider CTA is hidden when business exists', (tester) async {
    await _pumpDrawer(tester,
        role: ProfileRole.provider, businesses: [_business('published')]);

    expect(find.text('¿Ofreces un servicio?'), findsNothing);
  });

  testWidgets('logout is visible for authenticated users', (tester) async {
    await _pumpDrawer(tester);

    expect(find.text('Cerrar sesión'), findsOneWidget);
  });

  testWidgets('logout ends at sign-in and clears the drawer', (tester) async {
    await _pumpDrawer(tester);

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Ruta /sign-in'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsNothing);
  });

  testWidgets('provider logout clears selected active business',
      (tester) async {
    await _pumpDrawer(
      tester,
      role: ProfileRole.provider,
      businesses: [_business('published')],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.text('Cerrar sesión')),
    );
    container.read(activeProviderBusinessIdProvider.notifier).state =
        'business-published';

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(container.read(activeProviderBusinessIdProvider), isNull);
    expect(find.text('Ruta /sign-in'), findsOneWidget);
  });

  testWidgets('drawer has no overflow at 360px', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpDrawer(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('drawer closes with the close button', (tester) async {
    await _pumpDrawer(tester);

    expect(find.text('Inicio'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar menú'));
    await tester.pumpAndSettle();

    expect(find.text('Inicio'), findsNothing);
  });
}

Future<void> _pumpDrawer(
  WidgetTester tester, {
  AuthUser? user = const AuthUser(
    id: 'user-1',
    email: 'bruno@example.com',
    emailConfirmed: true,
  ),
  ProfileRole role = ProfileRole.customer,
  bool completeVisitorProfile = false,
  List<ProviderBusinessSummary>? businesses,
  bool chatEnabled = true,
  int unreadMessages = 0,
  int unreadNotifications = 0,
  String initialLocation = '/',
}) async {
  final profile = Profile(
    id: user?.id ?? 'user-1',
    fullName: user == null ? null : 'Bruno',
    phone: completeVisitorProfile ? '+56 9 1234 5678' : null,
    avatarUrl: null,
    role: role,
    accountStatus: 'active',
  );
  final businessItems = businesses ?? const <ProviderBusinessSummary>[];
  final activeBusiness = businessItems.isEmpty ? null : businessItems.first;
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      for (final route in [
        '/',
        '/explore',
        '/saved',
        '/requests',
        '/messages',
        '/notifications',
        '/provider/join',
        '/provider/register',
        '/provider/status',
        '/provider/dashboard',
        '/provider/business',
        '/admin',
        '/account',
        '/sign-in',
      ])
        GoRoute(
          path: route,
          builder: (context, state) => Scaffold(
            drawer: const RancoNavigationDrawer(),
            body: Builder(
              builder: (context) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Ruta ${state.uri.path}'),
                    FilledButton(
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      child: const Text('Abrir menú'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig(
            environment: AppEnvironment.development,
            supabaseUrl: null,
            supabasePublishableKey: null,
            featureFlags: FeatureFlags(chatEnabled: chatEnabled),
          ),
        ),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository(user)),
        authStateProvider.overrideWith((ref) => Stream.value(user)),
        currentProfileProvider.overrideWith((ref) async => profile),
        currentAdminRoleProvider.overrideWith(
          (ref) async => role.canAccessAdmin ? role : null,
        ),
        myProviderBusinessesProvider.overrideWith((ref) async => businessItems),
        activeProviderBusinessProvider
            .overrideWith((ref) async => activeBusiness),
        myProviderBusinessProvider.overrideWith((ref) async => activeBusiness),
        locationsProvider.overrideWith(
          (ref) async => const [
            Location(
              id: 'location-1',
              communeId: 'commune-1',
              name: 'Lago Ranco',
              slug: 'lago-ranco',
            ),
          ],
        ),
        selectedLocationProvider.overrideWith((ref) => null),
        unreadMessagesCountProvider.overrideWith((ref) async => unreadMessages),
        unreadNotificationsCountProvider
            .overrideWith((ref) async => unreadNotifications),
        messagingRealtimeProvider.overrideWith((ref) {}),
        notificationsRealtimeProvider.overrideWith((ref) {}),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  await tester.pump();
  await tester.tap(find.text('Abrir menú'));
  await tester.pumpAndSettle();
}

ProviderBusinessSummary _business(String status) {
  return ProviderBusinessSummary(
    id: 'business-$status',
    name: 'Servicios Ranco',
    businessType: BusinessType.service,
    publicationStatus: status,
  );
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<Result<void>> registerProviderIdentity() async => const Success(null);
  const _FakeAuthRepository(this.user);

  final AuthUser? user;

  @override
  AuthUser? currentUser() => user;

  @override
  Stream<AuthUser?> observeAuthState() => Stream.value(user);

  @override
  Future<Result<void>> sendPasswordResetEmail(String email) async {
    return const Success(null);
  }

  @override
  Future<Result<void>> updateRecoveredPassword(String password) async {
    return const Success(null);
  }

  @override
  Future<Result<AuthUser>> signIn({
    required String email,
    required String password,
  }) async {
    return Success(user!);
  }

  @override
  Future<Result<AuthUser>> signInAnonymously() async => Success(user!);

  @override
  Future<Result<void>> signOut() async {
    return const Success(null);
  }

  @override
  Future<Result<AuthUser?>> signUp({
    required String fullName,
    required String email,
    required String password,
    bool consentAccepted = false,
    bool providerRegistration = false,
    String? emailRedirectPath,
  }) async {
    return Success(user);
  }
}
