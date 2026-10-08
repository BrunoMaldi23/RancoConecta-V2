import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ranco_conecta_2/config/app_config.dart';
import 'package:ranco_conecta_2/core/errors/app_failure.dart';
import 'package:ranco_conecta_2/core/result/result.dart';
import 'package:ranco_conecta_2/features/auth/application/auth_controller.dart';
import 'package:ranco_conecta_2/features/auth/data/supabase_auth_repository.dart';
import 'package:ranco_conecta_2/features/auth/data/visitor_profile_repository.dart';
import 'package:ranco_conecta_2/features/auth/domain/auth_user.dart';
import 'package:ranco_conecta_2/features/auth/presentation/access_screen.dart';
import 'package:ranco_conecta_2/features/auth/presentation/sign_in_screen.dart';
import 'package:ranco_conecta_2/features/auth/presentation/visitor_contact_validation.dart';
import 'package:ranco_conecta_2/features/locations/application/location_providers.dart';
import 'package:ranco_conecta_2/features/legal/data/consent_repository.dart';
import 'package:ranco_conecta_2/features/profile/application/profile_providers.dart';
import 'package:ranco_conecta_2/features/provider_dashboard/application/provider_context.dart';
import 'package:ranco_conecta_2/features/provider_dashboard/application/provider_context_state.dart';
import 'package:ranco_conecta_2/features/service_requests/application/service_request_providers.dart';
import 'package:ranco_conecta_2/features/service_requests/presentation/create_request_screen.dart';
import 'package:ranco_conecta_2/features/service_requests/presentation/provider_requests_screen.dart';
import 'package:ranco_conecta_2/shared/models/profile.dart';
import 'package:ranco_conecta_2/shared/models/quote.dart';
import 'package:ranco_conecta_2/router/app_router.dart';

