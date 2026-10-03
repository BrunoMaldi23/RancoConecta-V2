import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ranco_conecta_2/config/app_config.dart';
import 'package:ranco_conecta_2/features/businesses/application/business_providers.dart';
import 'package:ranco_conecta_2/features/categories/application/category_providers.dart';
import 'package:ranco_conecta_2/features/categories/presentation/category_editorial_order.dart';
import 'package:ranco_conecta_2/features/categories/presentation/categories_screen.dart';
import 'package:ranco_conecta_2/features/businesses/presentation/business_card.dart';
import 'package:ranco_conecta_2/features/discovery/application/business_card_data.dart';
import 'package:ranco_conecta_2/features/discovery/presentation/explore_screen.dart';
import 'package:ranco_conecta_2/features/favorites/application/favorite_providers.dart';
import 'package:ranco_conecta_2/features/home/presentation/home_screen.dart';
import 'package:ranco_conecta_2/features/provider_dashboard/data/business_media_repository.dart';
import 'package:ranco_conecta_2/shared/models/business.dart';
import 'package:ranco_conecta_2/shared/models/category.dart';

void main() {
  const categories = [
    Category(
        id: 'other',
        name: 'Pintura',
        slug: 'pintura',
        iconKey: 'paint',
        themeKey: 'forest'),
    Category(
        id: 'mechanics',
        name: 'Mecánica',
        slug: 'mecanica',
        iconKey: 'tools',
        themeKey: 'forest'),
    Category(
        id: 'home',
        name: 'Hogar y mantenimiento',
        slug: 'hogar-y-mantenimiento',
        iconKey: 'home_repair',
        themeKey: 'forest'),
    Category(
        id: 'tourism',
        name: 'Turismo y Aventura',
        slug: 'turismo-aventura',
        iconKey: 'terrain',
        themeKey: 'moss'),
    Category(
        id: 'lodging',
        name: 'Alojamientos',
        slug: 'lodging',
        iconKey: 'bed',
        themeKey: 'lake'),
    Category(
        id: 'gastronomy',
        name: 'Gastronomía',
        slug: 'gastronomy',
        iconKey: 'restaurant',
        themeKey: 'clay'),
    Category(
        id: 'emergency',
        name: 'Emergencias',
        slug: 'emergencies',
        iconKey: 'alert',
        themeKey: 'clay'),
    Category(
        id: 'plumbing',
        name: 'Gasfitería',
        slug: 'gasfiteria',
        iconKey: 'plumbing',
        themeKey: 'forest'),
    Category(
        id: 'electricity',
        name: 'Electricidad',
        slug: 'electricidad',
        iconKey: 'bolt',
        themeKey: 'forest'),
  ];

  const tourismBusiness = Business(
    id: 'tour-1',
    ownerId: 'owner-1',
    type: BusinessType.tourism,
    name: 'Aventura Ranco',
    slug: 'aventura-ranco',
    description: null,
    phone: null,
    whatsapp: null,
    email: null,
    website: null,
    addressText: null,
    verificationStatus: 'unverified',
    isFeatured: false,
    acceptsRequests: true,
    ratingAvg: 0,
    reviewCount: 0,
    services: [],
    coverage: [],
    hours: [],
    media: [],
  );

  test('quick access prioritizes tourism and keeps other categories available',
      () {
    expect(
      quickAccessCategories(categories).map((category) => category.id),
      [
        'lodging',
        'gastronomy',
        'tourism',
        'emergency',
        'home',
      ],
    );
    expect(sortCategoriesForPresentation(categories).length, categories.length);
    expect(sortCategoriesForPresentation(categories).first.id, 'lodging');
  });

  test('tourism card has a meaningful category fallback without services', () {
    final card = BusinessCardData.fromBusiness(tourismBusiness);
    expect(card.serviceName, 'Turismo y Aventura');
    expect(card.coverImagePath, isNull);
  });

  testWidgets('tourism visual fallback fits at 360px', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessMediaRepositoryProvider.overrideWithValue(
            const BusinessMediaRepository(null),
          ),
          isFavoriteProvider(tourismBusiness.id)
              .overrideWith((ref) async => false),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: BusinessCard(
                  business: tourismBusiness,
                  variant: BusinessCardVariant.home,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Turismo y Aventura'), findsWidgets);
    expect(find.byIcon(Icons.terrain_outlined), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category directory shows tourism at 360px', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) async => categories),
        ],
        child: const MaterialApp(home: Scaffold(body: CategoriesScreen())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Turismo y Aventura'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Explore shows tourism before emergencies and More last',
      (tester) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: AppEnvironment.development,
              supabaseUrl: null,
              supabasePublishableKey: null,
            ),
          ),
          categoriesProvider.overrideWith((ref) async => categories),
        ],
        child: const MaterialApp(home: Scaffold(body: ExploreScreen())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Título de la página + enlace del footer.
    expect(find.text('Explorar'), findsWidgets);
    expect(MediaQuery.sizeOf(tester.element(find.byType(ExploreScreen))).width,
        1366);
    expect(find.text('Todas'), findsOneWidget);
    // Los accesos rápidos usan etiquetas cortas.
    expect(find.text('Turismo'), findsOneWidget);
    expect(find.text('Más'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Turismo')).dx,
      lessThan(tester.getTopLeft(find.text('Emergencias')).dx),
    );
    expect(
      tester.getTopLeft(find.text('Emergencias')).dx,
      lessThan(tester.getTopLeft(find.text('Más')).dx),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home tourism category opens Explore with its filter at 360px',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            environment: AppEnvironment.development,
            supabaseUrl: null,
            supabasePublishableKey: null,
          ),
        ),
        categoriesProvider.overrideWith((ref) async => categories),
        publishedBusinessesProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
            path: '/', builder: (_, __) => const Scaffold(body: HomeScreen())),
        GoRoute(
          path: '/explore',
          builder: (_, __) => const Scaffold(body: ExploreScreen()),
        ),
        GoRoute(
          path: '/categories',
          builder: (_, __) => const Scaffold(body: CategoriesScreen()),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.ensureVisible(find.text('Turismo y Aventura'));
    await tester.pump();
    await tester.tap(find.text('Turismo y Aventura'));
    await tester.pumpAndSettle();

    expect(container.read(selectedCategoryIdProvider), 'tourism');
    expect(find.byType(ExploreScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
