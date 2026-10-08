import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ranco_conecta_2/config/app_config.dart';
import 'package:ranco_conecta_2/core/widgets/ranco_error_state.dart';
import 'package:ranco_conecta_2/core/widgets/ranco_site_footer.dart';
import 'package:ranco_conecta_2/features/admin/application/admin_providers.dart';
import 'package:ranco_conecta_2/features/notifications/application/notification_providers.dart';
import 'package:ranco_conecta_2/features/notifications/presentation/notifications_screen.dart';
import 'package:ranco_conecta_2/features/provider_dashboard/application/provider_dashboard_providers.dart';
import 'package:ranco_conecta_2/features/provider_dashboard/data/provider_business_repository.dart';
import 'package:ranco_conecta_2/features/provider_dashboard/presentation/provider_dashboard_screen.dart';
import 'package:ranco_conecta_2/features/provider_dashboard/presentation/provider_hub.dart';
import 'package:ranco_conecta_2/features/provider_registration/application/business_onboarding_providers.dart';
import 'package:ranco_conecta_2/features/provider_registration/data/business_onboarding_repository.dart';
import 'package:ranco_conecta_2/features/provider_registration/presentation/provider_business_status_screen.dart';
import 'package:ranco_conecta_2/features/provider_registration/presentation/provider_registration_screen.dart';
import 'package:ranco_conecta_2/features/service_requests/application/service_request_providers.dart';
import 'package:ranco_conecta_2/features/auth/application/auth_controller.dart';
import 'package:ranco_conecta_2/features/auth/data/supabase_auth_repository.dart';
import 'package:ranco_conecta_2/features/auth/domain/auth_user.dart';
import 'package:ranco_conecta_2/features/profile/application/profile_providers.dart';
import 'package:ranco_conecta_2/features/profile/presentation/account_screen.dart';
import 'package:ranco_conecta_2/features/categories/application/category_providers.dart';
import 'package:ranco_conecta_2/features/locations/application/location_providers.dart';
import 'package:ranco_conecta_2/shared/models/profile.dart';
import 'package:ranco_conecta_2/shared/models/app_notification.dart';
import 'package:ranco_conecta_2/shared/models/business.dart';
import 'package:ranco_conecta_2/shared/models/business_capability.dart';
import 'package:ranco_conecta_2/shared/models/category.dart';
import 'package:ranco_conecta_2/shared/models/location.dart';