void main() {
  testWidgets('recovery requires a session and rejects an expired link',
      (tester) async {
    final auth = _FakeAuthRepository();
    await _pumpFlow(tester, auth: auth, startRoute: '/reset-password');
    expect(find.text('El enlace caducó o ya fue utilizado.'), findsOneWidget);
    expect(find.text('Guardar contraseña'), findsNothing);
  });

  testWidgets('recovered password is confirmed and returns to provider login',
      (tester) async {
    final auth = _FakeAuthRepository()
      .._current = const AuthUser(
          id: 'provider-1',
          email: 'provider@example.com',
          emailConfirmed: true);
    await _pumpFlow(tester, auth: auth, startRoute: '/reset-password');
    await tester.enterText(find.byType(TextFormField).at(0), 'clave-segura');
    await tester.enterText(find.byType(TextFormField).at(1), 'otra-clave');
    await tester.tap(find.text('Guardar contraseña'));
    await tester.pump();
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), 'clave-segura');
    await tester.tap(find.text('Guardar contraseña'));
    await tester.pumpAndSettle();
    expect(auth.recoveredPassword, 'clave-segura');
    expect(find.text('Acceso proveedor'), findsOneWidget);
  });

  test('WhatsApp accepts Chilean mobile formats only', () {
    expect(isValidChileanWhatsapp('+56 9 1234 5678'), isTrue);
    expect(isValidChileanWhatsapp('912345678'), isTrue);
    expect(isValidChileanWhatsapp('56912345678'), isTrue);
    expect(isValidChileanWhatsapp('+56 8 1234 5678'), isFalse);
    expect(isValidChileanWhatsapp('+54 9 1234 5678'), isFalse);
    expect(isValidChileanWhatsapp('12345'), isFalse);
  });

  for (final width in [1366.0, 1024.0, 768.0, 390.0]) {
    testWidgets('access and provider login fit at ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final auth = _FakeAuthRepository();
      await _pumpFlow(tester, auth: auth);
      expect(find.text('Bienvenido a Ranco Conecta'), findsOneWidget);
      expect(find.text('Explorar Ranco'), findsWidgets);
      expect(find.text('Tengo un negocio'), findsWidgets);
      expect(tester.takeException(), isNull);

      await _tapVisible(tester,
          find.widgetWithText(OutlinedButton, 'Continuar como prestador'));
      await tester.pumpAndSettle();
      expect(find.text('Acceso proveedor'), findsOneWidget);
      expect(find.text('Gestiona tu negocio en Ranco.'), findsOneWidget);
      expect(find.text('Olvidé mi contraseña'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .maxScrollExtent,
          0);
      await tester.tap(find.widgetWithText(TextButton, 'Volver'));
      await tester.pumpAndSettle();
      expect(find.text('Explorar Ranco'), findsWidgets);
      await _tapVisible(tester,
          find.widgetWithText(OutlinedButton, 'Continuar como prestador'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextFormField).at(0), 'provider@example.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'clave-segura');
      await _tapVisible(tester, find.widgetWithText(FilledButton, 'Ingresar'));
      await tester.pumpAndSettle();
      expect(find.text('Cuenta UI'), findsOneWidget);
    });
  }

  testWidgets('provider login waits for the new profile before navigation',
      (tester) async {
    final gate = Completer<void>();
    await _pumpFlow(tester, auth: _FakeAuthRepository(), profileGate: gate);
    await _tapVisible(tester,
        find.widgetWithText(OutlinedButton, 'Continuar como prestador'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).at(0), 'provider@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'clave-segura');
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Ingresar'));
    await tester.pump();
    expect(find.text('Cuenta UI'), findsNothing);
    expect(find.text('Acceso proveedor'), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Cuenta UI'), findsOneWidget);
  });

  testWidgets('provider signup retains its email return route', (tester) async {
    final auth = _FakeAuthRepository();
    await _pumpFlow(tester, auth: auth);
    await _tapVisible(tester,
        find.widgetWithText(OutlinedButton, 'Continuar como prestador'));
    await tester.pumpAndSettle();
    await _tapVisible(tester,
        find.widgetWithText(OutlinedButton, 'Ser parte de Ranco Conecta'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('Crear mi acceso'));
    await tester.pumpAndSettle();
    expect(find.text('Crea tu acceso'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Proveedor Prueba');
    await tester.enterText(fields.at(1), 'provider@example.com');
    await tester.enterText(fields.at(2), 'clave-segura');
    await tester.enterText(fields.at(3), 'clave-segura');
    for (final checkbox in tester.widgetList<Checkbox>(find.byType(Checkbox))) {
      checkbox.onChanged!(true);
    }
    await tester.pump();
    await _tapVisible(
        tester, find.widgetWithText(FilledButton, 'Crear acceso'));
    await tester.pumpAndSettle();
    expect(auth.lastEmailRedirectPath, '/account');
    expect(auth.lastProviderRegistration, isTrue);
    expect(find.text('Revisa tu correo para continuar'), findsOneWidget);
  });

  testWidgets('welcome offers direct public access without a profile',
      (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final auth = _FakeAuthRepository();
    final visitor = _FakeVisitorProfileRepository();
    await _pumpFlow(tester, auth: auth, visitor: visitor);

    expect(find.text('Explorar Ranco'), findsWidgets);
    expect(
        find.text(
            'Descubre alojamientos, gastronomía, servicios y experiencias sin crear una cuenta.'),
        findsOneWidget);
    expect(find.text('Tengo un negocio'), findsWidgets);
    expect(find.text('Publica tus servicios y conecta con visitantes.'),
        findsOneWidget);
    await _tapVisible(
        tester, find.widgetWithText(FilledButton, 'Empezar a explorar'));
    await tester.pumpAndSettle();

    expect(find.text('Home público'), findsOneWidget);
    expect(auth.anonymousCalls, 0);
    expect(visitor.calls, 0);
    expect(tester.takeException(), isNull);
  });

  for (final next in [
    '/business/business-1/table-reservation',
    '/business/business-1/availability',
  ]) {
    testWidgets('visitor opens pending $next without a profile',
        (tester) async {
      await _pumpFlow(tester, auth: _FakeAuthRepository(), nextRoute: next);
      await tester.tap(find.widgetWithText(FilledButton, 'Empezar a explorar'));
      await tester.pumpAndSettle();
      expect(
          find.text(next.endsWith('availability')
              ? 'Disponibilidad UI'
              : 'Reserva de mesa UI'),
          findsOneWidget);
      expect(find.text('Crea tu perfil visitante'), findsNothing);
    });
  }

  testWidgets('visitor session starts only after valid contact details',
      (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final auth = _FakeAuthRepository();
    final visitor = _FakeVisitorProfileRepository();
    await _pumpFlow(tester, auth: auth, visitor: visitor, startInProfile: true);
    expect(auth.anonymousCalls, 0);
    expect(find.text('Crea tu perfil visitante'), findsOneWidget);

    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa tu nombre completo.'), findsOneWidget);
    expect(auth.anonymousCalls, 0);

    await tester.enterText(find.byType(TextFormField).at(0), 'Juan Pérez');
    await tester.enterText(find.byType(TextFormField).at(1), '+56 9 1234 5678');
    await _acceptConsent(tester);
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();
    expect(auth.anonymousCalls, 1);
    expect(visitor.savedName, 'Juan Pérez');
    expect(visitor.savedPhone, '+56 9 1234 5678');
    expect(find.text('Explorar UI'), findsOneWidget);
    expect(find.text('Perfil creado correctamente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visitor form remains usable with a mobile keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });
    await _pumpFlow(tester, auth: _FakeAuthRepository(), startInProfile: true);

    await tester.tap(find.byType(TextFormField).at(1));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuar'));
    expect(find.text('Continuar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('provider request shows visitor contact and date',
      (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const ProviderRequestsScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        providerRequestQueueProvider.overrideWith((ref) async => [
              ProviderRequestItem(
                requestId: 'request-1',
                publicCode: 'RC-2026-000001',
                businessId: 'business-1',
                subcategoryId: 'service-1',
                subcategoryName: 'Electricidad',
                locationId: null,
                locationName: null,
                description: 'Necesito revisar el tablero eléctrico.',
                addressText: null,
                urgency: 'normal',
                desiredDate: null,
                requestStatus: 'submitted',
                attachmentCount: 0,
                quoteId: null,
                quoteStatus: null,
                quoteTotal: null,
                operationId: null,
                operationStatus: null,
                createdAt: DateTime(2026, 9, 30),
                guestName: 'Juan Pérez',
                guestPhone: '+56 9 1234 5678',
              ),
            ]),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Cliente: Juan Pérez'), findsOneWidget);
    expect(find.text('+56 9 1234 5678'), findsOneWidget);
    expect(find.text('Solicitud: 30/09/2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('visitor profile error offers retry and preserves entered data',
      (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final visitor = _FakeVisitorProfileRepository()..failFirst = true;
    await _pumpFlow(tester,
        auth: _FakeAuthRepository(), visitor: visitor, startInProfile: true);
    await tester.enterText(find.byType(TextFormField).at(0), 'Juan Pérez');
    await tester.enterText(find.byType(TextFormField).at(1), '+56 9 1234 5678');
    await _acceptConsent(tester);
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos crear tu perfil. Intenta nuevamente.'),
        findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    await _tapVisible(tester, find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(visitor.calls, 2);
    expect(visitor.savedName, 'Juan Pérez');
    expect(find.text('Explorar UI'), findsOneWidget);
  });

  testWidgets('provider choice lands in account despite a pending wizard route',
      (tester) async {
    await _pumpFlow(tester,
        auth: _FakeAuthRepository(), nextRoute: '/provider/register');
    await _tapVisible(tester,
        find.widgetWithText(OutlinedButton, 'Continuar como prestador'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).at(0), 'provider@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'clave-segura');
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Ingresar'));
    await tester.pumpAndSettle();
    expect(find.text('Cuenta UI'), findsOneWidget);
  });

  testWidgets('visitor opens a pending request without a session',
      (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final auth = _FakeAuthRepository();
    final visitor = _FakeVisitorProfileRepository();
    await _pumpFlow(tester,
        auth: auth,
        visitor: visitor,
        nextRoute: '/business/business-1/request');

    await tester.tap(find.widgetWithText(FilledButton, 'Empezar a explorar'));
    await tester.pumpAndSettle();
    expect(auth.anonymousCalls, 0);
    expect(find.byType(CreateRequestScreen), findsOneWidget);
    expect(auth.currentUser(), isNull);
    expect(visitor.calls, 0);
    expect(find.text('Crea tu perfil visitante'), findsNothing);
  });

  testWidgets('continuing as guest closes an existing anonymous session',
      (tester) async {
    final auth = _FakeAuthRepository();
    final visitor = _FakeVisitorProfileRepository();
    await auth.signInAnonymously();
    await _pumpFlow(tester, auth: auth, visitor: visitor, startInProfile: true);
    expect(find.text('Crea tu perfil visitante'), findsOneWidget);
    await _tapVisible(tester, find.text('Explorar primero'));
    await tester.pumpAndSettle();

    expect(find.text('Home público'), findsOneWidget);
    expect(auth.currentUser(), isNull);
    expect(auth.anonymousCalls, 1);
    expect(visitor.calls, 0);
  });

  testWidgets('visitor form rejects an invalid Chilean WhatsApp',
      (tester) async {
    await _pumpFlow(tester, auth: _FakeAuthRepository(), startInProfile: true);
    await tester.enterText(find.byType(TextFormField).at(0), 'Juan Pérez');
    await tester.enterText(find.byType(TextFormField).at(1), '+56 8 1234 5678');
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa un WhatsApp chileno: +56 9 XXXX XXXX.'),
        findsOneWidget);
  });

  testWidgets('request form remains visible before visitor contact details',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/business/business-1/request',
      routes: [
        GoRoute(
            path: '/business/:id/request',
            builder: (_, state) =>
                CreateRequestScreen(businessId: state.pathParameters['id']!)),
        GoRoute(
            path: '/business/:id/table-reservation',
            builder: (_, __) =>
                const Scaffold(body: Text('Reserva de mesa UI'))),
        GoRoute(
            path: '/business/:id/availability',
            builder: (_, __) =>
                const Scaffold(body: Text('Disponibilidad UI'))),
        GoRoute(
            path: '/visitor/profile',
            builder: (_, state) => Scaffold(
                body: Text('Perfil ${state.uri.queryParameters['next']}'))),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(
              id: 'visitor-1',
              email: null,
              emailConfirmed: false,
              isAnonymous: true,
            ))),
        currentProfileProvider.overrideWith((ref) async => const Profile(
              id: 'visitor-1',
              fullName: 'Juan Pérez',
              phone: '+56 8 1234 5678',
              avatarUrl: null,
              role: ProfileRole.customer,
              accountStatus: 'active',
            )),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(CreateRequestScreen), findsOneWidget);
    expect(find.text('Completar perfil'), findsNothing);
  });

  testWidgets('guest form opens without reading or creating a profile',
      (tester) async {
    final profileGate = Completer<void>();
    final auth = _FakeAuthRepository();
    await _pumpFlow(tester,
        auth: auth, profileGate: profileGate, startInProfile: true);
    expect(find.text('Crea tu perfil visitante'), findsOneWidget);
    expect(auth.anonymousCalls, 0);
    profileGate.complete();
  });

  testWidgets('real router returns from visitor form to access choices',
      (tester) async {
    final auth = _FakeAuthRepository();
    final visitor = _FakeVisitorProfileRepository();
    final container = ProviderContainer(overrides: [
      appConfigProvider.overrideWithValue(const AppConfig(
        environment: AppEnvironment.production,
        supabaseUrl: null,
        supabasePublishableKey: null,
      )),
      authRepositoryProvider.overrideWithValue(auth),
      visitorProfileRepositoryProvider.overrideWithValue(visitor),
      currentProfileProvider.overrideWith((ref) async => Profile(
            id: 'visitor-1',
            fullName: visitor.savedName,
            phone: visitor.savedPhone,
            avatarUrl: null,
            role: ProfileRole.customer,
            accountStatus: 'active',
          )),
      providerContextProvider.overrideWith((ref) async =>
          const ProviderContextState(
              status: ProviderContextStatus.unauthenticated)),
      locationsProvider.overrideWith((ref) async => []),
    ]);
    addTearDown(() {
      container.dispose();
      auth.dispose();
    });
    final router = container.read(appRouterProvider);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Empezar a explorar'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(auth.anonymousCalls, 0);
    router.go('/sign-in?next=%2Fbusiness%2Fbusiness-1%2Frequest');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Empezar a explorar'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path,
        '/business/business-1/request');
    expect(find.text('Crea tu perfil visitante'), findsNothing);
    router.go('/sign-in');
    await tester.pumpAndSettle();
    await _tapVisible(tester,
        find.widgetWithText(OutlinedButton, 'Continuar como prestador'));
    await tester.pumpAndSettle();
    expect(find.text('Acceso proveedor'), findsOneWidget);
    expect(auth.currentUser(), isNull);
    expect(auth.anonymousCalls, 0);
    expect(visitor.calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving waits for confirmed visitor contact before exploring',
      (tester) async {
    final confirmation = Completer<void>();
    await _pumpFlow(tester,
        auth: _FakeAuthRepository(),
        savedProfileGate: confirmation,
        startInProfile: true);
    await tester.enterText(find.byType(TextFormField).at(0), 'Juan Pérez');
    await tester.enterText(find.byType(TextFormField).at(1), '+56 9 1234 5678');
    await _acceptConsent(tester);
    await _tapVisible(tester, find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pump();

    expect(find.text('Explorar UI'), findsNothing);
    expect(find.text('Guardando...'), findsOneWidget);
    confirmation.complete();
    await tester.pumpAndSettle();
    expect(find.text('Explorar UI'), findsOneWidget);
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> _acceptConsent(WidgetTester tester) async {
  for (var index = 0; index < 3; index++) {
    // La fila incluye el enlace "Ver ..."; se marca la casilla en sí.
    await _tapVisible(
        tester,
        find.descendant(
            of: find.byType(CheckboxListTile).at(index),
            matching: find.byType(Checkbox)));
    await tester.pumpAndSettle();
  }
}

Future<void> _pumpFlow(WidgetTester tester,
    {required _FakeAuthRepository auth,
    String? startRoute,
    _FakeVisitorProfileRepository? visitor,
    String? nextRoute,
    bool startInProfile = false,
    Completer<void>? profileGate,
    Completer<void>? savedProfileGate}) async {
  final router = GoRouter(
      initialLocation:
          startRoute ?? (startInProfile ? '/visitor/profile' : '/sign-in'),
      routes: [
        GoRoute(
            path: '/',
            builder: (context, __) => Scaffold(
                  body: Column(children: [
                    const Text('Home público'),
                    TextButton(
                        onPressed: () => context.go('/explore'),
                        child: const Text('Abrir catálogo')),
                  ]),
                )),
        GoRoute(
            path: '/sign-in',
            builder: (_, __) => AccessScreen(nextRoute: nextRoute)),
        GoRoute(
            path: '/provider/sign-in',
            builder: (_, state) => SignInScreen(
                providerAccess: true,
                nextRoute: state.uri.queryParameters['next'])),
        GoRoute(
            path: '/reset-password',
            builder: (_, __) => const ResetPasswordScreen()),
        GoRoute(
            path: '/forgot-password',
            builder: (_, __) => const ForgotPasswordScreen()),
        GoRoute(
            path: '/visitor/profile',
            builder: (_, state) => VisitorProfileScreen(
                nextRoute: state.uri.queryParameters['next'])),
        GoRoute(
            path: '/explore',
            builder: (context, __) => Scaffold(
                  body: Column(children: [
                    const Text('Explorar UI'),
                    TextButton(
                        onPressed: () =>
                            context.go('/business/business-1/request'),
                        child: const Text('Solicitar prueba')),
                  ]),
                )),
        GoRoute(
            path: '/business/:id/request',
            builder: (_, state) =>
                CreateRequestScreen(businessId: state.pathParameters['id']!)),
        GoRoute(
            path: '/business/:id/table-reservation',
            builder: (_, __) =>
                const Scaffold(body: Text('Reserva de mesa UI'))),
        GoRoute(
            path: '/business/:id/availability',
            builder: (_, __) =>
                const Scaffold(body: Text('Disponibilidad UI'))),
        GoRoute(
            path: '/account',
            builder: (_, __) => const Scaffold(body: Text('Cuenta UI'))),
        GoRoute(
            path: '/provider/dashboard',
            builder: (_, __) =>
                const Scaffold(body: Text('Panel prestador UI'))),
        GoRoute(
            path: '/provider/join',
            builder: (_, __) => const ProviderJoinScreen()),
        GoRoute(
            path: '/sign-up',
            builder: (_, state) =>
                SignUpScreen(nextRoute: state.uri.queryParameters['next'])),
        GoRoute(
            path: '/provider/register',
            builder: (_, __) =>
                const Scaffold(body: Text('Registro proveedor UI'))),
      ]);
  addTearDown(router.dispose);
  addTearDown(auth.dispose);
  final visitorRepository = visitor ?? _FakeVisitorProfileRepository();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(const AppConfig(
        environment: AppEnvironment.production,
        supabaseUrl: null,
        supabasePublishableKey: null,
      )),
      authRepositoryProvider.overrideWithValue(auth),
      visitorProfileRepositoryProvider.overrideWithValue(visitorRepository),
      consentRepositoryProvider.overrideWithValue(_FakeConsentRepository()),
      currentProfileProvider.overrideWith((ref) async {
        if (profileGate != null) await profileGate.future;
        if (visitorRepository.savedName != null && savedProfileGate != null) {
          await savedProfileGate.future;
        }
        return Profile(
          id: 'visitor-1',
          fullName: visitorRepository.savedName,
          phone: visitorRepository.savedPhone,
          avatarUrl: null,
          role: ProfileRole.customer,
          accountStatus: 'active',
        );
      }),
      locationsProvider.overrideWith((ref) async => []),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

class _FakeAuthRepository implements AuthRepository {
  int anonymousCalls = 0;
  String? lastEmailRedirectPath;
  bool? lastProviderRegistration;
  String? recoveredPassword;

  @override
  Future<Result<void>> registerProviderIdentity() async => const Success(null);
  final _changes = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;

  void dispose() => _changes.close();

  @override
  AuthUser? currentUser() => _current;

  @override
  Stream<AuthUser?> observeAuthState() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<Result<AuthUser>> signInAnonymously() async {
    anonymousCalls++;
    _current = const AuthUser(
      id: 'visitor-1',
      email: null,
      emailConfirmed: false,
      isAnonymous: true,
    );
    _changes.add(_current);
    return Success(_current!);
  }

  @override
  Future<Result<AuthUser>> signIn(
      {required String email, required String password}) async {
    _current = const AuthUser(
        id: 'provider-1', email: 'provider@example.com', emailConfirmed: true);
    _changes.add(_current);
    return Success(_current!);
  }

  @override
  Future<Result<AuthUser?>> signUp(
      {required String fullName,
      required String email,
      required String password,
      bool consentAccepted = false,
      bool providerRegistration = false,
      String? emailRedirectPath}) async {
    lastEmailRedirectPath = emailRedirectPath;
    lastProviderRegistration = providerRegistration;
    return const Success(null);
  }

  @override
  Future<Result<void>> sendPasswordResetEmail(String email) async =>
      const Success(null);

  @override
  Future<Result<void>> updateRecoveredPassword(String password) async {
    recoveredPassword = password;
    return const Success(null);
  }

  @override
  Future<Result<void>> signOut() async {
    _current = null;
    _changes.add(null);
    return const Success(null);
  }
}

class _FakeConsentRepository extends ConsentRepository {
  _FakeConsentRepository() : super(null);

  @override
  Future<void> record({required String context}) async {}
}

class _FakeVisitorProfileRepository extends VisitorProfileRepository {
  _FakeVisitorProfileRepository() : super(null);

  String? savedName;
  String? savedPhone;
  bool failFirst = false;
  int calls = 0;

  @override
  Future<Result<void>> save({
    required String fullName,
    required String phone,
    String? email,
    String? locationId,
  }) async {
    calls++;
    if (failFirst && calls == 1) {
      return const Failure(
          AppFailure(type: AppFailureType.network, message: 'Sin conexión.'));
    }
    savedName = fullName;
    savedPhone = phone;
    return const Success(null);
  }
}
