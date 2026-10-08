import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ranco_conecta_2/config/app_config.dart';
import 'package:ranco_conecta_2/core/widgets/ranco_site_footer.dart';
import 'package:ranco_conecta_2/features/admin/application/admin_providers.dart';
import 'package:ranco_conecta_2/features/admin/data/admin_business_review_repository.dart';
import 'package:ranco_conecta_2/features/admin/data/admin_settings_repository.dart';
import 'package:ranco_conecta_2/features/admin/presentation/admin_screens.dart';
import 'package:ranco_conecta_2/features/admin/presentation/admin_settings_screens.dart';
import 'package:ranco_conecta_2/features/auth/application/auth_controller.dart';
import 'package:ranco_conecta_2/features/auth/domain/auth_user.dart';
import 'package:ranco_conecta_2/features/auth/presentation/sign_in_screen.dart';
import 'package:ranco_conecta_2/features/businesses/application/business_providers.dart';
import 'package:ranco_conecta_2/features/categories/application/category_providers.dart';
import 'package:ranco_conecta_2/features/discovery/presentation/explore_screen.dart';
import 'package:ranco_conecta_2/features/favorites/application/favorite_providers.dart';
import 'package:ranco_conecta_2/features/favorites/presentation/saved_screen.dart';
import 'package:ranco_conecta_2/features/home/presentation/home_screen.dart';
import 'package:ranco_conecta_2/features/legal/presentation/legal_screen.dart';
import 'package:ranco_conecta_2/features/locations/application/location_providers.dart';
import 'package:ranco_conecta_2/features/notifications/application/notification_providers.dart';
import 'package:ranco_conecta_2/features/notifications/presentation/notifications_screen.dart';
import 'package:ranco_conecta_2/features/profile/application/profile_providers.dart';
import 'package:ranco_conecta_2/features/profile/presentation/account_screen.dart';
import 'package:ranco_conecta_2/features/profile/presentation/account_security_screen.dart';
import 'package:ranco_conecta_2/features/provider_dashboard/data/business_media_repository.dart';
import 'package:ranco_conecta_2/shared/models/business.dart';
import 'package:ranco_conecta_2/shared/models/category.dart';
import 'package:ranco_conecta_2/shared/models/location.dart';
import 'package:ranco_conecta_2/shared/models/profile.dart';

