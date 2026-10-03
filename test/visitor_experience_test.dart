import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ranco_conecta_2/config/app_config.dart';
import 'package:ranco_conecta_2/features/auth/application/auth_controller.dart';
import 'package:ranco_conecta_2/features/auth/domain/auth_user.dart';
import 'package:ranco_conecta_2/features/businesses/application/business_providers.dart';
import 'package:ranco_conecta_2/features/locations/application/location_providers.dart';
import 'package:ranco_conecta_2/features/profile/application/profile_providers.dart';
import 'package:ranco_conecta_2/features/profile/presentation/account_screen.dart';
import 'package:ranco_conecta_2/features/service_requests/application/service_request_providers.dart';
import 'package:ranco_conecta_2/features/service_requests/domain/customer_activity_item.dart';
import 'package:ranco_conecta_2/features/service_requests/presentation/create_request_screen.dart';
import 'package:ranco_conecta_2/features/service_requests/presentation/requests_screen.dart';
import 'package:ranco_conecta_2/shared/models/location.dart';
import 'package:ranco_conecta_2/shared/models/business.dart';
import 'package:ranco_conecta_2/shared/models/category.dart';
import 'package:ranco_conecta_2/shared/models/profile.dart';
import 'package:ranco_conecta_2/shared/models/service_request.dart';
import 'package:ranco_conecta_2/shared/models/service_request_status.dart';

const _visitor = AuthUser(
  id: 'visitor-1',
  email: null,
  emailConfirmed: false,
  isAnonymous: true,
);

const _location = Location(
  id: 'location-1',
  communeId: 'commune-1',
  name: 'Lago Ranco',
  slug: 'lago-ranco',
);

