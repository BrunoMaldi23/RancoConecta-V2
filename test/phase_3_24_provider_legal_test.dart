import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ranco_conecta_2/config/app_config.dart';
import 'package:ranco_conecta_2/features/auth/data/supabase_auth_repository.dart';
import 'package:ranco_conecta_2/features/auth/domain/auth_user.dart';
import 'package:ranco_conecta_2/features/auth/presentation/sign_in_screen.dart';
import 'package:ranco_conecta_2/features/legal/presentation/legal_screen.dart';

/// FASE 3.24: incorporación de prestadores y legales.
void main() {
  const widths = [390.0, 430.0, 768.0, 1024.0, 1280.0, 1440.0, 1600.0];

  Future<void> setSize(WidgetTester tester, double width,
      [double height = 900]) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<void> pumpJoin(WidgetTester tester, {AuthUser? user}) async {
    final router = GoRouter(initialLocation: '/provider/join', routes: [
      GoRoute(
          path: '/provider/join',
          builder: (_, __) => const ProviderJoinScreen()),
      GoRoute(
          path: '/sign-up',
          builder: (_, state) =>
              Scaffold(body: Text('Registro ${state.uri.query}'))),
      GoRoute(
          path: '/sign-in',
          builder: (_, __) => const Scaffold(body: Text('Ingreso UI'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(const AppConfig(
          environment: AppEnvironment.development,
          supabaseUrl: null,
          supabasePublishableKey: null,
        )),
        if (user != null)
          authRepositoryProvider.overrideWithValue(_SignedIn(user)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  group('provider join', () {
    for (final width in widths) {
      testWidgets('layout, stepper and CTA at ${width.toInt()}px',
          (tester) async {
        await setSize(tester, width);
        await pumpJoin(tester);
        expect(find.text('Ser parte de Ranco Conecta'), findsOneWidget);
        expect(find.text('Haz visible tu negocio'), findsOneWidget);
        for (final benefit in [
          'Presencia en el catálogo local',
          'Solicitudes y reservas en un solo lugar',
          'Perfil editable desde tu cuenta',
        ]) {
          expect(find.text(benefit), findsOneWidget);
        }
        for (final step in [
          'Crear acceso',
          'Completar negocio',
          'Definir cobertura',
          'Enviar a revisión',
        ]) {
          expect(find.text(step), findsOneWidget);
        }
        // Stepper horizontal en desktop, vertical en móvil.
        final first = tester.getRect(find.text('Crear acceso'));
        final last = tester.getRect(find.text('Enviar a revisión'));
        if (width >= 1024) {
          expect((first.top - last.top).abs(), lessThan(2));
          expect(last.left, greaterThan(first.right));
        } else {
          expect(last.top, greaterThan(first.bottom));
        }
        await tester.ensureVisible(find.text('Crear mi acceso'));
        expect(find.text('Crear mi acceso'), findsOneWidget);
        expect(find.text('Puedes guardar tu avance y continuar más tarde.'),
            findsOneWidget);
        expect(find.text('Ya tengo una cuenta'), findsNothing);
        expect(find.textContaining('Publicar'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('desktop column uses 880–960 px', (tester) async {
      await setSize(tester, 1600);
      await pumpJoin(tester);
      final hero = tester.getRect(find
          .ancestor(
              of: find.text('Haz visible tu negocio'),
              matching: find.byType(Container))
          .last);
      expect(hero.width, inInclusiveRange(880, 960));
    });

    testWidgets('CTA keeps the existing flow to create access', (tester) async {
      await setSize(tester, 390, 844);
      await pumpJoin(tester);
      await tester.ensureVisible(find.text('Crear mi acceso'));
      await tester.tap(find.text('Crear mi acceso'));
      await tester.pumpAndSettle();
      expect(find.textContaining('next=%2Faccount'), findsOneWidget);
    });

    testWidgets('signed in: first step done and activation CTA',
        (tester) async {
      await setSize(tester, 1440);
      await pumpJoin(tester,
          user: const AuthUser(
              id: 'u1', email: 'vecina@ranco.cl', emailConfirmed: true));
      expect(find.text('Activar mi acceso prestador'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });
  });

  group('legal', () {
    Future<void> pumpLegal(WidgetTester tester, String route) async {
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
    }

    testWidgets('legal pages no longer show a summary block', (tester) async {
      await setSize(tester, 1440);
      for (final route in ['/politica-privacidad', '/terminos']) {
        await pumpLegal(tester, route);
        expect(find.text('EN POCAS PALABRAS'), findsNothing);
        expect(find.text('Actualizado el 1 oct 2026'), findsOneWidget);
        expect(find.text('Versión 2026-10-01'), findsOneWidget);
      }
    });

    testWidgets('desktop cards: two columns, odd card full width',
        (tester) async {
      await setSize(tester, 1440);
      await pumpLegal(tester, '/politica-privacidad');
      final c1 = tester.getRect(find.text('Datos que solicitamos'));
      final c2 = tester.getRect(find.text('Para qué los usamos'));
      final c5 = tester.getRect(find.text('Tus opciones'));
      expect((c1.top - c2.top).abs(), lessThan(2));
      expect(c2.left, greaterThan(c1.right));
      expect(c5.left, moreOrLessEquals(c1.left, epsilon: 1));
    });

    testWidgets('closing band: help CTA + compact legal links', (tester) async {
      await setSize(tester, 1366);
      await pumpLegal(tester, '/terminos');
      expect(find.text('¿Necesitas ayuda?'), findsOneWidget);
      final links = find.byKey(const ValueKey('legal-links'));
      for (final label in ['Términos', 'Privacidad', 'Contacto']) {
        expect(find.descendant(of: links, matching: find.text(label)),
            findsOneWidget);
      }
      // Sin tarjetas grandes de enlaces.
      expect(tester.getSize(links).height, lessThan(60));
      await tester
          .ensureVisible(find.widgetWithText(OutlinedButton, 'Contacto'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Contacto'));
      await tester.pumpAndSettle();
      expect(find.text('Hablemos'), findsOneWidget);
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    });

    testWidgets('contact shares the closing without pointing to itself',
        (tester) async {
      await setSize(tester, 1366);
      await pumpLegal(tester, '/contacto');
      expect(find.text('¿Necesitas ayuda?'), findsNothing);
      expect(find.byKey(const ValueKey('legal-links')), findsOneWidget);
      // FASE 3.25: sin canales no hay datos inventados ni aviso protagonista.
      expect(find.textContaining('Canal de contacto pendiente'), findsNothing);
      expect(find.text('WhatsApp'), findsNothing);
    });
  });
}

class _SignedIn implements AuthRepository {
  const _SignedIn(this.user);

  final AuthUser user;

  @override
  AuthUser? currentUser() => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