/// Fase 3.14: barrido responsive de las vistas refinadas. Falla ante
/// cualquier overflow/excepción de layout en los anchos de referencia.
void main() {
  const widths = [
    390.0,
    430.0,
    600.0,
    768.0,
    1024.0,
    1200.0,
    1280.0,
    1366.0,
    1440.0,
    1600.0,
  ];

  // Nombre largo real observado en QA: no debe romper columnas.
  const longName = 'Nuevo negoaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaocio';

  const categories = [
    Category(
        id: 'lodging',
        name: 'Alojamiento',
        slug: 'alojamiento',
        iconKey: 'bed',
        themeKey: 'lake'),
    Category(
        id: 'gastronomy',
        name: 'Gastronomía',
        slug: 'gastronomia',
        iconKey: 'restaurant',
        themeKey: 'clay'),
    Category(
        id: 'tourism',
        name: 'Turismo y Aventura',
        slug: 'turismo-aventura',
        iconKey: 'terrain',
        themeKey: 'moss'),
    Category(
        id: 'home',
        name: 'Hogar y mantenimiento',
        slug: 'hogar-y-mantenimiento',
        iconKey: 'home_repair',
        themeKey: 'forest'),
    Category(
        id: 'emergency',
        name: 'Emergencias',
        slug: 'emergencias',
        iconKey: 'alert',
        themeKey: 'danger'),
  ];

  const business = Business(
    id: 'business-1',
    ownerId: 'owner-1',
    type: BusinessType.service,
    name: longName,
    slug: 'nuevo-negocio',
    description: 'Servicio local.',
    phone: null,
    whatsapp: null,
    email: null,
    website: null,
    addressText: null,
    verificationStatus: 'verified',
    isFeatured: true,
    acceptsRequests: true,
    ratingAvg: 4.8,
    reviewCount: 12,
    services: [],
    coverage: [
      Location(
        id: 'location-1',
        communeId: 'commune-1',
        name: 'Lago Ranco',
        slug: 'lago-ranco',
      ),
    ],
    hours: [],
    media: [],
  );

  final reviewItem = AdminBusinessReviewSummary(
    id: 'business-1',
    name: longName,
    businessType: BusinessType.service,
    publicationStatus: BusinessPublicationStatus.pendingReview,
    verificationStatus: 'unverified',
    categoryName: 'Mecánica',
    ownerName: 'Propietario con un nombre bastante largo para la columna',
    ownerEmail: 'propietario@example.com',
    submittedAt: DateTime(2026, 9, 30),
    createdAt: DateTime(2026, 9, 29),
    totalCount: 1,
  );

  final overrides = [
    appConfigProvider.overrideWithValue(const AppConfig(
      environment: AppEnvironment.development,
      supabaseUrl: null,
      supabasePublishableKey: null,
    )),
    categoriesProvider.overrideWith((ref) async => categories),
    publishedBusinessesProvider.overrideWith((ref) async => const [business]),
    locationsProvider.overrideWith((ref) async => const []),
    businessMediaRepositoryProvider
        .overrideWithValue(const BusinessMediaRepository(null)),
    isFavoriteProvider(business.id).overrideWith((ref) async => false),
    currentAdminRoleProvider
        .overrideWith((ref) async => ProfileRole.superAdmin),
    adminReviewStatsProvider.overrideWith((ref) async => {
          'pending_review': 1,
          'published': 6,
          'rejected': 2,
        }),
    adminUsersProvider
        .overrideWith((ref, query) async => const AdminUsersPage(rows: [
              {
                'full_name': 'Usuaria con nombre extenso de prueba en Ranco',
                'email': 'una.direccion.de.correo.muy.larga@example.com',
                'role': 'provider',
                'account_status': 'active',
                'created_at': '2026-09-30T12:00:00Z',
                'total_count': 1,
              },
            ], total: 1)),
    adminBusinessReviewPageProvider.overrideWith((ref, query) async =>
        AdminBusinessReviewPage(items: [reviewItem], totalCount: 1)),
    adminAnalyticsSummaryProvider
        .overrideWith((ref) async => {'PROFILE_VIEW': 3}),
    // Fase 3.16: sesión admin y datos para Cuenta, Guardados y Notificaciones.
    authStateProvider.overrideWith((ref) => Stream.value(const AuthUser(
          id: 'admin-1',
          email: 'una.direccion.de.correo.muy.larga@example.com',
          emailConfirmed: true,
        ))),
    currentProfileProvider.overrideWith((ref) async => const Profile(
          id: 'admin-1',
          fullName: 'Administradora con nombre largo de Lago Ranco',
          phone: null,
          avatarUrl: null,
          role: ProfileRole.superAdmin,
          accountStatus: 'active',
        )),
    favoriteBusinessesProvider.overrideWith((ref) async => const [business]),
    notificationListProvider.overrideWith((ref) async => const []),
    adminWhatsAppSettingsProvider
        .overrideWith((ref) async => const AdminWhatsAppSettings(
              number: '56912345678',
              enabled: true,
              newBusiness: true,
              businessChanges: false,
              userReports: true,
            )),
  ];

  final screens = <String, Widget Function()>{
    'home': () => const Scaffold(body: HomeScreen()),
    'explore': () => const Scaffold(body: ExploreScreen()),
    'legal': () => const LegalScreen(privacy: false),
    'provider join': () => const ProviderJoinScreen(),
    'provider access': () =>
        const SignUpScreen(nextRoute: '/provider/register'),
    'footer': () => const Scaffold(
          body: SingleChildScrollView(child: RancoSiteFooter()),
        ),
    'account': () => const Scaffold(body: AccountScreen()),
    'security': () => const AccountSecurityScreen(),
    'saved': () => const Scaffold(body: SavedScreen()),
    'notifications': () => const NotificationsScreen(),
    'contact': () => const ContactScreen(),
    'privacy': () => const LegalScreen(privacy: true),
  };

  final adminScreens = <String, (String, Widget Function())>{
    'admin dashboard': ('/admin', () => const AdminDashboardScreen()),
    'admin businesses': (
      '/admin/businesses',
      () => const AdminBusinessesScreen()
    ),
    'admin users': ('/admin/users', () => const AdminUsersScreen()),
    'admin categories': (
      '/admin/categories',
      () => const AdminCategoriesScreen()
    ),
    'admin settings': (
      '/admin/settings',
      () => const AdminWhatsAppSettingsScreen()
    ),
    'admin analytics': ('/admin/analytics', () => const AdminAnalyticsScreen()),
    'admin audit': ('/admin/audit', () => const AdminAuditScreen()),
  };

  Future<void> setWidth(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  for (final width in widths) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} has no layout errors at ${width.toInt()}px',
          (tester) async {
        await setWidth(tester, width);
        final router = GoRouter(routes: [
          GoRoute(path: '/', builder: (_, __) => entry.value()),
        ]);
        addTearDown(router.dispose);
        await tester.pumpWidget(ProviderScope(
          overrides: overrides,
          child: MaterialApp.router(routerConfig: router),
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
      });
    }

    for (final entry in adminScreens.entries) {
      testWidgets('${entry.key} has no layout errors at ${width.toInt()}px',
          (tester) async {
        await setWidth(tester, width);
        final (path, builder) = entry.value;
        final router = GoRouter(initialLocation: path, routes: [
          ShellRoute(
            builder: (context, state, child) =>
                AdminWorkspaceShell(path: state.uri.path, child: child),
            routes: [GoRoute(path: path, builder: (_, __) => builder())],
          ),
        ]);
        addTearDown(router.dispose);
        await tester.pumpWidget(ProviderScope(
          overrides: overrides,
          child: MaterialApp.router(routerConfig: router),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('public UI never exposes "Verificado" for verified businesses',
      (tester) async {
    await setWidth(tester, 1366);
    final router = GoRouter(routes: [
      GoRoute(
          path: '/', builder: (_, __) => const Scaffold(body: HomeScreen())),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Verificad'), findsNothing);
  });

  testWidgets('admin users show Spanish role and status labels',
      (tester) async {
    await setWidth(tester, 1366);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const AdminUsersScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: overrides,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Prestador'), findsOneWidget);
    expect(find.text('Activo'), findsOneWidget);
    expect(find.text('PROVIDER'), findsNothing);
    expect(find.text('active'), findsNothing);
  });
}