void main() {
  for (final width in [1366.0, 1024.0, 768.0, 390.0]) {
    testWidgets('visitor profile fits at ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(initialLocation: '/account', routes: [
        GoRoute(path: '/account', builder: (_, __) => const AccountScreen()),
        GoRoute(
            path: '/visitor/profile',
            builder: (_, __) => const Scaffold(body: Text('Editar UI'))),
        GoRoute(
            path: '/requests',
            builder: (_, __) => const Scaffold(body: Text('Solicitudes UI'))),
      ]);
      addTearDown(router.dispose);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(const AppConfig(
            environment: AppEnvironment.production,
            supabaseUrl: null,
            supabasePublishableKey: null,
          )),
          authStateProvider.overrideWith((ref) => Stream.value(_visitor)),
          currentProfileProvider.overrideWith((ref) async => const Profile(
                id: 'visitor-1',
                fullName: 'Juan Pérez',
                phone: '+56 9 1234 5678',
                avatarUrl: null,
                role: ProfileRole.customer,
                accountStatus: 'active',
              )),
          locationsProvider.overrideWith((ref) async => [_location]),
          selectedLocationProvider.overrideWith((ref) => _location),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Mi perfil'), findsOneWidget);
      expect(find.text('Juan Pérez'), findsOneWidget);
      expect(find.text('+56 9 1234 5678'), findsOneWidget);
      expect(find.text('Lago Ranco'), findsOneWidget);
      expect(find.text('Editar datos'), findsOneWidget);
      expect(find.text('Mis solicitudes'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(find.text('Mi negocio'), findsNothing);
      expect(find.text('Panel administrativo'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(
          tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position
              .maxScrollExtent,
          0);

      await tester.tap(find.text('Editar datos'));
      await tester.pumpAndSettle();
      expect(find.text('Editar UI'), findsOneWidget);

      router.go('/account');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mis solicitudes'));
      await tester.pumpAndSettle();
      expect(find.text('Solicitudes UI'), findsOneWidget);
    });
  }

  testWidgets(
      'visitor requests show business, date, message, and clear statuses',
      (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = GoRouter(initialLocation: '/requests', routes: [
      GoRoute(path: '/requests', builder: (_, __) => const RequestsScreen()),
      GoRoute(
          path: '/requests/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Detalle ${state.pathParameters['id']}'))),
      GoRoute(
          path: '/explore',
          builder: (_, __) => const Scaffold(body: Text('Explorar UI'))),
    ]);
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(_visitor)),
        myCustomerActivityProvider.overrideWith((ref) async => [
              _request('1', ServiceRequestStatus.submitted, 'Cabañas Ranco'),
              _request('2', ServiceRequestStatus.quoted, 'Servicios Ranco'),
              _request('3', ServiceRequestStatus.completed, 'Taller Ranco'),
              _request('4', ServiceRequestStatus.accepted, 'Hotel Ranco'),
              _request('5', ServiceRequestStatus.rejected, 'Cocina Ranco'),
            ].map(CustomerActivityItem.fromService).toList()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mis solicitudes'), findsOneWidget);
    expect(find.text('Pendiente · 1'), findsOneWidget);
    expect(find.text('Aceptada · 1'), findsOneWidget);
    expect(find.text('Rechazada · 1'), findsOneWidget);
    expect(find.text('Finalizada · 1'), findsOneWidget);
    expect(find.text('Otros estados · 1'), findsOneWidget);
    expect(find.text('Cabañas Ranco'), findsOneWidget);
    expect(find.text('Alojamiento · 30/09/2026'), findsWidgets);
    expect(find.text('Necesito alojamiento para 4 personas.'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('Taller Ranco'), 220);
    expect(find.text('Taller Ranco'), findsOneWidget);
    expect(find.text('Finalizada'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(find.text('Cabañas Ranco'), -220);
    await tester.tap(find.text('Cabañas Ranco'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle 1'), findsOneWidget);
  });

  testWidgets('visitor contact gate keeps the selected service and message',
      (tester) async {
    final profileState = StateProvider<Profile>((ref) => const Profile(
          id: 'visitor-1',
          fullName: 'Juan Pérez',
          phone: '+56 9 1234 5678',
          avatarUrl: null,
          role: ProfileRole.customer,
          accountStatus: 'active',
        ));
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(_visitor)),
      currentProfileProvider
          .overrideWith((ref) async => ref.watch(profileState)),
      businessDetailProvider.overrideWith((ref, id) async => _business),
      locationsProvider.overrideWith((ref) async => [_location]),
    ]);
    addTearDown(container.dispose);
    final router =
        GoRouter(initialLocation: '/business/business-1/request', routes: [
      GoRoute(
          path: '/business/:id/request',
          builder: (_, state) =>
              CreateRequestScreen(businessId: state.pathParameters['id']!)),
      GoRoute(
          path: '/visitor/profile',
          builder: (_, __) =>
              const Scaffold(body: Text('Perfil visitante UI'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Electricidad').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Describe lo que necesitas'),
        'Necesito revisar el tablero eléctrico.');

    container.read(profileState.notifier).state = const Profile(
      id: 'visitor-1',
      fullName: 'Juan Pérez',
      phone: null,
      avatarUrl: null,
      role: ProfileRole.customer,
      accountStatus: 'active',
    );
    await tester.pumpAndSettle();
    expect(find.byType(CreateRequestScreen), findsOneWidget);
    expect(find.text('Servicios Ranco'), findsOneWidget);

    container.read(profileState.notifier).state = const Profile(
      id: 'visitor-1',
      fullName: 'Juan Pérez',
      phone: '+56 9 1234 5678',
      avatarUrl: null,
      role: ProfileRole.customer,
      accountStatus: 'active',
    );
    await tester.pumpAndSettle();
    expect(find.text('Necesito revisar el tablero eléctrico.'), findsOneWidget);
    expect(
        tester
            .widget<DropdownButtonFormField<String>>(
                find.byType(DropdownButtonFormField<String>).first)
            .initialValue,
        'service-1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('sent request confirms business, date, status and follow-up',
      (tester) async {
    await initializeDateFormatting('es');
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = GoRouter(initialLocation: '/requests/1?sent=1', routes: [
      GoRoute(
          path: '/requests/:id',
          builder: (_, state) => RequestDetailScreen(
                requestId: state.pathParameters['id']!,
                justSent: state.uri.queryParameters['sent'] == '1',
                attachmentsFailed:
                    state.uri.queryParameters['attachments'] == 'failed',
              )),
      GoRoute(
          path: '/requests',
          builder: (_, __) => const Scaffold(body: Text('Mis solicitudes UI'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig(
          environment: AppEnvironment.production,
          supabaseUrl: null,
          supabasePublishableKey: null,
        )),
        requestDetailProvider.overrideWith((ref, id) async =>
            _request(id, ServiceRequestStatus.submitted, 'Cabañas Ranco')),
        requestQuotesProvider.overrideWith((ref, id) async => []),
        requestAttachmentsProvider.overrideWith((ref, id) async => []),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Solicitud enviada'), findsWidgets);
    expect(find.text('Cabañas Ranco'), findsWidgets);
    expect(find.text('Fecha: 30/09/2026'), findsOneWidget);
    expect(find.text('Estado: Pendiente de respuesta'), findsOneWidget);
    expect(tester.takeException(), isNull);
    router.go('/requests/1?sent=1&attachments=failed');
    await tester.pumpAndSettle();
    expect(
        find.text(
            'La solicitud se envió, pero no pudimos adjuntar algunos archivos.'),
        findsOneWidget);
    await tester.tap(find.text('Ver mis solicitudes'));
    await tester.pumpAndSettle();
    expect(find.text('Mis solicitudes UI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _business = Business(
  id: 'business-1',
  ownerId: 'provider-1',
  type: BusinessType.service,
  name: 'Servicios Ranco',
  slug: 'servicios-ranco',
  description: null,
  phone: null,
  whatsapp: null,
  email: null,
  website: null,
  addressText: null,
  verificationStatus: 'verified',
  isFeatured: false,
  acceptsRequests: true,
  ratingAvg: 0,
  reviewCount: 0,
  services: [
    BusinessService(
      subcategory: Subcategory(
        id: 'service-1',
        categoryId: 'category-1',
        name: 'Electricidad',
        slug: 'electricidad',
        description: null,
        iconKey: 'bolt',
      ),
      description: null,
      priceFrom: null,
    ),
  ],
  coverage: [_location],
  hours: [],
  media: [],
);

ServiceRequest _request(
    String id, ServiceRequestStatus status, String businessName) {
  return ServiceRequest(
    id: id,
    publicCode: 'RC-2026-$id',
    businessId: 'business-$id',
    businessName: businessName,
    categoryId: 'category-1',
    categoryName: 'Alojamiento',
    subcategoryId: 'service-1',
    subcategoryName: 'Alojamiento',
    locationId: 'location-1',
    locationName: 'Lago Ranco',
    description: 'Necesito alojamiento para 4 personas.',
    addressText: null,
    urgency: RequestUrgency.normal,
    desiredDate: null,
    status: status,
    createdAt: DateTime(2026, 9, 30),
  );
}
