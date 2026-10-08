import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ranco_conecta_2/features/admin/application/admin_providers.dart';
import 'package:ranco_conecta_2/features/admin/data/admin_business_review_repository.dart';
import 'package:ranco_conecta_2/features/admin/data/admin_settings_repository.dart';
import 'package:ranco_conecta_2/features/admin/presentation/admin_screens.dart';
import 'package:ranco_conecta_2/features/admin/presentation/admin_settings_screens.dart';
import 'package:ranco_conecta_2/features/auth/presentation/sign_in_screen.dart';
import 'package:ranco_conecta_2/features/legal/presentation/consent_fields.dart';
import 'package:ranco_conecta_2/features/legal/presentation/legal_screen.dart';
import 'package:ranco_conecta_2/features/notifications/presentation/notifications_screen.dart';
import 'package:ranco_conecta_2/shared/models/app_notification.dart';
import 'package:ranco_conecta_2/shared/models/profile.dart';
import 'package:ranco_conecta_2/theme/ranco_theme.dart';

/// Fase 3.20: agrupación de notificaciones, consentimientos y flujos
/// públicos refinados.
void main() {
  AppNotification notification(String id, DateTime createdAt) =>
      AppNotification(
        id: id,
        type: 'new_message',
        title: 'Aviso $id',
        body: 'Detalle',
        createdAt: createdAt,
      );

  test('notifications group into Hoy, Ayer and Anteriores', () {
    final now = DateTime(2026, 10, 3, 9);
    final groups = groupNotificationsByDay([
      notification('a', DateTime(2026, 10, 3, 8)),
      notification('b', DateTime(2026, 10, 2, 23)),
      notification('c', DateTime(2026, 10, 2, 0, 1)),
      notification('d', DateTime(2026, 9, 28)),
      notification('e', DateTime(2026, 9, 20)),
    ], now);

    expect([for (final (label, _) in groups) label],
        ['Hoy', 'Ayer', 'Anteriores']);
    expect([for (final item in groups[1].$2) item.id], ['b', 'c']);
    expect([for (final item in groups[2].$2) item.id], ['d', 'e']);
  });

  test('empty groups are omitted', () {
    final groups = groupNotificationsByDay(
        [notification('x', DateTime(2026, 9, 1))], DateTime(2026, 10, 3));
    expect(groups.single.$1, 'Anteriores');
  });

  testWidgets('consents start unchecked and links do not toggle rows',
      (tester) async {
    var terms = false;
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: ConsentFields(
                terms: terms,
                privacy: false,
                dataProcessing: false,
                onTerms: (value) => setState(() => terms = value),
                onPrivacy: (_) {},
                onDataProcessing: (_) {},
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/terminos',
        builder: (_, __) => const Scaffold(body: Text('Documento términos')),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    final boxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
    expect(boxes, hasLength(3));
    expect(boxes.every((box) => box.value == false), isTrue);

    await tester.tap(find.text('Ver términos'));
    await tester.pumpAndSettle();
    expect(find.text('Documento términos'), findsOneWidget);
    expect(terms, isFalse);
  });

  for (final width in [390.0, 1440.0]) {
    testWidgets('provider join keeps flow CTAs at ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: RancoTheme.light(),
          home: const ProviderJoinScreen(),
        ),
      ));
      await tester.pump();

      expect(find.text('Haz visible tu negocio'), findsOneWidget);
      // FASE 3.24: el CTA describe el paso real (crear el acceso).
      expect(find.text('Crear mi acceso'), findsOneWidget);
      expect(find.text('Ya tengo una cuenta'), findsNothing);
      // Desktop: la columna del flujo no queda diminuta (620–700 px).
      if (width >= 1024) {
        final hero = tester.getSize(find
            .ancestor(
              of: find.text('Haz visible tu negocio'),
              matching: find.byType(Container),
            )
            .first);
        expect(hero.width, greaterThanOrEqualTo(620));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('legal header shows version metadata and numbered sections',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: RancoTheme.light(),
        home: const LegalScreen(privacy: true),
      ),
    );
    await tester.pump();

    expect(find.text('Versión 2026-10-01'), findsOneWidget);
    expect(find.text('Actualizado el 1 oct 2026'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    // Callout útil (frase existente del texto legal).
    // FASE 3.25: sin "En pocas palabras"; el destacado aparece al abrir la
    // card 03.
    expect(find.text('EN POCAS PALABRAS'), findsNothing);
    expect(
        find.text('No publicamos tu teléfono en el catálogo.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // --- Fase 3.20 (pre-beta): revisión admin, usuarios y acceso proveedor ---

  final reviewDetail = AdminBusinessReviewDetail.fromJson({
    'business': {
      'id': 'b-1',
      'name': 'Cabañas del Lago con un nombre bastante largo',
      'business_type': 'lodging',
      'publication_status': 'pending_review',
      'phone': '+56 9 1111 2222',
    },
    'category': {'name': 'Alojamiento'},
    'owner': {'full_name': 'Ana Propietaria', 'email': 'ana@example.com'},
    'coverage': [
      {'location_name': 'Lago Ranco', 'commune_name': 'Lago Ranco'},
    ],
    'services': const [],
    'media': [
      {'media_type': 'cover', 'storage_path': 'b-1/portada.jpg'},
    ],
    'requirements': [
      {'satisfied': false, 'message': 'Falta agregar una foto de portada.'},
      {'satisfied': true, 'message': 'Datos de contacto completos.'},
    ],
    'events': const [],
  });

  Future<void> pumpReview(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: '/admin/businesses/b-1', routes: [
      GoRoute(
        path: '/admin/businesses/:id',
        builder: (_, state) =>
            AdminBusinessDetailScreen(businessId: state.pathParameters['id']!),
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentAdminRoleProvider
            .overrideWith((ref) async => ProfileRole.superAdmin),
        adminBusinessReviewDetailProvider('b-1')
            .overrideWith((ref) async => reviewDetail),
      ],
      child:
          MaterialApp.router(theme: RancoTheme.light(), routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('review detail shows one section at a time with decision rail',
      (tester) async {
    await pumpReview(tester, 1440);
    expect(find.text('Decisión'), findsOneWidget);
    expect(find.text('Publicar'), findsOneWidget);
    // Resumen visible; Requisitos solo al elegirlo.
    expect(find.text('Información general'), findsOneWidget);
    expect(find.text('Falta agregar una foto de portada.'), findsNothing);
    await tester.tap(find.text('Requisitos'));
    await tester.pumpAndSettle();
    expect(find.text('Falta agregar una foto de portada.'), findsOneWidget);
    expect(find.text('Información general'), findsNothing);
    await tester.tap(find.text('Archivos'));
    await tester.pumpAndSettle();
    expect(find.text('portada.jpg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review detail uses accordions on mobile', (tester) async {
    await pumpReview(tester, 390);
    expect(find.byType(ExpansionTile), findsWidgets);
    expect(find.text('Información general'), findsOneWidget);
    // Las demás secciones existen como acordeones plegados.
    await tester.scrollUntilVisible(find.text('Historial'), 300,
        scrollable: find
            .ancestor(
                of: find.text('Información general'),
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('Sin eventos.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [600.0, 768.0, 1024.0, 1366.0, 1600.0]) {
    testWidgets('review detail has no layout errors at ${width.toInt()}px',
        (tester) async {
      await pumpReview(tester, width);
      expect(find.text('Decisión'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  // FASE 3.21: Codex conectó la gestión segura de cuentas; las acciones
  // del detalle quedan habilitadas (siempre con confirmación).
  testWidgets('admin user actions are enabled once backend exists',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const AdminUsersScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentAdminRoleProvider
            .overrideWith((ref) async => ProfileRole.superAdmin),
        adminUserMutationsReadyProvider.overrideWith((ref) async => true),
        adminUsersProvider
            .overrideWith((ref, query) async => const AdminUsersPage(rows: [
                  {
                    'full_name': 'Vecina Ranco',
                    'email': 'vecina@example.com',
                    'role': 'customer',
                    'account_status': 'active',
                  },
                ], total: 1)),
      ],
      child:
          MaterialApp.router(theme: RancoTheme.light(), routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Acciones'), findsOneWidget);
    // FASE 3.22A: la fila abre el detalle (la columna Acciones es solo "⋯").
    await tester.tap(find.text('Vecina Ranco'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle de usuario'), findsOneWidget);
    final suspend = tester.widget<OutlinedButton>(find.ancestor(
        of: find.text('Suspender'), matching: find.byType(OutlinedButton)));
    expect(suspend.onPressed, isNotNull);
    expect(find.text(AdminUserActions.unavailableHint), findsNothing);
  });

  testWidgets('provider sign-in keeps one task and links onboarding',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(initialLocation: '/provider/sign-in', routes: [
      GoRoute(
          path: '/provider/sign-in',
          builder: (_, __) => const SignInScreen(providerAccess: true)),
      GoRoute(
          path: '/provider/join',
          builder: (_, __) => const Scaffold(body: Text('Onboarding UI'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      child:
          MaterialApp.router(theme: RancoTheme.light(), routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('PORTAL PARA NEGOCIOS LOCALES'), findsOneWidget);
    expect(find.text('Acceso proveedor'), findsOneWidget);
    expect(find.text('Explorar como visitante'), findsNothing);
    // FASE 3.21: el registro de prestador no se rotula "Publicar mi negocio".
    expect(find.text('Publicar mi negocio'), findsNothing);
    expect(find.text('Crea tu acceso para gestionar tus servicios o negocio.'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Ser parte de Ranco Conecta'));
    await tester.tap(find.text('Ser parte de Ranco Conecta'));
    await tester.pumpAndSettle();
    expect(find.text('Onboarding UI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
