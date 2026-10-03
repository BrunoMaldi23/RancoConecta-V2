import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ranco_conecta_2/features/businesses/presentation/business_card.dart';
import 'package:ranco_conecta_2/features/favorites/application/favorite_providers.dart';
import 'package:ranco_conecta_2/features/provider_dashboard/data/business_media_repository.dart';
import 'package:ranco_conecta_2/shared/models/business.dart';
import 'package:ranco_conecta_2/shared/models/category.dart';
import 'package:ranco_conecta_2/shared/models/location.dart';

void main() {
  const business = Business(
    id: 'business-1',
    ownerId: 'owner-1',
    type: BusinessType.service,
    name: 'Instalaciones y reparaciones del Lago Ranco',
    slug: 'instalaciones-ranco',
    description: null,
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
    services: [
      BusinessService(
        subcategory: Subcategory(
          id: 'subcategory-1',
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

  for (final width in [360.0, 390.0, 800.0, 1366.0]) {
    testWidgets('Home card fits at ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = Size(width, 900);
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
            isFavoriteProvider(business.id).overrideWith((ref) async => false),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: width >= 800 ? 340 : 600,
                    ),
                    child: const BusinessCard(
                      business: business,
                      variant: BusinessCardVariant.home,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Electricidad'), findsWidgets);
      expect(find.text('Lago Ranco'), findsOneWidget);
      expect(find.text('Destacado'), findsNothing);
      expect(find.text('Verificado'), findsNothing);
      expect(find.text('Ver detalle'), findsOneWidget);
      expect(find.textContaining('Cobertura:'), findsNothing);
      expect(find.textContaining('reseñas'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Explore card keeps comparison details', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
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
          isFavoriteProvider(business.id).overrideWith((ref) async => false),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: BusinessCard(
                  business: business,
                  variant: BusinessCardVariant.explore,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Cobertura:'), findsOneWidget);
    expect(find.textContaining('reseñas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
