import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ranco_conecta_2/config/app_config.dart';
import 'package:ranco_conecta_2/features/businesses/application/business_profile_presenter.dart';
import 'package:ranco_conecta_2/features/businesses/presentation/business_detail_screen.dart';
import 'package:ranco_conecta_2/shared/models/business.dart';
import 'package:ranco_conecta_2/shared/models/category.dart';
import 'package:ranco_conecta_2/shared/models/location.dart';

void main() {
  test('service presentation shows service-specific sections', () {
    final presentation = businessProfilePresentation(_business());

    expect(presentation.sections, contains(BusinessProfileSection.services));
    expect(presentation.sections, contains(BusinessProfileSection.coverage));
    expect(presentation.sections, contains(BusinessProfileSection.hours));
    expect(presentation.showRequestCta, isTrue);
  });

  test('service presentation does not show lodging modules', () {
    final presentation = businessProfilePresentation(_business());

    expect(
      presentation.sections,
      isNot(contains(BusinessProfileSection.lodgingDetails)),
    );
  });

  test('lodging presentation does not show service-only sections', () {
    final presentation = businessProfilePresentation(
      _business(type: BusinessType.lodging),
    );

    expect(
      presentation.sections,
      isNot(contains(BusinessProfileSection.services)),
    );
    expect(presentation.showRequestCta, isFalse);
  });

  test('commerce/gastronomy/tourism/emergency adapt their public sections', () {
    expect(
      businessProfilePresentation(_business(type: BusinessType.commerce))
          .sections,
      contains(BusinessProfileSection.hours),
    );
    expect(
      businessProfilePresentation(_business(type: BusinessType.gastronomy))
          .sections,
      contains(BusinessProfileSection.hours),
    );
    expect(
      businessProfilePresentation(_business(type: BusinessType.tourism))
          .sections,
      contains(BusinessProfileSection.services),
    );
    expect(
      businessProfilePresentation(_business(type: BusinessType.emergency))
          .sections,
      contains(BusinessProfileSection.coverage),
    );
  });

  test('available now depends on real business hours', () {
    final business = _business(
      hours: const [
        BusinessHour(
          dayOfWeek: 1,
          openTime: '09:00',
          closeTime: '18:00',
          isClosed: false,
        ),
      ],
    );

    expect(
      businessIsAvailableNow(business, DateTime(2026, 9, 21, 10)),
      isTrue,
    );
    expect(
      businessIsAvailableNow(business, DateTime(2026, 9, 21, 19)),
      isFalse,
    );
  });

  testWidgets('service profile renders services coverage hours and request CTA',
      (tester) async {
    await _pumpProfile(tester, _business());

    expect(find.text('Servicios'), findsOneWidget);
    expect(find.text('Cobertura'), findsOneWidget);
    expect(find.text('Horarios'), findsOneWidget);
    expect(find.text('Solicitar servicio'), findsWidgets);
  });

  testWidgets('featured badge renders from real flag; verified stays private',
      (tester) async {
    await _pumpProfile(
      tester,
      _business(verified: true, featured: true),
    );

    // La verificación es un estado interno: no se expone en la ficha pública.
    expect(find.text('Verificado'), findsNothing);
    expect(find.text('Destacado'), findsOneWidget);

    await _pumpProfile(tester, _business(verified: false, featured: false));

    expect(find.text('Verificado'), findsNothing);
    expect(find.text('Destacado'), findsNothing);
  });

  testWidgets('phone and whatsapp buttons only render with real contact data',
      (tester) async {
    await _pumpProfile(tester, _business(phone: null, whatsapp: null));

    expect(find.text('Llamar'), findsNothing);
    expect(find.text('WhatsApp'), findsNothing);

    await _pumpProfile(
      tester,
      _business(phone: '+56911111111', whatsapp: '+56922222222'),
    );

    expect(find.text('Llamar'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
  });

  testWidgets('favorite button shows inactive state for guest', (tester) async {
    await _pumpProfile(tester, _business());

    expect(find.byIcon(Icons.favorite_border_rounded), findsWidgets);
  });

  testWidgets('no photos does not render empty photos section', (tester) async {
    await _pumpProfile(tester, _business(media: const []));

    expect(find.text('Fotos'), findsNothing);
  });

  testWidgets('empty description does not render about section',
      (tester) async {
    await _pumpProfile(tester, _business(description: null));

    expect(find.text('Acerca'), findsNothing);
  });

  testWidgets('business without hours does not show availability badge',
      (tester) async {
    await _pumpProfile(tester, _business(hours: const []));

    expect(find.text('Disponible ahora'), findsNothing);
    expect(find.text('Cerrado ahora'), findsNothing);
    expect(find.text('Horarios'), findsNothing);
  });

  testWidgets('lodging widget does not render service-only section',
      (tester) async {
    await _pumpProfile(tester, _business(type: BusinessType.lodging));

    expect(find.text('Servicios'), findsNothing);
    expect(find.text('Solicitar servicio'), findsNothing);
  });

  testWidgets('request CTA is service only for public profile', (tester) async {
    await _pumpProfile(tester, _business(type: BusinessType.commerce));

    expect(find.text('Solicitar servicio'), findsNothing);
  });

  testWidgets('commerce shows directions only with a real address',
      (tester) async {
    await _pumpProfile(
      tester,
      _business(type: BusinessType.commerce, addressText: 'Comercio 123'),
    );

    expect(find.text('Cómo llegar'), findsWidgets);
    expect(find.text('Ubicación'), findsOneWidget);

    await _pumpProfile(
      tester,
      _business(type: BusinessType.commerce, addressText: null),
    );

    expect(find.text('Cómo llegar'), findsNothing);
  });

  testWidgets('commerce profile does not show service or lodging modules',
      (tester) async {
    await _pumpProfile(
      tester,
      _business(type: BusinessType.commerce, addressText: 'Comercio 123'),
    );

    expect(find.text('Servicios'), findsNothing);
    expect(find.text('Alojamiento'), findsNothing);
    expect(find.text('Solicitar servicio'), findsNothing);
  });

  testWidgets('no reviews shows a clean empty state', (tester) async {
    await _pumpProfile(tester, _business(reviewCount: 0, ratingAvg: 0));

    expect(find.text('Aún no hay opiniones'), findsOneWidget);
    expect(find.text('0.0 · 0 reseñas'), findsNothing);
  });

  testWidgets('long business name has no overflow at 360px', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpProfile(
      tester,
      _business(
        name:
            'Servicios Integrales Especializados del Lago Ranco y Sectores Cercanos',
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('public profile has no overflow at 430px', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpProfile(tester, _business());

    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop layout constrains content width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpProfile(tester, _business());

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedBox && widget.constraints.maxWidth == 1080,
      ),
      findsWidgets,
    );
  });

  test('public detail query only fetches published businesses', () {
    final source = File(
      'lib/features/businesses/data/business_repository.dart',
    ).readAsStringSync();

    expect(source, contains(".eq('publication_status', 'published')"));
  });

  test('provider public link opens the current business id', () {
    final dashboard = File(
      'lib/features/provider_dashboard/presentation/provider_dashboard_screen.dart',
    ).readAsStringSync();
    final status = File(
      'lib/features/provider_registration/presentation/provider_business_status_screen.dart',
    ).readAsStringSync();

    expect(dashboard, contains("'/business/\${business.id}'"));
    expect(status, contains("'/business/\${business.id}'"));
  });
}

Future<void> _pumpProfile(WidgetTester tester, Business business) async {
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
      ],
      child: MaterialApp(
        home: BusinessPublicProfile(business: business),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Business _business({
  BusinessType type = BusinessType.service,
  String name = 'Servicios del Ranco',
  String? description = 'Instalaciones y reparaciones para hogares del sector.',
  String? phone = '+56911111111',
  String? whatsapp = '+56922222222',
  bool verified = true,
  bool featured = false,
  double ratingAvg = 4.8,
  int reviewCount = 12,
  List<BusinessHour>? hours,
  String? addressText,
  List<BusinessMedia> media = const [],
}) {
  return Business(
    id: 'business-1',
    ownerId: 'user-1',
    type: type,
    name: name,
    slug: 'servicios-del-ranco',
    description: description,
    phone: phone,
    whatsapp: whatsapp,
    email: 'hola@ranco.cl',
    website: 'https://ranco.cl',
    addressText: addressText,
    verificationStatus: verified ? 'verified' : 'unverified',
    isFeatured: featured,
    acceptsRequests: true,
    ratingAvg: ratingAvg,
    reviewCount: reviewCount,
    services: type == BusinessType.service || type == BusinessType.tourism
        ? [
            const BusinessService(
              subcategory: Subcategory(
                id: 'subcategory-1',
                categoryId: 'category-1',
                name: 'Enchufes e iluminación',
                slug: 'enchufes-iluminacion',
                description: null,
                iconKey: 'tools',
              ),
              description: 'Diagnóstico, instalación y reparación.',
              priceFrom: 25000,
            ),
          ]
        : const [],
    coverage: const [
      Location(
        id: 'location-1',
        communeId: 'commune-1',
        name: 'Lago Ranco',
        slug: 'lago-ranco',
      ),
      Location(
        id: 'location-2',
        communeId: 'commune-1',
        name: 'Futrono',
        slug: 'futrono',
      ),
    ],
    hours: hours ??
        const [
          BusinessHour(
            dayOfWeek: 1,
            openTime: '09:00',
            closeTime: '18:00',
            isClosed: false,
          ),
        ],
    media: media,
  );
}
