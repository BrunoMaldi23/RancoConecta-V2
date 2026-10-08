import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ranco_conecta_2/features/legal/data/contact_repository.dart';
import 'package:ranco_conecta_2/features/legal/presentation/legal_screen.dart';

class _ContactSender extends ContactRepository {
  _ContactSender() : super(null);

  int calls = 0;
  Completer<void>? pending;
  String? sentSubject;

  @override
  Future<void> send(
      {required String name,
      required String email,
      required String subject,
      required String message}) {
    calls++;
    sentSubject = subject;
    return pending?.future ?? Future.value();
  }
}

void main() {
  Future<void> pumpContact(WidgetTester tester, _ContactSender sender) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = GoRouter(initialLocation: '/contacto', routes: [
      GoRoute(
          path: '/', builder: (_, __) => const Scaffold(body: Text('Home'))),
      GoRoute(
          path: '/contacto',
          builder: (_, __) => ContactScreen(repository: sender)),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  Future<void> fillValid(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Ana Pérez');
    await tester.enterText(fields.at(1), 'ana@example.com');
    await tester.enterText(
        fields.at(2), 'Necesito información sobre mi cuenta.');
    await tester.ensureVisible(find.text('Enviar mensaje'));
    await tester.pumpAndSettle();
  }

  testWidgets('requires fields and rejects invalid email', (tester) async {
    final sender = _ContactSender();
    await pumpContact(tester, sender);
    await tester.ensureVisible(find.text('Enviar mensaje'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enviar mensaje'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa tu nombre.'), findsOneWidget);
    expect(find.text('Ingresa un correo válido.'), findsOneWidget);
    expect(find.text('Escribe al menos 10 caracteres.'), findsOneWidget);
    expect(sender.calls, 0);
    await tester.enterText(find.byType(TextFormField).at(1), 'mal-correo');
    await tester.tap(find.text('Enviar mensaje'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresa un correo válido.'), findsOneWidget);
  });

  testWidgets('sends once, shows loading and clears fields on success',
      (tester) async {
    final sender = _ContactSender()..pending = Completer<void>();
    await pumpContact(tester, sender);
    await fillValid(tester);
    await tester.tap(find.text('Enviar mensaje'));
    await tester.pump();
    expect(sender.calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Enviar mensaje'));
    await tester.pump();
    expect(sender.calls, 1);
    sender.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Mensaje enviado.'), findsOneWidget);
    for (final field
        in tester.widgetList<TextFormField>(find.byType(TextFormField))) {
      expect(field.controller!.text, isEmpty);
    }
    expect(sender.sentSubject, 'Consulta general');
  });

  testWidgets('recoverable error keeps draft for retry', (tester) async {
    final sender = _ContactSender()..pending = Completer<void>();
    await pumpContact(tester, sender);
    await fillValid(tester);
    await tester.tap(find.text('Enviar mensaje'));
    await tester.pump();
    sender.pending!.completeError(StateError('network'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No pudimos enviar'), findsOneWidget);
    final fields =
        tester.widgetList<TextFormField>(find.byType(TextFormField)).toList();
    expect(fields[0].controller!.text, 'Ana Pérez');
    expect(fields[2].controller!.text, isNotEmpty);
    sender.pending = null;
    await tester.tap(find.text('Enviar mensaje'));
    await tester.pumpAndSettle();
    expect(sender.calls, 2);
    expect(find.textContaining('Mensaje enviado.'), findsOneWidget);
  });
}