/// FASE 3.21: hub "Mi negocio", asistente, estados y footer.
void main() {
  setUpAll(() => initializeDateFormatting('es'));

  const resolver = BusinessCapabilityResolver(featureFlags: FeatureFlags());

  const widths = [390.0, 430.0, 768.0, 1024.0, 1366.0, 1440.0, 1600.0];

  Future<void> setSize(WidgetTester tester, double width,
      [double height = 900]) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  ProviderBusinessSummary summary(
    String status, {
    BusinessType type = BusinessType.service,
    String name = 'Bruno Servicio Prueba',
  }) =>
      ProviderBusinessSummary(
        id: 'b1',
        name: name,
        businessType: type,
        publicationStatus: status,
        submittedAt: DateTime(2026, 10, 2),
      );

  BusinessDraft draft({
    String description = '',
    String? category,
    bool coverage = false,
  }) =>
      BusinessDraft(
        id: 'b1',
        businessType: BusinessType.service,
        publicationStatus: BusinessPublicationStatus.draft,
        name: 'Bruno Servicio Prueba',
        description: description,
        phone: '+56912345678',
        whatsapp: null,
        email: null,
        website: null,
        primaryCategoryId: category,
        addressText: null,
        coverage: coverage
            ? const [
                Location(id: 'l1', communeId: 'c1', name: 'Futrono', slug: 'f'),
              ]
            : const [],
        services: const [],
        onboardingMetadata: const {},
        submittedAt: null,
        changesRequestedNote: null,
      );

  Future<void> pumpRoute(
    WidgetTester tester,
    Widget screen,
    List<Override> overrides,
  ) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => screen),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig(
          environment: AppEnvironment.development,
          supabaseUrl: null,
          supabasePublishableKey: null,
        )),
        ...overrides,
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('hub sections', () {
    test('service businesses get operation → content → profile tabs', () {
      final sections = providerHubSections(
        resolver.resolve(businessType: BusinessType.service),
        BusinessType.service,
      );
      expect([for (final section in sections) section.tab],
          ['Solicitudes', 'Servicios', 'Cobertura', 'Fotos', 'Perfil']);
      expect(sections.every((section) => section.route != null), isTrue);
    });

    test('lodging keeps bookings, calendar, rates, photos and setup', () {
      final routes = [
        for (final section in providerHubSections(
          resolver.resolve(businessType: BusinessType.lodging),
          BusinessType.lodging,
        ))
          section.route,
      ];
      expect(routes, [
        '/provider/bookings',
        '/provider/calendar',
        '/provider/rates',
        '/provider/photos',
        '/provider/lodging',
      ]);
    });

    test('commerce merges profile and contact into one section', () {
      final sections = providerHubSections(
        resolver.resolve(businessType: BusinessType.commerce),
        BusinessType.commerce,
      );
      final profileRoutes =
          sections.where((s) => s.route == '/provider/profile').toList();
      expect(profileRoutes, hasLength(1));
      expect(profileRoutes.single.title, 'Perfil y contacto');
    });

    test('publication tones never rely on the label alone', () {
      expect(providerPublicationTone(BusinessPublicationStatus.published),
          isNot(providerPublicationTone(BusinessPublicationStatus.rejected)));
      expect(providerPublicationTone(BusinessPublicationStatus.pendingReview),
          providerPublicationTone(BusinessPublicationStatus.changesRequested));
    });
  });

  group('draft progress', () {
    test('marks completed wizard steps from the saved draft', () {
      final steps = onboardingProgressSteps(draft(
        description: 'Arreglos eléctricos y gasfitería a domicilio.',
        category: 'cat-1',
      ));
      expect([
        for (final step in steps) step.label
      ], [
        'Tipo de negocio',
        'Información',
        'Categoría',
        'Cobertura',
        'Revisión',
      ]);
      expect([for (final step in steps) step.done],
          [true, true, false, false, false]);
    });

    test('a short description keeps Información pending', () {
      final steps = onboardingProgressSteps(draft(description: 'Corto'));
      expect(steps[1].done, isFalse);
    });
  });

  group('category picker groups', () {
    Category category(String name, String slug, String icon) => Category(
        id: slug, name: name, slug: slug, iconKey: icon, themeKey: 'forest');

    test('maps real categories into editorial groups', () {
      expect(
          categoryPickerGroup(
              category('Turismo y Aventura', 'turismo-aventura', 'terrain')),
          'Turismo');
      expect(categoryPickerGroup(category('Alojamiento', 'alojamiento', 'bed')),
          'Alojamiento');
      expect(
          categoryPickerGroup(
              category('Gastronomía', 'gastronomia', 'restaurant')),
          'Gastronomía');
      expect(
          categoryPickerGroup(category(
              'Servicios profesionales', 'servicios-profesionales', 'pro')),
          'Servicios');
      expect(
          categoryPickerGroup(category('Emergencias', 'emergencies', 'alert')),
          'Emergencias');
      expect(
          categoryPickerGroup(
              category('Otros servicios', 'otros-servicios', 'more')),
          'Otros');
      expect(categoryPickerGroups.first, 'Turismo');
    });
  });

  group('business hub — not published', () {
    List<Override> overrides(String status, {BusinessDraft? value}) => [
          myProviderBusinessesProvider
              .overrideWith((ref) async => [summary(status)]),
          providerBusinessDraftProvider('b1')
              .overrideWith((ref) async => value ?? draft()),
          reviewWhatsAppDetailsProvider('b1').overrideWith((ref) async => null),
        ];

    testWidgets('draft shows progress and continues configuration',
        (tester) async {
      await setSize(tester, 1366);
      await pumpRoute(
        tester,
        const ProviderBusinessStatusScreen(),
        overrides('draft'),
      );
      expect(find.text('Tu publicación aún no está visible.'), findsOneWidget);
      expect(find.text('Progreso de configuración'), findsOneWidget);
      expect(find.text('1 de 5'), findsOneWidget);
      expect(find.text('Continuar configuración'), findsOneWidget);
      expect(find.text('Borrador'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('in review explains what follows without a giant panel',
        (tester) async {
      await setSize(tester, 1366);
      await pumpRoute(
        tester,
        const ProviderBusinessStatusScreen(),
        overrides('pending_review'),
      );
      expect(find.text('Estamos revisando tu publicación.'), findsOneWidget);
      expect(find.text('Enviado el 02/10/2026'), findsOneWidget);
      expect(find.text('Qué sigue'), findsOneWidget);
      expect(find.text('Volver a Cuenta'), findsOneWidget);
      expect(find.text('Continuar configuración'), findsNothing);
      expect(find.text('En revisión'), findsOneWidget);
    });

    for (final width in widths) {
      testWidgets('status hub has no layout errors at ${width.toInt()}px',
          (tester) async {
        await setSize(tester, width);
        await pumpRoute(
          tester,
          const ProviderBusinessStatusScreen(),
          overrides('changes_requested'),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('business hub — published', () {
    final overrides = <Override>[
      myProviderBusinessesProvider
          .overrideWith((ref) async => [summary('published')]),
      activeProviderBusinessProvider
          .overrideWith((ref) async => summary('published')),
      activeProviderCapabilitiesProvider.overrideWith(
        (ref) async => resolver.resolve(businessType: BusinessType.service),
      ),
      serviceBusinessManagementProvider.overrideWith((ref) async => null),
      providerRequestQueueProvider.overrideWith((ref) async => const []),
    ];

    testWidgets('summary shows header, tabs, recent requests and actions',
        (tester) async {
      await setSize(tester, 1366);
      await pumpRoute(tester, const ProviderDashboardScreen(), overrides);
      expect(find.text('Bruno Servicio Prueba'), findsOneWidget);
      expect(find.text('Publicado'), findsOneWidget);
      for (final tab in [
        'Resumen',
        'Solicitudes',
        'Servicios',
        'Cobertura',
        'Fotos',
        'Perfil',
      ]) {
        expect(
            find.descendant(
              of: find.byType(ProviderHubTabBar),
              matching: find.text(tab),
            ),
            findsOneWidget);
      }
      expect(find.text('Solicitudes recientes'), findsOneWidget);
      expect(find.text('Acciones rápidas'), findsOneWidget);
      expect(find.text('Editar negocio'), findsOneWidget);
      expect(find.text('Gestionar fotos'), findsOneWidget);
    });

    for (final width in widths) {
      testWidgets('summary hub has no layout errors at ${width.toInt()}px',
          (tester) async {
        await setSize(tester, width);
        await pumpRoute(tester, const ProviderDashboardScreen(), overrides);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('shared states', () {
    testWidgets('error state is compact, human and retryable', (tester) async {
      var retried = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RancoErrorState(
            message: 'No pudimos cargar la información',
            onRetry: () => retried = true,
          ),
        ),
      ));
      expect(find.text('No pudimos cargar la información'), findsOneWidget);
      expect(
          find.text('Inténtalo nuevamente en unos segundos.'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      expect(retried, isTrue);
    });

    testWidgets('notifications empty state is specific', (tester) async {
      await setSize(tester, 390);
      await pumpRoute(tester, const NotificationsScreen(), [
        notificationListProvider.overrideWith((ref) async => const []),
      ]);
      expect(find.text('No tienes notificaciones pendientes.'), findsOneWidget);
      expect(
        find.text('Cuando haya novedades sobre solicitudes o tu cuenta '
            'aparecerán aquí.'),
        findsOneWidget,
      );
    });

    testWidgets('notifications list groups by day with compact rows',
        (tester) async {
      await setSize(tester, 1366);
      final now = DateTime.now();
      await pumpRoute(tester, const NotificationsScreen(), [
        notificationListProvider.overrideWith((ref) async => [
              AppNotification(
                id: 'n1',
                type: 'new_message',
                title: 'Nuevo mensaje',
                body: 'Tienes un mensaje sobre tu solicitud.',
                createdAt: now,
              ),
              AppNotification(
                id: 'n2',
                type: 'quote_received',
                title: 'Cotización recibida',
                body: 'Revisa la cotización enviada.',
                createdAt: now.subtract(const Duration(days: 30)),
                readAt: now,
              ),
            ]),
      ]);
      expect(find.text('HOY'), findsOneWidget);
      expect(find.text('ANTERIORES'), findsOneWidget);
      expect(find.text('Marcar todo como leído'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('footer placement', () {
    Future<void> pumpFooter(WidgetTester tester, int items) async {
      await setSize(tester, 1366, 900);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: RancoFooterScrollView(
            children: [
              for (var i = 0; i < items; i++)
                SizedBox(height: 120, child: Text('Fila $i')),
            ],
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('short page: footer rests at the bottom of the viewport',
        (tester) async {
      await pumpFooter(tester, 2);
      final footer = tester.getRect(find.byType(RancoSiteFooter));
      expect(footer.bottom, moreOrLessEquals(900, epsilon: 1));
      final content = tester.getRect(find.text('Fila 1'));
      expect(footer.top, greaterThan(content.bottom));
    });

    testWidgets('long page: footer comes after all content', (tester) async {
      await pumpFooter(tester, 20);
      expect(find.byType(RancoSiteFooter), findsNothing);
      await tester.scrollUntilVisible(
        find.byType(RancoSiteFooter),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      final footer = tester.getRect(find.byType(RancoSiteFooter));
      final last = tester.getRect(find.text('Fila 19'));
      expect(footer.top, greaterThanOrEqualTo(last.bottom));
    });
  });

  group('account as provider hub', () {
    const user = AuthUser(
      id: 'p1',
      email: 'prestador@example.com',
      emailConfirmed: true,
    );
    List<Override> overrides(String status) => [
          authStateProvider.overrideWith((ref) => Stream.value(user)),
          currentProfileProvider.overrideWith((ref) async => const Profile(
                id: 'p1',
                fullName: 'Bruno Prestador',
                phone: null,
                avatarUrl: null,
                role: ProfileRole.provider,
                accountStatus: 'active',
              )),
          myProviderBusinessesProvider
              .overrideWith((ref) async => [summary(status)]),
          activeProviderBusinessProvider
              .overrideWith((ref) async => summary(status)),
        ];

    testWidgets('business card shows type, semantic status and one CTA',
        (tester) async {
      await setSize(tester, 1366);
      await pumpRoute(
        tester,
        const Scaffold(body: AccountScreen()),
        overrides('pending_review'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bruno Servicio Prueba'), findsOneWidget);
      expect(find.text('Servicio'), findsOneWidget);
      expect(find.text('En revisión'), findsOneWidget);
      expect(find.text('Estamos revisando tu publicación.'), findsOneWidget);
      expect(find.text('Gestionar negocio'), findsOneWidget);
      expect(find.text('Contraseña y sesión actual'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      // Sin publicar no se ofrece "ver perfil público".
      expect(find.byTooltip('Ver perfil público'), findsNothing);
    });

    for (final width in [390.0, 768.0, 1440.0]) {
      testWidgets('account provider has no layout errors at ${width.toInt()}',
          (tester) async {
        await setSize(tester, width);
        await pumpRoute(
          tester,
          const Scaffold(body: AccountScreen()),
          overrides('published'),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Ver perfil público'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('publication wizard', () {
    List<Override> overrides() => [
          supabaseClientProvider.overrideWithValue(null),
          authRepositoryProvider.overrideWithValue(_SignedInAuth()),
          categoriesProvider.overrideWith((ref) async => const []),
          locationsProvider.overrideWith((ref) async => const []),
        ];

    testWidgets('desktop: labelled stepper and actions next to the form',
        (tester) async {
      await setSize(tester, 1440);
      await pumpRoute(tester, const ProviderRegistrationScreen(), overrides());
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Elige el tipo de negocio'), findsOneWidget);
      for (final label in [
        'Tipo',
        'Información',
        'Categoría',
        'Cobertura',
        'Revisión',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      final cta =
          tester.getRect(find.widgetWithText(FilledButton, 'Continuar'));
      // Botón de ancho natural, alineado al contenido (no a la ventana).
      expect(cta.width, lessThan(260));
      expect(cta.right, lessThan(1440 / 2 + 760 / 2 + 1));
      expect(tester.takeException(), isNull);
    });

    for (final width in [390.0, 430.0, 768.0]) {
      testWidgets('wizard has no layout errors at ${width.toInt()}px',
          (tester) async {
        await setSize(tester, width);
        await pumpRoute(
            tester, const ProviderRegistrationScreen(), overrides());
        await tester.pump(const Duration(milliseconds: 300));
        // Móvil: "Paso 1 de 5 · Tipo"; tablet: stepper con etiquetas.
        expect(find.textContaining('Paso 1 de 5'),
            width < 600 ? findsOneWidget : findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

/// Sesión iniciada mínima para el asistente (sin Supabase).
class _SignedInAuth implements AuthRepository {
  @override
  AuthUser? currentUser() => const AuthUser(
        id: 'p1',
        email: 'prestador@example.com',
        emailConfirmed: true,
      );

  @override
  Stream<AuthUser?> observeAuthState() => Stream.value(currentUser());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
