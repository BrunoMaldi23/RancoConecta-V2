import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ranco_conecta_2/features/legal/presentation/legal_screen.dart';

void main() {
  testWidgets('direct terms URL returns to home', (tester) async {
    final router = GoRouter(initialLocation: '/terminos', routes: [
      GoRoute(
          path: '/', builder: (_, __) => const Scaffold(body: Text('Home'))),
      GoRoute(
          path: '/terminos',
          builder: (_, __) => const LegalScreen(privacy: false)),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('flow draft survives terms, privacy and back navigation',
      (tester) async {
    final draft = TextEditingController();
    addTearDown(draft.dispose);
    final router = GoRouter(initialLocation: '/reserva', routes: [
      GoRoute(
          path: '/', builder: (_, __) => const Scaffold(body: Text('Home'))),
      GoRoute(
          path: '/reserva',
          builder: (context, __) => Scaffold(
                  body: Column(children: [
                TextField(controller: draft),
                TextButton(
                    onPressed: () => context.push('/terminos'),
                    child: const Text('Términos')),
              ]))),
      GoRoute(
          path: '/terminos',
          builder: (_, __) => const LegalScreen(privacy: false)),
      GoRoute(
          path: '/politica-privacidad',
          builder: (_, __) => const LegalScreen(privacy: true)),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Borrador de reserva');
    await tester.tap(find.text('Términos'));
    await tester.pumpAndSettle();
    // FASE 3.24: enlaces legales compactos del cierre (no los del footer).
    await tester.scrollUntilVisible(
        find
            .descendant(
                of: find.byKey(const ValueKey('legal-links')),
                matching: find.text('Privacidad'))
            .hitTestable(),
        250,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find
        .descendant(
            of: find.byKey(const ValueKey('legal-links')),
            matching: find.text('Privacidad'))
        .hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Borrador de reserva'), findsOneWidget);
  });

  testWidgets('origin to contact and back preserves origin', (tester) async {
    final router = GoRouter(initialLocation: '/origen', routes: [
      GoRoute(
          path: '/', builder: (_, __) => const Scaffold(body: Text('Home'))),
      GoRoute(
          path: '/origen',
          builder: (context, __) => Scaffold(
              body: TextButton(
                  onPressed: () => context.push('/contacto'),
                  child: const Text('Abrir contacto')))),
      GoRoute(path: '/contacto', builder: (_, __) => const ContactScreen()),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir contacto'));
    await tester.pumpAndSettle();
    expect(find.text('Hablemos'), findsOneWidget);
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir contacto'), findsOneWidget);
  });

  for (final width in [390.0, 1024.0]) {
    testWidgets('legal pages preserve back history at ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(initialLocation: '/terminos', routes: [
        GoRoute(
            path: '/', builder: (_, __) => const Scaffold(body: Text('Home'))),
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

      await tester.scrollUntilVisible(
          find
              .descendant(
                  of: find.byKey(const ValueKey('legal-links')),
                  matching: find.text('Privacidad'))
              .hitTestable(),
          250,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find
          .descendant(
              of: find.byKey(const ValueKey('legal-links')),
              matching: find.text('Privacidad'))
          .hitTestable());
      await tester.pumpAndSettle();
      expect(
          tester.widget<LegalScreen>(find.byType(LegalScreen)).privacy, isTrue);
      await tester.scrollUntilVisible(
          find
              .descendant(
                  of: find.byKey(const ValueKey('legal-links')),
                  matching: find.text('Contacto'))
              .hitTestable(),
          250,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find
          .descendant(
              of: find.byKey(const ValueKey('legal-links')),
              matching: find.text('Contacto'))
          .hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Hablemos'), findsOneWidget);
      expect(
          find.widgetWithText(FilledButton, 'Enviar mensaje'), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Enviar mensaje'))
              .onPressed,
          isNotNull);

      await tester.tap(find.byTooltip('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
