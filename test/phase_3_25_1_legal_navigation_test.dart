import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ranco_conecta_2/features/legal/application/legal_navigation.dart';
import 'package:ranco_conecta_2/features/legal/presentation/legal_screen.dart';

void main() {
  test('returnTo accepts known local routes only', () {
    expect(safeLegalReturnTo('/account?tab=profile'), '/account?tab=profile');
    expect(safeLegalReturnTo('/provider/dashboard'), '/provider/dashboard');
    for (final value in [
      'https://evil.example',
      '//evil.example',
      '/\\evil.example',
      '/terminos',
      '/unknown',
      '/account#fragment',
    ]) {
      expect(safeLegalReturnTo(value), isNull, reason: value);
    }
  });

  Future<GoRouter> pump(WidgetTester tester, String origin) async {
    final router = GoRouter(initialLocation: origin, routes: [
      for (final path in ['/', '/sign-in', '/account', '/provider/dashboard'])
        GoRoute(
          path: path,
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => openLegalPage(
                  context,
                  path == '/sign-in' || path == '/provider/dashboard'
                      ? '/politica-privacidad'
                      : '/terminos'),
              child: Text('Abrir desde $path'),
            ),
          ),
        ),
      GoRoute(
          path: '/terminos',
          builder: (_, __) => const LegalScreen(privacy: false)),
      GoRoute(
          path: '/politica-privacidad',
          builder: (_, __) => const LegalScreen(privacy: true)),
      GoRoute(path: '/contacto', builder: (_, __) => const ContactScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> legalLink(WidgetTester tester, String title) async {
    final link = find
        .descendant(
          of: find.byKey(const ValueKey('legal-links')),
          matching: find.text(title),
        )
        .hitTestable();
    await tester.scrollUntilVisible(link, 250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(link);
    await tester.pumpAndSettle();
  }

  for (final (origin, chain) in [
    ('/', ['Privacidad', 'Contacto']),
    ('/sign-in', ['Contacto']),
    ('/account', ['Privacidad', 'Contacto']),
    ('/provider/dashboard', ['Términos']),
  ]) {
    testWidgets('$origin survives legal page changes', (tester) async {
      final router = await pump(tester, origin);
      await tester.tap(find.text('Abrir desde $origin'));
      await tester.pumpAndSettle();
      expect(
          GoRouterState.of(tester.element(find.byType(LegalScreen)))
              .uri
              .queryParameters['returnTo'],
          origin);
      for (final title in chain) {
        await legalLink(tester, title);
        final legalPage = find.byType(LegalScreen).evaluate().isNotEmpty
            ? find.byType(LegalScreen)
            : find.byType(ContactScreen);
        expect(
            GoRouterState.of(tester.element(legalPage))
                .uri
                .queryParameters['returnTo'],
            origin);
      }
      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, origin);
      expect(find.text('Abrir desde $origin'), findsOneWidget);
    });
  }

  testWidgets('malicious and missing origin use safe fallback', (tester) async {
    final router = await pump(tester, '/');
    router.go('/terminos?returnTo=${Uri.encodeComponent('//evil.example')}');
    await tester.pumpAndSettle();
    await legalLink(tester, 'Privacidad');
    expect(
        router.routeInformationProvider.value.uri.queryParameters
            .containsKey('returnTo'),
        isFalse);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
  });

  test('returnTo accepts internal routes and rejects nested external next', () {
    expect(safeLegalReturnTo('/sign-in?next=%2Faccount'),
        '/sign-in?next=%2Faccount');
    expect(safeLegalReturnTo('/sign-in?next=%2F%2Fevil.example'), isNull);
    expect(
        safeLegalReturnTo('/sign-in?next=https%3A%2F%2Fevil.example'), isNull);
    expect(safeLegalReturnTo('https://evil.example'), isNull);
    expect(safeLegalReturnTo('/terminos'), isNull);
  });
}
