import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ranco_conecta_2/core/widgets/ranco_site_footer.dart';
import 'package:ranco_conecta_2/features/legal/presentation/legal_screen.dart';

/// FASE 3.24.1: secciones legales como cards expandibles.
void main() {
  // Texto legal fuente (no se modifica: la card abierta debe mostrarlo).
  const privacy = <(String, String)>[
    (
      'Datos que solicitamos',
      'Puedes explorar sin entregar datos personales. Al reservar, contactar un negocio o crear una cuenta, solicitamos los datos necesarios para gestionar esa acción: nombre, teléfono, correo cuando corresponda y los detalles de la solicitud.'
    ),
    (
      'Para qué los usamos',
      'Usamos estos datos para gestionar reservas y solicitudes, permitir que el negocio seleccionado responda, administrar cuentas y proteger el funcionamiento de la plataforma.'
    ),
    (
      'Con quién los compartimos',
      'Los datos de una solicitud o reserva se comparten con el negocio al que la diriges y con los proveedores tecnológicos necesarios para operar Ranco Conecta.'
    ),
    (
      'Analítica y errores',
      'Si estas funciones están habilitadas, registramos eventos de uso anónimos y errores técnicos para mejorar la plataforma. No añadimos nombres, teléfonos ni el texto de tus búsquedas a los eventos de analítica.'
    ),
    (
      'Tus opciones',
      'Puedes consultar, actualizar o solicitar la eliminación de tus datos mediante el canal de contacto de la plataforma, sujeto a las obligaciones de conservación aplicables.'
    ),
  ];
  const terms = <(String, String)>[
    (
      'Uso de la plataforma',
      'Ranco Conecta permite descubrir negocios y enviar solicitudes o reservas. Explorar el catálogo es libre. Para enviar una solicitud debes entregar datos de contacto correctos.'
    ),
    (
      'Negocios y disponibilidad',
      'Cada negocio es responsable de la información que publica, su disponibilidad, sus precios y la prestación de sus servicios. Una solicitud enviada no garantiza su aceptación.'
    ),
    (
      'Cuentas de proveedores',
      'Los proveedores deben entregar información veraz. Sus publicaciones pueden quedar pendientes de revisión, aprobarse o rechazarse antes de aparecer públicamente.'
    ),
    (
      'Uso responsable',
      'No uses la plataforma para enviar información falsa, contenido ilegal o solicitudes abusivas.'
    ),
  ];

  Future<void> setSize(WidgetTester tester, double width,
      [double height = 900]) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<GoRouter> pumpLegal(WidgetTester tester, String route) async {
    final router = GoRouter(initialLocation: route, routes: [
      GoRoute(
          path: '/', builder: (_, __) => const Scaffold(body: Text('Home'))),
      GoRoute(
          path: '/terminos',
          builder: (_, __) => const LegalScreen(privacy: false)),
      GoRoute(
          path: '/politica-privacidad',
          builder: (_, __) => const LegalScreen(privacy: true)),
      GoRoute(path: '/contacto', builder: (_, __) => const ContactScreen()),
      GoRoute(
          path: '/explore',
          builder: (_, __) => const Scaffold(body: Text('Explorar'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> toggle(WidgetTester tester, String title) async {
    await tester.ensureVisible(find.text(title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  for (final (name, route, sections) in [
    ('privacy', '/politica-privacidad', privacy),
    ('terms', '/terminos', terms),
  ]) {
    group(name, () {
      testWidgets('renders expandable cards, all closed', (tester) async {
        await setSize(tester, 1440);
        await pumpLegal(tester, route);
        expect(find.text('Ver detalle'), findsNWidgets(sections.length));
        expect(find.text('Ocultar detalle'), findsNothing);
        expect(find.text('EN ESTA PÁGINA'), findsNothing);
        for (final (title, body) in sections) {
          expect(find.text(title), findsOneWidget);
          // Cerrada: nunca el texto completo de varias oraciones.
          if (body.split('. ').length > 1) {
            expect(find.text(body), findsNothing);
          }
        }
      });

      testWidgets('opening shows the full source text, unchanged',
          (tester) async {
        await setSize(tester, 1440);
        await pumpLegal(tester, route);
        for (final (title, body) in sections) {
          await toggle(tester, title);
          expect(find.text(body), findsOneWidget,
              reason: 'Texto completo de "$title"');
          expect(find.text('Ocultar detalle'), findsOneWidget);
        }
      });

      testWidgets('only one card is open at a time', (tester) async {
        await setSize(tester, 1440);
        await pumpLegal(tester, route);
        await toggle(tester, sections[0].$1);
        await toggle(tester, sections[1].$1);
        expect(find.text('Ocultar detalle'), findsOneWidget);
        expect(find.text(sections[1].$2), findsOneWidget);
        // Cerrar la abierta deja todo cerrado.
        await toggle(tester, sections[1].$1);
        expect(find.text('Ocultar detalle'), findsNothing);
      });

      for (final width in [390.0, 768.0, 1024.0, 1440.0, 1600.0]) {
        testWidgets('no overflow at ${width.toInt()}px, closed and open',
            (tester) async {
          await setSize(tester, width);
          await pumpLegal(tester, route);
          final first = tester.getRect(find.text(sections[0].$1));
          final second = tester.getRect(find.text(sections[1].$1));
          if (width <= 768) {
            expect(second.top, greaterThan(first.bottom));
          } else {
            expect((first.top - second.top).abs(), lessThan(2));
            expect(second.left, greaterThan(first.right));
          }
          expect(tester.takeException(), isNull);
          await toggle(tester, sections.last.$1);
          expect(tester.takeException(), isNull);
        });
      }
    });
  }

  testWidgets('privacy highlight appears inside its open card', (tester) async {
    await setSize(tester, 1440);
    await pumpLegal(tester, '/politica-privacidad');
    const highlight = 'No publicamos tu teléfono en el catálogo.';
    expect(find.text(highlight), findsNothing); // cerrada
    await toggle(tester, 'Con quién los compartimos');
    expect(find.text(highlight), findsOneWidget);
  });

  testWidgets('closed cards are compact (≈120–150 px)', (tester) async {
    await setSize(tester, 1440);
    await pumpLegal(tester, '/terminos');
    final card = tester.getRect(find
        .ancestor(
            of: find.text('Uso de la plataforma'),
            matching: find.byType(Material))
        .first);
    expect(card.height, inInclusiveRange(100, 150));
  });

  testWidgets('page is short with cards closed; footer comes right after',
      (tester) async {
    await setSize(tester, 1440);
    await pumpLegal(tester, '/politica-privacidad');
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    // Contenido + footer caben casi en una pantalla de 900 px.
    expect(scroll.position.maxScrollExtent, lessThan(500));
    await tester.scrollUntilVisible(find.byType(RancoSiteFooter), 300,
        scrollable: find.byType(Scrollable).first);
    final footer = tester.getRect(find.byType(RancoSiteFooter));
    final links = tester.getRect(find.byKey(const ValueKey('legal-links')));
    expect(footer.top - links.bottom, inInclusiveRange(-0.5, 48));
  });

  testWidgets('footer follows short content without viewport filler',
      (tester) async {
    await setSize(tester, 1440, 1400);
    await pumpLegal(tester, '/terminos');
    final footer = tester.getRect(find.byType(RancoSiteFooter));
    final links = tester.getRect(find.byKey(const ValueKey('legal-links')));
    expect(footer.top - links.bottom, inInclusiveRange(-0.5, 48));
  });

  testWidgets('legal links keep push/pop history after opening a card',
      (tester) async {
    await setSize(tester, 1366);
    final router = await pumpLegal(tester, '/');
    router.push('/politica-privacidad');
    await tester.pumpAndSettle();
    await toggle(tester, 'Tus opciones');
    final terms = find
        .descendant(
            of: find.byKey(const ValueKey('legal-links')),
            matching: find.text('Términos'))
        .hitTestable();
    await tester.scrollUntilVisible(terms, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(terms);
    await tester.pumpAndSettle();
    expect(
        tester.widget<LegalScreen>(find.byType(LegalScreen)).privacy, isFalse);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  for (final width in [390.0, 768.0, 1024.0, 1440.0, 1600.0]) {
    testWidgets('contact without regressions at ${width.toInt()}px',
        (tester) async {
      await setSize(tester, width);
      await pumpLegal(tester, '/contacto');
      expect(find.text('Hablemos'), findsOneWidget);
      expect(find.byKey(const ValueKey('legal-links')), findsOneWidget);
      // FASE 3.25: formulario completo sin aviso de canal protagonista.
      expect(find.text('Motivo de contacto'), findsOneWidget);
      expect(find.textContaining('Canal de contacto pendiente'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
