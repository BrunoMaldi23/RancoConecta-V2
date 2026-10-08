import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ranco_conecta_2/features/auth/application/auth_controller.dart';
import 'package:ranco_conecta_2/features/gastronomy/presentation/table_reservation_screen.dart';

void main() {
  testWidgets('table booking collects contact directly without Auth/profile',
      (tester) async {
    tester.view.physicalSize = const Size(390, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final router = GoRouter(
      initialLocation: '/business/food-1/table-reservation',
      routes: [
        GoRoute(
          path: '/business/:id/table-reservation',
          builder: (_, state) => TableReservationScreen(
            businessId: state.pathParameters['id']!,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(null)),
    ]);
    addTearDown(container.dispose);
    await container.read(authStateProvider.future);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Seleccionar fecha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Hora'), '20:30');
    await tester.enterText(find.widgetWithText(TextField, 'Comensales'), '4');
    await tester.enterText(
        find.widgetWithText(TextField, 'Tu nombre'), 'Cliente QA');
    await tester.enterText(
        find.widgetWithText(TextField, 'Teléfono de contacto'),
        '+56 9 1234 5678');
    await tester.enterText(find.widgetWithText(TextField, 'Mensaje opcional'),
        'Mesa junto a la ventana.');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Enviar solicitud'));
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();

    expect(find.byType(TableReservationScreen), findsOneWidget);
    expect(container.read(authStateProvider).valueOrNull, isNull);
    expect(
        find.textContaining('No pudimos enviar la solicitud'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
