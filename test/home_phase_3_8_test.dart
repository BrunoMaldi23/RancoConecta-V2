import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ranco_conecta_2/config/app_config.dart';
import 'package:ranco_conecta_2/features/businesses/application/business_providers.dart';
import 'package:ranco_conecta_2/features/categories/application/category_providers.dart';
import 'package:ranco_conecta_2/features/home/presentation/home_screen.dart';
import 'package:ranco_conecta_2/features/locations/application/location_providers.dart';
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
        id: 'mechanics',
        name: 'Mecánica',
        slug: 'mecanica',
        iconKey: 'tools',
        themeKey: 'forest'),
  ];

  for (final width in [390.0, 768.0, 1024.0, 1366.0]) {
    testWidgets('Home discovery fits at ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(routes: [
        GoRoute(
            path: '/', builder: (_, __) => const Scaffold(body: HomeScreen())),
        GoRoute(
            path: '/explore',
            builder: (_, __) => const Scaffold(body: Text('Explorar UI'))),
        GoRoute(
            path: '/categories',
            builder: (_, __) => const Scaffold(body: Text('Categorías UI'))),
      ]);
      addTearDown(router.dispose);

      await tester.pumpWidget(ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(const AppConfig(
            environment: AppEnvironment.development,
            supabaseUrl: null,
            supabasePublishableKey: null,
          )),
          categoriesProvider.overrideWith((ref) async => categories),
          publishedBusinessesProvider.overrideWith((ref) async => const []),
          locationsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Encuentra servicios y experiencias en Lago Ranco'),
          findsOneWidget);
      expect(find.text('Buscar alojamientos, comida, servicios...'),
          findsOneWidget);
      expect(find.text('Alojamientos'), findsOneWidget);
      expect(find.text('Gastronomía'), findsOneWidget);
      expect(find.text('Turismo y Aventura'), findsOneWidget);
      expect(find.text('Servicios'), findsOneWidget);
      expect(find.text('Emergencias'), findsOneWidget);
      expect(find.text('Mecánica'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Home clears the visible search when filters reset',
      (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final container = ProviderContainer(overrides: [
      appConfigProvider.overrideWithValue(const AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: null,
        supabasePublishableKey: null,
      )),
      categoriesProvider.overrideWith((ref) async => categories),
      publishedBusinessesProvider.overrideWith((ref) async => const []),
      locationsProvider.overrideWith((ref) async => const []),
    ]);
    addTearDown(container.dispose);
    final router = GoRouter(routes: [
      GoRoute(
          path: '/', builder: (_, __) => const Scaffold(body: HomeScreen())),
      GoRoute(
          path: '/explore',
          builder: (_, __) => const Scaffold(body: Text('Explorar'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    final search = find.widgetWithText(
        TextField, 'Buscar alojamientos, comida, servicios...');
    await tester.enterText(search, 'cabaña');
    container.read(businessSearchQueryProvider.notifier).state = 'cabaña';
    await tester.pump();
    container.read(businessSearchQueryProvider.notifier).state = '';
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(search).controller?.text, isEmpty);
  });
}
