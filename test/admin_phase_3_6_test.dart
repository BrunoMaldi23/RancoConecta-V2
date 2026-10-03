import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ranco_conecta_2/config/app_config.dart';
import 'package:ranco_conecta_2/features/admin/application/admin_providers.dart';
import 'package:ranco_conecta_2/features/admin/data/admin_business_review_repository.dart';
import 'package:ranco_conecta_2/features/admin/data/admin_settings_repository.dart';
import 'package:ranco_conecta_2/features/admin/presentation/admin_screens.dart';
import 'package:ranco_conecta_2/features/admin/presentation/admin_settings_screens.dart';
import 'package:ranco_conecta_2/features/auth/application/auth_controller.dart';
import 'package:ranco_conecta_2/features/auth/domain/auth_user.dart';
import 'package:ranco_conecta_2/features/categories/application/category_providers.dart';
import 'package:ranco_conecta_2/features/profile/application/profile_providers.dart';
import 'package:ranco_conecta_2/features/profile/presentation/account_screen.dart';
import 'package:ranco_conecta_2/shared/models/business.dart';
import 'package:ranco_conecta_2/shared/models/category.dart';
import 'package:ranco_conecta_2/shared/models/profile.dart';

void main() {
  testWidgets('dashboard shows honest empty states at 390px', (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = GoRouter(initialLocation: '/admin', routes: [
      ShellRoute(
        builder: (context, state, child) => AdminWorkspaceShell(
          path: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(
              path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
        ],
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentAdminRoleProvider.overrideWith((ref) async => ProfileRole.admin),
        adminReviewStatsProvider.overrideWith((ref) async => {
              'pending_review': 0,
              'published': 0,
              'rejected': 0,
            }),
        adminUsersProvider.overrideWith(
            (ref, query) async => const AdminUsersPage(rows: [], total: 0)),
        categoriesProvider.overrideWith((ref) async => []),
        adminBusinessReviewPageProvider.overrideWith((ref, query) async =>
            const AdminBusinessReviewPage(items: [], totalCount: 0)),
        adminAnalyticsSummaryProvider.overrideWith((ref) async => {}),
        adminWhatsAppSettingsProvider
            .overrideWith((ref) async => const AdminWhatsAppSettings(
                  number: '',
                  enabled: false,
                  newBusiness: false,
                  businessChanges: false,
                  userReports: false,
                )),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Panel administrativo'), findsOneWidget);
    expect(find.text('Todo está al día'), findsOneWidget);
    expect(find.text('No existen negocios pendientes de revisión'),
        findsOneWidget);
    final layoutError = tester.takeException();
    expect(layoutError, isNull,
        reason:
            layoutError is FlutterError ? layoutError.toStringDeep() : null);
  });

  testWidgets('businesses All queries existing RPC without a status filter',
      (tester) async {
    tester.view.physicalSize = const Size(1366, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    BusinessPublicationStatus? queriedStatus;
    final router = GoRouter(initialLocation: '/admin/businesses', routes: [
      ShellRoute(
        builder: (context, state, child) => AdminWorkspaceShell(
          path: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(
              path: '/admin/businesses',
              builder: (_, __) => const AdminBusinessesScreen()),
        ],
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentAdminRoleProvider.overrideWith((ref) async => ProfileRole.admin),
        adminBusinessReviewPageProvider.overrideWith((ref, query) async {
          queriedStatus = query.status;
          return AdminBusinessReviewPage(items: [
            AdminBusinessReviewSummary(
              id: 'business-1',
              name: 'Taller Ranco',
              businessType: BusinessType.service,
              publicationStatus: BusinessPublicationStatus.pendingReview,
              verificationStatus: 'unverified',
              categoryName: 'Mecánica',
              ownerName: 'Vecino Ranco',
              ownerEmail: 'vecino@example.com',
              submittedAt: DateTime(2026, 9, 30),
              createdAt: DateTime(2026, 9, 29),
              totalCount: 1,
            ),
          ], totalCount: 1);
        }),
        adminBusinessReviewDetailProvider
            .overrideWith((ref, id) async => AdminBusinessReviewDetail(
                  business: {'id': id, 'name': 'Taller Ranco'},
                  category: const {},
                  owner: const {},
                  coverage: const [],
                  services: const [],
                  lodgingDetails: const {},
                  media: const [],
                  requirements: const [],
                  events: const [],
                )),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(queriedStatus, isNull);
    expect(find.text('Imagen'), findsOneWidget);
    expect(find.text('Taller Ranco'), findsOneWidget);
    expect(find.text('Propietario'), findsOneWidget);
    expect(find.text('Fecha'), findsOneWidget);
    expect(find.text('Ver detalle'), findsOneWidget);
    final tableError = tester.takeException();
    expect(tableError, isNull,
        reason: tableError is FlutterError ? tableError.toStringDeep() : null);
  });

  for (final width in [1024.0, 768.0, 390.0]) {
    testWidgets('business cards fit at ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final router = GoRouter(initialLocation: '/admin/businesses', routes: [
        ShellRoute(
          builder: (context, state, child) => AdminWorkspaceShell(
            path: state.uri.path,
            child: child,
          ),
          routes: [
            GoRoute(
                path: '/admin/businesses',
                builder: (_, __) => const AdminBusinessesScreen())
          ],
        ),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentAdminRoleProvider
              .overrideWith((ref) async => ProfileRole.admin),
          adminBusinessReviewPageProvider.overrideWith((ref, query) async =>
              AdminBusinessReviewPage(items: [
                AdminBusinessReviewSummary(
                  id: 'business-1',
                  name: 'Taller Ranco',
                  businessType: BusinessType.service,
                  publicationStatus: BusinessPublicationStatus.pendingReview,
                  verificationStatus: 'unverified',
                  categoryName: 'Mecánica',
                  ownerName: 'Vecino Ranco',
                  ownerEmail: 'vecino@example.com',
                  submittedAt: DateTime(2026, 9, 30),
                  createdAt: DateTime(2026, 9, 29),
                  totalCount: 1,
                ),
              ], totalCount: 1)),
          adminBusinessReviewDetailProvider
              .overrideWith((ref, id) async => AdminBusinessReviewDetail(
                    business: {'id': id, 'name': 'Taller Ranco'},
                    category: const {},
                    owner: const {},
                    coverage: const [],
                    services: const [],
                    lodgingDetails: const {},
                    media: const [],
                    requirements: const [],
                    events: const [],
                  )),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Taller Ranco'), findsOneWidget);
      expect(find.text('Imagen'), findsNothing);
      expect(find.text('Ver negocio'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sidebar opens a module and returns to the admin panel',
      (tester) async {
    tester.view.physicalSize = const Size(1024, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = GoRouter(initialLocation: '/admin', routes: [
      ShellRoute(
        builder: (context, state, child) => AdminWorkspaceShell(
          path: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(
              path: '/admin',
              builder: (_, __) => const Center(child: Text('Resumen UI'))),
          GoRoute(
              path: '/admin/categories',
              builder: (_, __) => const Center(child: Text('Catálogo UI'))),
        ],
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentAdminRoleProvider.overrideWith((ref) async => ProfileRole.admin),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categorías'));
    await tester.pumpAndSettle();
    expect(find.text('Catálogo UI'), findsOneWidget);
    expect(find.text('Volver al panel'), findsNothing);
    await tester.tap(find.text('Resumen'));
    await tester.pumpAndSettle();
    expect(find.text('Resumen UI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin error state retries without exposing technical errors',
      (tester) async {
    var calls = 0;
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const AdminAnalyticsScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentAdminRoleProvider.overrideWith((ref) async => ProfileRole.admin),
        adminAnalyticsSummaryProvider.overrideWith((ref) async {
          calls++;
          if (calls == 1) throw StateError('technical detail');
          return {'PROFILE_VIEW': 2};
        }),
        adminReviewStatsProvider.overrideWith((ref) async => {}),
        adminUsersProvider.overrideWith(
            (ref, query) async => const AdminUsersPage(rows: [], total: 0)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar la información.'), findsOneWidget);
    expect(find.textContaining('technical detail'), findsNothing);
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Actividad últimos 30 días'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('admin account hides provider invitation', (tester) async {
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
        authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(
              id: 'admin-1',
              email: 'admin@lagoranco.cl',
              emailConfirmed: true,
            ))),
        currentProfileProvider.overrideWith((ref) async => const Profile(
              id: 'admin-1',
              fullName: 'Admin Ranco',
              phone: null,
              avatarUrl: null,
              role: ProfileRole.admin,
              accountStatus: 'active',
            )),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    // Cuenta muestra un único acceso al panel; los módulos viven en /admin.
    expect(find.text('Administración'), findsOneWidget);
    expect(find.text('Panel administrativo'), findsOneWidget);
    expect(find.text('Abrir panel'), findsOneWidget);
    expect(find.text('Revisiones pendientes'), findsNothing);
    expect(find.text('¿Tienes un negocio?'), findsNothing);
    expect(find.text('Publícalo gratis en Ranco Conecta'), findsNothing);
  });

  testWidgets('category count stays dynamic', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const AdminCategoriesScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentAdminRoleProvider.overrideWith((ref) async => ProfileRole.admin),
        adminCategoriesProvider.overrideWith((ref) async => const [
              Category(
                  id: '1',
                  name: 'Turismo y Aventura',
                  slug: 'turismo-aventura',
                  iconKey: 'terrain',
                  themeKey: 'green'),
              Category(
                  id: '2',
                  name: 'Mecánica',
                  slug: 'mecanica',
                  iconKey: 'build',
                  themeKey: 'green'),
            ]),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('2 categorías'), findsOneWidget);
    expect(find.text('Turismo y Aventura'), findsOneWidget);
    expect(find.text('turismo-aventura'), findsOneWidget);
    // Todas están activas: el encabezado lo indica y no se repite el badge.
    expect(find.text('Activa'), findsNothing);
    await tester.enterText(find.byType(TextField), 'mecanica');
    await tester.pumpAndSettle();
    expect(find.text('Turismo y Aventura'), findsNothing);
    expect(find.text('Mecánica'), findsOneWidget);
    expect(find.text('2 categorías'), findsOneWidget);
    expect(find.text('Crear categoría'), findsNothing);
  });
}
